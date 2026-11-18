import AppKit
import Combine
import SwiftUI

struct LessonRecord: Codable {
    var completed = false
    var stars = 0
    var stepStars: [Int: Int] = [:]
    var bestBPM: [Int: Double] = [:]
    // Spaced repetition (see PracticePlan)
    var lastPracticed: Date? = nil
    var reviewIntervalDays: Double? = nil
    var due: Date? = nil
}

final class ProgressStore: ObservableObject {
    @Published var records: [String: LessonRecord] = [:]

    private let url: URL

    init(url: URL) {
        self.url = url
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([String: LessonRecord].self, from: data) {
            records = decoded
        }
    }

    func record(_ id: String) -> LessonRecord { records[id] ?? LessonRecord() }

    func update(_ id: String, _ change: (inout LessonRecord) -> Void) {
        var r = record(id)
        change(&r)
        records[id] = r
        if let data = try? JSONEncoder().encode(records) { try? data.write(to: url, options: .atomic) }
    }

    func reset() {
        records = [:]
        try? FileManager.default.removeItem(at: url)
    }
}

enum LabelMode: String, CaseIterable, Identifiable {
    case none = "Off", cOnly = "C only", all = "All keys"
    var id: String { rawValue }
}

/// Per-step practice aids. Any of them puts the step in practice mode (results are not recorded).
struct PracticeOptions: Equatable {
    var hand: Hand = .either     // .either = both hands
    var wait = false
    var loopOn = false
    var loopFrom = 1             // bars, 1-based, inclusive
    var loopTo = 1
    var autoSpeed = true
}

struct KeyMark {
    enum Kind { case target, info, demo, good, bad }
    var kind: Kind
    var hand: Hand = .either
    var finger: Int? = nil
    var label: String? = nil
}

final class AppModel: ObservableObject {
    let midi = MIDIManager()
    let audio = AudioEngine()
    let profiles: ProfileStore
    private(set) var progress: ProgressStore
    private(set) var history: HistoryStore
    let library = SongLibrary()
    @Published private(set) var sections: [CurriculumSection] = Curriculum.sections

    /// Sidebar destinations that are not lessons.
    static let todayID = "@today"
    static let progressID = "@progress"
    static let freePlayID = "@free"
    static let voiceID = "@voice"
    /// Set when rendering snapshots, so the microphone is never opened.
    static var headless = false

    // Voice
    let voice = VoiceEngine()
    @Published var singRunner: SingRunner?
    /// The key nearest to the note being sung, shown on the keyboard.
    @Published private(set) var sungKey: Int?
    private var sungCandidate: Int?
    private var sungCandidateTime = 0.0
    /// With headphones the piano can guide the singer without the microphone hearing it.
    @Published var headphones: Bool {
        didSet {
            UserDefaults.standard.set(headphones, forKey: "voiceHeadphones")
            if !headphones { voice.monitor = .off }
            if oldValue != headphones { rebuildSingRunner() }
        }
    }
    @Published var voiceRange: VoiceRange {
        didSet {
            if let data = try? JSONEncoder().encode(voiceRange) {
                UserDefaults.standard.set(data, forKey: "voiceRange." + profiles.currentID)
            }
        }
    }
    private var singSink: AnyCancellable?
    private var voiceSink: AnyCancellable?

    // Navigation
    @Published var selectedLessonID: String? { didSet { if oldValue != selectedLessonID { openLesson() } } }
    @Published var stepIndex = 0
    @Published var lessonFinished = false

    // Current step state
    @Published var runner: TaskRunner?
    @Published var quizRound = 0
    @Published var quizCorrect = 0
    @Published var quizDone = false
    @Published var checked: Set<Int> = []
    @Published var lastResult: TaskResult?

    // Live input
    @Published var pressed: [Int: Int] = [:]
    @Published var demoNotes: Set<Int> = []
    @Published var isDemoPlaying = false
    @Published var pedalDown = false
    @Published var lastVelocity: Int?
    @Published var outOfRange = false
    @Published var recentVelocities: [Int] = []

    // Settings
    @Published var soundOn: Bool { didSet { UserDefaults.standard.set(soundOn, forKey: "soundOn") } }
    @Published var labelMode: LabelMode { didSet { UserDefaults.standard.set(labelMode.rawValue, forKey: "labelMode") } }
    @Published var latencyMs: Double { didSet { UserDefaults.standard.set(latencyMs, forKey: "latencyMs") } }
    @Published var padLights: Bool {
        didSet {
            UserDefaults.standard.set(padLights, forKey: "padLights")
            midi.setPadLights(enabled: padLights)
        }
    }
    @Published var typingOctave = 4
    @Published var fallingNotes: Bool { didSet { UserDefaults.standard.set(fallingNotes, forKey: "fallingNotes") } }
    @Published var soundFontPath: String? {
        didSet {
            UserDefaults.standard.set(soundFontPath, forKey: "soundFontPath")
        }
    }

    // Practice aids for the current step
    @Published var options = PracticeOptions() {
        didSet { if oldValue != options, !suppressOptionChange { applyOptions(from: oldValue) } }
    }
    @Published var loopPass = 0
    private var suppressOptionChange = false
    private var baseTask: PlayTask?
    private var accompaniment: [ExpectedEvent] = []
    private var loopActive = false

    // Latency calibration
    @Published var calibration: TaskRunner?
    @Published var calibrationMessage: String?
    private var calibrationSink: AnyCancellable?

    private var librarySink: AnyCancellable?
    private var runnerSink: AnyCancellable?
    private var midiSink: AnyCancellable?
    private var demoWork: [DispatchWorkItem] = []
    /// Moving playhead of the demo, in beats (negative during the lead-in).
    let demoClock = PlayheadClock()
    /// What the falling-notes view shows while a demo plays; nil when the demo must not reveal the notes.
    @Published private(set) var demoScroll: (task: PlayTask, bpm: Double)?
    private lazy var sequencer = NoteSequencer(audio: audio)
    private var demoTimer: Timer?
    private var demoSpans: [(on: Double, off: Double, notes: [Int])] = []
    private var demoEnd = 0.0
    private var demoClicks = false
    private var keyMonitor: Any?
    private var typedDown: Set<UInt16> = []
    private var tempoOverride: [String: Double] = [:]

    private(set) var lessonIndex: [String: (section: CurriculumSection, unit: CurriculumUnit, lesson: Lesson)] = [:]
    private(set) var lessonOrder: [String] = []

    init() {
        let profiles = ProfileStore()
        self.profiles = profiles
        progress = ProgressStore(url: profiles.progressURL)
        history = HistoryStore(url: profiles.historyURL)
        PracticePlan.profileKey = "." + profiles.currentID
        let defaults = UserDefaults.standard
        soundOn = defaults.object(forKey: "soundOn") as? Bool ?? true
        labelMode = LabelMode(rawValue: defaults.string(forKey: "labelMode") ?? "") ?? .cOnly
        latencyMs = defaults.object(forKey: "latencyMs") as? Double ?? 0
        padLights = defaults.bool(forKey: "padLights")
        fallingNotes = defaults.object(forKey: "fallingNotes") as? Bool ?? true
        soundFontPath = defaults.string(forKey: "soundFontPath")
        headphones = defaults.bool(forKey: "voiceHeadphones")
        voiceRange = Self.storedVoiceRange(profiles.currentID)
        if let path = soundFontPath, !audio.loadInstrument(from: URL(fileURLWithPath: path)) { soundFontPath = nil }

        rebuildIndex()
        librarySink = library.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { self?.rebuildIndex() }
        }
        midi.onEvent = { [weak self] event in self?.handle(event) }
        midiSink = midi.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.objectWillChange.send()
                if self.padLights { self.midi.setPadLights(enabled: true) }
            }
        }
        if padLights { midi.setPadLights(enabled: true) }
        voice.output = audio
        voice.onFrame = { [weak self] frame in self?.handleVoice(frame) }
        voiceSink = voice.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { self?.objectWillChange.send() }
        }
        installTypingKeyboard()
        selectedLessonID = defaults.string(forKey: "lastLesson").flatMap { lessonIndex[$0] != nil ? $0 : nil } ?? Self.todayID
        openLesson()
    }

    private func rebuildIndex() {
        sections = Curriculum.sections + (library.section.map { [$0] } ?? [])
        lessonIndex = [:]
        lessonOrder = []
        for section in sections {
            for unit in section.units {
                for lesson in unit.lessons {
                    lessonIndex[lesson.id] = (section, unit, lesson)
                    lessonOrder.append(lesson.id)
                }
            }
        }
    }

    /// Ask for a MIDI or MusicXML file and add it to My Songs.
    func importSong() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["mid", "midi", "musicxml", "xml", "mxl"]
        panel.allowsMultipleSelection = true
        panel.message = "Choose MIDI or MusicXML files to add to My Songs"
        guard panel.runModal() == .OK else { return }
        var lastID: String?
        var failures: [String] = []
        for url in panel.urls {
            do { lastID = try library.importFile(at: url) } catch { failures.append("\(url.lastPathComponent): \(error.localizedDescription)") }
        }
        rebuildIndex()
        if let lastID, lessonIndex[lastID] != nil { selectedLessonID = lastID }
        if !failures.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Some files could not be imported"
            alert.informativeText = failures.joined(separator: "\n")
            alert.runModal()
        }
    }

    func removeImportedSong(_ id: String) {
        if selectedLessonID == id { selectedLessonID = Self.todayID }
        library.remove(id: id)
        rebuildIndex()
    }

    // MARK: Sound and calibration

    func chooseSoundFont() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["sf2", "dls"]
        panel.message = "Choose a SoundFont (.sf2) or DLS file with a piano as its first instrument"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if audio.loadInstrument(from: url) {
            soundFontPath = url.path
        } else {
            let alert = NSAlert()
            alert.messageText = "That file could not be loaded"
            alert.informativeText = "The built-in piano is still in use."
            alert.runModal()
        }
    }

    func resetSoundFont() {
        audio.loadInstrument(from: nil)
        soundFontPath = nil
    }

    /// Eight clicks: the learner taps along and the average offset becomes the latency compensation.
    func startCalibration() {
        stopTask()
        calibrationMessage = nil
        let task = L.timedTask("Calibration", "", L.rhythm("q q q q q q q q", count: false), bpm: 90)
        let r = TaskRunner(task: task)
        r.audio = audio
        r.latencyMs = 0
        r.onFinish = { [weak self] result in
            guard let self else { return }
            if result.correct >= 6, let offset = result.meanDeviationMs {
                let value = min(150, max(0, (offset / 5).rounded() * 5))
                self.latencyMs = value
                self.calibrationMessage = "You tapped \(Int(offset.rounded())) ms \(offset >= 0 ? "after" : "before") the clicks on average. Compensation set to \(Int(value)) ms."
            } else {
                self.calibrationMessage = "Not enough taps landed near the clicks. Try again and tap once per click."
            }
            self.calibration = nil
            self.calibrationSink = nil
        }
        calibrationSink = r.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
        calibration = r
        r.start()
    }

    func cancelCalibration() {
        calibration?.stop()
        calibration = nil
        calibrationSink = nil
    }

    // MARK: Profiles

    /// Point progress, history and the practice plan at the current profile.
    private func loadCurrentProfile() {
        history.saveNow()
        clearStepState()
        progress = ProgressStore(url: profiles.progressURL)
        history = HistoryStore(url: profiles.historyURL)
        PracticePlan.profileKey = "." + profiles.currentID
        tempoOverride = [:]
        voiceRange = Self.storedVoiceRange(profiles.currentID)
        selectedLessonID = Self.todayID
        objectWillChange.send()
    }

    func switchProfile(_ id: String) {
        guard id != profiles.currentID else { return }
        profiles.select(id)
        loadCurrentProfile()
    }

    func addProfile(name: String) {
        profiles.add(name: name)
        loadCurrentProfile()
    }

    func renameProfile(to name: String) {
        profiles.rename(profiles.currentID, to: name)
        objectWillChange.send()
    }

    func deleteCurrentProfile() {
        guard profiles.profiles.count > 1 else { return }
        let id = profiles.currentID
        history.reset()
        PracticePlan.clearCache()
        profiles.delete(id)
        loadCurrentProfile()
    }

    /// Manually mark a lesson complete, or clear the mark (stars and best tempos are kept).
    func setCompleted(_ lessonID: String, _ completed: Bool) {
        progress.update(lessonID) { record in
            record.completed = completed
            if completed {
                if record.lastPracticed == nil { record.lastPracticed = Date() }
            } else {
                record.due = nil
                record.reviewIntervalDays = nil
            }
        }
        if !completed, lessonID == selectedLessonID, lessonFinished {
            lessonFinished = false
            prepareStep()
        }
        objectWillChange.send()
    }

    func isCompleted(_ lessonID: String) -> Bool { progress.record(lessonID).completed }

    func resetAllProgress() {
        progress.reset()
        history.reset()
        PracticePlan.clearCache()
    }

    func shutdown() {
        history.saveNow()
        midi.setPadLights(enabled: false)
        audio.allNotesOff()
    }

    // MARK: Lesson navigation

    var lesson: Lesson? { selectedLessonID.flatMap { lessonIndex[$0]?.lesson } }
    var step: Step? {
        guard let lesson, lesson.steps.indices.contains(stepIndex) else { return nil }
        return lesson.steps[stepIndex]
    }

    var breadcrumb: String {
        guard let id = selectedLessonID, let entry = lessonIndex[id] else { return "" }
        return "\(entry.section.title)  ›  \(entry.unit.title)"
    }

    var nextLessonID: String? {
        guard let id = selectedLessonID, let i = lessonOrder.firstIndex(of: id), i + 1 < lessonOrder.count else { return nil }
        return lessonOrder[i + 1]
    }

    private func openLesson() {
        UserDefaults.standard.set(selectedLessonID, forKey: "lastLesson")
        stepIndex = 0
        lessonFinished = false
        prepareStep()
    }

    // MARK: Voice

    private static func storedVoiceRange(_ profile: String) -> VoiceRange {
        if let data = UserDefaults.standard.data(forKey: "voiceRange." + profile),
           let range = try? JSONDecoder().decode(VoiceRange.self, from: data) { return range }
        return .standard
    }

    /// The microphone is on only while a singing step or the voice studio is showing.
    private func updateVoice() {
        var wanted = selectedLessonID == Self.voiceID
        if case .sing = step, !lessonFinished { wanted = true }
        if wanted {
            if !Self.headless { voice.start() }
        } else {
            voice.monitor = .off
            voice.stop()
            if sungKey != nil { sungKey = nil }
        }
    }

    private func attachSing(_ task: SingTask) {
        singRunner?.stop()
        let runner = SingRunner(task: task, range: voiceRange, headphones: headphones)
        runner.audio = audio
        runner.onFinish = { [weak self] result in self?.singFinished(result) }
        runner.onRange = { [weak self] range in self?.voiceRange = range }
        singSink = runner.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
        singRunner = runner
        lastResult = nil
    }

    /// Start the current singing step again with the present range and headphone settings.
    func rebuildSingRunner() {
        guard case .sing(let task) = step, !lessonFinished, let runner = singRunner,
              runner.phase == .ready || runner.phase == .done || !runner.isTimed else { return }
        attachSing(task)
    }

    func setVoiceRange(_ range: VoiceRange) {
        voiceRange = range
        rebuildSingRunner()
    }

    private func singFinished(_ result: TaskResult) {
        lastResult = result
        guard let lesson else { return }
        let index = stepIndex
        history.record(Attempt(date: Date(), lessonID: lesson.id, step: index, accuracy: result.accuracy,
                               timingMs: nil, evenness: nil, bpm: nil, stars: result.stars, passed: result.passed))
        progress.update(lesson.id) { $0.stepStars[index] = max($0.stepStars[index] ?? 0, result.stars) }
    }

    private func handleVoice(_ frame: PitchFrame) {
        singRunner?.ingest(frame)
        let key = frame.midi.map { Int($0.rounded()) }.flatMap { (Music.lowestKey...Music.highestKey).contains($0) ? $0 : nil }
        // The lit key changes only once a new note has settled, so passing wobbles do not redraw the window.
        if key == sungKey {
            sungCandidate = key
        } else if key != sungCandidate {
            sungCandidate = key
            sungCandidateTime = frame.time
        } else if frame.time - sungCandidateTime >= (key == nil ? 0.15 : 0.06) {
            sungKey = key
        }
    }

    func goToStep(_ i: Int) {
        guard let lesson, lesson.steps.indices.contains(i) else { return }
        stepIndex = i
        lessonFinished = false
        prepareStep()
    }

    func nextStep() {
        guard let lesson else { return }
        if stepIndex + 1 < lesson.steps.count {
            stepIndex += 1
            prepareStep()
        } else {
            finishLesson()
        }
    }

    func previousStep() {
        if lessonFinished { lessonFinished = false; prepareStep(); return }
        if stepIndex > 0 { stepIndex -= 1; prepareStep() }
    }

    func goToNextLesson() {
        if let next = nextLessonID { selectedLessonID = next }
    }

    private func finishLesson() {
        guard let lesson else { return }
        clearStepState()
        let scored = lesson.steps.indices.filter { lesson.steps[$0].isScored }
        progress.update(lesson.id) { record in
            PracticePlan.reschedule(&record, stars: scored.isEmpty ? 3 : Int((Double(scored.reduce(0) { $0 + (record.stepStars[$1] ?? 0) }) / Double(scored.count)).rounded()), now: Date())
            record.completed = true
            if scored.isEmpty {
                record.stars = 3
            } else {
                let sum = scored.reduce(0) { $0 + (record.stepStars[$1] ?? 0) }
                record.stars = max(record.stars, Int((Double(sum) / Double(scored.count)).rounded()))
            }
        }
        lessonFinished = true
        updateVoice()
    }

    private func clearStepState() {
        loopActive = false
        stopDemo()
        runner?.stop()
        runner = nil
        runnerSink = nil
        singRunner?.stop()
        singRunner = nil
        singSink = nil
        lastResult = nil
        checked = []
        quizDone = false
    }

    private func prepareStep() {
        clearStepState()
        quizRound = 0
        quizCorrect = 0
        suppressOptionChange = true
        options = PracticeOptions()
        suppressOptionChange = false
        baseTask = nil
        switch step {
        case .play(let task): attach(task)
        case .quiz(let quiz): attach(quiz.make(0))
        case .sing(let task): attachSing(task)
        default: break
        }
        if selectedLessonID == Self.voiceID {
            // The voice studio draws free singing with no targets and never finishes.
            attachSing(SingTask(title: "Voice studio", instructions: "", kind: .free(seconds: .infinity, span: .infinity)))
        }
        updateVoice()
    }

    private func tempoKey() -> String { "\(selectedLessonID ?? "")#\(stepIndex)" }

    /// True when a practice aid is on; such attempts are not saved to progress or history.
    var isPractice: Bool { options.hand != .either || options.wait || options.loopOn }

    /// The step's task before practice aids are applied.
    var stepTask: PlayTask? { baseTask }

    var taskHasBothHands: Bool {
        guard let base = baseTask else { return false }
        let hands = Set(base.events.flatMap { $0.notes.map { $0.hand } })
        return hands.contains(.left) && hands.contains(.right)
    }

    var taskBarCount: Int {
        guard let base = baseTask, let config = base.timedConfig else { return 1 }
        return max(1, Int((base.totalBeats / Double(config.beatsPerBar)).rounded(.up)))
    }

    /// Apply loop range and hand selection. Returns the task to play and the notes the app plays along.
    private func effectiveTask(_ base: PlayTask) -> (PlayTask, [ExpectedEvent]) {
        var task = base
        var others: [ExpectedEvent] = []
        if options.loopOn, var config = base.timedConfig {
            let bar = Double(config.beatsPerBar)
            let from = Double(max(1, options.loopFrom) - 1) * bar
            let to = Double(max(options.loopFrom, options.loopTo)) * bar
            let slice = base.events.filter { $0.beat >= from - 1e-6 && $0.beat < to - 1e-6 }
            if !slice.isEmpty {
                task.events = slice.map { var e = $0; e.beat -= from; return e }
                config.totalBeats = to - from
                config.tempoEnd = nil
                task.timing = .timed(config)
                task.markers = base.markers.filter { $0.beat >= from - 1e-6 && $0.beat < to - 1e-6 }
                    .map { var m = $0; m.beat -= from; return m }
                task.repeats = []
            }
        }
        if options.hand != .either {
            let total = task.totalBeats
            var mine: [ExpectedEvent] = []
            for event in task.events {
                if event.isAnyKey { mine.append(event); continue }
                let keep = event.notes.filter { $0.hand == options.hand || $0.hand == .either }
                let rest = event.notes.filter { !($0.hand == options.hand || $0.hand == .either) }
                if !keep.isEmpty {
                    var e = event
                    e.notes = keep
                    if let d = keep.compactMap({ $0.duration }).max() { e.duration = d }
                    mine.append(e)
                }
                if !rest.isEmpty {
                    var e = event
                    e.notes = rest
                    if let d = rest.compactMap({ $0.duration }).max() { e.duration = d }
                    others.append(e)
                }
            }
            if mine.isEmpty {
                others = []
            } else {
                task.events = mine
                if var config = task.timedConfig {
                    config.totalBeats = total
                    task.timing = .timed(config)
                }
            }
        }
        return (task, others)
    }

    private func applyOptions(from old: PracticeOptions) {
        guard let base = baseTask else { return }
        loopActive = false
        stopDemo()
        if options.loopOn, !old.loopOn, let config = base.timedConfig {
            // Looping starts slower so the passage can be played cleanly, then climbs.
            if tempoOverride[tempoKey()] == nil {
                tempoOverride[tempoKey()] = max(40, (config.bpm * 0.7 / 4).rounded() * 4)
            }
            suppressOptionChange = true
            options.loopFrom = min(max(1, options.loopFrom), taskBarCount)
            options.loopTo = min(max(options.loopFrom, options.loopTo), taskBarCount)
            suppressOptionChange = false
        }
        loopPass = 0
        attach(base, isBase: true)
    }

    private func attach(_ base: PlayTask, isBase: Bool = true) {
        runner?.stop()
        baseTask = base
        let (task, others) = effectiveTask(base)
        accompaniment = others
        let r = TaskRunner(task: task, bpm: tempoOverride[tempoKey()], waitMode: options.wait)
        r.audio = audio
        r.latencyMs = latencyMs
        r.onFinish = { [weak self] result in self?.taskFinished(result) }
        r.onFeedback = { [weak self] good in
            guard let self, self.padLights else { return }
            self.midi.flashPads(color: good ? 21 : 5)
        }
        runnerSink = r.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
        runner = r
        lastResult = nil
        if task.listenFirst {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self, weak r] in
                guard let self, let r, self.runner === r, r.phase != .done else { return }
                self.playDemo()
            }
        }
    }

    func setTempo(_ bpm: Double) {
        guard let runner, runner.phase == .ready || runner.phase == .done else { return }
        let clamped = min(240, max(30, bpm))
        tempoOverride[tempoKey()] = clamped
        runner.bpm = clamped
    }

    func startTask() {
        stopDemo()
        guard let runner else { return }
        runner.latencyMs = latencyMs
        runner.start()
        lastResult = nil
        loopActive = options.loopOn
        // Play the hand the learner is not practising.
        for event in accompaniment {
            let on = runner.startTime + runner.tempo.time(event.beat) - HostClock.now()
            let off = runner.startTime + runner.tempo.time(event.beat + event.duration * 0.92) - HostClock.now()
            let notes = event.notes.map { $0.midi }
            guard on > 0 else { continue }
            schedule(after: on) { [weak self] in for n in notes { self?.audio.noteOn(n, velocity: 58) } }
            schedule(after: max(on + 0.05, off)) { [weak self] in for n in notes { self?.audio.noteOff(n) } }
        }
    }

    /// Stop a running timed task (and any loop).
    func stopTask() {
        loopActive = false
        stopDemo()
        for event in accompaniment { for spec in event.notes { audio.noteOff(spec.midi) } }
        runner?.reset()
    }

    func retryTask() {
        stopDemo()
        lastResult = nil
        guard let runner else { return }
        if case .quiz(let quiz) = step {
            quizRound = 0
            quizCorrect = 0
            quizDone = false
            attach(quiz.make(0))
        } else {
            loopActive = false
            runner.reset()
        }
    }

    private func taskFinished(_ result: TaskResult) {
        guard let lesson else { return }
        if case .quiz(let quiz) = step {
            if result.wrongNotes == 0 && result.accuracy >= 0.999 { quizCorrect += 1 }
            let next = quizRound + 1
            if next < quiz.rounds {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                    guard let self, case .quiz = self.step, !self.quizDone else { return }
                    self.quizRound = next
                    self.attach(quiz.make(next))
                }
            } else {
                quizDone = true
                let accuracy = Double(quizCorrect) / Double(max(1, quiz.rounds))
                let stars = accuracy >= 0.95 ? 3 : accuracy >= 0.8 ? 2 : accuracy >= 0.6 ? 1 : 0
                lastResult = TaskResult(accuracy: accuracy, correct: quizCorrect, total: quiz.rounds, wrongNotes: 0,
                                        meanAbsDeviationMs: nil, meanDeviationMs: nil, timingSpreadMs: nil,
                                        velocityMean: nil, velocityStdDev: nil, bpm: nil, rules: [],
                                        passed: stars > 0, stars: stars)
                let index = stepIndex
                progress.update(lesson.id) { $0.stepStars[index] = max($0.stepStars[index] ?? 0, stars) }
            }
            return
        }
        if isPractice {
            lastResult = result
            guard options.loopOn, loopActive, let runner, let config = baseTask?.timedConfig else { return }
            loopPass += 1
            if options.autoSpeed, result.accuracy >= 0.95, result.wrongNotes == 0, (result.meanAbsDeviationMs ?? 999) <= 70,
               runner.bpm < config.bpm {
                let next = min(config.bpm, runner.bpm + 4)
                tempoOverride[tempoKey()] = next
                runner.bpm = next
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self, weak runner] in
                guard let self, let runner, self.runner === runner, self.loopActive else { return }
                self.startTask()
            }
            return
        }
        lastResult = result
        let index = stepIndex
        history.record(Attempt(date: Date(), lessonID: lesson.id, step: index, accuracy: result.accuracy,
                               timingMs: result.meanAbsDeviationMs, evenness: result.velocityStdDev,
                               bpm: result.bpm, stars: result.stars, passed: result.passed))
        progress.update(lesson.id) { record in
            record.stepStars[index] = max(record.stepStars[index] ?? 0, result.stars)
            if result.passed, let bpm = result.bpm {
                record.bestBPM[index] = max(record.bestBPM[index] ?? 0, bpm)
            }
        }
    }

    // MARK: Demo playback

    /// The task the Demo button would play for the current step.
    var demoTask: PlayTask? {
        switch step {
        case .play: return runner?.task
        case .quiz: return (runner?.task.listenFirst ?? false) ? runner?.task : nil
        case .info(let info): return info.example
        default: return nil
        }
    }

    func playDemo() {
        guard var task = demoTask else { return }
        stopDemo()
        if let runner, runner.phase == .countIn || (runner.phase == .running && task.isTimed) { runner.reset() }
        let bpm = task.isTimed ? (runner?.bpm ?? task.timedConfig?.bpm ?? 80) : 100
        // Reading and ear tasks must not give the answer away on the keyboard.
        let reveal = task.showTargets
        let config = task.timedConfig
        let endBpm = config?.tempoEnd.map { $0 * bpm / (config?.bpm ?? bpm) } ?? bpm
        let tempo = TempoMap(bpm0: bpm, bpm1: endBpm, total: task.totalBeats)
        let events = task.prompt ?? task.events
        task.events = events

        // Lead-in: a counted bar for timed tasks, a short run-up otherwise, so the first notes can be
        // seen coming and played along with.
        var leadBeats = 0.0
        if reveal {
            if let config, config.metronome != .off, config.countInBeats > 0 {
                leadBeats = Double(config.countInBeats)
            } else {
                leadBeats = (1.5 * bpm / 60).rounded(.up)
            }
        }
        let start = HostClock.now() + 0.15 + leadBeats * 60 / bpm

        var notes: [NoteSequencer.Event] = []
        var spans: [(on: Double, off: Double, notes: [Int])] = []
        var end = 0.0
        for event in events {
            let midis = event.isAnyKey ? [60] : event.notes.map { $0.midi }
            let on = tempo.time(event.beat)
            let velocity = event.accent ? 110 : 76
            var last = on
            for (i, midi) in midis.enumerated() {
                let length = event.isAnyKey ? event.duration : (event.notes[i].duration ?? event.duration)
                let gate = event.articulation == .staccato ? 0.4 : 0.92
                let off = max(on + 0.05, tempo.time(event.beat + length * gate))
                notes.append(.init(time: start + on, note: midi, velocity: velocity))
                notes.append(.init(time: start + off, note: midi, velocity: 0))
                last = max(last, off)
            }
            end = max(end, last)
            if reveal { spans.append((on, last, midis)) }
        }

        if let config, reveal, config.metronome != .off {
            var clicks: [(time: Double, accent: Bool)] = []
            let last = config.metronome == .on ? Int(task.totalBeats.rounded(.up)) : 0
            for k in -Int(leadBeats)..<last {
                let inBar = ((k % config.beatsPerBar) + config.beatsPerBar) % config.beatsPerBar
                clicks.append((start + tempo.time(Double(k)), config.accentBeats.contains(inBar)))
            }
            audio.scheduleClicks(clicks)
            demoClicks = true
        }

        demoSpans = spans
        demoEnd = end
        demoClock.beat = -leadBeats
        demoScroll = reveal ? (task, bpm) : nil
        isDemoPlaying = true
        sequencer.play(notes)

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let t = HostClock.now() - start
            self.demoClock.beat = tempo.beat(t)
            var lit: Set<Int> = []
            for span in self.demoSpans where span.on <= t && t < span.off { lit.formUnion(span.notes) }
            if lit != self.demoNotes { self.demoNotes = lit }
            if t > self.demoEnd + 0.25 { self.stopDemo() }
        }
        RunLoop.main.add(timer, forMode: .common)
        demoTimer = timer
    }

    private func schedule(after delay: Double, _ block: @escaping () -> Void) {
        let work = DispatchWorkItem(block: block)
        demoWork.append(work)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func stopDemo() {
        demoWork.forEach { $0.cancel() }
        demoWork = []
        demoTimer?.invalidate()
        demoTimer = nil
        sequencer.stop()
        if demoClicks { audio.cancelClicks(); demoClicks = false }
        demoSpans = []
        if !demoNotes.isEmpty { demoNotes = [] }
        if demoScroll != nil { demoScroll = nil }
        if isDemoPlaying { isDemoPlaying = false }
    }

    // MARK: Input

    func handle(_ event: InputEvent) {
        switch event {
        case .noteOn(let note, let velocity, let time):
            pressed[note] = velocity
            lastVelocity = velocity
            recentVelocities.append(velocity)
            if recentVelocities.count > 32 { recentVelocities.removeFirst() }
            outOfRange = note < Music.lowestKey || note > Music.highestKey
            if soundOn { audio.noteOn(note, velocity: velocity) }
            if let calibration {
                calibration.noteOn(note, velocity: velocity, time: time)
            } else if demoScroll == nil {
                // While a demo scrolls, playing along is free practice and is not scored.
                runner?.noteOn(note, velocity: velocity, time: time)
            }
        case .noteOff(let note, let time):
            pressed[note] = nil
            audio.noteOff(note)
            runner?.noteOff(note, time: time)
        case .pedal(let down, let time):
            pedalDown = down
            if soundOn { audio.sustain(down) }
            runner?.pedal(down: down, time: time)
        }
    }

    /// Lets the Mac keyboard stand in for the controller: A S D F G H J K are white keys, W E T Y U black keys.
    private func installTypingKeyboard() {
        let map: [UInt16: Int] = [0: 0, 13: 1, 1: 2, 14: 3, 2: 4, 3: 5, 17: 6, 5: 7, 16: 8, 4: 9, 32: 10, 38: 11,
                                  40: 12, 31: 13, 37: 14, 35: 15, 41: 16]
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self else { return event }
            if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty { return event }
            if event.window?.firstResponder is NSTextView { return event }
            if event.type == .keyDown, !event.isARepeat {
                if event.keyCode == 6 { self.typingOctave = max(2, self.typingOctave - 1); return nil }   // Z
                if event.keyCode == 7 { self.typingOctave = min(6, self.typingOctave + 1); return nil }   // X
                if event.keyCode == 49, let sing = self.singRunner, sing.isTimed, sing.phase == .ready || sing.phase == .done {
                    sing.begin()
                    return nil
                }
                if event.keyCode == 49, self.calibration == nil, let runner = self.runner, runner.timedRun,
                   runner.phase == .ready || runner.phase == .done {                                     // space
                    self.startTask()
                    return nil
                }
            }
            guard let offset = map[event.keyCode] else { return event }
            let note = (self.typingOctave + 1) * 12 + offset
            if event.type == .keyDown {
                if !event.isARepeat, !self.typedDown.contains(event.keyCode) {
                    self.typedDown.insert(event.keyCode)
                    self.handle(.noteOn(note: note, velocity: 80, time: HostClock.now()))
                }
            } else {
                self.typedDown.remove(event.keyCode)
                self.handle(.noteOff(note: note, time: HostClock.now()))
            }
            return nil
        }
    }

    // MARK: Keyboard lighting

    /// What each key on the on-screen keyboard should show right now.
    var keyMarks: [Int: KeyMark] {
        var marks: [Int: KeyMark] = [:]
        if case .info(let info) = step, !lessonFinished {
            for key in info.keys {
                marks[key.midi] = KeyMark(kind: .info, hand: key.hand, label: key.label)
            }
        }
        if let runner, !lessonFinished, runner.phase != .done, runner.task.showTargets,
           runner.index < runner.task.events.count {
            for spec in runner.task.events[runner.index].notes {
                marks[spec.midi] = KeyMark(kind: .target, hand: spec.hand,
                                           finger: runner.task.showFingers ? spec.finger : nil)
            }
        }
        if let runner = singRunner, !lessonFinished, runner.phase != .done, runner.index < runner.targets.count,
           let target = runner.targets[runner.index].midi, (Music.lowestKey...Music.highestKey).contains(target) {
            marks[target] = KeyMark(kind: .target, label: Music.name(target))
        }
        if let key = sungKey {
            var good = false
            if let runner = singRunner, runner.index < runner.targets.count, let target = runner.targets[runner.index].midi {
                good = (key - target) % 12 == 0
            }
            marks[key] = KeyMark(kind: good ? .good : .info, label: Music.name(key))
        }
        // Playing along with the demo: a lit key turns green while it is held.
        for note in demoNotes { marks[note] = KeyMark(kind: pressed[note] != nil ? .good : .demo) }
        if let runner {
            for (note, good) in runner.flashes {
                var mark = marks[note] ?? KeyMark(kind: .good)
                mark.kind = good ? .good : .bad
                marks[note] = mark
            }
        }
        return marks
    }
}
