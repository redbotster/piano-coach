import AppKit
import Combine
import SwiftUI

struct LessonRecord: Codable {
    var completed = false
    var stars = 0
    var stepStars: [Int: Int] = [:]
    var bestBPM: [Int: Double] = [:]
}

final class ProgressStore: ObservableObject {
    @Published var records: [String: LessonRecord] = [:]

    private let url: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PianoCoach", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("progress.json")
    }()

    init() {
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
    let progress = ProgressStore()
    let sections: [CurriculumSection] = Curriculum.sections

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

    private var runnerSink: AnyCancellable?
    private var midiSink: AnyCancellable?
    private var demoWork: [DispatchWorkItem] = []
    private var keyMonitor: Any?
    private var typedDown: Set<UInt16> = []
    private var tempoOverride: [String: Double] = [:]

    private(set) var lessonIndex: [String: (section: CurriculumSection, unit: CurriculumUnit, lesson: Lesson)] = [:]
    private(set) var lessonOrder: [String] = []

    init() {
        let defaults = UserDefaults.standard
        soundOn = defaults.object(forKey: "soundOn") as? Bool ?? true
        labelMode = LabelMode(rawValue: defaults.string(forKey: "labelMode") ?? "") ?? .cOnly
        latencyMs = defaults.object(forKey: "latencyMs") as? Double ?? 0
        padLights = defaults.bool(forKey: "padLights")

        for section in sections {
            for unit in section.units {
                for lesson in unit.lessons {
                    lessonIndex[lesson.id] = (section, unit, lesson)
                    lessonOrder.append(lesson.id)
                }
            }
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
        installTypingKeyboard()
        selectedLessonID = defaults.string(forKey: "lastLesson").flatMap { lessonIndex[$0] != nil ? $0 : nil }
        if selectedLessonID != nil { openLesson() }
    }

    func shutdown() {
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
            record.completed = true
            if scored.isEmpty {
                record.stars = 3
            } else {
                let sum = scored.reduce(0) { $0 + (record.stepStars[$1] ?? 0) }
                record.stars = max(record.stars, Int((Double(sum) / Double(scored.count)).rounded()))
            }
        }
        lessonFinished = true
    }

    private func clearStepState() {
        stopDemo()
        runner?.stop()
        runner = nil
        runnerSink = nil
        lastResult = nil
        checked = []
        quizDone = false
    }

    private func prepareStep() {
        clearStepState()
        quizRound = 0
        quizCorrect = 0
        switch step {
        case .play(let task): attach(task)
        case .quiz(let quiz): attach(quiz.make(0))
        default: break
        }
    }

    private func tempoKey() -> String { "\(selectedLessonID ?? "")#\(stepIndex)" }

    private func attach(_ task: PlayTask) {
        runner?.stop()
        let r = TaskRunner(task: task, bpm: tempoOverride[tempoKey()])
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
    }

    func setTempo(_ bpm: Double) {
        guard let runner, runner.phase == .ready || runner.phase == .done else { return }
        let clamped = min(240, max(30, bpm))
        tempoOverride[tempoKey()] = clamped
        runner.bpm = clamped
    }

    func startTask() {
        stopDemo()
        runner?.latencyMs = latencyMs
        runner?.start()
        lastResult = nil
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
        } else if runner.task.isTimed {
            runner.reset()
        } else {
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
        lastResult = result
        let index = stepIndex
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
        case .info(let info): return info.example
        default: return nil
        }
    }

    func playDemo() {
        guard let task = demoTask else { return }
        stopDemo()
        if let runner, runner.phase == .countIn || (runner.phase == .running && task.isTimed) { runner.reset() }
        let bpm = task.isTimed ? (runner?.bpm ?? task.timedConfig?.bpm ?? 80) : 100
        let config = task.timedConfig
        let endBpm = config?.tempoEnd.map { $0 * bpm / (config?.bpm ?? bpm) } ?? bpm
        let tempo = TempoMap(bpm0: bpm, bpm1: endBpm, total: task.totalBeats)
        isDemoPlaying = true
        var end = 0.0
        for event in task.events {
            let notes = event.isAnyKey ? [60] : event.notes.map { $0.midi }
            let on = tempo.time(event.beat) + 0.15
            let gate = event.articulation == .staccato ? 0.4 : 0.92
            let off = tempo.time(event.beat + event.duration * gate) + 0.15
            end = max(end, off)
            let velocity = event.accent ? 110 : 76
            schedule(after: on) { [weak self] in
                guard let self else { return }
                for n in notes { self.audio.noteOn(n, velocity: velocity); self.demoNotes.insert(n) }
            }
            schedule(after: max(on + 0.05, off)) { [weak self] in
                guard let self else { return }
                for n in notes { self.audio.noteOff(n); self.demoNotes.remove(n) }
            }
        }
        schedule(after: end + 0.2) { [weak self] in self?.isDemoPlaying = false }
    }

    private func schedule(after delay: Double, _ block: @escaping () -> Void) {
        let work = DispatchWorkItem(block: block)
        demoWork.append(work)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func stopDemo() {
        demoWork.forEach { $0.cancel() }
        demoWork = []
        for n in demoNotes { audio.noteOff(n) }
        demoNotes = []
        isDemoPlaying = false
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
            runner?.noteOn(note, velocity: velocity, time: time)
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
                if event.keyCode == 49, let runner = self.runner, runner.task.isTimed,
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
        for note in demoNotes { marks[note] = KeyMark(kind: .demo) }
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
