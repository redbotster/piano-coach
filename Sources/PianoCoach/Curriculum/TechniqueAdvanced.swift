import Foundation

// Section 4, second half: intermediate and advanced technique, exercise traditions, MIDI skill tests.

fileprivate enum AdvKit {
    static func n(_ s: String) -> [Int] { Music.notes(s) }
    static func f(_ s: String) -> [Int] { s.split(separator: " ").compactMap { Int($0) } }

    /// Sequential events from tokens like "L:C2:5 L:C3+E3+G3:5-3-1 R:C4:1" (hand : notes : fingers).
    static func seq(_ spec: String, duration: Double = 1, start: Double = 0) -> [ExpectedEvent] {
        var out: [ExpectedEvent] = []
        var beat = start
        for token in spec.split(separator: " ") {
            let parts = token.split(separator: ":").map(String.init)
            guard parts.count >= 2 else { continue }
            let hand: Hand = parts[0] == "L" ? .left : .right
            let fingers: [Int] = parts.count > 2 ? parts[2].split(separator: "-").compactMap { Int($0) } : []
            var specs: [NoteSpec] = []
            for (i, name) in parts[1].split(separator: "+").enumerated() {
                specs.append(NoteSpec(midi: Music.midi(String(name)), hand: hand,
                                      finger: i < fingers.count ? fingers[i] : nil))
            }
            out.append(ExpectedEvent(notes: specs, beat: beat, duration: duration))
            beat += duration
        }
        return out
    }

    /// Octaves built on the given lower notes. Black keys take the 4th finger.
    static func oct(_ low: [Int], hand: Hand, duration: Double = 1, start: Double = 0) -> [ExpectedEvent] {
        let groups: [[Int]] = low.map { [$0, $0 + 12] }
        let fingers: [[Int]] = low.map { note in
            let outer = Music.isBlack(note) ? 4 : 5
            return hand == .left ? [outer, 1] : [1, outer]
        }
        return L.chords(groups, hand: hand, fingers: fingers, duration: duration, start: start)
    }

    /// One note per event, with a repeating cycle of durations (for rhythmic variants).
    static func cycle(_ notes: [Int], hand: Hand = .right, fingers: [Int], durations: [Double],
                      start: Double = 0) -> [ExpectedEvent] {
        var out: [ExpectedEvent] = []
        var beat = start
        for (i, note) in notes.enumerated() {
            let d = durations[i % durations.count]
            let finger: Int? = fingers.isEmpty ? nil : fingers[i % fingers.count]
            out.append(ExpectedEvent(notes: [NoteSpec(midi: note, hand: hand, finger: finger)], beat: beat, duration: d))
            beat += d
        }
        return out
    }

    /// Move a white key by a number of white-key steps.
    static func dia(_ midi: Int, _ steps: Int) -> Int {
        let pcs = [0, 2, 4, 5, 7, 9, 11]
        let index = (midi / 12) * 7 + (pcs.firstIndex(of: midi % 12) ?? 0) + steps
        return (index / 7) * 12 + pcs[index % 7]
    }

    /// The classic first Hanon figure (up a third, step up to the 6th, step back), rising one step per bar.
    static func hanon(start: Int, bars: Int, hand: Hand, duration: Double) -> [ExpectedEvent] {
        let shape = [0, 2, 3, 4, 5, 4, 3, 2]
        let fingers = hand == .left ? [5, 4, 3, 2, 1, 2, 3, 4] : [1, 2, 3, 4, 5, 4, 3, 2]
        var notes: [Int] = []
        var fing: [Int] = []
        for bar in 0..<bars {
            for (i, offset) in shape.enumerated() {
                notes.append(dia(start, bar + offset))
                fing.append(fingers[i])
            }
        }
        return L.line(notes, hand: hand, fingers: fing, duration: duration)
    }

    /// Low–high–middle–high for each (low, middle, high) chord.
    static func alberti(_ chords: [[Int]], repeats: Int) -> [Int] {
        var out: [Int] = []
        for chord in chords {
            for _ in 0..<repeats { out += [chord[0], chord[2], chord[1], chord[2]] }
        }
        return out
    }

    static let run: [Int] = n("C4 D4 E4 F4 G4 F4 E4 D4 C4 D4 E4 F4 G4 F4 E4 D4 C4")
    static let runFingers: [Int] = [1, 2, 3, 4, 5, 4, 3, 2, 1, 2, 3, 4, 5, 4, 3, 2, 1]

    static func runEvents(duration: Double) -> [ExpectedEvent] {
        var events = L.line(Array(run.dropLast()), fingers: Array(runFingers.dropLast()), duration: duration)
        events += L.line([60], fingers: [1], duration: 1, start: Double(run.count - 1) * duration)
        return events
    }
}

extension Curriculum {
    static var techniqueAdvanced: [CurriculumUnit] {
        [advPatternsUnit, advOctavesUnit, advAgilityUnit, advSoundUnit, advPracticeUnit, advTraditionsUnit, advTestsUnit]
    }

    // MARK: - Broken chords and Alberti bass

    fileprivate static var advPatternsUnit: CurriculumUnit {
        let rhBroken: [Int] = AdvKit.n("C4 E4 G4 E4 C4 F4 A4 F4 B3 D4 G4 D4 C4 E4 G4 E4")
        let rhFingers: [Int] = [1, 3, 5, 3, 1, 3, 5, 3, 1, 2, 5, 2, 1, 3, 5, 3]
        let brokenExample = L.timedTask("Broken chords", "", L.line(rhBroken, fingers: rhFingers, duration: 0.5),
                                        bpm: 80, display: .staff)
        let broken = lesson("technique.patterns.broken", "Broken chords",
                            "Play the notes of a chord one at a time, evenly.", [
            L.info("What is a broken chord?", """
            A **broken chord** plays the notes of a chord one after another instead of together. It keeps the harmony sounding while adding motion, and it is the basis of most piano accompaniments.

            Keep your hand in the chord shape the whole time: the fingers stay over their keys and simply take turns. Do not hop from note to note.
            """, keys: L.keys("C4 E4 G4", hand: .right), example: brokenExample),
            L.play("Right hand: C chord, broken", "Play C–E–G–E twice with fingers 1–3–5–3. Hold the shape; let each finger drop on its own.",
                   L.line("C4 E4 G4 E4 C4 E4 G4 E4", fingers: "1 3 5 3 1 3 5 3")),
            L.play("Left hand: C chord, broken", "Same idea in the left hand: C–E–G–E with fingers 5–3–1–3.",
                   L.line("C3 E3 G3 E3 C3 E3 G3 E3", hand: .left, fingers: "5 3 1 3 5 3 1 3")),
            L.timed("Changing chords", "Four broken chords in steady eighth notes: C, F, G, C. Only the fingers that need to move should move.",
                    L.line(rhBroken, fingers: rhFingers, duration: 0.5), bpm: 72, display: .staffAndRhythm),
            L.timed("With a bass note", "Add the left hand: one held bass note under each broken chord.",
                    L.together(L.line(rhBroken, fingers: rhFingers, duration: 0.5),
                               L.melody("C3:h:5 C3:h:5 B2:h:5 C3:h:5", hand: .left)),
                    bpm: 66, display: .staffAndRhythm),
            L.timed("Even touch", "Right hand alone again. This time the score checks that no note sticks out.",
                    L.line(rhBroken, fingers: rhFingers, duration: 0.5), bpm: 80, display: .staffAndRhythm,
                    rules: [.evenVelocity(maxStdDev: 13)]),
        ])

        let albertiChords: [[Int]] = [[48, 52, 55], [48, 53, 57], [47, 50, 55], [48, 52, 55]]
        let albertiNotes: [Int] = AdvKit.alberti(albertiChords, repeats: 2)
        let albertiFingers: [Int] = Array(repeating: [5, 1, 3, 1], count: 8).flatMap { $0 }
        let albertiLine = L.line(albertiNotes, hand: .left, fingers: albertiFingers, duration: 0.5)
        let albertiMelody = L.melody("E4:h:3 G4:h:5 F4:h:3 A4:h:5 D4:h:2 G4:h:5 E4:w:3")
        let alberti = lesson("technique.patterns.alberti", "Alberti bass",
                             "The classic low–high–middle–high left-hand pattern.", [
            L.info("Low – high – middle – high", """
            The **Alberti bass** breaks a chord in the order **low, high, middle, high**. Mozart, Haydn and Clementi used it constantly under singing melodies.

            In the left hand on a C chord that is C–G–E–G with fingers **5–1–3–1**. The thumb plays every other note, so keep it light: let the hand rock gently rather than poking with the thumb.
            """, keys: L.keys("C3 E3 G3", hand: .left),
                   example: L.timedTask("Alberti bass", "", L.line(AdvKit.alberti([[48, 52, 55]], repeats: 2), hand: .left, duration: 0.5),
                                        bpm: 96, display: .staff)),
            L.play("Learn the pattern", "C–G–E–G twice, fingers 5–1–3–1.",
                   L.line("C3 G3 E3 G3 C3 G3 E3 G3", hand: .left, fingers: "5 1 3 1 5 1 3 1")),
            L.timed("Four chords", "One bar each of C, F, G and C. The bottom note changes least; feel how little the hand has to move.",
                    albertiLine, bpm: 72, display: .staffAndRhythm),
            L.timed("Quiet and even", "The accompaniment should murmur. Keep every note at the same soft level.",
                    albertiLine, bpm: 80, display: .staffAndRhythm, rules: [.evenVelocity(maxStdDev: 13)]),
            L.timed("Melody over Alberti bass", "Right hand sings the melody in long notes; left hand keeps the pattern quieter than the tune.",
                    L.together(albertiMelody, albertiLine), bpm: 66, display: .staffAndRhythm,
                    rules: [.handBalance(melody: .right, minDiff: 10)]),
        ])
        return unit("technique.patterns", "Broken chords & Alberti bass", [broken, alberti])
    }

    // MARK: - Octaves and double notes

    fileprivate static var advOctavesUnit: CurriculumUnit {
        let wrist = lesson("technique.octaves.wrist", "Octaves: hand shape and wrist",
                           "Play octaves with a loose wrist instead of a stiff arm.", [
            L.info("The octave frame", """
            An octave is played with **thumb and fifth finger** (1 and 5). The hand opens to the span and keeps that frame; the three middle fingers stay relaxed and slightly raised, not clenched.

            The sound comes from a small **drop of the wrist and forearm**, like knocking on a door, not from squeezing the fingers. After each octave the wrist releases upward so tension never builds.

            If an octave is a stretch for your hand, play nearer the front edge of the keys and never force the span.
            """, keys: L.keys("C4 C5", hand: .right), links: [.video("piano octave technique loose wrist")]),
            L.checklist("Check your hand", "Play one octave C–C in the right hand and hold it.", items: [
                "My thumb and fifth finger reach the octave without straining",
                "My middle fingers are loose, not curled tight or pressed down",
                "My wrist is level and can bounce freely",
                "My shoulder and upper arm feel heavy and relaxed",
            ]),
            L.play("Right-hand octaves", "Five octaves stepping up from C. Drop into each one, then release.",
                   AdvKit.oct(AdvKit.n("C4 D4 E4 F4 G4"), hand: .right)),
            L.play("Left-hand octaves", "The same in the left hand, fifth finger on the bottom.",
                   AdvKit.oct(AdvKit.n("C2 D2 E2 F2 G2"), hand: .left)),
            L.timed("Up and back", "Octaves in quarter notes, up five notes and back. Both notes of each octave must arrive together.",
                    AdvKit.oct(AdvKit.n("C4 D4 E4 F4 G4 F4 E4 D4 C4"), hand: .right), bpm: 63, display: .staffAndRhythm),
            L.timed("Left hand up and back", "Now the left hand at the same tempo.",
                    AdvKit.oct(AdvKit.n("C2 D2 E2 F2 G2 F2 E2 D2 C2"), hand: .left), bpm: 63, display: .staffAndRhythm),
        ])

        let repeated: [Int] = Array(repeating: 60, count: 8) + Array(repeating: 65, count: 8) + Array(repeating: 67, count: 8) + [60]
        let passage: [Int] = AdvKit.n("C4 D4 Eb4 F4 G4 F4 Eb4 D4 C4")
        let bass: [Int] = AdvKit.n("C2 C2 G2 G2 A2 A2 F2 F2")
        let passages = lesson("technique.octaves.passages", "Repeated octaves and octave passages",
                              "Bounce repeated octaves from the wrist and move octaves along a line.", [
            L.info("Repeated octaves", """
            Repeated octaves come from a **light wrist bounce**. Stay close to the keys: lift only as far as the key needs to come back up.

            The moment your forearm starts to burn, stop and shake out. Speed in octaves comes from staying loose, never from pushing harder.
            """, links: [.video("repeated octaves piano wrist bounce")]),
            L.timed("Wrist bounce", "Repeated octaves in eighth notes: eight on C, eight on F, eight on G, then land on C.",
                    AdvKit.oct(Array(repeated.dropLast()), hand: .right, duration: 0.5) + AdvKit.oct([60], hand: .right, duration: 2, start: 12),
                    bpm: 72, display: .staffAndRhythm),
            L.info("Black keys take finger 4", """
            In an octave **passage** the hand travels sideways. To keep the top line smooth, pianists play the upper note of white-key octaves with finger **5** and black-key octaves with finger **4**. The thumb simply slides along underneath.

            The fingering circles on the keyboard show this in the next exercise.
            """, keys: L.keys("Eb4 Eb5", hand: .right, flats: true)),
            L.play("A passage with a black key", "C–D–E♭–F–G and back in octaves. Use 4 on the top of the E♭ octave.",
                   AdvKit.oct(passage, hand: .right), display: .staff, flats: true),
            L.timed("Passage in time", "The same passage in quarter notes.",
                    AdvKit.oct(passage, hand: .right), bpm: 60, display: .staffAndRhythm, flats: true),
            L.timed("Octave bass line", "Left-hand octaves are the foundation of big piano textures. Two on each of C, G, A and F.",
                    AdvKit.oct(bass, hand: .left), bpm: 69, display: .staffAndRhythm),
            L.timed("Octave bass with chords", "Left-hand octaves in half notes, right-hand chords on top.",
                    L.together(L.melody("E4+G4+C5:h G4+B4+D5:h E4+A4+C5:h F4+A4+C5:h E4+G4+C5:w"),
                               AdvKit.oct(AdvKit.n("C2 G2 A2 F2"), hand: .left, duration: 2) + AdvKit.oct([36], hand: .left, duration: 4, start: 8)),
                    bpm: 63, display: .staffAndRhythm),
        ])

        let thirdsUp: [[Int]] = [[60, 64], [62, 65], [64, 67], [65, 69], [67, 71], [69, 72]]
        let thirdsRun: [[Int]] = thirdsUp + thirdsUp.dropLast().reversed()
        let thirdsFing: [[Int]] = [[1, 3], [2, 4], [3, 5], [1, 3], [2, 4], [3, 5], [2, 4], [1, 3], [3, 5], [2, 4], [1, 3]]
        let thirds = lesson("technique.octaves.thirds", "Double notes: thirds",
                            "Two notes in one hand, sounding exactly together.", [
            L.info("Double thirds", """
            **Double notes** are two notes played at once by one hand. In thirds the usual finger pairs are **1–3, 2–4 and 3–5**.

            The challenge is togetherness: both notes must sound at the same instant with no "flam". Prepare both fingers on the key surfaces, then drop them as one unit with a small arm impulse.
            """, keys: L.keys("C4 E4", hand: .right)),
            L.play("Right hand: three pairs", "C–E, D–F, E–G and back, using 1–3, 2–4, 3–5.",
                   L.chords([[60, 64], [62, 65], [64, 67], [62, 65], [60, 64]], fingers: [[1, 3], [2, 4], [3, 5], [2, 4], [1, 3]])),
            L.play("Left hand: three pairs", "The left hand mirrors it: 5–3, 4–2, 3–1.",
                   L.chords([[48, 52], [50, 53], [52, 55], [50, 53], [48, 52]], hand: .left,
                            fingers: [[5, 3], [4, 2], [3, 1], [4, 2], [5, 3]])),
            L.timed("Thirds in time", "Quarter notes, right hand. Listen for both notes landing together.",
                    L.chords([[60, 64], [62, 65], [64, 67], [62, 65], [60, 64], [62, 65], [64, 67], [62, 65]],
                             fingers: [[1, 3], [2, 4], [3, 5], [2, 4], [1, 3], [2, 4], [3, 5], [2, 4]]),
                    bpm: 66, display: .staffAndRhythm),
            L.timed("A scale in thirds", "Up six thirds and back down. After 3–5 the hand shifts and starts again on 1–3.",
                    L.chords(thirdsRun, fingers: thirdsFing), bpm: 60, display: .staffAndRhythm),
            L.timed("Sing the top line", "Same thirds, but make the upper note of each pair a little louder than the lower.",
                    L.chords(thirdsRun, fingers: thirdsFing), bpm: 60, display: .staffAndRhythm,
                    rules: [.voicingTop(minDiff: 6)]),
        ])

        let sixthsRun: [[Int]] = [[64, 72], [65, 74], [67, 76], [69, 77], [67, 76], [65, 74], [64, 72]]
        let sixthsFing: [[Int]] = [[1, 5], [1, 4], [1, 5], [1, 4], [1, 5], [1, 4], [1, 5]]
        let sixths = lesson("technique.octaves.sixths", "Double notes: sixths",
                            "A wider frame: sixths with a loose hand.", [
            L.info("Double sixths", """
            A sixth is a wider frame than a third, played with **1–5** or **1–4**. Alternating 5 and 4 on the top note lets the upper line connect while the thumb slides.

            As with octaves, keep the frame of the hand and move it from the arm. The wrist stays springy.
            """, keys: L.keys("E4 C5", hand: .right)),
            L.play("Right-hand sixths", "E–C, F–D, G–E and back. Alternate 5 and 4 on top.",
                   L.chords([[64, 72], [65, 74], [67, 76], [65, 74], [64, 72]], fingers: [[1, 5], [1, 4], [1, 5], [1, 4], [1, 5]])),
            L.play("Left-hand sixths", "C–A, D–B, E–C and back, with 5–1 and 4–1.",
                   L.chords([[48, 57], [50, 59], [52, 60], [50, 59], [48, 57]], hand: .left,
                            fingers: [[5, 1], [4, 1], [5, 1], [4, 1], [5, 1]])),
            L.timed("Sixths in time", "Quarter notes up and down. Both notes together, every time.",
                    L.chords(sixthsRun, fingers: sixthsFing), bpm: 60, display: .staffAndRhythm),
            L.timed("Melody in sixths", "Make the top note of each sixth sing above the thumb.",
                    L.chords(sixthsRun, fingers: sixthsFing), bpm: 60, display: .staffAndRhythm,
                    rules: [.voicingTop(minDiff: 8)]),
        ])
        return unit("technique.octaves", "Octaves & double notes", [wrist, passages, thirds, sixths])
    }

    // MARK: - Ornaments, repetition, movement

    fileprivate static var advAgilityUnit: CurriculumUnit {
        let trillNotes16: [Int] = Array(repeating: [62, 64], count: 8).flatMap { $0 }
        let trills = lesson("technique.agility.trills", "Trills with even speed",
                            "Build a trill from slow, measured alternation.", [
            L.info("What is a trill?", """
            A **trill** is a rapid alternation between a note and its upper neighbour. A good trill is **even**, not merely fast: every note the same length and the same loudness.

            Use fingers **2–3** (or **1–3** for power). Keep the fingers close to the keys and the hand quiet; a tiny forearm rotation helps. Build speed from measured notes: eighths, then sixteenths.
            """, glyph: "tr", keys: L.keys("D4 E4", hand: .right),
                   example: L.timedTask("Trill", "", L.line(trillNotes16, duration: 0.25) + L.line([62], duration: 2, start: 4),
                                        bpm: 100, display: .staff)),
            L.play("Slow alternation", "D and E with fingers 2 and 3. Small motions; fingers stay touching the keys.",
                   L.line("D4 E4 D4 E4 D4 E4 D4 E4", fingers: "2 3 2 3 2 3 2 3")),
            L.timed("Measured trill: eighths", "Sixteen even eighth notes, then land on D.",
                    AdvKit.cycle(trillNotes16, fingers: [2, 3], durations: [0.5]) + L.line([62], fingers: [2], duration: 2, start: 8),
                    bpm: 84, display: .staffAndRhythm, rules: [.evenVelocity(maxStdDev: 13)]),
            L.timed("Measured trill: sixteenths", "Twice as fast. Stay loose; if it tightens, lower the tempo with the − button.",
                    AdvKit.cycle(trillNotes16, fingers: [2, 3], durations: [0.25]) + L.line([62], fingers: [2], duration: 2, start: 4),
                    bpm: 60, display: .staffAndRhythm, rules: [.evenVelocity(maxStdDev: 14)]),
            L.timed("Trill with 1–3", "The same trill with thumb and third finger, which many pianists find stronger.",
                    AdvKit.cycle(trillNotes16, fingers: [1, 3], durations: [0.25]) + L.line([62], fingers: [1], duration: 2, start: 4),
                    bpm: 66, display: .staffAndRhythm, rules: [.evenVelocity(maxStdDev: 14)]),
            L.timed("Left-hand trill", "C and D in the left hand with fingers 3 and 2.",
                    AdvKit.cycle(Array(repeating: [48, 50], count: 8).flatMap { $0 }, hand: .left, fingers: [3, 2], durations: [0.25])
                        + L.line([48], hand: .left, fingers: [3], duration: 2, start: 4),
                    bpm: 56, display: .staffAndRhythm, rules: [.evenVelocity(maxStdDev: 15)]),
        ])

        let ornaments = lesson("technique.agility.ornaments", "Mordents, turns and grace notes",
                               "Play the common ornaments cleanly and in time.", [
            L.info("Three small ornaments", """
            Ornaments decorate a main note with quick neighbours:

            - **Mordent**: main note, the note below, main note again. (The *upper* mordent uses the note above.)
            - **Turn**: note above, main note, note below, main note.
            - **Grace note**: one very short note squeezed in just before the main note.

            Play them lightly, with fingers close to the keys. The main note is the important one; the ornament should never disturb the beat.
            """),
            L.timed("Upper mordents", "Each beat starts with a quick main–upper–main figure. Keep the beat exactly in place.",
                    L.melody("E4:s:2 F4:s:3 E4:e:2 D4:s:2 E4:s:3 D4:e:2 C4:s:2 D4:s:3 C4:e:2 D4:q:3 C4:w:2"),
                    bpm: 56, display: .staffAndRhythm),
            L.timed("Lower mordents", "Now dip to the note below: main–lower–main.",
                    L.melody("E4:s:3 D4:s:2 E4:e:3 F4:s:3 E4:s:2 F4:e:3 G4:s:3 F4:s:2 G4:e:3 F4:q:2 E4:w:1"),
                    bpm: 56, display: .staffAndRhythm),
            L.timed("Turns", "A turn circles the main note: above, main, below, main.",
                    L.melody("G4:q:3 A4:s:4 G4:s:3 F4:s:2 G4:s:3 E4:q:2 F4:s:3 E4:s:2 D4:s:1 E4:s:2 C4:w:1"),
                    bpm: 56, display: .staffAndRhythm),
            L.timed("Grace notes", "A quick note right before beats 2 and 4, slipping into the main note. The main notes stay on the beat.",
                    L.melody("r:e. D4:s:2 E4:q:3 r:e. F4:s:3 G4:q:4 r:e. D4:s:2 E4:q:3 r:q C4:q:1"),
                    bpm: 66, display: .staffAndRhythm),
        ])

        let rep321: [Int] = Array(repeating: 67, count: 12)
        let rep4321: [Int] = Array(repeating: 64, count: 16)
        let repeatedNotes = lesson("technique.agility.repeated", "Repeated notes with finger changes",
                                   "Change fingers on one key for fast, clean repetition.", [
            L.info("Why change fingers?", """
            Repeating one key quickly with a single finger makes the hand stiff. Instead, pianists **change fingers**: 3–2–1 for groups of three, 4–3–2–1 for groups of four.

            Each finger plays and then slides off toward your palm, clearing the key for the next finger. The hand makes a small scratching motion, staying very close to the key.
            """, keys: L.keys("G4", hand: .right), links: [.video("piano repeated notes changing fingers")]),
            L.play("3–2–1", "Six G's, changing fingers 3–2–1, 3–2–1.",
                   L.line([67, 67, 67, 67, 67, 67], fingers: [3, 2, 1, 3, 2, 1])),
            L.play("4–3–2–1", "Eight E's with 4–3–2–1 twice.",
                   L.line(Array(repeating: 64, count: 8), fingers: [4, 3, 2, 1, 4, 3, 2, 1])),
            L.timed("Triplets with 3–2–1", "Four triplets on G, then land on C. One finger change per note.",
                    AdvKit.cycle(rep321, fingers: [3, 2, 1], durations: [1.0 / 3.0]) + L.line([72], fingers: [5], duration: 2, start: 4),
                    bpm: 66, display: .staffAndRhythm, rules: [.evenVelocity(maxStdDev: 14)]),
            L.timed("Sixteenths with 4–3–2–1", "Four groups of four on E, then land on C.",
                    AdvKit.cycle(rep4321, fingers: [4, 3, 2, 1], durations: [0.25]) + L.line([60], fingers: [1], duration: 2, start: 4),
                    bpm: 60, display: .staffAndRhythm, rules: [.evenVelocity(maxStdDev: 14)]),
            L.timed("Left hand 3–2–1", "The left hand uses the same idea on C.",
                    AdvKit.cycle(Array(repeating: 48, count: 12), hand: .left, fingers: [3, 2, 1], durations: [1.0 / 3.0])
                        + L.line([43], hand: .left, fingers: [5], duration: 2, start: 4),
                    bpm: 60, display: .staffAndRhythm),
        ])

        let stride = "L:C2:5 L:C3+E3+G3:5-3-1 L:G2:5 L:D3+F3+G3:4-2-1 L:C2:5 L:C3+E3+G3:5-3-1 L:G2:5 L:C3+E3+G3:5-3-1"
        let stride2 = "L:C2:5 L:C3+E3+G3:5-3-1 L:F2:5 L:C3+F3+A3:5-2-1 L:G2:5 L:D3+F3+G3:4-2-1 L:C2:5 L:C3+E3+G3:5-3-1"
        let leaps = lesson("technique.agility.leaps", "Leaps and jumps",
                           "Travel fast, arrive early, land accurately.", [
            L.info("How to land a leap", """
            A leap is won before the note sounds:

            - **Look first.** Your eyes go to the target key before your hand leaves.
            - **Move in a low arc**, led by the arm, as soon as the previous note is released.
            - **Arrive early** and touch the target key before playing it. Fast travel, calm landing.

            Practise the move silently first: play the first note, jump, and just touch the target without sounding it.
            """, keys: L.keys("C2 C3 E3 G3", hand: .left), links: [.video("piano leaps accuracy practice")]),
            L.play("Bass note to chord", "Left hand: low bass note, then jump to the chord. Take your time and land on all three notes at once.",
                   AdvKit.seq(stride)),
            L.timed("Stride in time", "The same jumps in slow quarter notes. Leave each bass note early so you can be waiting on the chord.",
                    AdvKit.seq(stride), bpm: 56, display: .rhythm),
            L.play("Right-hand leaps", "Thumb on middle C, fifth finger leaping to higher and higher targets.",
                   L.line("C4 G5 C4 C6 C4 G5 C4 C6", fingers: "1 5 1 5 1 5 1 5"), display: .staff),
            L.timed("Right-hand leaps in time", "Quarter notes. Eyes jump ahead of the hand.",
                    L.line("C4 G5 C4 C6 C4 G5 C4 C6", fingers: "1 5 1 5 1 5 1 5"), bpm: 56, display: .staffAndRhythm),
            L.timed("Accuracy test", "Left-hand stride through four chords. You need 90% of the notes to pass.",
                    AdvKit.seq(stride2), bpm: 60, display: .rhythm, pass: 0.9),
        ])

        let crossArp = "L:C3:5 L:E3:3 L:G3:1 R:C4:1 R:E4:3 R:G4:5 L:C5:2 R:G4:5 R:E4:3 R:C4:1 L:G3:1 L:E3:3 L:C3:5"
        let crossMel = "L:C3:5 R:E4+G4:1-3 L:C5:2 R:E4+G4:1-3 L:C3:5 R:F4+A4:1-3 L:F5:2 R:F4+A4:1-3 "
            + "L:B2:5 R:D4+G4:1-4 L:D5:2 R:D4+G4:1-4 L:C3:5 R:E4+G4:1-3 L:C5:2 R:E4+G4:1-3"
        let crossing = lesson("technique.agility.crossing", "Hand crossing",
                              "Cross one hand over the other without bumping or rushing.", [
            L.info("Crossing over", """
            In **hand crossing** one hand reaches over (or under) the other to play on its far side. It extends an arpeggio or lets one hand play both a bass and a high note around a steady middle part.

            The crossing hand travels **above** the other, with a higher wrist, and starts moving as soon as its last note is released. The hand that stays put keeps low and out of the way.

            On screen, orange keys are still the left hand even when they appear to the right of the blue ones.
            """, keys: L.keys("C3 E3 G3", hand: .left) + L.keys("C4 E4 G4", hand: .right) + [KeyHighlight(midi: 72, label: "LH", hand: .left)]),
            L.play("Arpeggio with a crossing", "Left hand C–E–G, right hand C–E–G, then the **left** hand crosses over to the top C. Come back down the same way.",
                   AdvKit.seq(crossArp)),
            L.timed("Crossing in time", "The same arpeggio in quarter notes. Begin the crossing early so the top C is not late.",
                    AdvKit.seq(crossArp), bpm: 72, display: .rhythm),
            L.timed("Smoother and faster", "Now in eighth notes. The handover from one hand to the other should be inaudible.",
                    AdvKit.seq(crossArp, duration: 0.5), bpm: 66, display: .rhythm, rules: [.evenVelocity(maxStdDev: 15)]),
            L.play("Bass and bell", "Right hand repeats a soft chord in the middle. Left hand alternates a bass note and a high note, crossing over each time.",
                   AdvKit.seq(crossMel)),
            L.timed("Bass and bell in time", "Keep the right hand still and low while the left hand flies over it.",
                    AdvKit.seq(crossMel), bpm: 63, display: .rhythm),
        ])

        let rock: [Int] = Array(repeating: [60, 67], count: 8).flatMap { $0 }
        let rockSixth: [Int] = Array(repeating: [64, 72], count: 8).flatMap { $0 }
        let rockOct: [Int] = Array(repeating: [60, 72], count: 8).flatMap { $0 }
        let rotation = lesson("technique.agility.rotation", "Rotation and the forearm",
                              "Use forearm rotation instead of finger effort for rocking figures.", [
            L.info("Turning the doorknob", """
            **Forearm rotation** is the turning motion you use on a doorknob. When a figure rocks between the thumb side and the little-finger side of the hand, rotation does the work and the fingers only transmit it.

            Let the forearm tip toward the thumb, then toward the fifth finger. The elbow stays quiet and the wrist stays level. It should feel almost lazy.
            """, keys: L.keys("C4 G4", hand: .right), links: [.video("piano forearm rotation technique")]),
            L.checklist("Feel the rotation", "Rest fingers 1 and 5 on C and G and rock slowly between them without playing.", items: [
                "The motion comes from my forearm turning, not from lifting my fingers",
                "My elbow hangs loosely and is not flapping",
                "My wrist stays level and soft",
                "The fingers I am not using stay relaxed",
            ]),
            L.play("Slow rocking", "C and G with fingers 1 and 5. Tip the hand into each note.",
                   L.line("C4 G4 C4 G4 C4 G4 C4 G4", fingers: "1 5 1 5 1 5 1 5")),
            L.timed("Rocking eighths", "Even eighth notes. Thumb notes and fifth-finger notes should be equally loud.",
                    AdvKit.cycle(rock, fingers: [1, 5], durations: [0.5]) + L.line([60], fingers: [1], duration: 2, start: 8),
                    bpm: 84, display: .staffAndRhythm, rules: [.evenVelocity(maxStdDev: 13)]),
            L.timed("Rocking sixths in sixteenths", "A wider rock, E to C, twice as fast.",
                    AdvKit.cycle(rockSixth, fingers: [1, 5], durations: [0.25]) + L.line([64], fingers: [1], duration: 2, start: 4),
                    bpm: 58, display: .staffAndRhythm, rules: [.evenVelocity(maxStdDev: 14)]),
            L.timed("Left-hand rotation", "C and G in the left hand, fingers 5 and 1.",
                    AdvKit.cycle(Array(repeating: [48, 55], count: 8).flatMap { $0 }, hand: .left, fingers: [5, 1], durations: [0.5])
                        + L.line([48], hand: .left, fingers: [5], duration: 2, start: 8),
                    bpm: 80, display: .staffAndRhythm, rules: [.evenVelocity(maxStdDev: 13)]),
            L.timed("Broken octaves", "The widest rock: an octave, in sixteenths. Pure rotation; the fingers hardly move.",
                    AdvKit.cycle(rockOct, fingers: [1, 5], durations: [0.25]) + L.line([60], fingers: [1], duration: 2, start: 4),
                    bpm: 54, display: .staffAndRhythm),
        ])

        let tremChord = String(repeating: "R:E4+G4:1-2 R:C5:5 ", count: 8)
        let tremLH: [ExpectedEvent] = AdvKit.cycle(Array(repeating: [48, 60], count: 8).flatMap { $0 }, hand: .left, fingers: [5, 1], durations: [0.25])
            + AdvKit.cycle(Array(repeating: [43, 55], count: 8).flatMap { $0 }, hand: .left, fingers: [5, 1], durations: [0.25], start: 4)
        let tremolo = lesson("technique.agility.tremolo", "Tremolo",
                             "Sustain sound by rapid rotation between two notes or chord halves.", [
            L.info("What is a tremolo?", """
            A **tremolo** is a fast alternation between two notes that are a third or more apart, or between two halves of a chord. It keeps a sound alive and can swell like an orchestra.

            It is pure **rotation**: the forearm shakes gently while the fingers hold their shape. Start measured (counted sixteenths), then let it become a free shimmer. Stay near the bottom of the keys; you do not need to let them rise fully.
            """, glyph: "trem.", keys: L.keys("C4 C5", hand: .right)),
            L.timed("Octave tremolo", "Right hand, C and C in measured sixteenths.",
                    AdvKit.cycle(rockOct, fingers: [1, 5], durations: [0.25]) + L.line([60], fingers: [1], duration: 2, start: 4),
                    bpm: 63, display: .staffAndRhythm, rules: [.evenVelocity(maxStdDev: 14)]),
            L.timed("Left-hand tremolo", "Octave tremolo in the bass: one bar on C, one bar on G.",
                    tremLH, bpm: 58, display: .staffAndRhythm),
            L.timed("Chord tremolo", "Split the chord: E and G together, then the top C, back and forth.",
                    AdvKit.seq(tremChord, duration: 0.25) + L.chords([[64, 67, 72]], fingers: [[1, 2, 5]], duration: 2, start: 4),
                    bpm: 54, display: .staffAndRhythm),
            L.timed("Crescendo tremolo", "Start soft and grow through the octave tremolo.",
                    AdvKit.cycle(rockOct + rockOct, fingers: [1, 5], durations: [0.25]), bpm: 60, display: .rhythm,
                    rules: [.crescendo]),
            L.timed("Melody over a tremolo", "Left-hand tremolo stays in the background while the right hand plays long melody notes.",
                    L.together(L.melody("E4:h:1 G4:h:3 F4:h:2 D4:h:1"), tremLH), bpm: 54, display: .staffAndRhythm,
                    rules: [.handBalance(melody: .right, minDiff: 8)]),
        ])

        let whitesUp: [Int] = (0...14).map { AdvKit.dia(60, $0) }
        let glissRun: [Int] = AdvKit.n("B4 C5 D5 E5 F5 G5 A5 B5")
        let glissTimed: [ExpectedEvent] = L.chords([[48, 55]], hand: .left, fingers: [[5, 1]], duration: 3)
            + L.line(glissRun, duration: 0.125, start: 3) + L.line([84], duration: 2, start: 4)
        let glissando = lesson("technique.agility.glissando", "Glissando",
                               "Slide across the white keys safely.", [
            L.info("Sliding over the keys", """
            A **glissando** is a slide across many keys with one sweeping motion. On the white keys:

            - **Going up** (right hand): turn the hand over and slide on the **nail** of the third finger, or the nails of 2–3–4 together.
            - **Going down** (right hand): slide on the **thumbnail**.

            Tilt the hand so only nail touches, keep the pressure light, and let the arm pull the hand along. Never drag the soft skin beside the nail: it hurts and can blister.

            The Launchkey's light keys make this easy. The app accepts the keys in order, however you play them.
            """, glyph: "gliss.", links: [.video("how to play a glissando on piano")]),
            L.checklist("Before you slide", "Try a short, slow slide over five keys first.", items: [
                "Only my fingernail touches the keys, not the skin",
                "I am pressing just hard enough to sound the notes",
                "My arm is doing the pulling and my wrist is loose",
                "I will stop if it stings",
            ]),
            L.play("Glissando up", "Slide from middle C up two octaves. Every white key should sound, in order.",
                   L.line(whitesUp), showFingers: false, pass: 0.7),
            L.play("Glissando down", "Now slide back down on the thumbnail.",
                   L.line(Array(whitesUp.reversed())), showFingers: false, pass: 0.7),
            L.timed("Slide into a target", "Left hand holds a chord for three beats. On beat 4 sweep up and land on the top C exactly on the next downbeat.",
                    glissTimed, bpm: 60, display: .rhythm, showFingers: false, pass: 0.6, toleranceMs: 200),
        ])

        return unit("technique.agility", "Ornaments, leaps & rotation",
                    [trills, ornaments, repeatedNotes, leaps, crossing, rotation, tremolo, glissando])
    }

    // MARK: - Voicing, balance, independence

    fileprivate static var advSoundUnit: CurriculumUnit {
        let melodyChords: [[Int]] = [[60, 64, 67], [60, 65, 69], [62, 67, 71], [64, 67, 72]]
        let melodyFing: [[Int]] = [[1, 3, 5], [1, 3, 5], [1, 3, 5], [1, 2, 5]]
        let voicing = lesson("technique.sound.voicing", "Voicing: the melody inside chords",
                             "Make the top note of a chord louder than the rest.", [
            L.info("One hand, two volumes", """
            **Voicing** means playing the notes of one chord at different loudness. Usually the **top note** carries the melody, so it must sing above the others.

            How: lean the weight of the hand toward the finger that plays the top note and make that fingertip firm. The other fingers stay soft and play "from the surface" of the key. Faster key = louder note, so the top finger moves quicker than the rest.

            The app measures this directly: the velocity of the top note compared with the others.
            """, keys: [KeyHighlight(midi: 60, label: "soft", hand: .right), KeyHighlight(midi: 67, label: "LOUD", hand: .right)]),
            L.play("Two notes", "C and G together, four times. Make the G clearly louder than the C.",
                   L.chords(Array(repeating: [60, 67], count: 4), fingers: Array(repeating: [1, 5], count: 4)),
                   rules: [.voicingTop(minDiff: 10)]),
            L.play("Three notes", "A C major triad, four times. Bring out the top G; keep C and E quiet.",
                   L.chords(Array(repeating: [60, 64, 67], count: 4), fingers: Array(repeating: [1, 3, 5], count: 4)),
                   rules: [.voicingTop(minDiff: 10)]),
            L.play("A melody on top", "Four chords whose top notes make a tune: G – A – B – C. Let us hear the tune.",
                   L.chords(melodyChords, fingers: melodyFing), display: .staff, rules: [.voicingTop(minDiff: 12)]),
            L.timed("Voiced chords in time", "The same chords as half notes with the metronome.",
                    L.chords(melodyChords + melodyChords.reversed(), fingers: melodyFing + melodyFing.reversed(), duration: 2),
                    bpm: 66, display: .staffAndRhythm, rules: [.voicingTop(minDiff: 12)]),
            L.info("Other voices", """
            The same skill brings out any voice: a bass line with the left-hand fifth finger, or a tune hidden in the middle of a chord under the thumb. The principle never changes: weight and speed go to the finger that sings; everything else stays light.
            """),
        ])

        let tune = L.melody("E4:q:3 D4:q:2 C4:q:1 D4:q:2 E4:q:3 E4:q:3 E4:h:3 D4:q:2 D4:q:2 D4:h:2 E4:q:3 G4:q:5 G4:h:5")
        let softChords = L.melody("C3+E3+G3:w:5-3-1 C3+E3+G3:w:5-3-1 B2+D3+G3:w:5-3-1 C3+E3+G3:w:5-3-1", hand: .left)
        let lhTune = L.melody("C3:q:5 D3:q:4 E3:q:3 G3:q:1 F3:q:2 E3:q:3 D3:h:4 C3:q:5 E3:q:3 G3:q:1 E3:q:3 C3:w:5", hand: .left)
        let rhSoft = L.melody("r:q E4+G4:q:1-3 r:q E4+G4:q:1-3 r:q D4+G4:q:1-4 r:q D4+G4:q:1-4 r:q E4+G4:q:1-3 r:q E4+G4:q:1-3 E4+G4:w:1-3")
        let albertiNotes: [Int] = AdvKit.alberti([[48, 52, 55], [48, 52, 55], [47, 50, 55], [48, 52, 55]], repeats: 2)
        let balance = lesson("technique.sound.balance", "Balancing the hands",
                             "Melody loud, accompaniment soft.", [
            L.info("Foreground and background", """
            Most piano music has a **melody** and an **accompaniment**. If both hands play equally loud, the tune drowns. Good balance means the melody hand plays about one or two dynamic levels above the other.

            Think of the melody hand as heavy and deep in the keys, the accompanying hand as light and close to the surface. It is harder than it sounds because the hands like to copy each other.
            """),
            L.play("Melody alone: forte", "Right hand only. Play the tune with a full, singing tone.",
                   Array(tune.prefix(8)), display: .staff, rules: [L.f]),
            L.play("Chords alone: piano", "Left hand only. Four soft chords, barely pressed.",
                   L.chords(Array(repeating: [48, 52, 55], count: 4), hand: .left, fingers: Array(repeating: [5, 3, 1], count: 4)),
                   rules: [L.p]),
            L.timed("Together", "Now combine them. The result shows the average loudness of each hand.",
                    L.together(tune, softChords), bpm: 66, display: .staffAndRhythm,
                    rules: [.handBalance(melody: .right, minDiff: 15)]),
            L.timed("Melody in the left hand", "Swap roles: the left hand sings, the right hand taps soft chords off the beat.",
                    L.together(rhSoft, lhTune), bpm: 63, display: .staffAndRhythm,
                    rules: [.handBalance(melody: .left, minDiff: 12)]),
            L.timed("Melody over a busy accompaniment", "An Alberti bass has many more notes than the tune, so it must be even softer.",
                    L.together(L.melody("E4:h:3 G4:h:5 E4:h:3 C4:h:1 D4:h:2 G4:h:5 E4:w:3"),
                               L.line(albertiNotes, hand: .left, fingers: Array(repeating: [5, 1, 3, 1], count: 8).flatMap { $0 }, duration: 0.5)),
                    bpm: 63, display: .staffAndRhythm, rules: [.handBalance(melody: .right, minDiff: 18)]),
        ])

        let legatoLine = "C4 D4 E4 F4 G4 F4 E4 D4"
        let staccLine = "C3 G3 E3 G3 C3 G3 E3 G3"
        let independence = lesson("technique.sound.independence", "Polyphonic independence",
                                  "A different touch in each hand, and two voices in one hand.", [
            L.info("Two things at once", """
            **Polyphonic** music has several independent lines at the same time. Each line needs its own articulation and shape: one hand smooth while the other is detached, or one voice held while another moves.

            The method is always the same: learn each part alone until its touch is automatic, then combine slowly.
            """),
            L.play("Right hand: legato", "Play this line perfectly connected: hold each key until the next one goes down.",
                   L.line(legatoLine, fingers: "1 2 3 4 5 4 3 2"), display: .staff, rules: [.legato]),
            L.play("Left hand: staccato", "Play this line short and bouncy: leave each key at once.",
                   L.line(staccLine, hand: .left, fingers: "5 1 3 1 5 1 3 1"), display: .staff, rules: [.staccato]),
            L.timed("Legato over staccato", "Together, slowly. Right hand stays smooth, left hand stays short. Scored for accuracy; use your ears for the touch.",
                    L.together(L.line(legatoLine, fingers: "1 2 3 4 5 4 3 2"), L.line(staccLine, hand: .left, fingers: "5 1 3 1 5 1 3 1")),
                    bpm: 56, display: .staffAndRhythm),
            L.play("Swap: right hand staccato", "The right-hand line again, now short and detached.",
                   L.line(legatoLine, fingers: "1 2 3 4 5 4 3 2"), display: .staff, rules: [.staccato]),
            L.play("Swap: left hand legato", "And the left-hand line smoothly connected.",
                   L.line(staccLine, hand: .left, fingers: "5 1 3 1 5 1 3 1"), display: .staff, rules: [.legato]),
            L.timed("Staccato over legato", "Together with the roles reversed.",
                    L.together(L.line(legatoLine, fingers: "1 2 3 4 5 4 3 2"), L.line(staccLine, hand: .left, fingers: "5 1 3 1 5 1 3 1")),
                    bpm: 56, display: .staffAndRhythm),
            L.play("Two voices in one hand", "Hold middle C down with your thumb the whole time while fingers 3, 4 and 5 play the upper voice.",
                   AdvKit.seq("R:C4+E4:1-3 R:F4:4 R:G4:5 R:F4:4 R:E4:3 R:F4:4 R:G4:5 R:F4:4 R:E4:3")),
        ])
        return unit("technique.sound", "Voicing, balance & independence", [voicing, balance, independence])
    }

    // MARK: - Speed, stamina, health

    fileprivate static var advPracticeUnit: CurriculumUnit {
        let run: [Int] = Array(AdvKit.run.dropLast())
        let fing: [Int] = Array(AdvKit.runFingers.dropLast())
        let landing = L.line([60], fingers: [1], duration: 1, start: 8)
        let variants = lesson("technique.practice.variants", "Speed building: rhythmic variants",
                              "Practise a fast passage in dotted rhythms to make it secure.", [
            L.info("Why change the rhythm?", """
            To play a passage fast, practise it in **rhythmic variants**. In a long–short rhythm, half the notes are played quickly but each is followed by a rest point where the hand can relax and prepare. Then flip it to short–long so the *other* half gets the fast move.

            After both variants, the even version feels easy. This lesson uses one short passage throughout.
            """, example: L.timedTask("The passage", "", AdvKit.runEvents(duration: 0.25), bpm: 96, display: .staff)),
            L.timed("Even eighths", "First learn the notes: steady eighth notes.",
                    L.line(run, fingers: fing, duration: 0.5) + landing, bpm: 84, display: .staffAndRhythm),
            L.timed("Long – short", "Dotted rhythm: hold the first note of each pair, flick the second into the next.",
                    AdvKit.cycle(run, fingers: fing, durations: [0.75, 0.25]) + landing, bpm: 72, display: .staffAndRhythm),
            L.timed("Short – long", "Reverse it: quick first note, long second note.",
                    AdvKit.cycle(run, fingers: fing, durations: [0.25, 0.75]) + landing, bpm: 72, display: .staffAndRhythm),
            L.timed("Even sixteenths", "Now straight sixteenths. It should feel easier than before.",
                    AdvKit.runEvents(duration: 0.25), bpm: 63, display: .staffAndRhythm, rules: [.evenVelocity(maxStdDev: 14)]),
            L.timed("Push the tempo", "Same passage, faster and with stricter timing. Use the BPM + button to find your clean top speed; the app remembers your best.",
                    AdvKit.runEvents(duration: 0.25), bpm: 80, display: .staffAndRhythm, toleranceMs: 80),
        ])

        // Chunks: four fast notes that land on the next note, then a rest.
        func chunks(_ size: Int) -> [ExpectedEvent] {
            var out: [ExpectedEvent] = []
            var beat = 0.0
            var i = 0
            while i + size < AdvKit.run.count {
                for k in 0..<size {
                    out.append(ExpectedEvent(notes: [NoteSpec(midi: AdvKit.run[i + k], hand: .right, finger: AdvKit.runFingers[i + k])],
                                             beat: beat, duration: 0.25))
                    beat += 0.25
                }
                out.append(ExpectedEvent(notes: [NoteSpec(midi: AdvKit.run[i + size], hand: .right, finger: AdvKit.runFingers[i + size])],
                                         beat: beat, duration: 1))
                beat += 2
                i += size
            }
            return out
        }
        let chunking = lesson("technique.practice.chunking", "Speed building: chunking",
                              "Play short bursts at full speed, then join them.", [
            L.info("Small bursts at full speed", """
            **Chunking** means playing a few notes at the final tempo, landing on the first note of the next group, and stopping. In the stop you relax completely and think ahead.

            Because each chunk is short, you can play it fast and loose from the start. Then make the chunks longer: 4 notes, 8 notes, the whole passage. Always land on the next beat so the chunks overlap.
            """),
            L.timed("Chunks of four", "Four quick notes landing on the fifth, then a full beat of rest. Relax your hand in every rest.",
                    chunks(4), bpm: 72, display: .staffAndRhythm),
            L.timed("Chunks of eight", "Twice as long: eight notes and a landing.",
                    chunks(8), bpm: 72, display: .staffAndRhythm),
            L.timed("The whole passage", "Join the chunks without stopping.",
                    AdvKit.runEvents(duration: 0.25), bpm: 72, display: .staffAndRhythm),
            L.timed("Step the tempo up", "Start here, and each time you pass press BPM + once (4 BPM) and go again. Stop raising it when the playing stops being clean.",
                    AdvKit.runEvents(duration: 0.25), bpm: 80, display: .staffAndRhythm, pass: 0.9, toleranceMs: 80),
        ])

        let five = L.line("C4 D4 E4 F4 G4 F4 E4 D4", fingers: "1 2 3 4 5 4 3 2", duration: 0.5)
        let fiveLH = L.line("C3 D3 E3 F3 G3 F3 E3 D3", hand: .left, fingers: "5 4 3 2 1 2 3 4", duration: 0.5)
        let albertiLong: [Int] = AdvKit.alberti([[48, 52, 55], [48, 53, 57], [47, 50, 55], [48, 52, 55]], repeats: 4)
        let stamina = lesson("technique.practice.stamina", "Stamina and endurance",
                             "Play longer without tightening up.", [
            L.info("Endurance is relaxation", """
            Stamina at the piano is not muscle strength. It is the ability to **keep releasing tension** while you play. A tight forearm tires in seconds; a loose one can play for hours.

            During the long exercises below, keep checking: shoulders down, elbow hanging, wrist soft, breathing normally. If your forearm starts to ache or burn, stop at once, shake out, and restart slower. Never play through pain.
            """),
            L.checklist("Relaxation cues", "Run through these before each long exercise, and again in the middle of it.", items: [
                "Shoulders dropped, not creeping up toward my ears",
                "Jaw and face relaxed; I am breathing out slowly",
                "Wrist level and springy",
                "Fingers that are not playing are resting, not held up in the air",
            ]),
            L.timed("Eight bars, right hand", "A five-finger pattern for eight bars without stopping. Keep the sound even all the way to the end.",
                    L.loop(five, times: 8, length: 4), bpm: 88, display: .rhythm, rules: [.evenVelocity(maxStdDev: 15)]),
            L.timed("Eight bars, left hand", "The same in the left hand.",
                    L.loop(fiveLH, times: 8, length: 4), bpm: 84, display: .rhythm, rules: [.evenVelocity(maxStdDev: 15)]),
            L.timed("Eight bars, hands together", "Both hands in parallel. Do a relaxation check every two bars.",
                    L.loop(L.together(five, fiveLH), times: 8, length: 4), bpm: 76, display: .rhythm),
            L.timed("Long Alberti bass", "Eight bars of Alberti bass. If the thumb side tires, you are pressing instead of rocking.",
                    L.line(albertiLong, hand: .left, fingers: Array(repeating: [5, 1, 3, 1], count: 16).flatMap { $0 }, duration: 0.5),
                    bpm: 92, display: .rhythm, rules: [.evenVelocity(maxStdDev: 15)]),
        ])

        let health = lesson("technique.practice.health", "Injury prevention",
                            "Warm up, take breaks, and recognise warning signs.", [
            L.info("Playing should never hurt", """
            Piano injuries (tendonitis, carpal tunnel problems, focal strain) almost always come from **tension plus repetition**: practising too long, too fast, too loud, with a tight hand.

            The rules are simple:

            - **Warm up** with slow, soft playing before anything demanding.
            - **Take breaks**: about five minutes away from the keys every 25–30 minutes.
            - **Pain means stop.** Tiredness is fine; pain, tingling, numbness or burning is not.
            - Build difficult techniques (octaves, big stretches, fast repetition) **gradually**, a few minutes a day.
            """, links: [.video("pianist warm up and stretches injury prevention")]),
            L.checklist("Warm-up routine", "Do this before each practice session.", items: [
                "Shake out both hands and roll my shoulders for a few seconds",
                "Gently open and close my hands ten times, without forcing any stretch",
                "My hands are warm (run them under warm water if they are cold)",
                "I will start with something slow and soft, not my hardest piece",
            ]),
            L.play("Warm-up: slow and soft", "Five-finger pattern in the right hand, very slowly and softly. Feel each finger sink to the bottom of the key and release.",
                   L.line("C4 D4 E4 F4 G4 F4 E4 D4 C4", fingers: "1 2 3 4 5 4 3 2 1"), rules: [L.p]),
            L.play("Warm-up: left hand", "The same in the left hand, just as soft.",
                   L.line("C3 D3 E3 F3 G3 F3 E3 D3 C3", hand: .left, fingers: "5 4 3 2 1 2 3 4 5"), rules: [L.p]),
            L.checklist("Tension scan", "Play any note and hold it. While it sounds, check each of these.", items: [
                "After the key is down I am not still pressing into it",
                "My thumb is loose, not clamped against my hand",
                "My wrist is neither sagging below the keys nor arched high",
                "My forearm, upper arm and shoulder feel soft",
                "My feet are flat on the floor and my back is tall but not rigid",
            ]),
            L.info("Warning signs", """
            Stop playing for the day and rest if you notice:

            - Sharp or burning pain in the hand, wrist, forearm or elbow
            - Tingling or numbness in the fingers
            - Pain that is still there the next morning

            If symptoms keep returning, see a doctor or physiotherapist, ideally one who works with musicians. A few days of rest early on is far better than months of forced rest later.

            Small hands? Do not force octaves and large chords. Roll them, leave out a note, or play nearer the key edge.
            """),
        ])
        return unit("technique.practice", "Speed, stamina & healthy practice", [variants, chunking, stamina, health])
    }

    // MARK: - Exercise traditions

    fileprivate static var advTraditionsUnit: CurriculumUnit {
        let hanon = lesson("technique.traditions.hanon", "In the style of Hanon",
                           "Sequential five-finger patterns for evenness and endurance.", [
            L.info("Hanon: The Virtuoso Pianist", """
            Charles-Louis Hanon's exercises (1873) repeat one short finger pattern, moving it up a step each bar. They train **evenness, finger independence and stamina**, with both hands doing the same work.

            The first exercise skips a third, climbs by step, and walks back: C–E–F–G–A–G–F–E, then the same from D, from E, and so on. Play it with firm fingertips and a quiet hand. Keep it relaxed: Hanon played with tension does more harm than good.
            """, example: L.timedTask("Hanon pattern", "", AdvKit.hanon(start: 60, bars: 2, hand: .right, duration: 0.25), bpm: 80, display: .staff)),
            L.play("Right hand: two bars", "Learn the shape. Fingers 1–2–3–4–5–4–3–2; note the skip between 1 and 2.",
                   AdvKit.hanon(start: 60, bars: 2, hand: .right, duration: 0.5), display: .staff),
            L.play("Left hand: two bars", "The left hand plays the same notes an octave lower with 5–4–3–2–1–2–3–4.",
                   AdvKit.hanon(start: 48, bars: 2, hand: .left, duration: 0.5), display: .staff),
            L.timed("Right hand: four bars", "Steady eighth notes, rising one step each bar.",
                    AdvKit.hanon(start: 60, bars: 4, hand: .right, duration: 0.5), bpm: 84, display: .staffAndRhythm),
            L.timed("Left hand: four bars", "The same for the left hand.",
                    AdvKit.hanon(start: 48, bars: 4, hand: .left, duration: 0.5), bpm: 80, display: .staffAndRhythm),
            L.timed("Hands together", "Both hands an octave apart, exactly together.",
                    L.together(AdvKit.hanon(start: 60, bars: 4, hand: .right, duration: 0.5),
                               AdvKit.hanon(start: 48, bars: 4, hand: .left, duration: 0.5)),
                    bpm: 72, display: .staffAndRhythm),
            L.timed("In sixteenths, evenly", "Right hand at speed. The score checks that every note has the same weight.",
                    AdvKit.hanon(start: 60, bars: 4, hand: .right, duration: 0.25), bpm: 60, display: .staffAndRhythm,
                    rules: [.evenVelocity(maxStdDev: 12)]),
        ])

        let czScale: [Int] = AdvKit.n("C4 D4 E4 F4 G4 A4 B4 C5 B4 A4 G4 F4 E4 D4 C4 D4")
        let czScaleF: [Int] = [1, 2, 3, 1, 2, 3, 4, 5, 4, 3, 2, 1, 3, 2, 1, 2]
        let czArp: [Int] = AdvKit.n("E4 G4 C5 G4 E4 G4 C5 G4 D4 G4 B4 G4 D4 G4 B4 G4")
        let czArpF: [Int] = [1, 2, 5, 2, 1, 2, 5, 2, 1, 3, 5, 3, 1, 3, 5, 3]
        let czAll: [ExpectedEvent] = L.line(czScale + czArp, fingers: czScaleF + czArpF, duration: 0.25)
            + L.line([60], fingers: [1], duration: 2, start: 8)
        let czLH = L.melody("C3+E3+G3:w:5-3-1 C3+E3+G3:h:5-3-1 B2+D3+G3:h:5-3-1 C3+E3+G3:h:5-3-1", hand: .left)
        let czerny = lesson("technique.traditions.czerny", "In the style of Czerny",
                            "Velocity figures: scale runs and broken chords over simple harmony.", [
            L.info("Czerny: The School of Velocity", """
            Carl Czerny, Beethoven's pupil and Liszt's teacher, wrote thousands of short studies. Unlike Hanon they sound like little pieces: quick **scale runs and broken-chord figures** in the right hand over plain left-hand chords.

            They train **speed with clarity**: light fingers, clean thumb crossings, and a left hand that stays out of the way. This short study is written in that style.
            """, example: L.timedTask("Velocity study", "", L.together(czAll, czLH), bpm: 76, display: .staff)),
            L.play("The scale run", "Up the C major scale and back, with the standard thumb crossing.",
                   L.line(czScale, fingers: czScaleF), display: .staff),
            L.play("The broken-chord figure", "Two bars of broken chords: C major, then G.",
                   L.line(czArp, fingers: czArpF), display: .staff),
            L.timed("Right hand in eighths", "The whole right-hand part at half speed.",
                    L.line(czScale + czArp, fingers: czScaleF + czArpF, duration: 0.5) + L.line([60], fingers: [1], duration: 2, start: 16),
                    bpm: 92, display: .staffAndRhythm),
            L.timed("Right hand in sixteenths", "Now at Czerny speed. Light fingers, no accents on the thumb.",
                    czAll, bpm: 54, display: .staffAndRhythm, rules: [.evenVelocity(maxStdDev: 14)]),
            L.timed("Hands together", "Add the left-hand chords. They are soft punctuation under the running right hand.",
                    L.together(czAll, czLH), bpm: 54, display: .staffAndRhythm,
                    rules: [.handBalance(melody: .right, minDiff: 5)]),
        ])

        let burgRH = L.melody("E4:q:1 G4:q:2 C5:h:5 B4:q:4 A4:q:3 G4:h:2 A4:q:3 F4:q:1 D4:q:1 G4:q:4 E4:w:2")
        let burgLH = L.melody("C3+G3:h:5-1 C3+G3:h:5-1 G2+D3:h:5-1 G2+D3:h:5-1 F2+C3:h:5-1 G2+D3:h:5-1 C3+G3:w:5-1", hand: .left)
        let burgmuller = lesson("technique.traditions.burgmuller", "In the style of Burgmüller",
                                "A short lyrical study: phrasing, dynamics and balance.", [
            L.info("Burgmüller: 25 Easy and Progressive Studies", """
            Friedrich Burgmüller's Op. 100 studies are real character pieces with titles like *Arabesque* and *Innocence*. Each one trains a technical point **through musical expression**: a singing legato, a graceful phrase, clear dynamics.

            This short piece in that spirit is about **shaping a phrase**: grow toward the high point, then relax away from it, with the left hand always softer than the tune.
            """, example: L.timedTask("Lyrical study", "", L.together(burgRH, burgLH), bpm: 84, display: .staff)),
            L.play("Rise: crescendo", "Climb with a crescendo: each note a little louder than the last.",
                   L.line("C4 E4 G4 C5 E5", fingers: "1 2 3 5 5"), display: .staff, rules: [.crescendo]),
            L.play("Fall: diminuendo", "Come down getting softer on every note.",
                   L.line("E5 C5 G4 E4 C4", fingers: "5 3 2 1 1"), display: .staff, rules: [.diminuendo]),
            L.play("The melody, legato", "The right-hand tune, smoothly connected. Fingers shown above the notes.",
                   burgRH, display: .staff, rules: [.legato]),
            L.timed("Melody in time", "Right hand with the metronome, still legato.",
                    burgRH, bpm: 76, display: .staffAndRhythm, rules: [.legato]),
            L.play("Left hand", "Soft open fifths in the left hand.",
                   burgLH, display: .staff, rules: [L.p]),
            L.timed("The whole study", "Hands together. Let the melody sing over a quiet left hand.",
                    L.together(burgRH, burgLH), bpm: 72, display: .staffAndRhythm,
                    rules: [.handBalance(melody: .right, minDiff: 10)]),
        ])

        let pischnaInner = String(repeating: "R:D4:2 R:E4:3 R:F4:4 R:E4:3 ", count: 3)
        let pischnaLH = String(repeating: "L:F3:2 L:E3:3 L:D3:4 L:E3:3 ", count: 3)
        let pischna = lesson("technique.traditions.pischna", "In the style of Pischna",
                             "Held notes: some fingers stay down while others move.", [
            L.info("Pischna: held-note exercises", """
            Josef Pischna's exercises begin with **held notes**: one or two fingers keep their keys down while the others play. This trains **finger independence**, especially the weaker 3rd, 4th and 5th fingers.

            Hold the keys down with almost no pressure; just enough weight to keep them from rising. The moving fingers lift only a little. If the back of your hand starts to feel tight, stop and shake out.

            The app cannot see held keys, so holding them is up to you.
            """, keys: [KeyHighlight(midi: 60, label: "hold", hand: .right), KeyHighlight(midi: 67, label: "hold", hand: .right)]),
            L.play("Thumb held", "Press middle C with your thumb and **keep it down**. Above it, alternate fingers 3 and 4 on E and F.",
                   AdvKit.seq("R:C4:1 R:E4:3 R:F4:4 R:E4:3 R:F4:4 R:E4:3 R:F4:4 R:E4:3")),
            L.play("Thumb and fifth held", "Hold C and G with fingers 1 and 5. Inside that frame, fingers 2–3–4 play D–E–F–E.",
                   AdvKit.seq("R:C4+G4:1-5 " + pischnaInner)),
            L.play("Left hand", "Mirror image: hold C and G with 5 and 1, and play F–E–D–E with fingers 2–3–4–3.",
                   AdvKit.seq("L:C3+G3:5-1 " + pischnaLH)),
            L.timed("Held frame, moving middle", "Play the frame on beat 1 and hold it, then the inner fingers in even eighth notes.",
                    AdvKit.seq("R:C4+G4:1-5", duration: 1) + AdvKit.seq(pischnaInner, duration: 0.5, start: 1),
                    bpm: 66, display: .rhythm, rules: [.evenVelocity(maxStdDev: 16)]),
            L.timed("Left hand in time", "The same for the left hand.",
                    AdvKit.seq("L:C3+G3:5-1", duration: 1) + AdvKit.seq(pischnaLH, duration: 0.5, start: 1),
                    bpm: 63, display: .rhythm, rules: [.evenVelocity(maxStdDev: 16)]),
        ])

        let dohRH = "R:C4+D4+E4+F4+G4:1-2-3-4-5 " + String(repeating: "R:E4:3 ", count: 4) + String(repeating: "R:F4:4 ", count: 4)
            + String(repeating: "R:D4:2 ", count: 4)
        let dohLH = "L:C3+D3+E3+F3+G3:5-4-3-2-1 " + String(repeating: "L:E3:3 ", count: 4) + String(repeating: "L:D3:4 ", count: 4)
            + String(repeating: "L:F3:2 ", count: 4)
        let dohnanyi = lesson("technique.traditions.dohnanyi", "In the style of Dohnányi",
                              "Hold four fingers down and train one at a time.", [
            L.info("Dohnányi: Essential Finger Exercises", """
            Ernő Dohnányi's exercises go a step beyond held notes: **all five fingers** rest on their keys, four hold down, and one finger at a time lifts and plays. They build **strength and independence** in each finger very efficiently.

            They are also demanding, so follow Dohnányi's own advice: a few minutes only, slowly, with a relaxed hand. The fourth finger will not lift far; that is normal anatomy. Do not force it.
            """, keys: L.keys("C4 D4 E4 F4 G4", hand: .right), links: [.video("Dohnanyi essential finger exercises tutorial")]),
            L.checklist("Safety first", "Rest all five fingers on C–D–E–F–G and press them down gently.", items: [
                "The held fingers rest on the key bed without pressing hard",
                "My wrist is level and loose",
                "I will keep this exercise short and stop if my hand tires",
            ]),
            L.play("Right hand", "Press all five keys and **keep them down**. Then lift and play finger 3 four times, finger 4 four times, finger 2 four times, with the others still held.",
                   AdvKit.seq(dohRH)),
            L.play("Left hand", "The same in the left hand: fingers 3, then 4, then 2.",
                   AdvKit.seq(dohLH)),
            L.timed("Right hand in time", "Slow quarter notes. Each repeated note should be the same loudness, even from the fourth finger.",
                    AdvKit.seq(dohRH), bpm: 63, display: .rhythm),
            L.timed("Left hand in time", "The left hand with the metronome.",
                    AdvKit.seq(dohLH), bpm: 63, display: .rhythm),
        ])

        let wideChords: [[Int]] = [[60, 67, 72, 76], [60, 69, 72, 77], [59, 67, 74, 79], [60, 67, 72, 76]]
        var wideNotes: [Int] = []
        for c in wideChords { wideNotes += [c[0], c[1], c[2], c[3], c[2], c[1], c[0], c[1]] }
        let wideFing: [Int] = Array(repeating: [1, 2, 4, 5, 4, 2, 1, 2], count: 4).flatMap { $0 }
        let wideRH: [ExpectedEvent] = L.line(wideNotes, fingers: wideFing, duration: 0.5) + L.line([60], fingers: [1], duration: 2, start: 16)
        let wideLHNotes: [Int] = AdvKit.n("C2 G2 C3 E3 C3 G2 C2 G2 C3 E3 C3 G2 C2 G2 C3 E3")
        let wideLHFing: [Int] = [5, 3, 2, 1, 2, 3, 5, 3, 2, 1, 2, 3, 5, 3, 2, 1]
        let bell = "R:G4:1 R:G6:5 R:A4:1 R:G6:5 R:B4:1 R:G6:5 R:C5:1 R:G6:5 R:B4:1 R:G6:5 R:A4:1 R:G6:5 R:G4:1 R:G6:5"
        let thirdsEtude: [[Int]] = [[60, 64], [62, 65], [64, 67], [65, 69], [64, 67], [62, 65], [60, 64], [62, 65],
                                    [64, 67], [65, 69], [67, 71], [69, 72], [67, 71], [65, 69], [64, 67], [62, 65]]
        let thirdsEtudeF: [[Int]] = [[1, 3], [2, 4], [3, 5], [1, 3], [3, 5], [2, 4], [1, 3], [2, 4],
                                     [3, 5], [1, 3], [2, 4], [3, 5], [2, 4], [1, 3], [3, 5], [2, 4]]
        let etudes = lesson("technique.traditions.etudes", "Étude ideas from Chopin and Liszt",
                            "Simplified versions of three famous étude problems.", [
            L.info("The concert étude", """
            Chopin and Liszt turned the technical study into concert music. Each étude takes **one technical problem** to its limit:

            - Chopin Op. 10 No. 1: arpeggios wider than the hand, so the hand must open, close and rotate.
            - Chopin Op. 25 No. 6: running double thirds.
            - Liszt *La Campanella*: huge right-hand leaps to a repeated high "bell" note.

            The real pieces are years away, but the movements can be practised now in simple form. All three need a loose, travelling arm; none can be played with the fingers alone.
            """),
            L.play("Wide arpeggio: learn the shape", "C–G–C–E covers a tenth. Do not stretch to hold it all: let the hand open and the arm carry it across.",
                   L.line("C4 G4 C5 E5 C5 G4 C4", fingers: "1 2 4 5 4 2 1"), display: .staff),
            L.timed("Wide arpeggios", "Four chords of wide arpeggios in eighth notes. The wrist leads sideways; the hand closes again as it passes.",
                    wideRH, bpm: 66, display: .staffAndRhythm),
            L.timed("Wide arpeggios, left hand", "A wide left-hand figure in the style of Chopin's accompaniments.",
                    L.line(wideLHNotes, hand: .left, fingers: wideLHFing, duration: 0.5) + L.line([36], hand: .left, fingers: [5], duration: 2, start: 8),
                    bpm: 60, display: .staffAndRhythm),
            L.timed("Running thirds", "Double thirds in eighth notes, up and down without a break.",
                    L.chords(thirdsEtude, fingers: thirdsEtudeF, duration: 0.5) + L.chords([[60, 64]], fingers: [[1, 3]], duration: 2, start: 8),
                    bpm: 56, display: .staffAndRhythm),
            L.play("The bell: learn the leap", "Thumb plays a slow melody; the fifth finger leaps two octaves up to the same high G every time.",
                   AdvKit.seq(bell), display: .staff),
            L.timed("The bell in time", "Eighth notes. Look at the high G, not at your thumb: the thumb can find its notes by feel.",
                    AdvKit.seq(bell, duration: 0.5) + L.line([67], fingers: [1], duration: 1, start: 7),
                    bpm: 56, display: .staffAndRhythm, pass: 0.85),
        ])
        return unit("technique.traditions", "Exercise traditions", [hanon, czerny, burgmuller, pischna, dohnanyi, etudes])
    }

    // MARK: - MIDI skill tests

    fileprivate static var advTestsUnit: CurriculumUnit {
        let five = L.line("C4 D4 E4 F4 G4 F4 E4 D4 C4 D4 E4 F4 G4 F4 E4 D4", fingers: "1 2 3 4 5 4 3 2 1 2 3 4 5 4 3 2", duration: 0.5)
        let fiveLH = L.line("C3 D3 E3 F3 G3 F3 E3 D3 C3 D3 E3 F3 G3 F3 E3 D3", hand: .left, fingers: "5 4 3 2 1 2 3 4 5 4 3 2 1 2 3 4", duration: 0.5)
        let scale = L.line(Music.scale(root: 60, type: .major, octaves: 1, descend: true),
                           fingers: [1, 2, 3, 1, 2, 3, 4, 5, 4, 3, 2, 1, 3, 2, 1], duration: 0.5)
        let trill: [Int] = Array(repeating: [62, 64], count: 8).flatMap { $0 }
        let evenness = lesson("technique.tests.evenness", "Test: evenness",
                              "How even is your touch? Measured by velocity variance.", [
            L.info("What this measures", """
            Every key press reports a **velocity** from 1 to 127. An even touch means those numbers barely change from note to note.

            These tests pass only if the velocity spread is **±8 or less**, which is a strict, pianist-level target. The usual culprits are a heavy thumb and a weak fourth finger. Choose any comfortable loudness; only the consistency counts.
            """),
            L.timed("Five fingers, right hand", "Sixteen eighth notes. Aim for identical weight on every note.",
                    five, bpm: 80, display: .staffAndRhythm, rules: [.evenVelocity(maxStdDev: 8)]),
            L.timed("Five fingers, left hand", "The left hand takes the same test.",
                    fiveLH, bpm: 80, display: .staffAndRhythm, rules: [.evenVelocity(maxStdDev: 8)]),
            L.timed("Scale", "One octave of C major up and down. The thumb crossings must not bump.",
                    scale, bpm: 84, display: .staffAndRhythm, rules: [.evenVelocity(maxStdDev: 8)]),
            L.timed("Trill", "A measured sixteenth-note trill with fingers 2 and 3.",
                    AdvKit.cycle(trill, fingers: [2, 3], durations: [0.25]), bpm: 66, display: .staffAndRhythm,
                    rules: [.evenVelocity(maxStdDev: 9)]),
        ])

        var ladder: [Step] = [
            L.info("The speed ladder", """
            The same sixteenth-note passage at five rising tempos. To pass a rung you need **95% of the notes** and an average timing error under **60 ms**: that is what "clean" means here.

            Climb until a rung fails, then go back down one and play it three times well. The app stores the fastest tempo you pass on each step. You can also fine-tune any rung with the BPM buttons.
            """, example: L.timedTask("The passage", "", AdvKit.runEvents(duration: 0.25), bpm: 72, display: .staff)),
        ]
        for bpm in [60.0, 72.0, 84.0, 96.0, 108.0] {
            ladder.append(L.timed("Rung: \(Int(bpm)) BPM", "Sixteenth notes at \(Int(bpm)) beats per minute. Loose hand, fingers close to the keys.",
                                  AdvKit.runEvents(duration: 0.25), bpm: bpm, display: .staffAndRhythm, pass: 0.95, toleranceMs: 60))
        }
        let speed = lesson("technique.tests.speed", "Test: clean speed", "Find the fastest tempo you can play cleanly.", ladder)

        let quarters = Array(repeating: "q", count: 16).joined(separator: " ")
        let eighths = Array(repeating: "e", count: 32).joined(separator: " ")
        let timing = lesson("technique.tests.timing", "Test: timing consistency",
                            "Hold a tempo on your own after the metronome stops.", [
            L.info("Your inner metronome", """
            In these tests the metronome only **counts you in**, then goes silent. You keep the pulse alone.

            Two numbers matter in the result:

            - **Timing** shows how far from the ideal beat you were on average, and whether you drift early (rushing) or late (dragging).
            - **Steadiness** is the spread of your timing. Under 25 ms is very steady.

            Count out loud or tap your foot. Most people rush; if you do, breathe out and think of the space between the beats.
            """),
            L.timed("Sixteen quarter notes", "Any key. Four clicks to count you in, then you are on your own for four bars.",
                    L.rhythm(quarters), bpm: 80, metronome: .countInOnly, display: .rhythm, toleranceMs: 70),
            L.timed("Thirty-two eighth notes", "Any key, eighth notes, four bars with no click.",
                    L.rhythm(eighths), bpm: 76, metronome: .countInOnly, display: .rhythm, toleranceMs: 70),
            L.timed("A scale with no click", "C major up and down in eighth notes. Fingering must not disturb the pulse.",
                    scale, bpm: 84, metronome: .countInOnly, display: .staffAndRhythm, toleranceMs: 70),
            L.timed("Slow is harder", "Quarter notes at a very slow tempo. Long gaps are the real test of an inner pulse.",
                    L.rhythm(Array(repeating: "q", count: 12).joined(separator: " ")), bpm: 50, metronome: .countInOnly,
                    display: .rhythm, toleranceMs: 80),
        ])

        let fourNote: [[Int]] = [[60, 64, 67, 72], [60, 65, 69, 72], [59, 62, 67, 74], [60, 64, 67, 72]]
        let fourFing: [[Int]] = [[1, 2, 3, 5], [1, 2, 4, 5], [1, 2, 3, 5], [1, 2, 3, 5]]
        let triads: [[Int]] = [[60, 64, 67], [60, 65, 69], [62, 67, 71], [64, 67, 72]]
        let voicingTest = lesson("technique.tests.voicing", "Test: voicing",
                                 "Measure how clearly you bring out the top note and the melody hand.", [
            L.info("What this measures", """
            For each chord the app compares the velocity of the **top note** with the average of the notes beneath it. A difference of 10 is audible; **15–20** is a clearly voiced melody.

            Lean toward the fifth finger, firm fingertip on top, soft fingers below.
            """),
            L.play("Triads: top note +18", "Four triads. The top note must be at least 18 louder than the others.",
                   L.chords(triads, fingers: [[1, 3, 5], [1, 3, 5], [1, 3, 5], [1, 2, 5]]), display: .staff,
                   rules: [.voicingTop(minDiff: 18)]),
            L.play("Four-note chords: top note +15", "Fuller chords make it harder to keep the lower notes down.",
                   L.chords(fourNote, fingers: fourFing), display: .staff, rules: [.voicingTop(minDiff: 15)]),
            L.timed("Voicing in time", "The four-note chords as half notes with the metronome.",
                    L.chords(fourNote + fourNote, fingers: fourFing + fourFing, duration: 2), bpm: 66, display: .staffAndRhythm,
                    rules: [.voicingTop(minDiff: 15)]),
            L.timed("Hand balance: melody +20", "Right-hand melody over left-hand chords. The melody hand must average 20 louder.",
                    L.together(L.melody("E4:q:3 D4:q:2 C4:q:1 D4:q:2 E4:q:3 G4:q:5 E4:h:3 D4:q:2 F4:q:4 E4:q:3 D4:q:2 C4:w:1"),
                               L.melody("C3+E3+G3:w:5-3-1 C3+E3+G3:w:5-3-1 B2+D3+G3:w:5-3-1 C3+E3+G3:w:5-3-1", hand: .left)),
                    bpm: 69, display: .staffAndRhythm, rules: [.handBalance(melody: .right, minDiff: 20)]),
        ])
        return unit("technique.tests", "MIDI skill tests", [evenness, speed, timing, voicingTest])
    }
}
