import Foundation

/// Headless checks of the scoring engine with synthetic key presses: `PianoCoach --selftest`.
enum SelfTest {
    static func run() -> Bool {
        var failures = 0
        func expect(_ condition: Bool, _ what: String) {
            print(condition ? "  ok    \(what)" : "  FAIL  \(what)")
            if !condition { failures += 1 }
        }
        func spin(_ seconds: Double) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }

        // 1. Untimed: one wrong note on the way.
        do {
            let runner = TaskRunner(task: L.task("t", "", L.line("C4 D4 E4")))
            var t = HostClock.now()
            for (note, velocity) in [(60, 70), (61, 70), (62, 72), (64, 68)] {
                runner.noteOn(note, velocity: velocity, time: t)
                runner.noteOff(note, time: t + 0.2)
                t += 0.3
            }
            spin(0.8)
            let r = runner.result
            expect(r != nil, "untimed task finishes")
            expect(r?.correct == 2 && r?.total == 3 && r?.wrongNotes == 1, "untimed scoring counts the slip (\(r?.correct ?? -1)/\(r?.total ?? -1), wrong \(r?.wrongNotes ?? -1))")
        }

        // 2. Untimed chord, any octave, legato / staccato / evenness rules.
        do {
            let runner = TaskRunner(task: L.task("t", "", L.chords("C4 E4 G4"), anyOctave: true))
            let t = HostClock.now()
            for note in [48, 76, 67] { runner.noteOn(note, velocity: 80, time: t) }
            spin(0.8)
            expect(runner.result?.accuracy == 1, "chord accepted in any octave")

            func touch(_ rule: Rule, gap: Double, velocities: [Int]) -> Bool {
                let runner = TaskRunner(task: L.task("t", "", L.line("C4 D4 E4 F4 G4"), rules: [rule]))
                var t = HostClock.now() - 3
                for (i, note) in [60, 62, 64, 65, 67].enumerated() {
                    runner.noteOn(note, velocity: velocities[i], time: t)
                    runner.noteOff(note, time: t + 0.4 - gap)
                    t += 0.4
                }
                spin(0.8)
                return runner.result?.rules.first?.passed ?? false
            }
            let even = [70, 72, 69, 71, 70], uneven = [100, 60, 90, 40, 75]
            expect(touch(.legato, gap: -0.02, velocities: even), "legato detected when notes overlap")
            expect(!touch(.legato, gap: 0.2, velocities: even), "legato rejected when notes are detached")
            expect(touch(.staccato, gap: 0.3, velocities: even), "staccato detected for short notes")
            expect(!touch(.staccato, gap: 0.0, velocities: even), "staccato rejected for held notes")
            expect(touch(.evenVelocity(maxStdDev: 8), gap: 0, velocities: even), "even velocity passes")
            expect(!touch(.evenVelocity(maxStdDev: 8), gap: 0, velocities: uneven), "uneven velocity fails")
            expect(touch(.crescendo, gap: 0, velocities: [40, 55, 70, 85, 100]), "crescendo detected")
            expect(touch(L.p, gap: 0, velocities: [40, 42, 45, 38, 41]), "piano dynamic range detected")
        }

        // 3. Timed: every note 25 ms late, one note missed, with a tempo ramp variant.
        for ramp in [false, true] {
            let events = L.rhythm("q q q q q q q q", note: 60)
            let task = L.timedTask("t", "", events, bpm: 240, countIn: 2, tempoEnd: ramp ? 300 : nil)
            let runner = TaskRunner(task: task)
            let map = TempoMap(bpm0: 240, bpm1: ramp ? 300 : 240, total: task.totalBeats)
            let origin = HostClock.now() + 0.3 + 2 * 60.0 / 240
            runner.start()
            for event in events where event.beat != 5 {
                let at = origin + map.time(event.beat) + 0.025
                DispatchQueue.main.asyncAfter(deadline: .now() + (at - HostClock.now())) {
                    runner.noteOn(60, velocity: 80, time: at)
                    runner.noteOff(60, time: at + 0.1)
                }
            }
            spin(0.3 + 0.5 + map.time(task.totalBeats) + 0.8)
            let r = runner.result
            expect(r != nil, "timed task finishes\(ramp ? " (accelerando)" : "")")
            expect(r?.correct == 7 && r?.total == 8, "timed scoring finds the missed note (\(r?.correct ?? -1)/\(r?.total ?? -1))")
            let dev = r?.meanAbsDeviationMs ?? -1
            expect(abs(dev - 25) < 4, "timing deviation measured as \(String(format: "%.1f", dev)) ms (expected 25)")
            expect(runner.statuses[5] == .missed, "missed note is marked")
        }

        // 4. Polyrhythm 3 against 2, hands matched separately.
        do {
            let right = L.rhythm("3q 3q 3q 3q 3q 3q", note: 72, hand: .right, count: false)
            let left = L.rhythm("q q q q", note: 48, hand: .left, count: false)
            let task = L.timedTask("t", "", L.together(right, left), bpm: 200, countIn: 2)
            let runner = TaskRunner(task: task)
            let origin = HostClock.now() + 0.3 + 2 * 60.0 / 200
            runner.start()
            for (part, note) in [(right, 72), (left, 48)] {
                for event in part {
                    let at = origin + event.beat * 60 / 200
                    DispatchQueue.main.asyncAfter(deadline: .now() + (at - HostClock.now())) {
                        runner.noteOn(note, velocity: note == 72 ? 95 : 55, time: at)
                    }
                }
            }
            spin(0.3 + 0.6 + 4 * 0.3 + 0.9)
            expect(runner.result?.accuracy == 1, "3:2 polyrhythm fully matched (\(runner.result?.correct ?? -1)/\(runner.result?.total ?? -1))")
        }

        print(failures == 0 ? "All engine checks passed" : "\(failures) engine check(s) failed")
        return failures == 0
    }
}
