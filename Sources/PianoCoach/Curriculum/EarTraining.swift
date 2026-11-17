import Foundation

// Ear training: the app plays something, the keys stay dark, and the learner plays it back.

fileprivate enum Ear {
    static func pick<T>(_ xs: [T]) -> T { xs[Int.random(in: 0..<xs.count)] }

    static func note(_ midi: Int, at beat: Double, dur: Double = 1) -> ExpectedEvent {
        ExpectedEvent(notes: [NoteSpec(midi: midi, hand: .either)], beat: beat, duration: dur)
    }

    static func chord(_ midis: [Int], at beat: Double, dur: Double = 1) -> ExpectedEvent {
        ExpectedEvent(notes: midis.map { NoteSpec(midi: $0, hand: .either) }, beat: beat, duration: dur)
    }

    static func line(_ midis: [Int], start: Double = 0, step: Double = 1) -> [ExpectedEvent] {
        midis.enumerated().map { i, m in note(m, at: start + Double(i) * step, dur: step) }
    }

    /// A by-ear task: the prompt plays automatically, no keys light up.
    static func task(_ title: String, answer: [ExpectedEvent], prompt: [ExpectedEvent]? = nil,
                     anyOctave: Bool = false) -> PlayTask {
        var t = L.task(title, "", answer, showTargets: false, showFingers: false, anyOctave: anyOctave)
        t.listenFirst = true
        t.prompt = prompt
        return t
    }

    /// A by-ear step outside a quiz (longer answers, so a gentler pass mark).
    static func step(_ title: String, _ instructions: String, answer: [ExpectedEvent],
                     prompt: [ExpectedEvent]? = nil, anyOctave: Bool = false, pass: Double = 0.6) -> Step {
        var t = L.task(title, instructions, answer, showTargets: false, showFingers: false,
                       anyOctave: anyOctave, pass: pass)
        t.listenFirst = true
        t.prompt = prompt
        return .play(t)
    }

    /// Something to listen to inside an info step (keys light up while it plays).
    static func listen(_ events: [ExpectedEvent]) -> PlayTask {
        L.task("Listen", "", events, showFingers: false)
    }

    /// White keys between two MIDI notes, inclusive.
    static func whites(_ low: Int, _ high: Int) -> [Int] {
        (low...high).filter { !Music.isBlack($0) }
    }

    /// A random melody that wanders through `pool` (indices move by at most `leap`).
    static func walk(_ pool: [Int], count: Int, leap: Int, startIndex: Int? = nil) -> [Int] {
        var index = startIndex ?? Int.random(in: 0..<pool.count)
        var out: [Int] = [pool[index]]
        while out.count < count {
            var move = Int.random(in: -leap...leap)
            if move == 0 { move = Bool.random() ? 1 : -1 }
            var next = index + move
            if next < 0 || next >= pool.count { next = index - move }
            next = min(pool.count - 1, max(0, next))
            index = next
            out.append(pool[index])
        }
        return out
    }

    static let intervalNames: [Int: String] = [
        0: "unison", 1: "minor 2nd", 2: "major 2nd", 3: "minor 3rd", 4: "major 3rd", 5: "perfect 4th",
        6: "tritone", 7: "perfect 5th", 8: "minor 6th", 9: "major 6th", 10: "minor 7th", 11: "major 7th",
        12: "octave",
    ]

    static func list(_ intervals: [Int]) -> String {
        intervals.map { intervalNames[$0] ?? "\($0)" }.joined(separator: ", ")
    }

    /// Tonic triad in close position starting on `tonic`.
    static func triad(_ tonic: Int, minor: Bool) -> [Int] { [tonic, tonic + (minor ? 3 : 4), tonic + 7] }

    static func keyName(_ tonic: Int, minor: Bool) -> String {
        let flats = Music.prefersFlats(tonicPC: Music.pc(tonic), minor: minor)
        return Music.name(tonic, flats: flats, octave: false) + (minor ? " minor" : " major")
    }
}

fileprivate extension L {
    /// Same as `L.info`, accepting the example before the keys.
    static func info(_ title: String, _ body: String, example: PlayTask, keys: [KeyHighlight]) -> Step {
        info(title, body, keys: keys, example: example)
    }
}

extension Curriculum {
    static var earTraining: CurriculumSection {
        CurriculumSection(id: "earTraining", title: "Ear Training", symbol: "ear",
                          units: [earPitch, earMotion, earIntervals, earDegrees, earChords, earEcho, earByEar])
    }

    // MARK: - Unit 1: Pitch

    fileprivate static var earPitch: CurriculumUnit {
        let nearWhites = Ear.whites(55, 76)   // G3–E5

        func pairQuiz(maxSteps: Int) -> (Int) -> PlayTask {
            { _ in
                let i = Int.random(in: 5...(nearWhites.count - 6))
                let j = min(nearWhites.count - 1, max(0, i + Int.random(in: -maxSteps...maxSteps)))
                let a = nearWhites[i], b = nearWhites[j]
                return Ear.task("Starts on \(Music.name(a)) — play both notes",
                                answer: Ear.line([a, b]),
                                prompt: [Ear.note(a, at: 0), Ear.note(b, at: 1.5, dur: 1.5)])
            }
        }

        let highLow = lesson("earTraining.pitch.highlow", "Higher, lower or the same?",
                             "The first skill of the ear: hearing which way a note moves.", [
            L.info("What ear training is",
                   "So far the screen has told you what to play. In this section the **sound** tells you. The app plays something, the keys stay dark, and you play it back.\n\nEach by-ear step works the same way:\n\n- The app plays the sound automatically. Press **Hear again** as often as you like.\n- Play your answer. A wrong key flashes red — just try again; the step waits for you.\n- Your score counts the notes you got right **first try**, so listen (and hum!) before you play.\n\nDon't worry about low scores at first. Ears improve quickly with a few minutes of daily practice."),
            L.info("High and low",
                   "**Pitch** is how high or low a note sounds. On the keyboard, higher notes are to the **right** and lower notes to the **left**.\n\nListen: Middle C, then a higher note; Middle C again, then a lower note. A big help is to **sing or hum** the two notes — your voice feels the direction.",
                   example: Ear.listen([Ear.note(60, at: 0), Ear.note(67, at: 1, dur: 1.5), Ear.note(60, at: 3), Ear.note(53, at: 4, dur: 1.5)])),
            L.play("See it and hear it", "Play the lit keys and listen to each move: up, back, down, back, same.",
                   L.line("C4 E4 C4 A3 C4 C4", hand: .either), showFingers: false),
            L.quiz("Up, down or the same?", "You hear two notes. The first one is named; the second is the same note or a close neighbour (white keys only). Play **both**.",
                   rounds: 10, make: pairQuiz(maxSteps: 2)),
            L.quiz("Bigger moves", "The second note can now be further away. Decide the direction first, then how far.",
                   rounds: 10, make: pairQuiz(maxSteps: 5)),
        ])

        func afterC(_ pool: [Int], count: Int) -> (Int) -> PlayTask {
            { _ in
                var targets: [Int] = []
                for _ in 0..<count { targets.append(Ear.pick(pool)) }
                var prompt: [ExpectedEvent] = [Ear.note(60, at: 0)]
                for (i, t) in targets.enumerated() { prompt.append(Ear.note(t, at: 1.5 + Double(i) * 1.2, dur: 1.2)) }
                return Ear.task(count == 1 ? "Middle C, then a mystery note" : "Middle C, then \(count) mystery notes",
                                answer: Ear.line(targets), prompt: prompt)
            }
        }

        let five = Music.notes("C4 D4 E4 F4 G4")
        let match5 = lesson("earTraining.pitch.match5", "Matching notes in C position",
                            "Use Middle C as a reference and find the note you hear.", [
            L.info("A reference note",
                   "Very few people can name a note out of thin air, and you don't need to. Musicians use **relative pitch**: they compare a note to one they already know.\n\nHere the reference is always **Middle C**. You hear C, then a mystery note from the five keys under your right hand in C position: **C D E F G**. Keep your hand there and answer with the right finger.",
                   keys: L.keys(five, labels: ["C", "D", "E", "F", "G"], hand: .right)),
            L.play("Learn the five sounds", "Play C before each note and listen to how far away the note feels. Sing along if you can.",
                   L.line("C4 D4 C4 E4 C4 F4 C4 G4 C4", fingers: "1 2 1 3 1 4 1 5 1")),
            L.quiz("Which of the five?", "You hear Middle C, then one note from C D E F G (it may be C again). Play **only the mystery note**.",
                   rounds: 10, make: afterC(five, count: 1)),
            L.quiz("Two in a row", "After Middle C you hear two mystery notes. Play them in order.",
                   rounds: 8, make: afterC(five, count: 2)),
        ])

        let octaveWhites = Ear.whites(60, 72)
        let matchOctave = lesson("earTraining.pitch.octave", "Matching notes across an octave",
                                 "All eight white keys from Middle C to the C above.", [
            L.info("A wider field",
                   "Now the mystery note can be any white key from Middle C up to the next C. The reference is still Middle C.\n\nTip: notes close to the reference (D, E) feel like small steps; **G** sounds strong and open; the **high C** sounds like the same note, only brighter; **B** leans hard towards that high C.",
                   keys: L.keys(octaveWhites, labels: ["C", "D", "E", "F", "G", "A", "B", "C"])),
            L.play("Learn the eight sounds", "Play C before each note, all the way up.",
                   L.line("C4 D4 C4 E4 C4 F4 C4 G4 C4 A4 C4 B4 C4 C5", hand: .either), showFingers: false),
            L.quiz("Which white key?", "Middle C, then a mystery white key between Middle C and the C above. Play only the mystery note.",
                   rounds: 12, make: afterC(octaveWhites, count: 1)),
            L.quiz("Above or below", "The mystery note can now also be **below** Middle C (down to the G below).",
                   rounds: 12, make: afterC(Ear.whites(55, 72), count: 1)),
        ])

        let blacks = [61, 63, 66, 68, 70]
        let matchBlack = lesson("earTraining.pitch.black", "Black keys by ear",
                                "Hear the notes in the cracks between the white keys.", [
            L.info("The notes in between",
                   "The black keys sit **between** the white ones, a half step from their neighbours. By ear they sound like notes that don't belong to the plain C-major sound — a little surprising or colourful after Middle C.\n\nWhen a mystery note doesn't seem to match any white key, it's a black one: find the white key just below it and move up a half step.",
                   keys: L.keys(blacks, labels: ["C♯ D♭", "D♯ E♭", "F♯ G♭", "G♯ A♭", "A♯ B♭"])),
            L.play("Climb by half steps", "Play every key from Middle C to the next C and hear each half step.",
                   L.line(Array(60...72), hand: .either), showFingers: false),
            L.quiz("Which black key?", "Middle C, then one of the five black keys above it. Play only the mystery note.",
                   rounds: 10, make: afterC(blacks, count: 1)),
            L.quiz("Any of the twelve", "Middle C, then any key — black or white — up to the next C.",
                   rounds: 14, make: afterC(Array(60...72), count: 1)),
        ])

        func hunt(_ pool: [Int], _ range: String) -> (Int) -> PlayTask {
            { _ in
                let target = Ear.pick(pool)
                return Ear.task("Find this note (\(range))", answer: [Ear.note(target, at: 0)],
                                prompt: [Ear.note(target, at: 0, dur: 2)])
            }
        }

        let find = lesson("earTraining.pitch.find", "Finding a note with no reference",
                          "Hum it, hold it, hunt for it.", [
            L.info("Hum, then hunt",
                   "This time there is **no reference note**. You hear one note and have to find it on the keyboard.\n\nThe method singers and guitarists use:\n\n- **Hum** the note and keep humming it\n- Play a key near Middle C and compare: is your hum higher or lower?\n- Move in that direction until the key and your hum melt together\n\nOnly your first try counts towards the score, so low scores are normal here. Each round you finish also gives you a reference for the next — use it."),
            L.play("Practise the method", "Hum each lit note before you play it, and check that the key matches your hum.",
                   L.line("C4 E4 D4 G4 A3 C4", hand: .either), showFingers: false),
            L.quiz("A narrow search", "One note, somewhere from the A below Middle C to the E above it (white keys). Find it.",
                   rounds: 8, make: hunt(Ear.whites(57, 64), "A3 to E4")),
            L.quiz("A wider search", "One note from the G below Middle C to the G above it (white keys).",
                   rounds: 10, make: hunt(Ear.whites(55, 67), "G3 to G4")),
        ])

        return unit("earTraining.pitch", "Pitch", [highLow, match5, matchOctave, matchBlack, find])
    }

    // MARK: - Unit 2: Steps, skips and direction

    fileprivate static var earMotion: CurriculumUnit {
        let pool = Ear.whites(57, 76)     // A3–E5
        let five = Music.notes("C4 D4 E4 F4 G4")

        func run(count: Int, stepSizes: [Int]) -> (Int) -> PlayTask {
            { _ in
                let size = Ear.pick(stepSizes)
                let up = Bool.random()
                let span = size * (count - 1)
                let start = Int.random(in: (up ? 0 : span)...(up ? pool.count - 1 - span : pool.count - 1))
                let notes = (0..<count).map { pool[start + (up ? 1 : -1) * size * $0] }
                return Ear.task("Starts on \(Music.name(notes[0])) — play all \(count) notes",
                                answer: Ear.line(notes), prompt: Ear.line(notes, step: 0.9))
            }
        }

        let direction = lesson("earTraining.motion.direction", "Up or down?",
                               "Hear the direction of a short run of notes.", [
            L.info("Direction",
                   "Melodies are made of motion: notes go **up**, go **down**, or **repeat**. Before worrying about exact notes, train yourself to hear the direction — it removes half the wrong answers at once.\n\nListen: three notes going up by step, then three going down.",
                   example: Ear.listen(Ear.line([60, 62, 64]) + Ear.line([67, 65, 64], start: 4))),
            L.play("Up and down the stairs", "Play the lit keys: three up, three down.",
                   L.line("C4 D4 E4 G4 F4 E4", hand: .either), showFingers: false),
            L.quiz("Three notes by step", "Three notes moving by step (next-door white keys), all up or all down. The first note is named.",
                   rounds: 10, make: run(count: 3, stepSizes: [1])),
            L.quiz("Four notes by step", "Four notes by step, up or down.", rounds: 8, make: run(count: 4, stepSizes: [1])),
        ])

        func pair() -> (Int) -> PlayTask {
            { _ in
                let i = Int.random(in: 2...(pool.count - 3))
                let move = Ear.pick([-2, -1, 1, 2])
                let a = pool[i], b = pool[i + move]
                return Ear.task("Starts on \(Music.name(a)) — step or skip?",
                                answer: Ear.line([a, b]), prompt: [Ear.note(a, at: 0), Ear.note(b, at: 1.2, dur: 1.5)])
            }
        }

        let stepSkip = lesson("earTraining.motion.stepskip", "Step or skip?",
                              "Tell next-door notes from notes that jump over a key.", [
            L.info("Steps and skips",
                   "A **step** moves to the very next white key (C to D). A **skip** jumps over one (C to E).\n\nSteps sound smooth, like walking. Skips sound more open, like the start of a chord. Listen: a step up, then a skip up, both from C.",
                   example: Ear.listen([Ear.note(60, at: 0), Ear.note(62, at: 1, dur: 1.5), Ear.note(60, at: 3), Ear.note(64, at: 4, dur: 1.5)]),
                   keys: L.keys([60, 62, 64], labels: ["C", "step", "skip"])),
            L.play("Compare them", "Step up, skip up, step down, skip down — all from C or back to it.",
                   L.line("C4 D4 C4 E4 E4 D4 E4 C4", hand: .either), showFingers: false),
            L.quiz("Step or skip?", "Two notes: a step or a skip, up or down. The first note is named; play both.",
                   rounds: 12, make: pair()),
            L.quiz("Runs of skips", "Three notes that all move the same way — either all steps or all skips.",
                   rounds: 10, make: run(count: 3, stepSizes: [1, 2])),
        ])

        func fragment(count: Int, leap: Int, inPool notes: [Int]) -> (Int) -> PlayTask {
            { _ in
                let melody = Ear.walk(notes, count: count, leap: leap)
                return Ear.task("Starts on \(Music.name(melody[0]))",
                                answer: Ear.line(melody), prompt: Ear.line(melody, step: 0.9))
            }
        }

        let fragments = lesson("earTraining.motion.fragments", "Echo: three-note shapes",
                               "Short shapes that mix steps and skips.", [
            L.info("Hearing a shape",
                   "Real melodies change direction. A three-note fragment can go up-up, up-down, down-up or down-down, by step or by skip.\n\nListen for the **shape** first — like a tiny mountain or valley — then fill in the exact notes. Everything here stays inside C position (C D E F G).",
                   example: Ear.listen(Ear.line([60, 64, 62]) + Ear.line([67, 64, 65], start: 4)),
                   keys: L.keys(five, labels: ["C", "D", "E", "F", "G"], hand: .right)),
            L.play("Two shapes with the lights on", "A hill (up then down) and a valley (down then up).",
                   L.line("C4 E4 D4 G4 E4 F4", hand: .either), showFingers: false),
            L.quiz("Three-note shapes", "Three notes from C D E F G. The first is named.", rounds: 10,
                   make: fragment(count: 3, leap: 2, inPool: five)),
            L.quiz("Four-note shapes", "Four notes from C D E F G.", rounds: 10,
                   make: fragment(count: 4, leap: 2, inPool: five)),
        ])

        let contours = lesson("earTraining.motion.contours", "Echo: wider contours",
                              "Longer shapes across a full octave.", [
            L.info("Contour",
                   "The overall up-and-down outline of a melody is its **contour**. With a full octave to move in, the shapes get bigger — but the method is the same: direction first, then size (step, skip, or a larger leap), then the notes.",
                   example: Ear.listen(Ear.line([60, 64, 67, 72, 71, 67, 64, 60], step: 0.75))),
            L.play("Trace a contour", "Up through the chord notes, then back down.",
                   L.line("C4 E4 G4 C5 B4 G4 E4 C4", hand: .either), showFingers: false),
            L.quiz("Four notes, one octave", "Four white-key notes between Middle C and the C above, with leaps of up to a 4th.",
                   rounds: 10, make: fragment(count: 4, leap: 3, inPool: Ear.whites(60, 72))),
            L.quiz("Five notes, one octave", "Five notes now.", rounds: 8,
                   make: fragment(count: 5, leap: 3, inPool: Ear.whites(60, 72))),
        ])

        return unit("earTraining.motion", "Steps, skips and direction", [direction, stepSkip, fragments, contours])
    }

    // MARK: - Unit 3: Intervals

    fileprivate static func intervalQuiz(_ intervals: [Int], roots: [Int], descending: Bool? = false) -> (Int) -> PlayTask {
        { _ in
            let size = Ear.pick(intervals)
            let down = descending ?? Bool.random()
            let low = Ear.pick(roots)
            let first = down ? low + size : low
            let second = down ? low : low + size
            let flats = Music.isBlack(first) && down
            return Ear.task("Starts on \(Music.name(first, flats: flats))" + (descending == true ? " — going down" : ""),
                            answer: Ear.line([first, second]),
                            prompt: [Ear.note(first, at: 0), Ear.note(second, at: 1.2, dur: 1.8)])
        }
    }

    fileprivate static func intervalLesson(_ slug: String, _ title: String, _ summary: String,
                                           intervals: [Int], intro: String, memory: String) -> Lesson {
        var demo: [ExpectedEvent] = []
        var guided: [Int] = []
        for (i, size) in intervals.enumerated() {
            demo.append(Ear.note(60, at: Double(i) * 3.5))
            demo.append(Ear.note(60 + size, at: Double(i) * 3.5 + 1, dur: 1.5))
            guided += [60, 60 + size, 65, 65 + size]
        }
        let names = Ear.list(intervals)
        return lesson("earTraining.intervals.\(slug)", title, summary, [
            L.info(title, intro + "\n\nListen to each one starting from Middle C: **\(names)**.",
                   example: Ear.listen(demo),
                   keys: L.keys([60] + intervals.map { 60 + $0 }, labels: ["C"] + intervals.map { Ear.intervalNames[$0] ?? "" })),
            L.info("How to remember them", memory),
            L.play("Play them with the lights on", "Each interval from C, then the same interval from F. Sing the two notes as you play.",
                   L.line(guided, hand: .either), showFingers: false),
            L.quiz("From Middle C", "You hear two notes going up from Middle C. It is one of: \(names). Play both notes.",
                   rounds: 8, make: intervalQuiz(intervals, roots: [60])),
            L.quiz("From any note", "Same intervals, but the starting note changes every round (it is named for you).",
                   rounds: 10, make: intervalQuiz(intervals, roots: Array(55...65))),
            L.quiz("Going down", "Now the second note is **below** the first. Same choices: \(names).",
                   rounds: 8, make: intervalQuiz(intervals, roots: Array(55...65), descending: true)),
        ])
    }

    fileprivate static var earIntervals: CurriculumUnit {
        let seconds = intervalLesson("seconds", "Seconds", "Half steps and whole steps by ear.", intervals: [1, 2],
            intro: "An **interval** is the distance between two notes. The smallest are the **seconds**: next-door notes.\n\n- A **minor 2nd** is a half step — the tightest, most tense interval.\n- A **major 2nd** is a whole step — the sound of walking up a scale.",
            memory: "Link each interval to a tune you already know:\n\n- **Minor 2nd**: the nagging two-note figure that opens Beethoven's *Für Elise* (it rocks down and back up a half step). Think of a creeping, suspenseful sound.\n- **Major 2nd**: the first two different notes of *Happy Birthday* (\"-py birth-\"), or the start of *Frère Jacques*.\n\nIf the two notes sound like they're rubbing against each other, it's minor. If they sound like the first step of a scale, it's major.")

        let thirds = intervalLesson("thirds", "Thirds", "The interval that makes chords sound happy or sad.", intervals: [3, 4],
            intro: "**Thirds** are skips. They are the building blocks of chords, and they carry the mood:\n\n- A **minor 3rd** (3 half steps) sounds darker, sadder.\n- A **major 3rd** (4 half steps) sounds brighter, happier.",
            memory: "- **Minor 3rd**: the first two notes of *Greensleeves*, or the start of Brahms's *Lullaby* (\"Lul-la-by\").\n- **Major 3rd**: the first two notes of *When the Saints Go Marching In* (\"Oh when\"), or of a bugle call.\n\nSing the bottom note, then imagine a major chord growing from it. If the top note fits that bright chord, it's a major 3rd; if it sounds like the sad version, it's minor.")

        let fourFive = intervalLesson("fourths-fifths", "Fourths, fifths and the tritone", "The open, strong intervals — and the restless one between them.",
            intervals: [5, 6, 7],
            intro: "- A **perfect 4th** (5 half steps) sounds strong and announcing.\n- A **perfect 5th** (7 half steps) sounds open and hollow, very stable.\n- The **tritone** (6 half steps) sits exactly between them and sounds restless and unresolved, as if it must move somewhere.",
            memory: "- **Perfect 4th**: *Here Comes the Bride* (\"Here comes\"), or the start of *Amazing Grace* (\"A-ma-\").\n- **Perfect 5th**: *Twinkle, Twinkle, Little Star* — the jump from the first \"twinkle\" to the second.\n- **Tritone**: no comfortable folk tune starts with it, which is itself the clue. If an interval sounds like a 4th or 5th gone sour, it's the tritone.\n\n4th versus 5th is the classic confusion. Sing up the scale from the bottom note: if you arrive on the 4th note (do-re-mi-**fa**) it's a 4th; one more (**sol**) and it's a 5th.")

        let sixths = intervalLesson("sixths", "Sixths", "Wide, warm, song-like leaps.", intervals: [8, 9],
            intro: "**Sixths** are wide, lyrical leaps.\n\n- A **minor 6th** (8 half steps) sounds yearning, a little bittersweet.\n- A **major 6th** (9 half steps) sounds warm and open-hearted.",
            memory: "- **Minor 6th**: in Joplin's *The Entertainer*, the leap up right after the three-note pickup.\n- **Major 6th**: *My Bonnie Lies Over the Ocean* (\"My Bon-\"), or the bell-chime \"N-B-C\" opening leap.\n\nAnother route: a major 6th is a whole step above a perfect 5th; a minor 6th is just a half step above it. Find the 5th in your head, then ask how far beyond it the note sits.")

        let sevenths = intervalLesson("sevenths-octave", "Sevenths and the octave", "The widest intervals inside an octave.", intervals: [10, 11, 12],
            intro: "- A **minor 7th** (10 half steps) sounds bluesy and unfinished — it's the top of a dominant 7th chord.\n- A **major 7th** (11 half steps) is sharp and tense: just a half step short of the octave.\n- An **octave** (12 half steps) is the same note again, higher — the two notes blend almost into one.",
            memory: "- **Octave**: the opening leap of *Somewhere Over the Rainbow* (\"Some-where\").\n- **Major 7th**: sing the octave, then feel the top note sag by a half step. It wants badly to resolve upwards.\n- **Minor 7th**: a whole step short of the octave. It sounds like a question, less harsh than the major 7th.\n\nStrategy: first decide \"is this the same note higher?\" (octave). If not, how badly does the top note want to climb to the octave? Desperately = major 7th. Mildly = minor 7th.")

        func harmonicQuiz(_ intervals: [Int]) -> (Int) -> PlayTask {
            { _ in
                let size = Ear.pick(intervals)
                let low = Int.random(in: 55...65)
                return Ear.task("Lower note: \(Music.name(low)) — play both notes",
                                answer: [Ear.chord([low, low + size], at: 0)],
                                prompt: [Ear.chord([low, low + size], at: 0, dur: 2.5)])
            }
        }

        let harmonic = lesson("earTraining.intervals.harmonic", "Harmonic intervals",
                              "Two notes sounding together.", [
            L.info("Together instead of in turn",
                   "So far the two notes came one after the other (a **melodic** interval). Played **together** they form a **harmonic** interval, and you hear a single blended colour instead of a leap.\n\nRoughly, from smooth to rough:\n\n- **Open and hollow**: octave, perfect 5th, perfect 4th\n- **Sweet**: 3rds and 6ths\n- **Tense, clashing**: 2nds, 7ths and the tritone\n\nA trick: hum the lower note, then slide your hum up until it finds the upper note — you've turned it back into a melodic interval.",
                   example: Ear.listen([Ear.chord([60, 67], at: 0, dur: 1.5), Ear.chord([60, 64], at: 2, dur: 1.5), Ear.chord([60, 61], at: 4, dur: 1.5)])),
            L.play("Hear the colours", "Play each pair together: 5th, major 3rd, minor 3rd, major 2nd, octave.",
                   L.chords("C4 G4, C4 E4, C4 Eb4, C4 D4, C4 C5", hand: .either), showFingers: false),
            L.quiz("3rds and 5ths together", "Two notes at once. The lower note is named; the interval is a minor 3rd, major 3rd or perfect 5th. Play both keys.",
                   rounds: 10, make: harmonicQuiz([3, 4, 7])),
            L.quiz("4ths, 5ths, 6ths and octaves", "Choices: perfect 4th, perfect 5th, minor 6th, major 6th, octave.",
                   rounds: 10, make: harmonicQuiz([5, 7, 8, 9, 12])),
            L.quiz("The clashes", "Choices: minor 2nd, major 2nd, tritone, minor 7th, major 7th.",
                   rounds: 10, make: harmonicQuiz([1, 2, 6, 10, 11])),
            L.quiz("Any harmonic interval", "Everything from a minor 2nd to an octave.", rounds: 12,
                   make: harmonicQuiz(Array(1...12))),
        ])

        let mixed = lesson("earTraining.intervals.mixed", "Interval mix",
                           "All twelve intervals, up and down.", [
            L.info("Putting it together",
                   "Now any interval can appear, going up or down. Work in two passes:\n\n- **Family first**: small (2nds), medium (3rds), open (4th, 5th), wide (6ths), very wide (7ths, octave)\n- **Then the exact one**: within the family, is it the smaller or larger version?\n\nUse your reference tunes, and sing before you play."),
            L.quiz("Up to a 5th, ascending", "Any interval from a minor 2nd to a perfect 5th, going up. The first note is named.",
                   rounds: 12, make: intervalQuiz(Array(1...7), roots: Array(55...65))),
            L.quiz("Up to an octave, ascending", "Any interval up to an octave, going up.",
                   rounds: 12, make: intervalQuiz(Array(1...12), roots: Array(55...62))),
            L.quiz("Up to an octave, descending", "Any interval, going down.",
                   rounds: 12, make: intervalQuiz(Array(1...12), roots: Array(55...62), descending: true)),
            L.quiz("Either direction", "Any interval, up **or** down — you decide which.",
                   rounds: 14, make: intervalQuiz(Array(1...12), roots: Array(55...62), descending: nil)),
        ])

        return unit("earTraining.intervals", "Intervals", [seconds, thirds, fourFive, sixths, sevenths, harmonic, mixed])
    }

    // MARK: - Unit 4: Scale degrees and tonal memory

    fileprivate static func degreeQuiz(tonic: Int, minor: Bool, degrees: [Int], count: Int = 1) -> (Int) -> PlayTask {
        let scale = minor ? [0, 2, 3, 5, 7, 8, 10] : [0, 2, 4, 5, 7, 9, 11]
        return { _ in
            var targets: [Int] = []
            for _ in 0..<count { targets.append(tonic + scale[Ear.pick(degrees) - 1]) }
            var prompt: [ExpectedEvent] = [Ear.chord(Ear.triad(tonic, minor: minor), at: 0, dur: 1.6)]
            for (i, t) in targets.enumerated() { prompt.append(Ear.note(t, at: 2 + Double(i) * 1.1, dur: 1.2)) }
            return Ear.task("Key of \(Ear.keyName(tonic, minor: minor)) — " + (count == 1 ? "which note of the scale?" : "which \(count) notes?"),
                            answer: Ear.line(targets), prompt: prompt, anyOctave: true)
        }
    }

    fileprivate static var earDegrees: CurriculumUnit {
        let cScale = Music.notes("C4 D4 E4 F4 G4 A4 B4")

        let home = lesson("earTraining.degrees.home", "Finding home: the tonic",
                          "Every key has a home note; hear how the others pull towards it.", [
            L.info("The tonic",
                   "In any key one note feels like **home**: the **tonic** (scale degree 1, or *do*). Every other note has its own character measured against it:\n\n- **1 (do)** — home, completely at rest\n- **3 (mi)** — calm and sweet, part of the home chord\n- **5 (sol)** — strong and stable, also part of the home chord\n- **2, 4, 6** — in motion, wanting to step down to 1, 3 and 5\n- **7 (ti)** — restless, pulling up to home\n\nHearing notes as scale degrees, rather than as distances from the previous note, is what lets musicians play melodies by ear in any key.",
                   example: Ear.listen([Ear.chord([60, 64, 67], at: 0, dur: 1.5)] + Ear.line([60, 62, 64, 65, 67, 69, 71, 72], start: 2, step: 0.75)),
                   keys: L.keys(cScale, labels: ["1", "2", "3", "4", "5", "6", "7"])),
            L.play("Feel the pull", "Play each lit note and notice how the active ones resolve: 7 up to 1, 2 down to 1, 4 down to 3, 6 down to 5.",
                   L.line("C4 E4 G4 B4 C5 D4 C4 F4 E4 A4 G4 C4", hand: .either), showFingers: false),
            L.quiz("1, 3 or 5?", "You hear the C major chord, then one note of that chord: C (1), E (3) or G (5). Play it in any octave.",
                   rounds: 10, make: degreeQuiz(tonic: 60, minor: false, degrees: [1, 3, 5])),
            L.quiz("1 to 5", "Now any of the first five notes of the scale: C D E F G.",
                   rounds: 10, make: degreeQuiz(tonic: 60, minor: false, degrees: [1, 2, 3, 4, 5])),
        ])

        let cMajor = lesson("earTraining.degrees.cmajor", "Scale degrees in C major",
                            "All seven degrees, heard against the home chord.", [
            L.info("All seven",
                   "The full set. You'll hear the **C major chord** to plant the key in your ear, then a mystery note from the C major scale.\n\nIf you're stuck, sing the mystery note and then sing **down the scale** until you land on home, counting the steps. With practice you'll recognise each degree's flavour directly.",
                   keys: L.keys(cScale, labels: ["1 do", "2 re", "3 mi", "4 fa", "5 sol", "6 la", "7 ti"])),
            L.play("Sing the numbers", "Play up and down the scale singing \"one, two, three…\".",
                   L.line("C4 D4 E4 F4 G4 A4 B4 C5 B4 A4 G4 F4 E4 D4 C4", hand: .either), showFingers: false),
            L.quiz("Which degree?", "C major chord, then one note of the C major scale. Play it (any octave).",
                   rounds: 12, make: degreeQuiz(tonic: 60, minor: false, degrees: Array(1...7))),
            L.quiz("Two degrees", "After the chord you hear two scale notes. Play them in order.",
                   rounds: 10, make: degreeQuiz(tonic: 60, minor: false, degrees: Array(1...7), count: 2)),
            L.quiz("Three degrees", "Three notes after the chord.", rounds: 8,
                   make: degreeQuiz(tonic: 60, minor: false, degrees: Array(1...7), count: 3)),
        ])

        let otherKeys = lesson("earTraining.degrees.gf", "Scale degrees in G and F",
                               "The same seven flavours, on new keys.", [
            L.info("Degrees travel",
                   "The character of each scale degree is the **same in every key**. Degree 5 sounds as strong in G major (where it's D) as in C major (where it's G). That's why thinking in degrees lets you play one tune in any key.\n\nG major has one black key, **F♯** (degree 7). F major has one black key, **B♭** (degree 4).",
                   keys: L.keys(Music.notes("G3 A3 B3 C4 D4 E4 F#4"), labels: ["1", "2", "3", "4", "5", "6", "7"], hand: .right)),
            L.play("G major and F major", "Play both scales and listen for the same pattern on new keys.",
                   L.line("G3 A3 B3 C4 D4 E4 F#4 G4 F4 G4 A4 Bb4 C5 D5 E5 F5", hand: .either), showFingers: false),
            L.quiz("Degrees in G major", "G major chord, then a note of the G major scale (remember F♯).",
                   rounds: 12, make: degreeQuiz(tonic: 55, minor: false, degrees: Array(1...7))),
            L.quiz("Degrees in F major", "F major chord, then a note of the F major scale (remember B♭).",
                   rounds: 12, make: degreeQuiz(tonic: 53, minor: false, degrees: Array(1...7))),
            L.quiz("Two notes, G or F", "Two scale notes after the chord; the key changes between rounds.", rounds: 10) { round in
                degreeQuiz(tonic: round % 2 == 0 ? 55 : 53, minor: false, degrees: Array(1...7), count: 2)(round)
            },
        ])

        let minorKeys = lesson("earTraining.degrees.minor", "Scale degrees in minor keys",
                               "Home sounds darker; degrees 3, 6 and 7 are lowered.", [
            L.info("Minor home",
                   "In a **minor key** the home chord is a minor triad and three degrees sit a half step lower than in major: **3, 6 and 7**. Home still feels like home — just in a darker room.\n\nThese quizzes use the **natural minor** scale. A minor uses only white keys: A B C D E F G.",
                   example: Ear.listen([Ear.chord([57, 60, 64], at: 0, dur: 1.5)] + Ear.line([57, 59, 60, 62, 64, 65, 67, 69], start: 2, step: 0.75)),
                   keys: L.keys(Music.notes("A3 B3 C4 D4 E4 F4 G4"), labels: ["1", "2", "3", "4", "5", "6", "7"])),
            L.play("A minor, D minor", "Play both natural minor scales.",
                   L.line("A3 B3 C4 D4 E4 F4 G4 A4 D4 E4 F4 G4 A4 Bb4 C5 D5", hand: .either), showFingers: false),
            L.quiz("Degrees in A minor", "A minor chord, then a note of the A natural minor scale.",
                   rounds: 12, make: degreeQuiz(tonic: 57, minor: true, degrees: Array(1...7))),
            L.quiz("Degrees in D minor", "D minor chord, then a note of D natural minor (it has B♭).",
                   rounds: 10, make: degreeQuiz(tonic: 62, minor: true, degrees: Array(1...7))),
            L.quiz("Degrees in E minor", "E minor chord, then a note of E natural minor (it has F♯).",
                   rounds: 10, make: degreeQuiz(tonic: 52, minor: true, degrees: Array(1...7))),
        ])

        func fiveNote() -> (Int) -> PlayTask {
            { _ in
                let tonic = Ear.pick([55, 57, 60, 62, 64, 65])
                let minor = Bool.random()
                let notes = [0, 2, minor ? 3 : 4, 5, 7].map { tonic + $0 }
                return Ear.task("Starts on \(Music.name(tonic)) — five notes up",
                                answer: Ear.line(notes), prompt: Ear.line(notes, step: 0.7))
            }
        }

        func fullScale() -> (Int) -> PlayTask {
            { round in
                let tonic = Ear.pick([55, 57, 60, 62])
                let type: ScaleType = [.major, .naturalMinor, .harmonicMinor][Int.random(in: 0..<3)]
                let notes = Music.scale(root: tonic, type: type)
                return Ear.task("Starts on \(Music.name(tonic)) — eight notes up",
                                answer: Ear.line(notes), prompt: Ear.line(notes, step: 0.6))
            }
        }

        let majorMinor = lesson("earTraining.degrees.majorminor", "Major or minor?",
                                "Hear which kind of scale is being played and play it back.", [
            L.info("One note decides",
                   "Play the first five notes of a major scale, then lower the **third** note by a half step: you now have minor. That single note flips the mood from bright to dark.\n\nListen: C major five-finger pattern, then C minor.",
                   example: Ear.listen(Ear.line([60, 62, 64, 65, 67], step: 0.75) + Ear.line([60, 62, 63, 65, 67], start: 5, step: 0.75)),
                   keys: L.keys([60, 62, 63, 64, 65, 67], labels: ["1", "2", "minor 3", "major 3", "4", "5"])),
            L.play("Bright, then dark", "Major five-finger pattern, then minor, from C and from G.",
                   L.line("C4 D4 E4 F4 G4 C4 D4 Eb4 F4 G4 G3 A3 B3 C4 D4 G3 A3 Bb3 C4 D4", hand: .either), showFingers: false),
            L.quiz("Five notes: major or minor?", "You hear five notes climbing from the named note. Decide whether the third is major or minor, and play all five.",
                   rounds: 10, make: fiveNote()),
            L.info("Three kinds of full scale",
                   "Over a whole octave you'll meet three common scales:\n\n- **Major** — bright all the way up\n- **Natural minor** — dark, with a relaxed whole step at the top\n- **Harmonic minor** — dark, but with a dramatic wide gap before a raised 7th that pulls strongly to the top note\n\nListen for the third note (major or minor?) and then the last two steps.",
                   example: Ear.listen(Ear.line(Music.scale(root: 57, type: .naturalMinor), step: 0.6)
                                       + Ear.line(Music.scale(root: 57, type: .harmonicMinor), start: 6, step: 0.6))),
            L.quiz("Which scale?", "Eight notes up from the named note: major, natural minor or harmonic minor. Play the scale back.",
                   rounds: 8, make: fullScale()),
        ])

        func pattern(keys: [Int], length: Int) -> (Int) -> PlayTask {
            let shapes: [[Int]] = [[1, 2, 3], [3, 2, 1], [1, 3, 5], [5, 3, 1], [1, 2, 3, 1], [3, 4, 5, 3], [5, 4, 3, 2, 1],
                                   [1, 3, 2, 1], [5, 6, 5, 3], [1, 2, 3, 4, 5], [3, 5, 4, 2, 1], [1, 5, 3, 1], [5, 3, 2, 1]]
            let major = [0, 2, 4, 5, 7, 9, 11]
            return { _ in
                let tonic = Ear.pick(keys)
                let options = shapes.filter { $0.count == length || length == 0 }
                let shape = Ear.pick(options.isEmpty ? shapes : options)
                let notes = shape.map { tonic + major[$0 - 1] }
                return Ear.task("Key of \(Ear.keyName(tonic, minor: false)) — starts on \(Music.name(notes[0], flats: Music.prefersFlats(tonicPC: Music.pc(tonic))))",
                                answer: Ear.line(notes),
                                prompt: [Ear.chord(Ear.triad(tonic, minor: false), at: 0, dur: 1.6)] + Ear.line(notes, start: 2, step: 0.8))
            }
        }

        let solfege = lesson("earTraining.degrees.patterns", "Do–re–mi patterns",
                             "Common melodic shapes heard as scale degrees.", [
            L.info("Melodies are made of patterns",
                   "Most tunes are built from a handful of scale-degree shapes: **1-2-3** (do-re-mi), **3-2-1**, **1-3-5** (the chord), **5-4-3-2-1** (walking home).\n\nSingers name the degrees **do re mi fa sol la ti**. Whether you use numbers or syllables, the idea is the same: recognise the pattern, then play it in whatever key you're in.",
                   example: Ear.listen(Ear.line([60, 62, 64], step: 0.8) + Ear.line([60, 64, 67], start: 3, step: 0.8) + Ear.line([67, 65, 64, 62, 60], start: 6, step: 0.8)),
                   keys: L.keys(Music.notes("C4 D4 E4 F4 G4"), labels: ["do", "re", "mi", "fa", "sol"])),
            L.play("Four classic shapes", "1-2-3, 3-2-1, 1-3-5 and 5-4-3-2-1 in C.",
                   L.line("C4 D4 E4 E4 D4 C4 C4 E4 G4 G4 F4 E4 D4 C4", hand: .either), showFingers: false),
            L.quiz("Three-note patterns in C", "You hear the C chord, then a three-note pattern. The first note is named.",
                   rounds: 8, make: pattern(keys: [60], length: 3)),
            L.quiz("Longer patterns in C", "Four- and five-note patterns in C major.", rounds: 10) { round in
                pattern(keys: [60], length: round % 2 == 0 ? 4 : 5)(round)
            },
            L.quiz("Patterns in G, F and D", "The same shapes in other keys. Hear the degrees, not the note names.", rounds: 10,
                   make: pattern(keys: [55, 53, 62], length: 0)),
        ])

        return unit("earTraining.degrees", "Scale degrees and tonal memory", [home, cMajor, otherKeys, minorKeys, majorMinor, solfege])
    }

    // MARK: - Unit 5: Chords

    fileprivate static func chordQuiz(_ types: [ChordType], roots: [Int], broken: Bool, inversions: [Int] = [0]) -> (Int) -> PlayTask {
        { _ in
            let root = Ear.pick(roots)
            let type = Ear.pick(types)
            let inversion = Ear.pick(inversions)
            let notes = Music.chord(root: root, type: type, inversion: inversion)
            var prompt: [ExpectedEvent] = [Ear.chord(notes, at: 0, dur: 2)]
            if broken {
                prompt += Ear.line(notes, start: 2.5, step: 0.6)
                prompt.append(Ear.chord(notes, at: 2.5 + Double(notes.count) * 0.6 + 0.3, dur: 2))
            }
            let flats = Music.prefersFlats(tonicPC: Music.pc(notes[0]))
            let label = inversions == [0] ? "Root: \(Music.name(root, flats: flats))" : "Lowest note: \(Music.name(notes[0], flats: flats))"
            return Ear.task("\(label) — play the chord", answer: [Ear.chord(notes, at: 0)], prompt: prompt)
        }
    }

    fileprivate static var earChords: CurriculumUnit {
        let whiteRoots = [55, 57, 60, 62, 64, 65]
        let allRoots = Array(55...65)

        let majMin = lesson("earTraining.chords.majmin", "Major or minor triad?",
                            "The most useful chord distinction of all.", [
            L.info("Bright and dark",
                   "A **triad** is a three-note chord: root, third, fifth. The outer notes are the same in major and minor — only the **middle note** changes:\n\n- **Major**: bright, settled, happy\n- **Minor**: darker, sadder, more serious\n\nListen: C major, then C minor. Each is played together, then one note at a time.",
                   example: Ear.listen([Ear.chord([60, 64, 67], at: 0, dur: 1.5)] + Ear.line([60, 64, 67], start: 2, step: 0.6)
                                       + [Ear.chord([60, 63, 67], at: 5, dur: 1.5)] + Ear.line([60, 63, 67], start: 7, step: 0.6)),
                   keys: L.keys([60, 63, 64, 67], labels: ["root", "minor 3rd", "major 3rd", "5th"])),
            L.play("Switch the third", "Play C major, C minor, then the same on G and F. Only the middle finger moves.",
                   L.chords("C4 E4 G4, C4 Eb4 G4, G3 B3 D4, G3 Bb3 D4, F3 A3 C4, F3 Ab3 C4", hand: .either), showFingers: false),
            L.quiz("On C: major or minor?", "A chord on C, played together and then broken. Play back all three notes.",
                   rounds: 8, make: chordQuiz([.major, .minor], roots: [60], broken: true)),
            L.quiz("On white-key roots", "The root changes each round and is named for you. Major or minor?",
                   rounds: 10, make: chordQuiz([.major, .minor], roots: whiteRoots, broken: true)),
            L.quiz("Block chords only, any root", "No broken version this time, and the root can be any key.",
                   rounds: 12, make: chordQuiz([.major, .minor], roots: allRoots, broken: false)),
        ])

        let dimAug = lesson("earTraining.chords.dimaug", "Diminished and augmented",
                            "The two unstable triads.", [
            L.info("Squeezed and stretched",
                   "Two more triads complete the set. Both sound **unstable**, as if the music must move on:\n\n- **Diminished** — a minor triad with the fifth **lowered**. Tight, tense, anxious.\n- **Augmented** — a major triad with the fifth **raised**. Strange, floating, dreamlike.\n\nListen: C diminished, then C augmented.",
                   example: Ear.listen([Ear.chord([60, 63, 66], at: 0, dur: 1.5)] + Ear.line([60, 63, 66], start: 2, step: 0.6)
                                       + [Ear.chord([60, 64, 68], at: 5, dur: 1.5)] + Ear.line([60, 64, 68], start: 7, step: 0.6)),
                   keys: L.keys([60, 63, 64, 66, 67, 68], labels: ["root", "m3", "M3", "dim 5", "5th", "aug 5"])),
            L.play("All four on C", "Major, minor, diminished, augmented.",
                   L.chords("C4 E4 G4, C4 Eb4 G4, C4 Eb4 Gb4, C4 E4 G#4", hand: .either), showFingers: false),
            L.quiz("Diminished or augmented?", "Root named; the chord is diminished or augmented. Play it.",
                   rounds: 8, make: chordQuiz([.diminished, .augmented], roots: whiteRoots, broken: true)),
            L.quiz("All four qualities", "Major, minor, diminished or augmented — with the broken version to help.",
                   rounds: 12, make: chordQuiz([.major, .minor, .diminished, .augmented], roots: whiteRoots, broken: true)),
            L.quiz("All four, block only", "Just the block chord, any root.",
                   rounds: 12, make: chordQuiz([.major, .minor, .diminished, .augmented], roots: allRoots, broken: false)),
        ])

        let inversions = lesson("earTraining.chords.inversions", "Inversions by ear",
                                "The same chord with a different note on the bottom.", [
            L.info("Which note is in the bass?",
                   "A triad can be stacked three ways:\n\n- **Root position** — root on the bottom. Solid and grounded.\n- **First inversion** — third on the bottom. Lighter, a little less settled.\n- **Second inversion** — fifth on the bottom. Open, as if waiting to resolve.\n\nThe chord's name doesn't change; its colour does. In these quizzes the **lowest note is named**. Work out the rest by ear: is the gap above the bass note a 3rd or a 4th?",
                   example: Ear.listen([Ear.chord([60, 64, 67], at: 0, dur: 1.5), Ear.chord([64, 67, 72], at: 2, dur: 1.5), Ear.chord([67, 72, 76], at: 4, dur: 1.5)])),
            L.play("C major three ways", "Root position, first inversion, second inversion — then the same for A minor.",
                   L.chords("C4 E4 G4, E4 G4 C5, G4 C5 E5, A3 C4 E4, C4 E4 A4, E4 A4 C5", hand: .either), showFingers: false),
            L.quiz("Major triads, any inversion", "A major triad in root position, first or second inversion. The lowest note is named.",
                   rounds: 10, make: chordQuiz([.major], roots: [55, 57, 60, 62, 53], broken: true, inversions: [0, 1, 2])),
            L.quiz("Major or minor, any inversion", "Now the triad may be minor as well.",
                   rounds: 12, make: chordQuiz([.major, .minor], roots: [55, 57, 60, 62, 53], broken: true, inversions: [0, 1, 2])),
            L.quiz("Block chords only", "No broken version.", rounds: 10,
                   make: chordQuiz([.major, .minor], roots: [55, 57, 60, 62, 53], broken: false, inversions: [0, 1, 2])),
        ])

        let sevenths = lesson("earTraining.chords.sevenths", "Seventh chords",
                              "Major 7th, dominant 7th and minor 7th.", [
            L.info("Four-note chords",
                   "Add one more third on top of a triad and you get a **seventh chord**. Three are everywhere in pop, jazz and musical theatre:\n\n- **Major 7th** (Cmaj7) — a major triad plus a major 7th. Lush, dreamy.\n- **Dominant 7th** (C7) — a major triad plus a minor 7th. Bluesy, pushing forward; it wants to resolve.\n- **Minor 7th** (Cm7) — a minor triad plus a minor 7th. Mellow, smooth.\n\nListen in two steps: is the triad underneath major or minor? Then, for major triads: is the top note sweet and close to the octave (maj7) or bluesy (dominant 7)?",
                   example: Ear.listen([Ear.chord([60, 64, 67, 71], at: 0, dur: 1.8), Ear.chord([60, 64, 67, 70], at: 2.5, dur: 1.8), Ear.chord([60, 63, 67, 70], at: 5, dur: 1.8)])),
            L.play("Three sevenths on C", "Cmaj7, C7, Cm7 — then the same on G.",
                   L.chords("C4 E4 G4 B4, C4 E4 G4 Bb4, C4 Eb4 G4 Bb4, G3 B3 D4 F#4, G3 B3 D4 F4, G3 Bb3 D4 F4", hand: .either), showFingers: false),
            L.quiz("Maj7 or dominant 7?", "Root named. Both have a major triad — listen to the top note.",
                   rounds: 10, make: chordQuiz([.maj7, .dom7], roots: whiteRoots, broken: true)),
            L.quiz("Three kinds of seventh", "Major 7th, dominant 7th or minor 7th.",
                   rounds: 12, make: chordQuiz([.maj7, .dom7, .min7], roots: whiteRoots, broken: true)),
            L.quiz("Block sevenths, any root", "No broken version, any root.",
                   rounds: 12, make: chordQuiz([.maj7, .dom7, .min7], roots: allRoots, broken: false)),
        ])

        // Chord progressions: degree -> (offset from tonic, minor?)
        let chordTable: [Int: (Int, Bool)] = [1: (0, false), 2: (2, true), 4: (5, false), 5: (7, false), 6: (9, true)]
        func triads(_ tonic: Int, _ degrees: [Int]) -> [[Int]] {
            degrees.map { degree in
                let entry = chordTable[degree] ?? (0, false)
                return Ear.triad(tonic + entry.0, minor: entry.1)
            }
        }
        func progressionQuiz(_ options: [[Int]], tonics: [Int], rootsOnly: Bool) -> (Int) -> PlayTask {
            { _ in
                let tonic = Ear.pick(tonics)
                let degrees = Ear.pick(options)
                let chords = triads(tonic, degrees)
                let prompt = chords.enumerated().map { i, c in Ear.chord(c, at: Double(i) * 2, dur: 1.9) }
                let key = Ear.keyName(tonic, minor: false)
                if rootsOnly {
                    return Ear.task("Key of \(key) — play the \(degrees.count) roots",
                                    answer: Ear.line(chords.map { $0[0] }), prompt: prompt, anyOctave: true)
                }
                return Ear.task("Key of \(key) — play the \(degrees.count) chords",
                                answer: chords.enumerated().map { i, c in Ear.chord(c, at: Double(i)) }, prompt: prompt, anyOctave: true)
            }
        }
        let basic: [[Int]] = [[1, 4, 5, 1], [1, 5, 4, 1], [1, 4, 1, 5], [1, 5, 1, 4], [1, 4, 4, 5], [1, 1, 4, 5]]
        let withSix: [[Int]] = basic + [[1, 6, 4, 5], [1, 5, 6, 4], [6, 4, 1, 5], [1, 4, 6, 5], [1, 6, 2, 5]]

        let roots = lesson("earTraining.chords.roots", "Progressions: hearing the bass",
                           "Follow the roots of I, IV and V.", [
            L.info("Three chords run the world",
                   "Thousands of songs use just three chords, built on scale degrees **1, 4 and 5** and written with Roman numerals:\n\n- **I** — home. Rest.\n- **IV** — away from home, open and warm, like setting out.\n- **V** — tension. It leans hard back towards I.\n\nThe easiest way in is to follow the **lowest note** (the root) of each chord. In C major the roots are **C, F and G**.",
                   example: Ear.listen(triads(48, [1, 4, 5, 1]).enumerated().map { i, c in Ear.chord(c, at: Double(i) * 2, dur: 1.9) }),
                   keys: L.keys([48, 53, 55], labels: ["I", "IV", "V"], hand: .left)),
            L.play("I, IV, V, I with the lights on", "Play the chords in C, then just their roots.",
                   L.chords("C3 E3 G3, F3 A3 C4, G3 B3 D4, C3 E3 G3", hand: .left) + L.line("C3 F3 G3 C3", hand: .left, start: 4), showFingers: false),
            L.quiz("Roots in C", "Four chords in C major using I, IV and V. Play the four **root notes** (any octave).",
                   rounds: 8, make: progressionQuiz(basic, tonics: [48], rootsOnly: true)),
            L.quiz("Roots in G and F", "The same in G major (roots G, C, D) and F major (roots F, B♭, C).",
                   rounds: 8, make: progressionQuiz(basic, tonics: [43, 53], rootsOnly: true)),
            L.info("Adding vi and ii",
                   "Two minor chords join the family: **vi** (A minor in C) is the sad cousin of I, and **ii** (D minor in C) often leads to V. The famous pop loop **I–V–vi–IV** uses the first of them.",
                   example: Ear.listen(triads(48, [1, 5, 6, 4]).enumerated().map { i, c in Ear.chord(c, at: Double(i) * 2, dur: 1.9) })),
            L.quiz("Roots with vi and ii", "Progressions may now include the minor chords vi and ii. Keys: C, G, F.",
                   rounds: 10, make: progressionQuiz(withSix, tonics: [48, 43, 53], rootsOnly: true)),
        ])

        let progressions = lesson("earTraining.chords.progressions", "Progressions: playing the chords",
                                  "Hear a four-chord progression and play it back.", [
            L.info("From roots to chords",
                   "Once you can follow the roots, the chords are nearly free: in a major key **I, IV and V are major**, and **ii and vi are minor**. Find the root by ear, then build the triad on it using only notes of the key.\n\nPlay the chords in root position with whichever hand you like; any octave is accepted.",
                   keys: L.keys(Music.notes("C3 E3 G3 F3 A3 C4 G3 B3 D4"), labels: ["I", "", "", "IV", "", "", "V", "", ""], hand: .left)),
            L.play("The five chords of C", "I, ii, IV, V, vi, and home again.",
                   L.chords("C3 E3 G3, D3 F3 A3, F3 A3 C4, G3 B3 D4, A3 C4 E4, C3 E3 G3", hand: .left), showFingers: false),
            L.quiz("I, IV and V in C", "Four chords. Play each one back.", rounds: 8,
                   make: progressionQuiz(basic, tonics: [48], rootsOnly: false)),
            L.quiz("I, IV and V in G and F", "New keys, same three chords.", rounds: 8,
                   make: progressionQuiz(basic, tonics: [43, 53], rootsOnly: false)),
            L.quiz("With the minor chords", "Progressions including vi and ii, in C, G or F.", rounds: 10,
                   make: progressionQuiz(withSix, tonics: [48, 43, 53], rootsOnly: false)),
        ])

        return unit("earTraining.chords", "Chords", [majMin, dimAug, inversions, sevenths, roots, progressions])
    }

    // MARK: - Unit 6: Melodic playback

    fileprivate static func echoQuiz(_ pool: [Int], count: Int, leap: Int, startOn: Int? = nil, step: Double = 0.8) -> (Int) -> PlayTask {
        { _ in
            let melody = Ear.walk(pool, count: count, leap: leap, startIndex: startOn.flatMap { pool.firstIndex(of: $0) })
            let flats = Music.isBlack(melody[0])
            return Ear.task("Starts on \(Music.name(melody[0], flats: flats)) — \(count) notes",
                            answer: Ear.line(melody), prompt: Ear.line(melody, step: step))
        }
    }

    fileprivate static var earEcho: CurriculumUnit {
        let five = Music.notes("C4 D4 E4 F4 G4")
        let gFive = Music.notes("G4 A4 B4 C5 D5")

        let short = lesson("earTraining.echo.short", "Echo: three and four notes",
                           "Hear a tiny melody, hold it in your head, play it back.", [
            L.info("Musical memory",
                   "Playing back a melody needs two things: hearing the moves (which you've practised) and **remembering** them long enough to play.\n\nThe best memory tool is your voice. After the app plays, **sing the melody back** before touching a key. If you can sing it, you can find it.\n\nEverything here is in C position and the first note is always named.",
                   keys: L.keys(five, labels: ["C", "D", "E", "F", "G"], hand: .right)),
            L.play("Warm-up", "Play this little phrase and then sing it from memory.",
                   L.line("E4 D4 C4 D4 E4", fingers: "3 2 1 2 3")),
            L.quiz("Three notes from C", "Three notes, always starting on Middle C.", rounds: 8,
                   make: echoQuiz(five, count: 3, leap: 2, startOn: 60)),
            L.quiz("Three notes from anywhere", "Three notes starting on any of the five.", rounds: 8,
                   make: echoQuiz(five, count: 3, leap: 3)),
            L.quiz("Four notes", "Four notes in C position.", rounds: 10, make: echoQuiz(five, count: 4, leap: 3)),
        ])

        let fiveNotes = lesson("earTraining.echo.five", "Echo: five notes",
                               "Longer phrases in two hand positions.", [
            L.info("Chunking",
                   "Five notes is about the limit of what most people can hold as separate items. So don't: hear the phrase as **one shape** or as two small chunks (for example \"three going up, then two coming back\").",
                   example: Ear.listen(Ear.line([60, 62, 64, 62, 60], step: 0.8))),
            L.quiz("Five notes in C position", "Five notes from C D E F G.", rounds: 10, make: echoQuiz(five, count: 5, leap: 2)),
            L.quiz("Five notes in G position", "Move your right hand up: thumb on the G above Middle C. Notes: G A B C D.", rounds: 8,
                   make: echoQuiz(gFive, count: 5, leap: 2)),
            L.quiz("Six notes", "One more note, back in C position.", rounds: 8, make: echoQuiz(five, count: 6, leap: 2)),
        ])

        let eight = lesson("earTraining.echo.eight", "Echo: eight notes",
                           "A full two-bar phrase.", [
            L.info("Phrases",
                   "Eight notes is a real musical phrase. Listen to it as **two halves** of four notes — a question and an answer — and press **Hear again** freely; even trained musicians need several hearings for longer phrases.\n\nIf you get lost midway, restart from the first note in your head rather than guessing key by key.",
                   example: Ear.listen(Ear.line([60, 62, 64, 62, 64, 65, 67, 64], step: 0.75))),
            L.quiz("Eight notes by step", "Eight notes in C position, moving only by step.", rounds: 6,
                   make: echoQuiz(five, count: 8, leap: 1, step: 0.7)),
            L.quiz("Eight notes with skips", "Steps and skips now.", rounds: 6,
                   make: echoQuiz(five, count: 8, leap: 2, step: 0.7)),
        ])

        let pentaC = Music.notes("C4 D4 E4 G4 A4 C5")
        let blackPenta = Music.notes("F#4 G#4 A#4 C#5 D#5")
        let pentatonic = lesson("earTraining.echo.pentatonic", "Echo: pentatonic melodies",
                                "Five-note-scale tunes, including the black keys.", [
            L.info("The pentatonic sound",
                   "The **major pentatonic** scale leaves out degrees 4 and 7, so there are no half steps and nothing clashes. Folk songs, spirituals and countless pop hooks live in it.\n\nIn C it is **C D E G A**. The five black keys form the same scale starting on F♯ — you can't play a wrong-sounding note on them.",
                   example: Ear.listen(Ear.line([60, 62, 64, 67, 69, 72, 69, 67], step: 0.7)),
                   keys: L.keys(pentaC, labels: ["C", "D", "E", "G", "A", "C"])),
            L.play("C pentatonic", "Up and down the scale. Notice the two wider gaps (E–G and A–C).",
                   L.line("C4 D4 E4 G4 A4 C5 A4 G4 E4 D4 C4", hand: .either), showFingers: false),
            L.quiz("Four pentatonic notes", "Four notes from C D E G A C.", rounds: 8, make: echoQuiz(pentaC, count: 4, leap: 2)),
            L.quiz("Six pentatonic notes", "Six notes.", rounds: 8, make: echoQuiz(pentaC, count: 6, leap: 2)),
            L.quiz("Black-key melodies", "Four or five notes using only the black keys from F♯ up to D♯.", rounds: 8) { round in
                echoQuiz(blackPenta, count: round % 2 == 0 ? 4 : 5, leap: 2)(round)
            },
        ])

        let cOctave = Ear.whites(60, 72)
        let gOctave = Music.scale(root: 55, type: .major)
        let fOctave = Music.scale(root: 53, type: .major)
        let aMinor = Music.scale(root: 57, type: .naturalMinor)
        let fullScale = lesson("earTraining.echo.scale", "Echo: full-scale melodies",
                               "Melodies that roam a whole octave, in several keys.", [
            L.info("The whole scale",
                   "With all seven notes available you now meet the half steps (3–4 and 7–8 in major) that the pentatonic scale avoided. Use everything you've trained: direction, step or skip, scale degrees, and the pull of 7 up to 8 and 4 down to 3.\n\nThe key is given by the first note and the title."),
            L.quiz("C major, five notes", "Five white-key notes between Middle C and the C above.", rounds: 8,
                   make: echoQuiz(cOctave, count: 5, leap: 2)),
            L.quiz("C major, seven notes", "Seven notes.", rounds: 6, make: echoQuiz(cOctave, count: 7, leap: 2, step: 0.7)),
            L.quiz("G major and F major", "Five notes from the G major scale (with F♯) or the F major scale (with B♭), starting on the tonic.", rounds: 8) { round in
                round % 2 == 0 ? echoQuiz(gOctave, count: 5, leap: 2, startOn: 55)(round) : echoQuiz(fOctave, count: 5, leap: 2, startOn: 53)(round)
            },
            L.quiz("A minor", "Five or six notes from A natural minor, starting on A.", rounds: 8) { round in
                echoQuiz(aMinor, count: round % 2 == 0 ? 5 : 6, leap: 2, startOn: 57)(round)
            },
        ])

        func rhythmEcho(_ title: String, _ pattern: String, bpm: Double) -> Step {
            var t = L.timedTask(title, "Listen to the rhythm first (it plays automatically; press **Hear again** to repeat). Then press Start and tap it back on any key with the metronome, **keeping your eyes on your hands, not the timeline**.",
                                L.rhythm(pattern), bpm: bpm, display: .rhythm, showTargets: false)
            t.listenFirst = true
            return .play(t)
        }

        let rhythm = lesson("earTraining.echo.rhythm", "Echo: rhythms",
                            "Clap-back rhythms: listen, remember, tap.", [
            L.info("Rhythm is half of every melody",
                   "A melody is pitches **plus** rhythm, and by-ear playing needs both. A rhythm echo works like a melodic echo: listen, say it back (\"ta, ta, ti-ti, ta\"), then play it.\n\nOne honest limitation: the app has to show the rhythm timeline in order to score your timing, so the answer is on screen. To make this real ear training, **listen with your eyes closed**, then look at your hands — not the timeline — while you tap. Use the timeline afterwards to check yourself."),
            rhythmEcho("Rhythm 1", "q q e e q | q e e h", bpm: 84),
            rhythmEcho("Rhythm 2", "e e q e e q | q q h", bpm: 84),
            rhythmEcho("Rhythm 3", "q. e q q | e e e e h", bpm: 84),
            rhythmEcho("Rhythm 4", "q rq e e q | rq q h", bpm: 84),
            rhythmEcho("Rhythm 5", "e q e q q | q. e h", bpm: 80),
            rhythmEcho("Rhythm 6", "s s s s q e e q | q e e h", bpm: 72),
        ])

        return unit("earTraining.echo", "Melodic playback", [short, fiveNotes, eight, pentatonic, fullScale, rhythm])
    }

    // MARK: - Unit 7: Playing by ear

    fileprivate static func tuneStep(_ title: String, start: String, _ melody: String, hint: String = "") -> Step {
        let events = L.melody(melody, hand: .either)
        return Ear.step(title, "This tune starts on **\(start)**. Listen, sing it, then work it out — the keys stay dark, and a wrong key flashes red. \(hint)",
                        answer: events)
    }

    fileprivate static var earByEar: CurriculumUnit {
        let method = L.info("How to work out a tune",
                            "Playing by ear is detective work, and you now have the tools:\n\n- **Sing it first.** If you can't sing the next note, listen again.\n- **Find the first note** (given here) and the **last note** — tunes usually end on the tonic.\n- **Go one move at a time**: same note, step, skip or leap? Up or down?\n- **Notice repeats.** Most tunes reuse their opening phrase, so half the work is done once.\n\nThese steps are longer than quiz rounds, so the pass mark is gentler. Wrong first tries are part of the process; the goal is fewer of them each time.")

        let fiveFinger = lesson("earTraining.byear.five", "Tunes in five notes",
                                "Familiar melodies that fit under one hand.", [
            method,
            tuneStep("Mary Had a Little Lamb", start: "E4",
                     "E4:q D4:q C4:q D4:q | E4:q E4:q E4:h | D4:q D4:q D4:h | E4:q G4:q G4:h",
                     hint: "Everything is in C position."),
            tuneStep("Ode to Joy", start: "E4",
                     "E4:q E4:q F4:q G4:q | G4:q F4:q E4:q D4:q | C4:q C4:q D4:q E4:q | E4:q. D4:e D4:h",
                     hint: "C position again; it moves almost entirely by step."),
            tuneStep("Hot Cross Buns", start: "E4",
                     "E4:q D4:q C4:h | E4:q D4:q C4:h | C4:e C4:e C4:e C4:e D4:e D4:e D4:e D4:e | E4:q D4:q C4:h"),
            tuneStep("Jingle Bells (chorus)", start: "E4",
                     "E4:q E4:q E4:h | E4:q E4:q E4:h | E4:q G4:q C4:q. D4:e | E4:w",
                     hint: "Lots of repeated notes, then one skip up and a leap down."),
            tuneStep("Frère Jacques (opening)", start: "C4",
                     "C4:q D4:q E4:q C4:q | C4:q D4:q E4:q C4:q | E4:q F4:q G4:h | E4:q F4:q G4:h"),
        ])

        let wider = lesson("earTraining.byear.wider", "Tunes with a wider range",
                           "Melodies that need a leap or a move out of position.", [
            L.info("Leaving the five-finger position",
                   "These tunes span more than five notes, so your hand will have to stretch or move. Listen especially for the **big leaps** — they're the landmarks. Name the interval if you can (the leap in *Twinkle* is a perfect 5th; *Happy Birthday* climbs to an octave)."),
            tuneStep("Twinkle, Twinkle, Little Star", start: "C4",
                     "C4:q C4:q G4:q G4:q | A4:q A4:q G4:h | F4:q F4:q E4:q E4:q | D4:q D4:q C4:h",
                     hint: "One leap up at the start, then it walks home by step."),
            tuneStep("Happy Birthday (first two lines)", start: "G4",
                     "G4:e. G4:s A4:q G4:q C5:q | B4:h G4:e. G4:s | A4:q G4:q D5:q C5:h",
                     hint: "The second line copies the first but reaches one note higher."),
            tuneStep("Amazing Grace (first line)", start: "D4",
                     "D4:q G4:h B4:e G4:e | B4:h A4:q | G4:h E4:q | D4:h",
                     hint: "A pentatonic tune in G: it uses only G A B D E."),
            tuneStep("When the Saints Go Marching In", start: "C4",
                     "C4:q E4:q F4:q G4:w | C4:q E4:q F4:q G4:w | C4:q E4:q F4:q G4:h E4:h | C4:h E4:h D4:w"),
            tuneStep("Row, Row, Row Your Boat (opening)", start: "C4",
                     "C4:q. C4:q. C4:q D4:e E4:q. | E4:q D4:e E4:q F4:e G4:h."),
            tuneStep("London Bridge", start: "G4",
                     "G4:q. A4:e G4:q F4:q | E4:q F4:q G4:h | D4:q E4:q F4:h | E4:q F4:q G4:h"),
        ])

        let newKeys = lesson("earTraining.byear.keys", "The same tune in a new key",
                             "Transposing by ear: the scale degrees stay, the keys change.", [
            L.info("Transposing",
                   "*Mary Had a Little Lamb* is **3-2-1-2-3-3-3** in scale degrees. That's true in every key. To play it in G, find degrees 1, 2 and 3 of G (G, A, B) and play the same numbers.\n\nThis is the real payoff of ear training: you learn a tune once and can play it anywhere. You'll hear each tune in its new key, with only the starting note named.",
                   keys: L.keys(Music.notes("G4 A4 B4"), labels: ["1", "2", "3"], hand: .right)),
            tuneStep("Mary Had a Little Lamb in G", start: "B4",
                     "B4:q A4:q G4:q A4:q | B4:q B4:q B4:h | A4:q A4:q A4:h | B4:q D5:q D5:h"),
            tuneStep("Mary Had a Little Lamb in F", start: "A4",
                     "A4:q G4:q F4:q G4:q | A4:q A4:q A4:h | G4:q G4:q G4:h | A4:q C5:q C5:h"),
            tuneStep("Twinkle in G", start: "G4",
                     "G4:q G4:q D5:q D5:q | E5:q E5:q D5:h | C5:q C5:q B4:q B4:q | A4:q A4:q G4:h"),
            tuneStep("Twinkle in F", start: "F4",
                     "F4:q F4:q C5:q C5:q | D5:q D5:q C5:h | Bb4:q Bb4:q A4:q A4:q | G4:q G4:q F4:h",
                     hint: "F major has one black key."),
            tuneStep("Ode to Joy in D", start: "F♯4",
                     "F#4:q F#4:q G4:q A4:q | A4:q G4:q F#4:q E4:q | D4:q D4:q E4:q F#4:q | F#4:q. E4:e E4:h",
                     hint: "D major uses F♯ (and C♯, though this tune doesn't need it)."),
        ])

        let twinkleMelody = L.melody("C4:q C4:q G4:q G4:q | A4:q A4:q G4:h | F4:q F4:q E4:q E4:q | D4:q D4:q C4:h", hand: .right)
        let twinkleChords = L.melody("C3+E3+G3:w | F3+A3+C4:h C3+E3+G3:h | F3+A3+C4:h C3+E3+G3:h | B2+D3+G3:h C3+E3+G3:h", hand: .left)
        let twinkleRoots = L.melody("C3:w | F3:h C3:h | F3:h C3:h | G3:h C3:h", hand: .left)
        let saintsMelody = L.melody("C4:q E4:q F4:q G4:w | C4:q E4:q F4:q G4:w | C4:q E4:q F4:q G4:h E4:h | C4:h E4:h D4:w", hand: .right)
        let saintsRoots = L.melody("r:q r:q r:q C3:w | r:q r:q r:q C3:w | r:q r:q r:q C3:h C3:h | C3:h C3:h G3:w", hand: .left)

        func whichChord() -> (Int) -> PlayTask {
            let options: [(melody: [Int], root: Int)] = [
                ([60, 64, 67], 48), ([67, 64, 60], 48), ([64, 67, 72], 48), ([72, 67, 64], 48),
                ([65, 69, 72], 53), ([72, 69, 65], 53), ([69, 65, 69], 53), ([65, 69, 65], 53),
                ([67, 71, 74], 55), ([74, 71, 67], 55), ([62, 67, 71], 55), ([71, 74, 71], 55),
            ]
            return { _ in
                let pick = Ear.pick(options)
                let prompt = [Ear.chord(Ear.triad(pick.root, minor: false), at: 0, dur: 3.2)] + Ear.line(pick.melody, start: 0.5, step: 0.9)
                return Ear.task("I (C), IV (F) or V (G)? Play the chord's root", answer: [Ear.note(pick.root, at: 0)],
                                prompt: prompt, anyOctave: true)
            }
        }

        let harmonise = lesson("earTraining.byear.harmonise", "Harmonising with I, IV and V",
                               "Find the chords that fit under a melody.", [
            L.info("Which chord fits?",
                   "To accompany a tune you need to hear which chord belongs under each bar. With only I, IV and V to choose from, there's a simple test: **a chord fits when the important melody notes belong to it.**\n\nIn C major:\n\n- **I = C E G** — fits melody notes C, E, G\n- **IV = F A C** — fits F, A, C\n- **V = G B D** — fits G, B, D\n\nAnd trust your ear: the wrong chord sounds like a clash; the right one makes the melody glow. Tunes almost always **end V → I**.",
                   keys: L.keys(Music.notes("C3 E3 G3 F3 A3 C4 G3 B3 D4"), labels: ["I", "", "", "IV", "", "", "V", "", ""], hand: .left)),
            L.play("The three chords", "Left hand: I, IV, I, V, I in C major.",
                   L.chords("C3 E3 G3, F3 A3 C4, C3 E3 G3, G3 B3 D4, C3 E3 G3", hand: .left), showFingers: false),
            L.quiz("Which chord is under the melody?", "You hear three melody notes over a chord. Play the **root** of the chord: C, F or G.",
                   rounds: 12, make: whichChord()),
            L.info("Twinkle, harmonised",
                   "Here is *Twinkle, Twinkle* with its chords. Listen to how the harmony changes: home (I), away (IV), home, away, home, tension (V), home.",
                   example: L.task("Listen", "", L.together(twinkleMelody, twinkleChords), display: .staff, showFingers: false)),
            L.play("Guided: melody and roots", "Right hand plays the tune, left hand plays just the root of each chord. The keys light up this time.",
                   L.together(twinkleMelody, twinkleRoots), display: .staff, showFingers: false),
            Ear.step("By ear: the roots under Twinkle", "Now the keys are dark. You hear the tune with its chords; play **only the bass notes** (seven of them: C, F or G each time), in order.",
                     answer: twinkleRoots.map { e in var e = e; e.notes = e.notes.map { NoteSpec(midi: $0.midi, hand: .either) }; return e },
                     prompt: L.together(twinkleMelody, twinkleChords), anyOctave: true),
            L.play("Guided: melody and chords", "Both hands, full chords in the left.",
                   L.together(twinkleMelody, twinkleChords), display: .staff, showFingers: false),
            Ear.step("By ear: the roots under When the Saints", "A new tune. Listen to the melody with its bass line, then play the bass notes back (they are all C or G). The bass enters on the long notes.",
                     answer: saintsRoots.map { e in var e = e; e.notes = e.notes.map { NoteSpec(midi: $0.midi, hand: .either) }; return e },
                     prompt: L.together(saintsMelody, saintsRoots), anyOctave: true),
        ])

        return unit("earTraining.byear", "Playing by ear", [fiveFinger, wider, newKeys, harmonise])
    }
}
