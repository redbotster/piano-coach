import Foundation

// Songs: public-domain pieces only (traditional, or published in 1930 or earlier),
// in simple arrangements written for this app. No in-copyright material is included.

struct Song {
    var id: String
    var title: String
    var summary: String
    var about: String
    var key: Int = 0
    var meter: (Int, Int) = (4, 4)
    var unit: Int = 4
    var accent: [Int] = [0]
    var slow: Double
    var tempo: Double
    /// Melody tokens; tokens without ":" take the default duration (`rd` / `ld`).
    var rh: String
    var rd: String = "q"
    var lh: String? = nil
    var ld: String = "w"
    /// Five-finger position for the right hand: notes in it get finger numbers automatically.
    var pos: String? = nil
    var dynamic: String = "mf"
    var fermataLast: Bool = false
}

extension Curriculum {
    static var songs: CurriculumSection {
        CurriculumSection(id: "songs", title: "Songs", symbol: "music.quarternote.3",
                          units: [sFirst, sMoreFirst, sChristmas, sFolk, sClassics, sStudies, sStage, sModern])
    }

    // MARK: - Helpers

    fileprivate static func expand(_ text: String, _ d: String) -> String {
        text.split(separator: " ").map { token -> String in
            let t = String(token)
            if t == "|" || t.contains(":") { return t }
            return t + ":" + d
        }.joined(separator: " ")
    }

    fileprivate static func autoFinger(_ events: [ExpectedEvent], _ position: [Int]) -> [ExpectedEvent] {
        events.map { event in
            var e = event
            e.notes = e.notes.map { spec in
                var s = spec
                if s.finger == nil, let i = position.firstIndex(of: spec.midi) { s.finger = i + 1 }
                return s
            }
            return e
        }
    }

    static func songLesson(_ s: Song) -> Lesson {
        var rh = L.melody(expand(s.rh, s.rd), hand: .right, unit: s.unit)
        if let pos = s.pos { rh = autoFinger(rh, Music.notes(pos)) }
        if s.fermataLast, !rh.isEmpty { rh[rh.count - 1].fermata = true }
        let lh = s.lh.map { L.melody(expand($0, s.ld), hand: .left, unit: s.unit) }
        return songLesson(id: s.id, title: s.title, summary: s.summary, about: s.about, key: s.key, meter: s.meter,
                          accent: s.accent, slow: s.slow, tempo: s.tempo, rh: rh, lh: lh, dynamic: s.dynamic)
    }

    /// The standard shape of a song lesson: listen, right hand, left hand, together slowly, then up to tempo.
    fileprivate static func songLesson(id: String, title: String, summary: String, about: String, key: Int,
                                       meter: (Int, Int), accent: [Int], slow: Double, tempo: Double,
                                       rh: [ExpectedEvent], lh: [ExpectedEvent]?, dynamic: String) -> Lesson {
        func timed(_ name: String, _ text: String, _ events: [ExpectedEvent], _ bpm: Double) -> PlayTask {
            var t = L.timedTask(name, text, events, bpm: bpm, meter: meter, accentBeats: accent,
                                display: .staff, key: key, pass: 0.8, toleranceMs: 130)
            t.markers = [StaffMarker(beat: 0, text: dynamic)]
            return t
        }
        func untimed(_ name: String, _ text: String, _ events: [ExpectedEvent]) -> Step {
            L.play(name, text, events, display: .staff, key: key)
        }
        var steps: [Step] = [
            L.info("About this piece",
                   about + "\n\nPress **Listen** to hear the melody. Then learn it in stages: find the notes with no time pressure, play slowly with the metronome, and only then bring it up to tempo. Use the BPM − / + buttons whenever you need it slower.",
                   example: timed(title, "", rh, tempo)),
            untimed("Right hand: find the notes", "Follow the lit keys. The lesson waits for you, so aim for the right key first time.", rh),
            .play(timed("Right hand, slowly", "Now in time, at a slow tempo. Keep going if you slip.", rh, slow)),
        ]
        if let lh {
            let both = L.together(rh, lh)
            steps.append(untimed("Left hand: find the notes", "The left-hand part alone. Notice where it changes.", lh))
            steps.append(.play(timed("Hands together, slowly", "Both hands at the slow tempo. Look ahead to the next left-hand change.", both, slow)))
            steps.append(.play(timed("Hands together, at tempo", "The full piece at performance tempo. Let the melody sing a little louder than the left hand.", both, tempo)))
        } else {
            steps.append(.play(timed("Right hand, at tempo", "The melody at performance tempo.", rh, tempo)))
        }
        return lesson(id, title, summary, steps)
    }

    static func rep(_ text: String, _ times: Int) -> String {
        Array(repeating: text, count: times).joined(separator: " ")
    }

    // MARK: - Unit 1: First songs

    fileprivate static var sFirst: CurriculumUnit {
        let cPos = "C4 D4 E4 F4 G4"
        let list: [Song] = [
            Song(id: "songs.first.ode-to-joy", title: "Ode to Joy", summary: "Beethoven's theme, entirely in C position.",
                 about: "The theme from the finale of **Beethoven's Ninth Symphony** (1824). It moves almost entirely by step and fits under five fingers in **C position**, which is why it is nearly everyone's first real tune.\n\nKey of C, 4/4. The only tricky spot is the dotted rhythm at the end of each line: long–short–long.",
                 slow: 66, tempo: 96,
                 rh: "E4 E4 F4 G4 | G4 F4 E4 D4 | C4 C4 D4 E4 | E4:q. D4:e D4:h | E4 E4 F4 G4 | G4 F4 E4 D4 | C4 C4 D4 E4 | D4:q. C4:e C4:h",
                 lh: "C3 G2 C3 G2 C3 G2 C3 G2:h C3:h", pos: cPos),
            Song(id: "songs.first.twinkle", title: "Twinkle, Twinkle, Little Star", summary: "A French folk tune with one small hand shift.",
                 about: "An 18th-century French melody (*Ah! vous dirai-je, maman*) that Mozart wrote variations on.\n\nKey of C, 4/4. The tune reaches up to **A**, one note beyond C position, so finger 4 plays G and finger 5 stretches to A. Coming back down, finger 4 moves to F — follow the finger numbers.",
                 slow: 66, tempo: 100,
                 rh: "C4:q:1 C4:q:1 G4:q:4 G4:q:4 | A4:q:5 A4:q:5 G4:h:4 | F4:q:4 F4:q:4 E4:q:3 E4:q:3 | D4:q:2 D4:q:2 C4:h:1 | G4:q:5 G4:q:5 F4:q:4 F4:q:4 | E4:q:3 E4:q:3 D4:h:2 | G4:q:5 G4:q:5 F4:q:4 F4:q:4 | E4:q:3 E4:q:3 D4:h:2 | C4:q:1 C4:q:1 G4:q:4 G4:q:4 | A4:q:5 A4:q:5 G4:h:4 | F4:q:4 F4:q:4 E4:q:3 E4:q:3 | D4:q:2 D4:q:2 C4:h:1",
                 lh: "C3:w | F3 C3 | F3 C3 | G2 C3 | C3 F3 | C3 G2 | C3 F3 | C3 G2 | C3:w | F3 C3 | F3 C3 | G2 C3", ld: "h"),
            Song(id: "songs.first.frere-jacques", title: "Frère Jacques", summary: "A French round over a single left-hand note.",
                 about: "A traditional French round. Each two-bar idea is played twice, so there are only four things to learn.\n\nKey of C, 4/4. Bars 5–6 have quick eighth notes, and the last line dips below Middle C to **G** with the thumb.",
                 slow: 66, tempo: 104,
                 rh: "C4:q:1 D4:q:2 E4:q:3 C4:q:1 | C4 D4 E4 C4 | E4:q:3 F4:q:4 G4:h:5 | E4 F4 G4:h | G4:e:4 A4:e:5 G4:e:4 F4:e:3 E4:q:2 C4:q:1 | G4:e A4:e G4:e F4:e E4 C4 | C4:q:2 G3:q:1 C4:h:2 | C4 G3 C4:h",
                 lh: "C3 C3 C3 C3 C3 C3 C3 C3"),
            Song(id: "songs.first.london-bridge", title: "London Bridge", summary: "An English nursery tune with a dotted rhythm.",
                 about: "A traditional English singing game, first printed in the 1700s.\n\nKey of C, 4/4. It opens with a **dotted quarter and eighth** (long–short). The right hand needs A above its five-finger position, so start with finger 4 on G.",
                 slow: 66, tempo: 104,
                 rh: "G4:q.:4 A4:e:5 G4:q:4 F4:q:3 | E4:q:2 F4:q:3 G4:h:4 | D4:q:1 E4:q:2 F4:h:3 | E4:q:2 F4:q:3 G4:h:4 | G4:q. A4:e G4 F4 | E4 F4 G4:h | D4:h:1 G4:h:4 | E4:q:2 C4:h.:1",
                 lh: "C3 C3 G2 C3 C3 C3 G2 C3"),
            Song(id: "songs.first.yankee-doodle", title: "Yankee Doodle", summary: "A brisk march that dips below Middle C.",
                 about: "A marching song from the 1700s, known on both sides of the Atlantic.\n\nKey of C, 4/4. The melody drops below Middle C to **B, A and G**, so the hand opens out: the thumb takes the low notes.",
                 slow: 72, tempo: 112,
                 rh: "C4:q:2 C4:q:2 D4:q:3 E4:q:4 | C4:q:2 E4:q:4 D4:q:3 G3:q:1 | C4 C4 D4 E4 | C4:h:2 B3:h:1 | C4:q:1 C4:q:1 D4:q:2 E4:q:3 | F4:q:4 E4:q:3 D4:q:2 C4:q:1 | B3:q:3 G3:q:1 A3:q:2 B3:q:3 | C4:h:4 C4:h:4",
                 lh: "C3 | C3:h G2:h | C3 | C3:h G2:h | C3 | F3 | G2 | C3"),
            Song(id: "songs.first.jingle-bells", title: "Jingle Bells (chorus)", summary: "The famous chorus, all inside C position.",
                 about: "Written by **James Lord Pierpont** in 1857. The chorus never leaves C position.\n\nKey of C, 4/4. Lots of repeated notes: keep the wrist loose and let the finger bounce rather than pressing.",
                 slow: 76, tempo: 116,
                 rh: "E4 E4 E4:h | E4 E4 E4:h | E4 G4 C4:q. D4:e | E4:w | F4 F4 F4:q. F4:e | F4 E4 E4 E4:e E4:e | E4 D4 D4 E4 | D4:h G4:h | E4 E4 E4:h | E4 E4 E4:h | E4 G4 C4:q. D4:e | E4:w | F4 F4 F4:q. F4:e | F4 E4 E4 E4:e E4:e | G4 G4 F4 D4 | C4:w",
                 lh: "C3 C3 C3 C3 F3 C3 G2 G2 C3 C3 C3 C3 F3 C3 G2 C3", pos: cPos),
            Song(id: "songs.first.saints", title: "When the Saints Go Marching In", summary: "A New Orleans favourite that starts after a rest.",
                 about: "A traditional American gospel song that became a jazz-band standard.\n\nKey of C, 4/4. Every phrase **starts on beat 2**, after a quarter rest — count \"(one) two three four\". The left hand marks beat 1 for you.",
                 slow: 76, tempo: 120,
                 rh: "r C4 E4 F4 | G4:w | r C4 E4 F4 | G4:w | r C4 E4 F4 | G4:h E4:h | C4:h E4:h | D4:w | r E4 E4 D4 | C4:h. C4 | E4:h G4:h | G4 F4:h. | r:h E4 F4 | G4:h E4:h | C4:h D4:h | C4:w",
                 lh: "C3 C3 C3 C3 C3 C3 C3 G2 C3 C3 C3 F3 F3 C3 C3:h G2:h C3", pos: cPos),
            Song(id: "songs.first.going-home", title: "Largo (\"Goin' Home\")", summary: "Dvořák's slow theme: practise a singing legato.",
                 about: "The slow-movement theme of **Dvořák's Symphony No. 9 \"From the New World\"** (1893), later sung as *Goin' Home*.\n\nKey of C, 4/4, slow. It stays in C position, so put all your attention on **legato**: join every note to the next and shape each two-bar phrase like one breath.",
                 slow: 56, tempo: 72,
                 rh: "E4:q. G4:e G4:h | E4:q. D4:e C4:h | D4:q. E4:e G4:q. E4:e | D4:w | E4:q. G4:e G4:h | E4:q. D4:e C4:h | D4 E4 D4:q. C4:e | C4:w",
                 lh: "C3 C3 G2 G2 C3 C3 G2 C3", pos: cPos, dynamic: "p"),
        ]
        return unit("songs.first", "First songs", list.map { songLesson($0) })
    }

    // MARK: - Unit 2: Folk songs and carols

    fileprivate static var sFolk: CurriculumUnit {
        let list: [Song] = [
            Song(id: "songs.folk.aura-lee", title: "Aura Lee", summary: "An 1861 ballad with a gentle chromatic-free melody.",
                 about: "Composed by **George R. Poulton** in 1861 and sung on both sides of the American Civil War.\n\nKey of C, 4/4. The verse sits around Middle C (thumb on G below it); the chorus moves up to repeated Es. The left hand changes note once per bar.",
                 slow: 66, tempo: 92,
                 rh: "G3:q:1 C4:q:4 B3:q:3 C4:q:4 | D4:q:5 A3:q:2 D4:h:5 | C4:q:4 B3:q:3 A3:q:2 B3:q:3 | C4:w:4 | G3 C4 B3 C4 | D4 A3 D4:h | C4 B3 A3 B3 | C4:w | E4:q:3 E4:q:3 E4:h:3 | E4 E4 E4:h | E4:q:3 D4:q:2 C4:q:1 D4:q:2 | E4:w:3 | E4:q:3 E4:q:3 F4:q:4 E4:q:3 | D4:q:5 A3:q:2 D4:h:5 | C4 B3 A3 B3 | C4:w",
                 lh: "C3 D3 G2 C3 C3 D3 G2 C3 C3 C3 A2 C3 C3 D3 G2 C3"),
            Song(id: "songs.folk.camptown", title: "Camptown Races", summary: "Stephen Foster's lively tune, verse and chorus.",
                 about: "Written by **Stephen Foster** in 1850.\n\nKey of C, 4/4. The chorus leaps up to high C — open the hand and reach with finger 5. Keep it light and bouncy.",
                 slow: 76, tempo: 116,
                 rh: "G4 G4 E4 G4 | A4 G4 E4:h | E4 D4:h. | E4 D4:h. | G4 G4 E4 G4 | A4 G4 E4:h | D4:h E4 D4 | C4:w | C4:q.:1 C4:e:1 E4:q:2 G4:q:3 | C5:w:5 | A4:q.:3 A4:e:3 C5:q:5 A4:q:3 | G4:w:2 | G4 G4:e G4:e E4 G4 | A4 G4 E4:h | D4:h E4 D4 | C4:w",
                 lh: "C3 C3 G2 G2 C3 C3 G2 C3 C3 C3 F3 C3 C3 C3 G2 C3"),
            Song(id: "songs.folk.happy-birthday", title: "Happy Birthday to You", summary: "The song you will be asked to play most often.",
                 about: "The melody was published in 1893 by **Patty and Mildred Hill** as *Good Morning to All*.\n\nKey of C, **3/4**, starting with a pickup on beat 3. Each line begins with the same long–short pair of Gs. The third line jumps a whole octave, from low G to high G.",
                 meter: (3, 4), slow: 66, tempo: 96,
                 rh: "r:h G3:e.:1 G3:s:1 | A3:q:2 G3:q:1 C4:q:4 | B3:h:3 G3:e. G3:s | A3 G3 D4:q:5 | C4:h:4 G3:e.:1 G3:s:1 | G4:q:5 E4:q:3 C4:q:1 | B3:q:2 A3:q:1 F4:e.:5 F4:s:5 | E4:q:4 C4:q:2 D4:q:3 | C4:h:2",
                 lh: "r:h. C3 G2 G2 C3 C3 F3 C3:h G2:q C3:h", ld: "h.", fermataLast: true),
            Song(id: "songs.folk.amazing-grace", title: "Amazing Grace", summary: "A pentatonic hymn in 3/4 with a pickup.",
                 about: "The tune *New Britain* was first printed in 1829; John Newton's words are from 1779.\n\nKey of C, **3/4**, with a pickup. The melody uses only five different notes (a pentatonic scale). Feel one slow pulse per bar and let the long notes ring.",
                 meter: (3, 4), slow: 66, tempo: 88,
                 rh: "r:h G3:q:1 | C4:h:2 E4:e:4 C4:e:2 | E4:h:4 D4:q:3 | C4:h:2 A3:q:1 | G3:h:1 G3:q | C4:h E4:e C4:e | E4:h D4:q | G4:h.:5 | G4:h:5 E4:q:3 | G4:h:5 E4:e:3 C4:e:1 | E4:h:3 D4:q:2 | C4:h:1 A3:q:2 | G3:h:1 G3:q | C4:h E4:e C4:e | E4:h D4:q | C4:h. | C4:h",
                 lh: "r C3 C3 F3 C3 C3 C3 G2 G2 C3 C3 F3 C3 C3 G2 C3 C3", ld: "h.", dynamic: "mp", fermataLast: true),
            Song(id: "songs.folk.auld-lang-syne", title: "Auld Lang Syne", summary: "The Scottish New Year song in F.",
                 about: "A traditional Scottish melody set to words by **Robert Burns** (1788).\n\nKey of F (one flat in the key signature, although this pentatonic tune never uses B♭ in the melody), 4/4 with a pickup. The dotted quarter–eighth rhythm runs all the way through.",
                 key: -1, slow: 66, tempo: 92,
                 rh: "r:h. C4:q:1 | F4:q.:3 F4:e F4:q A4:q:5 | G4:q.:4 F4:e:3 G4:q:4 A4:q:5 | F4:q.:2 F4:e A4:q:3 C5:q:5 | D5:h.:5 D5:q | C5:q.:4 A4:e:2 A4:q F4:q:1 | G4:q.:2 F4:e:1 G4:q:2 A4:q:3 | F4:q.:3 D4:e:2 D4:q C4:q:1 | F4:h.:3",
                 lh: "r F3 C3 F3 Bb2 F3 C3 Bb2:h C3:h F3:h."),
            Song(id: "songs.folk.silent-night", title: "Silent Night", summary: "Franz Gruber's carol, a gentle lullaby in three.",
                 about: "Composed by **Franz Xaver Gruber** in 1818.\n\nKey of C, 3/4. The rocking figure G–A–G returns again and again. Near the end the melody climbs to high E and F — the emotional peak — then falls gently home.",
                 meter: (3, 4), slow: 66, tempo: 92,
                 rh: "G4:q.:2 A4:e:3 G4:q:2 | E4:h.:1 | G4:q. A4:e G4 | E4:h. | D5:h:5 D5:q | B4:h.:3 | C5:h:4 C5:q | G4:h.:1 | A4:h:2 A4:q | C5:q.:4 B4:e:3 A4:q:2 | G4:q.:2 A4:e:3 G4:q:2 | E4:h.:1 | A4:h A4:q | C5:q. B4:e A4 | G4:q. A4:e G4 | E4:h. | D5:h:2 D5:q | F5:q.:4 D5:e:2 B4:q:1 | C5:h.:2 | E5:h.:4 | C5:q:2 G4:q:1 E4:q:1 | G4:q.:3 F4:e:2 D4:q:1 | C4:h.:1 | C4:h.",
                 lh: "C3 C3 C3 C3 G2 G2 C3 C3 F3 F3 C3 C3 F3 F3 C3 C3 G2 G2 C3 C3 C3 G2 C3 C3", ld: "h.", dynamic: "p"),
        ]
        return unit("songs.folk", "Folk songs and carols", list.map { songLesson($0) })
    }

    // MARK: - Unit 3: Classical favourites

    fileprivate static var sClassics: CurriculumUnit {
        let turkishLeftA = "A3 C4+E4 C4+E4 C4+E4"
        let turkishLeftE = "E3 B3+E4 B3+E4 B3+E4"
        let elise = "A2 E3 A3 r:e."
        let eliseE = "E2 E3 G#3 r:e."
        var list: [Lesson] = []

        list.append(songLesson(Song(
            id: "songs.classics.morning-mood", title: "Morning Mood (excerpt)", summary: "Grieg's sunrise melody in a flowing 6/8.",
            about: "The opening of **Morning Mood** from Grieg's music for *Peer Gynt* (1875).\n\nKey of C, **6/8**: six eighth notes per bar, felt as two gentle swings. The tune uses only five notes and stays under the hand. The left hand holds a soft open fifth.",
            meter: (6, 8), unit: 8, accent: [0, 3], slow: 120, tempo: 168,
            rh: rep("G4:e:5 E4:e:3 D4:e:2 C4:e:1 D4:e:2 E4:e:3 | G4 E4 D4 C4 D4:s E4:s D4:s E4:s | G4:e:4 E4:e:2 G4:e:4 A4:e:5 E4:e:2 A4:e:5 | G4:e:5 E4:e:3 D4:e:2 C4:q.:1 |", 2),
            rd: "e", lh: rep("C3+G3", 8), ld: "h.", dynamic: "p")))

        list.append(songLesson(Song(
            id: "songs.classics.minuet-in-g", title: "Minuet in G", summary: "The famous minuet from the Anna Magdalena Notebook.",
            about: "From the *Notebook for Anna Magdalena Bach* (1725); long credited to J. S. Bach, it is now attributed to **Christian Petzold**.\n\nKey of G (F♯ in the key signature), 3/4. The right hand alternates a quarter note with running eighths. The left hand here is a simplified version of the original bass line.",
            key: 1, meter: (3, 4), slow: 72, tempo: 108,
            rh: "D5:q:5 G4:e:1 A4:e:2 B4:e:3 C5:e:4 | D5:q:5 G4:q:1 G4:q:1 | E5:q:3 C5:e:1 D5:e:2 E5:e:3 F#5:e:4 | G5:q:5 G4:q:1 G4:q:1 | C5:q:4 D5:e:5 C5:e:4 B4:e:3 A4:e:2 | B4:q:3 C5:e:4 B4:e:3 A4:e:2 G4:e:1 | F#4:q:1 G4:e:2 A4:e:3 B4:e:4 G4:e:2 | A4:h.:3 | D5:q G4 A4 B4 C5 | D5:q G4:q G4:q | E5:q C5 D5 E5 F#5 | G5:q G4:q G4:q | C5:q D5 C5 B4 A4 | B4:q C5 B4 A4 G4 | A4:q:3 B4:e:4 A4:e:3 G4:e:2 F#4:e:1 | G4:h.:2",
            rd: "e",
            lh: "G3:h A3:q | B3:h. | C4:h. | B3:h. | A3:h. | G3:h. | D4:q B3:q G3:q | D4:h. | G3:h A3:q | B3:h. | C4:h. | B3:h. | A3:h. | G3:h B3:q | C4:q D4:q D3:q | G3:h.")))

        list.append(songLesson(Song(
            id: "songs.classics.brahms-lullaby", title: "Brahms's Lullaby", summary: "Wiegenlied: a rocking melody over slow bass notes.",
            about: "**Johannes Brahms**, *Wiegenlied*, Op. 49 No. 4 (1868).\n\nKey of C, 3/4, starting with two pickup eighth notes. Play it softly and evenly, like rocking a cradle. This is a simplified arrangement of the vocal line.",
            meter: (3, 4), slow: 63, tempo: 84,
            rh: "r:h E4:e:3 E4:e:3 | G4:q.:5 E4:e:3 E4:q | G4:h E4:e G4:e | C5:q:5 B4:q.:4 A4:e:3 | A4:q:3 G4:q:2 D4:e:1 E4:e:2 | F4:q:3 D4:q:1 D4:e E4:e | F4:h:3 D4:e:1 F4:e:2 | B4:q:5 A4:q:4 G4:q:3 | B4:q:4 C5:q:5 C4:e:1 C4:e | C5:h:5 A4:e:3 F4:e:1 | G4:h:3 E4:e:2 C4:e:1 | F4:q:2 G4:q:3 A4:q:4 | G4:h:3 C4:e:1 C4:e | C5:h A4:e F4:e | G4:h E4:e C4:e | F4:q:4 E4:q:3 D4:q:2 | C4:h.:1",
            lh: "r C3 C3 C3 C3 G2 G2 G2 C3 F3 C3 G2 C3 F3 C3 G2 C3", ld: "h.", dynamic: "p")))

        list.append(songLesson(Song(
            id: "songs.classics.greensleeves", title: "Greensleeves", summary: "The Elizabethan tune in A minor, verse and refrain.",
            about: "An English tune from the late 1500s.\n\nA minor, 3/4, with a pickup. This version uses the old **melodic-minor colouring**: F♯ and G♯ appear as accidentals on the way up. The refrain starts on high G. One left-hand note per bar outlines the harmony.",
            meter: (3, 4), slow: 72, tempo: 108,
            rh: "r:h A4:q:1 | C5:h:3 D5:q:4 | E5:q.:5 F#5:e E5:q | D5:h:4 B4:q:2 | G4:q.:1 A4:e:2 B4:q:3 | C5:h:4 A4:q:2 | A4:q.:3 G#4:e:2 A4:q:3 | B4:h:4 G#4:q:2 | E4:h:1 A4:q:1 | C5:h D5 | E5:q. F#5:e E5 | D5:h B4 | G4:q. A4:e B4 | C5:q.:4 B4:e:3 A4:q:2 | G#4:q.:2 F#4:e:1 G#4:q:2 | A4:h.:3 | A4:h. | G5:h.:5 | G5:q.:5 F#5:e:4 E5:q:3 | D5:h:2 B4:q:1 | G4:q.:1 A4:e:2 B4:q:3 | C5:h:4 A4:q:2 | A4:q. G#4:e A4 | B4:h G#4 | E4:h. | G5:h.:5 | G5:q. F#5:e E5 | D5:h B4 | G4:q. A4:e B4 | C5:q. B4:e A4 | G#4:q. F#4:e G#4 | A4:h. | A4:h.",
            lh: "r | A2 C3 G2 E3 A2 A2 E3 E3 | A2 C3 G2 E3 A2 E3 A2 A2 | C3 C3 G2 E3 A2 A2 E3 E3 | C3 C3 G2 E3 A2 E3 A2 A2", ld: "h.")))

        list.append(songLesson(Song(
            id: "songs.classics.canon-in-d", title: "Canon in D (theme)", summary: "Pachelbel's eight-note bass with two melodies above it.",
            about: "**Johann Pachelbel**, Canon in D (c. 1680). The whole piece is built on eight bass notes — D A B F♯ G D G A — repeated again and again.\n\nKey of D (F♯ and C♯), 4/4. First the right hand plays a slow descending line in half notes, then a quarter-note melody over the same bass.",
            key: 2, slow: 60, tempo: 80,
            rh: "F#5:h:4 E5:h:3 | D5:h:2 C#5:h:1 | B4:h:3 A4:h:2 | B4:h:3 C#5:h:4 | D5:q:1 F#5:q:3 A5:q:5 G5:q:4 | F#5:q:3 D5:q:1 F#5:q:3 E5:q:2 | D5:q:4 B4:q:2 D5:q:4 A4:q:1 | G4:q:1 B4:q:3 A4:q:2 G4:q:1 | F#4:w:2",
            lh: "D3 A2 | B2 F#2 | G2 D3 | G2 A2 | D3 A2 | B2 F#2 | G2 D3 | G2 A2 | D3:w", ld: "h")))

        list.append(songLesson(Song(
            id: "songs.classics.eine-kleine", title: "Eine kleine Nachtmusik (opening)", summary: "Mozart's fanfare with both hands in octaves.",
            about: "The opening of **Mozart's** serenade K. 525 (1787).\n\nKey of G, 4/4. Both hands play the same notes an octave apart, as the orchestra does. Observe the rests exactly — the silences give the theme its punch.",
            key: 1, slow: 76, tempo: 120,
            rh: "G4:q:3 r:e D4:e:1 G4:q:3 r:e D4:e:1 | G4:e:2 D4:e:1 G4:e:2 B4:e:3 D5:q:5 r:q | C5:q:4 r:e A4:e:2 C5:q:4 r:e A4:e:2 | C5:e:4 A4:e:2 F#4:e:1 A4:e:2 D4:q:1 r:q",
            lh: "G3:q r:e D3:e G3:q r:e D3:e | G3:e D3:e G3:e B3:e D4:q r:q | C4:q r:e A3:e C4:q r:e A3:e | C4:e A3:e F#3:e A3:e D3:q r:q", dynamic: "f")))

        list.append(songLesson(Song(
            id: "songs.classics.mountain-king", title: "In the Hall of the Mountain King", summary: "Grieg's creeping theme: quiet, even and staccato.",
            about: "From **Grieg's** *Peer Gynt* (1875). Written here in A minor.\n\n4/4. The theme is all eighth notes with a quarter at the end of each half bar; D♯ and B♭ add the sinister colour (the staff shows B♭ as A♯). Play it quietly and detached, then try raising the tempo a notch each time, as the orchestra does.",
            slow: 76, tempo: 116,
            rh: rep("A3:e:1 B3:e:2 C4:e:3 D4:e:1 E4:e:2 C4:e:1 E4:q:3 | D#4:e:3 B3:e:1 D#4:q:3 D4:e:3 Bb3:e:1 D4:q:3 | A3:e:1 B3:e:2 C4:e:3 D4:e:1 E4:e:2 C4:e:1 E4:e:2 A4:e:5 | G4:e:4 E4:e:2 C4:e:1 E4:e:2 G4:h:4 |", 2),
            lh: rep("A2 E3 A2 E3", 8), ld: "q", dynamic: "p")))

        list.append(songLesson(Song(
            id: "songs.classics.blue-danube", title: "The Blue Danube (opening)", summary: "Strauss's waltz with a real oom-pah-pah left hand.",
            about: "**Johann Strauss II**, *An der schönen blauen Donau* (1866).\n\nKey of C, 3/4, with a pickup. The melody climbs a chord and is answered an octave higher, so the right hand must **leap** — look at the target key before you jump. The left hand plays a waltz pattern: bass note, then two light chords.",
            meter: (3, 4), slow: 84, tempo: 132,
            rh: "r:h C4:q:1 | C4:q:1 E4:q:2 G4:q:3 | G4:h:3 G5:q:5 | G5:h:5 E5:q:3 | E5:h:3 C4:q:1 | C4 E4 G4 | G4:h G5:q | G5:h:5 F5:q:4 | F5:h:4 B3:q:1 | B3:q:1 D4:q:2 A4:q:5 | A4:h:3 A5:q:5 | A5:h:5 F5:q:3 | F5:h:3 B3:q:1 | B3 D4 A4 | A4:h A5:q | A5:h:5 E5:q:2 | E5:h.:2",
            lh: "r:h. | " + rep("C3 E3+G3 E3+G3 |", 6) + " " + rep("G2 D3+F3 D3+F3 |", 8) + " " + rep("C3 E3+G3 E3+G3 |", 2), ld: "q")))

        list.append(songLesson(Song(
            id: "songs.classics.fur-elise", title: "Für Elise (main theme)", summary: "Beethoven's theme, with the hands passing broken chords.",
            about: "**Beethoven**, Bagatelle in A minor, WoO 59 (1810).\n\nA minor, **3/8**: three eighth notes per bar, mostly filled with sixteenths. The famous E–D♯ wobble uses fingers 5 and 4. In the answering bars the **left hand starts a broken chord and the right hand finishes it** — aim for one unbroken line.",
            meter: (3, 8), unit: 8, slow: 76, tempo: 126,
            rh: "r:q E5:s:5 D#5:s:4 | E5:s:5 D#5:s:4 E5:s:5 B4:s:2 D5:s:4 C5:s:3 | A4:e:1 r C4:s:1 E4:s:2 A4:s:5 | B4:e:5 r E4:s:1 G#4:s:2 B4:s:5 | C5:e:5 r E4:s:1 E5 D#5 | E5 D#5 E5 B4 D5 C5 | A4:e r C4 E4 A4 | B4:e r E4:s:1 C5:s:4 B4:s:3 | A4:q.:2",
            rd: "s",
            lh: "r:q. | r:q. | \(elise) | \(eliseE) | \(elise) | r:q. | \(elise) | \(eliseE) | \(elise)", ld: "s", dynamic: "pp")))

        list.append(bachPrelude)
        list.append(gymnopedie)
        list.append(moonlight)

        list.append(songLesson(Song(
            id: "songs.classics.mozart-k545", title: "Sonata in C, K. 545 (opening)", summary: "Mozart's \"easy\" sonata: melody over an Alberti bass.",
            about: "The first four bars of **Mozart's** Sonata in C, K. 545 (1788).\n\nKey of C, 4/4. The left hand plays an **Alberti bass** — bottom, top, middle, top — which must stay soft and even under the singing right hand. The trill in bar 4 is written out here in a simplified form.",
            slow: 63, tempo: 100,
            rh: "C5:h:1 E5:q:3 G5:q:5 | B4:q.:1 C5:s:2 D5:s:3 C5:q:2 r:q | A5:h:5 G5:q:4 C6:q:5 | G5:q:4 F5:e:3 E5:s:2 F5:s:3 E5:q:2 r:q",
            lh: "C4 G4 E4 G4 C4 G4 E4 G4 | D4 G4 F4 G4 C4 G4 E4 G4 | C4 A4 F4 A4 C4 G4 E4 G4 | B3 G4 D4 G4 C4 G4 E4 G4", ld: "e")))

        list.append(songLesson(Song(
            id: "songs.classics.turkish-march", title: "Rondo alla Turca (opening)", summary: "Mozart's Turkish March: quick turns over a marching left hand.",
            about: "The opening of the finale of **Mozart's** Sonata in A, K. 331 (1783).\n\nA minor, 2/4. The right hand plays four-note turns in sixteenths that climb an octave each time; the left hand marches in eighths, bass note then chords. Learn it slowly — clarity matters far more than speed.",
            meter: (2, 4), slow: 56, tempo: 96,
            rh: "r:q B4:s:4 A4:s:3 G#4:s:2 A4:s:3 | C5:e:5 r:e D5:s:4 C5:s:3 B4:s:2 C5:s:3 | E5:e:5 r:e F5:s:4 E5:s:3 D#5:s:2 E5:s:3 | B5:s:4 A5:s:3 G#5:s:2 A5:s:3 B5 A5 G#5 A5 | C6:q:5 A5:e:3 C6:e:5 | B5:e:4 A5:e:3 G5:e:2 A5:e:3 | B5:e A5:e G5:e A5:e | B5:e:4 A5:e:3 G5:e:2 F#5:e:1 | E5:q:2 r:q",
            rd: "s",
            lh: "r:h | \(rep(turkishLeftA + " |", 4)) \(rep(turkishLeftE + " |", 3)) E3:q r:q", ld: "e")))

        return unit("songs.classics", "Classical favourites", list)
    }

    fileprivate static var bachPrelude: Lesson {
        // Each bar: two left-hand notes, then three right-hand notes played twice; the whole figure repeats.
        let bars: [[String]] = [
            ["C4", "E4", "G4", "C5", "E5"], ["C4", "D4", "A4", "D5", "F5"], ["B3", "D4", "G4", "D5", "F5"],
            ["C4", "E4", "G4", "C5", "E5"], ["C4", "E4", "A4", "E5", "A5"], ["C4", "D4", "F#4", "A4", "D5"],
            ["B3", "D4", "G4", "D5", "G5"], ["B3", "C4", "E4", "G4", "C5"],
        ]
        var rh: [ExpectedEvent] = []
        var lh: [ExpectedEvent] = []
        for (b, names) in bars.enumerated() {
            let n = names.map { Music.midi($0) }
            for half in 0..<2 {
                let base = Double(b) * 4 + Double(half) * 2
                lh.append(ExpectedEvent(notes: [NoteSpec(midi: n[0], hand: .left, finger: 5)], beat: base, duration: 0.25))
                lh.append(ExpectedEvent(notes: [NoteSpec(midi: n[1], hand: .left, finger: n[1] - n[0] <= 2 ? 4 : 3)], beat: base + 0.25, duration: 0.25))
                let order = [2, 3, 4, 2, 3, 4]
                let fingers = [1, 2, 4, 1, 2, 4]
                for (i, k) in order.enumerated() {
                    rh.append(ExpectedEvent(notes: [NoteSpec(midi: n[k], hand: .right, finger: fingers[i])],
                                            beat: base + 0.5 + Double(i) * 0.25, duration: 0.25))
                }
            }
        }
        lh.append(ExpectedEvent(notes: [NoteSpec(midi: 60, hand: .left), NoteSpec(midi: 64, hand: .left)], beat: 32, duration: 4))
        rh.append(ExpectedEvent(notes: [NoteSpec(midi: 67), NoteSpec(midi: 72), NoteSpec(midi: 76)], beat: 32, duration: 4))
        return songLesson(
            id: "songs.classics.bach-prelude-c", title: "Prelude in C (opening)", summary: "Bach's rippling broken chords, shared between the hands.",
            about: "The first eight bars of the **Prelude in C** from J. S. Bach's *Well-Tempered Clavier*, Book 1 (1722), closed here with a C chord.\n\nKey of C, 4/4, all sixteenth notes. Every bar is one chord, broken the same way: the **left hand plays two notes, the right hand plays three notes twice**, and the whole figure repeats. Learn each bar as a hand shape, and listen to how the harmony shifts.",
            key: 0, meter: (4, 4), accent: [0], slow: 44, tempo: 66, rh: rh, lh: lh, dynamic: "p")
    }

    fileprivate static var gymnopedie: Lesson {
        var rh = L.melody("r:h. r:h. r:h. r:h. | r:q F#5:q:3 A5:q:5 | G5:q:4 F#5:q:3 C#5:q:1 | B4:q:2 C#5:q:3 D5:q:4 | A4:h.:1 | F#4:h.:2")
        rh[rh.count - 1].fermata = true
        var lh: [ExpectedEvent] = []
        for bar in 0..<10 {
            let start = Double(bar) * 3
            let onG = bar % 2 == 0
            lh.append(ExpectedEvent(notes: [NoteSpec(midi: Music.midi(onG ? "G2" : "D2"), hand: .left, finger: 5)], beat: start, duration: 1))
            var chord = onG ? ["B3", "D4", "F#4"] : ["A3", "C#4", "F#4"]
            if bar == 8 { chord = ["B3", "D4"] }       // the right hand is holding F♯ here
            let fingers = [5, 3, 1]
            lh.append(ExpectedEvent(notes: chord.enumerated().map { NoteSpec(midi: Music.midi($1), hand: .left, finger: fingers[$0]) },
                                    beat: start + 1, duration: 2))
        }
        return songLesson(
            id: "songs.classics.gymnopedie", title: "Gymnopédie No. 1 (opening)", summary: "Satie's floating melody over a swaying left hand.",
            about: "**Erik Satie**, *Gymnopédie No. 1* (1888).\n\nKey of D (F♯ and C♯), 3/4, very slow. The left hand does all the travelling: a **low bass note on beat 1**, then a **chord on beat 2** higher up. Practise that jump alone until it is relaxed. The melody enters in bar 5 and should float above, soft and unhurried.",
            key: 2, meter: (3, 4), accent: [0], slow: 56, tempo: 72, rh: rh, lh: lh, dynamic: "pp")
    }

    fileprivate static var moonlight: Lesson {
        let groups: [[String]] = [
            ["G#3", "C#4", "E4"], ["G#3", "C#4", "E4"], ["G#3", "C#4", "E4"], ["G#3", "C#4", "E4"],
            ["G#3", "C#4", "E4"], ["G#3", "C#4", "E4"], ["G#3", "C#4", "E4"], ["G#3", "C#4", "E4"],
            ["A3", "C#4", "E4"], ["A3", "C#4", "E4"], ["A3", "D4", "F#4"], ["A3", "D4", "F#4"],
            ["G#3", "C4", "F#4"], ["G#3", "C#4", "E4"], ["G#3", "C#4", "D#4"], ["F#3", "C4", "D#4"],
            ["G#3", "C#4", "E4"], ["G#3", "C#4", "E4"], ["G#3", "C#4", "E4"], ["G#3", "C#4", "E4"],
        ]
        var rh: [ExpectedEvent] = []
        for (g, names) in groups.enumerated() {
            let fingers = [1, 2, names[2] == "F#4" && names[1] != "D4" ? 5 : 3]
            for (i, name) in names.enumerated() {
                rh.append(ExpectedEvent(notes: [NoteSpec(midi: Music.midi(name), hand: .right, finger: fingers[i])],
                                        beat: Double(g) + Double(i) / 3, duration: 1.0 / 3))
            }
        }
        let lh = L.melody("C#3:w | B2:w | A2:h F#2:h | G#2:h G#2:h | C#3:w", hand: .left)
        return songLesson(
            id: "songs.classics.moonlight", title: "Moonlight Sonata (opening)", summary: "Beethoven's slow triplets over a sinking bass.",
            about: "The first bars of **Beethoven's** Sonata Op. 27 No. 2 (1801), closing here on the home chord.\n\nC♯ minor (four sharps), 4/4, with the right hand in **triplets**: three even notes to every beat, twelve per bar. The left hand sinks slowly in long notes (single notes here; the original doubles them in octaves). One note in bar 4 is written B♯ in the score — it is the key C, and the staff here shows it as C natural.\n\nKeep the triplets very soft and perfectly even, and hold the sustain pedal through each harmony if you have one.",
            key: 4, meter: (4, 4), accent: [0], slow: 44, tempo: 56, rh: rh, lh: lh, dynamic: "pp")
    }

    // MARK: - Unit 4: Stage and show tunes (public domain)

    fileprivate static var sStage: CurriculumUnit {
        let list: [Song] = [
            Song(id: "songs.stage.can-can", title: "Can-Can", summary: "Offenbach's galop from the operetta Orpheus in the Underworld (1858).",
                 about: "The *Galop infernal* from **Jacques Offenbach's** operetta *Orpheus in the Underworld* (1858) — the tune the world knows as the Can-Can.\n\nKey of C, 4/4, written here in quarter notes so it is easy to read; it sounds right once you push the tempo. One bar swoops up an octave to high C and tumbles back down.",
                 slow: 92, tempo: 160,
                 rh: "r:h C4:h:1 | D4:q:2 F4:q:4 E4:q:3 D4:q:2 | G4:h:5 G4:h | G4:q:4 A4:q:5 E4:q:2 F4:q:3 | D4:h:1 D4:h | D4:q:2 F4:q:4 E4:q:3 D4:q:2 | C4:q:1 C5:q:5 B4:q:4 A4:q:3 | G4:q:5 F4:q:4 E4:q:3 D4:q:2 | C4:h:1 r:h",
                 lh: "r C3 | G2 G2 | C3 C3 | D3 D3 | G2 G2 | G2 G2 | C3 C3 | G2 G2 | C3 r", ld: "h", dynamic: "f"),
            Song(id: "songs.stage.toreador", title: "Toreador Song (refrain, excerpt)", summary: "The swaggering refrain from Bizet's opera Carmen (1875).",
                 about: "The refrain of Escamillo's song from **Georges Bizet's** opera *Carmen* (1875).\n\nKey of F (B♭), 4/4, a proud march. The **dotted eighth–sixteenth** rhythm gives it its strut: hold the long note, then flick the short one. The left hand marches in steady quarter notes.",
                 key: -1, slow: 72, tempo: 108,
                 rh: "C5:q:4 D5:e.:5 C5:s:4 A4:q:2 A4:q | A4:e.:3 G4:s:2 A4:e.:3 Bb4:s:4 A4:h:3 | Bb4:q:4 G4:e.:2 C5:s:5 A4:h:3 | F4:q:3 D4:e.:1 G4:s:4 C4:h:1",
                 lh: "F3 C3 F3 C3 | F3 C3 F3 C3 | C3 C3 F3 C3 | D3 G2 C3:h", ld: "q", dynamic: "f"),
            Song(id: "songs.stage.swan-lake", title: "Swan Lake: Swan Theme (excerpt)", summary: "The haunting oboe theme from Tchaikovsky's ballet (1877).",
                 about: "The Swan Theme from **Tchaikovsky's** ballet *Swan Lake* (1877), written here in A minor.\n\n4/4. A long opening note, a rising run, then a falling sigh repeated. Play the phrase twice. The left hand rolls gently through each chord — keep it well under the melody.",
                 slow: 66, tempo: 92,
                 rh: rep("E5:h:5 A4:e:1 B4:e:2 C5:e:3 D5:e:4 | E5:q.:5 C5:e:3 E5:q.:5 C5:e:3 | E5:q.:5 A4:e:1 C5:e:3 A4:e:2 F4:e:1 C5:e:4 | A4:w:2 |", 2),
                 lh: rep("A2 E3 A3 E3 | A2 E3 A3 E3 | F2 C3 F3 C3 | A2 E3 A3 E3 |", 2), ld: "q", dynamic: "mp"),
            Song(id: "songs.stage.daisy-bell", title: "Daisy Bell (chorus, excerpt)", summary: "\"A Bicycle Built for Two\", a music-hall waltz from 1892.",
                 about: "Written by **Harry Dacre** in 1892 and made famous on the London and New York music-hall stage. This is the first half of the chorus.\n\nKey of F, 3/4. The tune opens by falling through an F chord in long notes — one per bar — then picks up into quarters. Feel one swing per bar, like a waltz.",
                 key: -1, meter: (3, 4), slow: 96, tempo: 144,
                 rh: "C5:h.:5 | A4:h.:3 | F4:h.:2 | C4:h.:1 | D4:q:1 E4:q:2 F4:q:3 | D4:h:1 F4:q:3 | C4:h.:1 | C4:h. | G4:h.:2 | C5:h.:5 | A4:h.:3 | F4:h.:1 | D4:q:1 E4:q:2 F4:q:3 | G4:h:4 A4:q:5 | G4:h.:4 | G4:h r:q",
                 rd: "h.",
                 lh: "F3 F3 F3 F3 Bb2 Bb2 F3 F3 C3 C3 F3 F3 Bb2 C3 C3 C3", ld: "h."),
            Song(id: "songs.stage.ball-game", title: "Take Me Out to the Ball Game (excerpt)", summary: "The 1908 vaudeville waltz, first twelve bars of the chorus.",
                 about: "Written in 1908 by **Jack Norworth and Albert Von Tilzer** and introduced on the vaudeville stage. This is the first twelve bars of the chorus.\n\nKey of C, 3/4. The tune begins with an **octave leap** from Middle C to the C above. Watch for the G♯ in bar 9.",
                 meter: (3, 4), slow: 96, tempo: 152,
                 rh: "C4:h:1 C5:q:5 | A4:q:3 G4:q:2 E4:q:1 | G4:h.:3 | D4:h.:1 | C4:h:1 C5:q:5 | A4:q:3 G4:q:2 E4:q:1 | G4:h.:3 | G4:h. | A4:q:4 G#4:q:3 A4:q:4 | E4:q:1 F4:q:2 G4:q:3 | A4:h:5 F4:q:3 | D4:h.:1",
                 lh: "C3 C3 C3 G2 C3 C3 C3 C3 A2 A2 D3 D3", ld: "h."),
        ]
        return unit("songs.stage", "Stage and show tunes (public domain)", list.map { songLesson($0) })
    }

    // MARK: - Unit 5: Getting ready for modern musicals (original exercises)

    fileprivate static func n(_ names: String) -> [Int] { Music.notes(names) }

    /// Right-hand chords over a left-hand part, one chord per `dur` beats.
    fileprivate static func comp(_ right: [[Int]], _ left: [[Int]], dur: Double, labels: [String]? = nil) -> [ExpectedEvent] {
        L.together(L.chords(right, hand: .right, duration: dur, labels: labels), L.chords(left, hand: .left, duration: dur))
    }

    /// One bar per chord: the right hand plays `hits` (beat, length) and the left hand plays `bass` (beat, length).
    fileprivate static func groove(_ right: [[Int]], _ left: [[Int]], hits: [(Double, Double)], bass: [(Double, Double)]) -> [ExpectedEvent] {
        var r: [ExpectedEvent] = []
        var l: [ExpectedEvent] = []
        for bar in right.indices {
            let start = Double(bar) * 4
            for hit in hits {
                r.append(ExpectedEvent(notes: right[bar].map { NoteSpec(midi: $0, hand: .right) }, beat: start + hit.0, duration: hit.1))
            }
            for b in bass {
                l.append(ExpectedEvent(notes: left[bar].map { NoteSpec(midi: $0, hand: .left) }, beat: start + b.0, duration: b.1))
            }
        }
        return L.together(r, l)
    }

    fileprivate static var sModern: CurriculumUnit {
        // Close right-hand voicings that move as little as possible.
        let cC = n("E4 G4 C5"), cG = n("D4 G4 B4"), cAm = n("E4 A4 C5"), cF = n("F4 A4 C5")
        let gG = n("G4 B4 D5"), gD = n("F#4 A4 D5"), gEm = n("G4 B4 E5"), gC = n("G4 C5 E5")
        let bC = n("C3"), bG = n("G2"), bAm = n("A2"), bF = n("F2")

        // 1. Four-chord vamps
        let vampRight = [cC, cG, cAm, cF]
        let vampLeft = [bC, bG, bAm, bF]
        let vampLabels = ["C", "G", "Am", "F"]
        let vamps = lesson("songs.modern.four-chords", "Four-chord vamps", "The I–V–vi–IV loop behind countless pop and musical-theatre songs.", [
            L.info("Where are the modern shows?",
                   "Songs from modern musicals such as **The Phantom of the Opera** and **Rent** are still under copyright, so their melodies are not built into this app.\n\nYou can still learn them here. Get a MIDI or MusicXML arrangement you are entitled to use (many publishers sell them), then choose **Import a song…** in the sidebar (⌘I). It appears under **My Songs** with the same lit keys, hands-separate practice and scoring as everything else.\n\nThis unit prepares you for that music with **original exercises**: the chord loops, rhythms and accompaniment patterns that modern show tunes are built from."),
            L.info("One loop, a thousand songs",
                   "A huge number of pop, rock and stage ballads run on the same four chords: **I – V – vi – IV**. In the key of C that is **C – G – Am – F**.\n\nThe trick to playing them smoothly is **voice leading**: choose shapes that share notes so the hand barely moves. Here the right hand plays C as E–G–C, G as D–G–B, Am as E–A–C and F as F–A–C. The left hand plays the **root** of each chord.",
                   keys: L.keys(cC, labels: ["E", "G", "C"], hand: .right) + L.keys(bC, labels: ["C"], hand: .left)),
            L.play("Right-hand shapes", "Play the four chords. Notice which fingers stay put between shapes.",
                   L.chords(vampRight, labels: vampLabels), display: .staff),
            L.play("Left-hand roots", "The roots: C, G, A, F.", L.chords(vampLeft, hand: .left), display: .staff),
            L.timed("The loop, one chord per bar", "Both hands together, whole notes, twice round the loop.",
                    L.loop(comp(vampRight, vampLeft, dur: 4, labels: vampLabels), times: 2, length: 16), bpm: 76, display: .staffAndRhythm),
            L.timed("Add a pulse", "Left hand holds the root; right hand repeats the chord on every beat. Keep the wrist loose so the repeats stay light.",
                    groove(vampRight, vampLeft, hits: [(0, 1), (1, 1), (2, 1), (3, 1)], bass: [(0, 4)]), bpm: 76, display: .staffAndRhythm),
            L.timed("The same loop in G", "I – V – vi – IV in G is **G – D – Em – C**. One sharp: F♯.",
                    L.loop(comp([gG, gD, gEm, gC], [n("G2"), n("D3"), n("E3"), n("C3")], dur: 4, labels: ["G", "D", "Em", "C"]), times: 2, length: 16),
                    bpm: 76, display: .staffAndRhythm, key: 1),
            L.timed("Start on the minor chord", "Rotate the loop to **vi – IV – I – V** (Am – F – C – G) and it turns darker and more dramatic.",
                    L.loop(comp([cAm, cF, cC, cG], [bAm, bF, bC, bG], dur: 4, labels: ["Am", "F", "C", "G"]), times: 2, length: 16),
                    bpm: 76, display: .staffAndRhythm),
        ])

        // 2. Syncopated comping
        let comping = lesson("songs.modern.comping", "Syncopated comping", "Pop and rock rhythms for the chord hand.", [
            L.info("Comping",
                   "\"Comping\" means accompanying with chords in rhythm. Modern show scores rarely put chords squarely on every beat; they push and pull against the pulse.\n\nThe most useful pattern of all groups the eight eighth notes of a bar as **3 + 3 + 2**: chords land on beat 1, on the \"and\" of 2, and on beat 4.",
                   example: L.timedTask("3 + 3 + 2", "", L.rhythm("q. q. q q. q. q"), bpm: 96, display: .rhythm)),
            L.timed("Tap 3 + 3 + 2", "Tap the rhythm on any key, counting \"**1** 2 3 **1** 2 3 **1** 2\" in eighths.",
                    L.rhythm("q. q. q q. q. q q. q. q q. q. q"), bpm: 88, display: .rhythm),
            L.timed("3 + 3 + 2 with chords", "Right-hand chords in the 3 + 3 + 2 rhythm over held left-hand roots.",
                    groove([cC, cG, cAm, cF], [bC, bG, bAm, bF], hits: [(0, 1.5), (1.5, 1.5), (3, 1)], bass: [(0, 4)]),
                    bpm: 84, display: .staffAndRhythm),
            L.timed("Backbeat", "Rock feel: the left hand plays beats 1 and 3, the right-hand chord answers on **2 and 4**.",
                    groove([cC, cG, cAm, cF], [bC, bG, bAm, bF], hits: [(1, 1), (3, 1)], bass: [(0, 1), (2, 1)]),
                    bpm: 88, display: .staffAndRhythm),
            L.timed("Off-beat stabs", "Now the chords fall **between** the beats, on every \"and\", while the left hand keeps beats 1 and 3. Keep them short.",
                    groove([cC, cG, cAm, cF], [bC, bG, bAm, bF], hits: [(0.5, 0.5), (1.5, 0.5), (2.5, 0.5), (3.5, 0.5)], bass: [(0, 1), (2, 1)]),
                    bpm: 76, display: .staffAndRhythm, toleranceMs: 120),
        ])

        // 3. Arpeggiated ballad accompaniment with an original melody
        func roll(_ root: String, minor: Bool = false) -> [Int] {
            let r = Music.midi(root)
            return [r, r + 7, r + 12, r + (minor ? 15 : 16), r + 12, r + 7, r + 12, r + 7]
        }
        let rollFingers = [5, 2, 1, 2, 1, 2, 1, 2]
        func rollLine(_ roots: [(String, Bool)]) -> [ExpectedEvent] {
            var out: [ExpectedEvent] = []
            for (bar, root) in roots.enumerated() {
                out += L.line(roll(root.0, minor: root.1), hand: .left, fingers: rollFingers, duration: 0.5, start: Double(bar) * 4)
            }
            return out
        }
        // The 10th is reached by crossing finger 2 over the thumb.
        let balladRoots: [(String, Bool)] = [("C3", false), ("A2", true), ("F2", false), ("G2", false)]
        let balladLeft = rollLine(balladRoots)
        let balladTune = L.melody("G4:h.:2 A4:q:3 | C5:h:5 A4:h:3 | A4:h.:3 F4:q:1 | G4:w:2")
        let ballad = lesson("songs.modern.ballad-arpeggios", "Ballad arpeggios", "The rolling 1–5–8–10 left hand of slow show songs.", [
            L.info("Rolling the chord",
                   "In a ballad the left hand rarely plays blocks. It **rolls** the chord across more than an octave: root, fifth, octave, then the third on top — numbered **1 – 5 – 8 – 10** from the root.\n\nIn C that is C – G – C – E. Play C with finger 5, G with 2, the upper C with the thumb, then **cross finger 2 over the thumb** to reach E. Keep the wrist moving sideways with the notes.",
                   keys: L.keys(n("C3 G3 C4 E4"), labels: ["1", "5", "8", "10"], hand: .left)),
            L.play("The roll on C", "Up to the 10th and back down, slowly. Follow the finger numbers.",
                   L.line(roll("C3"), hand: .left, fingers: rollFingers, duration: 0.5), display: .staff),
            L.play("Four chords", "The same roll on C, A minor, F and G.", balladLeft, display: .staff),
            L.timed("Rolling in time", "Even eighth notes, one chord per bar. Aim for a smooth, harp-like sound.",
                    balladLeft, bpm: 66, display: .staffAndRhythm, rules: [.evenVelocity(maxStdDev: 14)]),
            L.play("A melody to go on top", "An original four-bar melody in long notes. Find it with the right hand.", balladTune, display: .staff),
            L.timed("Melody over the roll", "Both hands. The long right-hand notes must **sing above** the moving left hand.",
                    L.together(balladTune, balladLeft), bpm: 60, display: .staffAndRhythm,
                    rules: [.handBalance(melody: .right, minDiff: 8)], toleranceMs: 130),
        ])

        // 4. Dramatic minor: lament bass and octaves
        let lamentRight = [n("C4 E4 A4"), n("B3 D4 G4"), n("C4 F4 A4"), n("B3 E4 G#4")]
        let lamentLeft = [n("A2 A3"), n("G2 G3"), n("F2 F3"), n("E2 E3")]
        let chromRight = [n("C4 E4 A4"), n("E4 G#4 B4"), n("C4 E4 G4"), n("D4 F#4 A4"), n("C4 F4 A4"), n("B3 E4 G#4"), n("B3 E4 G#4"), n("C4 E4 A4")]
        let chromLeft = [n("A2 A3"), n("G#2 G#3"), n("G2 G3"), n("F#2 F#3"), n("F2 F3"), n("E2 E3"), n("E2 E3"), n("A2 A3")]
        let octaveTune = L.melody("E4+E5:h F4+F5:q E4+E5:q | D4+D5:h. C4+C5:q | B3+B4:h C4+C5:q D4+D5:q | E4+E5:w")
        let octaveBass = L.melody("A2:w D3:w E3:w A2:w", hand: .left)
        let drama = lesson("songs.modern.dramatic-minor", "Dramatic minor", "Falling bass lines and big octaves for the gothic, operatic style.", [
            L.info("The lament bass",
                   "For four hundred years composers have signalled tragedy the same way: a **bass line that walks down** from the home note of a minor key to the fifth. In A minor that is **A – G – F – E**, harmonised Am – G – F – E.\n\nPlayed in **left-hand octaves** under full chords it gives the dark, organ-like weight you hear in gothic and operatic musicals. Play octaves from a loose wrist with fingers 1 and 5, and let the arm carry the hand to each new position.",
                   keys: L.keys(n("A2 A3"), labels: ["A", "A"], hand: .left) + L.keys(n("C4 E4 A4"), labels: ["C", "E", "A"], hand: .right)),
            L.play("Left-hand octaves", "A – G – F – E in octaves. Keep the hand shape fixed and move from the arm.",
                   L.chords(lamentLeft, hand: .left), display: .staff),
            L.play("Chords above", "A minor, G, F, then E major (with G♯).", L.chords(lamentRight, labels: ["Am", "G", "F", "E"]), display: .staff),
            L.timed("The lament, hands together", "Half notes, twice through. Play it **forte** with arm weight, not force.",
                    L.loop(comp(lamentRight, lamentLeft, dur: 2, labels: ["Am", "G", "F", "E"]), times: 2, length: 8),
                    bpm: 66, display: .staffAndRhythm, rules: [L.f]),
            L.info("Filling in the half steps",
                   "The same descent becomes even more intense when the bass moves by **half steps**: A – G♯ – G – F♯ – F – E. Each bass note gets its own chord above: Am, E/G♯, C/G, D/F♯, F, E.\n\nThe symbol **E/G♯** is a *slash chord*: an E chord with G♯ in the bass."),
            L.timed("The chromatic descent", "Six half-note steps down, two bars to rest on E, then home to A minor.",
                    comp(chromRight, chromLeft, dur: 2, labels: ["Am", "E/G♯", "C/G", "D/F♯", "F", "E", "E", "Am"]),
                    bpm: 60, display: .staffAndRhythm),
            L.timed("A theme in octaves", "An original melody played in **right-hand octaves** for power, over single bass notes.",
                    L.together(octaveTune, octaveBass), bpm: 66, display: .staffAndRhythm, toleranceMs: 130),
        ])

        // 5. Power-ballad build
        let buildLeftSingle = [n("G2"), n("D3"), n("E3"), n("C3")]
        let buildLeftOctave = [n("G2 G3"), n("D3 D4"), n("E3 E4"), n("C3 C4")]
        let buildChords = [gG, gD, gEm, gC]
        let passOne = comp([n("B4"), n("A4"), n("G4"), n("G4")], buildLeftSingle, dur: 4)
        let passTwo = groove(buildChords, buildLeftSingle, hits: [(0, 2), (2, 2)], bass: [(0, 2), (2, 2)])
        let passThree = groove(buildChords, buildLeftOctave, hits: [(0, 1), (1, 1), (2, 1), (3, 1)], bass: [(0, 4)])
        var buildAll = passOne
        buildAll += passTwo.map { var e = $0; e.beat += 16; return e }
        buildAll += passThree.map { var e = $0; e.beat += 32; return e }
        var buildTask = L.timedTask("The full build", "All three verses in a row: 12 bars from **p** to **f**. Plan the crescendo so the loudest point is the very end.",
                                    buildAll, bpm: 76, display: .staffAndRhythm, key: 1, rules: [.crescendo], toleranceMs: 130)
        buildTask.markers = [StaffMarker(beat: 0, text: "p"), StaffMarker(beat: 16, text: "mf"), StaffMarker(beat: 32, text: "f")]
        let build = lesson("songs.modern.power-ballad", "The power-ballad build", "Grow one chord loop from a whisper to a full-voiced climax.", [
            L.info("Building a number",
                   "Big show ballads often use the **same chords from start to finish**. The drama comes from how the texture grows:\n\n- **Verse 1** — a single line over single bass notes, soft\n- **Verse 2** — full chords, moving twice as often, medium loud\n- **Final chorus** — repeated chords over left-hand octaves, loud\n\nYou will play one loop in G (G – D – Em – C) three ways, then join them into one long crescendo."),
            L.timed("Verse 1: bare and quiet", "Single right-hand notes over single bass notes. Play **p**.",
                    passOne, bpm: 76, display: .staffAndRhythm, key: 1, rules: [L.p]),
            L.timed("Verse 2: fuller", "Three-note chords in half notes. Play **mf**.",
                    passTwo, bpm: 76, display: .staffAndRhythm, key: 1, rules: [L.mf]),
            L.timed("Final chorus: everything", "Chords on every beat over left-hand octaves. Play **f**, using arm weight.",
                    passThree, bpm: 76, display: .staffAndRhythm, key: 1, rules: [L.f]),
            .play(buildTask),
        ])

        // 6. Gospel chords, sus and slash chords
        struct Symbol { let name: String; let right: [Int]; let left: [Int] }
        let symbols: [Symbol] = [
            Symbol(name: "C", right: cC, left: n("C3")), Symbol(name: "C/E", right: cC, left: n("E3")),
            Symbol(name: "F", right: cF, left: n("F3")), Symbol(name: "Gsus4", right: n("D4 G4 C5"), left: n("G2")),
            Symbol(name: "G", right: cG, left: n("G2")), Symbol(name: "Am", right: cAm, left: n("A2")),
            Symbol(name: "G/B", right: cG, left: n("B2")), Symbol(name: "F/A", right: cF, left: n("A2")),
        ]
        let sheetOrder = [0, 1, 2, 3, 4, 5, 6, 0]
        let sheet = comp(sheetOrder.map { symbols[$0].right }, sheetOrder.map { symbols[$0].left }, dur: 2,
                         labels: sheetOrder.map { symbols[$0].name })
        let amen = comp([n("F4 A4 C5"), n("E4 G4 C5")], [n("F2 C3"), n("C3 G3")], dur: 4, labels: ["F", "C"])
        let chorale = comp([n("E4 G4 C5"), n("F4 A4 C5"), n("E4 G4 C5"), n("D4 G4 B4"), n("E4 A4 C5"), n("F4 A4 D5"), n("D4 G4 B4"), n("E4 G4 C5")],
                           [n("C3 G3"), n("F2 C3"), n("C3 G3"), n("G2 D3"), n("A2 E3"), n("D3 A3"), n("G2 D3"), n("C3 G3")], dur: 2,
                           labels: ["C", "F", "C", "G", "Am", "Dm", "G", "C"])
        let gospel = lesson("songs.modern.ensemble-chords", "Ensemble chords, sus and slash chords", "Full choral voicings and the chord symbols modern scores use.", [
            L.info("Chords for the whole company",
                   "Ensemble numbers and finales often sound like a choir: **four or five voices moving together**, the left hand playing root and fifth, the right hand a full chord. The \"Amen\" ending, **F to C** (IV – I), is the most familiar gospel sound of all.\n\nPlay these chords as one block — all the keys going down at exactly the same moment.",
                   example: L.timedTask("Amen", "", amen, bpm: 60, display: .staff)),
            L.play("The Amen", "F, then C. Left hand plays root and fifth, right hand the full chord.", amen, display: .staff),
            L.timed("A chorale phrase", "Eight chords in half notes, like a choir. Listen that every chord arrives together.",
                    chorale, bpm: 60, display: .staffAndRhythm, toleranceMs: 130),
            L.info("Sus chords and slash chords",
                   "Two symbols appear constantly in modern vocal scores:\n\n- **sus4** — the third is replaced by the fourth, creating suspense that *resolves* when the third returns. **Gsus4** is G–C–D; it resolves to G (G–B–D).\n- **Slash chords** — the letter after the slash is the **bass note**. **C/E** is a C chord over E; **G/B** is a G chord over B. They make the bass line walk smoothly by step.",
                   keys: L.keys(n("D4 G4 C5"), labels: ["D", "G", "C"], hand: .right) + L.keys(n("G2"), labels: ["G"], hand: .left)),
            L.play("Reading a chord chart", "C – C/E – F – Gsus4 – G – Am – G/B – C. The right hand keeps simple shapes; watch how the left-hand bass walks.",
                   sheet, display: .staff),
            L.timed("The chart in time", "The same chart in half notes.", sheet, bpm: 66, display: .staffAndRhythm, toleranceMs: 130),
            L.quiz("Chord-symbol flashcards", "Play the chord named, with the correct **bass note** in the left hand. No lights — work it out.", rounds: 8) { round in
                let s = symbols[(round * 3 + Int.random(in: 0..<symbols.count)) % symbols.count]
                return L.task(s.name, "", comp([s.right], [s.left], dur: 1), showTargets: false, anyOctave: true)
            },
        ])

        return unit("songs.modern", "Getting ready for modern musicals", [vamps, comping, ballad, drama, build, gospel])
    }
}
