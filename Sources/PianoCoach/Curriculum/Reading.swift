import Foundation

// Section 3 — Reading Music.
// Reading tasks show notation with the key lights OFF, so the learner has to read.

fileprivate enum R {
    static var lastCard = -1

    static func pick<T>(_ items: [T]) -> T { items[Int.random(in: 0..<items.count)] }

    /// A random element that differs from the previous flashcard.
    static func fresh(_ pool: [Int]) -> Int {
        guard pool.count > 1 else { return pool.first ?? 60 }
        var n = pick(pool)
        var guardCount = 0
        while n == lastCard && guardCount < 8 { n = pick(pool); guardCount += 1 }
        lastCard = n
        return n
    }

    static func whites(_ lo: Int, _ hi: Int) -> [Int] { (lo...hi).filter { !Music.isBlack($0) } }

    /// Notes of a major scale (by tonic pitch class) inside a range.
    static func scalePool(_ tonicPC: Int, _ lo: Int, _ hi: Int) -> [Int] {
        let pcs = Set(ScaleType.major.intervals.map { (tonicPC + $0) % 12 })
        return (lo...hi).filter { pcs.contains(Music.pc($0)) }
    }

    static func labeled(_ events: [ExpectedEvent], flats: Bool = false) -> [ExpectedEvent] {
        events.map { event in
            var e = event
            e.label = event.notes.map { Music.name($0.midi, flats: flats, octave: false) }.joined(separator: " ")
            return e
        }
    }

    /// One note per event; notes below middle C go to the left hand (bass staff).
    static func byPitch(_ notes: [Int], duration: Double = 1) -> [ExpectedEvent] {
        notes.enumerated().map { i, n in
            ExpectedEvent(notes: [NoteSpec(midi: n, hand: n < 60 ? .left : .right)],
                          beat: Double(i) * duration, duration: duration)
        }
    }

    static func hand(for clef: ClefMode, _ midi: Int) -> Hand {
        switch clef {
        case .bass: return .left
        case .treble: return .right
        default: return midi < 60 ? .left : .right
        }
    }

    /// Untimed reading task: notation shown, keys not lit.
    static func read(_ title: String, _ instructions: String, _ events: [ExpectedEvent],
                     clef: ClefMode = .auto, key: Int = 0, flats: Bool = false, targets: Bool = false,
                     rules: [Rule] = [], pass: Double = 0.8) -> Step {
        L.play(title, instructions, events, display: .staff, clef: clef, key: key, flats: flats,
               showTargets: targets, rules: rules, pass: pass)
    }

    /// Timed reading task: the metronome keeps going, so there is no stopping.
    static func readTimed(_ title: String, _ instructions: String, _ events: [ExpectedEvent],
                          bpm: Double = 66, meter: (Int, Int) = (4, 4), clef: ClefMode = .auto,
                          key: Int = 0, flats: Bool = false, rules: [Rule] = [], pass: Double = 0.75) -> Step {
        L.timed(title, instructions, events, bpm: bpm, meter: meter, display: .staff, clef: clef, key: key,
                flats: flats, showTargets: false, rules: rules, pass: pass, toleranceMs: 130)
    }

    static func example(_ events: [ExpectedEvent], clef: ClefMode = .auto, key: Int = 0, flats: Bool = false) -> PlayTask {
        L.task("Example", "", events, display: .staff, clef: clef, key: key, flats: flats)
    }

    static func timedExample(_ events: [ExpectedEvent], bpm: Double = 72, meter: (Int, Int) = (4, 4),
                             clef: ClefMode = .auto, key: Int = 0, flats: Bool = false) -> PlayTask {
        L.timedTask("Example", "", events, bpm: bpm, meter: meter, display: .staff, clef: clef, key: key, flats: flats)
    }

    /// A staff flashcard with one or more notes played one after another.
    static func card(_ notes: [Int], clef: ClefMode, key: Int = 0, flats: Bool = false,
                     title: String = "Play this note") -> PlayTask {
        let events = notes.enumerated().map { i, n in
            ExpectedEvent(notes: [NoteSpec(midi: n, hand: hand(for: clef, n))], beat: Double(i), duration: 1)
        }
        return L.task(title, "", events, display: .staff, clef: clef, key: key, flats: flats, showTargets: false)
    }

    /// A prompt with no notation and no lit keys; the learner works out the notes.
    static func prompt(_ title: String, _ notes: [Int], anyOctave: Bool = false) -> PlayTask {
        L.task(title, "", L.line(notes), display: .keyboard, showTargets: false, anyOctave: anyOctave)
    }

    /// A random melodic walk through `pool` using the given rhythm.
    static func phrase(_ pool: [Int], _ rhythm: String, hand: Hand = .right, maxLeap: Int = 1,
                       start: Double = 0, endOn: Int? = nil) -> [ExpectedEvent] {
        guard !pool.isEmpty else { return [] }
        var beat = start
        var index = Int.random(in: 0..<pool.count)
        var out: [ExpectedEvent] = []
        for token in rhythm.split(separator: " ") where token != "|" {
            let d = L.dur(String(token))
            if !d.rest {
                out.append(ExpectedEvent(notes: [NoteSpec(midi: pool[index], hand: hand)], beat: beat, duration: d.beats))
                var delta = Int.random(in: 1...max(1, maxLeap)) * (Bool.random() ? 1 : -1)
                if index + delta < 0 || index + delta >= pool.count { delta = -delta }
                index = min(pool.count - 1, max(0, index + delta))
            }
            beat += d.beats
        }
        if let endOn, !out.isEmpty {
            out[out.count - 1].notes = [NoteSpec(midi: endOn, hand: hand)]
        }
        return out
    }

    /// A marking below the staff (dynamics, hairpins, pedal).
    static func below(_ beat: Double, _ text: String) -> StaffMarker { StaffMarker(beat: beat, text: text, below: true) }

    /// A marking above the staff (road-map words, endings, octave signs, chord symbols).
    static func above(_ beat: Double, _ text: String) -> StaffMarker { StaffMarker(beat: beat, text: text) }

    /// Add notation extras to a task: markers, repeat signs and slurs (pairs of event indices).
    static func mark(_ task: PlayTask, markers: [StaffMarker] = [], repeats: [RepeatSpan] = [],
                     slurs: [(Int, Int)] = []) -> PlayTask {
        var t = task
        t.markers += markers
        t.repeats += repeats
        for (a, b) in slurs where a < t.events.count && b < t.events.count {
            t.events[a].slurStart = true
            t.events[b].slurEnd = true
        }
        return t
    }

    static func mark(_ step: Step, markers: [StaffMarker] = [], repeats: [RepeatSpan] = [],
                     slurs: [(Int, Int)] = []) -> Step {
        guard case .play(let task) = step else { return step }
        return .play(mark(task, markers: markers, repeats: repeats, slurs: slurs))
    }

    /// Notes "as written" with an ornament sign on each one.
    static func ornamented(_ spec: String, _ ornament: Ornament, start: Double = 0) -> [ExpectedEvent] {
        L.melody(spec, start: start).map { var e = $0; e.ornament = ornament; return e }
    }

    static func chordName(_ rootPC: Int, _ type: ChordType) -> String {
        let flats = Music.prefersFlats(tonicPC: rootPC, minor: type == .minor || type == .min7)
        return (flats ? Music.flatNames : Music.sharpNames)[rootPC] + type.symbol
    }

    /// Chord-symbol flashcard: any octave and any inversion is accepted.
    static func chordCard(_ rootPC: Int, _ type: ChordType) -> PlayTask {
        let notes = Music.chord(root: 60 + rootPC, type: type)
        return L.task(chordName(rootPC, type), "", L.chords([notes]), display: .keyboard,
                      showTargets: false, anyOctave: true)
    }
}

extension Curriculum {
    static var reading: CurriculumSection {
        CurriculumSection(id: "reading", title: "Reading Music", symbol: "music.note.list", units: [
            readingStaffUnit, readingLandmarksUnit, readingKeysUnit, readingRoadmapUnit,
            readingExpressionUnit, readingOrnamentsUnit, readingSightUnit, readingLeadSheetUnit,
            readingDrillsUnit,
        ])
    }

    // MARK: - Unit 1: staff and clefs

    fileprivate static var readingStaffUnit: CurriculumUnit {
        let treble = lesson("reading.staff.treble", "The staff and the treble clef",
                            "Five lines, four spaces, and the clef that names them for the right hand.", [
            L.info("The staff", """
            Music is written on a **staff**: five lines and the four spaces between them. Each line and each space \
            is one white key. The higher a note sits on the staff, the higher it sounds — and the further right it is on the keyboard.

            Lines and spaces are counted **from the bottom up**: line 1 is the lowest line, line 5 the highest.

            A staff by itself does not say *which* notes the lines are. That is the job of the **clef** at the start of every line of music.
            """, glyph: "𝄞"),
            L.info("The treble clef", """
            The **treble clef** (also called the **G clef**) is used for higher notes, usually the right hand. \
            Its spiral curls around the **second line**, and that line is the **G above middle C**.

            From G you can count to every other note: each step to the next line or space is the next letter.

            The five lines, bottom to top, are **E G B D F** — "Every Good Boy Does Fine". Listen and watch the keys.
            """, glyph: "𝄞", keys: L.keys("G4"),
                   example: R.example(R.labeled(L.line("E4 G4 B4 D5 F5")), clef: .treble)),
            R.read("Play the treble lines", "Play the five line notes from bottom to top: E G B D F. The keys light up this time.",
                   L.line("E4 G4 B4 D5 F5"), clef: .treble, targets: true),
            L.info("The treble spaces", """
            The four spaces, bottom to top, spell **F A C E**.

            Lines and spaces alternate, so reading up the staff line–space–line–space is simply walking up the white keys: \
            E F G A B C D E F.
            """, example: R.example(R.labeled(L.line("F4 A4 C5 E5")), clef: .treble)),
            R.read("Play the treble spaces", "Play F A C E. The keys light up.", L.line("F4 A4 C5 E5"), clef: .treble, targets: true),
            R.read("Walk up the staff", "Now read without lights: line, space, line, space… every white key from the bottom line E to the top line F.",
                   L.line("E4 F4 G4 A4 B4 C5 D5 E5 F5"), clef: .treble),
            L.quiz("Treble clef flashcards", "A note appears on the staff. Play it. The keys do not light up — find it by reading.", rounds: 10) { _ in
                R.card([R.fresh(R.whites(64, 77))], clef: .treble)
            },
        ])

        let bass = lesson("reading.staff.bass", "The bass clef",
                          "The clef for low notes and the left hand.", [
            L.info("The bass clef", """
            The **bass clef** (the **F clef**) is used for lower notes, usually the left hand. Its two dots sit either side of the \
            **fourth line**, and that line is the **F below middle C**.

            The same lines now have different names. Bottom to top, the bass lines are **G B D F A** — "Good Boys Do Fine Always".
            """, glyph: "𝄢", keys: L.keys("F3"),
                   example: R.example(R.labeled(L.line("G2 B2 D3 F3 A3", hand: .left)), clef: .bass)),
            R.read("Play the bass lines", "Left hand: play G B D F A from the bottom line up. The keys light up.",
                   L.line("G2 B2 D3 F3 A3", hand: .left), clef: .bass, targets: true),
            L.info("The bass spaces", """
            The bass spaces, bottom to top, are **A C E G** — "All Cows Eat Grass".

            A tip that saves a lot of memorising: read the position as if it were treble clef, then go **up two letters**. \
            The bottom line is E in the treble clef, so it is G in the bass clef; the top line F becomes A.
            """, example: R.example(R.labeled(L.line("A2 C3 E3 G3", hand: .left)), clef: .bass)),
            R.read("Play the bass spaces", "Left hand: A C E G. The keys light up.", L.line("A2 C3 E3 G3", hand: .left), clef: .bass, targets: true),
            R.read("Walk up the bass staff", "No lights now. Read every line and space from the bottom line G up to the top line A.",
                   L.line("G2 A2 B2 C3 D3 E3 F3 G3 A3", hand: .left), clef: .bass),
            L.quiz("Bass clef flashcards", "Play the note shown in the bass clef.", rounds: 10) { _ in
                R.card([R.fresh(R.whites(43, 57))], clef: .bass)
            },
        ])

        let grand = lesson("reading.staff.grand", "The grand staff",
                           "Treble and bass joined together, meeting at middle C.", [
            L.info("Two staves, one instrument", """
            Piano music uses both clefs at once. The treble staff sits on top (mostly right hand), the bass staff below \
            (mostly left hand), joined by a brace at the left. Together they are the **grand staff**.

            Notes that are lined up vertically are played at the same moment.
            """, glyph: "𝄞 𝄢"),
            L.info("Middle C lives in the gap", """
            Between the two staves there is room for exactly one extra line. A note on that short line is **middle C**.

            It can be written just below the treble staff or just above the bass staff — both are the same key. \
            The notes either side of it, B and D, hang just above the bass staff and just below the treble staff.
            """, keys: L.keys("C4"),
                   example: R.example(R.labeled(R.byPitch(Music.notes("F3 G3 A3 B3 C4 D4 E4 F4 G4"))), clef: .grand)),
            R.read("Cross the gap", "Left hand plays the bass-staff notes, right hand the treble-staff notes. Walk from F up to G through middle C. Keys light up.",
                   R.byPitch(Music.notes("F3 G3 A3 B3 C4 D4 E4 F4 G4")), clef: .grand, targets: true),
            R.read("Both staves, no lights", "Read across both staves. Notes on the lower staff are for the left hand.",
                   R.byPitch(Music.notes("C3 E3 G3 C4 E4 G4 C5 G4 E4 C4 G3 E3 C3")), clef: .grand),
            R.read("Hands together", "Stacked notes are played together: left hand on the bass note, right hand on the treble note.",
                   L.together(L.line("C4 D4 E4 F4 G4", hand: .right), L.line("C3 B2 C3 A2 G2", hand: .left)), clef: .grand),
            L.quiz("Grand staff flashcards", "The note can be on either staff. Play it with the matching hand.", rounds: 12) { _ in
                R.card([R.fresh(R.whites(43, 77))], clef: .grand)
            },
        ])
        return unit("reading.staff", "Staff and clefs", [treble, bass, grand])
    }

    // MARK: - Unit 2: ledger lines, landmarks, intervals

    fileprivate static var readingLandmarksUnit: CurriculumUnit {
        let ledger = lesson("reading.landmarks.ledger", "Ledger lines",
                            "Short extra lines for notes above and below the staff.", [
            L.info("Extending the staff", """
            When a note is too high or too low for the five lines, we add short **ledger lines** just for that note. \
            They work exactly like staff lines: line, space, line, space.

            You already know one: **middle C** sits on one ledger line below the treble staff — or one above the bass staff.
            """, example: R.example(R.labeled(L.line("E4 D4 C4 B3 A3")), clef: .treble)),
            R.read("Below the treble staff", "Right hand. Step down from the bottom line E: D hangs under the staff, C is on a ledger line, B hangs under it, A is on the second ledger line.",
                   L.line("E4 D4 C4 B3 A3 B3 C4 D4 E4"), clef: .treble, targets: true),
            L.info("Above the treble staff", """
            Going up from the top line F: **G** sits on top of the staff, **A** is on the first ledger line, **B** sits above it, \
            and **C** is on the second ledger line. That C is two octaves above middle C.
            """, example: R.example(R.labeled(L.line("F5 G5 A5 B5 C6")), clef: .treble)),
            R.read("Above the treble staff", "No lights. Climb from the top line F to high C and come back.",
                   L.line("F5 G5 A5 B5 C6 B5 A5 G5 F5"), clef: .treble),
            L.info("Around the bass staff", """
            The bass staff mirrors this. **Above** it: B sits on top, middle C is on the first ledger line, D above it, E on the second ledger line.

            **Below** it: F hangs under the bottom line, **E** is on the first ledger line, D hangs below, and **low C** is on the second ledger line.
            """, example: R.example(R.labeled(L.line("G2 F2 E2 D2 C2", hand: .left)), clef: .bass)),
            R.read("Below the bass staff", "Left hand, no lights. Step down from the bottom line G to low C — the lowest key on your Launchkey — and back.",
                   L.line("G2 F2 E2 D2 C2 D2 E2 F2 G2", hand: .left), clef: .bass),
            R.read("Above the bass staff", "Left hand. Step up from the top line A through middle C to E.",
                   L.line("A3 B3 C4 D4 E4 D4 C4 B3 A3", hand: .left), clef: .bass),
            L.quiz("Ledger line flashcards", "Every card is on or next to a ledger line. Count lines and spaces from the staff.", rounds: 12) { round in
                if round % 2 == 0 {
                    return R.card([R.fresh(R.whites(57, 62) + R.whites(79, 84))], clef: .treble)
                }
                return R.card([R.fresh(R.whites(36, 41) + R.whites(59, 64))], clef: .bass)
            },
        ])

        let landmarkNotes: [Int] = Music.notes("C2 C3 F3 C4 G4 C5 C6")
        let landmarkLabels = ["Low C", "Bass C", "Bass F", "Middle C", "Treble G", "Treble C", "High C"]
        let landmarks = lesson("reading.landmarks.landmarks", "Landmark notes",
                               "Seven notes to know instantly, so every other note is only a step or two away.", [
            L.info("Why landmarks?", """
            Fluent readers do not recite "Every Good Boy…" for each note. They know a handful of **landmark notes** on sight \
            and read everything else by its distance from the nearest one.

            The seven landmarks are lit on the keyboard:

            - **Low C** — two ledger lines below the bass staff
            - **Bass C** — second space of the bass staff
            - **Bass F** — the line between the bass clef's dots
            - **Middle C** — the ledger line between the staves
            - **Treble G** — the line the treble clef curls around
            - **Treble C** — third space of the treble staff
            - **High C** — two ledger lines above the treble staff

            Notice the symmetry: the Cs mirror each other around middle C.
            """, keys: L.keys(landmarkNotes, labels: landmarkLabels),
                   example: R.example(R.byPitch(landmarkNotes), clef: .grand)),
            R.read("Play the landmarks", "Play all seven landmarks from low C to high C. The keys light up.",
                   R.byPitch(landmarkNotes), clef: .grand, targets: true),
            R.read("Landmarks, shuffled", "No lights. Name each landmark as you play it.",
                   R.byPitch(Music.notes("C4 G4 F3 C5 C3 C6 C2 F3 G4 C4")), clef: .grand),
            L.quiz("Landmark flashcards", "One landmark at a time. Aim to answer instantly.", rounds: 10) { _ in
                R.card([R.fresh(landmarkNotes)], clef: .grand)
            },
            L.info("Neighbours of a landmark", """
            Now use the landmarks. A note one position above Treble G is **A**; one below is **F**. \
            A note one position above Bass F is **G**; one below is **E**.

            In the next drill each card shows a landmark followed by a neighbour. Play both.
            """, example: R.example(R.labeled(R.byPitch(Music.notes("G4 A4 G4 F4 F3 G3 F3 E3"))), clef: .grand)),
            L.quiz("Landmark + neighbour", "Play the landmark, then the note next to it.", rounds: 10) { _ in
                let base = R.fresh([48, 53, 60, 67, 72])
                let pool = R.whites(base - 2, base + 2).filter { $0 != base }
                let neighbour = R.pick(pool)
                return R.card([base, neighbour], clef: .grand, title: "Play both notes")
            },
        ])

        let intervals = lesson("reading.landmarks.intervals", "Reading by steps and skips",
                               "Read the shape of the line — the distance between notes — instead of naming every note.", [
            L.info("Steps", """
            A **step** (a 2nd) moves from a line to the very next space, or from a space to the very next line. \
            On the keyboard it is the neighbouring white key.

            Once you know the first note, a run of steps needs no note names at all: just follow the line up or down.
            """, example: R.example(L.line("C4 D4 E4 F4 G4 F4 E4 D4 C4"), clef: .treble)),
            R.read("Steps only", "Find the first note (middle C), then just follow the steps up and down. Do not name the notes.",
                   L.line("C4 D4 E4 D4 E4 F4 G4 F4 E4 D4 C4"), clef: .treble),
            L.info("Skips", """
            A **skip** (a 3rd) jumps from a line to the next **line**, or from a space to the next **space**. \
            On the keyboard you skip one white key.

            Line–line or space–space = skip. Line–space = step. That one visual rule reads most beginner music.
            """, example: R.example(L.line("C4 E4 G4 E4 C4 D4 F4 A4 F4 D4"), clef: .treble)),
            R.read("Skips only", "Each note is a skip from the last: line to line, or space to space.",
                   L.line("C4 E4 G4 B4 G4 E4 C4"), clef: .treble),
            R.read("Steps and skips mixed", "Before each note ask only: same, step or skip — and up or down?",
                   L.line("E4 F4 G4 E4 C4 D4 F4 E4 G4 G4 F4 D4 C4"), clef: .treble),
            L.info("Bigger intervals", """
            Larger jumps have shapes too:

            - **4th** — line to space (or space to line) with one line or space skipped in between. Three white keys away.
            - **5th** — line to line with one line skipped (or space to space with one space skipped). The outer fingers of a five-finger position.
            - **Octave (8th)** — line to space, far apart; the same letter name again.

            Odd-numbered intervals (3rd, 5th, 7th) match: line–line or space–space. Even ones (2nd, 4th, 6th, octave) do not.
            """, example: R.example(R.labeled(L.line("C4 F4 C4 G4 C4 C5")), clef: .treble)),
            R.read("4ths and 5ths", "Left hand in the bass clef. Read the jumps by shape.",
                   L.line("C3 G3 C3 F3 D3 G3 E3 A3 G3 C3", hand: .left), clef: .bass),
            L.quiz("Interval flashcards", "Two notes: play the first, read the distance, play the second.", rounds: 12) { round in
                let size = R.pick([1, 1, 2, 2, 3, 4])
                if round % 2 == 0 {
                    let pool = R.whites(60, 79)
                    let i = Int.random(in: 0..<(pool.count - size))
                    let pair = Bool.random() ? [pool[i], pool[i + size]] : [pool[i + size], pool[i]]
                    return R.card(pair, clef: .treble, title: "Play both notes")
                }
                let pool = R.whites(41, 60)
                let i = Int.random(in: 0..<(pool.count - size))
                let pair = Bool.random() ? [pool[i], pool[i + size]] : [pool[i + size], pool[i]]
                return R.card(pair, clef: .bass, title: "Play both notes")
            },
        ])
        return unit("reading.landmarks", "Ledger lines, landmarks and intervals", [ledger, landmarks, intervals])
    }

    // MARK: - Unit 3: accidentals and key signatures

    fileprivate static var readingKeysUnit: CurriculumUnit {
        let accidentalCases: [(String, [Int])] = [
            ("F♯   G   F   |   F", Music.notes("F#4 G4 F#4 F4")),
            ("B♭   A   B   |   B", Music.notes("Bb4 A4 Bb4 B4")),
            ("C♯   D   C♮   C", Music.notes("C#4 D4 C4 C4")),
            ("G♯   A   G   G   |   G", Music.notes("G#4 A4 G#4 G#4 G4")),
            ("E♭   D   E   |   E   E♭", Music.notes("Eb4 D4 Eb4 E4 Eb4")),
            ("F♯ (low)   A   F (one octave higher)", Music.notes("F#4 A4 F5")),
        ]
        let accidentals = lesson("reading.keys.accidentals", "Sharps, flats and naturals",
                                 "The signs that send you to the black keys — and how long they last.", [
            L.info("Three signs", """
            An **accidental** is a sign written just **before** a note head, on the same line or space:

            - **♯ sharp** — play the very next key to the **right** (a half step higher)
            - **♭ flat** — play the very next key to the **left** (a half step lower)
            - **♮ natural** — cancel a sharp or flat; play the plain white key

            When we say the name the sign comes after the letter ("F sharp"), but on the staff it is printed in front of the note.
            """, glyph: "♯ ♭ ♮", keys: L.keys("F4 F#4 B4 Bb4", flats: false)),
            L.info("Sharps on the staff", """
            The note head stays on the line or space of its letter; only the sign changes which key you press. \
            Here are F, then F♯, then C and C♯.
            """, example: R.example(R.labeled(L.line("F4 F#4 G4 C5 C#5 D5")), clef: .treble)),
            R.read("Read the sharps", "No lights. A sharp moves the note one key to the right.",
                   L.line("G4 F#4 G4 A4 G#4 A4 D5 C#5 D5"), clef: .treble),
            R.read("Read the flats", "A flat moves the note one key to the left.",
                   L.line("A4 B4 Bb4 A4 E5 Eb5 D5 Ab4 G4"), clef: .treble, flats: true),
            R.read("Bass clef accidentals", "Left hand. Same signs, same rule.",
                   L.line("D3 C#3 D3 F3 F#3 G3 Bb2 A2", hand: .left), clef: .bass),
            L.info("How long does an accidental last?", """
            This is the rule people forget:

            - An accidental lasts **until the next bar line**. Every later note on that same line or space in the bar is also changed.
            - The **bar line cancels it**. In the next measure the note is back to normal, with no sign needed.
            - It only applies to **that exact line or space** — the same letter in another octave is not affected.
            - A **natural ♮** cancels it early, inside the same bar.

            Printed music often adds a reminder sign in the next bar (a *courtesy accidental*, sometimes in brackets). \
            This app plays safe and prints the sign on every altered note, so the next drill uses words instead of notation.
            """, glyph: "♯ |"),
            L.quiz("What actually sounds?", """
            Each card is a short passage as it would be **written**: "|" is a bar line, and a letter with no sign has no sign printed. \
            Play what it should **sound** like, applying the bar rule. Start in the octave from middle C upward.
            """, rounds: accidentalCases.count) { round in
                let item = accidentalCases[round % accidentalCases.count]
                return R.prompt(item.0, item.1)
            },
            L.info("Double sharps and double flats", """
            Occasionally you will meet a **double sharp** (an x-shaped sign) — two half steps higher — or a **double flat** (two flat signs) — two half steps lower.

            They land on keys you already know by another name: F double-sharp is the key G; B double-flat is the key A. \
            Two names for one key are called **enharmonic** spellings.
            """, glyph: "𝄪 𝄫", keys: L.keys([67, 69], labels: ["F𝄪", "B𝄫"])),
        ])

        let sharps = lesson("reading.keys.sharps", "Key signatures with sharps",
                            "Sharps at the start of the line apply to the whole piece.", [
            L.info("What a key signature is", """
            Instead of writing a sharp in front of every F in a piece, the composer writes it **once**, right after the clef on every line. \
            That is a **key signature**.

            A sharp on the F line means **every F, in every octave, in every bar, is F♯** — until a natural sign or a new key signature says otherwise.

            One sharp (F♯) is the key signature of **G major**. Listen to the G major scale: no accidentals appear next to the notes, yet the F is sharp.
            """, glyph: "♯", keys: L.keys("F#4 F#5"),
                   example: R.example(L.line("G4 A4 B4 C5 D5 E5 F#5 G5"), clef: .treble, key: 1)),
            R.read("G major scale", "One sharp: every F is F♯. Read the scale up and down — nothing reminds you at the note itself.",
                   L.line("G4 A4 B4 C5 D5 E5 F#5 G5 F#5 E5 D5 C5 B4 A4 G4"), clef: .treble, key: 1),
            L.info("The order of sharps", """
            Sharps are always added in the same order: **F C G D A E B** ("Father Charles Goes Down And Ends Battle").

            - 1 sharp: F♯ — **G major**
            - 2 sharps: F♯ C♯ — **D major**
            - 3 sharps: F♯ C♯ G♯ — **A major**
            - 4 sharps: F♯ C♯ G♯ D♯ — **E major**

            **Shortcut:** the major key is one half step **above the last sharp**. Last sharp C♯ → D major.
            """, example: R.example(L.line("D4 E4 F#4 G4 A4 B4 C#5 D5"), clef: .treble, key: 2)),
            R.read("A tune in D major", "Two sharps: F♯ and C♯. Check the signature first, then read.",
                   L.line("D4 F#4 A4 G4 F#4 E4 D4 C#4 D4 E4 F#4 D4"), clef: .treble, key: 2),
            R.read("A major, left hand", "Three sharps: F♯, C♯, G♯.",
                   L.line("A2 B2 C#3 D3 E3 F#3 G#3 A3 E3 C#3 A2", hand: .left), clef: .bass, key: 3),
            L.quiz("Sharp key flashcards", "Each card has a key signature. Play the note as the signature tells you.", rounds: 12) { round in
                let fifths = round % 4 + 1
                let tonic = (fifths * 7) % 12
                let altered = Set(Spelling.keyAccidentals(fifths: fifths).enumerated().filter { $0.element != 0 }
                    .map { ([0, 2, 4, 5, 7, 9, 11][$0.offset] + 1) % 12 })
                let pool = R.scalePool(tonic, 60, 79)
                // Favour the notes the signature changes.
                let hot = pool.filter { altered.contains(Music.pc($0)) }
                let note = (round % 3 != 2 && !hot.isEmpty) ? R.pick(hot) : R.pick(pool)
                return R.card([note], clef: .treble, key: fifths)
            },
        ])

        let flats = lesson("reading.keys.flats", "Key signatures with flats",
                           "The flat keys, and how to name any key signature at a glance.", [
            L.info("Flats in the signature", """
            Flat key signatures work the same way. One flat (B♭) is **F major**: every B is played as B♭.

            Flats are added in the order **B E A D G C F** — the order of sharps backwards.

            - 1 flat: B♭ — **F major**
            - 2 flats: B♭ E♭ — **B♭ major**
            - 3 flats: B♭ E♭ A♭ — **E♭ major**
            - 4 flats: B♭ E♭ A♭ D♭ — **A♭ major**

            **Shortcut:** the major key is the **second-to-last flat**. (One flat you simply remember: F.)
            """, glyph: "♭", keys: L.keys("Bb3 Bb4", flats: true),
                   example: R.example(L.line("F4 G4 A4 Bb4 C5 D5 E5 F5"), clef: .treble, key: -1)),
            R.read("F major scale", "One flat: every B is B♭.",
                   L.line("F4 G4 A4 Bb4 C5 D5 E5 F5 E5 D5 C5 Bb4 A4 G4 F4"), clef: .treble, key: -1),
            R.read("A tune in B♭ major", "Two flats: B♭ and E♭.",
                   L.line("Bb4 C5 D5 Eb5 D5 C5 Bb4 A4 Bb4 F4 G4 Bb4"), clef: .treble, key: -2),
            R.read("E♭ major, left hand", "Three flats: B♭, E♭, A♭.",
                   L.line("Eb3 F3 G3 Ab3 Bb3 Ab3 G3 F3 Eb3 Bb2 Eb3", hand: .left), clef: .bass, key: -3),
            L.quiz("Flat key flashcards", "Play each note as its key signature says.", rounds: 12) { round in
                let fifths = -(round % 4 + 1)
                let tonic = ((fifths * 7) % 12 + 12) % 12
                let pool = R.scalePool(tonic, 60, 79)
                let hot = pool.filter { Music.isBlack($0) }
                let note = (round % 3 != 2 && !hot.isEmpty) ? R.pick(hot) : R.pick(pool)
                return R.card([note], clef: .treble, key: fifths)
            },
            L.info("Accidentals inside a key", """
            Accidentals still appear in pieces with key signatures — they mark notes **outside** the key.

            In G major every F is sharp, so to get a plain F the composer must write a **natural ♮**. \
            As always it lasts to the bar line; after that, F♯ returns automatically.

            Every major key also shares its signature with a **relative minor** three half steps below the major tonic \
            (G major and E minor both have one sharp). A piece that keeps coming home to E, often with an added D♯, is in E minor.
            """, example: R.example(L.line("G4 F#4 G4 A4 G4 F4 E4 D#4 E4"), clef: .treble, key: 1)),
            R.read("Naturals in G major", "One sharp in the signature. Watch for the natural sign and the extra sharp.",
                   L.line("B4 A4 G4 F#4 G4 F4 E4 D#4 E4 F#4 G4"), clef: .treble, key: 1),
            L.quiz("Name the key", "Read the description, work out the major key with the shortcuts, and play its tonic (any octave).", rounds: 8) { round in
                let options = [1, 2, 3, 4, -1, -2, -3, -4]
                let fifths = options[round % options.count]
                let tonic = ((fifths * 7) % 12 + 12) % 12
                let count = abs(fifths)
                let kind = fifths > 0 ? (count == 1 ? "sharp" : "sharps") : (count == 1 ? "flat" : "flats")
                return R.prompt("\(count) \(kind) — which major key?", [60 + tonic], anyOctave: true)
            },
        ])
        return unit("reading.keys", "Accidentals and key signatures", [accidentals, sharps, flats])
    }

    // MARK: - Unit 4: measures, repeats, road maps, octave signs, clef changes

    fileprivate static var readingRoadmapUnit: CurriculumUnit {
        let phraseA = "C4:q D4:q E4:q F4:q"
        let measures = lesson("reading.roadmap.measures", "Measures and bar lines",
                              "How music is divided into equal groups of beats.", [
            L.info("Bar lines and measures", """
            Vertical **bar lines** divide the staff into **measures** (also called **bars**). Every measure holds the same number of beats.

            The **time signature** after the clef tells you how many: the top number is the beats per measure, the bottom number the note value that gets one beat. \
            In 4/4 each measure adds up to four quarter-note beats.

            The first beat after each bar line — the **downbeat** — is felt as the strongest.
            """, glyph: "4/4",
                   example: R.timedExample(L.melody("C4:q D4:q E4:q F4:q | G4:h E4:h | F4:q E4:q D4:q B3:q | C4:w"), clef: .treble)),
            L.info("Kinds of bar line", """
            - A **single bar line** ends each measure.
            - A **double bar line** (two thin lines) marks the end of a section — often where the key or time signature changes.
            - A **final bar line** (thin + thick) ends the piece.

            Bar lines are also where accidentals expire, and they are your map references: teachers say "start at bar 9".
            """, glyph: "𝄂"),
            R.readTimed("Read four measures", "Press Start (or the Space bar) and count 1-2-3-4 in every measure. Keep going whatever happens: the playhead moves on without you.",
                        L.melody("E4:q E4:q F4:q G4:q | G4:q F4:q E4:q D4:q | C4:q C4:q D4:q E4:q | D4:h C4:h"), bpm: 66, clef: .treble),
            R.readTimed("Three beats in a measure", "A 3/4 time signature: three quarter-note beats per bar. Count 1-2-3.",
                        L.melody("C4:q E4:q G4:q | A4:h G4:q | F4:q E4:q D4:q | C4:h."), bpm: 72, meter: (3, 4), clef: .treble),
            R.readTimed("Rests fill the bar too", "Silence is counted exactly like sound. Keep counting through the rests.",
                        L.melody("G4:q r:q E4:q r:q | F4:h r:h | D4:q E4:q F4:q r:q | C4:w"), bpm: 66, clef: .treble),
        ])

        let repeats = lesson("reading.roadmap.repeats", "Repeats and 1st / 2nd endings",
                             "Signs that tell you to play a section again.", [
            L.info("Repeat signs", """
            A **repeat sign** is a final-style bar line with two dots. The dots always face the music to be repeated.

            - On reaching the **end repeat** (dots on the left of the lines), go back to the matching **start repeat** (dots on the right) and play the section once more.
            - If there is **no start repeat**, go back to the very beginning.
            - The second time, carry straight on past the sign.

            The example shows a passage **as written**, with a start repeat at the beginning and an end repeat after bar 2. \
            (Listen plays the page straight through once; the repeat is yours to add.)

            Played:  C D E F | G G E – | C D E F | G G E – | C
            """, glyph: "𝄆 𝄇",
                   example: R.mark(R.timedExample(L.melody("\(phraseA) | G4:q G4:q E4:h | C4:w"), clef: .treble),
                                   repeats: [RepeatSpan(start: 0, end: 8)])),
            R.readTimed("Play the repeat", "Here is that passage written out in full, the way it sounds. Notice bars 3–4 are bars 1–2 again.",
                        L.melody("\(phraseA) | G4:q G4:q E4:h | \(phraseA) | G4:q G4:q E4:h | C4:w"), bpm: 72, clef: .treble),
            L.info("First and second endings", """
            Sometimes the repeated section should end differently the second time. Brackets above the staff, numbered **1.** and **2.**, show this — they are called **volta brackets**.

            - First time: play the **1st ending**, obey the repeat sign and go back.
            - Second time: **skip the 1st ending entirely** and jump straight to the **2nd ending**.

            The example shows it **as written**: bar 2 is the 1st ending, with the repeat sign after it; bar 3 is the 2nd ending.

            Played:  C D E F | G E G – | C D E F | E D C –
            """, glyph: "1. 2.",
                   example: R.mark(R.timedExample(L.melody("\(phraseA) | G4:q E4:q G4:h | E4:q D4:q C4:h"), clef: .treble),
                                   markers: [R.above(4, "1."), R.above(8, "2.")],
                                   repeats: [RepeatSpan(start: 0, end: 8)])),
            R.readTimed("Play both endings", "The written-out version: bar 2 is the first ending, bar 4 the second.",
                        L.melody("\(phraseA) | G4:q E4:q G4:h | \(phraseA) | E4:q D4:q C4:h"), bpm: 72, clef: .treble),
            L.quiz("Follow the repeat", """
            Now do the unfolding yourself. Each card shows the music as **written**; play it as it should **sound**. \
            All notes are in the octave starting at middle C. "|:" and ":|" are repeat signs; [1.] and [2.] are endings.
            """, rounds: 4) { round in
                let cases: [(String, [Int])] = [
                    ("|: C E G :|  C", Music.notes("C4 E4 G4 C4 E4 G4 C4")),
                    ("C D  |: E F :|  G", Music.notes("C4 D4 E4 F4 E4 F4 G4")),
                    ("|: C D  [1.] E :|  [2.] G", Music.notes("C4 D4 E4 C4 D4 G4")),
                    ("|: G E  [1.] F D :|  [2.] D C", Music.notes("G4 E4 F4 D4 G4 E4 D4 C4")),
                ]
                let item = cases[round % cases.count]
                return R.prompt(item.0, item.1)
            },
        ])

        let partA = "E4:q G4:q E4:q C4:q | D4:q E4:q D4:h"
        let partB = "F4:q A4:q G4:q F4:q | E4:q D4:q E4:h"
        let dcal = lesson("reading.roadmap.dcds", "D.C., D.S., Coda and Fine",
                          "The Italian road signs that send you around a piece.", [
            L.info("D.C. and Fine", """
            Longer jumps use words instead of repeat signs.

            - **D.C.** (*Da Capo*, "from the head") — go back to the **very beginning**.
            - **Fine** ("the end", say *fee-nay*) — the place where the piece actually stops, even though it is not the last bar on the page.
            - **D.C. al Fine** — go back to the beginning and play until the word *Fine*.

            The example shows a short piece **as written**: section A (bars 1–2) ends with *Fine*, and section B (bars 3–4) ends with *D.C. al Fine*.

            Played:  A, B, A.

            Convention: repeat signs are ignored on the way back unless the score says otherwise.
            """, glyph: "D.C.",
                   example: R.mark(R.timedExample(L.melody("\(partA) | \(partB)"), bpm: 76, clef: .treble),
                                   markers: [R.above(6, "Fine"), R.above(14, "D.C. al Fine")])),
            R.readTimed("D.C. al Fine", "Written out as it sounds: section A, section B, then A again, stopping at the Fine.",
                        L.melody("\(partA) | \(partB) | \(partA)"), bpm: 76, clef: .treble),
            L.info("D.S. and the segno", """
            - **D.S.** (*Dal Segno*, "from the sign") — go back, not to the beginning, but to the **segno**: a sign like a slanted **S** crossed by a stroke with a dot on each side.
            - **D.S. al Fine** — go back to the segno and play to *Fine*.

            Use it when a piece has an introduction you do not want to hear twice.
            """, glyph: "D.S."),
            L.info("The Coda", """
            A **coda** ("tail") is a separate ending section, usually printed at the bottom of the page and marked with the **coda sign**: a circle with a cross through it.

            **D.S. al Coda** (or **D.C. al Coda**) means:

            - go back to the segno (or the beginning),
            - play until you reach the words **To Coda** (or the coda sign),
            - then **jump** straight to the coda and play to the end.

            The example shows it **as written**, one bar per section: Intro | A (segno at its start, *To Coda* at its end) | B (*D.S. al Coda*) | Coda.

            Played:  Intro, A, B, A, Coda.
            """, glyph: "Coda",
                   example: R.mark(R.timedExample(L.melody("C4:h G4:h | E4:q G4:q E4:q C4:q | F4:q A4:q G4:q F4:q | D4:q B3:q C4:h"), bpm: 76, clef: .treble),
                                   markers: [R.above(4, "Segno"), R.above(7, "To Coda"), R.above(10, "D.S. al Coda"), R.above(12, "Coda")])),
            R.readTimed("D.S. al Coda", "Written out as it sounds: Intro, A, B, back to A, then jump to the Coda. One bar each.",
                        L.melody("C4:h G4:h | E4:q G4:q E4:q C4:q | F4:q A4:q G4:q F4:q | E4:q G4:q E4:q C4:q | D4:q B3:q C4:h"),
                        bpm: 76, clef: .treble),
            L.quiz("Navigate the road map", """
            Each card names the sections as written. Each letter stands for one note: **A = C, B = E, C = G, Coda = high C** (the C above middle C). \
            Play the notes in the order the sections would be heard.
            """, rounds: 4) { round in
                let cases: [(String, [Int])] = [
                    ("A (Fine)  |  B  D.C. al Fine", Music.notes("C4 E4 C4")),
                    ("A  |  segno B (Fine)  |  C  D.S. al Fine", Music.notes("C4 E4 G4 E4")),
                    ("A (To Coda)  |  B  D.C. al Coda  |  Coda", Music.notes("C4 E4 C4 C5")),
                    ("A  |  segno B (To Coda)  |  C  D.S. al Coda  |  Coda", Music.notes("C4 E4 G4 E4 C5")),
                ]
                let item = cases[round % cases.count]
                return R.prompt(item.0, item.1)
            },
        ])

        let octaveCases: [(String, [Int])] = [
            ("8va over:  C5  E5  G5", Music.notes("C6 E6 G6")),
            ("8vb under:  C4  A3  F3", Music.notes("C3 A2 F2")),
            ("8va over:  G4  A4  B4", Music.notes("G5 A5 B5")),
            ("15ma over:  C4  D4  E4", Music.notes("C6 D6 E6")),
            ("8vb under:  G3  E3  C3", Music.notes("G2 E2 C2")),
            ("8va over E5 F5, then loco: G5", Music.notes("E6 F6 G5")),
        ]
        let octaves = lesson("reading.roadmap.octaves", "Octave signs: 8va, 8vb, 15ma",
                             "Shorthand that avoids stacks of ledger lines.", [
            L.info("8va", """
            Very high notes need many ledger lines, which are slow to read. Instead the composer writes the notes an octave lower and puts **8va** with a dashed line above them.

            **8va** (*ottava*) above the staff: play everything under the dashed line **one octave higher** than written.

            When the line ends — sometimes marked **loco** ("in place") — play as written again.

            In the example, the first five notes are written comfortably inside the staff under an **8va** sign. \
            The next five (after *loco*) show the same notes written honestly at the pitch they sound: up to four ledger lines.
            """, glyph: "8va",
                   example: R.mark(R.example(R.labeled(L.line("C5 D5 E5 F5 G5 C6 D6 E6 F6 G6")), clef: .treble),
                                   markers: [R.above(0, "8va"), R.above(5, "loco")])),
            L.info("8vb and 15ma", """
            - **8vb** (*ottava bassa*) **below** the staff: play **one octave lower** than written. Common in the left hand.
            - **15ma** (*quindicesima*) above the staff: play **two octaves higher**. (15, not 16: an octave is 8 notes, and the middle note is counted once.)
            - **15mb** below the staff: two octaves lower.

            On a keyboard an octave is the same letter and the same pattern of black keys, 12 keys away.

            In the example, the first three notes carry an **8vb** sign; the last three show where they really sound.
            """, glyph: "8vb", keys: L.keys("C3 C4 C5 C6"),
                   example: R.mark(R.example(R.labeled(L.line("C4 A3 F3 C3 A2 F2", hand: .left)), clef: .bass),
                                   markers: [R.below(0, "8vb"), R.below(3, "loco")])),
            R.read("Read the real ledger lines", "First, the hard way: these notes are written at their true pitch.",
                   L.line("G5 A5 B5 C6 D6 E6 D6 C6"), clef: .treble),
            L.quiz("Apply the octave sign", "Each card names the **written** notes and the sign over or under them. Play them where they really sound.",
                   rounds: octaveCases.count) { round in
                let item = octaveCases[round % octaveCases.count]
                return R.prompt(item.0, item.1)
            },
        ])

        let clefChange = lesson("reading.roadmap.clefs", "Clef changes within a piece",
                                "When a hand wanders into the other clef's territory.", [
            L.info("A new clef mid-line", """
            A staff is not locked to one clef. If the left hand climbs high for a while, a small **treble clef** appears in the lower staff; \
            if the right hand drops low, a small **bass clef** appears in the upper staff.

            - The new clef applies **from that point on**, until another clef replaces it.
            - It is usually printed slightly smaller, and often **just before a bar line** as a warning for the next bar.
            - The hand does not change — only the way its notes are named. Left hand in treble clef is still the left hand.

            Always glance at the clef at the start of each new line, too: the clef in force is reprinted there.
            """, glyph: "𝄢 𝄞"),
            L.info("How this app shows it", """
            This app draws a grand staff and moves the notes to the other staff rather than printing a small clef. \
            The reading skill is the same: the instant the clef changes, you must switch which set of note names you are using.

            In the example the melody starts in the bass clef, crosses into the treble clef and returns.
            """, example: R.example(R.byPitch(Music.notes("C3 E3 G3 C4 E4 G4 E4 C4 G3 E3 C3")), clef: .grand)),
            R.read("One hand, two clefs", "Play the whole line with your **left hand** — it climbs into the treble staff and comes back.",
                   R.byPitch(Music.notes("G2 B2 D3 G3 B3 D4 G4 D4 B3 G3 D3 B2 G2")), clef: .grand),
            R.read("Switch quickly", "The clef changes every two notes. Reset your landmarks each time: Bass F below, Treble G above.",
                   R.byPitch(Music.notes("F3 A3 G4 B4 E3 G3 F4 A4 D3 F3 E4 G4 C3 C4")), clef: .grand),
            L.quiz("Which clef?", "Cards alternate between treble and bass clef. Check the clef before you read the note.", rounds: 12) { round in
                // The same staff position means a different note in each clef.
                let position = Int.random(in: 0..<9)
                if (round + Int.random(in: 0...1)) % 2 == 0 {
                    return R.card([R.whites(64, 77)[position]], clef: .treble)
                }
                return R.card([R.whites(43, 57)[position]], clef: .bass)
            },
        ])
        return unit("reading.roadmap", "Measures, repeats and road maps", [measures, repeats, dcal, octaves, clefChange])
    }

    // MARK: - Unit 5: dynamics and articulation

    fileprivate static var readingExpressionUnit: CurriculumUnit {
        let five = "C4 D4 E4 F4 G4 F4 E4 D4 C4"
        let dynamics = lesson("reading.expression.dynamics", "Dynamics: pp to ff",
                              "The letters under the staff that tell you how loud to play.", [
            L.info("Dynamic markings", """
            **Dynamics** are written below the staff (between the staves in piano music) in bold italic letters. They are Italian:

            - **pp** — *pianissimo* — very soft
            - **p** — *piano* — soft
            - **mp** — *mezzo piano* — moderately soft
            - **mf** — *mezzo forte* — moderately loud
            - **f** — *forte* — loud
            - **ff** — *fortissimo* — very loud

            A dynamic stays in force until the next one appears.

            On a keyboard, loudness comes from **how fast the key goes down**, not how hard you press afterwards. \
            Your Launchkey reports this as **velocity** (1–127); watch the velocity meter above the on-screen keyboard.

            The example is marked **p** at the start and **f** halfway through.
            """, glyph: "p  f",
                   example: R.mark(R.example(L.line("C4 D4 E4 F4 G4 F4 E4 D4"), clef: .treble),
                                   markers: [R.below(0, "p"), R.below(4, "f")])),
            R.mark(R.read("Play piano (p)", "Soft: let the keys go down slowly, fingers close to the keys.", L.line(five), clef: .treble, targets: true, rules: [L.p]), markers: [R.below(0, "p")]),
            R.mark(R.read("Play forte (f)", "Loud: a quicker, deeper drop into each key using the weight of your arm — not a stiff hit.", L.line(five), clef: .treble, targets: true, rules: [L.f]), markers: [R.below(0, "f")]),
            L.info("The in-between levels", """
            **mp** and **mf** are the everyday speaking voices of music, and the hardest to tell apart. \
            Think of **mf** as your normal, comfortable tone and **mp** as one notch gentler.

            If the app says your notes fall outside the range, look at the average velocity it reports and adjust.
            """, glyph: "mp mf"),
            R.mark(R.read("Play mezzo piano (mp)", "Moderately soft.", L.line(five), clef: .treble, targets: true, rules: [L.mp]), markers: [R.below(0, "mp")]),
            R.mark(R.read("Play mezzo forte (mf)", "Moderately loud: your natural, full tone.", L.line(five), clef: .treble, targets: true, rules: [L.mf]), markers: [R.below(0, "mf")]),
            R.mark(R.read("Play pianissimo (pp)", "As soft as you can while every note still sounds. This is the hardest dynamic to control.", L.line(five), clef: .treble, targets: true, rules: [L.pp], pass: 0.7), markers: [R.below(0, "pp")]),
            R.mark(R.read("Play fortissimo (ff)", "Very loud, but never harsh: drop from the arm and stay loose in the wrist.", L.line(five), clef: .treble, targets: true, rules: [L.ff]), markers: [R.below(0, "ff")]),
            R.mark(R.read("Soft, then loud", "A sudden change: play the first four notes **p** and the last four **f**, as marked. The result card checks that the end is clearly louder than the start.",
                   L.line("C4 D4 E4 F4 G4 A4 B4 C5", fingers: "1 2 3 1 2 3 4 5"), clef: .treble, targets: true, rules: [.crescendo]),
                   markers: [R.below(0, "p"), R.below(4, "f")]),
        ])

        let changes = lesson("reading.expression.changes", "Crescendo, diminuendo, sfz and fp",
                             "Gradual and sudden changes of loudness.", [
            L.info("Getting louder and softer", """
            - **Crescendo** (*cresc.*) — gradually **louder**. Drawn as a long wedge opening to the right: a "hairpin".
            - **Diminuendo** (*dim.*) or **decrescendo** (*decresc.*) — gradually **softer**. A hairpin closing to the right.

            The change is spread evenly across the whole hairpin. The classic mistake is to get loud immediately — \
            start a crescendo **softer than you think**, so you have somewhere to go.

            The example grows from **p** to **f** under an opening hairpin, then fades back under a closing one.
            """, glyph: "𝆒 𝆓",
                   example: R.mark(R.example(L.line("C4 D4 E4 F4 G4 A4 B4 C5 B4 A4 G4 F4 E4 D4 C4"), clef: .treble),
                                   markers: [R.below(0, "p"), R.below(1, "cresc<"), R.below(7, "f"),
                                             R.below(8, "dim>"), R.below(14, "p")])),
            R.mark(R.read("Crescendo", "Follow the hairpin: start soft and make every note a little louder than the one before.",
                   L.line("C4 D4 E4 F4 G4 A4 B4 C5", fingers: "1 2 3 1 2 3 4 5"), clef: .treble, targets: true, rules: [.crescendo]),
                   markers: [R.below(0, "p"), R.below(1, "cresc<"), R.below(7, "f")]),
            R.mark(R.read("Diminuendo", "Follow the closing hairpin: start loud and fade steadily to soft.",
                   L.line("C5 B4 A4 G4 F4 E4 D4 C4", fingers: "5 4 3 2 1 3 2 1"), clef: .treble, targets: true, rules: [.diminuendo]),
                   markers: [R.below(0, "f"), R.below(1, "dim>"), R.below(7, "p")]),
            L.info("Sudden accents: sfz", """
            **sfz** or **sf** (*sforzando*, "forcing") — a sudden, strong accent on **one note or chord only**. \
            Everything around it stays at the prevailing dynamic.

            In the example the third note of each group carries the sfz.
            """, glyph: "sfz",
                   example: R.mark(R.example(L.melody("C4:q D4:q E4:q> D4:q C4:q D4:q E4:q> D4:q"), clef: .treble),
                                   markers: [R.below(0, "p"), R.below(2, "sfz"), R.below(6, "sfz")])),
            R.mark(R.read("Sforzando", "Play softly, but punch the notes marked **sfz**. Then drop straight back to soft.",
                   L.melody("C4:q D4:q E4:q> D4:q C4:q D4:q E4:q> D4:q C4:q"), clef: .treble, targets: true, rules: [.accents(minDiff: 25)]),
                   markers: [R.below(0, "p"), R.below(2, "sfz"), R.below(6, "sfz")]),
            L.info("Forte-piano: fp", """
            **fp** (*fortepiano*) — attack **loud**, then be **immediately soft**. \
            On a piano a single held note cannot get softer after it is struck, so in practice: the marked note is forte and the notes that follow are suddenly piano.

            Related sudden markings: **subito p** ("suddenly soft") and **subito f**.
            """, glyph: "fp"),
            R.mark(R.read("Forte-piano", "The first note of each group of four is marked **fp**: strike it loud, then play the next three softly.",
                   L.melody("G4:q> E4:q E4:q E4:q A4:q> F4:q F4:q F4:q G4:q> E4:q E4:q E4:q"), clef: .treble, targets: true, rules: [.accents(minDiff: 25)]),
                   markers: [R.below(0, "fp"), R.below(4, "fp"), R.below(8, "fp")]),
        ])

        let articulation = lesson("reading.expression.articulation", "Articulation marks",
                                  "Dots, dashes and wedges that shape how each note begins and ends.", [
            L.info("Staccato and staccatissimo", """
            Articulation marks sit directly above or below the note head.

            - **Staccato** — a **dot** above or below the note: play it short and detached, roughly half its written length. The beat does not speed up; the rest of the note's time becomes silence.
            - **Staccatissimo** — a small **wedge** (a tiny filled triangle): as short as possible.

            Do not confuse the staccato dot (above/below the head) with the dot **after** a note head, which makes the note longer.
            """, glyph: "note:q",
                   example: R.example(L.melody("C4:q' E4:q' G4:q' E4:q' C4:q'"), clef: .treble)),
            R.read("Staccato", "Release each key the instant it sounds, like touching something hot. The dot under each note is the staccato mark.",
                   L.melody("C4:q' D4:q' E4:q' F4:q' G4:q' F4:q' E4:q' D4:q' C4:q'"), clef: .treble, targets: true, rules: [.staccato]),
            R.read("Staccatissimo", "Even shorter: the lightest possible flick from the fingertip.",
                   L.melody("G4:q' G4:q' E4:q' E4:q' C4:q' C4:q' G4:q' C4:q'"), clef: .treble, targets: true, rules: [.staccato]),
            L.info("Tenuto", """
            **Tenuto** — a short horizontal **dash** over the note: hold the note for its **full value**, with a little extra weight. \
            It is the opposite instruction to staccato.
            """, glyph: "ten."),
            R.read("Tenuto", "Hold every note right up to the moment the next one begins — no gaps at all.",
                   L.line("C4 E4 D4 F4 E4 G4 F4 D4 C4").map { var e = $0; e.articulation = .tenuto; return e },
                   clef: .treble, targets: true, rules: [.legato]),
            L.info("Accent and marcato", """
            - **Accent** — a sideways wedge **>** : play this note noticeably louder than its neighbours.
            - **Marcato** — an upright wedge **^** ("marked"): a heavier accent, usually a little detached as well.

            Accents are relative: in a soft passage an accented note is still only moderately loud.
            """, glyph: ">  ^",
                   example: R.example(L.melody("C4:q> D4:q E4:q F4:q G4:q> F4:q E4:q D4:q"), clef: .treble)),
            R.read("Accents", "Lean into the notes marked >, keep the others lighter.",
                   L.melody("C4:q> D4:q E4:q F4:q G4:q> F4:q E4:q D4:q C4:q>"), clef: .treble, targets: true, rules: [.accents(minDiff: 18)]),
            R.read("Marcato", "A bigger contrast now: marked notes much louder, with a firm attack.",
                   L.melody("C4:q> G4:q C4:q> G4:q E4:q> G4:q E4:q> G4:q C4:q>"), clef: .treble, targets: true, rules: [.accents(minDiff: 30)]),
        ])

        let slurs = lesson("reading.expression.slurs", "Slurs and phrase marks",
                           "Curved lines that connect notes into musical sentences.", [
            L.info("The slur", """
            A **slur** is a curved line over or under a group of **different** notes. Play them **legato**: smoothly connected, \
            each key released only as the next goes down.

            At the **end** of a slur, lift the hand gently — a small breath before whatever follows.

            Do not confuse a slur with a **tie**: a tie joins two notes of the **same pitch** into one longer note that is struck only once.
            """, glyph: "legato",
                   example: R.mark(R.example(L.line("E4 F4 G4 A4 G4 F4 E4"), clef: .treble), slurs: [(0, 6)])),
            R.mark(R.read("One long slur", "A single slur covers all nine notes. Connect every note to the next.",
                   L.line("C4 D4 E4 F4 G4 F4 E4 D4 C4", fingers: "1 2 3 4 5 4 3 2 1"), clef: .treble, targets: true, rules: [.legato]),
                   slurs: [(0, 8)]),
            L.info("Two-note slurs", """
            A slur over just two notes has its own gesture: **down–up**. Drop into the first note with a little weight, \
            connect to the second, and play the second **softer and shorter** as the wrist lifts.

            The example shows four two-note slurs. Listen for the tiny lift after each pair.
            """, example: R.mark(R.timedExample(L.melody("G4:q E4:e r:e A4:q F4:e r:e | G4:q E4:e r:e F4:q D4:e r:e"), bpm: 80, clef: .treble),
                                 slurs: [(0, 1), (2, 3), (4, 5), (6, 7)])),
            R.mark(R.read("Slurred thirds, left hand", "Left hand. One slur over the whole line: smoothly connected throughout.",
                   L.line("C3 E3 D3 F3 E3 G3 F3 D3 C3", hand: .left, fingers: "5 3 4 2 3 1 2 4 5"), clef: .bass, targets: true, rules: [.legato]),
                   slurs: [(0, 8)]),
            L.info("Phrase marks", """
            A longer curve spanning several bars is a **phrase mark**. It shows a complete musical thought, like a sentence.

            - Play the whole phrase connected, with one overall shape — usually growing toward the middle and relaxing at the end.
            - Between phrases, **lift**: singers and wind players breathe there, and pianists should too.

            Next you will play two five-note phrases, each under its own curve. Connect within each phrase, and lift between them.
            """),
            R.mark(R.read("Two phrases", "Phrase 1 is C D E F G, phrase 2 is A G F E C. Connect inside each phrase; lift your hand where one curve ends and the next begins.",
                   L.line("C4 D4 E4 F4 G4 A4 G4 F4 E4 C4"), clef: .treble, targets: true, rules: [.legato]),
                   slurs: [(0, 4), (5, 9)]),
            R.mark(R.read("Shape the phrase", "One phrase under one curve: connected, and getting louder toward the top note.",
                   L.line("C4 D4 E4 F4 G4 A4 B4 C5", fingers: "1 2 3 1 2 3 4 5"), clef: .treble, targets: true, rules: [.legato, .crescendo]),
                   markers: [R.below(0, "p"), R.below(1, "cresc<"), R.below(7, "f")], slurs: [(0, 7)]),
        ])
        return unit("reading.expression", "Dynamics and articulation", [dynamics, changes, articulation, slurs])
    }

    // MARK: - Unit 6: ornaments, pedal, fingering

    fileprivate static var readingOrnamentsUnit: CurriculumUnit {
        let trills = lesson("reading.ornaments.trills", "Trills and mordents",
                            "Small signs that stand for quick decorations.", [
            L.info("Ornaments are shorthand", """
            An **ornament** is a small sign above a note that stands for several quick notes. \
            Composers use them because writing out every tiny note would clutter the page.

            For each sign, the examples show the note **as written** with its ornament sign, followed by the **realisation** — the notes you actually play — written out in full.
            """, glyph: "tr"),
            L.info("The trill", """
            **tr** above a note (often followed by a wavy line): alternate rapidly between the **written note** and the **note above it** in the key, for the full length of the note.

            - In music from about 1800 onward, start on the **written note**.
            - In Baroque and early Classical music (Bach, Mozart), trills usually start on the **upper note**.

            Bar 1 shows a trill on C **as written**. Bar 2 is the realisation: sixteenth notes for two beats, landing on a held C.
            """, glyph: "tr",
                   example: R.timedExample(R.ornamented("C5:h", .trill)
                                           + L.melody("C5:s D5:s C5:s D5:s C5:s D5:s C5:s D5:s C5:h", start: 4), bpm: 60, clef: .treble)),
            R.read("Trill, slowly", "Fingers 2 and 3. Alternate C and D evenly; stay loose and close to the keys.",
                   L.line("C5 D5 C5 D5 C5 D5 C5 D5 C5", fingers: "2 3 2 3 2 3 2 3 2"), clef: .treble, targets: true, rules: [.evenVelocity(maxStdDev: 14)]),
            R.readTimed("Trill in time", "Four notes per click, then hold the last C. If it is too fast, lower the tempo.",
                        L.melody("C5:s D5:s C5:s D5:s C5:s D5:s C5:s D5:s C5:h"), bpm: 54, clef: .treble, pass: 0.7),
            L.info("The mordent", """
            A **mordent** is a single quick "bite": written note, neighbour, written note — played right on the beat, as fast as is clean.

            - **Lower mordent** — a short zigzag with a **vertical stroke through it**: written note → note **below** → written note. On C: C–B–C.
            - **Upper mordent** (also called an inverted mordent or *Pralltriller*) — the short zigzag **without** the stroke: written note → note **above** → written note. On C: C–D–C.

            Unlike a trill, a mordent happens once and then the main note is held.

            Bar 1 shows a mordent on C **as written**. Bar 2 is the realisation of the lower mordent (C–B–C), then of the upper mordent (C–D–C).
            """, glyph: "C-B-C",
                   example: R.timedExample(R.ornamented("C5:h", .mordent)
                                           + L.melody("C5:t B4:t C5:q.. C5:t D5:t C5:q..", start: 4), bpm: 60, clef: .treble)),
            R.read("Lower mordent", "Each group is main note – note below – main note. Play each group as one quick gesture.",
                   L.line("C5 B4 C5 E5 D5 E5 G5 F5 G5", fingers: "3 2 3 3 2 3 3 2 3"), clef: .treble, targets: true),
            R.read("Upper mordent", "Main note – note above – main note.",
                   L.line("C5 D5 C5 E5 F5 E5 G5 A5 G5", fingers: "2 3 2 2 3 2 2 3 2"), clef: .treble, targets: true),
        ])

        let turns = lesson("reading.ornaments.turns", "Turns and grace notes",
                           "The turn, the acciaccatura and the appoggiatura.", [
            L.info("The turn", """
            A **turn** is a sign like a letter **S lying on its side**. It circles the written note with four notes:

            **note above → written note → note below → written note**

            A turn on C: **D – C – B – C**.

            If the sign sits directly **over** the note, the turn starts on the beat. If it sits **between** two notes, play the first note, then fit the turn in just before the next one.

            Bar 1 shows a turn on C **as written**, moving on to E. Bar 2 is the realisation.
            """, glyph: "turn",
                   example: R.timedExample(R.ornamented("C5:q", .turn) + L.melody("E5:h", start: 1)
                                           + L.melody("D5:s C5:s B4:s C5:s E5:h", start: 4), bpm: 60, clef: .treble)),
            R.read("Turn, slowly", "Turns on C, then on E, then on G: above, main, below, main.",
                   L.line("D5 C5 B4 C5 F5 E5 D5 E5 A5 G5 F5 G5", fingers: "4 3 2 3 4 3 2 3 4 3 2 3"), clef: .treble, targets: true),
            R.readTimed("Turn in time", "A turn on beat 1 leading to a held E, twice.",
                        L.melody("D5:s C5:s B4:s C5:s E5:h. | D5:s C5:s B4:s C5:s E5:h."), bpm: 56, clef: .treble, pass: 0.7),
            L.info("Grace notes: the acciaccatura", """
            **Grace notes** are printed as tiny notes before a normal note. They have no time of their own in the bar.

            The **acciaccatura** ("crushed note") is a tiny eighth note with a **slash through its stem**. \
            Play it as quickly as possible, squeezed in right before (or right on) the beat, so the main note still lands in time.

            Think of it as a flick: the two keys go down almost — but not quite — together.

            Bar 1 shows two notes **as written**, each with a grace note. Bar 2 is the realisation: a crushed note a step below, flicked in just before each beat.
            """, glyph: "note:e note:q",
                   example: R.timedExample(R.ornamented("r:q C5:q r:q E5:q", .acciaccatura)
                                           + L.melody("r:e.. B4:t C5:q r:e.. D5:t E5:q", start: 4), bpm: 60, clef: .treble)),
            R.read("Acciaccatura", "Each pair is a crushed grace note and its main note. Flick the first and land on the second.",
                   L.line("B4 C5 D5 E5 F#5 G5 B5 C6", fingers: "2 3 2 3 2 3 2 3"), clef: .treble, targets: true),
            L.info("The appoggiatura", """
            The **appoggiatura** ("leaning note") is a tiny note **without** a slash. It is not quick at all: \
            it is played **on the beat** and **takes half the value** of the main note (two thirds if the main note is dotted).

            It leans on the main note: play the appoggiatura a little stronger and resolve softly onto the main note.

            Written: small D before a half note C.  Played: D quarter, C quarter.

            Bar 1 shows two half notes **as written**, each with an appoggiatura. Bar 2 is the realisation: the leaning note takes the first half of each.
            """, glyph: "note:q note:h",
                   example: R.timedExample(R.ornamented("C5:h E5:h", .appoggiatura)
                                           + L.melody("D5:q> C5:q F5:q> E5:q", start: 4), bpm: 66, clef: .treble)),
            R.readTimed("Appoggiatura", "Each pair is an appoggiatura (accented, on the beat) resolving to its main note. Lean, then relax.",
                        L.melody("D5:q> C5:q F5:q> E5:q | A5:q> G5:q D5:q> C5:q"), bpm: 66, clef: .treble, rules: [.accents(minDiff: 10)]),
        ])

        let pedalChords: [[Int]] = [Music.notes("C4 E4 G4"), Music.notes("C4 F4 A4"), Music.notes("B3 D4 G4"), Music.notes("C4 E4 G4")]
        let pedal = lesson("reading.ornaments.pedal", "Pedal markings",
                           "How the score tells your right foot what to do.", [
            L.info("The sustain pedal", """
            The right-hand pedal on a piano — the **sustain** or **damper** pedal — lets notes ring on after you release the keys.

            Your Launchkey has a **sustain pedal socket** on the back. With a pedal plugged in, the "Pedal" indicator above the on-screen keyboard lights when you press it. \
            If you do not own a pedal yet, read this lesson and skip the playing steps.

            Keep your heel on the floor and press with the ball of the foot.
            """, glyph: "Ped."),
            L.info("How pedalling is written", """
            Two systems are in use:

            - **Ped. … ✱** — the ornate word **Ped.** means press the pedal; an asterisk-like star means release it.
            - **A bracket line** under the staff — the line drops down where the pedal goes down, runs along while it is held, and ends with an upturn where it lifts. \
            A small upward notch (like an inverted V) in the line means **change**: lift and immediately press again.

            Other words: **con pedale** / **con ped.** — use the pedal as your ear suggests; **senza ped.** — without pedal; **una corda** — the left (soft) pedal; **tre corde** — release it.

            The example shows four chords with a **Ped.** marking under each: a fresh pedal for every chord.
            """, glyph: "Ped. *",
                   example: R.mark(R.example(L.chords(pedalChords), clef: .treble),
                                   markers: [R.below(0, "Ped."), R.below(1, "Ped."), R.below(2, "Ped."), R.below(3, "Ped.")])),
            L.info("Legato pedalling", """
            The essential technique is the **pedal change**. The foot does **not** move with the hands:

            - Play the new chord — **then** let the pedal come up to clear the old sound,
            - and press it down again straight away while the new chord is still held.

            Hands down, foot up–down. "Play… change. Play… change." If you lift the pedal *before* the chord you get a gap; if you never lift you get a blur.
            """),
            R.mark(R.read("Change the pedal on each chord", "Press the pedal, then play the four chords. At each new **Ped.** marking, play the chord first, then lift the pedal and press it again straight away.",
                   L.chords(pedalChords), clef: .treble, targets: true, rules: [.pedalChange]),
                   markers: [R.below(0, "Ped."), R.below(1, "Ped."), R.below(2, "Ped."), R.below(3, "Ped.")]),
            R.mark(R.read("Pedalled bass notes", "Left hand, one note at a time, far apart. The pedal joins them: change it just after each note.",
                   L.line("C3 G2 A2 F2 G2 C3", hand: .left), clef: .bass, targets: true, rules: [.pedalChange]),
                   markers: (0..<6).map { R.below(Double($0), "Ped.") }),
        ])

        let fingering = lesson("reading.ornaments.fingering", "Fingering numbers in the score",
                               "The small digits above the notes, and why you should obey them.", [
            L.info("What the numbers mean", """
            Small digits printed above or below notes are **fingerings**. In both hands:

            **1 = thumb, 2 = index, 3 = middle, 4 = ring, 5 = little finger.**

            They are not rhythm, not counting, and not note names — only which finger plays that note.

            Editors do not number every note. A number appears where the hand must **change position**, **cross**, or do something you would not guess. \
            Between numbers, use neighbouring fingers for neighbouring notes.
            """, glyph: "1 2 3"),
            L.info("Reading the clues", """
            - A **1 after a 3 or 4** going up in the right hand means the thumb passes **under**.
            - A **3 or 4 after a 1** going down in the right hand means that finger crosses **over** the thumb.
            - Two numbers joined by a dash or slur on one note (for example 4–1) mean **swap fingers** silently while holding the key.
            - Stacked numbers on a chord are read bottom to top, matching the notes.

            Use the same fingering every time you practise. Your hand learns the passage as a movement; change the fingering and it has to learn it again.
            """, example: R.example(L.line("C4 D4 E4 F4 G4 A4 B4 C5", fingers: "1 2 3 1 2 3 4 5"), clef: .treble)),
            R.read("Follow the fingering", "The fingering is printed above the staff — the keys are not lit. Note the **1** on F: thumb under.",
                   L.line("C4 D4 E4 F4 G4 A4 B4 C5", fingers: "1 2 3 1 2 3 4 5"), clef: .treble),
            R.read("Coming down", "Descending: after the thumb plays F, finger **3** crosses over onto E.",
                   L.line("C5 B4 A4 G4 F4 E4 D4 C4", fingers: "5 4 3 2 1 3 2 1"), clef: .treble),
            R.read("Left-hand fingering", "Left hand, bass clef. Finger 5 starts; after the thumb on G, finger **3** crosses over to A.",
                   L.line("C3 D3 E3 F3 G3 A3 B3 C4", hand: .left, fingers: "5 4 3 2 1 3 2 1"), clef: .bass),
            R.read("A position shift", "Only the important fingers are marked. The **1** on G tells you to move the whole hand up.",
                   L.melody("C4:q:1 D4:q E4:q F4:q G4:q:1 A4:q B4:q C5:q D5:q:5 B4:q:3 G4:q:1"), clef: .treble),
            R.read("Chord fingering", "Stacked numbers read bottom to top. Use 1-3-5, then 1-2-5, then 1-3-5.",
                   L.chords([Music.notes("C4 E4 G4"), Music.notes("B3 D4 G4"), Music.notes("C4 E4 G4")],
                            fingers: [[1, 3, 5], [1, 2, 5], [1, 3, 5]]), clef: .treble),
        ])
        return unit("reading.ornaments", "Ornaments, pedal and fingering", [trills, turns, pedal, fingering])
    }

    // MARK: - Unit 7: sight-reading

    fileprivate static var readingSightUnit: CurriculumUnit {
        let cPos = R.whites(60, 67)
        let cOct = R.whites(60, 72)
        let bassPos = R.whites(48, 55)
        let gPool = R.scalePool(7, 67, 79)

        let basics = lesson("reading.sight.basics", "How to sight-read",
                            "The method — and the one unbreakable rule: never stop.", [
            L.info("What sight-reading is", """
            **Sight-reading** is playing music you have never seen, at first sight, without stopping. \
            It is a separate skill from learning a piece, and it improves only by doing a little, often, on **easy** material.

            The golden rule: **keep the pulse going**. A wrong note in time is a small mistake. Stopping to fix it is a big one — \
            in a group, everyone else has moved on.

            That is why every exercise here runs against the metronome: the playhead will not wait for you.
            """),
            L.info("The 30-second scan", """
            Before playing a note, look through the music for:

            - **Key signature** — which notes are sharp or flat? Put your hand on them.
            - **Time signature** — how many beats, and what is the shortest note value?
            - **Starting note and hand position** — and the highest and lowest notes: will your hand have to move?
            - **Patterns** — scales, repeated bars, skips.
            - **The hardest bar** — choose a tempo at which you could play *that* bar.

            Then count yourself in and go. The melodies in the following steps are **newly generated every time you open the app**, so you can never memorise them.
            """),
            R.readTimed("Level 1 — five notes, quarter notes", "C position: right thumb on middle C, one finger per key. Scan first, then press Start.",
                        R.phrase(cPos.filter { $0 <= 67 }, "q q q q | q q h | q q q q | h h", maxLeap: 1, endOn: 60), bpm: 60, clef: .treble),
            R.readTimed("Level 1 — again, new notes", "A different melody in the same position. Do not look at your hand: feel the five keys.",
                        R.phrase(cPos.filter { $0 <= 67 }, "q q h | q q q q | h q q | w", maxLeap: 1, endOn: 60), bpm: 60, clef: .treble),
            L.info("If you get lost", """
            You will lose your place sometimes. When it happens:

            - **Keep counting.** Drop out for a beat or two if you must.
            - **Jump back in on the next downbeat** — the first note after a bar line.
            - Play only the **first note of each bar** until you recover.

            Dropping notes to stay in time is the correct choice, every time. (The **Wait for me** option under a timed task is for learning pieces. Leave it off here: sight-reading means the beat does not wait.)
            """),
            R.readTimed("Level 2 — skips and half notes", "Now there are skips (line to line, space to space) across a full octave. Your hand may need to shift.",
                        R.phrase(cOct, "q q h | q q q q | h q q | h. rq", maxLeap: 2), bpm: 63, clef: .treble),
            R.readTimed("Level 2 — rests", "Count through the rests. Lift on the rest; do not hold the previous note over it.",
                        R.phrase(cOct, "q rq q q | h q rq | q q q q | h rh", maxLeap: 2), bpm: 63, clef: .treble),
        ])

        let levels = lesson("reading.sight.levels", "Sight-reading: getting harder",
                            "Bass clef, key signatures, eighth notes and both hands.", [
            L.info("Raising the level", """
            Each step adds one new difficulty. Before each one, do the 30-second scan — and if it goes badly, **lower the tempo** rather than repeating it until you know it. \
            Once you have played a line twice, it is no longer sight-reading.

            A good target is a pass at the first or second attempt.
            """),
            R.readTimed("Level 3 — bass clef", "Left hand: little finger on the C below middle C.",
                        R.phrase(bassPos, "h q q | q q h | q q q q | w", hand: .left, maxLeap: 1, endOn: 48), bpm: 60, clef: .bass),
            R.readTimed("Level 3 — bass clef with skips", "Left hand again, wider range.",
                        R.phrase(R.whites(43, 57), "q q q q | h h | q q h | h. rq", hand: .left, maxLeap: 2), bpm: 60, clef: .bass),
            R.readTimed("Level 4 — key signature and eighth notes", "G major: one sharp, so every F is F♯. Eighth notes go two to a click — count \"1 & 2 &\".",
                        R.phrase(gPool, "q e e q q | e e e e h | q. e q q | h. rq", maxLeap: 1, endOn: 67), bpm: 63, clef: .treble, key: 1),
            R.readTimed("Level 4 — F major in three", "One flat (B♭) and three beats in a bar.",
                        R.phrase(R.scalePool(5, 65, 77), "q q q | h q | q e e q | h.", maxLeap: 1, endOn: 65), bpm: 69, meter: (3, 4), clef: .treble, key: -1),
            R.readTimed("Level 5 — hands taking turns", "Right hand plays bars 1 and 3, left hand answers in bars 2 and 4. Keep both hands in C position, ready.",
                        R.phrase(cPos, "q q q q", maxLeap: 1)
                        + R.phrase(bassPos, "q q h", hand: .left, maxLeap: 1, start: 4)
                        + R.phrase(cPos, "q q h", maxLeap: 1, start: 8)
                        + R.phrase(bassPos, "q q h", hand: .left, maxLeap: 1, start: 12, endOn: 48),
                        bpm: 58, clef: .grand),
            R.readTimed("Level 6 — hands together", "The left hand holds one long note per bar while the right hand moves. Read **vertically**: bottom note first, then the top.",
                        L.together(R.phrase(cPos, "q q q q | q q h | q q q q | w", maxLeap: 1, endOn: 60),
                                   R.phrase([48, 53, 55], "w | w | w | w", hand: .left, maxLeap: 1, endOn: 48)),
                        bpm: 56, clef: .grand, pass: 0.7),
        ])

        let patterns = lesson("reading.sight.patterns", "Reading ahead and spotting patterns",
                              "Read groups of notes — scales, chords and sequences — the way you read whole words.", [
            L.info("Eyes ahead of hands", """
            You read this sentence in words, not letter by letter. Music works the same way.

            Good sight-readers keep their **eyes ahead of their hands** — at least one beat, eventually a whole bar. \
            By the time the fingers play a group, the eyes are already taking in the next one.

            Train it deliberately: as you play beat 1, force your eyes on to beat 2 or 3. And **do not look down** at the keyboard; every glance loses your place.

            The key is recognising a few common shapes instantly.
            """),
            L.info("Pattern 1: scale runs", """
            A run of notes on **every** line and space in a row is a **scale passage**. You only need two facts: where it **starts** and where it **ends**. \
            Everything between is neighbouring keys.
            """, example: R.timedExample(L.melody("G4:e A4:e B4:e C5:e D5:e C5:e B4:e A4:e | G4:w"), bpm: 72, clef: .treble)),
            R.readTimed("Scale runs", "Each bar is one gesture: read the first and last note and let the fingers fill in between.",
                        L.melody("C4:e D4:e E4:e F4:e G4:h | G4:e F4:e E4:e D4:e C4:h | E4:e F4:e G4:e A4:e B4:e C5:e D5:e E5:e | C5:w"),
                        bpm: 63, clef: .treble),
            L.info("Pattern 2: chords", """
            Notes stacked **line–line–line** or **space–space–space** form a **triad** in root position — a "snowman" shape. \
            Read the bottom note; the others are a skip and another skip above it.

            The same three notes spread out one after another are a **broken chord** or **arpeggio**: all skips. Read it as "a C chord", not as C, E, G, C.

            If a stack has a **gap** in it (one larger space between two of the notes), it is an inversion — the same chord rearranged.
            """, example: R.example(L.chords("C4 E4 G4, D4 F4 A4, E4 G4 B4, F4 A4 C5") + L.line("C4 E4 G4 C5", start: 4), clef: .treble)),
            L.quiz("Snowman chords", "A three-note stack appears. Read the bottom note and play all three notes together.", rounds: 8) { _ in
                let roots = R.whites(60, 69)
                let root = R.fresh(roots)
                let pool = R.whites(root, root + 8)
                let chord = [pool[0], pool[2], pool[4]]
                return L.task("Play this chord", "", L.chords([chord]), display: .staff, clef: .treble, showTargets: false)
            },
            R.readTimed("Broken chords", "Bar 1 is a C chord, bar 2 an F chord, bar 3 a G chord. See each bar as one hand shape.",
                        L.melody("C4:q E4:q G4:q E4:q | C4:q F4:q A4:q F4:q | B3:q D4:q G4:q D4:q | C4:q E4:q G4:h"), bpm: 66, clef: .treble),
            L.info("Pattern 3: sequences", """
            A **sequence** is a short shape repeated, each time one step higher or lower. Once you have read the first group, the rest is the same finger pattern moved along.

            In the example the shape "up three notes" starts on C, then D, then E, then F.
            """, example: R.timedExample(L.melody("C4:e D4:e E4:q D4:e E4:e F4:q | E4:e F4:e G4:q F4:e G4:e A4:q"), bpm: 72, clef: .treble)),
            R.readTimed("Sequences", "Spot the repeating shape in the first two beats, then just move it.",
                        L.melody("C4:e D4:e E4:q D4:e E4:e F4:q | E4:e F4:e G4:q F4:e G4:e A4:q | G4:q E4:q F4:q D4:q | E4:q C4:q C4:h"),
                        bpm: 63, clef: .treble),
            R.readTimed("All three patterns", "Scan first: find the scale run, the broken chord and the sequence before you start.",
                        L.melody("C4:e D4:e E4:e F4:e G4:q E4:q | C4:q E4:q G4:q C5:q | A4:e G4:e F4:q G4:e F4:e E4:q | F4:e E4:e D4:q C4:h"),
                        bpm: 63, clef: .treble),
        ])
        return unit("reading.sight", "Sight-reading", [basics, levels, patterns])
    }

    // MARK: - Unit 8: lead sheets and chord symbols

    fileprivate static var readingLeadSheetUnit: CurriculumUnit {
        let triads = lesson("reading.leadsheets.triads", "Chord symbols: triads",
                            "Read C, Cm, C° and C+ and turn them into notes.", [
            L.info("What a lead sheet is", """
            A **lead sheet** shows a song in its simplest form: the **melody** on a single treble staff, with **chord symbols** written above it. \
            Pop, jazz and folk musicians play from these all the time (collections are called *fake books*).

            Nothing tells you exactly which notes to play in the accompaniment. The symbol names a chord; **you** decide how to play it. \
            The first job is to decode the symbols.
            """, glyph: "C  Am"),
            L.info("Major and minor triads", """
            A chord symbol starts with a **root**: a letter, possibly with ♯ or ♭.

            - A letter **alone** means a **major triad**: root, the note 4 half steps up, and the note 7 half steps up. **C** = C E G.
            - A small **m** (or "min" or "–") means a **minor triad**: the middle note is one half step lower. **Cm** = C E♭ G.

            On white keys: C, F and G are major using only white keys; Dm, Em and Am are minor using only white keys.
            """, keys: L.keys("C4 E4 G4"),
                   example: R.example(L.chords([Music.chord(root: 60, type: .major), Music.chord(root: 60, type: .minor),
                                                Music.chord(root: 65, type: .major), Music.chord(root: 62, type: .minor)],
                                               labels: ["C", "Cm", "F", "Dm"]), clef: .treble, flats: true)),
            L.play("Major to minor", "Play each pair: the major triad, then lower the middle note for the minor triad.",
                   L.chords([Music.chord(root: 60, type: .major), Music.chord(root: 60, type: .minor),
                             Music.chord(root: 65, type: .major), Music.chord(root: 65, type: .minor),
                             Music.chord(root: 67, type: .major), Music.chord(root: 67, type: .minor)],
                            labels: ["C", "Cm", "F", "Fm", "G", "Gm"]), display: .staff, clef: .treble, flats: true),
            L.quiz("White-key triads", "The card shows a chord symbol. Play all three notes together — any octave, any order of notes.", rounds: 10) { _ in
                let options: [(Int, ChordType)] = [(0, .major), (2, .minor), (4, .minor), (5, .major), (7, .major), (9, .minor)]
                let choice = options[R.fresh(Array(0..<options.count))]
                return R.chordCard(choice.0, choice.1)
            },
            L.info("Diminished and augmented", """
            Two rarer triads:

            - **dim** or a small circle **°** — **diminished**: a minor triad with the top note lowered too. **Cdim** = C E♭ G♭.
            - **aug** or **+** — **augmented**: a major triad with the top note raised. **Caug** = C E G♯.

            And two that replace the middle note:

            - **sus4** — the 4th instead of the 3rd: **Csus4** = C F G.
            - **sus2** — the 2nd instead of the 3rd: **Csus2** = C D G.
            """, keys: L.keys("C4 Eb4 Gb4", flats: true)),
            L.quiz("Any root, major or minor", "Now the root can be any of the twelve keys. Build major = 4 + 3 half steps, minor = 3 + 4.", rounds: 12) { round in
                R.chordCard(R.fresh(Array(0..<12)), round % 2 == 0 ? .major : .minor)
            },
            L.quiz("Dim, aug and sus", "Mixed triad types.", rounds: 8) { _ in
                R.chordCard(R.pick([0, 2, 4, 5, 7, 9]), R.pick([.diminished, .augmented, .sus4, .sus2]))
            },
        ])

        let sevenths = lesson("reading.leadsheets.sevenths", "Chord symbols: sevenths and beyond",
                              "C7, Cmaj7, Cm7 — and how to read monsters like G7♭9.", [
            L.info("Three kinds of seventh", """
            A **7** adds a fourth note above the triad. The catch: a plain 7 means the **lowered** seventh.

            - **C7** — *dominant seventh*: major triad + the note **two half steps below** the octave. C E G **B♭**.
            - **Cmaj7** (also CM7 or C△) — *major seventh*: major triad + the note **one half step below** the octave. C E G **B**.
            - **Cm7** — *minor seventh*: minor triad + lowered seventh. C E♭ G B♭.

            So "maj" in a chord symbol describes the **seventh**, while "m" describes the **third**.
            """, keys: L.keys("C4 E4 G4 Bb4", flats: true),
                   example: R.example(L.chords([Music.chord(root: 60, type: .dom7), Music.chord(root: 60, type: .maj7),
                                                Music.chord(root: 60, type: .min7)], labels: ["C7", "Cmaj7", "Cm7"]),
                                      clef: .treble, flats: true)),
            L.play("C7, Cmaj7, Cm7", "Play the three seventh chords on C and listen to how different they feel.",
                   L.chords([Music.chord(root: 60, type: .dom7), Music.chord(root: 60, type: .maj7), Music.chord(root: 60, type: .min7)],
                            labels: ["C7", "Cmaj7", "Cm7"]), display: .staff, clef: .treble, flats: true),
            L.quiz("Seventh chord flashcards", "Play all four notes — any octave or inversion.", rounds: 12) { round in
                let types: [ChordType] = [.dom7, .maj7, .min7]
                return R.chordCard(R.pick([0, 2, 4, 5, 7, 9, 10, 3]), types[round % types.count])
            },
            L.info("Reading a long symbol", """
            Decode any symbol **left to right**:

            - **Root** — G
            - **Quality** — nothing (major), m, dim, aug
            - **Seventh** — 7, maj7
            - **Extensions and alterations** — 9, 11, 13, and ♭ or ♯ versions

            **G7♭9** = G dominant seventh (G B D F) plus a **flattened ninth**. The 9th is the note a whole step above the root, an octave up (A); flattened, it is **A♭**. So: G B D F A♭.

            More you will meet:

            - **Cm7♭5** (or a circle with a slash: "half-diminished") — C E♭ G♭ B♭
            - **Cdim7** (C°7) — C E♭ G♭ A: every note 3 half steps apart
            - **C6** — C E G A   ·   **Cm6** — C E♭ G A
            - **C9** — C7 plus D   ·   **Cmaj9** — Cmaj7 plus D
            """, keys: L.keys([55, 59, 62, 65, 68], labels: ["G", "B", "D", "F", "A♭"]),
                   example: R.example(L.chords([Music.chord(root: 55, type: .dom7), Music.chord(root: 55, type: .dom7b9)],
                                               labels: ["G7", "G7♭9"]), clef: .treble, flats: true)),
            L.play("Build G7♭9", "Play G7, then G7♭9: add the A♭ on top (it is a stretch — you may split it between two hands).",
                   L.chords([Music.chord(root: 55, type: .dom7), Music.chord(root: 55, type: .dom7b9)],
                            hand: .either, labels: ["G7", "G7♭9"]), display: .staff, clef: .grand, flats: true),
            L.quiz("Altered and extended chords", "Decode the symbol piece by piece. Use two hands if you like; any octave counts.", rounds: 10) { round in
                let types: [ChordType] = [.halfDim7, .dim7, .six, .dom9, .dom7b9, .min6, .maj9, .dom7sharp9, .min9, .minMaj7]
                return R.chordCard(R.pick([0, 2, 4, 5, 7, 9]), types[round % types.count])
            },
        ])

        let odeMelody = "E4:q E4:q F4:q G4:q | G4:q F4:q E4:q D4:q | C4:q C4:q D4:q E4:q | E4:q. D4:e D4:h"
        let odeChords: [[Int]] = [Music.notes("C3 E3 G3"), Music.notes("G2 B2 D3 F3"), Music.notes("C3 E3 G3"), Music.notes("G2 B2 D3")]
        let odeLabels = ["C", "G7", "C", "G"]
        let playing = lesson("reading.leadsheets.playing", "Playing from a lead sheet",
                             "Slash chords, where chords change, and putting melody and chords together.", [
            L.info("Slash chords", """
            A symbol with a slash, such as **C/E**, means "**C chord over an E bass**": play the chord named on the left, with the single note on the right as the **lowest** note.

            - **C/E** — E in the bass, C chord above.
            - **G/B** — B in the bass, G chord above.
            - **F/C** — C in the bass, F chord above.

            Slash chords make smooth, stepwise bass lines: C – G/B – Am walks the bass down C, B, A.
            """, glyph: "C/E", keys: L.keys([52, 60, 64, 67], labels: ["E", "C", "E", "G"])),
            L.play("C – G/B – Am – C/E", "Left hand plays the single bass note, right hand the chord. Listen to the bass walk down, then leap.",
                   L.together(L.chords([Music.notes("C4 E4 G4"), Music.notes("B3 D4 G4"), Music.notes("C4 E4 A4"), Music.notes("C4 E4 G4")],
                                       labels: ["C", "G/B", "Am", "C/E"]),
                              L.line("C3 B2 A2 E3", hand: .left)), display: .staff, clef: .grand),
            L.info("When do chords change?", """
            A chord symbol is written **above the beat where it starts** and lasts **until the next symbol** — one beat, a bar, or several bars.

            - Slashes in an empty bar ( / / / / ) mean "keep playing this chord for these beats".
            - **N.C.** means *no chord*: play the melody alone.

            The simplest way to play a lead sheet: **right hand melody, left hand chord**, struck on the first beat of each bar and held. \
            Keep the left hand low and compact (around the C below middle C) so it stays out of the melody's way.
            """),
            R.mark(R.readTimed("Step 1 — the melody", "The tune is Beethoven's \"Ode to Joy\", laid out like a lead sheet: melody on the staff, chord symbols above. Read the melody alone first.",
                        L.melody(odeMelody), bpm: 72, clef: .treble),
                   markers: [R.above(0, "C"), R.above(4, "G7"), R.above(8, "C"), R.above(12, "G")]),
            L.quiz("Step 2 — the chords", "These are the four chords of the tune, in order: one per bar. Play each with your left hand (any octave).", rounds: 4) { round in
                let types: [ChordType] = [.major, .dom7, .major, .major]
                let roots = [0, 7, 0, 7]
                return R.chordCard(roots[round % 4], types[round % 4])
            },
            R.mark(R.readTimed("Step 3 — melody and chords", "The chord symbols are printed above the staff. Left hand plays each chord on beat 1 and holds it for the whole bar. If it falls apart, practise with **Left hand** or **Right hand** alone, or turn on **Wait for me**, then come back to both.",
                        L.together(L.chords(odeChords, hand: .left, duration: 4), L.melody(odeMelody)),
                        bpm: 63, clef: .grand, pass: 0.7),
                   markers: zip([0.0, 4, 8, 12], odeLabels).map { R.above($0.0, $0.1) }),
            L.info("Where to go from here", """
            Once block chords feel easy, vary the left hand without changing the harmony:

            - play just the **root** as a bass note,
            - play **root – fifth – root** as a broken pattern,
            - play the chord on beats 1 and 3,
            - choose **inversions** so your hand moves as little as possible between chords.

            The symbols stay the same; the arrangement is yours. That freedom is the whole point of a lead sheet.
            """),
        ])
        return unit("reading.leadsheets", "Lead sheets and chord symbols", [triads, sevenths, playing])
    }

    // MARK: - Unit 9: MIDI drills

    fileprivate static var readingDrillsUnit: CurriculumUnit {
        let notes = lesson("reading.drills.notes", "Drill: note flashcards",
                           "Rapid-fire note reading with live accuracy scoring.", [
            L.info("How the drills work", """
            These are repeatable workouts. Your keyboard is the answer sheet: every card is checked the instant you play, \
            and only a **first-try** correct answer scores.

            - Three stars need 95% first-try accuracy.
            - Cards are random, so run a drill as often as you like.
            - Go for speed only once you are accurate. Aim to answer within about a second.

            A few minutes of these each day does more than one long session a week.
            """),
            L.quiz("Treble sprint", "Fifteen treble-clef notes, including the nearest ledger lines.", rounds: 15) { _ in
                R.card([R.fresh(R.whites(59, 81))], clef: .treble)
            },
            L.quiz("Bass sprint", "Fifteen bass-clef notes, including the nearest ledger lines.", rounds: 15) { _ in
                R.card([R.fresh(R.whites(40, 62))], clef: .bass)
            },
            L.quiz("Grand staff marathon", "Twenty notes anywhere on the grand staff, from low C to high C.", rounds: 20) { _ in
                R.card([R.fresh(R.whites(36, 84))], clef: .grand)
            },
            L.quiz("Three in a row", "Each card has three notes. Read them as a group, then play them in order.", rounds: 10) { round in
                let treble = round % 2 == 0
                let pool = treble ? R.whites(60, 79) : R.whites(41, 60)
                let start = Int.random(in: 2..<(pool.count - 2))
                let a = start
                let b = min(pool.count - 1, max(0, a + R.pick([-2, -1, 1, 2])))
                var c = min(pool.count - 1, max(0, b + R.pick([-2, -1, 1, 2])))
                if c == b { c = b > 0 ? b - 1 : b + 1 }
                return R.card([pool[a], pool[b], pool[c]], clef: treble ? .treble : .bass, title: "Play these notes")
            },
        ])

        let theory = lesson("reading.drills.theory", "Drill: keys, intervals and chords",
                            "Flashcards for key signatures, interval shapes and chord symbols.", [
            L.quiz("Key signature sprint", "Any key signature up to four sharps or flats. Remember what the signature changes.", rounds: 16) { round in
                let options = [1, -1, 2, -2, 3, -3, 4, -4]
                let fifths = options[round % options.count]
                let tonic = ((fifths * 7) % 12 + 12) % 12
                let pool = R.scalePool(tonic, 60, 79)
                let hot = pool.filter { Music.isBlack($0) }
                let note = (Bool.random() && !hot.isEmpty) ? R.pick(hot) : R.pick(pool)
                return R.card([note], clef: .treble, key: fifths)
            },
            L.quiz("Bass key signatures", "The same, in the bass clef.", rounds: 12) { round in
                let options = [1, -1, 2, -2, 3, -3]
                let fifths = options[round % options.count]
                let tonic = ((fifths * 7) % 12 + 12) % 12
                let pool = R.scalePool(tonic, 43, 60)
                let hot = pool.filter { Music.isBlack($0) }
                let note = (Bool.random() && !hot.isEmpty) ? R.pick(hot) : R.pick(pool)
                return R.card([note], clef: .bass, key: fifths)
            },
            L.quiz("Interval sprint", "Two notes, from a step up to an octave. Read the shape, not the names.", rounds: 15) { round in
                let size = R.pick([1, 2, 2, 3, 3, 4, 4, 5, 7])
                let treble = round % 2 == 0
                let pool = treble ? R.whites(60, 81) : R.whites(40, 60)
                let i = Int.random(in: 0..<(pool.count - size))
                let pair = Bool.random() ? [pool[i], pool[i + size]] : [pool[i + size], pool[i]]
                return R.card(pair, clef: treble ? .treble : .bass, title: "Play both notes")
            },
            L.quiz("Chord symbol sprint", "Triads and sevenths on any root. Any octave or inversion counts.", rounds: 15) { _ in
                let type: ChordType = R.pick([.major, .minor, .major, .minor, .dom7, .maj7, .min7, .diminished, .sus4])
                return R.chordCard(R.fresh(Array(0..<12)), type)
            },
            L.quiz("Chords on the staff", "A triad written on the staff, in a key signature. Play all three notes together.", rounds: 10) { round in
                let options = [0, 1, -1, 2, -2]
                let fifths = options[round % options.count]
                let tonic = ((fifths * 7) % 12 + 12) % 12
                let pool = R.scalePool(tonic, 57, 79)
                let i = Int.random(in: 0..<(pool.count - 4))
                return L.task("Play this chord", "", L.chords([[pool[i], pool[i + 2], pool[i + 4]]]), display: .staff,
                              clef: .treble, key: fifths, showTargets: false)
            },
        ])

        let cPos = R.whites(60, 67)
        let sprints = lesson("reading.drills.sightreading", "Drill: sight-reading sprints",
                             "Fresh, never-seen melodies against the clock, scored note by note.", [
            L.info("Fresh material every launch", """
            The melodies below are **generated new each time you open the app**. One attempt each is the honest test — \
            the score you get first time is your sight-reading level today.

            You are scored live on **note accuracy** and **timing**. Remember the rule: never stop, never go back. \
            Use the tempo control to find a speed where you pass first time, then nudge it up over the coming weeks.
            """),
            R.readTimed("Sprint 1 — C position", "Right hand, quarter and half notes.",
                        R.phrase(cPos, "q q q q | h q q | q q h | q q q q | h h | q q q q | q q h | w", maxLeap: 1, endOn: 60),
                        bpm: 72, clef: .treble),
            R.readTimed("Sprint 2 — bass clef", "Left hand.",
                        R.phrase(R.whites(48, 57), "q q h | q q q q | h q q | h. rq | q q q q | h h | q q q q | w", hand: .left, maxLeap: 2, endOn: 48),
                        bpm: 66, clef: .bass),
            R.readTimed("Sprint 3 — D major with eighths", "Two sharps: F♯ and C♯.",
                        R.phrase(R.scalePool(2, 62, 76), "q e e q q | h q q | e e e e q q | h. rq | q q e e q | e e q h | q. e q q | w", maxLeap: 1, endOn: 62),
                        bpm: 66, clef: .treble, key: 2),
            R.readTimed("Sprint 4 — B♭ major in three", "Two flats: B♭ and E♭. Three beats per bar.",
                        R.phrase(R.scalePool(10, 65, 77), "q q q | h q | q e e q | h. | q q q | q e e q | h q | h.", maxLeap: 1, endOn: 70),
                        bpm: 72, meter: (3, 4), clef: .treble, key: -2),
            R.readTimed("Sprint 5 — hands taking turns", "Two bars right hand, two bars left hand, twice.",
                        R.phrase(cPos, "q q q q | q q h", maxLeap: 1)
                        + R.phrase(R.whites(48, 55), "q q q q | q q h", hand: .left, maxLeap: 1, start: 8)
                        + R.phrase(cPos, "q e e q q | h h", maxLeap: 1, start: 16)
                        + R.phrase(R.whites(48, 55), "q q q q | w", hand: .left, maxLeap: 1, start: 24, endOn: 48),
                        bpm: 66, clef: .grand),
            R.readTimed("Sprint 6 — hands together", "Right hand melody over held left-hand notes. Read from the bottom up.",
                        L.together(R.phrase(cPos, "q q q q | h h | q q q q | h. rq | q q h | q q q q | h q q | w", maxLeap: 1, endOn: 60),
                                   R.phrase([48, 52, 53, 55], "w | w | w | w | w | w | w | w", hand: .left, maxLeap: 1, endOn: 48)),
                        bpm: 60, clef: .grand, pass: 0.7),
        ])
        return unit("reading.drills", "MIDI drills: live-scored reading", [notes, theory, sprints])
    }
}
