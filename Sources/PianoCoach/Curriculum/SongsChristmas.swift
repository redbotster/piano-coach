import Foundation

// Christmas songs: traditional carols in the public domain, in simple arrangements written for this app.
// Ordered from easiest to hardest; the left hand plays one or two notes per bar.

extension Curriculum {
    static var sChristmas: CurriculumUnit {
        let cPos = "C4 D4 E4 F4 G4"
        let angelsVerse = "E4 E4 E4 G4 | G4:q. F4:e E4:h | E4 D4 E4 G4 | E4:q. D4:e C4:h |"
        let angelsGloria = "G4:h:4 A4:e:5 G4:e:4 F4:e:3 E4:e:2 | F4:h:4 G4:e:5 F4:e:4 E4:e:3 D4:e:2 | E4:h:4 F4:e:5 E4:e:4 D4:e:3 C4:e:2 | D4:q.:3 G3:e:1 G3:h:1 | C4:q:1 D4:q:2 E4:q:3 F4:q:4 | E4:h:3 D4:h:2 |"
        let deckLine = "G4:q.:5 F4:e:4 E4:q:3 D4:q:2 | C4:q:1 D4:q:2 E4:q:3 C4:q:1 | D4:e:2 E4:e:3 F4:e:4 D4:e:2 E4:q.:3 D4:e:2 | C4:q:1 B3:q:2 C4:h:1 |"
        let tree = "C4:e.:2 C4:s:2 C4:q.:2 D4:e:3 | E4:e.:4 E4:s:4 E4:q.:4 E4:e:4 | D4:e:3 E4:e:4 F4:q:5 B3:q:1 |"
        let dingVerse = "G4:q:4 G4:q:4 A4:e:5 G4:e:4 F#4:e:3 E4:e:2 | D4:h.:1 D4:q:1 | E4:q:2 G4:q:4 G4:q:4 F#4:q:3 | G4:h:4 G4:h:4 |"
        let list: [Song] = [
            Song(id: "songs.xmas.angels-we-have-heard", title: "Angels We Have Heard on High", summary: "A French carol with the famous falling \"Gloria\".",
                 about: "A traditional French carol (*Les anges dans nos campagnes*), sung in English since the 1860s.\n\nKey of C, 4/4. The verse stays in **C position**. In the \"Gloria\" the same five-note shape is played three times, each one a step lower — follow the finger numbers as the hand moves down — and the thumb reaches **G below Middle C** at the end of the run.",
                 slow: 66, tempo: 100,
                 rh: rep(angelsVerse, 2) + " " + angelsGloria + " " + angelsGloria.replacingOccurrences(of: "E4:h:3 D4:h:2 |", with: "E4:h:3 D4:h:2 | C4:w:1"),
                 lh: "C3 | C3 | C3 | G2:h C3:h | C3 | C3 | C3 | G2:h C3:h | C3 | G2 | A2 | G2 | C3 | C3:h G2:h | C3 | G2 | A2 | G2 | C3 | C3:h G2:h | C3",
                 pos: cPos),
            Song(id: "songs.xmas.away-in-a-manger", title: "Away in a Manger", summary: "A gentle lullaby carol in three.",
                 about: "The tune is by **James R. Murray** (1887); the words are American, from the 1880s.\n\nKey of C, **3/4**, starting with a pickup on beat 3. The melody drifts down from G to the **G an octave lower**, so the hand changes position several times: follow the finger numbers. Play it softly, like a lullaby.",
                 meter: (3, 4), slow: 66, tempo: 92,
                 rh: "r:h G4:q:5 | G4:q.:5 F4:e:4 E4:q:3 | E4:q:3 D4:q:2 C4:q:1 | C4:q:4 B3:q:3 A3:q:2 | G3:h:1 G3:q:1 | G3:q.:1 A3:e:2 G3:q:1 | G3:q:1 D4:q:5 B3:q:3 | A3:q:2 G3:q:1 C4:q:1 | E4:h:3 G4:q:5 | G4:q.:5 F4:e:4 E4:q:3 | E4:q:3 D4:q:2 C4:q:1 | C4:q:4 B3:q:3 A3:q:2 | G3:h:1 G3:q:1 | F4:q.:4 E4:e:3 D4:q:2 | E4:q:3 D4:q:2 C4:q:1 | D4:q:4 A3:q:1 B3:q:2 | C4:h:3",
                 lh: "r C3 C3 F3 C3 C3 G2 F3:h C3:q C3 C3 C3 F3 C3 G2 C3 G2 C3:h", ld: "h.", dynamic: "p"),
            Song(id: "songs.xmas.we-wish-you", title: "We Wish You a Merry Christmas", summary: "A lively English carol in three, verse and refrain.",
                 about: "A traditional carol from the West Country of England.\n\nKey of C, **3/4**, with a pickup. Each of the first three lines is the same shape starting **one step higher**, so the hand moves up a key each time. The refrain (\"Good tidings we bring\") is mostly quarter notes, with one leap up to high G.",
                 meter: (3, 4), slow: 72, tempo: 120,
                 rh: "r:h G3:q:1 | C4:q:4 C4:e:4 D4:e:5 C4:e:4 B3:e:3 | A3:q:2 A3:q:2 A3:q:2 | D4:q:4 D4:e:4 E4:e:5 D4:e:4 C4:e:3 | B3:q:2 G3:q:1 G3:q:1 | E4:q:4 E4:e:4 F4:e:5 E4:e:4 D4:e:3 | C4:q:3 A3:q:2 G3:e:1 G3:e:1 | A3:q:2 D4:q:5 B3:q:3 | C4:h:4 G3:q:1 | C4:q:4 C4:q:4 C4:q:4 | B3:h:3 B3:q:3 | C4:q:4 B3:q:3 A3:q:2 | G3:h:1 D4:q:2 | E4:q:3 D4:q:2 C4:q:1 | G4:q:5 G3:q:1 G3:e:1 G3:e:1 | A3:q:2 D4:q:5 B3:q:3 | C4:h:4",
                 lh: "r C3 F3 D3 G2 C3 F3 F3:q G2:h C3 C3 G2 F3 C3 C3 C3 F3:q G2:h C3:h", ld: "h."),
            Song(id: "songs.xmas.o-christmas-tree", title: "O Christmas Tree", summary: "O Tannenbaum, with its bouncing dotted rhythm.",
                 about: "A German folk melody; the words *O Tannenbaum* date from 1824.\n\nKey of C, **3/4**, with a pickup. The opening has a **dotted eighth and sixteenth** (long–short, like a skip) followed by a long note. In the middle section the hand moves up so that finger 5 can reach **A**.",
                 meter: (3, 4), slow: 63, tempo: 92,
                 rh: "r:h G3:q:1 | " + tree + " D4:q:3 C4:q:2 G3:q:1 | " + tree + " D4:q:3 C4:q:2 r:e G4:e:4 | G4:e:4 E4:e:2 A4:q.:5 G4:e:4 | G4:e:4 F4:e:3 F4:q.:3 F4:e:3 | F4:e:3 D4:e:1 G4:q.:4 F4:e:3 | F4:e:3 E4:e:2 E4:q:2 G3:q:1 | " + tree + " D4:q:3 C4:h:2",
                 lh: "r C3 C3 G2 G2:q C3:h C3 C3 G2 G2:q C3:h C3:q F3:h G2 G2 C3 C3 C3 G2 G2:q C3:h", ld: "h."),
            Song(id: "songs.xmas.joy-to-the-world", title: "Joy to the World", summary: "A carol that opens with a complete descending scale.",
                 about: "The tune *Antioch* was arranged by **Lowell Mason** in 1839; Isaac Watts wrote the words in 1719.\n\nKey of C, 4/4. The first line is simply the **C major scale coming down**, with finger 3 crossing over the thumb. Later the melody climbs back to high C by step. Keep the dotted rhythms crisp.",
                 slow: 76, tempo: 120,
                 rh: "C5:h:5 B4:q.:4 A4:e:3 | G4:h.:2 F4:q:1 | E4:h:3 D4:h:2 | C4:h.:1 G4:q:2 | A4:h.:3 A4:q:3 | B4:h.:4 B4:q:4 | C5:h.:5 C5:q:5 | C5:q:5 B4:q:4 A4:q:3 G4:q:2 | G4:q.:3 F4:e:2 E4:q:1 C5:q:5 | C5:q:5 B4:q:4 A4:q:3 G4:q:2 | G4:q.:3 F4:e:2 E4:q:1 E4:q:3 | E4:q:3 E4:q:3 E4:q:3 E4:e:3 F4:e:4 | G4:h.:5 F4:e:4 E4:e:3 | D4:q:2 D4:q:2 D4:q:2 D4:e:2 E4:e:3 | F4:h.:4 E4:e:3 D4:e:2 | C4:q:1 C5:h:5 A4:q | G4:q.:5 F4:e:4 E4:q:3 F4:q:4 | E4:h:3 D4:h:2 | C4:w:1",
                 lh: "C3 | C3 | C3:h G2:h | C3 | F3 | G2 | C3 | C3 | C3 | C3 | C3 | C3 | C3 | G2 | G2 | C3 | C3 | C3:h G2:h | C3",
                 dynamic: "f"),
            Song(id: "songs.xmas.deck-the-halls", title: "Deck the Halls", summary: "A Welsh dance tune full of fa-la-las.",
                 about: "A Welsh melody (*Nos Galan*) from the 1500s; the English words are from 1862.\n\nKey of C, 4/4. Lines 1, 2 and 4 begin the same way, coming down from G. The third line climbs to **high C** and uses one black key, **F♯**. In the last line the hand jumps up to A and comes down the scale.",
                 slow: 72, tempo: 116,
                 rh: rep(deckLine, 2) + " D4:q.:2 E4:e:3 F4:q:4 D4:q:2 | E4:q.:3 F4:e:4 G4:q:5 D4:q:2 | E4:e:1 F#4:e:2 G4:q:1 A4:e:2 B4:e:3 C5:q:4 | B4:q:3 A4:q:2 G4:h:1 | G4:q.:5 F4:e:4 E4:q:3 D4:q:2 | C4:q:1 D4:q:2 E4:q:3 C4:q:1 | A4:e:3 A4:e:3 A4:e:3 A4:e:3 G4:q.:2 F4:e:1 | E4:q:3 D4:q:2 C4:h:1",
                 lh: "C3 | C3 | G2:h C3:h | C3:q G2:q C3:h | C3 | C3 | G2:h C3:h | C3:q G2:q C3:h | G2 | C3 | C3:h D3:h | G2 | C3 | C3 | F3:h C3:h | C3:q G2:q C3:h"),
            Song(id: "songs.xmas.first-noel", title: "The First Noel", summary: "A flowing carol that climbs the scale again and again.",
                 about: "A traditional English carol, first printed in 1823. The two lines of the verse are the same; here you play it once, then the refrain.\n\nKey of C, **3/4**, with two pickup eighth notes. The melody keeps running **up the C major scale**: pass the thumb under after finger 3 on the way up, and let finger 3 cross over on the way down.",
                 meter: (3, 4), slow: 66, tempo: 100,
                 rh: "r:h E4:e:3 D4:e:2 | C4:q.:1 D4:e:2 E4:e:3 F4:e:1 | G4:h:2 A4:e:3 B4:e:4 | C5:q:5 B4:q:4 A4:q:3 | G4:h:2 A4:e:3 B4:e:4 | C5:q:5 B4:q:4 A4:q:3 | G4:q:2 A4:q:3 B4:q:4 | C5:q:5 G4:q:2 F4:q:1 | E4:h:3 E4:e:3 D4:e:2 | C4:q.:1 D4:e:2 E4:e:3 F4:e:1 | G4:h:2 C5:e:5 B4:e:4 | A4:h:3 A4:q:3 | G4:h.:2 | C5:q:5 B4:q:4 A4:q:3 | G4:q:2 A4:q:3 B4:q:4 | C5:q:5 G4:q:2 F4:q:1 | E4:h:3",
                 lh: "r C3 C3 F3 C3 F3 G2 C3:h G2:q C3 C3 C3 F3 C3 F3 G2 C3:h G2:q C3:h", ld: "h."),
            Song(id: "songs.xmas.hark-the-herald", title: "Hark! The Herald Angels Sing", summary: "Mendelssohn's march-like tune with wide leaps.",
                 about: "The music is by **Felix Mendelssohn** (1840), adapted to Charles Wesley's words in 1855.\n\nKey of C, 4/4. The tune starts on **G below Middle C** and leaps up a fourth. The dotted quarter–eighth rhythm appears in almost every line. The last two lines are nearly the same; the first ends on E, the second comes home to C.",
                 slow: 72, tempo: 108,
                 rh: "G3:q:1 C4:q:3 C4:q.:3 B3:e:2 | C4:q:3 E4:q:5 E4:q:5 D4:q:4 | G4:q:5 G4:q:5 G4:q.:5 F4:e:4 | E4:q:3 D4:q:2 E4:h:3 | G3:q:1 C4:q:3 C4:q.:3 B3:e:2 | C4:q:3 E4:q:5 E4:q:5 D4:q:4 | G4:q:5 D4:q:3 D4:q.:3 B3:e:1 | B3:q:3 A3:q:2 G3:h:1 | G4:q:5 G4:q:5 G4:q:5 C4:q:1 | F4:q:4 E4:q:3 E4:q:3 D4:q:2 | G4:q:5 G4:q:5 G4:q:5 C4:q:1 | F4:q:4 E4:q:3 E4:q:3 D4:q:2 | A4:q:5 A4:q:5 A4:q:5 G4:q:4 | F4:q:3 E4:q:2 F4:h:3 | D4:q:1 E4:e:2 F4:e:3 G4:q.:4 C4:e:1 | C4:q:1 D4:q:2 E4:h:3 | A4:q.:5 A4:e:5 A4:q:5 G4:q:4 | F4:q:3 E4:q:2 F4:h:3 | D4:q:1 E4:e:2 F4:e:3 G4:q.:4 C4:e:1 | C4:q:1 D4:q:2 C4:h:1",
                 lh: "C3 | C3 | C3 | G2:h C3:h | C3 | C3 | G2 | D3:h G2:h | C3 | G2 | C3 | G2 | F3 | F3 | G2 | C3 | F3 | F3 | G2 | C3",
                 dynamic: "f"),
            Song(id: "songs.xmas.god-rest-ye", title: "God Rest Ye Merry, Gentlemen", summary: "An old English carol in a minor key.",
                 about: "A traditional English carol, known since at least the 1700s.\n\nKey of **A minor** (no sharps or flats), 4/4, with a pickup. It uses only white keys but sounds dark because its home note is A. The melody is nearly all quarter notes; keep them even and steady, like walking. The thumb starts on **A below Middle C**.",
                 slow: 76, tempo: 120,
                 rh: "r:h. A3:q:1 | A3:q:1 E4:q:5 E4:q:5 D4:q:4 | C4:q:3 B3:q:2 A3:q:1 G3:q:2 | A3:q:1 B3:q:2 C4:q:3 D4:q:4 | E4:h.:5 A3:q:1 | A3:q:1 E4:q:5 E4:q:5 D4:q:4 | C4:q:3 B3:q:2 A3:q:1 G3:q:2 | A3:q:1 B3:q:2 C4:q:3 D4:q:4 | E4:h.:5 E4:q:2 | F4:q:3 D4:q:1 E4:q:2 F4:q:3 | G4:q:4 A4:q:5 E4:q:2 D4:q:1 | C4:q:3 A3:q:1 B3:q:2 C4:q:3 | D4:h:4 C4:q:3 D4:q:4 | E4:h:4 F4:q:5 E4:q:4 | E4:q:5 D4:q:4 C4:q:3 B3:q:2 | A3:h:1 C4:e:3 B3:e:2 A3:q:1 | D4:h:4 C4:q:3 D4:q:4 | E4:q:2 F4:q:3 G4:q:4 A4:q:5 | E4:q:5 D4:q:4 C4:q:3 B3:q:2 | A3:h.:1",
                 lh: "r | A2 | A2 | A2 | E3 | A2 | A2 | A2 | E3 | D3 | C3 | A2 | D3 | A2 | E3 | A2 | D3 | C3 | E3 | A2:h."),
            Song(id: "songs.xmas.o-come-all-ye-faithful", title: "O Come, All Ye Faithful", summary: "Adeste Fideles in G, building to a grand refrain.",
                 about: "The hymn *Adeste Fideles* is attributed to **John Francis Wade** (about 1743).\n\nKey of **G** (one sharp, F♯), 4/4, with a pickup. Long notes alternate with steady quarters. The refrain \"O come, let us adore Him\" is sung three times, each time **higher and stronger**, so let it grow.",
                 key: 1, slow: 69, tempo: 100,
                 rh: "r:h. G4:q:4 | G4:h:4 D4:q:1 G4:q:4 | A4:h:5 D4:h:1 | B4:q:3 A4:q:2 B4:q:3 C5:q:4 | B4:h:3 A4:q:2 G4:q:1 | G4:h:4 F#4:q:3 E4:q:2 | F#4:q:1 G4:q:2 A4:q:3 B4:q:4 | F#4:h:3 E4:q.:2 D4:e:1 | D4:h.:1 r:q | D5:h:5 C5:q:4 B4:q:3 | C5:h:4 B4:h:3 | A4:q:2 B4:q:3 G4:q:1 A4:q:2 | F#4:q.:3 E4:e:2 D4:q:1 G4:q:4 | G4:q:4 F#4:q:3 G4:q:4 A4:q:5 | G4:h:4 D4:q:1 B4:q:3 | B4:q:3 A4:q:2 B4:q:3 C5:q:4 | B4:h:3 A4:q:2 B4:q:3 | C5:q:4 B4:q:3 A4:q:2 G4:q:1 | F#4:h:2 G4:q:1 C5:q:4 | B4:h:3 A4:q.:2 G4:e:1 | G4:h.:1",
                 lh: "r | G2 | D3 | G2 | G2:h D3:h | G2:h C3:h | D3:h G2:h | D3 | D3:h. r:q | G2 | C3:h G2:h | D3:h G2:h | D3 | G2:h D3:h | G2 | G2 | G2:h D3:h | C3:h G2:h | D3:h G2:q C3:q | G2:h D3:h | G2:h."),
            Song(id: "songs.xmas.ding-dong-merrily", title: "Ding Dong! Merrily on High", summary: "A French dance tune with a cascading \"Gloria\".",
                 about: "The melody is a French dance from 1589 (*Branle de l'Official*); the English words were added in 1924.\n\nKey of **G** (one sharp, F♯), 4/4. The \"Gloria\" is one six-note figure played **five times, each a step lower**, always with the same fingers: 5, 4, 3-4-5-3. Learn the shape once, then just move the hand down. Keep the eighth notes even.",
                 key: 1, slow: 63, tempo: 100,
                 rh: rep(dingVerse, 2) + " D5:q.:5 C5:e:4 B4:e:3 C5:e:4 D5:e:5 B4:e:3 | C5:q.:5 B4:e:4 A4:e:3 B4:e:4 C5:e:5 A4:e:3 | B4:q.:5 A4:e:4 G4:e:3 A4:e:4 B4:e:5 G4:e:3 | A4:q.:5 G4:e:4 F#4:e:3 G4:e:4 A4:e:5 F#4:e:3 | G4:q.:5 F#4:e:4 E4:e:3 F#4:e:4 G4:e:5 E4:e:3 | F#4:q.:4 E4:e:3 D4:q:2 D4:q:2 | E4:q:3 G4:q:5 G4:q:5 F#4:q:4 | G4:h:5 G4:h:5",
                 lh: "G2:h C3:h | D3 | C3:h D3:h | G2 | G2:h C3:h | D3 | C3:h D3:h | G2 | G2 | C3 | G2 | D3 | E3 | D3 | C3:h D3:h | G2"),
            Song(id: "songs.xmas.what-child-is-this", title: "What Child Is This? (Greensleeves)", summary: "The old English tune Greensleeves, in E minor.",
                 about: "The tune **Greensleeves** dates from the 1500s; the carol words were written in 1865.\n\nKey of **E minor** (one sharp, F♯), **3/4**, with a pickup. Two more black keys appear as accidentals: **C♯** and **D♯**. The long–short–long rhythm (dotted quarter, eighth, quarter) gives the tune its lilt. The refrain starts on **high D**, the top of the piece.",
                 key: 1, meter: (3, 4), slow: 69, tempo: 104,
                 rh: "r:h E4:q:1 | G4:h:2 A4:q:3 | B4:q.:4 C#5:e:5 B4:q:4 | A4:h:3 F#4:q:1 | D4:q.:1 E4:e:2 F#4:q:3 | G4:h:4 E4:q:2 | E4:q.:2 D#4:e:1 E4:q:2 | F#4:h:3 D#4:q:2 | B3:h:1 E4:q:1 | G4:h:2 A4:q:3 | B4:q.:4 C#5:e:5 B4:q:4 | A4:h:3 F#4:q:1 | D4:q.:1 E4:e:2 F#4:q:3 | G4:q.:4 F#4:e:3 E4:q:2 | D#4:q.:2 C#4:e:1 D#4:q:2 | E4:h.:3 | E4:h.:3 | D5:h.:5 | D5:q.:5 C#5:e:4 B4:q:3 | A4:h:2 F#4:q:1 | D4:q.:1 E4:e:2 F#4:q:3 | G4:h:4 E4:q:2 | E4:q.:2 D#4:e:1 E4:q:2 | F#4:h:3 D#4:q:2 | B3:h.:1 | D5:h.:5 | D5:q.:5 C#5:e:4 B4:q:3 | A4:h:2 F#4:q:1 | D4:q.:1 E4:e:2 F#4:q:3 | G4:q.:4 F#4:e:3 E4:q:2 | D#4:q.:2 C#4:e:1 D#4:q:2 | E4:h.:3 | E4:h:3",
                 lh: "r E3 E3 D3 D3 E3 E3 B2 B2 E3 E3 D3 D3 E3 B2 E3 E3 G2 G2 D3 D3 E3 E3 B2 B2 G2 G2 D3 D3 E3 B2 E3 E3:h", ld: "h.", dynamic: "mp"),
        ]
        return unit("songs.xmas", "Christmas songs", list.map { songLesson($0) })
    }
}
