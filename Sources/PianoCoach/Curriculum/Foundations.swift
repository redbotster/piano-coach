import Foundation

extension Curriculum {
    static var foundations: CurriculumSection {
        CurriculumSection(id: "foundations", title: "Foundations", symbol: "pianokeys",
                          units: [fOrientation, fSetup, fFirstPlaying, fMidiSkills])
    }

    // MARK: - Helpers

    /// Every key with the given pitch class on the 61-key keyboard, low to high.
    fileprivate static func allKeys(pc: Int) -> [Int] {
        (Music.lowestKey...Music.highestKey).filter { Music.pc($0) == pc }
    }

    /// Give each note the finger it gets in a five-finger position.
    fileprivate static func fingered(_ events: [ExpectedEvent], position: [Int], hand: Hand) -> [ExpectedEvent] {
        events.map { event in
            var e = event
            e.notes = e.notes.map { spec in
                var s = spec
                if let i = position.firstIndex(of: spec.midi) { s.finger = hand == .left ? 5 - i : i + 1 }
                return s
            }
            return e
        }
    }

    fileprivate static func upDown(_ position: [Int]) -> [Int] { position + position.dropLast().reversed() }

    // MARK: - Unit 1: Instrument orientation

    fileprivate static var fOrientation: CurriculumUnit {
        let twos = (Music.lowestKey...Music.highestKey).filter { [1, 3].contains(Music.pc($0)) }
        let threes = (Music.lowestKey...Music.highestKey).filter { [6, 8, 10].contains(Music.pc($0)) }
        let twoGroups = stride(from: 37, through: 85, by: 12).map { [$0, $0 + 2] }
        let threeGroups = stride(from: 42, through: 90, by: 12).map { [$0, $0 + 2, $0 + 4] }
        let letters = ["C", "D", "E", "F", "G", "A", "B"]
        let letterPC = [0, 2, 4, 5, 7, 9, 11]

        let layout = lesson("foundations.orientation.layout", "The keyboard layout",
                            "Black keys come in twos and threes — use them to find every note.", [
            L.info("Twos and threes",
                   "Look at your Launchkey. The white keys all look alike, but the **black keys** are arranged in a repeating pattern: a group of **two**, then a group of **three**, over and over.\n\nThat pattern is your map. On screen, the groups of two are orange and the groups of three are blue. Every white key gets its name from where it sits relative to these groups.",
                   keys: L.keys(twos, hand: .left) + L.keys(threes, hand: .right)),
            L.play("Play the groups of two",
                   "Using two fingers together, play each **group of two black keys**, from the lowest (left) to the highest (right). The keys light up to guide you.",
                   L.chords(twoGroups, hand: .either)),
            L.play("Play the groups of three",
                   "Now play each **group of three black keys** with three fingers together, low to high.",
                   L.chords(threeGroups, hand: .either)),
            L.info("Finding C",
                   "**C** is the white key immediately to the **left of every group of two** black keys.\n\nYour keyboard has six Cs. The one with a dot on screen is **Middle C**, the most important landmark on the piano.",
                   keys: L.keys(allKeys(pc: 0), labels: Array(repeating: "C", count: 6))),
            L.play("Play every C", "Play all six Cs from the lowest to the highest.", L.line(allKeys(pc: 0), hand: .either)),
            L.info("D and E",
                   "The group of two black keys has three white keys around it:\n\n- **C** is on the left\n- **D** is in the middle, between the two black keys\n- **E** is on the right",
                   keys: L.keys("C4 D4 E4")),
            L.play("C, D, E in every octave", "Play C–D–E around each group of two, low to high.",
                   L.line((2...6).flatMap { o in [0, 2, 4].map { (o + 1) * 12 + $0 } }, hand: .either)),
            L.info("F, G, A and B",
                   "The group of three black keys has four white keys around it:\n\n- **F** is on the left\n- **G** and **A** sit between the black keys\n- **B** is on the right\n\nThen the pattern starts again at C.",
                   keys: L.keys("F4 G4 A4 B4")),
            L.play("F, G, A, B in every octave", "Play F–G–A–B around each group of three, low to high.",
                   L.line((2...6).flatMap { o in [5, 7, 9, 11].map { (o + 1) * 12 + $0 } }, hand: .either)),
            L.quiz("Find the key", "No lights this time. Play the named key **anywhere** on the keyboard. Use the black-key groups to find it.",
                   rounds: 12) { _ in
                let i = Int.random(in: 0..<7)
                return L.task("Play any \(letters[i])", "", [ExpectedEvent(notes: [NoteSpec(midi: 60 + letterPC[i], hand: .either)], beat: 0)],
                              showTargets: false, anyOctave: true)
            },
        ])

        let octaves = lesson("foundations.orientation.octaves", "Octaves, register and Middle C",
                             "Low is left, high is right, and the same seven notes repeat in every octave.", [
            L.info("What is an octave?",
                   "The distance from one note to the next note with the **same name** is an **octave** — eight white keys counting both ends. Notes an octave apart sound like the same note, just higher or lower.\n\nYour Launchkey 61 has **five octaves**: 61 keys running from a low C on the far left to a high C on the far right.",
                   keys: L.keys("C3 C4", labels: true)),
            L.play("Feel an octave", "Play C, then the next C up, in each octave.",
                   L.line("C2 C3 C3 C4 C4 C5 C5 C6 C6 C7", hand: .either)),
            L.info("Register: low, middle, high",
                   "**Left is low**, **right is high**.\n\n- The **low register** (left) sounds deep; it's usually the left hand's home.\n- The **middle register** is where most melodies live.\n- The **high register** (right) sounds bright.\n\nTo tell octaves apart, each one is numbered. The lowest C here is **C2**, then C3, C4, C5, C6 and the top key, C7. Every note takes the number of the C below it, so the D above C4 is D4.",
                   keys: L.keys(allKeys(pc: 0), labels: ["C2", "C3", "C4", "C5", "C6", "C7"])),
            L.play("Lowest to highest", "Play the lowest key on your keyboard, then the highest.",
                   L.line("C2 C7", hand: .either)),
            L.info("Middle C",
                   "**Middle C (C4)** is the C nearest the middle of a full piano. On your Launchkey it is the **third C from the left**. Right-hand melodies usually start near here, and it's the note that links the two staves when you read music.\n\nIf the on-screen keyboard lights the wrong octave when you play, press the **Octave −/+** buttons on the Launchkey until both are unlit.",
                   keys: L.keys([60], labels: ["Middle C"])),
            L.play("Find Middle C", "Play Middle C three times, then the C above it and the C below it.",
                   L.line("C4 C4 C4 C5 C3 C4", hand: .either)),
            L.quiz("Which C? Which octave?", "Play the exact key named. The octave number matters now.", rounds: 10) { _ in
                let octave = Int.random(in: 2...6)
                let i = [0, 0, 0, 2, 4, 5, 7][Int.random(in: 0..<7)]
                let note = (octave + 1) * 12 + i
                return L.task("Play \(Music.name(note))", "", [ExpectedEvent(notes: [NoteSpec(midi: note, hand: .either)], beat: 0)],
                              showTargets: false)
            },
        ])

        let names = lesson("foundations.orientation.names", "Note names: the A–G cycle",
                           "The musical alphabet has only seven letters, and it loops.", [
            L.info("Seven letters",
                   "Music uses just seven letter names: **A B C D E F G**. After G comes A again, one octave higher.\n\nGoing **up** (to the right) the alphabet goes forwards. Going **down** (to the left) it goes backwards: G F E D C B A.",
                   keys: L.keys("A3 B3 C4 D4 E4 F4 G4 A4")),
            L.play("Up the alphabet", "Play A B C D E F G A, saying each letter aloud.",
                   L.line("A3 B3 C4 D4 E4 F4 G4 A4", hand: .either)),
            L.play("Down the alphabet", "Now backwards: A G F E D C B A. Say the letters as you go.",
                   L.line("A4 G4 F4 E4 D4 C4 B3 A3", hand: .either)),
            L.info("Neighbours",
                   "It helps to know each letter's neighbours instantly, in both directions. What comes after G? **A**. What comes before C? **B**. What is two letters above E? **G**.\n\nSkipping a letter (C to E, E to G) is a **skip**; moving to the next letter is a **step**. You'll use both constantly when reading music."),
            L.play("Skips", "Play every other letter: C E G B D F A C.", L.line("C4 E4 G4 B4 D5 F5 A5 C6", hand: .either)),
            L.quiz("Name it, play it", "Play the named note in the octave shown — no lights.", rounds: 12) { _ in
                let i = Int.random(in: 0..<7)
                let octave = Int.random(in: 3...5)
                let note = (octave + 1) * 12 + letterPC[i]
                return L.task("Play \(Music.name(note))", "", [ExpectedEvent(notes: [NoteSpec(midi: note, hand: .either)], beat: 0)],
                              showTargets: false)
            },
        ])

        let blackNames = ["C♯", "D♭", "D♯", "E♭", "F♯", "G♭", "G♯", "A♭", "A♯", "B♭"]
        let blackPC = [1, 1, 3, 3, 6, 6, 8, 8, 10, 10]
        let accidentals = lesson("foundations.orientation.accidentals", "Sharps, flats and enharmonics",
                                 "Every black key has two names — and so do some white keys.", [
            L.info("Sharp means up",
                   "A **sharp** (♯) raises a note to the very next key on the right. **C♯** is the black key just right of C.",
                   glyph: "♯", keys: L.keys([60, 61], labels: ["C", "C♯"])),
            L.play("Play the sharps", "Play each white key, then its sharp: C C♯, D D♯, F F♯, G G♯, A A♯.",
                   L.line("C4 C#4 D4 D#4 F4 F#4 G4 G#4 A4 A#4", hand: .either)),
            L.info("Flat means down",
                   "A **flat** (♭) lowers a note to the very next key on the left. **D♭** is the black key just left of D.\n\nWait — that's the same key as C♯!",
                   glyph: "♭", keys: L.keys([62, 61], labels: ["D", "D♭"])),
            L.play("Play the flats", "Play each white key, then its flat: D D♭, E E♭, G G♭, A A♭, B B♭.",
                   L.line("D4 Db4 E4 Eb4 G4 Gb4 A4 Ab4 B4 Bb4", hand: .either)),
            L.info("Enharmonic equivalents",
                   "Two names for the same key are called **enharmonic equivalents**: C♯ = D♭, D♯ = E♭, F♯ = G♭, G♯ = A♭, A♯ = B♭.\n\nWhich name is used depends on the key the music is in — you'll see why when you learn key signatures.\n\nWhite keys can have second names too. There's no black key between E and F or between B and C, so **E♯ is F**, **F♭ is E**, **B♯ is C** and **C♭ is B**. A **natural** sign (♮) cancels a sharp or flat.",
                   glyph: "♮", keys: L.keys([61, 63, 66, 68, 70], labels: ["C♯ D♭", "D♯ E♭", "F♯ G♭", "G♯ A♭", "A♯ B♭"])),
            L.quiz("Sharps and flats", "Play the named note anywhere on the keyboard.", rounds: 14) { _ in
                let i = Int.random(in: 0..<blackNames.count)
                return L.task("Play any \(blackNames[i])", "", [ExpectedEvent(notes: [NoteSpec(midi: 60 + blackPC[i], hand: .either)], beat: 0)],
                              showTargets: false, anyOctave: true)
            },
            L.quiz("Tricky spellings", "These are white keys in disguise.", rounds: 6) { round in
                let options: [(String, Int)] = [("E♯", 5), ("F♭", 4), ("B♯", 0), ("C♭", 11), ("E♯", 5), ("C♭", 11)]
                let pick = options[round % options.count]
                return L.task("Play any \(pick.0)", "", [ExpectedEvent(notes: [NoteSpec(midi: 60 + pick.1, hand: .either)], beat: 0)],
                              showTargets: false, anyOctave: true)
            },
        ])

        let steps = lesson("foundations.orientation.steps", "Half steps and whole steps",
                           "The two building blocks of every scale.", [
            L.info("Half steps",
                   "A **half step** (semitone) is the distance from one key to the very next key — black or white, with nothing in between. C to C♯ is a half step. So is E to F, because there is no black key between them.",
                   keys: L.keys([60, 61, 64, 65], labels: ["C", "C♯", "E", "F"])),
            L.play("Climb by half steps", "Play every key from C up to the next C, black and white. That's twelve half steps.",
                   L.line(Array(60...72), hand: .either)),
            L.info("Whole steps",
                   "A **whole step** (tone) is **two half steps** — you skip exactly one key. C to D is a whole step (skipping C♯). E to F♯ is a whole step (skipping F).",
                   keys: L.keys([60, 62, 64, 66], labels: ["C", "D", "E", "F♯"])),
            L.play("Climb by whole steps", "Play C D E F♯ G♯ A♯ C: every move skips one key.",
                   L.line("C4 D4 E4 F#4 G#4 A#4 C5", hand: .either)),
            L.info("Why it matters",
                   "Scales are recipes of whole and half steps. The **major scale** is **W W H W W W H**. Start on C and that recipe lands on white keys only: C D E F G A B C. Start anywhere else and you'll need black keys to keep the recipe.",
                   keys: L.keys("C4 D4 E4 F4 G4 A4 B4 C5")),
            L.play("The recipe from C", "Play the C major scale and notice the half steps: E–F and B–C.",
                   L.line("C4 D4 E4 F4 G4 A4 B4 C5", fingers: "1 2 3 1 2 3 4 5")),
            L.play("The same recipe from G", "W W H W W W H starting on G needs one black key: F♯.",
                   L.line("G3 A3 B3 C4 D4 E4 F#4 G4", fingers: "1 2 3 1 2 3 4 5")),
            L.quiz("Step quiz", "Work out the answer and play it (any octave).", rounds: 12) { _ in
                let base = Int.random(in: 0..<12)
                let kinds: [(String, Int)] = [("half step above", 1), ("half step below", -1), ("whole step above", 2), ("whole step below", -2)]
                let kind = kinds[Int.random(in: 0..<4)]
                let flats = kind.1 < 0
                let name = (flats ? Music.flatNames : Music.sharpNames)[base]
                return L.task("A \(kind.0) \(name)", "", [ExpectedEvent(notes: [NoteSpec(midi: 60 + (base + kind.1 + 12) % 12, hand: .either)], beat: 0)],
                              showTargets: false, anyOctave: true)
            },
        ])

        return unit("foundations.orientation", "Instrument orientation", [layout, octaves, names, accidentals, steps])
    }

    // MARK: - Unit 2: Physical setup

    fileprivate static var fSetup: CurriculumUnit {
        let cRight = Music.notes("C4 D4 E4 F4 G4")
        let cLeft = Music.notes("C3 D3 E3 F3 G3")

        let posture = lesson("foundations.setup.posture", "Posture, bench height and distance",
                             "Set yourself up so playing is comfortable and injury-free.", [
            L.info("Why posture comes first",
                   "Good technique starts before you play a note. A keyboard on a desk is often **too high** and a desk chair often **too low**, which forces your wrists to bend and your shoulders to lift. A few minutes of setup now prevents tension and pain later.\n\nMIDI can't see your body, so these steps ask you to check yourself. A mirror or a phone video from the side is a big help.",
                   links: [.video("piano posture and bench height for beginners")]),
            L.checklist("Height", "Sit at the keyboard and let your arms hang, then bring your hands to the keys.",
                        items: [
                            "My forearms are roughly level with the floor — elbows at or slightly above the height of the white keys.",
                            "My wrists are level: not dropped below the keys, not arched high above them.",
                            "My shoulders are down and loose, not lifted towards my ears.",
                            "If the keyboard is too high, I've raised my seat (cushion) or lowered the keyboard (a stand helps).",
                        ]),
            L.checklist("Distance and position", "Now check where you are sitting.",
                        items: [
                            "I'm sitting on the front half of the seat, not leaning on a backrest.",
                            "My elbows are slightly in front of my body, with a comfortable bend — I can reach the keys without leaning.",
                            "My belly button is roughly in line with Middle C.",
                            "Both feet are flat on the floor (the right foot can reach the sustain pedal if I have one).",
                            "My back is tall but not stiff, and I can lean left and right from the hips to reach the far keys.",
                        ]),
            L.play("Reach test", "Staying seated tall, lean from the hips to play the lowest C, Middle C, and the highest C. Your feet stay planted.",
                   L.line("C2 C4 C7 C4 C2", hand: .either)),
        ])

        let handShape = lesson("foundations.setup.hands", "Hand shape",
                               "Curved fingers and a level, relaxed wrist.", [
            L.info("The natural hand",
                   "Stand up and let your arm hang at your side. Look at your hand: the fingers curve gently, as if holding a small ball. **That is your piano hand shape.** Bring it to the keys without changing it.\n\n- Fingers **curved**, playing on the **pads near the fingertips** (not flat, not on the nails)\n- The **thumb** plays on the **side of its tip**, lying relaxed along the key\n- **Knuckles** form a gentle arch — they shouldn't collapse inward\n- The **wrist** is level and loose, a bridge between forearm and hand",
                   links: [.video("piano hand position curved fingers beginner")]),
            L.checklist("Shape check", "Rest your right hand on C–D–E–F–G (thumb on Middle C) without pressing.",
                        items: [
                            "My fingers are curved, like holding a small ball or a bubble.",
                            "My fingertips (not flat fingers) touch the keys; my thumb rests on its side.",
                            "My knuckles are the highest point of my hand — the arch hasn't collapsed.",
                            "My wrist is level with my forearm and feels loose.",
                            "My fingernails are short enough that the pads can reach the keys.",
                        ]),
            L.play("Keep the shape while you play",
                   "Play slowly with your right hand, thumb on Middle C. After each note, glance at your hand: still curved? Wrist still level?",
                   fingered(L.line(upDown(cRight)), position: cRight, hand: .right)),
            L.play("Left hand too",
                   "Same check with the left hand, little finger on the C below Middle C.",
                   fingered(L.line(upDown(cLeft), hand: .left), position: cLeft, hand: .left)),
        ])

        let fingers = lesson("foundations.setup.fingers", "Finger numbers",
                             "Thumbs are 1, little fingers are 5 — in both hands.", [
            L.info("One to five",
                   "Pianists number their fingers so that music can tell you which one to use:\n\n- **1** — thumb\n- **2** — index finger\n- **3** — middle finger\n- **4** — ring finger\n- **5** — little finger\n\nIt's the same in **both hands**: thumbs are always 1. That means the hands mirror each other — going up the keyboard, the right hand counts 1-2-3-4-5 but the left hand counts 5-4-3-2-1.\n\nIn this app, the number in the circle on a lit key is the finger to use. **Blue is right hand, orange is left hand.**"),
            L.play("Right hand 1 to 5", "Thumb (1) on Middle C. Play up to 5 and back, using the finger shown on each key.",
                   fingered(L.line(upDown(cRight)), position: cRight, hand: .right)),
            L.play("Left hand 5 to 1", "Left little finger (5) on the C below Middle C. Play up to your thumb and back.",
                   fingered(L.line(upDown(cLeft), hand: .left), position: cLeft, hand: .left)),
            L.quiz("Right-hand finger quiz", "Keep your right hand over C–D–E–F–G (thumb on Middle C) and play with the finger named.", rounds: 10) { _ in
                let finger = Int.random(in: 1...5)
                return L.task("Right hand: finger \(finger)", "", [ExpectedEvent(notes: [NoteSpec(midi: cRight[finger - 1], hand: .right)], beat: 0)],
                              showTargets: false)
            },
            L.quiz("Left-hand finger quiz", "Left hand over C–D–E–F–G below Middle C (little finger on C). Play with the finger named.", rounds: 10) { _ in
                let finger = Int.random(in: 1...5)
                return L.task("Left hand: finger \(finger)", "", [ExpectedEvent(notes: [NoteSpec(midi: cLeft[5 - finger], hand: .left)], beat: 0)],
                              showTargets: false)
            },
            L.play("Same fingers together", "Play both hands at once, same finger numbers: 1 and 1, 2 and 2… The hands move in opposite directions.",
                   L.together(fingered(L.line(cRight), position: cRight, hand: .right),
                              fingered(L.line(Array(cLeft.reversed()), hand: .left), position: cLeft, hand: .left))),
        ])

        let weight = lesson("foundations.setup.weight", "Arm weight and relaxation",
                            "Let gravity make the sound; never squeeze or press.", [
            L.info("Weight, not force",
                   "A good piano sound comes from the **weight of your arm** dropping into the key through a firm fingertip — not from pushing with a stiff finger.\n\nTry it away from the keyboard: lift your forearm a few centimetres and let it **drop** onto your knee, completely loose. That heavy, relaxed feeling is what you want arriving in the keys.\n\nOnce a key is down, **stop pressing**. Holding a key takes almost no effort; extra pressure does nothing to the sound and only builds tension.",
                   links: [.video("piano arm weight relaxation exercise")]),
            L.checklist("Tension scan", "Play a few notes, freeze, and scan your body from the top down.",
                        items: [
                            "Jaw unclenched, breathing normally.",
                            "Shoulders low; I can shrug and drop them.",
                            "Elbows hang loosely, not pinned to my sides or sticking out.",
                            "Wrists can bounce gently up and down while a key is held.",
                            "Fingers that aren't playing rest on the keys instead of sticking up in the air.",
                        ]),
            L.play("Drop and release", "With finger 3 of the right hand, **drop** your arm weight into each lit key, let the wrist float up as you release, then drop into the next. Slow and heavy.",
                   L.line("C4 E4 G4 E4 C4", fingers: "3 3 3 3 3")),
            L.play("Weight makes a full sound", "Play the five notes with relaxed arm weight. Aim for a full, round **mf**: the Velocity meter above the on-screen keyboard should read about 60–90.",
                   fingered(L.line(upDown(cRight)), position: cRight, hand: .right), rules: [L.mf]),
            L.play("Light arm, soft sound", "Now let less weight fall: play the same notes softly (**p**, velocity about 25–58). Stay just as relaxed — soft does not mean tense.",
                   fingered(L.line(upDown(cRight)), position: cRight, hand: .right), rules: [L.p]),
            L.info("Make it a habit",
                   "Tension creeps in when you concentrate. Build these habits now:\n\n- Check your shoulders and wrists at the start of every exercise\n- If something feels tight, stop, shake out your hands, and restart slower\n- **Pain is never part of practising.** If anything hurts, stop for the day"),
        ])

        return unit("foundations.setup", "Physical setup", [posture, handShape, fingers, weight])
    }

    // MARK: - Unit 3: First playing

    fileprivate static func positionLesson(_ name: String, right: String, left: String, note: String) -> Lesson {
        let r = Music.notes(right)
        let l = Music.notes(left)
        let flats = name == "F"
        let rightLine = fingered(L.line(upDown(r)), position: r, hand: .right)
        let leftLine = fingered(L.line(upDown(l), hand: .left), position: l, hand: .left)
        let labels = r.map { Music.name($0, flats: flats, octave: false) }
        return lesson("foundations.first.position-\(name.lowercased())", "\(name) position",
                      "Five fingers over five neighbouring notes starting on \(name).", [
            L.info("The \(name) five-finger position",
                   "In a **five-finger position** each finger gets its own key and the hand doesn't move. In **\(name) position** the right thumb and the left little finger both sit on \(name).\n\n\(note)\n\nPlace both hands now: right hand on the blue keys, left hand on the orange keys.",
                   keys: L.keys(r, labels: labels, hand: .right) + L.keys(l, labels: labels, hand: .left)),
            L.play("Right hand", "Play up and back down with the right hand. Use the finger shown on each key and keep the others resting on their keys.", rightLine),
            L.play("Left hand", "Now the left hand: little finger (5) starts.", leftLine),
            L.play("Hands together", "Both hands play the same notes an octave apart. Go slowly — the fingers don't match (right 1 plays with left 5).",
                   L.together(rightLine, leftLine)),
            L.timed("Right hand with the metronome", "One note per click. Listen to the four-click count-in, then start on the next click.",
                    rightLine + fingered(L.line([r[0]], start: 9), position: r, hand: .right),
                    bpm: 66, display: .staffAndRhythm, flats: flats),
            L.timed("Left hand with the metronome", "Same again with the left hand.",
                    leftLine + fingered(L.line([l[0]], hand: .left, start: 9), position: l, hand: .left),
                    bpm: 66, display: .staffAndRhythm, flats: flats),
        ])
    }

    fileprivate static var fFirstPlaying: CurriculumUnit {
        let cR = Music.notes("C4 D4 E4 F4 G4")
        let cL = Music.notes("C3 D3 E3 F3 G3")

        let positions = [
            positionLesson("C", right: "C4 D4 E4 F4 G4", left: "C3 D3 E3 F3 G3",
                           note: "C position uses only white keys: **C D E F G**."),
            positionLesson("G", right: "G4 A4 B4 C5 D5", left: "G2 A2 B2 C3 D3",
                           note: "G position is also all white keys: **G A B C D**. Notice the hand feels the same — only the place has changed."),
            positionLesson("F", right: "F4 G4 A4 Bb4 C5", left: "F2 G2 A2 Bb2 C3",
                           note: "F position has one black key: **F G A B♭ C**. Finger 4 of the right hand (finger 2 of the left) plays B♭. Slide the hand slightly forward so the black key is easy to reach."),
            positionLesson("D", right: "D4 E4 F#4 G4 A4", left: "D3 E3 F#3 G3 A3",
                           note: "D position has one black key in the middle: **D E F♯ G A**. Finger 3 plays F♯ in both hands — the longest finger on the black key feels natural."),
            positionLesson("A", right: "A4 B4 C#5 D5 E5", left: "A2 B2 C#3 D3 E3",
                           note: "A position mirrors D position: **A B C♯ D E**, with finger 3 on the black key again."),
        ]

        let mary = fingered(L.melody("E4:q D4:q C4:q D4:q | E4:q E4:q E4:h | D4:q D4:q D4:h | E4:q G4:q G4:h | E4:q D4:q C4:q D4:q | E4:q E4:q E4:q E4:q | D4:q D4:q E4:q D4:q | C4:w"),
                            position: cR, hand: .right)
        let buns = fingered(L.melody("E4:q D4:q C4:h | E4:q D4:q C4:h | C4:e C4:e C4:e C4:e D4:e D4:e D4:e D4:e | E4:q D4:q C4:h"),
                            position: cR, hand: .right)
        let ode1 = "E4:q E4:q F4:q G4:q | G4:q F4:q E4:q D4:q | C4:q C4:q D4:q E4:q | E4:q. D4:e D4:h"
        let ode2 = "E4:q E4:q F4:q G4:q | G4:q F4:q E4:q D4:q | C4:q C4:q D4:q E4:q | D4:q. C4:e C4:h"
        let ode = fingered(L.melody(ode1 + " | " + ode2), position: cR, hand: .right)
        let clair = fingered(L.melody("C3:q C3:q C3:q D3:q | E3:h D3:h | C3:q E3:q D3:q D3:q | C3:w", hand: .left),
                             position: cL, hand: .left)
        let lightly = fingered(L.melody("G3:q E3:q E3:h | F3:q D3:q D3:h | C3:q D3:q E3:q F3:q | G3:q G3:q G3:h", hand: .left),
                               position: cL, hand: .left)

        let melodies = lesson("foundations.first.melodies", "Single-hand melodies",
                              "Real tunes in C position, one hand at a time.", [
            L.info("From exercises to music",
                   "You can already play real melodies: plenty of tunes fit inside the five notes under your hand.\n\nEach tune appears twice. First **untimed** — the lesson waits for every note, so take your time finding the keys. Then **with the metronome**, where the music keeps moving. Press **Demo** to hear a tune first. If the metronome version runs away from you, lower the tempo with **BPM −** or turn on **Wait for me**.\n\nThe blocks in the timeline show how long each note lasts: longer block, longer note. Hold each key down for the full length of its block.",
                   keys: L.keys(cR, labels: ["C", "D", "E", "F", "G"], hand: .right)),
            L.play("Hot Cross Buns — find the notes", "Right hand in C position. Follow the lit keys and finger numbers.", buns, display: .staff),
            L.timed("Hot Cross Buns — in time", "Now with the metronome. The quick notes in bar 3 go two to a click.", buns,
                    bpm: 72, display: .staffAndRhythm),
            L.play("Mary Had a Little Lamb — find the notes", "Right hand, C position.", mary, display: .staff),
            L.timed("Mary Had a Little Lamb — in time", "Keep going even if you slip — the music doesn't wait.", mary,
                    bpm: 84, display: .staffAndRhythm),
            L.play("Ode to Joy — find the notes", "Beethoven's famous theme fits C position perfectly.", ode, display: .staff),
            L.timed("Ode to Joy — in time", "Watch the dotted rhythm at the end of each line: long–short–long.", ode,
                    bpm: 84, display: .staffAndRhythm),
            L.play("Au Clair de la Lune — left hand", "The left hand gets a tune too. Little finger on the C below Middle C.", clair, display: .staff),
            L.timed("Au Clair de la Lune — in time", "Left hand with the metronome.", clair, bpm: 76, display: .staffAndRhythm),
            L.timed("Lightly Row — left hand", "Another left-hand melody, starting on the thumb (G).", lightly, bpm: 76, display: .staffAndRhythm),
        ])

        let question = fingered(L.melody("C4:q D4:q E4:q F4:q | G4:h r:h"), position: cR, hand: .right)
        let answer = fingered(L.melody("G3:q F3:q E3:q D3:q | C3:h", hand: .left, start: 8), position: cL, hand: .left)
        let odeRight = fingered(L.melody(ode1), position: cR, hand: .right)
        let odeLeft = fingered(L.melody("E3:q E3:q F3:q G3:q | G3:q F3:q E3:q D3:q | C3:q C3:q D3:q E3:q | D3:q. C3:e C3:h", hand: .left, start: 16),
                               position: cL, hand: .left)
        let pingPong = L.together(
            fingered(L.melody("C4:q r:q E4:q r:q | G4:q r:q E4:q r:q | C4:q r:q D4:q r:q | E4:h r:h"), position: cR, hand: .right),
            fingered(L.melody("r:q C3:q r:q E3:q | r:q G3:q r:q E3:q | r:q C3:q r:q D3:q | r:h C3:h", hand: .left), position: cL, hand: .left))

        let alternating = lesson("foundations.first.alternating", "Hands alternating",
                                 "Pass a melody from one hand to the other.", [
            L.info("Taking turns",
                   "Before the hands play at the same time, they learn to **take turns** without the beat stumbling. Keep **both hands on the keys** in C position the whole time — the resting hand stays ready, it doesn't drop into your lap.\n\nIn the timeline, the top lane is the right hand and the bottom lane is the left.",
                   keys: L.keys(cR, hand: .right) + L.keys(cL, hand: .left)),
            L.play("Question and answer", "The right hand asks (going up), the left hand answers (coming down).", question + answer, display: .staff),
            L.timed("Question and answer — in time", "Now with the metronome. Count the rest at the end of the question.", question + answer,
                    bpm: 76, display: .staffAndRhythm),
            L.timed("Ping-pong", "The hands swap every beat: right, left, right, left. Keep the beat perfectly even as it crosses between hands.", pingPong,
                    bpm: 72, display: .staffAndRhythm),
            L.timed("Ode to Joy, shared", "The right hand plays the first line, then the left hand finishes the tune an octave lower. No gap at the handover!",
                    odeRight + odeLeft, bpm: 80, display: .staffAndRhythm),
        ])

        let rLine = fingered(L.line(upDown(cR)), position: cR, hand: .right)
        let lLine = fingered(L.line(upDown(cL), hand: .left), position: cL, hand: .left)
        let touch = lesson("foundations.first.legato", "Legato and separated notes",
                           "Connect notes smoothly, or leave air between them.", [
            L.info("Legato: smooth and connected",
                   "**Legato** means the notes are joined with no gap, like singing a phrase in one breath. To play legato, **hold each key until the next one goes down** — the fingers hand over like feet when walking: one lands as the other lifts.\n\nThe app measures the gap between releasing one key and pressing the next. For legato it should be zero (a tiny overlap is fine).",
                   example: L.timedTask("Legato", "", L.line(upDown(cR), duration: 1), bpm: 90, display: .rhythm)),
            L.play("Legato, right hand", "Walk up and down C position. Don't let go of a key until the next finger has played.", rLine, rules: [.legato]),
            L.play("Legato, left hand", "The same with the left hand.", lLine, rules: [.legato]),
            L.info("Separated notes",
                   "The opposite touch leaves a little silence between notes: play each key and **release it early**, well before the next. Very short, bouncy notes are called **staccato**.\n\nUse a light, quick finger — like touching something hot — and keep the wrist loose.",
                   example: L.timedTask("Separated", "", L.rhythm("q' q' q' q' q' q' q' q'", note: 60).enumerated().map { i, e in
                       var e = e; e.notes = [NoteSpec(midi: upDown(cR)[i % 9])]; e.label = nil; return e
                   }, bpm: 90, display: .rhythm)),
            L.play("Separated, right hand", "Play each note short and detached, releasing almost as soon as you play.", rLine, rules: [.staccato]),
            L.play("Separated, left hand", "And with the left hand.", lLine, rules: [.staccato]),
            L.timed("Legato in time", "Smooth and connected, one note per click. Each note lasts until the next begins.", rLine,
                    bpm: 72, display: .rhythm, rules: [.legato]),
            L.timed("Separated in time", "Short notes exactly on the clicks — the silence between them is part of the rhythm.", rLine,
                    bpm: 72, display: .rhythm, rules: [.staccato]),
        ])

        return unit("foundations.first", "First playing", positions + [melodies, alternating, touch])
    }

    // MARK: - Unit 4: MIDI skills

    fileprivate static var fMidiSkills: CurriculumUnit {
        let cR = Music.notes("C4 D4 E4 F4 G4")
        let cL = Music.notes("C3 D3 E3 F3 G3")
        let rLine = fingered(L.line(upDown(cR)), position: cR, hand: .right)
        let lLine = fingered(L.line(upDown(cL), hand: .left), position: cL, hand: .left)

        func randomRun(_ position: [Int], hand: Hand, count: Int) -> [ExpectedEvent] {
            var index = Int.random(in: 0..<5)
            var notes: [Int] = []
            for _ in 0..<count {
                notes.append(position[index])
                let move = [-2, -1, -1, 1, 1, 2][Int.random(in: 0..<6)]
                index = min(4, max(0, index + move))
                if notes.last == position[index] { index = index == 4 ? 3 : index + 1 }
            }
            return fingered(L.line(notes, hand: hand), position: position, hand: hand)
        }

        let accuracy = lesson("foundations.midi.accuracy", "Note accuracy",
                              "Hit the right key first time, every time.", [
            L.info("What the app measures",
                   "Because your Launchkey sends every key press to the app, your playing can be measured exactly:\n\n- **Accuracy** — how many notes you played correctly at the first attempt\n- **Wrong notes** — extra or incorrect keys\n- **Timing** — how many milliseconds early or late each note was\n- **Velocity** — how fast the key went down (1–127), which sets the loudness\n\nThis lesson is about accuracy. The secret is to **keep your eyes on the screen and feel the keys** — in a five-finger position your fingers already know where the notes are."),
            L.quiz("Follow the lights — right hand", "Eight random notes in C position. Play each lit key with the finger shown, without looking at your hand.", rounds: 5) { _ in
                var t = L.task("Right hand", "", randomRun(cR, hand: .right, count: 8))
                t.passAccuracy = 1
                return t
            },
            L.quiz("Follow the lights — left hand", "The same with the left hand.", rounds: 5) { _ in
                L.task("Left hand", "", randomRun(cL, hand: .left, count: 8))
            },
            L.quiz("Finger numbers only", "No lights now, only the notes and finger numbers on the staff. Right hand in C position: play the finger numbers shown.", rounds: 5) { _ in
                L.task("Read the fingering", "", randomRun(cR, hand: .right, count: 6), display: .staff, showTargets: false)
            },
            L.timed("Accuracy in time", "A longer pattern with the metronome. Aim for 100% with no wrong notes.",
                    fingered(L.line("C4 E4 D4 F4 E4 G4 F4 D4 E4 C4 D4 F4 E4 G4 E4 C4"), position: cR, hand: .right),
                    bpm: 72, display: .staffAndRhythm, pass: 0.95),
            L.timed("Both hands, taking turns", "Two bars right hand, two bars left hand.",
                    fingered(L.line("C4 E4 D4 F4 E4 G4 F4 D4"), position: cR, hand: .right)
                        + fingered(L.line("C3 E3 D3 F3 E3 G3 E3 C3", hand: .left, start: 8), position: cL, hand: .left),
                    bpm: 72, display: .staffAndRhythm, pass: 0.95),
        ])

        let evenness = lesson("foundations.midi.evenness", "Even velocity",
                              "Make every finger sound equally strong.", [
            L.info("Why notes come out uneven",
                   "Your fingers are not equally strong. The thumb is heavy, fingers 4 and 5 are weak, so a simple five-note pattern often comes out *LOUD-loud-loud-soft-soft*.\n\nThe app shows this as **velocity evenness**: how much your key speed varied from note to note (shown as ±). Beginners often vary by ±15 or more; a controlled, even touch is **±10 or less**, and very polished playing gets under ±6.\n\nTo even things out: play the thumb **lighter** than feels natural, and give fingers 4 and 5 a little more arm weight behind them. The Velocity meter above the on-screen keyboard shows each note's value as you play."),
            L.play("Baseline", "Play C position up and down at a comfortable medium loudness. This one is mostly a measurement (anything under ±18 passes): see what your evenness number is.",
                   rLine, rules: [.evenVelocity(maxStdDev: 18)]),
            L.play("Even touch, right hand", "Again, listening closely. Thumb lighter, little finger firmer. Target: ±12 or less.",
                   rLine + fingered(L.line(upDown(cR), start: 9), position: cR, hand: .right), rules: [.evenVelocity(maxStdDev: 12)]),
            L.play("Even touch, left hand", "The left hand usually needs more work. Target: ±12 or less.",
                   lLine + fingered(L.line(upDown(cL), hand: .left, start: 9), position: cL, hand: .left), rules: [.evenVelocity(maxStdDev: 12)]),
            L.play("Even and soft", "Soft playing is harder to keep even. Play **p** (velocity about 25–58) and keep every note the same.",
                   rLine, rules: [L.p, .evenVelocity(maxStdDev: 10)]),
            L.play("Even and strong", "Now **f** (velocity about 80–112) using arm weight, not finger force.",
                   rLine, rules: [L.f, .evenVelocity(maxStdDev: 12)]),
            L.timed("Even in time", "With the metronome: steady rhythm and steady tone together. Target: ±10 or less.",
                    rLine + fingered(L.line(upDown(cR), start: 9), position: cR, hand: .right) + fingered(L.line([60], start: 18), position: cR, hand: .right),
                    bpm: 80, display: .rhythm, rules: [.evenVelocity(maxStdDev: 10)]),
            L.timed("Even in time, left hand", "The same challenge for the left hand.",
                    lLine + fingered(L.line(upDown(cL), hand: .left, start: 9), position: cL, hand: .left) + fingered(L.line([48], hand: .left, start: 18), position: cL, hand: .left),
                    bpm: 80, display: .rhythm, rules: [.evenVelocity(maxStdDev: 10)]),
        ])

        return unit("foundations.midi", "MIDI skills: accuracy and evenness", [accuracy, evenness])
    }
}
