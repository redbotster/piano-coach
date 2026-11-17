import Foundation
import SwiftUI

enum EventStatus {
    case pending, correct, wrong, missed
}

struct TempoMap {
    let bpm0: Double
    let bpm1: Double
    let total: Double

    private var isConstant: Bool { abs(bpm1 - bpm0) < 0.01 || total <= 0 }
    private var slope: Double { (bpm1 - bpm0) / total }

    /// Seconds from beat 0 to `beat` (negative during the count-in).
    func time(_ beat: Double) -> Double {
        if isConstant || beat <= 0 { return beat * 60 / bpm0 }
        let b = min(beat, total)
        var t = 60 / slope * log((bpm0 + slope * b) / bpm0)
        if beat > total { t += (beat - total) * 60 / bpm1 }
        return t
    }

    func beat(_ time: Double) -> Double {
        if isConstant || time <= 0 { return time * bpm0 / 60 }
        let b = bpm0 * (exp(slope * time / 60) - 1) / slope
        if b > total { return total + (time - self.time(total)) * bpm1 / 60 }
        return b
    }
}

/// Publishes the moving playhead separately so only the notation views redraw at 60 fps.
final class PlayheadClock: ObservableObject {
    @Published var beat: Double = 0
}

struct HitMark: Identifiable {
    let id = UUID()
    let beat: Double
    let deviationMs: Double?
    let hand: Hand
}

/// Runs one `PlayTask`: matches incoming notes against what is expected and scores the attempt.
final class TaskRunner: ObservableObject {
    enum Phase { case ready, countIn, running, done }

    struct Hit {
        var note: Int
        var velocity: Int
        var on: Double
        var off: Double?
        var event: Int?
        var hand: Hand
        var deviationMs: Double?
    }

    let task: PlayTask
    let clock = PlayheadClock()

    @Published var phase: Phase
    @Published var statuses: [EventStatus]
    @Published var index = 0
    @Published var flashes: [Int: Bool] = [:]      // note -> good?
    @Published var result: TaskResult?
    @Published var bpm: Double
    @Published var hitMarks: [HitMark] = []
    @Published var countInBeat: Int?

    var onFinish: ((TaskResult) -> Void)?
    var onFeedback: ((Bool) -> Void)?
    var audio: AudioEngine?
    var latencyMs: Double = 0

    private var hits: [Hit] = []
    private var heldHit: [Int: Int] = [:]
    private var matched: [[Bool]]
    private var eventHadError: [Bool]
    private var wrongNotes = 0
    private var pedalEvents: [(down: Bool, time: Double)] = []
    private var startTime: Double = 0
    private var tempo = TempoMap(bpm0: 80, bpm1: 80, total: 0)
    private var window: Double = 0.25
    private var timer: Timer?
    private var finishWork: DispatchWorkItem?

    init(task: PlayTask, bpm: Double? = nil) {
        self.task = task
        self.statuses = Array(repeating: .pending, count: task.events.count)
        self.matched = task.events.map { Array(repeating: false, count: max(1, $0.notes.count)) }
        self.eventHadError = Array(repeating: false, count: task.events.count)
        self.bpm = bpm ?? task.timedConfig?.bpm ?? 80
        self.phase = task.isTimed ? .ready : .running
    }

    deinit { timer?.invalidate() }

    // MARK: Lifecycle

    func reset() {
        stop()
        statuses = Array(repeating: .pending, count: task.events.count)
        matched = task.events.map { Array(repeating: false, count: max(1, $0.notes.count)) }
        eventHadError = Array(repeating: false, count: task.events.count)
        hits = []
        heldHit = [:]
        wrongNotes = 0
        pedalEvents = []
        hitMarks = []
        flashes = [:]
        index = 0
        result = nil
        clock.beat = 0
        countInBeat = nil
        phase = task.isTimed ? .ready : .running
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        finishWork?.cancel()
        audio?.cancelClicks()
    }

    /// Begin a timed attempt: count-in, then the task.
    func start() {
        guard let config = task.timedConfig else { return }
        reset()
        let total = task.totalBeats
        let endBpm = config.tempoEnd.map { $0 * bpm / config.bpm } ?? bpm
        tempo = TempoMap(bpm0: bpm, bpm1: endBpm, total: total)
        let countIn = config.metronome == .off ? 0 : config.countInBeats
        startTime = HostClock.now() + 0.3 + Double(countIn) * 60 / bpm

        var onsets = task.events.map { tempo.time($0.beat) }
        onsets = Array(Set(onsets)).sorted()
        var minGap = 1.0
        for i in onsets.indices.dropFirst() { minGap = min(minGap, onsets[i] - onsets[i - 1]) }
        window = min(0.30, max(0.09, minGap * 0.5))

        var clicks: [(time: Double, accent: Bool)] = []
        if config.metronome != .off {
            let last = config.metronome == .on ? Int(total.rounded(.up)) : 0
            for k in -countIn..<last {
                let inBar = ((k % config.beatsPerBar) + config.beatsPerBar) % config.beatsPerBar
                clicks.append((startTime + tempo.time(Double(k)), config.accentBeats.contains(inBar)))
            }
        }
        audio?.scheduleClicks(clicks)

        phase = countIn > 0 ? .countIn : .running
        clock.beat = Double(-countIn)
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func eventTime(_ i: Int) -> Double { startTime + tempo.time(task.events[i].beat) }

    private func tick() {
        let now = HostClock.now()
        let beat = tempo.beat(now - startTime)
        clock.beat = beat
        if beat < 0 {
            let remaining = Int(ceil(-beat))
            if countInBeat != remaining { countInBeat = remaining }
            return
        }
        if phase == .countIn {
            phase = .running
            countInBeat = nil
        }
        var changed = false
        var newStatuses = statuses
        for i in task.events.indices where newStatuses[i] == .pending && eventTime(i) + window < now {
            newStatuses[i] = .missed
            changed = true
        }
        if changed { statuses = newStatuses }
        let next = statuses.firstIndex(of: .pending) ?? task.events.count
        if next != index { index = next }
        if now > startTime + tempo.time(task.totalBeats) + 0.35 {
            finish()
        }
    }

    // MARK: Input

    private func matches(_ spec: NoteSpec, _ note: Int) -> Bool {
        task.anyOctave ? Music.pc(spec.midi) == Music.pc(note) : spec.midi == note
    }

    private func flash(_ note: Int, good: Bool) {
        flashes[note] = good
        onFeedback?(good)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            if self?.heldHit[note] == nil { self?.flashes[note] = nil }
        }
    }

    func noteOn(_ note: Int, velocity: Int, time: Double) {
        switch phase {
        case .ready, .done:
            return
        case .countIn, .running:
            break
        }
        if task.isTimed {
            timedNoteOn(note, velocity: velocity, time: time - latencyMs / 1000)
        } else {
            untimedNoteOn(note, velocity: velocity, time: time)
        }
    }

    func noteOff(_ note: Int, time: Double) {
        if let i = heldHit[note] {
            hits[i].off = time
            heldHit[note] = nil
        }
        if flashes[note] != nil { flashes[note] = nil }
    }

    func pedal(down: Bool, time: Double) {
        pedalEvents.append((down, time))
    }

    private func untimedNoteOn(_ note: Int, velocity: Int, time: Double) {
        guard index < task.events.count else { return }
        let event = task.events[index]
        var hit = Hit(note: note, velocity: velocity, on: time, off: nil, event: nil, hand: .either, deviationMs: nil)
        var good = false
        if event.isAnyKey {
            matched[index][0] = true
            good = true
        } else if let slot = event.notes.indices.first(where: { !matched[index][$0] && matches(event.notes[$0], note) }) {
            matched[index][slot] = true
            hit.hand = event.notes[slot].hand
            good = true
        } else if event.notes.contains(where: { matches($0, note) }) {
            // Re-striking a note of the chord that is already down: harmless.
            return
        }
        if good {
            hit.event = index
            hits.append(hit)
            heldHit[note] = hits.count - 1
            flash(note, good: true)
            if !matched[index].contains(false) {
                statuses[index] = eventHadError[index] ? .wrong : .correct
                index += 1
                if index >= task.events.count {
                    let work = DispatchWorkItem { [weak self] in self?.finish() }
                    finishWork = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
                }
            }
        } else {
            wrongNotes += 1
            eventHadError[index] = true
            flash(note, good: false)
        }
    }

    private func timedNoteOn(_ note: Int, velocity: Int, time: Double) {
        var best: (event: Int, slot: Int, delta: Double)?
        for i in task.events.indices where statuses[i] == .pending || statuses[i] == .missed {
            let delta = time - eventTime(i)
            guard abs(delta) <= window else { continue }
            let event = task.events[i]
            let slot: Int?
            if event.isAnyKey {
                slot = matched[i][0] ? nil : 0
            } else {
                slot = event.notes.indices.first { !matched[i][$0] && matches(event.notes[$0], note) }
            }
            if let slot, best == nil || abs(delta) < abs(best!.delta) {
                best = (i, slot, delta)
            }
        }
        var hit = Hit(note: note, velocity: velocity, on: time, off: nil, event: nil, hand: .either, deviationMs: nil)
        if let best {
            matched[best.event][best.slot] = true
            hit.event = best.event
            hit.deviationMs = best.delta * 1000
            hit.hand = task.events[best.event].isAnyKey ? .either : task.events[best.event].notes[best.slot].hand
            if !matched[best.event].contains(false) { statuses[best.event] = .correct }
            flash(note, good: true)
        } else {
            wrongNotes += 1
            flash(note, good: false)
        }
        hits.append(hit)
        heldHit[note] = hits.count - 1
        hitMarks.append(HitMark(beat: tempo.beat(time - startTime), deviationMs: hit.deviationMs, hand: hit.hand))
    }

    // MARK: Scoring

    private func finish() {
        guard phase != .done else { return }
        timer?.invalidate()
        timer = nil
        let now = HostClock.now()
        for i in hits.indices where hits[i].off == nil { hits[i].off = now }
        for i in statuses.indices where statuses[i] == .pending { statuses[i] = .missed }
        phase = .done
        countInBeat = nil
        let r = score()
        result = r
        onFinish?(r)
    }

    private func mean(_ xs: [Double]) -> Double { xs.isEmpty ? 0 : xs.reduce(0, +) / Double(xs.count) }

    private func stdDev(_ xs: [Double]) -> Double {
        guard xs.count > 1 else { return 0 }
        let m = mean(xs)
        return sqrt(xs.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(xs.count))
    }

    private func score() -> TaskResult {
        let good = hits.filter { $0.event != nil }
        let velocities = good.map { Double($0.velocity) }
        var total = 0
        var correct = 0
        var meanAbs: Double?
        var meanDev: Double?
        var spread: Double?

        if task.isTimed {
            total = task.events.reduce(0) { $0 + max(1, $1.notes.count) }
            correct = matched.reduce(0) { $0 + $1.filter { $0 }.count }
            let devs = good.compactMap { $0.deviationMs }
            if !devs.isEmpty {
                meanAbs = mean(devs.map { abs($0) })
                meanDev = mean(devs)
                spread = stdDev(devs)
            }
        } else {
            total = task.events.count
            correct = statuses.filter { $0 == .correct }.count
        }
        let accuracy = total == 0 ? 1 : Double(correct) / Double(total)
        let rules = task.rules.map { evaluate($0, good: good) }

        var passed = accuracy >= task.passAccuracy && !rules.contains { !$0.passed }
        if task.isTimed {
            if wrongNotes > max(2, total / 4) { passed = false }
            if let m = meanAbs, m > task.timingToleranceMs { passed = false }
            if meanAbs == nil { passed = false }
        }
        var stars = 0
        if passed {
            stars = 1
            if accuracy >= 0.95 && wrongNotes <= max(0, total / 20) { stars += 1 }
            if task.isTimed {
                if let m = meanAbs, m <= 40, accuracy >= 0.95 { stars += 1 }
            } else if wrongNotes == 0 {
                stars += 1
            }
        }
        return TaskResult(accuracy: accuracy, correct: correct, total: total, wrongNotes: wrongNotes,
                          meanAbsDeviationMs: meanAbs, meanDeviationMs: meanDev, timingSpreadMs: spread,
                          velocityMean: velocities.isEmpty ? nil : mean(velocities),
                          velocityStdDev: velocities.count > 1 ? stdDev(velocities) : nil,
                          bpm: task.isTimed ? bpm : nil, rules: rules, passed: passed, stars: stars)
    }

    private func evaluate(_ rule: Rule, good: [Hit]) -> RuleResult {
        let velocities = good.map { Double($0.velocity) }
        func fmt(_ x: Double) -> String { String(format: "%.0f", x) }

        switch rule {
        case .evenVelocity(let maxStdDev):
            let sd = stdDev(velocities)
            return RuleResult(name: "Even touch", passed: velocities.count > 1 && sd <= maxStdDev,
                              detail: "Velocity varied by ±\(fmt(sd)) (target ±\(fmt(maxStdDev)) or less)")

        case .velocityRange(let lo, let hi, let name):
            let inside = good.filter { $0.velocity >= lo && $0.velocity <= hi }.count
            let share = good.isEmpty ? 0 : Double(inside) / Double(good.count)
            return RuleResult(name: "Dynamic: \(name)", passed: share >= 0.75,
                              detail: "\(Int(share * 100))% of notes inside the \(name) range (velocity \(lo)–\(hi)); your average was \(fmt(mean(velocities)))")

        case .crescendo, .diminuendo:
            let third = max(1, velocities.count / 3)
            let first = mean(Array(velocities.prefix(third)))
            let last = mean(Array(velocities.suffix(third)))
            let rising: Bool
            if case .crescendo = rule { rising = true } else { rising = false }
            let change = rising ? last - first : first - last
            return RuleResult(name: rising ? "Crescendo" : "Diminuendo", passed: velocities.count >= 3 && change >= 15,
                              detail: "Velocity went from \(fmt(first)) to \(fmt(last)) (need a change of 15 or more)")

        case .voicingTop(let minDiff):
            var diffs: [Double] = []
            for i in task.events.indices where task.events[i].notes.count > 1 {
                let chordHits = good.filter { $0.event == i }
                guard chordHits.count > 1, let top = chordHits.max(by: { $0.note < $1.note }) else { continue }
                let rest = chordHits.filter { $0.note != top.note }.map { Double($0.velocity) }
                diffs.append(Double(top.velocity) - mean(rest))
            }
            let ok = diffs.filter { $0 >= Double(minDiff) }.count
            return RuleResult(name: "Voicing the top note", passed: !diffs.isEmpty && Double(ok) / Double(diffs.count) >= 0.7,
                              detail: "Top note was \(fmt(mean(diffs))) louder on average (target \(minDiff)+)")

        case .handBalance(let melody, let minDiff):
            let lead = good.filter { $0.hand == melody }.map { Double($0.velocity) }
            let other = good.filter { $0.hand != melody && $0.hand != .either }.map { Double($0.velocity) }
            let diff = mean(lead) - mean(other)
            return RuleResult(name: "Hand balance", passed: !lead.isEmpty && !other.isEmpty && diff >= Double(minDiff),
                              detail: "\(melody == .right ? "Right" : "Left") hand \(fmt(mean(lead))), other hand \(fmt(mean(other))) (need \(minDiff)+ difference)")

        case .accents(let minDiff):
            let accented = good.filter { $0.event.map { task.events[$0].accent } ?? false }.map { Double($0.velocity) }
            let plain = good.filter { !($0.event.map { task.events[$0].accent } ?? false) }.map { Double($0.velocity) }
            let diff = mean(accented) - mean(plain)
            return RuleResult(name: "Accents", passed: !accented.isEmpty && !plain.isEmpty && diff >= Double(minDiff),
                              detail: "Accented notes \(fmt(mean(accented))), others \(fmt(mean(plain))) (need \(minDiff)+ difference)")

        case .legato:
            var joined = 0
            var pairs = 0
            let ordered = good.sorted { $0.on < $1.on }
            for i in ordered.indices.dropFirst() {
                let previous = ordered[i - 1]
                guard previous.event != ordered[i].event, previous.hand == ordered[i].hand else { continue }
                pairs += 1
                if ordered[i].on - (previous.off ?? ordered[i].on) <= 0.04 { joined += 1 }
            }
            let share = pairs == 0 ? 0 : Double(joined) / Double(pairs)
            return RuleResult(name: "Legato", passed: pairs > 0 && share >= 0.8,
                              detail: "\(joined) of \(pairs) notes connected smoothly to the next")

        case .staccato:
            let secondsPerBeat = 60 / bpm
            var short = 0
            for hit in good {
                let held = (hit.off ?? hit.on) - hit.on
                let expected = hit.event.map { task.events[$0].duration } ?? 1
                let limit = task.isTimed ? min(0.25, max(0.09, expected * secondsPerBeat * 0.55)) : 0.25
                if held <= limit { short += 1 }
            }
            let share = good.isEmpty ? 0 : Double(short) / Double(good.count)
            return RuleResult(name: "Staccato", passed: share >= 0.8,
                              detail: "\(short) of \(good.count) notes were short and detached")

        case .pedalChange:
            var changes = 0
            var needed = 0
            for i in task.events.indices.dropFirst() {
                guard let onset = good.filter({ $0.event == i }).map({ $0.on }).min() else { continue }
                needed += 1
                if let up = pedalEvents.first(where: { !$0.down && $0.time >= onset - 0.06 && $0.time <= onset + 0.7 }),
                   pedalEvents.contains(where: { $0.down && $0.time > up.time && $0.time <= up.time + 0.9 }) {
                    changes += 1
                }
            }
            return RuleResult(name: "Pedal changes", passed: needed > 0 && Double(changes) / Double(needed) >= 0.75,
                              detail: "\(changes) of \(needed) pedal changes made cleanly just after the new notes")
        }
    }
}
