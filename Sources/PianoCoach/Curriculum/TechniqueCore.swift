import Foundation

// Technique, part one: basic touch, scales and arpeggios.

fileprivate enum TC {
    static let majorNames = ["C", "D♭", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]
    static let minorNames = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "G♯", "A", "B♭", "B"]
    static let slugs = ["c", "db", "d", "eb", "e", "f", "fs", "g", "ab", "a", "bb", "b"]
    /// Lesson order: around the circle of fifths.
    static let circleMajor = [0, 7, 2, 9, 4, 11, 6, 1, 8, 3, 10, 5]
    static let circleMinor = [9, 4, 11, 6, 1, 8, 3, 10, 5, 0, 7, 2]
    static let sharpOrder = ["F♯", "C♯", "G♯", "D♯", "A♯", "E♯", "B♯"]
    static let flatOrder = ["B♭", "E♭", "A♭", "D♭", "G♭", "C♭", "F♭"]

    /// Left-hand starting note for a tonic; the right hand starts an octave above.
    static func low(_ pc: Int) -> Int { pc <= 6 ? 48 + pc : 36 + pc }
    static func high(_ pc: Int) -> Int { low(pc) + 12 }

    static func names(_ notes: [Int], flats: Bool) -> [String] {
        notes.map { Music.name($0, flats: flats, octave: false) }
    }

    static func text(_ fingers: [Int]) -> String {
        fingers.map { "\($0)" }.joined(separator: " ")
    }

    /// Correct spellings of the raised 7th (harmonic/melodic minor) and raised 6th (melodic minor), by tonic.
    static let raisedSeventh = [0: "B♮", 1: "B♯", 2: "C♯", 3: "D♮", 4: "D♯", 5: "E♮", 6: "E♯", 7: "F♯", 8: "F𝄪", 9: "G♯", 10: "A♮", 11: "A♯"]
    static let raisedSixth = [0: "A♮", 1: "A♯", 2: "B♮", 3: "C♮", 4: "C♯", 5: "D♮", 6: "D♯", 7: "E♮", 8: "E♯", 9: "F♯", 10: "G♮", 11: "G♯"]
    /// Where the correct spelling differs from the everyday name of the key: what the key (and this app's staff) shows instead.
    static let everydayName = ["B♯": "C", "E♯": "F", "F𝄪": "G"]

    static func enharmonicNote(_ names: [String]) -> String {
        let odd = names.filter { everydayName[$0] != nil }
        guard !odd.isEmpty else { return "" }
        let parts = odd.map { "**\($0)** is the white key you normally call \(everydayName[$0]!)" }
        return "\n\n" + parts.joined(separator: ", and ") + ". The lit key is labelled with its proper name; the staff in this app shows it as a natural (\(odd.map { everydayName[$0]! + "♮" }.joined(separator: ", ")))."
    }

    static func minorKey(_ pc: Int) -> Int { pc == 3 ? -6 : Music.fifths(minorTonicPC: pc) }

    static func signature(_ key: Int) -> String {
        if key == 0 { return "no sharps or flats" }
        let count = abs(key)
        let list = (key > 0 ? sharpOrder : flatOrder).prefix(count).joined(separator: ", ")
        return "\(count) \(key > 0 ? "sharp" : "flat")\(count == 1 ? "" : "s") (\(list))"
    }

    static func upDown(_ up: [Int]) -> [Int] { up + up.dropLast().reversed() }

    /// One slur over the whole line (drawn on the staff).
    static func slurred(_ events: [ExpectedEvent]) -> [ExpectedEvent] {
        var out = events
        guard out.count > 1 else { return out }
        out[0].slurStart = true
        out[out.count - 1].slurEnd = true
        return out
    }

    /// A scale with its standard fingering attached.
    static func run(_ root: Int, _ type: ScaleType, hand: Hand, octaves: Int = 1, descend: Bool = true,
                    duration: Double = 1) -> [ExpectedEvent] {
        let notes = Music.scale(root: root, type: type, octaves: octaves, descend: descend)
        var fingers = Fingering.scaleRun(tonicPC: Music.pc(root), type: type, hand: hand, octaves: octaves, descend: descend)
        // The F shape (1 2 3 4 1 2 3 4): inside a longer run the key-note is a thumb; finger 4 is only for the very top.
        if hand != .left, octaves > 1, var f = fingers,
           let one = Fingering.scale(tonicPC: Music.pc(root), type: type, hand: hand), one.first == 1, one.last == 4 {
            let top = notes.max() ?? root
            for i in notes.indices where Music.pc(notes[i]) == Music.pc(root) && notes[i] != top { f[i] = 1 }
            fingers = f
        }
        return L.line(notes, hand: hand, fingers: fingers, duration: duration)
    }

    /// Melodic minor: raised 6th and 7th going up, natural minor coming down.
    static func melodic(_ root: Int, hand: Hand, duration: Double = 1) -> [ExpectedEvent] {
        let up = Music.scale(root: root, type: .melodicMinor)
        let down = Array(Music.scale(root: root, type: .naturalMinor).dropLast().reversed())
        let one = Fingering.scale(tonicPC: Music.pc(root), type: .melodicMinor, hand: hand)
        // C♯ and F♯ melodic minor: the raised 6th is a black key, so the right hand regroups on the way up.
        let regroup = hand != .left && [1, 6].contains(Music.pc(root))
        // The top note takes finger 3 so the descent (natural minor) can start 3 2 1.
        let rising: [Int]? = regroup ? [2, 3, 1, 2, 3, 4, 1, 3] : one
        var fingers: [Int]? = nil
        if let rising, let one { fingers = rising + one.dropLast().reversed() }
        return L.line(up + down, hand: hand, fingers: fingers, duration: duration)
    }

    /// Up-and-down line with explicit one-way fingering.
    static func custom(_ up: [Int], _ fingers: [Int], hand: Hand, duration: Double = 1, descend: Bool = true) -> [ExpectedEvent] {
        descend
            ? L.line(upDown(up), hand: hand, fingers: upDown(fingers), duration: duration)
            : L.line(up, hand: hand, fingers: fingers, duration: duration)
    }

    /// C-major fingering for any white key, used when a scale starts on a different degree.
    static func cMajorFingers(_ notes: [Int], hand: Hand) -> [Int] {
        let rh = [0: 1, 2: 2, 4: 3, 5: 1, 7: 2, 9: 3, 11: 4]
        let lh = [0: 1, 2: 4, 4: 3, 5: 2, 7: 1, 9: 3, 11: 2]
        var out = notes.map { (hand == .left ? lh : rh)[Music.pc($0)] ?? 3 }
        guard let top = notes.max(), let bottom = notes.min() else { return out }
        for i in notes.indices {
            if hand == .right, notes[i] == top, Music.pc(top) == 0 { out[i] = 5 }
            if hand == .left, notes[i] == bottom, Music.pc(bottom) == 0 { out[i] = 5 }
        }
        return out
    }

    static func cMajorLine(from start: Int, hand: Hand, duration: Double = 1) -> [ExpectedEvent] {
        let white = upDown(whiteRun(from: start))
        return L.line(white, hand: hand, fingers: cMajorFingers(white, hand: hand), duration: duration)
    }

    /// Eight consecutive white keys starting on `start`.
    static func whiteRun(from start: Int) -> [Int] {
        var out: [Int] = []
        var n = start
        while out.count < 8 {
            if !Music.isBlack(n) { out.append(n) }
            n += 1
        }
        return out
    }

    // MARK: Arpeggios

    /// Fingering for root-third-fifth-octave.
    static func arpFingers(root: Int, type: ChordType, hand: Hand) -> [Int] {
        let notes = Music.chord(root: root, type: type)
        let black = notes.map { Music.isBlack($0) }
        let minor = type == .minor
        if !black[0] || !black.contains(false) {
            if hand != .left { return [1, 2, 3, 5] }
            if !black.contains(false) { return minor ? [5, 4, 2, 1] : [5, 3, 2, 1] }
            return (black[1] && !minor) ? [5, 3, 2, 1] : [5, 4, 2, 1]
        }
        if hand != .left { return black[1] ? [2, 3, 1, 2] : [2, 1, 2, 4] }
        if black[1] || !black[2] { return [3, 2, 1, 3] }
        return [2, 1, 4, 2]
    }

    static func arp(_ root: Int, _ type: ChordType, hand: Hand, duration: Double = 1) -> [ExpectedEvent] {
        let up = Music.arpeggio(root: root, type: type)
        return custom(up, arpFingers(root: root, type: type, hand: hand), hand: hand, duration: duration)
    }

    /// Root position, first inversion, second inversion, root position an octave up.
    static func inversions(_ root: Int, _ type: ChordType) -> [[Int]] {
        [Music.chord(root: root, type: type), Music.chord(root: root, type: type, inversion: 1),
         Music.chord(root: root, type: type, inversion: 2), Music.chord(root: root + 12, type: type)]
    }

    static let rhBlockFingers: [[Int]] = [[1, 3, 5], [1, 2, 5], [1, 3, 5], [1, 3, 5]]
    static let lhBlockFingers: [[Int]] = [[5, 3, 1], [5, 3, 1], [5, 2, 1], [5, 3, 1]]
}

extension Curriculum {
    static var techniqueCore: [CurriculumUnit] {
        [tcBasicUnit, tcMajorUnit, tcMinorUnit, tcScaleSkillsUnit, tcColourScalesUnit, tcModesUnit, tcJazzUnit, tcArpeggioUnit,
         tcArpeggioKeysUnit]
    }

    // MARK: - Basic

    fileprivate static var tcBasicUnit: CurriculumUnit {
        unit("technique.basic", "Basic technique", [
            tcIndependenceLesson, tcCrossingLesson, tcTouchLesson, tcHandsTogetherLesson, tcMotionLesson,
        ])
    }

    fileprivate static var tcIndependenceLesson: Lesson {
        var steps: [Step] = []
        steps.append(L.info("One finger moves, four stay quiet", """
            Finger independence means each finger can play on its own while the others rest lightly on their keys. It is the base of every scale and melody.

            - Keep all five fingertips touching their keys (C D E F G), fingers curved.
            - Play from the knuckle: the finger drops, the wrist and arm stay loose.
            - Fingers 4 and 5 are the weakest. Do not push harder with the arm to help them — let them be a little slower at first.
            - Strength at the piano is control, not force. Stop if anything aches.
            """, keys: L.keys(Music.notes("C4 D4 E4 F4 G4"), labels: ["1", "2", "3", "4", "5"], hand: .right)))
        steps.append(L.play("Right hand: walk up and down", "Place the right thumb on middle C. Play each finger in turn, up and back, keeping the others resting on their keys.",
                            L.line("C4 D4 E4 F4 G4 F4 E4 D4 C4", hand: .right, fingers: "1 2 3 4 5 4 3 2 1")))
        steps.append(L.play("Left hand: walk up and down", "Left little finger on the C below middle C. Same idea: one finger at a time.",
                            L.line("C3 D3 E3 F3 G3 F3 E3 D3 C3", hand: .left, fingers: "5 4 3 2 1 2 3 4 5")))
        steps.append(L.play("Skipping fingers", "Now skip: 1-3, 2-4, 3-5 and back. The finger in between stays down on the surface of its key without pressing.",
                            L.line("C4 E4 D4 F4 E4 G4 F4 D4 E4 C4", hand: .right, fingers: "1 3 2 4 3 5 4 2 3 1")))
        steps.append(L.play("Weak-finger workout", "Fingers 3, 4 and 5 only. Aim for the same loudness on every note — the result shows how even your touch was.",
                            L.line("E4 F4 G4 F4 E4 F4 G4 F4 E4 F4 G4 F4 E4", hand: .right, fingers: "3 4 5 4 3 4 5 4 3 4 5 4 3"),
                            rules: [.evenVelocity(maxStdDev: 12)]))
        steps.append(L.play("Left-hand weak fingers", "The same workout for left-hand fingers 5, 4 and 3.",
                            L.line("C3 D3 E3 D3 C3 D3 E3 D3 C3 D3 E3 D3 C3", hand: .left, fingers: "5 4 3 4 5 4 3 4 5 4 3 4 5"),
                            rules: [.evenVelocity(maxStdDev: 12)]))
        let pattern = L.line("C4 E4 D4 F4 E4 G4 F4 D4 C4 E4 D4 F4 E4 G4 F4 D4", hand: .right,
                             fingers: "1 3 2 4 3 5 4 2 1 3 2 4 3 5 4 2", duration: 0.5)
        steps.append(L.timed("Even eighth notes", "Play the skipping pattern as steady eighth notes (two per click). Every note the same loudness.",
                             pattern + L.line("C4", hand: .right, fingers: "1", duration: 1, start: 8),
                             bpm: 66, display: .staffAndRhythm, clef: .treble, rules: [.evenVelocity(maxStdDev: 12)]))
        return lesson("technique.basic.independence", "Finger independence and strength",
                      "Each finger plays alone, evenly, while the others stay relaxed.", steps)
    }

    fileprivate static var tcCrossingLesson: Lesson {
        var steps: [Step] = []
        steps.append(L.info("Running out of fingers", """
            A scale has more notes than you have fingers. The solution is a **crossing**:

            - **Thumb under**: when the right hand climbs or the left hand descends, the thumb slides under the hand to take the next key.
            - **Finger over**: going the other way (right hand descending, left hand climbing), finger 3 or 4 swings over the thumb.

            Start moving the thumb early — as soon as finger 2 plays, the thumb is already travelling under. Keep the wrist level and the elbow quiet; the hand should not twist or bump.
            """, keys: L.keys(Music.notes("C4 D4 E4 F4"), labels: ["1", "2", "3", "1"], hand: .right)))
        steps.append(L.play("Thumb under (right hand)", "Play C D E with 1 2 3, then tuck the thumb under to F. Repeat the crossing a few times.",
                            L.line("C4 D4 E4 F4 E4 F4 E4 F4 G4", hand: .right, fingers: "1 2 3 1 3 1 3 1 2")))
        steps.append(L.play("Finger over (right hand)", "Coming down: when the thumb plays F, swing finger 3 over it to E.",
                            L.line("G4 F4 E4 D4 C4 D4 E4 F4 E4 D4 C4", hand: .right, fingers: "2 1 3 2 1 2 3 1 3 2 1")))
        steps.append(L.play("Thumb under finger 4", "In the top half of a scale the thumb passes under finger 4 — a slightly bigger move. F G A B, then thumb on C.",
                            L.line("F4 G4 A4 B4 C5 B4 A4 G4 F4", hand: .right, fingers: "1 2 3 4 1 4 3 2 1")))
        steps.append(L.play("Left hand: finger over, thumb under", "The left hand mirrors the right. Going up, finger 3 crosses over the thumb (G to A). Coming down, the thumb goes under.",
                            L.line("C3 D3 E3 F3 G3 A3 G3 A3 G3 F3 E3 D3 C3", hand: .left, fingers: "5 4 3 2 1 3 1 3 1 2 3 4 5")))
        steps.append(L.play("The full C major scale, right hand", "Put it together: 1 2 3, thumb under, 1 2 3 4 5 — and back with 3 over the thumb. Connect every note.",
                            TC.run(60, .major, hand: .right), display: .staff, clef: .treble, rules: [.legato]))
        steps.append(L.play("The full C major scale, left hand", "5 4 3 2 1, then 3 over, 3 2 1 — and back with the thumb under.",
                            TC.run(48, .major, hand: .left), display: .staff, clef: .bass, rules: [.legato]))
        steps.append(L.timed("Crossings in time", "Right hand, one note per click. Listen for a bump at the crossing: the thumb note should be no louder than its neighbours.",
                             TC.run(60, .major, hand: .right), bpm: 76, display: .staffAndRhythm, clef: .treble,
                             rules: [.evenVelocity(maxStdDev: 12)]))
        return lesson("technique.basic.crossings", "Thumb-under and finger-over crossings",
                      "Pass the thumb under and the fingers over without bumps.", steps)
    }

    fileprivate static var tcTouchLesson: Lesson {
        var steps: [Step] = []
        steps.append(L.info("Legato: joined notes", """
            **Legato** means smooth and connected. One finger goes down exactly as the previous one comes up, like walking — there is always one foot on the ground.

            In the score, legato is shown by a **slur**: a curved line over the notes.

            The app measures the gap between releasing one key and pressing the next. For legato there should be no gap at all; a tiny overlap is fine.
            """, glyph: "legato",
            example: L.timedTask("Legato", "", TC.slurred(L.line("C4 D4 E4 F4 G4", hand: .right, duration: 1)), bpm: 90, display: .staff)))
        steps.append(L.play("Legato, right hand", "Play up and down, handing each note to the next with no silence between them.",
                            L.line("C4 D4 E4 F4 G4 F4 E4 D4 C4", hand: .right, fingers: "1 2 3 4 5 4 3 2 1"), rules: [.legato]))
        steps.append(L.play("Legato, left hand", "The same in the left hand.",
                            L.line("C3 D3 E3 F3 G3 F3 E3 D3 C3", hand: .left, fingers: "5 4 3 2 1 2 3 4 5"), rules: [.legato]))
        var staccatoExample = L.line("C4 D4 E4 F4 G4", hand: .right, duration: 1)
        for i in staccatoExample.indices { staccatoExample[i].articulation = .staccato }
        steps.append(L.info("Staccato: short notes", """
            **Staccato** means detached. Each note is released almost at once, leaving silence before the next. In the score it is a dot above or below the note head.

            Think of touching something hot: the finger springs back up. Keep the wrist loose and stay close to the keys — staccato is short, not loud.
            """, glyph: "stacc.",
            example: L.timedTask("Staccato", "", staccatoExample, bpm: 90, display: .staff)))
        var staccatoRight = L.line("C4 D4 E4 F4 G4 F4 E4 D4 C4", hand: .right, fingers: "1 2 3 4 5 4 3 2 1")
        for i in staccatoRight.indices { staccatoRight[i].articulation = .staccato }
        steps.append(L.play("Staccato, right hand", "Play the same notes short and light. Release each key quickly.",
                            staccatoRight, rules: [.staccato]))
        var staccatoLeft = L.line("C3 D3 E3 F3 G3 F3 E3 D3 C3", hand: .left, fingers: "5 4 3 2 1 2 3 4 5")
        for i in staccatoLeft.indices { staccatoLeft[i].articulation = .staccato }
        steps.append(L.play("Staccato, left hand", "Short and light in the left hand.", staccatoLeft, rules: [.staccato]))
        steps.append(L.timed("Legato with the metronome", "One note per click, perfectly joined.",
                             TC.slurred(L.line("C4 D4 E4 F4 G4 F4 E4 D4 C4 D4 E4 F4 G4 F4 E4 D4", hand: .right,
                                               fingers: "1 2 3 4 5 4 3 2 1 2 3 4 5 4 3 2")),
                             bpm: 80, display: .staffAndRhythm, clef: .treble, rules: [.legato]))
        var timedStaccato = L.line("C4 D4 E4 F4 G4 F4 E4 D4 C4 D4 E4 F4 G4 F4 E4 D4", hand: .right,
                                   fingers: "1 2 3 4 5 4 3 2 1 2 3 4 5 4 3 2")
        for i in timedStaccato.indices { timedStaccato[i].articulation = .staccato }
        steps.append(L.timed("Staccato with the metronome", "The same notes, now short. The notes still land exactly on the click — only their length changes.",
                             timedStaccato, bpm: 80, display: .staffAndRhythm, clef: .treble, rules: [.staccato]))
        return lesson("technique.basic.touch", "Legato and staccato touch",
                      "Connect notes smoothly, then play them short and detached.", steps)
    }

    fileprivate static var tcHandsTogetherLesson: Lesson {
        var steps: [Step] = []
        steps.append(L.info("Two hands, one brain", """
            Playing hands together is a coordination skill, and it is learned slowly.

            - Learn each hand **separately** first until it is easy.
            - Then combine at half speed. Think of the two hands as one event: "together, together, right, together".
            - Look for where the hands land **at the same time** and where one moves alone.
            - If it falls apart, the tempo is too fast. Slow down rather than repeat mistakes.

            The timed tasks give you three helpers: **Right hand / Left hand / Both** (the app plays the hand you leave out), **Wait for me** (the music pauses until you find each note), and **Loop bars** (repeat a tricky bar, speeding up as you get it clean).
            """))
        steps.append(L.play("Same notes, both hands", "Both hands play C D E F G together, an octave apart. Notice the fingers are mirrored: right hand 1 2 3 4 5, left hand 5 4 3 2 1.",
                            L.together(L.line("C4 D4 E4 F4 G4 F4 E4 D4 C4", hand: .right, fingers: "1 2 3 4 5 4 3 2 1"),
                                       L.line("C3 D3 E3 F3 G3 F3 E3 D3 C3", hand: .left, fingers: "5 4 3 2 1 2 3 4 5")),
                            display: .staff))
        steps.append(L.timed("Left hand holds, right hand moves", "The left hand plays one long note per bar while the right hand plays a note on every click.",
                             L.together(L.melody("C4:q:1 D4:q:2 E4:q:3 F4:q:4 G4:q:5 F4:q:4 E4:q:3 D4:q:2 C4:w:1", hand: .right),
                                        L.melody("C3:w:5 G3:w:1 C3:w:5", hand: .left)),
                             bpm: 72, display: .staffAndRhythm))
        steps.append(L.timed("Right hand holds, left hand moves", "Now swap roles: the right hand holds while the left hand walks.",
                             L.together(L.melody("E4:w:3 D4:w:2 C4:w:1", hand: .right),
                                        L.melody("C3:q:5 D3:q:4 E3:q:3 F3:q:2 G3:q:1 F3:q:2 E3:q:3 D3:q:4 C3:w:5", hand: .left)),
                             bpm: 72, display: .staffAndRhythm))
        steps.append(L.timed("Taking turns", "The hands alternate, one bar each. Keep the pulse steady across the hand-over.",
                             L.together(L.melody("C4:q:1 D4:q:2 E4:q:3 F4:q:4 r:w G4:q:5 F4:q:4 E4:q:3 D4:q:2 r:w", hand: .right),
                                        L.melody("r:w G3:q:1 F3:q:2 E3:q:3 D3:q:4 r:w C3:h:5 C3:h:5", hand: .left)),
                             bpm: 76, display: .staffAndRhythm))
        steps.append(L.timed("Ode to Joy, hands together", "Beethoven's tune in the right hand over two slow left-hand notes per bar. Press **Demo** to hear it. To learn the hands separately, choose **Right hand** or **Left hand** under the task and the app plays the other part.",
                             L.together(
                                L.melody("E4:q:3 E4:q:3 F4:q:4 G4:q:5 G4:q:5 F4:q:4 E4:q:3 D4:q:2 C4:q:1 C4:q:1 D4:q:2 E4:q:3 E4:q.:3 D4:e:2 D4:h:2", hand: .right),
                                L.melody("C3:h:5 G3:h:1 C3:h:5 G3:h:1 C3:h:5 G3:h:1 C3:h:5 G3:h:1", hand: .left)),
                             bpm: 76, display: .staffAndRhythm))
        return lesson("technique.basic.together", "Hands-together coordination",
                      "Combine the hands: same rhythm, different rhythms, and a first two-hand tune.", steps)
    }

    fileprivate static var tcMotionLesson: Lesson {
        var steps: [Step] = []
        steps.append(L.info("Parallel and contrary motion", """
            When both hands move in the **same direction** it is **parallel motion**. The notes match but the fingers do not: as the right hand goes 1 2 3, the left goes 5 4 3.

            When the hands move in **opposite directions** it is **contrary motion**. Now the fingers match — both thumbs, both 2s, both 3s — which makes it feel surprisingly natural.
            """, keys: L.keys(Music.notes("F3 G3 A3 B3 C4"), labels: ["5", "4", "3", "2", "1"], hand: .left)
                + L.keys(Music.notes("E4 F4 G4 A4 B4"), labels: ["1", "2", "3", "4", "5"], hand: .right)))
        steps.append(L.play("Parallel motion", "Both hands rise and fall together, an octave apart.",
                            L.together(L.line("C4 D4 E4 F4 G4 F4 E4 D4 C4", hand: .right, fingers: "1 2 3 4 5 4 3 2 1"),
                                       L.line("C3 D3 E3 F3 G3 F3 E3 D3 C3", hand: .left, fingers: "5 4 3 2 1 2 3 4 5")),
                            display: .staff))
        steps.append(L.play("Contrary motion", "Thumbs start side by side (left on middle C, right on E). The hands open outwards, then close again. Matching fingers play together.",
                            L.together(L.line("E4 F4 G4 A4 B4 A4 G4 F4 E4", hand: .right, fingers: "1 2 3 4 5 4 3 2 1"),
                                       L.line("C4 B3 A3 G3 F3 G3 A3 B3 C4", hand: .left, fingers: "1 2 3 4 5 4 3 2 1")),
                            display: .staff))
        steps.append(L.play("C major scale in contrary motion", "Both thumbs on a C (an octave apart). Right hand climbs, left hand descends, with identical fingering: 1 2 3, thumb under, 1 2 3 4 5.",
                            tcContraryEvents(0, type: .major),
                            display: .staff))
        steps.append(L.timed("Parallel, in time", "Parallel motion with the metronome.",
                             L.together(L.line("C4 D4 E4 F4 G4 F4 E4 D4 C4 D4 E4 F4 G4 F4 E4 D4", hand: .right,
                                               fingers: "1 2 3 4 5 4 3 2 1 2 3 4 5 4 3 2"),
                                        L.line("C3 D3 E3 F3 G3 F3 E3 D3 C3 D3 E3 F3 G3 F3 E3 D3", hand: .left,
                                               fingers: "5 4 3 2 1 2 3 4 5 4 3 2 1 2 3 4")),
                             bpm: 72, display: .staffAndRhythm))
        steps.append(L.timed("Contrary, in time", "Contrary motion with the metronome. Aim for both hands sounding exactly together.",
                             L.together(L.line("E4 F4 G4 A4 B4 A4 G4 F4 E4 F4 G4 A4 B4 A4 G4 F4", hand: .right,
                                               fingers: "1 2 3 4 5 4 3 2 1 2 3 4 5 4 3 2"),
                                        L.line("C4 B3 A3 G3 F3 G3 A3 B3 C4 B3 A3 G3 F3 G3 A3 B3", hand: .left,
                                               fingers: "1 2 3 4 5 4 3 2 1 2 3 4 5 4 3 2")),
                             bpm: 72, display: .staffAndRhythm))
        return lesson("technique.basic.motion", "Contrary and parallel motion",
                      "Move the hands in the same direction, then in mirror image.", steps)
    }

    // MARK: - Major scales

    fileprivate static var tcMajorUnit: CurriculumUnit {
        unit("technique.major", "Major scales in all 12 keys", TC.circleMajor.map { tcMajorLesson($0) })
    }

    fileprivate static func tcMajorLesson(_ pc: Int) -> Lesson {
        let name = TC.majorNames[pc]
        let flats = Music.prefersFlats(tonicPC: pc)
        let key = Music.fifths(majorTonicPC: pc)
        let lo = TC.low(pc)
        let hi = TC.high(pc)
        let rhFingers = Fingering.scale(tonicPC: pc, type: .major, hand: .right) ?? []
        let lhFingers = Fingering.scale(tonicPC: pc, type: .major, hand: .left) ?? []
        let octave = Music.scale(root: hi, type: .major)
        var labels = TC.names(octave, flats: flats)
        if pc == 6 { labels[6] = "E♯" }
        let rhThumbs = zip(labels, rhFingers).filter { $0.1 == 1 }.map { $0.0 }.joined(separator: " and ")
        let lhThumbs = zip(labels, lhFingers).filter { $0.1 == 1 }.map { $0.0 }.joined(separator: " and ")
        var extra = ""
        if pc == 6 { extra = "\n\nThe seventh note is **E♯**. It is the white key you usually call F — in this key every letter name is used once, so it has to be some kind of E." }
        if !Music.isBlack(pc) && key != 0 && rhFingers == [1, 2, 3, 1, 2, 3, 4, 5] {
            extra += "\n\nThe fingering is the same as C major — only the black keys change."
        }
        if Music.isBlack(pc) {
            extra += "\n\nBecause the scale starts on a black key, the thumbs wait for the white keys: long fingers on black keys, thumbs on white."
        }

        var steps: [Step] = []
        steps.append(L.info("The key of \(name) major", """
            \(name) major has \(TC.signature(key)). Its notes are **\(labels.dropLast().joined(separator: " "))**.

            - Right hand: **\(TC.text(rhFingers))** — thumb on \(rhThumbs).
            - Left hand: **\(TC.text(lhFingers))** — thumb on \(lhThumbs).\(extra)
            """, keys: L.keys(octave, labels: labels, hand: .right),
            example: L.timedTask("\(name) major", "", TC.run(hi, .major, hand: .right, duration: 0.5), bpm: 96,
                                 display: .staff, clef: .treble, key: key, flats: flats)))
        steps.append(L.play("Right hand", "Up and down one octave. Follow the finger numbers on the lit keys and keep it legato.",
                            TC.run(hi, .major, hand: .right), display: .staff, clef: .treble, key: key, flats: flats))
        steps.append(L.play("Left hand", "Up and down one octave with the left hand.",
                            TC.run(lo, .major, hand: .left), display: .staff, clef: .bass, key: key, flats: flats))
        steps.append(L.play("Hands together", "Both hands, an octave apart. Go slowly — the lesson waits for you. The crossings happen at different moments in each hand.",
                            L.together(TC.run(hi, .major, hand: .right), TC.run(lo, .major, hand: .left)),
                            display: .staff, key: key, flats: flats))
        steps.append(L.timed("Hands together with the metronome", "One note per click. If the hands tangle, choose **Right hand** or **Left hand** under the task (the app plays the other part) or switch on **Wait for me**. Lower the tempo with BPM − if you need to — clean and slow beats fast and messy.",
                             L.together(TC.run(hi, .major, hand: .right), TC.run(lo, .major, hand: .left)),
                             bpm: 66, display: .staff, key: key, flats: flats))
        steps.append(L.timed("Two octaves, even eighth notes", "Right hand, two octaves, two notes per click. Every note should be equally loud. If one bar keeps tripping you, use **Loop bars** on it. When the whole run is easy, raise the tempo a notch with BPM +.",
                             TC.run(hi, .major, hand: .right, octaves: 2, duration: 0.5),
                             bpm: 72, display: .staff, clef: .treble, key: key, flats: flats,
                             rules: [.evenVelocity(maxStdDev: 12)]))
        return lesson("technique.major.\(TC.slugs[pc])", "\(name) major",
                      "\(name) major scale: each hand, hands together, then in time.", steps)
    }

    // MARK: - Minor scales

    fileprivate static var tcMinorUnit: CurriculumUnit {
        unit("technique.minor", "Minor scales in all 12 keys", TC.circleMinor.map { tcMinorLesson($0) })
    }

    fileprivate static func tcMinorLesson(_ pc: Int) -> Lesson {
        let name = TC.minorNames[pc]
        let flats = Music.prefersFlats(tonicPC: pc, minor: true)
        let key = TC.minorKey(pc)
        let lo = TC.low(pc)
        let hi = TC.high(pc)
        let relative = TC.majorNames[(pc + 3) % 12]
        let natural = Music.scale(root: hi, type: .naturalMinor)
        let harmonic = Music.scale(root: hi, type: .harmonicMinor)
        let melodic = Music.scale(root: hi, type: .melodicMinor)
        var labels = TC.names(natural, flats: flats)
        if pc == 3 { labels[5] = "C♭" }
        let rhFingers = Fingering.scale(tonicPC: pc, type: .naturalMinor, hand: .right) ?? []
        let lhFingers = Fingering.scale(tonicPC: pc, type: .naturalMinor, hand: .left) ?? []
        let seventh = TC.raisedSeventh[pc] ?? Music.name(harmonic[6], flats: false, octave: false)
        let sixth = TC.raisedSixth[pc] ?? Music.name(melodic[5], flats: false, octave: false)
        let regrouped = [1, 6].contains(pc)
        let fingeringNote = regrouped
            ? "This fingering serves the natural and harmonic forms. Going up the melodic minor, the right hand regroups to **2 3 1 2 3 4 1 3** so the thumb stays off the raised 6th (a black key)."
            : "The same fingering serves all three forms of the minor scale."
        let cFlatNote = pc == 3 ? "\n\nThe sixth note is **C♭** — the white key you normally call B." : ""

        var steps: [Step] = []
        steps.append(L.info("\(name) natural minor", """
            \(name) minor shares its key signature with \(relative) major: \(TC.signature(key)). The **natural minor** uses exactly those notes: **\(labels.dropLast().joined(separator: " "))**.

            - Right hand: **\(TC.text(rhFingers))**
            - Left hand: **\(TC.text(lhFingers))**

            \(fingeringNote)\(cFlatNote)
            """, keys: L.keys(natural, labels: labels, hand: .right),
            example: L.timedTask("\(name) natural minor", "", TC.run(hi, .naturalMinor, hand: .right, duration: 0.5), bpm: 96,
                                 display: .staff, clef: .treble, key: key, flats: flats)))
        steps.append(L.play("Natural minor, right hand", "Up and down one octave.",
                            TC.run(hi, .naturalMinor, hand: .right), display: .staff, clef: .treble, key: key, flats: flats))
        steps.append(L.play("Natural minor, left hand", "Up and down one octave.",
                            TC.run(lo, .naturalMinor, hand: .left), display: .staff, clef: .bass, key: key, flats: flats))
        steps.append(L.info("\(name) harmonic minor", """
            The **harmonic minor** raises the 7th note by a half step, here to **\(seventh)**. That creates a strong pull back to \(name) — and a wide, exotic-sounding gap of three half steps between the 6th and 7th notes.

            Stretch gently across the gap; do not jab at the raised note.\(TC.enharmonicNote([seventh]))
            """, keys: L.keys(harmonic, labels: labels.enumerated().map { $0.offset == 6 ? seventh : $0.element }, hand: .right),
            example: L.timedTask("\(name) harmonic minor", "", TC.run(hi, .harmonicMinor, hand: .right, duration: 0.5), bpm: 96,
                                 display: .staff, clef: .treble, key: key, flats: flats)))
        steps.append(L.play("Harmonic minor, hands together", "Both hands, an octave apart, up and down.",
                            L.together(TC.run(hi, .harmonicMinor, hand: .right), TC.run(lo, .harmonicMinor, hand: .left)),
                            display: .staff, key: key, flats: flats))
        steps.append(L.info("\(name) melodic minor", """
            The **melodic minor** smooths out that gap. Going **up**, both the 6th and 7th are raised (**\(sixth)** and **\(seventh)**). Coming **down**, it returns to the natural minor.

            So the scale is different in each direction — listen for the brighter climb and the darker descent.\(TC.enharmonicNote([sixth, seventh]))
            """, keys: L.keys(melodic, labels: labels.enumerated().map { $0.offset == 5 ? sixth : $0.offset == 6 ? seventh : $0.element }, hand: .right),
            example: L.timedTask("\(name) melodic minor", "", TC.melodic(hi, hand: .right, duration: 0.5), bpm: 96,
                                 display: .staff, clef: .treble, key: key, flats: flats)))
        steps.append(L.play("Melodic minor, right hand", regrouped ? "Raised 6th and 7th on the way up with the regrouped fingering (2 3 1 2 3 4 1 3), natural minor on the way down." : "Raised 6th and 7th on the way up, natural minor on the way down.",
                            TC.melodic(hi, hand: .right), display: .staff, clef: .treble, key: key, flats: flats))
        steps.append(L.play("Melodic minor, left hand", "The same in the left hand.",
                            TC.melodic(lo, hand: .left), display: .staff, clef: .bass, key: key, flats: flats))
        steps.append(L.timed("Harmonic minor in time", "Hands together with the metronome, one note per click, evenly. Use **Right hand** / **Left hand** (the app plays the other part) or **Wait for me** if you need a step in between.",
                             L.together(TC.run(hi, .harmonicMinor, hand: .right), TC.run(lo, .harmonicMinor, hand: .left)),
                             bpm: 66, display: .staff, key: key, flats: flats, rules: [.evenVelocity(maxStdDev: 12)]))
        return lesson("technique.minor.\(TC.slugs[pc])", "\(name) minor",
                      "\(name) minor in its natural, harmonic and melodic forms.", steps)
    }

    // MARK: - Scale skills: fingering rules, intervals apart, contrary motion, chromatic

    fileprivate static var tcScaleSkillsUnit: CurriculumUnit {
        unit("technique.scaleskills", "Scale fingering and formats", [
            tcFingeringLesson, tcIntervalsLesson, tcContraryLesson, tcChromaticLesson,
        ])
    }

    fileprivate static var tcFingeringLesson: Lesson {
        var steps: [Step] = []
        steps.append(L.info("Why scale fingerings are standard", """
            Every seven-note scale is fingered as one group of **three** (1 2 3) and one group of **four** (1 2 3 4). The only question is where the groups start. Three rules decide it:

            - The **thumb never plays a black key** in a scale.
            - The **4th finger plays only once per octave**. If you know where 4 goes, you know the whole fingering.
            - The 5th finger is used only to start or finish.

            Learn the families below and you will not need to memorise twelve separate fingerings.
            """))
        steps.append(L.info("Family 1: the C group", """
            **C, G, D, A and E major** (and the minors on A, E, D, G, C) all use the same shape:

            - Right hand: **1 2 3 1 2 3 4 5**
            - Left hand: **5 4 3 2 1 3 2 1**

            The right-hand 4th finger is on the 7th note; the left-hand 4th finger is on the 2nd note.
            """, keys: L.keys(Music.scale(root: 62, type: .major), labels: ["1", "2", "3", "1", "2", "3", "4", "5"], hand: .right)))
        steps.append(L.play("C group: D major, right hand", "The C-major fingering on D major. Fingers 3 and 4 land on the black keys.",
                            TC.run(62, .major, hand: .right), display: .staff, clef: .treble, key: 2))
        steps.append(L.info("The exceptions: B and F", """
            Two white-key scales bend the pattern so a thumb avoids a black key:

            - **F major, right hand: 1 2 3 4 1 2 3 4** — the group of four comes first, because B♭ needs finger 4.
            - **B major, left hand: 4 3 2 1 4 3 2 1** — it starts on 4 so the thumb lands on E and B.

            The other hand keeps the C-group fingering in both keys.
            """, keys: L.keys(Music.scale(root: 65, type: .major), labels: ["1", "2", "3", "4", "1", "2", "3", "4"], hand: .right)))
        steps.append(L.play("F major, right hand", "Four fingers first: 1 2 3 4, then thumb under to C.",
                            TC.run(65, .major, hand: .right), display: .staff, clef: .treble, key: -1))
        steps.append(L.play("B major, left hand", "Start on finger 4. The thumb plays E and B.",
                            TC.run(47, .major, hand: .left), display: .staff, clef: .bass, key: 5))
        steps.append(L.info("Family 2: black-key scales", """
            In scales that start on a black key, the fingers arrange themselves around the black-key groups:

            - **Right hand**: the 4th finger always plays **B♭ (A♯)**. Fingers 2 3 take the group of two black keys, 2 3 4 the group of three.
            - **Left hand** (flat keys B♭, E♭, A♭, D♭): start on **3**, and the 4th finger plays the **4th note** of the scale. F♯ major starts on 4.
            - The thumbs take the white keys in between.

            Example — E♭ major, right hand: **3 1 2 3 4 1 2 3**.
            """, keys: L.keys(Music.scale(root: 63, type: .major), labels: ["3", "1", "2", "3", "4", "1", "2", "3"], hand: .right)))
        steps.append(L.play("E♭ major, right hand", "Start on finger 3. The 4th finger plays B♭.",
                            TC.run(63, .major, hand: .right), display: .staff, clef: .treble, key: -3))
        steps.append(L.play("A♭ major, left hand", "Start on finger 3; the 4th finger plays D♭, the 4th note.",
                            TC.run(44, .major, hand: .left), display: .staff, clef: .bass, key: -4))
        steps.append(L.play("F♯ major, right hand", "All five black keys. 2 3 4 on the group of three, 2 3 on the group of two, thumbs on B and E♯ (F).",
                            TC.run(66, .major, hand: .right), display: .staff, clef: .treble, key: 6))
        return lesson("technique.scaleskills.fingering", "Standard fingerings per key",
                      "The rules and families behind every scale fingering.", steps)
    }

    fileprivate static var tcIntervalsLesson: Lesson {
        let rhOct = TC.cMajorLine(from: 60, hand: .right)
        let lhOct = TC.cMajorLine(from: 48, hand: .left)
        var steps: [Step] = []
        steps.append(L.info("Scales at different distances", """
            So far both hands played the same note an octave apart. Advanced scale practice changes the distance between the hands:

            - **An octave apart**: the standard form.
            - **In thirds**: the right hand starts a third above the left (C with E), so the hands play side by side.
            - **In sixths**: the right hand starts a sixth above the left (E with C).
            - **In tenths**: an octave plus a third — the thirds form, opened out.

            Each hand keeps its normal C-major fingering; it simply begins on a different finger. The harmony between the hands is what you train your ear on.
            """))
        steps.append(L.play("An octave apart", "The familiar form: C major, hands an octave apart.",
                            L.together(rhOct, lhOct), display: .staff))
        steps.append(L.play("In thirds", "Left hand starts on C, right hand on the E just above it. The hands are close together — keep the left wrist slightly lower.",
                            L.together(TC.cMajorLine(from: 52, hand: .right), lhOct), display: .staff, clef: .bass))
        steps.append(L.play("In sixths", "Left hand starts on E, right hand on the C above. The right hand uses normal C-major fingering; the left starts on finger 3.",
                            L.together(rhOct, TC.cMajorLine(from: 52, hand: .left)), display: .staff))
        steps.append(L.play("In tenths", "Left hand on C, right hand on the E an octave and a third higher. A warm, open sound.",
                            L.together(TC.cMajorLine(from: 64, hand: .right), lhOct), display: .staff))
        steps.append(L.timed("Thirds in time", "Scale in thirds with the metronome.",
                             L.together(TC.cMajorLine(from: 52, hand: .right), lhOct), bpm: 66, display: .staff, clef: .bass))
        steps.append(L.timed("Sixths in time", "Scale in sixths with the metronome.",
                             L.together(rhOct, TC.cMajorLine(from: 52, hand: .left)), bpm: 66, display: .staff))
        steps.append(L.timed("Tenths in time", "Scale in tenths with the metronome, evenly.",
                             L.together(TC.cMajorLine(from: 64, hand: .right), lhOct), bpm: 66, display: .staff,
                             rules: [.evenVelocity(maxStdDev: 12)]))
        return lesson("technique.scaleskills.intervals", "Scales in octaves, 3rds, 6ths and 10ths",
                      "Hands together at an octave, a third, a sixth and a tenth.", steps)
    }

    fileprivate static func tcContraryEvents(_ pc: Int, type: ScaleType, duration: Double = 1) -> [ExpectedEvent] {
        let shape = [1, 2, 3, 1, 2, 3, 4, 5]
        let top = 60 + pc
        let up = Music.scale(root: top, type: type)
        let down = Array(Music.scale(root: top - 24, type: type).reversed())
        return L.together(L.line(TC.upDown(up), hand: .right, fingers: TC.upDown(shape), duration: duration),
                          L.line(TC.upDown(down), hand: .left, fingers: TC.upDown(shape), duration: duration))
    }

    fileprivate static var tcContraryLesson: Lesson {
        var steps: [Step] = []
        steps.append(L.info("Scales in contrary motion", """
            In a contrary-motion scale both thumbs start on the key-note and the hands travel **outwards** in opposite directions, then return.

            In the C-group keys both hands use the **same fingering at the same time**: 1 2 3, thumb under, 1 2 3 4 5. The crossings line up, so it often feels easier than parallel motion — but the black keys now arrive at different moments in each hand.

            Here the thumbs start an octave apart so the hands have room.
            """, example: L.timedTask("C major, contrary motion", "", tcContraryEvents(0, type: .major, duration: 0.5), bpm: 96, display: .staff)))
        steps.append(L.play("C major", "Thumbs on two Cs. Open out for one octave, then close.",
                            tcContraryEvents(0, type: .major), display: .staff))
        steps.append(L.play("G major", "The same shape. The right hand meets F♯ near the top; the left hand meets it near the start.",
                            tcContraryEvents(7, type: .major), display: .staff, key: 1))
        steps.append(L.play("E major", "Four sharps. Watch how the hands mirror each other on the black keys.",
                            tcContraryEvents(4, type: .major), display: .staff, key: 4))
        steps.append(L.play("A harmonic minor", "Contrary motion in a minor key, with the raised 7th (G♯).",
                            tcContraryEvents(9, type: .harmonicMinor), display: .staff))
        steps.append(L.timed("C major in time", "Contrary motion with the metronome, one note per click.",
                             tcContraryEvents(0, type: .major), bpm: 72, display: .staff))
        steps.append(L.timed("C major in eighth notes", "Two notes per click. Both hands should sound exactly together and equally loud.",
                             tcContraryEvents(0, type: .major, duration: 0.5), bpm: 66, display: .staff,
                             rules: [.evenVelocity(maxStdDev: 12)]))
        return lesson("technique.scaleskills.contrary", "Contrary-motion scales",
                      "Hands mirror each other outwards and back.", steps)
    }

    fileprivate static var tcChromaticLesson: Lesson {
        let rhUp = Array(60...72)
        let rhFingers = [1, 3, 1, 3, 1, 2, 3, 1, 3, 1, 3, 1, 2]
        let lhUp = Array(48...60)
        let lhFingers = [1, 3, 1, 3, 2, 1, 3, 1, 3, 1, 3, 2, 1]
        var steps: [Step] = []
        steps.append(L.info("The chromatic scale", """
            The chromatic scale plays **every key**, black and white, in order — twelve half steps to the octave.

            The fingering is simple:

            - **Finger 3 on every black key.**
            - **Thumb on white keys.**
            - Where two white keys sit side by side (E–F and B–C), finger **2** helps out.

            Right hand from C: **1 3 1 3 1 2 3 1 3 1 3 1 2**. Keep the fingers curved and close to the keys, with the hand slightly forward towards the black keys.
            """, keys: L.keys(rhUp, labels: rhFingers.map { "\($0)" }, hand: .right),
            example: L.timedTask("Chromatic scale", "", TC.custom(rhUp, rhFingers, hand: .right, duration: 0.5), bpm: 100,
                                 display: .staff, clef: .treble)))
        steps.append(L.play("Right hand, going up", "Middle C to the next C. Finger 3 on each black key, 2 on F and on the top C.",
                            TC.custom(rhUp, rhFingers, hand: .right, descend: false), display: .staff, clef: .treble))
        steps.append(L.play("Right hand, up and down", "The same fingers on the same keys coming down.",
                            TC.custom(rhUp, rhFingers, hand: .right), display: .staff, clef: .treble))
        steps.append(L.info("Left hand", """
            The left hand follows the same rules, mirrored. Going up from C: **1 3 1 3 2 1 3 1 3 1 3 2 1**.

            Finger 2 now takes **E** and **B** — the lower key of each white pair.
            """, keys: L.keys(lhUp, labels: lhFingers.map { "\($0)" }, hand: .left)))
        steps.append(L.play("Left hand, up and down", "Finger 3 on black keys, 2 on E and B.",
                            TC.custom(lhUp, lhFingers, hand: .left), display: .staff, clef: .bass))
        steps.append(L.play("Hands together", "An octave apart. The 2nd fingers arrive at different moments, so go slowly.",
                            L.together(TC.custom(rhUp, rhFingers, hand: .right), TC.custom(lhUp, lhFingers, hand: .left)),
                            display: .staff))
        steps.append(L.timed("Chromatic in time", "Right hand, two notes per click, perfectly even.",
                             TC.custom(rhUp, rhFingers, hand: .right, duration: 0.5), bpm: 72, display: .staff, clef: .treble,
                             rules: [.evenVelocity(maxStdDev: 12)]))
        steps.append(L.timed("Hands together in time", "Both hands, two notes per click.",
                             L.together(TC.custom(rhUp, rhFingers, hand: .right, duration: 0.5),
                                        TC.custom(lhUp, lhFingers, hand: .left, duration: 0.5)),
                             bpm: 60, display: .staff, rules: [.evenVelocity(maxStdDev: 12)]))
        return lesson("technique.scaleskills.chromatic", "Chromatic scale",
                      "Every key in order, with the standard 1-3 fingering.", steps)
    }

    // MARK: - Pentatonic, blues, whole-tone

    fileprivate static var tcColourScalesUnit: CurriculumUnit {
        unit("technique.colour", "Pentatonic, blues and whole-tone scales", [
            tcPentatonicLesson, tcBluesLesson, tcWholeToneLesson,
        ])
    }

    fileprivate static var tcPentatonicLesson: Lesson {
        let cMajorPent = Music.scale(root: 60, type: .majorPentatonic)
        let aMinorPent = Music.scale(root: 57, type: .minorPentatonic)
        let blackPent = Music.scale(root: 66, type: .majorPentatonic)
        var steps: [Step] = []
        steps.append(L.info("Five-note scales", """
            A **pentatonic** scale has five notes per octave. Take a major scale and leave out the 4th and 7th notes: the two half steps disappear, and with them every harsh clash. Any pentatonic note sounds good against any other.

            **C major pentatonic: C D E G A.**

            It is the sound of folk songs, a great deal of pop and rock, and countless melodies around the world.
            """, keys: L.keys(cMajorPent, labels: TC.names(cMajorPent, flats: false), hand: .right),
            example: L.timedTask("C major pentatonic", "", TC.custom(cMajorPent, [1, 2, 3, 1, 2, 3], hand: .right, duration: 0.5),
                                 bpm: 96, display: .staff, clef: .treble)))
        steps.append(L.play("C major pentatonic, right hand", "1 2 3 on C D E, thumb under to G, then 2 3 on A and C.",
                            TC.custom(cMajorPent, [1, 2, 3, 1, 2, 3], hand: .right), display: .staff, clef: .treble))
        steps.append(L.play("C major pentatonic, left hand", "Left hand: 3 2 1 on C D E, then 3 2 1 on G A C.",
                            TC.custom(Music.scale(root: 48, type: .majorPentatonic), [3, 2, 1, 3, 2, 1], hand: .left),
                            display: .staff, clef: .bass))
        steps.append(L.info("The minor pentatonic", """
            Start the same five notes from A and you get **A minor pentatonic: A C D E G** — the relative minor, exactly as A minor relates to C major.

            Built on its own: root, minor 3rd, 4th, 5th, minor 7th. This is the backbone of rock and blues soloing.
            """, keys: L.keys(aMinorPent, labels: TC.names(aMinorPent, flats: false), hand: .right),
            example: L.timedTask("A minor pentatonic", "", TC.custom(aMinorPent, [1, 2, 3, 1, 2, 3], hand: .right, duration: 0.5),
                                 bpm: 96, display: .staff, clef: .treble)))
        steps.append(L.play("A minor pentatonic, right hand", "A C D with 1 2 3, thumb under to E, then G A with 2 3.",
                            TC.custom(aMinorPent, [1, 2, 3, 1, 2, 3], hand: .right), display: .staff, clef: .treble))
        steps.append(L.info("The black keys are a pentatonic scale", """
            The five black keys form **F♯ (G♭) major pentatonic**. Play only black keys in any order and it will sound like music — a good way to improvise with no wrong notes.
            """, keys: L.keys(blackPent, labels: TC.names(blackPent, flats: false), hand: .right)))
        steps.append(L.play("Black-key pentatonic", "Only black keys, from F♯ up to the next F♯ and back. Use flatter fingers on the black keys.",
                            TC.custom(blackPent, [2, 3, 4, 1, 2, 3], hand: .right), display: .staff, clef: .treble, key: 6))
        steps.append(L.timed("Minor pentatonic in time", "A minor pentatonic in eighth notes with the metronome.",
                             TC.custom(aMinorPent, [1, 2, 3, 1, 2, 3], hand: .right, duration: 0.5), bpm: 76, display: .staff,
                             clef: .treble, rules: [.evenVelocity(maxStdDev: 12)]))
        return lesson("technique.colour.pentatonic", "Pentatonic scales",
                      "Major and minor five-note scales, including the black-key pentatonic.", steps)
    }

    fileprivate static var tcBluesLesson: Lesson {
        let blues = Music.scale(root: 60, type: .blues)
        let rhFingers = [1, 2, 3, 4, 1, 2, 3]
        let lhFingers = [5, 4, 3, 2, 1, 2, 1]
        var steps: [Step] = []
        steps.append(L.info("The blues scale", """
            Take the minor pentatonic and add one note: the **flattened 5th**, the "blue note". In C:

            **C  E♭  F  F♯  G  B♭**

            The blue note (F♯/G♭) is a passing note — slide through it between F and G rather than resting on it. Those three neighbouring keys, F–F♯–G, are where the scale gets its bite.
            """, keys: L.keys(blues, labels: ["C", "E♭", "F", "F♯", "G", "B♭", "C"], hand: .right),
            example: L.timedTask("C blues scale", "", TC.custom(blues, rhFingers, hand: .right, duration: 0.5), bpm: 100,
                                 display: .staff, clef: .treble, flats: true)))
        steps.append(L.play("Right hand, going up", "1 2 3 4 on C E♭ F F♯, thumb under to G, then 2 3.",
                            TC.custom(blues, rhFingers, hand: .right, descend: false), display: .staff, clef: .treble, flats: true))
        steps.append(L.play("Right hand, up and down", "Now return the same way.",
                            TC.custom(blues, rhFingers, hand: .right), display: .staff, clef: .treble, flats: true))
        steps.append(L.play("Left hand", "5 4 3 2 1 up to G, then finger 2 crosses over to B♭ and the thumb takes the top C.",
                            TC.custom(Music.scale(root: 48, type: .blues), lhFingers, hand: .left), display: .staff, clef: .bass, flats: true))
        steps.append(L.timed("Blues scale over a bass note", "The left hand holds a low C while the right hand plays the scale in eighth notes.",
                             L.together(TC.custom(blues, rhFingers, hand: .right, duration: 0.5),
                                        L.melody("C3:w:5 C3:w:5", hand: .left)),
                             bpm: 80, display: .staff, flats: true))
        steps.append(L.timed("A blues lick", "A short phrase using the blue note. Lean a little on the first note of each bar.",
                             L.melody("C5:e:5 B♭4:e:4 G4:e:3 F♯4:e:2 F4:e:1 E♭4:e:2 C4:q:1 r:e E♭4:e:2 F4:e:3 F♯4:e:4 G4:e:1 B♭4:e:2 C5:q:3", hand: .right),
                             bpm: 84, display: .staffAndRhythm, clef: .treble, flats: true))
        return lesson("technique.colour.blues", "Blues scale", "The minor pentatonic plus the blue note.", steps)
    }

    fileprivate static var tcWholeToneLesson: Lesson {
        let whole = Music.scale(root: 60, type: .wholeTone)
        let other = Music.scale(root: 61, type: .wholeTone)
        let rhFingers = [1, 2, 1, 2, 3, 4, 5]
        let lhFingers = [3, 2, 1, 4, 3, 2, 1]
        var steps: [Step] = []
        steps.append(L.info("The whole-tone scale", """
            Every step in this scale is a **whole step**. Six notes fill the octave:

            **C  D  E  F♯  G♯  A♯**

            With no half steps there is no pull towards any note, so the sound floats — dreamlike and unsettled. Debussy used it constantly; film music uses it for dream sequences.

            There are only **two** whole-tone scales: this one, and the one starting a half step higher. Together they contain all twelve notes.
            """, keys: L.keys(whole, labels: ["C", "D", "E", "F♯", "G♯", "A♯", "C"], hand: .right),
            example: L.timedTask("Whole-tone scale", "", TC.custom(whole, rhFingers, hand: .right, duration: 0.5), bpm: 100,
                                 display: .staff, clef: .treble)))
        steps.append(L.play("Right hand", "1 2 on C D, thumb under to E, then 2 3 4 on the three black keys and 5 on C.",
                            TC.custom(whole, rhFingers, hand: .right), display: .staff, clef: .treble))
        steps.append(L.play("Left hand", "3 2 1 on C D E, then 4 3 2 on the black keys and thumb on C.",
                            TC.custom(Music.scale(root: 48, type: .wholeTone), lhFingers, hand: .left), display: .staff, clef: .bass))
        steps.append(L.info("The other whole-tone scale", """
            Start on D♭ and you get the second scale: **D♭  E♭  F  G  A  B**. Two black keys, then four white.
            """, keys: L.keys(other, labels: ["D♭", "E♭", "F", "G", "A", "B", "D♭"], hand: .right)))
        steps.append(L.play("The second scale, right hand", "2 3 on the black keys, then thumb on F, 2 3 4 up to B, and 5 on the top D♭.",
                            TC.custom(other, [2, 3, 1, 2, 3, 4, 5], hand: .right), display: .staff, clef: .treble, flats: true))
        steps.append(L.timed("Whole-tone in time", "The C whole-tone scale in eighth notes, evenly.",
                             TC.custom(whole, rhFingers, hand: .right, duration: 0.5), bpm: 76, display: .staff, clef: .treble,
                             rules: [.evenVelocity(maxStdDev: 12)]))
        return lesson("technique.colour.wholetone", "Whole-tone scale", "Six equal whole steps: the floating scale.", steps)
    }

    // MARK: - Modes

    fileprivate struct ModeInfo {
        let type: ScaleType
        let slug: String
        let whiteRoot: Int        // right-hand start of the white-key version
        let parentKey: Int        // key signature of the C-based version
        let character: String
        let compare: String
        let colourDegree: Int?    // index of the characteristic note
        let sound: String
    }

    fileprivate static let tcModeTable: [ModeInfo] = [
        ModeInfo(type: .dorian, slug: "dorian", whiteRoot: 62, parentKey: -2,
                 character: "the natural minor with a **raised 6th**", compare: "D natural minor has B♭; D Dorian has B♮",
                 colourDegree: 5, sound: "Minor, but hopeful. Folk tunes, funk and modal jazz."),
        ModeInfo(type: .phrygian, slug: "phrygian", whiteRoot: 64, parentKey: -4,
                 character: "the natural minor with a **lowered 2nd**", compare: "E natural minor has F♯; E Phrygian has F♮",
                 colourDegree: 1, sound: "Dark and Spanish-sounding, thanks to the half step right above the key-note."),
        ModeInfo(type: .lydian, slug: "lydian", whiteRoot: 65, parentKey: 1,
                 character: "the major scale with a **raised 4th**", compare: "F major has B♭; F Lydian has B♮",
                 colourDegree: 3, sound: "Bright and dreamy. A favourite of film composers."),
        ModeInfo(type: .mixolydian, slug: "mixolydian", whiteRoot: 55, parentKey: -1,
                 character: "the major scale with a **lowered 7th**", compare: "G major has F♯; G Mixolydian has F♮",
                 colourDegree: 6, sound: "Major but relaxed and bluesy. Rock, folk and the scale of dominant 7th chords."),
        ModeInfo(type: .aeolian, slug: "aeolian", whiteRoot: 57, parentKey: -3,
                 character: "exactly the **natural minor** scale", compare: "A Aeolian and A natural minor are the same thing",
                 colourDegree: 5, sound: "The plain minor sound: sad, serious."),
        ModeInfo(type: .locrian, slug: "locrian", whiteRoot: 59, parentKey: -5,
                 character: "the natural minor with a **lowered 2nd and lowered 5th**", compare: "B natural minor has C♯ and F♯; B Locrian has C♮ and F♮",
                 colourDegree: 4, sound: "Unstable: its home chord is diminished. Rare as a key, common over half-diminished chords in jazz."),
    ]

    fileprivate static var tcModesUnit: CurriculumUnit {
        unit("technique.modes", "Modes", [tcModesIntroLesson] + tcModeTable.map { tcModeLesson($0) })
    }

    fileprivate static var tcModesIntroLesson: Lesson {
        var steps: [Step] = []
        steps.append(L.info("What is a mode?", """
            Play only the white keys, but begin and end on a note other than C. The notes are the same as C major, yet the scale sounds different, because the whole steps and half steps now fall in different places around the new home note. Each starting note gives a **mode**:

            - C: **Ionian** (the major scale)
            - D: **Dorian**
            - E: **Phrygian**
            - F: **Lydian**
            - G: **Mixolydian**
            - A: **Aeolian** (the natural minor)
            - B: **Locrian**

            Three modes sound major (Ionian, Lydian, Mixolydian) and four sound minor (Dorian, Phrygian, Aeolian, Locrian).
            """, keys: L.keys(Music.notes("C4 D4 E4 F4 G4 A4 B4"), labels: ["Ion", "Dor", "Phr", "Lyd", "Mix", "Aeo", "Loc"], hand: .right)))
        steps.append(L.play("C to C: Ionian", "The major scale you know.", TC.run(60, .major, hand: .right, descend: false),
                            display: .staff, clef: .treble))
        steps.append(L.play("D to D: Dorian", "Same white keys, starting on D. Hear how it turns minor.",
                            TC.run(62, .dorian, hand: .right, descend: false), display: .staff, clef: .treble))
        steps.append(L.play("G to G: Mixolydian", "White keys from G: major, but with a softer 7th.",
                            TC.run(55, .mixolydian, hand: .right, descend: false), display: .staff, clef: .treble))
        steps.append(L.info("Two ways to think about a mode", """
            - **Relative**: D Dorian is "C major starting from D". Useful for finding the notes.
            - **Parallel**: D Dorian is "D minor with one note changed". Useful for hearing the colour.

            The lessons that follow do both: first the white-key version, then the same mode built on C so you can compare it directly with C major and C minor.
            """))
        steps.append(L.quiz("Find the mode's home note", "Play the white key each mode starts on (any octave).", rounds: 7) { round in
            let names = ["Ionian", "Dorian", "Phrygian", "Lydian", "Mixolydian", "Aeolian", "Locrian"]
            let roots = [60, 62, 64, 65, 67, 69, 71]
            let order = [1, 4, 0, 5, 3, 2, 6]
            let i = order[round % 7]
            return L.task(names[i], "", L.line([roots[i]], hand: .right), showTargets: false, anyOctave: true)
        })
        return lesson("technique.modes.intro", "What modes are", "Seven scales from the same seven white keys.", steps)
    }

    fileprivate static func tcModeLine(_ root: Int, _ type: ScaleType, hand: Hand, duration: Double = 1) -> [ExpectedEvent] {
        if type == .lydian, Music.pc(root) == 0 {
            let fingers = hand == .left ? [5, 4, 3, 2, 1, 3, 2, 1] : [1, 2, 3, 4, 1, 2, 3, 4]
            return TC.custom(Music.scale(root: root, type: type), fingers, hand: hand, duration: duration)
        }
        return TC.run(root, type, hand: hand, duration: duration)
    }

    fileprivate static func tcModeLesson(_ mode: ModeInfo) -> Lesson {
        let name = mode.type.displayName
        let rootName = Music.name(mode.whiteRoot, octave: false)
        let white = Music.scale(root: mode.whiteRoot, type: mode.type)
        var whiteLabels = TC.names(white, flats: false)
        if let d = mode.colourDegree { whiteLabels[d] = whiteLabels[d] + "!" }
        let onC = Music.scale(root: 60, type: mode.type)
        let cLabels = TC.names(onC, flats: mode.parentKey < 0)
        let leftRoot = mode.whiteRoot - 12 > 52 ? mode.whiteRoot - 24 : mode.whiteRoot - 12

        var steps: [Step] = []
        steps.append(L.info("\(rootName) \(name)", """
            The white keys from \(rootName) to \(rootName) form the **\(name)** mode: \(TC.names(white, flats: false).dropLast().joined(separator: " ")).

            \(name) is \(mode.character). For example, \(mode.compare). The note marked **!** is the one that gives the mode its colour.

            \(mode.sound)
            """, keys: L.keys(white, labels: whiteLabels, hand: .right),
            example: L.timedTask("\(rootName) \(name)", "", tcModeLine(mode.whiteRoot, mode.type, hand: .right, duration: 0.5),
                                 bpm: 96, display: .staff, clef: .treble)))
        steps.append(L.play("\(rootName) \(name), right hand", "White keys only, up and down. Linger in your ear on the colour note.",
                            tcModeLine(mode.whiteRoot, mode.type, hand: .right), display: .staff, clef: .treble))
        steps.append(L.play("\(rootName) \(name), left hand", "The same mode in the left hand.",
                            tcModeLine(leftRoot, mode.type, hand: .left), display: .staff, clef: .bass))
        steps.append(L.info("C \(name)", """
            Now the same pattern of steps starting on C: **\(cLabels.dropLast().joined(separator: " "))**.

            Compare it with C major (all white keys)\(mode.type.isMinor ? " and C natural minor (E♭, A♭, B♭)" : ""). Building every mode on the same note is the best way to hear what makes each one different.
            """, keys: L.keys(onC, labels: cLabels, hand: .right),
            example: L.timedTask("C \(name)", "", tcModeLine(60, mode.type, hand: .right, duration: 0.5), bpm: 96,
                                 display: .staff, clef: .treble, key: mode.parentKey)))
        steps.append(L.play("C \(name), right hand", "Up and down from middle C.",
                            tcModeLine(60, mode.type, hand: .right), display: .staff, clef: .treble, key: mode.parentKey))
        steps.append(L.timed("\(rootName) \(name) in time", "Eighth notes with the metronome, over a held left-hand \(rootName) so you hear the mode against its home note.",
                             L.together(tcModeLine(mode.whiteRoot, mode.type, hand: .right, duration: 0.5),
                                        L.line([leftRoot, leftRoot], hand: .left, fingers: [5, 5], duration: 4)),
                             bpm: 76, display: .staff, rules: [.evenVelocity(maxStdDev: 12)]))
        return lesson("technique.modes.\(mode.slug)", "\(name) mode", "\(name): \(mode.sound)", steps)
    }

    // MARK: - Jazz scales

    fileprivate static var tcJazzUnit: CurriculumUnit {
        unit("technique.jazz", "Jazz scales", [tcBebopLesson, tcAlteredLesson, tcDiminishedLesson])
    }

    fileprivate static func tcShell(_ names: String, bars: Int) -> [ExpectedEvent] {
        let chord = Music.notes(names)
        return L.chords(Array(repeating: chord, count: bars), hand: .left, duration: 4)
    }

    fileprivate static var tcBebopLesson: Lesson {
        let dominant = Music.scale(root: 60, type: .bebopDominant)
        let domFingers = [1, 2, 3, 1, 2, 1, 2, 3, 4]
        let major = Music.scale(root: 60, type: .bebopMajor)
        let majFingers = [1, 2, 3, 1, 2, 3, 1, 2, 3]
        let descending = Array(dominant.reversed())
        var steps: [Step] = []
        steps.append(L.info("Why bebop scales have eight notes", """
            A normal scale has seven notes, so in a run of eighth notes the chord tones drift on and off the beat. Bebop players fixed this by adding **one passing note**. With eight notes, the chord tones land **on every beat** and the line outlines the harmony by itself.

            **C bebop dominant** = C Mixolydian plus a B♮ between B♭ and C:

            **C D E F G A B♭ B**

            Played downwards from C over a C7 chord, the beats fall on C, B♭, G and E — the notes of C7.
            """, keys: L.keys(dominant, labels: ["C", "D", "E", "F", "G", "A", "B♭", "B", "C"], hand: .right),
            example: L.timedTask("C bebop dominant", "", L.line(descending + [60], hand: .right, duration: 0.5), bpm: 110,
                                 display: .staff, clef: .treble, flats: true)))
        steps.append(L.play("Bebop dominant, going up", "1 2 3 on C D E, thumb on F, 2 on G, thumb again on A, then 2 3 4 for B♭ B C.",
                            TC.custom(dominant, domFingers, hand: .right, descend: false), display: .staff, clef: .treble, flats: true))
        steps.append(L.play("Bebop dominant, up and down", "The same fingers on the way down. The half steps B♭–B–C sit under fingers 2 3 4.",
                            TC.custom(dominant, domFingers, hand: .right), display: .staff, clef: .treble, flats: true))
        steps.append(L.timed("Descending over C7", "The left hand holds a C7 shell (C, E, B♭). The right hand runs down the scale in eighth notes: listen for chord tones on each click.",
                             L.together(Array(L.line(descending, hand: .right, fingers: Array(domFingers.reversed()), duration: 0.5)
                                            .dropLast()) + L.melody("C4:h:1", hand: .right, start: 4),
                                        tcShell("C3 E3 B♭3", bars: 2)),
                             bpm: 80, display: .staff, flats: true))
        steps.append(L.info("The bebop major scale", """
            The major version adds a passing note between the 5th and 6th:

            **C D E F G G♯ A B**

            Now the beats fall on C, E, G and A — a C6 chord.
            """, keys: L.keys(major, labels: ["C", "D", "E", "F", "G", "G♯", "A", "B", "C"], hand: .right),
            example: L.timedTask("C bebop major", "", TC.custom(major, majFingers, hand: .right, duration: 0.5), bpm: 110,
                                 display: .staff, clef: .treble)))
        steps.append(L.play("Bebop major, right hand", "1 2 3, thumb on F, 2 3 on G G♯, thumb on A, then 2 3.",
                            TC.custom(major, majFingers, hand: .right), display: .staff, clef: .treble))
        steps.append(L.timed("Bebop major in time", "Up and down in eighth notes over a held C major chord.",
                             L.together(TC.custom(major, majFingers, hand: .right, duration: 0.5), tcShell("C3 E3 G3", bars: 2) + tcShellTail("C3 E3 G3", at: 8)),
                             bpm: 76, totalBeats: 12, display: .staff))
        return lesson("technique.jazz.bebop", "Bebop scales", "Eight-note scales that put chord tones on the beat.", steps)
    }

    fileprivate static func tcShellTail(_ names: String, at beat: Double) -> [ExpectedEvent] {
        L.chords([Music.notes(names)], hand: .left, duration: 4, start: beat)
    }

    fileprivate static var tcAlteredLesson: Lesson {
        let altered = Music.scale(root: 60, type: .altered)
        let fingers = [1, 2, 3, 1, 2, 3, 4, 5]
        var steps: [Step] = []
        steps.append(L.info("The altered scale", """
            Jazz players add tension to a dominant 7th chord by "altering" its upper notes. The **altered scale** contains the root, 3rd and 7th of the chord — and every possible alteration:

            **C  D♭  E♭  E  G♭  A♭  B♭**

            That is root, ♭9, ♯9, 3rd, ♭5, ♯5, ♭7. The whole scale strains to resolve, which is why it is used on a dominant chord just before it moves home (C7alt going to F).

            A shortcut for finding it: it is the **melodic minor scale a half step above the root**. C altered uses the notes of D♭ melodic minor.
            """, keys: L.keys(altered, labels: ["C", "D♭", "E♭", "E", "G♭", "A♭", "B♭", "C"], hand: .right),
            example: L.timedTask("C altered", "", TC.custom(altered, fingers, hand: .right, duration: 0.5), bpm: 100,
                                 display: .staff, clef: .treble, flats: true)))
        steps.append(L.play("C altered, going up", "1 2 3 on C D♭ E♭, thumb under to E, then 2 3 4 on the three black keys.",
                            TC.custom(altered, fingers, hand: .right, descend: false), display: .staff, clef: .treble, flats: true))
        steps.append(L.play("C altered, up and down", "Now both directions.",
                            TC.custom(altered, fingers, hand: .right), display: .staff, clef: .treble, flats: true))
        steps.append(L.play("The chord it belongs to", "Left hand: the C7 shell — C, E and B♭. These three notes are inside the altered scale.",
                            L.chords([Music.notes("C3 E3 B♭3")], hand: .left, fingers: [[5, 2, 1]]), display: .staff, clef: .bass, flats: true))
        steps.append(L.timed("Altered scale over C7", "Hold the shell in the left hand and run the altered scale in eighth notes.",
                             L.together(TC.custom(altered, fingers, hand: .right, duration: 0.5), tcShell("C3 E3 B♭3", bars: 2)),
                             bpm: 76, display: .staff, flats: true))
        steps.append(L.timed("Tension and release", "An altered run over C7 that resolves to an F major chord. This is what the scale is for.",
                             L.together(
                                L.melody("C5:e:5 B♭4:e:4 A♭4:e:3 G♭4:e:2 E4:e:1 E♭4:e:3 D♭4:e:2 C4:e:1 A3+C4:h:1-2", hand: .right),
                                L.chords([Music.notes("C3 E3 B♭3"), Music.notes("F2 C3 F3")], hand: .left, duration: 4)),
                             bpm: 76, totalBeats: 8, display: .staff, flats: true))
        return lesson("technique.jazz.altered", "Altered scale", "Every altered tension over a dominant 7th chord.", steps)
    }

    fileprivate static var tcDiminishedLesson: Lesson {
        let halfWhole = Music.scale(root: 60, type: .diminishedHalfWhole)
        let hwFingers = [1, 2, 3, 1, 2, 1, 2, 3, 4]
        let wholeHalf = Music.scale(root: 60, type: .diminishedWholeHalf)
        let whFingers = [1, 2, 3, 1, 2, 3, 1, 2, 3]
        var steps: [Step] = []
        steps.append(L.info("Diminished scales", """
            A diminished scale alternates **half steps and whole steps** all the way up. That gives eight notes per octave, and a pattern that repeats every three half steps — so there are only three different diminished scales in total.

            There are two ways to start:

            - **Half-whole** (half step first): used over **dominant 7th** chords.
            - **Whole-half** (whole step first): used over **diminished 7th** chords.
            """))
        steps.append(L.info("Half-whole diminished", """
            **C  D♭  E♭  E  F♯  G  A  B♭**

            It contains C7 (C E G B♭) plus the tensions ♭9, ♯9 and ♯11. Use it on a dominant 7th chord for a tense, glittering sound.
            """, keys: L.keys(halfWhole, labels: ["C", "D♭", "E♭", "E", "F♯", "G", "A", "B♭", "C"], hand: .right),
            example: L.timedTask("C half-whole diminished", "", TC.custom(halfWhole, hwFingers, hand: .right, duration: 0.5),
                                 bpm: 100, display: .staff, clef: .treble, flats: true)))
        steps.append(L.play("Half-whole, right hand", "1 2 3 on C D♭ E♭, thumb on E, 2 on F♯, thumb on G, then 2 3 4.",
                            TC.custom(halfWhole, hwFingers, hand: .right), display: .staff, clef: .treble, flats: true))
        steps.append(L.info("Whole-half diminished", """
            **C  D  E♭  F  G♭  A♭  A  B**

            It contains the C diminished 7th chord (C E♭ G♭ A), with a note a whole step above each chord tone.
            """, keys: L.keys(wholeHalf, labels: ["C", "D", "E♭", "F", "G♭", "A♭", "A", "B", "C"], hand: .right),
            example: L.timedTask("C whole-half diminished", "", TC.custom(wholeHalf, whFingers, hand: .right, duration: 0.5),
                                 bpm: 100, display: .staff, clef: .treble, flats: true)))
        steps.append(L.play("Whole-half, right hand", "1 2 3 on C D E♭, thumb on F, 2 3 on G♭ A♭, thumb on A, then 2 3.",
                            TC.custom(wholeHalf, whFingers, hand: .right), display: .staff, clef: .treble, flats: true))
        steps.append(L.timed("Half-whole over C7", "Left hand holds the C7 shell; right hand plays the half-whole scale in eighth notes.",
                             L.together(TC.custom(halfWhole, hwFingers, hand: .right, duration: 0.5),
                                        tcShell("C3 E3 B♭3", bars: 2) + tcShellTail("C3 E3 B♭3", at: 8)),
                             bpm: 72, totalBeats: 12, display: .staff, flats: true))
        steps.append(L.timed("Whole-half over C diminished", "Left hand holds C, E♭ and A; right hand plays the whole-half scale.",
                             L.together(TC.custom(wholeHalf, whFingers, hand: .right, duration: 0.5),
                                        tcShell("C3 E♭3 A3", bars: 2) + tcShellTail("C3 E♭3 A3", at: 8)),
                             bpm: 72, totalBeats: 12, display: .staff, flats: true))
        return lesson("technique.jazz.diminished", "Diminished scales", "Half-whole and whole-half: the two symmetrical eight-note scales.", steps)
    }

    // MARK: - Arpeggios: concepts

    fileprivate static var tcArpeggioUnit: CurriculumUnit {
        unit("technique.arpeggios", "Arpeggios", [
            tcInversionsLesson, tcSeventhArpeggioLesson, tcHandOverHandLesson, tcExtendedArpeggioLesson,
        ])
    }

    fileprivate static func tcBrokenInversions(_ root: Int, _ type: ChordType, hand: Hand, duration: Double = 1) -> [ExpectedEvent] {
        let rh: [[Int]] = [[1, 2, 3, 5], [1, 2, 4, 5], [1, 2, 4, 5]]
        let lh: [[Int]] = [[5, 4, 2, 1], [5, 4, 2, 1], [5, 3, 2, 1]]
        var notes: [Int] = []
        var fingers: [Int] = []
        for inversion in 0..<3 {
            let chord = Music.chord(root: root, type: type, inversion: inversion)
            notes += chord + [chord[0] + 12]
            fingers += (hand == .left ? lh : rh)[inversion]
        }
        return L.line(notes, hand: hand, fingers: fingers, duration: duration)
    }

    fileprivate static var tcInversionsLesson: Lesson {
        var steps: [Step] = []
        steps.append(L.info("Triads and their inversions", """
            A **triad** is a three-note chord: root, 3rd and 5th. C major is C–E–G; A minor is A–C–E.

            The same three notes can be stacked in three orders:

            - **Root position**: C E G — root at the bottom.
            - **First inversion**: E G C — 3rd at the bottom.
            - **Second inversion**: G C E — 5th at the bottom.

            Right-hand fingering: **1 3 5**, **1 2 5**, **1 3 5**. Left hand: **5 3 1**, **5 3 1**, **5 2 1**. The middle finger changes because the gap between the notes changes.
            """, keys: L.keys(Music.notes("C4 E4 G4"), labels: ["root", "3rd", "5th"], hand: .right),
            example: L.task("C major inversions", "", L.chords(TC.inversions(60, .major), hand: .right), display: .staff, clef: .treble)))
        steps.append(L.play("C major inversions, right hand", "Root position, first inversion, second inversion, then root position an octave higher. Press all three notes together.",
                            L.chords(TC.inversions(60, .major), hand: .right, fingers: TC.rhBlockFingers,
                                     labels: ["root", "1st inv", "2nd inv", "root"]),
                            display: .staff, clef: .treble))
        steps.append(L.play("C major inversions, left hand", "The same four chords in the left hand.",
                            L.chords(TC.inversions(48, .major), hand: .left, fingers: TC.lhBlockFingers,
                                     labels: ["root", "1st inv", "2nd inv", "root"]),
                            display: .staff, clef: .bass))
        steps.append(L.play("A minor inversions, right hand", "A–C–E in its three positions.",
                            L.chords(TC.inversions(57, .minor), hand: .right, fingers: TC.rhBlockFingers,
                                     labels: ["root", "1st inv", "2nd inv", "root"]),
                            display: .staff, clef: .treble))
        steps.append(L.info("From chord to arpeggio", """
            An **arpeggio** is a chord played one note at a time. Add the octave on top and each position becomes a four-note shape:

            - Right hand: **1 2 3 5** in root position, **1 2 4 5** in the inversions.
            - Left hand: **5 4 2 1** in root position and first inversion, **5 3 2 1** in second inversion.

            Open the hand to cover the shape before you play, and let the wrist travel sideways with the fingers.
            """, example: L.timedTask("Broken inversions", "", tcBrokenInversions(60, .major, hand: .right, duration: 0.5), bpm: 96,
                                     display: .staff, clef: .treble)))
        steps.append(L.play("Broken inversions, right hand", "C major: each position as four notes, climbing.",
                            tcBrokenInversions(60, .major, hand: .right), display: .staff, clef: .treble))
        steps.append(L.play("Broken inversions, left hand", "The same in the left hand.",
                            tcBrokenInversions(36, .major, hand: .left), display: .staff, clef: .bass))
        steps.append(L.timed("Broken inversions in time", "Right hand, eighth notes with the metronome. Even tone on every note — do not accent the thumb.",
                             tcBrokenInversions(60, .major, hand: .right, duration: 0.5) + L.line([72], hand: .right, fingers: [1], duration: 2, start: 6),
                             bpm: 72, display: .staff, clef: .treble, rules: [.evenVelocity(maxStdDev: 12)]))
        return lesson("technique.arpeggios.inversions", "Triads: root position and inversions",
                      "Block and broken triads in all three positions.", steps)
    }

    fileprivate static func tcSeventh(_ root: Int, _ type: ChordType, hand: Hand, duration: Double = 1) -> [ExpectedEvent] {
        let up = Music.arpeggio(root: root, type: type)
        return TC.custom(up, hand == .left ? [5, 4, 3, 2, 1] : [1, 2, 3, 4, 5], hand: hand, duration: duration)
    }

    fileprivate static var tcSeventhArpeggioLesson: Lesson {
        var steps: [Step] = []
        steps.append(L.info("Dominant 7th arpeggios", """
            Add a fourth note to a major triad — a **minor 7th above the root** — and you get a **dominant 7th** chord. C7 is **C E G B♭**.

            It is called dominant because it is built on the 5th note of a key and pulls strongly home: C7 wants to resolve to F.

            With four different notes, the arpeggio uses every finger: right hand **1 2 3 4** (5 on the top root), left hand **5 4 3 2** (1 on the top root).
            """, keys: L.keys(Music.notes("C4 E4 G4 B♭4 C5"), labels: ["1", "2", "3", "4", "5"], hand: .right),
            example: L.timedTask("C7 arpeggio", "", tcSeventh(60, .dom7, hand: .right, duration: 0.5), bpm: 96, display: .staff,
                                 clef: .treble, flats: true)))
        steps.append(L.play("C7, right hand", "C E G B♭ C and back. Keep the hand open; finger 4 reaches for B♭.",
                            tcSeventh(60, .dom7, hand: .right), display: .staff, clef: .treble, flats: true))
        steps.append(L.play("C7, left hand", "5 4 3 2 1 going up.",
                            tcSeventh(48, .dom7, hand: .left), display: .staff, clef: .bass, flats: true))
        steps.append(L.play("C7 resolves to F", "Play C7 as a block chord, then F major. Hear the tension release.",
                            L.chords([Music.notes("C4 E4 G4 B♭4"), Music.notes("C4 F4 A4")], hand: .right,
                                     fingers: [[1, 2, 3, 5], [1, 3, 5]], labels: ["C7", "F"]),
                            display: .staff, clef: .treble, flats: true))
        steps.append(L.play("G7 and D7", "Two more dominant 7ths: G B D F, then D F♯ A C.",
                            tcSeventh(55, .dom7, hand: .right) + tcSeventh(62, .dom7, hand: .right).map { var e = $0; e.beat += 9; return e },
                            display: .staff, clef: .treble))
        steps.append(L.info("Diminished 7th arpeggios", """
            A **diminished 7th** chord stacks **minor 3rds**: C E♭ G♭ A. Every note is three half steps from the next, so the chord divides the octave into four equal parts.

            Because of that symmetry there are only **three** different diminished 7th chords — start on C, C♯ or D and you have covered all twelve notes. Each inversion is another diminished 7th chord.

            The shape is the same size everywhere: right hand **1 2 3 4**, left hand **5 4 3 2**.
            """, keys: L.keys(Music.notes("C4 E♭4 G♭4 A4 C5"), labels: ["C", "E♭", "G♭", "A", "C"], hand: .right),
            example: L.timedTask("C diminished 7th", "", tcSeventh(60, .dim7, hand: .right, duration: 0.5), bpm: 96,
                                 display: .staff, clef: .treble, flats: true)))
        steps.append(L.play("C diminished 7th, right hand", "C E♭ G♭ A C and back.",
                            tcSeventh(60, .dim7, hand: .right), display: .staff, clef: .treble, flats: true))
        steps.append(L.play("The other two, right hand", "C♯ diminished 7th (C♯ E G B♭), then D diminished 7th (D F A♭ B). With these you know them all.",
                            TC.custom(Music.arpeggio(root: 61, type: .dim7), [2, 1, 2, 3, 4], hand: .right)
                                + tcSeventh(62, .dim7, hand: .right).map { var e = $0; e.beat += 9; return e },
                            display: .staff, clef: .treble, flats: true))
        steps.append(L.timed("C7 in time", "C7 arpeggio in eighth notes, right hand, evenly.",
                             L.line([60, 64, 67, 70, 72, 70, 67, 64, 60, 64, 67, 70, 72, 70, 67, 64, 60], hand: .right,
                                    fingers: [1, 2, 3, 4, 5, 4, 3, 2, 1, 2, 3, 4, 5, 4, 3, 2, 1], duration: 0.5),
                             bpm: 76, totalBeats: 12, display: .staff, clef: .treble, flats: true, rules: [.evenVelocity(maxStdDev: 12)]))
        steps.append(L.timed("Diminished 7th in time", "C diminished 7th, hands together, eighth notes.",
                             L.together(tcSeventh(60, .dim7, hand: .right, duration: 0.5), tcSeventh(48, .dim7, hand: .left, duration: 0.5)),
                             bpm: 66, display: .staff, flats: true))
        return lesson("technique.arpeggios.sevenths", "Dominant 7th and diminished 7th arpeggios",
                      "Four-note arpeggios: the dominant 7th and the symmetrical diminished 7th.", steps)
    }

    fileprivate static func tcHandOverHand(_ root: Int, _ type: ChordType, duration: Double = 1, descend: Bool = true) -> [ExpectedEvent] {
        let triad = Music.chord(root: root, type: type)
        var up: [ExpectedEvent] = []
        var beat = 0.0
        for octave in 0..<4 {
            let hand: Hand = octave % 2 == 0 ? .left : .right
            let fingers = hand == .left ? [5, 3, 1] : [1, 2, 3]
            for (i, n) in triad.enumerated() {
                up.append(ExpectedEvent(notes: [NoteSpec(midi: n + 12 * octave, hand: hand, finger: fingers[i])], beat: beat, duration: duration))
                beat += duration
            }
        }
        up.append(ExpectedEvent(notes: [NoteSpec(midi: root + 48, hand: .left, finger: 2)], beat: beat, duration: duration))
        guard descend else { return up }
        var all = up
        for e in up.dropLast().reversed() {
            beat += duration
            var copy = e
            copy.beat = beat
            all.append(copy)
        }
        return all
    }

    fileprivate static var tcHandOverHandLesson: Lesson {
        var steps: [Step] = []
        steps.append(L.info("Hand-over-hand arpeggios", """
            The easiest way to sweep an arpeggio across the whole keyboard needs no thumb crossings at all. The hands **take turns**, three notes each:

            - Left hand plays C E G (5 3 1).
            - Right hand plays the next C E G (1 2 3).
            - While the right hand plays, the left hand **lifts over** it to the next octave.
            - And so on, finishing with the left hand reaching over for the top note.

            Move the free hand early and in an arc. The sound should be one unbroken line — the listener must not hear where the hands change.
            """, keys: L.keys(Music.notes("C2 E2 G2"), labels: ["5", "3", "1"], hand: .left)
                + L.keys(Music.notes("C3 E3 G3"), labels: ["1", "2", "3"], hand: .right),
            example: L.timedTask("Hand over hand", "", tcHandOverHand(36, .major, duration: 0.5), bpm: 100, display: .staff)))
        steps.append(L.play("C major, going up", "Orange keys are the left hand, blue keys the right. Four octaves, ending with the left hand crossing over to the top C.",
                            tcHandOverHand(36, .major, descend: false), display: .staff))
        steps.append(L.play("C major, up and down", "Now come back the same way. On the way down each hand plays its three notes from the top, and the left hand crosses back over the right.",
                            tcHandOverHand(36, .major), display: .staff))
        steps.append(L.play("A minor", "The same sweep on A–C–E.", tcHandOverHand(33 + 12, .minor, descend: false), display: .staff))
        steps.append(L.play("F major", "And on F–A–C.", tcHandOverHand(41, .major, descend: false), display: .staff))
        steps.append(L.timed("C major in time", "Eighth notes with the metronome, going up. No gap at the hand changes.",
                             tcHandOverHand(36, .major, duration: 0.5, descend: false), bpm: 72, display: .staff,
                             rules: [.evenVelocity(maxStdDev: 12)]))
        steps.append(L.timed("Up and down in time", "The full sweep, up and back, in eighth notes.",
                             tcHandOverHand(36, .major, duration: 0.5), bpm: 72, display: .staff, rules: [.evenVelocity(maxStdDev: 12)]))
        return lesson("technique.arpeggios.handoverhand", "Hand-over-hand arpeggios",
                      "Sweep a chord across four octaves by alternating hands.", steps)
    }

    fileprivate static func tcExtended(_ root: Int, _ type: ChordType, hand: Hand, duration: Double = 1, descend: Bool = true) -> [ExpectedEvent] {
        let up = Music.arpeggio(root: root, type: type, octaves: 2)
        let one = TC.arpFingers(root: root, type: type, hand: hand)
        // The upper octave repeats the shape; only a right-hand thumb start needs the 5th finger on top.
        let fingers: [Int] = (hand != .left && one[0] == 1) ? [1, 2, 3, 1, 2, 3, 5] : one + Array(one[1...3])
        return TC.custom(up, fingers, hand: hand, duration: duration, descend: descend)
    }

    fileprivate static var tcExtendedArpeggioLesson: Lesson {
        var steps: [Step] = []
        steps.append(L.info("Arpeggios over two octaves", """
            To continue an arpeggio in **one hand**, the thumb must pass under — and the distance is much bigger than in a scale: from G all the way to the next C.

            Right hand, C major: **1 2 3**, thumb under, **1 2 3 5**.

            - Do not twist the wrist or swing the elbow out to reach. Instead let the whole **arm glide sideways** so the hand is carried to the new position.
            - As finger 3 plays, the thumb is already moving behind it.
            - At speed the join is not truly legato — it is a quick, quiet shift. Never accent the thumb.
            """, keys: L.keys(Music.arpeggio(root: 60, type: .major, octaves: 2), labels: ["1", "2", "3", "1", "2", "3", "5"], hand: .right),
            example: L.timedTask("C major, two octaves", "", tcExtended(60, .major, hand: .right, duration: 0.5), bpm: 96,
                                 display: .staff, clef: .treble)))
        steps.append(L.play("The crossing by itself", "Just the join: E, G, then thumb under to C — and back with finger 3 over. Repeat until it feels easy.",
                            L.line("E4 G4 C5 G4 E4 G4 C5 G4 E4", hand: .right, fingers: "2 3 1 3 2 3 1 3 2"), display: .staff, clef: .treble))
        steps.append(L.play("C major, right hand, going up", "Two octaves: 1 2 3, 1 2 3, 5.",
                            tcExtended(60, .major, hand: .right, descend: false), display: .staff, clef: .treble))
        steps.append(L.play("C major, right hand, up and down", "Coming down, finger 3 swings over the thumb.",
                            tcExtended(60, .major, hand: .right), display: .staff, clef: .treble))
        steps.append(L.play("C major, left hand", "Left hand: 5 4 2 1, then finger 4 crosses over the thumb: 4 2 1.",
                            tcExtended(36, .major, hand: .left), display: .staff, clef: .bass))
        steps.append(L.play("A minor, right hand", "The same shape on A–C–E.",
                            tcExtended(57, .minor, hand: .right), display: .staff, clef: .treble))
        steps.append(L.play("E♭ major, right hand", "A black-key arpeggio: start on finger 2 and let the thumb take the white key G. 2 1 2 4, 1 2 4.",
                            tcExtended(63, .major, hand: .right), display: .staff, clef: .treble, key: -3))
        steps.append(L.play("C major, hands together", "Both hands, two octaves. The crossings come at different moments, so start slowly.",
                            L.together(tcExtended(60, .major, hand: .right), tcExtended(36, .major, hand: .left)), display: .staff))
        steps.append(L.timed("C major in time", "Right hand, eighth notes. Listen for a thumb that is no louder than the rest.",
                             tcExtended(60, .major, hand: .right, duration: 0.5), bpm: 72, display: .staff, clef: .treble,
                             rules: [.evenVelocity(maxStdDev: 12)]))
        return lesson("technique.arpeggios.extended", "Extended arpeggios",
                      "Two-octave arpeggios in one hand with the thumb passing under.", steps)
    }

    // MARK: - Arpeggios in every key

    fileprivate static var tcArpeggioKeysUnit: CurriculumUnit {
        unit("technique.arpkeys", "Triad arpeggios in all 12 keys", TC.circleMajor.map { tcArpeggioKeyLesson($0) })
    }

    fileprivate static func tcArpeggioKeyLesson(_ pc: Int) -> Lesson {
        let majorName = TC.majorNames[pc]
        let minorName = TC.minorNames[pc]
        let majorFlats = Music.prefersFlats(tonicPC: pc)
        let minorFlats = Music.prefersFlats(tonicPC: pc, minor: true)
        let hi = 60 + pc
        let lo = 36 + pc
        let majorNotes = Music.arpeggio(root: hi, type: .major)
        let minorNotes = Music.arpeggio(root: hi, type: .minor)
        let rhMajor = TC.arpFingers(root: hi, type: .major, hand: .right)
        let lhMajor = TC.arpFingers(root: lo, type: .major, hand: .left)
        let rhMinor = TC.arpFingers(root: hi, type: .minor, hand: .right)
        let lhMinor = TC.arpFingers(root: lo, type: .minor, hand: .left)
        let majorLabels = TC.names(majorNotes, flats: majorFlats)
        let minorLabels = TC.names(minorNotes, flats: minorFlats)
        let blackTip = Music.isBlack(pc) && rhMajor[0] != 1
            ? "\n\nThe root is a black key, so the hand starts on a long finger and the thumb takes a white key."
            : ""

        var steps: [Step] = []
        steps.append(L.info("\(majorName) major triad", """
            \(majorName) major is **\(majorLabels.prefix(3).joined(separator: " – "))**: root, major 3rd, perfect 5th.

            - Right hand: **\(TC.text(rhMajor))**
            - Left hand: **\(TC.text(lhMajor))**\(blackTip)
            """, keys: L.keys(majorNotes, labels: majorLabels, hand: .right),
            example: L.timedTask("\(majorName) major arpeggio", "", TC.arp(hi, .major, hand: .right, duration: 0.5), bpm: 96,
                                 display: .staff, clef: .treble, flats: majorFlats)))
        steps.append(L.play("\(majorName) major inversions", "Block chords, right hand: root position, first inversion, second inversion, root position.",
                            L.chords(TC.inversions(hi, .major), hand: .right, fingers: TC.rhBlockFingers,
                                     labels: ["root", "1st inv", "2nd inv", "root"]),
                            display: .staff, clef: .treble, flats: majorFlats))
        steps.append(L.play("\(majorName) major arpeggio, right hand", "One octave up and down.",
                            TC.arp(hi, .major, hand: .right), display: .staff, clef: .treble, flats: majorFlats))
        steps.append(L.play("\(majorName) major arpeggio, left hand", "One octave up and down.",
                            TC.arp(lo, .major, hand: .left), display: .staff, clef: .bass, flats: majorFlats))
        steps.append(L.info("\(minorName) minor triad", """
            Lower the middle note by a half step and the chord turns minor: **\(minorLabels.prefix(3).joined(separator: " – "))**.

            - Right hand: **\(TC.text(rhMinor))**
            - Left hand: **\(TC.text(lhMinor))**
            """, keys: L.keys(minorNotes, labels: minorLabels, hand: .right),
            example: L.timedTask("\(minorName) minor arpeggio", "", TC.arp(hi, .minor, hand: .right, duration: 0.5), bpm: 96,
                                 display: .staff, clef: .treble, flats: minorFlats)))
        steps.append(L.play("\(minorName) minor arpeggio, right hand", "One octave up and down.",
                            TC.arp(hi, .minor, hand: .right), display: .staff, clef: .treble, flats: minorFlats))
        steps.append(L.play("\(minorName) minor arpeggio, left hand", "One octave up and down.",
                            TC.arp(lo, .minor, hand: .left), display: .staff, clef: .bass, flats: minorFlats))
        steps.append(L.timed("\(majorName) major, hands together in time", "Both hands, eighth notes with the metronome. Even tone, no accent on the thumbs.",
                             L.together(TC.arp(hi, .major, hand: .right, duration: 0.5), TC.arp(lo, .major, hand: .left, duration: 0.5)),
                             bpm: 66, display: .staff, flats: majorFlats, rules: [.evenVelocity(maxStdDev: 12)]))
        return lesson("technique.arpkeys.\(TC.slugs[pc])", "\(majorName) major and \(minorName) minor arpeggios",
                      "Triads on \(majorName): inversions and one-octave arpeggios in both hands.", steps)
    }
}
