import Foundation

// Voice, unit 7: public-domain songs to sing, with the words written on the notes.
// "–" marks a note that continues the previous syllable.

extension Curriculum {
    /// A song to sing, written as phrases of scale degrees with lyrics (`3=Ma 2=ry`).
    struct VoiceSong {
        var id: String
        var title: String
        var summary: String
        var about: String
        var bpm: Double
        /// Slower tempo for learning the sections.
        var slow: Double
        var phrases: [String]
        /// Names for the sections, one per phrase.
        var names: [String]
    }

    /// Removes the lyrics so the notes show their solfège syllables.
    private static func solfege(_ phrase: String) -> String {
        phrase.split(separator: " ").map { token -> String in
            token.split(separator: "=", maxSplits: 1).first.map(String.init) ?? String(token)
        }.joined(separator: " ")
    }

    static func voiceSongLesson(_ s: VoiceSong) -> Lesson {
        var steps: [Step] = [
            L.info("About this song",
                   s.about + "\n\nPress **Hear it** on any step to listen first. Learn the tune on solfège, then each section with the words, then sing the whole song. Breathe at the ends of lines, where you would if you were speaking the words."),
            V.pattern("The opening on solfège", "Sing the first line on the solfège syllables to fix the tune in your ear before adding words.",
                      solfege(s.phrases[0]), bpm: s.slow),
        ]
        if s.phrases.count > 1 {
            for (i, phrase) in s.phrases.enumerated() {
                steps.append(V.song(i < s.names.count ? s.names[i] : "Section \(i + 1)",
                                    "A little under tempo, with the words. A \"–\" means the syllable carries on over that note.",
                                    V.notes(phrase), bpm: s.slow))
            }
        }
        steps.append(V.song("The whole song", "Everything joined together at singing tempo. Enjoy it!",
                            V.notes(s.phrases.joined(separator: " ")), bpm: s.bpm))
        return lesson(s.id, s.title, s.summary, steps)
    }

    static var vSongs: CurriculumUnit {
        let list: [VoiceSong] = [
            VoiceSong(id: "voice.songs.mary", title: "Mary Had a Little Lamb", summary: "Three notes and one skip: a first song.",
                      about: "An American nursery song from the 1830s. The tune uses only **do, re and mi**, with one skip up to **sol**.",
                      bpm: 100, slow: 80,
                      phrases: ["3=Ma 2=ry 1=had 2=a 3=lit 3=tle 3:h=lamb | 2=lit 2=tle 2:h=lamb | 3=lit 5=tle 5:h=lamb",
                                "3=Ma 2=ry 1=had 2=a 3=lit 3=tle 3=lamb 3=its | 2=fleece 2=was 3=white 2=as 1:w=snow"],
                      names: ["First half", "Second half"]),
            VoiceSong(id: "voice.songs.twinkle", title: "Twinkle, Twinkle, Little Star", summary: "A leap of a fifth, then steps all the way down.",
                      about: "An 18th-century French melody with English words by Jane Taylor (1806). It begins with a leap of a **fifth**, do to sol, then walks down the scale by step.",
                      bpm: 96, slow: 80,
                      phrases: ["1=Twin 1=kle 5=twin 5=kle 6=lit 6=tle 5:h=star | 4=How 4=I 3=won 3=der 2=what 2=you 1:h=are",
                                "5=Up 5=a 4=bove 4=the 3=world 3=so 2:h=high | 5=Like 5=a 4=dia 4=mond 3=in 3=the 2:h=sky",
                                "1=Twin 1=kle 5=twin 5=kle 6=lit 6=tle 5:h=star | 4=How 4=I 3=won 3=der 2=what 2=you 1:h=are"],
                      names: ["Twinkle, twinkle", "Up above the world", "Twinkle again"]),
            VoiceSong(id: "voice.songs.frere-jacques", title: "Frère Jacques (Are You Sleeping?)", summary: "A French round with a quick line in the middle.",
                      about: "A French round known since the 1700s, sung here with the English words. Every line is sung twice. The third line moves in quick **eighth notes**, and the last line drops to **sol below do**.",
                      bpm: 104, slow: 84,
                      phrases: ["1=Are 2=you 3=sleep 1=ing | 1=Are 2=you 3=sleep 1=ing | 3=Bro 4=ther 5:h=John | 3=Bro 4=ther 5:h=John",
                                "5:e=Mor 6:e=ning 5:e=bells 4:e=are 3=ring 1=ing | 5:e=Mor 6:e=ning 5:e=bells 4:e=are 3=ring 1=ing | 1=Ding 5,=ding 1:h=dong | 1=Ding 5,=ding 1:h=dong"],
                      names: ["Are you sleeping", "Morning bells"]),
            VoiceSong(id: "voice.songs.london-bridge", title: "London Bridge", summary: "A long–short rhythm at the start of each line.",
                      about: "An English nursery song first printed in the 1700s. The first bar has a **dotted rhythm**: a long note, then a quick one.",
                      bpm: 108, slow: 88,
                      phrases: ["5:q.=Lon 6:e=don 5=Bridge 4=is 3=fall 4=ing 5:h=down | 2=fall 3=ing 4:h=down | 3=fall 4=ing 5:h=down",
                                "5:q.=Lon 6:e=don 5=Bridge 4=is 3=fall 4=ing 5:h=down | 2:h=my 5:h=fair 3=la 1:h.=dy"],
                      names: ["First half", "Second half"]),
            VoiceSong(id: "voice.songs.row", title: "Row, Row, Row Your Boat", summary: "A lilting tune that climbs a whole octave.",
                      about: "An American round first printed in 1852. It has a swinging **long–short** lilt, and \"merrily\" starts on **high do**, a full octave above the first note, then tumbles down the chord.\n\nThe count-in clicks are quick: the song swings in groups of three of them.",
                      bpm: 132, slow: 108,
                      phrases: ["1:q.=Row 1:q.=row 1=row 2:e=your 3:q.=boat | 3=gent 2:e=ly 3=down 4:e=the 5:h.=stream",
                                "1':e=mer 1':e=ri 1':e=ly 5:e=mer 5:e=ri 5:e=ly 3:e=mer 3:e=ri 3:e=ly 1:e=mer 1:e=ri 1:e=ly | 5=life 4:e=is 3=but 2:e=a 1:h.=dream"],
                      names: ["Row your boat", "Merrily"]),
            VoiceSong(id: "voice.songs.ode-to-joy", title: "Ode to Joy", summary: "Beethoven's theme, moving almost entirely by step.",
                      about: "The theme from the finale of **Beethoven's Ninth Symphony** (1824), with the English hymn words by Henry van Dyke (1907). It moves by step within five notes, so it is ideal for smooth, connected singing.",
                      bpm: 100, slow: 84,
                      phrases: ["3=Joy 3=ful 4=joy 5=ful 5=we 4=a 3=dore 2=thee | 1=God 1=of 2=glo 3=ry 3:q.=Lord 2:e=of 2:h=love",
                                "3=Hearts 3=un 4=fold 5=like 5=flowers 4=be 3=fore 2=thee | 1=Open 1=ing 2=to 3=the 2:q.=sun 1:e=a 1:h=bove"],
                      names: ["Joyful, joyful", "Hearts unfold"]),
            VoiceSong(id: "voice.songs.happy-birthday", title: "Happy Birthday to You", summary: "Starts below do and leaps an octave in the third line.",
                      about: "The melody was published in 1893 by Patty and Mildred Hill. It is in three time and starts on **sol below do**. The third \"Happy birthday\" leaps up a full **octave**, which is where most people go out of tune: hear the top note before you jump.",
                      bpm: 100, slow: 84,
                      phrases: ["r:h 5,:e.=Hap 5,:s=py | 6,=birth 5,=day 1=to | 7,:h=you 5,:e.=Hap 5,:s=py | 6,=birth 5,=day 2=to | 1:h=you",
                                "5,:e.=Hap 5,:s=py | 5=birth 3=day 1=dear | 7,=friend 6,=– 4:e.=Hap 4:s=py | 3=birth 1=day 2=to | 1:h=you"],
                      names: ["First two lines", "Last two lines"]),
            VoiceSong(id: "voice.songs.amazing-grace", title: "Amazing Grace", summary: "A slow hymn in three, using only five different notes.",
                      about: "Words by John Newton (1779), sung to the tune *New Britain* (1829). The melody is **pentatonic**: it uses only do, re, mi, sol and la. It is slow, in three time, so every long note needs steady breath. Several syllables are spread over two notes.",
                      bpm: 84, slow: 72,
                      phrases: ["r:h 5,=A | 1:h=maz 3:e=ing 1:e=– | 3:h=grace 2=how | 1:h=sweet 6,=the | 5,:h=sound 5,=that | 1:h=saved 3:e=a 1:e=– | 3:h=wretch 2=like | 5:h.=me | 5:h=– 3=I",
                                "5:h=once 3:e=was 1:e=– | 3:h=lost 2=but | 1:h=now 6,=am | 5,:h=found 5,=was | 1:h=blind 3:e=but 1:e=– | 3:h=now 2=I | 1:h.=see | 1:h=–"],
                      names: ["Amazing grace", "I once was lost"]),
            VoiceSong(id: "voice.songs.auld-lang-syne", title: "Auld Lang Syne", summary: "The Scottish New Year song, with a dotted lilt.",
                      about: "A Scottish folk tune with words by Robert Burns (1788). Almost every bar begins with a **long–short** pair. The tune starts on sol below do and rises to **la** in the middle.",
                      bpm: 96, slow: 80,
                      phrases: ["r:h. 5,=Should | 1:q.=auld 1:e=ac 1=quain 3=tance | 2:q.=be 1:e=for 2=got 3=and | 1:q.=ne 1:e=ver 3=brought 5=to | 6:h.=mind 6=Should",
                                "5:q.=auld 3:e=ac 3=quain 1=tance | 2:q.=be 1:e=for 2=got 3=and | 1:q.=days 6,:e=of 6,=auld 5,=lang | 1:h.=syne"],
                      names: ["Should auld acquaintance", "And days of auld lang syne"]),
            VoiceSong(id: "voice.songs.silent-night", title: "Silent Night", summary: "A gentle carol with a wide range and long phrases.",
                      about: "Composed by **Franz Gruber** in 1818. It is in a slow three time and covers more than an octave, climbing highest on \"peace\". Sing it quietly, and plan a breath at the end of every line.",
                      bpm: 92, slow: 76,
                      phrases: ["5:q.=Si 6:e=– 5=lent | 3:h.=night | 5:q.=Ho 6:e=– 5=ly | 3:h.=night | 2':h=All 2'=is | 7:h.=calm | 1':h=all 1'=is | 5:h.=bright",
                                "6:h=Round 6=yon | 1':q.=vir 7:e=– 6=gin | 5:q.=mo 6:e=ther 5=and | 3:h.=child | 6:h=Ho 6=ly | 1':q.=in 7:e=fant 6=so | 5:q.=ten 6:e=der 5=and | 3:h.=mild",
                                "2':h=Sleep 2'=in | 4':q.=hea 2':e=ven 7=ly | 1':h.=peace | 3':h.=– | 1'=Sleep 5=– 3=in | 5:q.=hea 4:e=ven 2=ly | 1:h.=peace | 1:h.=–"],
                      names: ["Silent night", "Round yon virgin", "Sleep in heavenly peace"]),
        ]
        return unit("voice.songs", "Songs to sing", list.map { voiceSongLesson($0) })
    }
}
