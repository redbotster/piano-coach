import Foundation

// Technique builders: public-domain exercises and teaching pieces that piano teachers use to develop
// particular skills. Hanon's figures are given in a one-octave form; the pieces are openings or excerpts.

extension Curriculum {
    static var sStudies: CurriculumUnit {
        let hanon: [Lesson] = [
            hanonLesson(number: 1, slug: "hanon-1",
                        summary: "The most-played finger exercise there is: both hands, up and back.",
                        figure: "skips a third, climbs by step to the sixth note, and walks back: **C–E–F–G–A–G–F–E**",
                        builds: "an even touch across all five fingers and a comfortable stretch between fingers 1 and 2 (right hand) and 5 and 4 (left hand)",
                        up: [0, 2, 3, 4, 5, 4, 3, 2], rhUp: [1, 2, 3, 4, 5, 4, 3, 2], lhUp: [5, 4, 3, 2, 1, 2, 3, 4],
                        down: [0, -2, -3, -4, -5, -4, -3, -2], rhDown: [5, 4, 3, 2, 1, 2, 3, 4], lhDown: [1, 2, 3, 4, 5, 4, 3, 2]),
            hanonLesson(number: 2, slug: "hanon-2",
                        summary: "A wider reach, then fingers 3 and 4 trade places.",
                        figure: "skips a third, reaches up to the sixth, and comes back with a turn: **C–E–A–G–F–G–F–E**",
                        builds: "independence of fingers **3 and 4**, the weakest pair in the hand",
                        up: [0, 2, 5, 4, 3, 4, 3, 2], rhUp: [1, 2, 5, 4, 3, 4, 3, 2], lhUp: [5, 3, 1, 2, 3, 2, 3, 4]),
            hanonLesson(number: 3, slug: "hanon-3",
                        summary: "The same reach, with the turn lower in the hand.",
                        figure: "skips a third, reaches up to the sixth, steps down three notes and turns back up: **C–E–A–G–F–E–F–G**",
                        builds: "independence of fingers **2, 3 and 4**, and evenness when the line changes direction",
                        up: [0, 2, 5, 4, 3, 2, 3, 4], rhUp: [1, 2, 5, 4, 3, 2, 3, 4], lhUp: [5, 3, 1, 2, 3, 4, 3, 2]),
            hanonLesson(number: 4, slug: "hanon-4",
                        summary: "A quick wiggle at the bottom of the hand before the reach.",
                        figure: "rocks between the first two notes, then skips up and walks back: **C–D–C–E–A–G–F–E**",
                        builds: "quick alternation of fingers **1 and 2** (right hand) and **5 and 4** (left hand)",
                        up: [0, 1, 0, 2, 5, 4, 3, 2], rhUp: [1, 2, 1, 2, 5, 4, 3, 2], lhUp: [5, 4, 5, 3, 1, 2, 3, 4]),
        ]

        let aChord = "A3+C4+E4:q':5-3-1"
        let dChord = "A3+D4+F4:q':5-2-1"
        let cChord = "G3+C4+E4:q':5-2-1"
        let gChord = "G3+B3+F4:q':5-3-1"
        let turcaA = "A3:e:5 C4+E4:e:2-1 C4+E4:e:2-1 C4+E4:e:2-1"
        let turcaE = "E3:e:5 B3+E4:e:2-1 B3+E4:e:2-1 B3+E4:e:2-1"

        let pieces: [Song] = [
            Song(id: "songs.studies.clementi-sonatina", title: "Sonatina in C, Op. 36 No. 1 (opening)",
                 summary: "Clementi: a broken chord, then a clean run of eighth notes.",
                 about: "The opening phrase of **Muzio Clementi's** Sonatina in C, Op. 36 No. 1 (1797), played twice. Generations of students have met their first sonata form here.\n\n**What it builds:** crisp, even eighth notes and smooth **thumb crossings** in a descending scale.\n\nKey of C, 4/4. Bars 1 and 2 outline the C chord. In bars 3 and 4 the line runs down by step: the thumb plays B, and finger 3 crosses over it to reach A. Keep the wrist level at the crossing. The right hand is Clementi's; the left hand is simplified to long notes for this lesson.\n\n**How to practise:** play bars 3 and 4 alone with **Loop**, slowly, listening for one unbroken line with no bump at the thumb.",
                 slow: 66, tempo: 112,
                 rh: rep("C5:q:2 E5:e:4 C5:e:2 G4:q:1 G4:q:1 | C5:q:2 E5:e:4 C5:e:2 G4:q:1 G5:q:5 | F5:e:5 E5:e:4 D5:e:3 C5:e:2 B4:e:1 C5:e:2 B4:e:1 C5:e:2 | D5:e:3 C5:e:2 B4:e:1 A4:e:3 G4:q:2 r:q |", 2),
                 lh: rep("C3:w:5 | C3:w:5 | F3:h:2 G3:h:1 | G2:h.:5 r:q |", 2)),
            Song(id: "songs.studies.burgmuller-arabesque", title: "Arabesque, Op. 100 No. 2 (opening)",
                 summary: "Burgmüller: quick five-note runs over short chords.",
                 about: "The first ten bars of **Friedrich Burgmüller's** *Arabesque*, No. 2 of his 25 Easy and Progressive Studies, Op. 100 (1851).\n\n**What it builds:** fast, even **five-finger runs** that land lightly, and a relaxed left hand playing **short (staccato) chords**.\n\nKey of A minor, 2/4. The left hand starts alone with two bars of chords. Each right-hand run is five neighbouring notes under fingers 1 to 5, and the last note is short. For each new run, move the whole hand so the thumb sits on the first note: A, A, D, then the A an octave higher.\n\n**How to practise:** first play each run as a block (all five notes at once) to learn the hand positions. Then play the runs slowly with the fingers close to the keys. The printed tempo is very fast (about 150); speed comes last.",
                 meter: (2, 4), slow: 54, tempo: 96,
                 rh: "r:h | r:h | A4:s:1 B4:s:2 C5:s:3 B4:s:2 A4:e':1 r:e | A4:s:1 B4:s:2 C5:s:3 D5:s:4 E5:e':5 r:e | D5:s:1 E5:s:2 F5:s:3 G5:s:4 A5:e':5 r:e | A5:s:1 B5:s:2 C6:s:3 D6:s:4 E6:e':5 r:e | r:e E5:e:3 E5:e:3 F5:e:4 | D5:e:2 r:e D5:q.:2 G5:e:5 D5:e:2 E5:e:3 | C5:q:1 r:q",
                 lh: "\(aChord) \(aChord) | \(aChord) \(aChord) | \(aChord) \(aChord) | \(aChord) \(aChord) | \(dChord) \(dChord) | \(aChord) \(aChord) | \(cChord) \(cChord) | \(gChord) \(gChord) | \(gChord) \(gChord) | C4+E4:q:3-1 r:q",
                 dynamic: "p"),
            Song(id: "songs.studies.rondo-alla-turca", title: "Rondo alla Turca (opening)",
                 summary: "Mozart: turning figures that train quick, clear fingers.",
                 about: "The first eight bars of the **Rondo alla Turca**, the finale of Mozart's Sonata in A, K. 331 (about 1783).\n\n**What it builds:** fast **turning figures** with fingers 4-3-2-1, a light bouncing left hand, and reading accidentals (G♯, D♯, F♯).\n\nKey of A minor, 2/4, starting with a pickup on beat 2. Each group of four sixteenth notes leads to a longer note; aim for that note. The left hand plays a bass note and then repeated two-note chords. From bar 5, Mozart writes the right hand in thirds; this lesson gives the **top line only**.\n\n**How to practise:** say \"four-three-two-one\" for each turn and keep the fingertips close to the keys. Practise the left hand until it runs by itself before adding the right.",
                 meter: (2, 4), slow: 50, tempo: 92,
                 rh: "r:q B4:s:4 A4:s:3 G#4:s:2 A4:s:1 | C5:e:3 r:e D5:s:4 C5:s:3 B4:s:2 C5:s:1 | E5:e:3 r:e F5:s:4 E5:s:3 D#5:s:2 E5:s:1 | B5:s:4 A5:s:3 G#5:s:2 A5:s:1 B5:s:4 A5:s:3 G#5:s:2 A5:s:1 | C6:q:5 A5:e:3 C6:e:5 | B5:e:4 A5:e:3 G5:e:2 A5:e:3 | B5:e:4 A5:e:3 G5:e:2 A5:e:3 | B5:e:4 A5:e:3 G5:e:2 F#5:e:1 | E5:q:2 r:q",
                 lh: "r:h | \(turcaA) | \(turcaA) | A3:e:5 C4+E4:e:2-1 A3:e:5 C4+E4:e:2-1 | \(turcaA) | \(turcaE) | \(turcaE) | E3:e:5 B3+E4:e:2-1 B2:e:5 B3:e:1 | E3:q:3 r:q",
                 dynamic: "p"),
            Song(id: "songs.studies.bach-invention-1", title: "Invention No. 1 in C (opening)",
                 summary: "Bach: the hands take turns with the same idea.",
                 about: "The first two bars of **J. S. Bach's** Two-Part Invention No. 1, BWV 772 (1723). Bach wrote the Inventions to teach his students to play two independent lines cleanly.\n\n**What it builds:** **hand independence**. The right hand states a short idea; the left hand answers with the same idea an octave lower while the right hand carries on with something else.\n\nKey of C, 4/4. Both hands begin their idea just after the beat, following a sixteenth rest. The excerpt ends on the first note of bar 3.\n\n**How to practise:** learn each hand until it is automatic, using the **hand selector**. Then put them together very slowly, and listen for the left-hand entry in the second half of bar 1 to be as clear as the right hand was.",
                 slow: 44, tempo: 66,
                 rh: "r:s C4:s:1 D4:s:2 E4:s:3 F4:s:4 D4:s:2 E4:s:3 C4:s:1 G4:e:1 C5:e:4 B4:e:3 C5:e:4 | D5:s:5 G4:s:1 A4:s:2 B4:s:3 C5:s:4 A4:s:2 B4:s:3 G4:s:1 D5:e:2 G5:e:5 F5:e:4 G5:e:5 | E5:q:3 r:h.",
                 lh: "r:h r:s C3:s:5 D3:s:4 E3:s:3 F3:s:2 D3:s:4 E3:s:3 C3:s:5 | G3:e:1 G2:e:5 r:q r:s G3:s:5 A3:s:4 B3:s:3 C4:s:2 A3:s:4 B3:s:3 G3:s:5 | C4:q:1 r:h."),
        ]

        return unit("songs.studies", "Technique builders", hanon + pieces.map { songLesson($0) })
    }

    /// White-key note `degree` steps above Middle C (negative for below).
    private static func whiteKey(_ degree: Int, octaveShift: Int = 0) -> Int {
        let scale = [0, 2, 4, 5, 7, 9, 11]
        let octave = Int((Double(degree) / 7).rounded(.down))
        return 60 + 12 * (octave + octaveShift) + scale[degree - octave * 7]
    }

    /// A Hanon exercise in a one-octave form: the figure rises one step per bar, both hands an octave apart.
    /// With `down`, it also comes back; otherwise it closes on a long C.
    private static func hanonLesson(number: Int, slug: String, summary: String, figure: String, builds: String,
                                    up: [Int], rhUp: [Int], lhUp: [Int],
                                    down: [Int]? = nil, rhDown: [Int] = [], lhDown: [Int] = []) -> Lesson {
        func build(bars: Int?) -> (rh: [ExpectedEvent], lh: [ExpectedEvent]) {
            var rh: [ExpectedEvent] = []
            var lh: [ExpectedEvent] = []
            var beat = 0.0
            func add(_ degree: Int, _ rf: Int?, _ lf: Int?, _ duration: Double) {
                rh.append(ExpectedEvent(notes: [NoteSpec(midi: whiteKey(degree), hand: .right, finger: rf)], beat: beat, duration: duration))
                lh.append(ExpectedEvent(notes: [NoteSpec(midi: whiteKey(degree, octaveShift: -1), hand: .left, finger: lf)], beat: beat, duration: duration))
                beat += duration
            }
            let rising = Array(0..<7).prefix(bars ?? 7)
            for root in rising {
                for (i, step) in up.enumerated() { add(root + step, rhUp[i], lhUp[i], 0.5) }
            }
            if bars == nil {
                if let down {
                    for root in stride(from: 11, through: 4, by: -1) {
                        for (i, step) in down.enumerated() { add(root + step, rhDown[i], lhDown[i], 0.5) }
                    }
                    add(0, 1, 5, 4)
                } else {
                    add(7, 1, 5, 4)
                }
            }
            return (rh, lh)
        }
        let full = build(bars: nil)
        let short = build(bars: 2)
        let both = L.together(full.rh, full.lh)
        let shape = down == nil ? "It rises one step each bar for seven bars and closes on a long C."
            : "It rises one step each bar for seven bars, then the figure turns upside down and comes back down to C."
        func timed(_ name: String, _ text: String, _ events: [ExpectedEvent], _ bpm: Double, rules: [Rule] = []) -> Step {
            L.timed(name, text, events, bpm: bpm, display: .staff, rules: rules, pass: 0.8, toleranceMs: 130)
        }
        let about = """
        Exercise No. \(number) from **Charles-Louis Hanon's** *The Virtuoso Pianist* (1873), here in a one-octave form. Hanon's original runs through two octaves.

        **What it builds:** \(builds).

        The figure \(figure). \(shape) Both hands play the same notes an octave apart, so the fingering is mirrored: follow the finger numbers.

        **How to practise:** lift each finger a little and let it drop; keep the wrist loose and the hand quiet. Play slowly and evenly before you play fast. If your forearm tires, stop and shake it out.
        """
        return lesson("songs.studies.\(slug)", "Hanon No. \(number)", summary, [
            L.info("About this exercise", about,
                   example: L.timedTask("Hanon No. \(number)", "", full.rh, bpm: 96, display: .staff)),
            L.play("Right hand: learn the figure", "The first two bars. The lesson waits for you; follow the finger numbers.", short.rh, display: .staff),
            L.play("Left hand: learn the figure", "The same two bars for the left hand. Finger 5 starts.", short.lh, display: .staff),
            timed("Right hand, slowly", "The whole exercise in time. Every note the same length and the same weight.", full.rh, 60),
            timed("Left hand, slowly", "The left hand alone. Listen for fingers 4 and 5 sounding as clearly as the others.", full.lh, 60),
            timed("Hands together, slowly", "Both hands exactly together. If one hand lags, go back to hands separately.", both, 56),
            timed("Hands together, at tempo", "Faster, but no louder and no tenser. Aim for every note at the same volume.", both, 88,
                  rules: [.evenVelocity(maxStdDev: 14)]),
        ])
    }
}
