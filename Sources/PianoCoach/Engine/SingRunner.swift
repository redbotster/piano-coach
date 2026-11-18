import Foundation
import SwiftUI

/// Runs one singing exercise: follows the voice against the target notes and scores it.
final class SingRunner: ObservableObject {
    enum Phase { case ready, countIn, running, done }

    struct Target {
        var midi: Int?
        /// Seconds from the start of the exercise (timed) or unused (untimed).
        var start: Double
        var length: Double
        var label: String?
    }

    struct TracePoint {
        var time: Double
        var midi: Double
        /// Whether the voice was on the target note; nil when there was no target.
        var good: Bool?
    }

    let task: SingTask
    let tonic: Int
    let targets: [Target]
    let headphones: Bool
    /// "Now" for the pitch display, in seconds. Timed: from the first beat (negative during the count-in).
    let clock = PlayheadClock()

    @Published private(set) var phase = Phase.ready
    @Published private(set) var index = 0
    @Published private(set) var statuses: [EventStatus]
    @Published private(set) var result: TaskResult?
    @Published private(set) var isListening = false
    /// Untimed: how much of the required hold has been sung, 0...1.
    @Published private(set) var heldProgress = 0.0
    /// Range finder: the note currently being held steadily, and the ends chosen so far.
    @Published private(set) var stableNote: Int?
    @Published var rangeLow: Int?
    @Published var rangeHigh: Int?
    /// Free exploration: seconds sung and semitones covered so far.
    @Published private(set) var freeSeconds = 0.0
    @Published private(set) var freeSpan = 0.0
    private var freeTime = 0.0

    private(set) var trace: [TracePoint] = []
    var audio: AudioEngine?
    var onFinish: ((TaskResult) -> Void)?
    var onRange: ((VoiceRange) -> Void)?

    private var sequencer: NoteSequencer?
    private var timer: Timer?
    private var origin = HostClock.now()
    private var startTime = 0.0
    private var totalSeconds = 0.0
    private var lastFrameTime = 0.0
    private var ignoreUntil = 0.0
    private var held = 0.0
    private var lastGood = 0.0
    private var good: [Int]
    private var seen: [Int]
    private var voiced: [Int]
    private var errors: [Double] = []
    private var recentPitches: [(time: Double, midi: Double)] = []
    private var freeLow = Double.infinity
    private var freeHigh = -Double.infinity
    private var pending: [DispatchWorkItem] = []

    var bpm: Double { if case .timed(let bpm) = task.kind { return bpm } else { return 80 } }
    var isTimed: Bool { task.isTimed }

    init(task: SingTask, range: VoiceRange, headphones: Bool) {
        self.task = task
        self.headphones = headphones
        tonic = range.tonic(for: task.span)
        var tempo = 80.0
        if case .timed(let value) = task.kind { tempo = value }
        let beat: Double = 60 / tempo
        var cursor = 0.0
        var list: [Target] = []
        for note in task.expanded {
            let length = note.beats * beat
            if case .match = task.kind, note.semitone == nil { continue }
            list.append(Target(midi: note.semitone.map { range.tonic(for: task.span) + $0 }, start: cursor, length: length, label: note.label))
            cursor += length
        }
        targets = list
        totalSeconds = cursor
        statuses = Array(repeating: .pending, count: list.count)
        good = Array(repeating: 0, count: list.count)
        seen = Array(repeating: 0, count: list.count)
        voiced = Array(repeating: 0, count: list.count)
        if !task.isTimed { phase = .running }
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Lowest and highest MIDI notes the display should cover.
    var displayRange: ClosedRange<Int> {
        let notes = targets.compactMap { $0.midi }
        guard let low = notes.min(), let high = notes.max() else { return 40...84 }
        let pad = max(4, (14 - (high - low)) / 2)
        return (low - pad)...(high + pad)
    }

    // MARK: Control

    /// Begin: plays the first note, then for timed exercises counts in.
    func begin() {
        if case .match = task.kind {
            playReference()
            return
        }
        guard isTimed, phase == .ready || phase == .done else { return }
        reset()
        let beat = 60 / bpm
        let countIn = 4
        let now = HostClock.now()
        startTime = now + 0.3 + Double(countIn) * beat
        var clicks: [(time: Double, accent: Bool)] = []
        for k in 0..<countIn { clicks.append((startTime - Double(countIn - k) * beat, k == 0)) }
        var notes: [NoteSequencer.Event] = []
        // The starting note sounds through the count-in so the singer can find it.
        if let first = targets.first(where: { $0.midi != nil })?.midi {
            notes.append(.init(time: now + 0.3, note: first, velocity: 70))
            notes.append(.init(time: startTime - beat * 0.6, note: first, velocity: 0))
        }
        if headphones {
            let beats = Int((totalSeconds / beat).rounded(.up))
            for k in 0..<beats { clicks.append((startTime + Double(k) * beat, false)) }
            if task.guide {
                for target in targets {
                    guard let midi = target.midi else { continue }
                    notes.append(.init(time: startTime + target.start, note: midi, velocity: 58))
                    notes.append(.init(time: startTime + target.start + target.length * 0.92, note: midi, velocity: 0))
                }
            }
        }
        audio?.scheduleClicks(clicks)
        play(notes)
        phase = .countIn
        clock.beat = -Double(countIn) * beat
    }

    /// Play the exercise on the piano without scoring.
    func listen() {
        guard phase != .countIn, !(isTimed && phase == .running) else { return }
        stopSound()
        let now = HostClock.now() + 0.15
        var notes: [NoteSequencer.Event] = []
        var end = 0.0
        if case .match = task.kind {
            for (i, target) in targets.enumerated() {
                guard let midi = target.midi else { continue }
                notes.append(.init(time: now + Double(i) * 0.8, note: midi, velocity: 72))
                notes.append(.init(time: now + Double(i) * 0.8 + 0.72, note: midi, velocity: 0))
                end = Double(i) * 0.8 + 0.8
            }
        } else {
            for target in targets {
                guard let midi = target.midi else { continue }
                notes.append(.init(time: now + target.start, note: midi, velocity: 72))
                notes.append(.init(time: now + target.start + target.length * 0.92, note: midi, velocity: 0))
            }
            end = totalSeconds
        }
        play(notes)
        isListening = true
        if !headphones { ignoreUntil = now + end + 0.3 }
        after(end + 0.3) { [weak self] in self?.isListening = false }
    }

    /// Sound the current note of an untimed exercise.
    func playReference() {
        guard index < targets.count, let midi = targets[index].midi else { return }
        stopSound()
        let now = HostClock.now() + 0.05
        play([.init(time: now, note: midi, velocity: 74), .init(time: now + 1.1, note: midi, velocity: 0)])
        // Without headphones the microphone would hear the piano, so wait for it to finish.
        if !headphones { ignoreUntil = now + 1.3 }
        held = 0
        heldProgress = 0
    }

    /// Give up on the current note of an untimed exercise.
    func skip() {
        guard case .match = task.kind, phase == .running, index < targets.count else { return }
        statuses[index] = .missed
        advance()
    }

    func reset() {
        stopSound()
        statuses = Array(repeating: .pending, count: targets.count)
        good = Array(repeating: 0, count: targets.count)
        seen = Array(repeating: 0, count: targets.count)
        voiced = Array(repeating: 0, count: targets.count)
        errors = []
        trace = []
        index = 0
        held = 0
        heldProgress = 0
        freeSeconds = 0
        freeTime = 0
        freeSpan = 0
        freeLow = .infinity
        freeHigh = -.infinity
        result = nil
        origin = HostClock.now()
        clock.beat = 0
        phase = isTimed ? .ready : .running
    }

    func stop() {
        stopSound()
        timer?.invalidate()
        timer = nil
    }

    private func stopSound() {
        pending.forEach { $0.cancel() }
        pending = []
        sequencer?.stop()
        audio?.cancelClicks()
        isListening = false
    }

    private func play(_ notes: [NoteSequencer.Event]) {
        guard let audio else { return }
        if sequencer == nil { sequencer = NoteSequencer(audio: audio) }
        sequencer?.play(notes)
    }

    private func after(_ delay: Double, _ block: @escaping () -> Void) {
        let work = DispatchWorkItem(block: block)
        pending.append(work)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// True while the display should scroll.
    var isMoving: Bool { isTimed ? (phase == .countIn || phase == .running) : phase != .done }

    /// Seconds on the exercise's own timeline, read straight from the clock for smooth drawing.
    func displayTime() -> Double {
        guard isMoving, !AppModel.headless else { return clock.beat }
        return isTimed ? HostClock.now() - startTime : HostClock.now() - origin
    }

    // MARK: Following the voice

    private func tick() {
        let now = HostClock.now()
        guard isTimed else {
            clock.beat = now - origin
            return
        }
        guard phase == .countIn || phase == .running else { return }
        let t = now - startTime
        clock.beat = t
        if phase == .countIn, t >= 0 { phase = .running }
        // Settle notes that have gone by.
        while index < targets.count, t > targets[index].start + targets[index].length + 0.12 {
            settle(index)
            index += 1
        }
        if t > totalSeconds + 0.4 { finishTimed() }
    }

    private func settle(_ i: Int) {
        guard targets[i].midi != nil else {
            statuses[i] = .correct
            return
        }
        if voiced[i] == 0 {
            statuses[i] = .missed
        } else {
            statuses[i] = Double(good[i]) >= 0.5 * Double(max(1, seen[i])) ? .correct : .wrong
        }
    }

    /// Distance from the target in semitones, folded to the nearest octave when any octave counts.
    private func offset(_ midi: Double, from target: Int) -> Double {
        var diff = midi - Double(target)
        if task.anyOctave { diff -= 12 * (diff / 12).rounded() }
        return diff
    }

    /// Feed one microphone reading (main thread).
    func ingest(_ frame: PitchFrame) {
        let dt = min(0.05, max(0, frame.time - lastFrameTime))
        lastFrameTime = frame.time
        guard phase != .done, frame.time >= ignoreUntil else { return }
        switch task.kind {
        case .timed:
            guard phase == .running || phase == .countIn else { return }
            let t = frame.time - startTime
            let i = targets.firstIndex { t >= $0.start && t < $0.start + $0.length }
            var onTarget: Bool? = nil
            var shown = frame.midi
            if let i, let target = targets[i].midi, phase == .running {
                let into = t - targets[i].start
                let grace = min(0.25, targets[i].length * 0.35)
                let scoring = into >= grace && into <= targets[i].length * 0.95
                if scoring { seen[i] += 1 }
                if let midi = frame.midi {
                    let diff = offset(midi, from: target)
                    shown = Double(target) + diff
                    onTarget = abs(diff) * 100 <= task.toleranceCents
                    if scoring {
                        voiced[i] += 1
                        if onTarget == true { good[i] += 1 }
                        errors.append(abs(diff) * 100)
                    }
                }
            }
            if let shown { append(TracePoint(time: t, midi: shown, good: onTarget)) }

        case .match(let hold):
            guard index < targets.count, let target = targets[index].midi else { return }
            let t = frame.time - origin
            if let midi = frame.midi {
                let diff = offset(midi, from: target)
                let onTarget = abs(diff) * 100 <= task.toleranceCents
                append(TracePoint(time: t, midi: Double(target) + diff, good: onTarget))
                if onTarget {
                    held += dt
                    lastGood = frame.time
                    errors.append(abs(diff) * 100)
                } else if frame.time - lastGood > 0.2 {
                    held = 0
                }
            } else if frame.time - lastGood > 0.2 {
                held = 0
            }
            // Published in steps, so the screen is not redrawn for every reading.
            let progress = (min(1, held / hold) * 25).rounded() / 25
            if progress != heldProgress { heldProgress = progress }
            if held >= hold {
                statuses[index] = .correct
                advance()
            }

        case .free(let seconds, let span):
            guard let midi = frame.midi else { return }
            append(TracePoint(time: frame.time - origin, midi: midi, good: nil))
            freeTime += dt
            freeLow = min(freeLow, midi)
            freeHigh = max(freeHigh, midi)
            // Published in steps, so the screen is not redrawn for every reading.
            let shownSeconds = (freeTime * 4).rounded(.down) / 4
            if shownSeconds != freeSeconds, seconds.isFinite { freeSeconds = shownSeconds }
            let shownSpan = (max(0, freeHigh - freeLow) * 2).rounded(.down) / 2
            if shownSpan != freeSpan, span.isFinite { freeSpan = shownSpan }
            if freeTime >= seconds, max(0, freeHigh - freeLow) >= span {
                finish(accuracy: 1, correct: 1, total: 1, detail: String(format: "You covered %.0f semitones.", freeSpan))
            }

        case .range:
            let t = frame.time - origin
            if let midi = frame.midi {
                append(TracePoint(time: t, midi: midi, good: nil))
                recentPitches.append((frame.time, midi))
            } else {
                recentPitches = []
            }
            recentPitches.removeAll { frame.time - $0.time > 0.6 }
            if let first = recentPitches.first, frame.time - first.time > 0.45 {
                let sorted = recentPitches.map { $0.midi }.sorted()
                let steady = sorted[sorted.count - 1] - sorted[0] < 1.0
                let note = steady ? Int(sorted[sorted.count / 2].rounded()) : nil
                if note != stableNote { stableNote = note }
            } else if stableNote != nil {
                stableNote = nil
            }
        }
    }

    private func append(_ point: TracePoint) {
        trace.append(point)
        if trace.count > 3000 { trace.removeFirst(500) }
    }

    private func advance() {
        held = 0
        heldProgress = 0
        index += 1
        if index >= targets.count {
            let total = statuses.count
            let correct = statuses.filter { $0 == .correct }.count
            finish(accuracy: Double(correct) / Double(max(1, total)), correct: correct, total: total, detail: nil)
        } else {
            ignoreUntil = HostClock.now() + 0.35
            after(0.35) { [weak self] in self?.playReference() }
        }
    }

    private func finishTimed() {
        while index < targets.count {
            settle(index)
            index += 1
        }
        let sung = targets.indices.filter { targets[$0].midi != nil }
        let correct = sung.filter { statuses[$0] == .correct }.count
        finish(accuracy: Double(correct) / Double(max(1, sung.count)), correct: correct, total: sung.count, detail: nil)
    }

    /// Finish the range finder with the chosen notes.
    func finishRange() {
        guard let low = rangeLow, let high = rangeHigh, high - low >= 5 else { return }
        onRange?(VoiceRange(low: low, high: high))
        finish(accuracy: 1, correct: 1, total: 1,
               detail: "Your range is \(Music.name(low)) to \(Music.name(high)): \(high - low) semitones. Exercises will now be placed inside it.")
    }

    private func finish(accuracy: Double, correct: Int, total: Int, detail: String?) {
        guard phase != .done else { return }
        stopSound()
        phase = .done
        var rules: [RuleResult] = []
        if let detail {
            rules.append(RuleResult(name: "Result", passed: true, detail: detail))
        } else if !errors.isEmpty {
            let mean = errors.reduce(0, +) / Double(errors.count)
            let word = mean <= 15 ? "excellent" : mean <= 25 ? "good" : mean <= 40 ? "fair" : "wide"
            rules.append(RuleResult(name: "Pitch", passed: mean <= task.toleranceCents,
                                    detail: "on average \(Int(mean.rounded())) cents from the note (\(word))"))
        }
        let stars: Int
        if case .match = task.kind {
            stars = accuracy >= 0.999 ? 3 : accuracy >= 0.75 ? 2 : accuracy >= 0.5 ? 1 : 0
        } else {
            stars = accuracy >= 0.9 ? 3 : accuracy >= 0.75 ? 2 : accuracy >= task.pass ? 1 : 0
        }
        let passed = (task.isTimed ? accuracy >= task.pass : accuracy >= min(task.pass, 0.5)) && stars > 0
        let outcome = TaskResult(accuracy: accuracy, correct: correct, total: total, wrongNotes: 0,
                                 meanAbsDeviationMs: nil, meanDeviationMs: nil, timingSpreadMs: nil,
                                 velocityMean: nil, velocityStdDev: nil, bpm: nil, rules: rules,
                                 passed: passed, stars: stars)
        result = outcome
        onFinish?(outcome)
    }

    // MARK: Self-test

    static func selfTest() -> Bool {
        var failures = 0
        func expect(_ ok: Bool, _ name: String) {
            print("  \(ok ? "ok  " : "FAIL")  \(name)")
            if !ok { failures += 1 }
        }
        let range = VoiceRange(low: 48, high: 67)
        guard case .sing(let scale) = V.pattern("Scale", "", "1 2 3 4 5", bpm: 120) else { return false }
        expect(range.tonic(for: scale.span) + scale.span.lowerBound >= 48 && range.tonic(for: scale.span) + scale.span.upperBound <= 67,
               "a pattern is placed inside the singer's range")
        let parsed = V.notes("1 b3:h 5, 1' r:e #4=la")
        expect(parsed.map { $0.semitone } == [0, 3, -5, 12, nil, 6] && parsed[1].beats == 2 && parsed[4].beats == 0.5
               && parsed[5].label == "la" && parsed[0].label == "do", "sing notation parses degrees, lengths, rests and text")
        guard case .sing(let warm) = V.pattern("Warm-up", "", "1 3 5", bpm: 100, shifts: [0, 1, 2]) else { return false }
        expect(warm.expanded.count == 11 && warm.span == 0...9, "a warm-up repeats its pattern a semitone higher each time")

        /// Sing a timed task with a fixed error and return the result.
        func sing(_ task: SingTask, cents: Double, octave: Int = 0, silent: Set<Int> = []) -> TaskResult? {
            let runner = SingRunner(task: task, range: range, headphones: true)
            runner.begin()
            let start = runner.startTime
            for (i, target) in runner.targets.enumerated() {
                guard let midi = target.midi, !silent.contains(i) else { continue }
                var t = target.start
                while t < target.start + target.length {
                    runner.phase = .running
                    runner.ingest(PitchFrame(time: start + t, midi: Double(midi + 12 * octave) + cents / 100, level: 0.5, clarity: 0.95))
                    t += 0.011
                }
            }
            runner.finishTimed()
            runner.stop()
            return runner.result
        }
        let inTune = sing(scale, cents: 12)
        expect(inTune?.accuracy == 1 && inTune?.stars == 3 && inTune?.passed == true, "singing in tune scores every note")
        let octave = sing(scale, cents: -10, octave: 1)
        expect(octave?.accuracy == 1, "the right notes an octave higher still count")
        let flat = sing(scale, cents: -70)
        expect(flat?.accuracy == 0 && flat?.passed == false, "singing 70 cents flat scores no notes")
        let partial = sing(scale, cents: 5, silent: [1, 3])
        expect(partial.map { abs($0.accuracy - 0.6) < 0.001 } == true, "notes left out are counted as missed")

        guard case .sing(let matching) = V.match("Match", "", "1 5", hold: 0.5) else { return false }
        let runner = SingRunner(task: matching, range: range, headphones: true)
        var time = HostClock.now() + 1
        for target in runner.targets {
            guard let midi = target.midi else { continue }
            runner.ignoreUntil = 0
            for _ in 0..<70 {
                runner.ingest(PitchFrame(time: time, midi: Double(midi) + 0.2, level: 0.5, clarity: 0.95))
                time += 0.011
            }
        }
        runner.stop()
        expect(runner.result?.accuracy == 1 && runner.phase == .done, "holding each note in tune completes a matching exercise")

        print(failures == 0 ? "All singing checks passed" : "\(failures) singing check(s) FAILED")
        return failures == 0
    }
}
