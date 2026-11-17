import Foundation

// Section 2: Rhythm & Time.
// Rhythm-only tasks accept any key; pitched tasks light the keys and show the staff.

fileprivate enum R {
    /// Rhythm-only scored task (any key unless `note` is given).
    static func tap(_ title: String, _ text: String, _ pattern: String, bpm: Double = 80,
                    meter: (Int, Int) = (4, 4), unit: Int = 4, note: Int? = nil, accentBeats: [Int] = [0],
                    metronome: MetronomeMode = .on, tol: Double = 110, count: Bool = true, pass: Double = 0.8,
                    rules: [Rule] = [], start: Double = 0, total: Double? = nil, tempoEnd: Double? = nil) -> Step {
        .play(tapTask(title, text, pattern, bpm: bpm, meter: meter, unit: unit, note: note, accentBeats: accentBeats,
                      metronome: metronome, tol: tol, count: count, pass: pass, rules: rules, start: start,
                      total: total, tempoEnd: tempoEnd))
    }

    static func tapTask(_ title: String, _ text: String = "", _ pattern: String, bpm: Double = 80,
                        meter: (Int, Int) = (4, 4), unit: Int = 4, note: Int? = nil, accentBeats: [Int] = [0],
                        metronome: MetronomeMode = .on, tol: Double = 110, count: Bool = true, pass: Double = 0.8,
                        rules: [Rule] = [], start: Double = 0, total: Double? = nil, tempoEnd: Double? = nil) -> PlayTask {
        let events = L.rhythm(pattern, note: note, unit: unit, count: count, beatsPerBar: meter.0, start: start)
        return L.timedTask(title, text, events, bpm: bpm, meter: meter, metronome: metronome, tempoEnd: tempoEnd,
                           accentBeats: accentBeats, totalBeats: total, display: .rhythm, rules: rules, pass: pass,
                           toleranceMs: tol)
    }

    /// Pitched scored task shown on the staff with the rhythm lane.
    static func tune(_ title: String, _ text: String, _ spec: String, bpm: Double = 80,
                     meter: (Int, Int) = (4, 4), unit: Int = 4, accentBeats: [Int] = [0],
                     metronome: MetronomeMode = .on, tol: Double = 110, pass: Double = 0.8, rules: [Rule] = [],
                     start: Double = 0, total: Double? = nil, tempoEnd: Double? = nil, flats: Bool = false) -> Step {
        .play(tuneTask(title, text, spec, bpm: bpm, meter: meter, unit: unit, accentBeats: accentBeats,
                       metronome: metronome, tol: tol, pass: pass, rules: rules, start: start, total: total,
                       tempoEnd: tempoEnd, flats: flats))
    }

    static func tuneTask(_ title: String, _ text: String = "", _ spec: String, bpm: Double = 80,
                         meter: (Int, Int) = (4, 4), unit: Int = 4, accentBeats: [Int] = [0],
                         metronome: MetronomeMode = .on, tol: Double = 110, pass: Double = 0.8, rules: [Rule] = [],
                         start: Double = 0, total: Double? = nil, tempoEnd: Double? = nil, flats: Bool = false) -> PlayTask {
        let events = L.melody(spec, unit: unit, start: start)
        return L.timedTask(title, text, events, bpm: bpm, meter: meter, metronome: metronome, tempoEnd: tempoEnd,
                           accentBeats: accentBeats, totalBeats: total, display: .staffAndRhythm, flats: flats,
                           rules: rules, pass: pass, toleranceMs: tol)
    }

    /// Relabel events in an /8 meter with compound counting: 1 la li 2 la li.
    static func laLi(_ events: [ExpectedEvent], beatsPerBar: Int) -> [ExpectedEvent] {
        events.map { event in
            var e = event
            let whole = Int((event.beat + 1e-6).rounded(.down))
            let frac = event.beat - Double(whole)
            if frac > 0.02 { e.label = "·"; return e }
            let inBar = whole % max(1, beatsPerBar)
            switch inBar % 3 {
            case 0: e.label = "\(inBar / 3 + 1)"
            case 1: e.label = "la"
            default: e.label = "li"
            }
            return e
        }
    }

    /// Two-hand polyrhythm: right hand on `rh`, left hand on `lh`, repeated.
    static func poly(right: String, left: String, bar: Double, times: Int,
                     rh: Int = 67, lh: Int = 48) -> [ExpectedEvent] {
        let a = L.rhythm(right, note: rh, hand: .right, count: false)
        let b = L.rhythm(left, note: lh, hand: .left, count: false)
        return L.loop(L.together(a, b), times: times, length: bar)
    }

    /// A line with hand-written (free) timings, for Listen examples of rubato and fermatas.
    static func free(_ names: String, _ lengths: [Double]) -> [ExpectedEvent] {
        var beat = 0.0
        var out: [ExpectedEvent] = []
        for (i, n) in Music.notes(names).enumerated() {
            let d = i < lengths.count ? lengths[i] : 1
            out.append(ExpectedEvent(notes: [NoteSpec(midi: n)], beat: beat, duration: d))
            beat += d
        }
        return out
    }
}

extension Curriculum {
    static var rhythm: CurriculumSection {
        CurriculumSection(id: "rhythm", title: "Rhythm & Time", symbol: "metronome", units: [
            rhythmPulse, rhythmValues, rhythmRests, rhythmMeter, rhythmFeel, rhythmPoly, rhythmTempo, rhythmOdd,
            rhythmLab,
        ])
    }

    // MARK: 1. Pulse

    fileprivate static var rhythmPulse: CurriculumUnit {
        let steady = lesson("rhythm.pulse.steady", "Steady pulse", "Feel the beat and play exactly with the metronome.", [
            L.info("The beat", """
            Music has a **pulse** — a steady, repeating beat like a heartbeat or footsteps. Everything in rhythm is measured against it.

            **Tempo** is how fast the pulse goes, measured in **BPM** (beats per minute). 60 BPM is one beat per second; 120 BPM is two.

            A **metronome** clicks the pulse for you. In every timed exercise you hear a count-in (one bar of clicks), then you play. The higher click marks beat 1.
            """, glyph: "note:q", example: R.tapTask("Pulse at 60", "", "q q q q q q q q", bpm: 60)),
            L.info("How these exercises work", """
            - Press **Start** (or the space bar). Listen to the count-in.
            - Tap **any key** on each block as the playhead reaches it. For rhythm-only drills the pitch doesn't matter.
            - Coloured ticks show where you really played: green is on the beat, yellow is close, orange is far.
            - Your result shows the average distance from the beat in milliseconds and whether you tend to **rush** (early) or **drag** (late).

            Tip: don't wait to hear the click and then react. Predict it — aim to land *with* the click so it almost disappears under your note.
            """),
            R.tap("Slow pulse", "One note on every click, 60 BPM. Tap any key. Keep your arm loose and count **1 2 3 4** out loud.",
                  "q q q q | q q q q", bpm: 60),
            R.tap("Walking pulse", "Same idea a little faster. Stay relaxed and keep counting.",
                  "q q q q | q q q q | q q q q", bpm: 80),
            R.tap("Brisk pulse", "100 BPM, four bars. Small, light finger movements.",
                  "q q q q | q q q q | q q q q | q q q q", bpm: 100),
            R.tune("Pulse on real keys", "Now on the lit keys: alternate C and G with a steady beat.",
                   "C4:q G4:q C4:q G4:q | C4:q G4:q C4:q G4:q", bpm: 76),
        ])

        let downbeat = lesson("rhythm.pulse.downbeat", "Bars and the downbeat", "Group beats into bars and feel beat 1.", [
            L.info("Bars (measures)", """
            Beats are grouped into **bars** (also called **measures**), separated by vertical **bar lines**. The most common grouping is four beats per bar.

            Beat 1 of each bar is the **downbeat**. It naturally feels a little stronger — the metronome gives it a higher click. Count **1** 2 3 4, **1** 2 3 4.
            """, example: R.tapTask("Accented downbeats", "", "q> q q q | q> q q q", bpm: 80)),
            R.tap("Count the bars", "Three bars of four. Say the numbers aloud and feel each new bar begin on 1.",
                  "q q q q | q q q q | q q q q", bpm: 84),
            R.tap("Lean on beat 1", "Play beat 1 of each bar clearly **louder** than beats 2, 3 and 4 (marked >).",
                  "q> q q q | q> q q q | q> q q q | q> q q q", bpm: 80, rules: [.accents(minDiff: 8)]),
            R.tap("Only the downbeats", "Play **only on beat 1** of each bar and count 2-3-4 silently. Staying still accurately is a skill too.",
                  "q rq rq rq | q rq rq rq | q rq rq rq | q rq rq rq", bpm: 84),
        ])
        return unit("rhythm.pulse", "Pulse & Metronome", [steady, downbeat])
    }

    // MARK: 2. Note values

    fileprivate static var rhythmValues: CurriculumUnit {
        let long = lesson("rhythm.values.long", "Whole, half and quarter notes", "The three basic note lengths.", [
            L.info("Quarter note", """
            The **quarter note** (crotchet) has a filled head and a stem. In most music it gets **one beat**.

            Four quarter notes fill a bar of four beats: count **1 2 3 4**.
            """, glyph: "note:q", example: R.tapTask("Quarters", "", "q q q q", bpm: 72)),
            L.info("Half note", """
            The **half note** (minim) has a hollow head and a stem. It lasts **two beats** — play on the first and keep the key **held down** through the second.

            Count **1**-2, **3**-4.
            """, glyph: "note:h", example: R.tapTask("Halves", "", "h h", bpm: 72)),
            L.info("Whole note", """
            The **whole note** (semibreve) is a hollow head with no stem. It lasts **four beats** — a whole bar. Play on 1 and hold while you count 2, 3, 4.

            Each value is half the one before: 1 whole = 2 halves = 4 quarters.
            """, glyph: "note:w", example: R.tapTask("Whole", "", "w", bpm: 72)),
            R.tap("Quarters and halves", "Hold each half note for its full two beats.", "q q h | h q q | q q q q | h h", bpm: 72),
            R.tap("Add whole notes", "Hold the whole notes all the way to the next bar line.", "w | h h | q q q q | w", bpm: 76),
            R.tune("Long and short on the keys", "Play the lit keys, holding each note for its full length.",
                   "C4:q D4:q E4:h | F4:h G4:h | E4:q D4:q C4:h | C4:w", bpm: 72, rules: [.legato]),
        ])

        let eighths = lesson("rhythm.values.eighths", "Eighth notes", "Two notes per beat: 1 & 2 &.", [
            L.info("Eighth note", """
            An **eighth note** (quaver) has a filled head, a stem and one **flag**. Two eighths fit in one beat, and in pairs their flags join into a **beam**.

            Count the notes between the beats as **“and”**: **1 & 2 & 3 & 4 &**. The numbers fall on the clicks; the “&”s fall exactly halfway between.
            """, glyph: "note:e note:e", example: R.tapTask("Eighths", "", "e e e e e e e e", bpm: 72)),
            R.tap("Steady eighths", "Two even notes per click. Say “1 and 2 and…”.", "e e e e e e e e | e e e e e e e e", bpm: 66),
            R.tap("Quarters and eighths", "Switch between one and two notes per beat without changing the pulse.",
                  "q q e e q | e e e e q q | q e e q e e | e e e e h", bpm: 72),
            R.tap("Eighths at speed", "Keep the “&” exactly in the middle — don't let pairs clump together.",
                  "e e q e e q | q e e e e q | e e e e e e e e | h h", bpm: 88),
            R.tune("Eighths on the keys", "A five-finger tune with running eighths.",
                   "C4:e D4:e E4:e F4:e G4:q G4:q | G4:e F4:e E4:e D4:e C4:h", bpm: 70),
        ])

        let sixteenths = lesson("rhythm.values.sixteenths", "Sixteenth notes", "Four notes per beat: 1 e & a.", [
            L.info("Sixteenth note", """
            A **sixteenth note** (semiquaver) has **two flags** or beams. Four of them fit in one beat.

            Count **1 e & a, 2 e & a** (“one-ee-and-uh”). The number is on the click, “&” is still the halfway point, and “e” and “a” fill the gaps.
            """, glyph: "note:s note:s", example: R.tapTask("Sixteenths", "", "s s s s s s s s q q", bpm: 60)),
            R.tap("Four per beat", "Slow tempo. Alternate two fingers (or two hands) if that's easier — evenness is the goal.",
                  "s s s s q s s s s q | s s s s s s s s h", bpm: 56),
            L.info("Common sixteenth patterns", """
            Three shapes appear everywhere:

            - **eighth + two sixteenths**: “1 - & a” (long short short)
            - **two sixteenths + eighth**: “1 e & -” (short short long)
            - four sixteenths: “1 e & a”

            Keep saying all four syllables in your head and only play the ones written.
            """, example: R.tapTask("Patterns", "", "e s s e s s | s s e s s e | s s s s q", bpm: 60, total: 6)),
            R.tap("Long-short-short", "Eighth then two sixteenths: “1 (e) & a”.", "e s s e s s e s s q | e s s e s s h", bpm: 60),
            R.tap("Short-short-long", "Two sixteenths then an eighth: “1 e & (a)”.", "s s e s s e s s e q | s s e s s e h", bpm: 60),
            R.tap("Mixed sixteenths", "All three shapes. Keep the click in your ear.",
                  "s s s s e s s q e e | s s e s s s s e e q", bpm: 63),
        ])

        let thirtySeconds = lesson("rhythm.values.thirtyseconds", "Thirty-second notes", "Eight notes per beat, in short bursts.", [
            L.info("Thirty-second note", """
            A **thirty-second note** (demisemiquaver) has **three flags** or beams. Eight fit in one beat — twice as fast as sixteenths.

            They usually appear in slow music as quick flourishes. To count them, slow the pulse right down and feel each *eighth* as its own mini-beat with four notes inside it.

            The full family: whole (4 beats), half (2), quarter (1), eighth (½), sixteenth (¼), thirty-second (⅛). Each is half the previous.
            """, glyph: "note:t note:t", example: R.tapTask("Thirty-seconds", "", "q t t t t t t t t q q", bpm: 50)),
            R.tap("Half a beat of 32nds", "A burst of four fast notes leading into the next eighth. Use alternating fingers 2-3 or two hands.",
                  "q t t t t e q q | q t t t t e h", bpm: 50, pass: 0.75),
            R.tap("A full beat of 32nds", "Eight notes inside one click. Stay loose — tension makes fast notes uneven.",
                  "q t t t t t t t t q q | h t t t t t t t t q", bpm: 46, pass: 0.75),
            R.tap("The whole family", "Every value from whole note to 32nd, each half as long as the last.",
                  "w | h h | q q q q | e e e e s s s s s s s s | t t t t t t t t q h", bpm: 50, pass: 0.75),
        ])
        return unit("rhythm.values", "Note Values", [long, eighths, sixteenths, thirtySeconds])
    }

    // MARK: 3. Rests, dots, ties

    fileprivate static var rhythmRests: CurriculumUnit {
        let longRests = lesson("rhythm.rests.long", "Whole, half and quarter rests", "Silence is counted just as carefully as sound.", [
            L.info("Rests", """
            Every note value has a matching **rest** — a symbol for silence of the same length. Rests are counted exactly like notes; you simply lift off the key.

            The **quarter rest** is a squiggle and lasts one beat.
            """, glyph: "rest:q", example: R.tapTask("Quarter rests", "", "q rq q rq | q q rq q", bpm: 76)),
            L.info("Half and whole rests", """
            The **half rest** is a small block sitting **on top of** the middle line (like a hat): two beats of silence.

            The **whole rest** is the same block **hanging below** a line: four beats — and it is also used to mean “a whole bar of silence” in any time signature.
            """, glyph: "rest:h rest:w", example: R.tapTask("Half and whole rests", "", "h rh | rw | q q rh", bpm: 76)),
            R.tap("Quarter rests", "Release the key for each rest and keep counting through the silence.",
                  "q rq q rq | q q rq q | rq q rq q | q rq rq q", bpm: 76),
            R.tap("Half and whole rests", "Count the empty bar — don't come in early.", "h rh | q q rh | rw | rh h", bpm: 80),
            R.tune("Rests in a melody", "Lift cleanly for each rest so the silence is real.",
                   "C4:q E4:q G4:q r:q | G4:q r:q E4:q r:q | C4:h r:h", bpm: 76),
        ])

        let shortRests = lesson("rhythm.rests.short", "Eighth, sixteenth and 32nd rests", "Short silences and off-beat entries.", [
            L.info("Eighth rest", """
            The **eighth rest** looks like a slanted stroke with one small flag: half a beat of silence.

            An eighth rest *on* the beat followed by an eighth note puts the note on the **“&”** — the off-beat. Feel the click as the rest, then play.
            """, glyph: "rest:e", example: R.tapTask("Off-beats", "", "re e re e re e re e | q rq h", bpm: 72)),
            R.tap("Notes on the “&”", "Rest on each click and play exactly between clicks.", "re e re e re e re e | re e re e q rq", bpm: 66),
            R.tap("Eighth rests mixed in", "Count “1 & 2 &” throughout.", "e re e e q re e | q re e re e q | e e re e h", bpm: 72),
            L.info("Sixteenth and 32nd rests", """
            The **sixteenth rest** has two flags (a quarter of a beat); the **thirty-second rest** has three (an eighth of a beat).

            Count “1 e & a” and leave out the syllable where the rest falls. The complete set of rests mirrors the notes: whole, half, quarter, eighth, sixteenth, thirty-second.
            """, glyph: "rest:s rest:t", example: R.tapTask("Sixteenth rests", "", "rs s s s q | s rs s s q", bpm: 56, meter: (2, 4))),
            R.tap("Sixteenth rest on the beat", "Silent on the click, then “e & a”.", "rs s s s q rs s s s q | rs s s s rs s s s h", bpm: 54, pass: 0.75),
            R.tap("Sixteenth rests inside the beat", "“1 (e) & a” and “1 e (&) a”.", "s rs s s q s s rs s q | s rs s s s s rs s h", bpm: 54, pass: 0.75),
            R.tap("A 32nd rest", "A tiny breath: the burst starts just after the click.", "q rt t t t e q q | rt t t t e q h", bpm: 46, pass: 0.7),
        ])

        let dotted = lesson("rhythm.rests.dotted", "Dotted notes", "A dot adds half the note's value.", [
            L.info("The dot", """
            A **dot** after a note adds **half of its value** again:

            - dotted half = 2 + 1 = **3 beats**
            - dotted quarter = 1 + ½ = **1½ beats**
            - dotted eighth = ½ + ¼ = **¾ of a beat**

            Rests can be dotted the same way.
            """, glyph: "note:h. note:q.", example: R.tapTask("Dotted half", "", "h. q | h. q", bpm: 76)),
            R.tap("Dotted half notes", "Hold for three full beats, then a quarter on beat 4.", "h. q | h. q | q q h | h. rq", bpm: 80),
            L.info("Dotted quarter + eighth", """
            The dotted quarter is nearly always followed by an eighth: together they fill two beats.

            Count “**1** (2) **&**”: play on 1, hold through 2, and play the eighth on the “&” of 2.
            """, glyph: "note:q. note:e", example: R.tapTask("Dotted quarter", "", "q. e q q | q. e h", bpm: 72)),
            R.tap("Dotted quarter + eighth", "Feel beat 2 pass silently before the short note.", "q. e q q | q. e h | q. e q. e | w", bpm: 72),
            L.info("Dotted eighth + sixteenth", """
            Inside one beat, a dotted eighth plus a sixteenth gives a skipping **long-short**: “**1** (e &) **a**”.

            The sixteenth belongs to the *next* beat — tuck it in late, just before the click.
            """, glyph: "note:e. note:s", example: R.tapTask("Dotted eighth", "", "e. s e. s q q", bpm: 63)),
            R.tap("Dotted eighth + sixteenth", "Long-short, long-short. Don't let it soften into triplets.", "e. s e. s q q | e. s e. s e. s q", bpm: 60, pass: 0.75),
            R.tune("Dotted tune", "Dotted rhythms on the keys.", "C4:q. D4:e E4:q C4:q | E4:q. F4:e G4:h | G4:e. F4:s E4:e. D4:s C4:h", bpm: 66),
        ])

        let ties = lesson("rhythm.rests.ties", "Ties", "Joining notes into one longer sound.", [
            L.info("The tie", """
            A **tie** is a curved line joining two notes of the **same pitch**. Play the first and **hold through** the second without striking again — their lengths add together.

            Ties make lengths that no single note can show, and they carry a sound **across a bar line**. (A curved line over *different* pitches is a slur — that means legato, not hold.)

            In the rhythm lane a tied note is drawn as one long block.
            """, example: R.tapTask("Tie across the bar", "", "q q q q~q q q q", bpm: 76)),
            R.tap("Tie within the bar", "Half tied to an eighth: hold for 2½ beats, then play on the “&” of 3.", "h~e e q | h~e e q | q q h~q q h", bpm: 72),
            R.tap("Tie across the bar line", "The last note of bar 1 holds into beat 1 of bar 2 — don't re-strike on the downbeat.",
                  "q q q q~q q q q | q q h~h q q", bpm: 76),
            R.tap("Ties and dots", "A dotted quarter is really a quarter tied to an eighth. Both appear here.",
                  "q. e q~e e | q q~e e q | h~e e e e | w", bpm: 72),
        ])
        return unit("rhythm.rests", "Rests, Dots & Ties", [longRests, shortRests, dotted, ties])
    }

    // MARK: 4. Meter

    fileprivate static var rhythmMeter: CurriculumUnit {
        let simple = lesson("rhythm.meter.simple", "4/4, 3/4 and 2/4", "Reading time signatures in simple meters.", [
            L.info("Time signatures", """
            The two numbers at the start of a piece are the **time signature**.

            - The **top** number says how many beats are in each bar.
            - The **bottom** number says which note value gets one beat: 4 = quarter note, 8 = eighth note, 2 = half note.

            **4/4** is four quarter-note beats per bar. It is so common it is called **common time** and may be written as a large **C**. Accent pattern: **strong** – weak – medium – weak.
            """, glyph: "4/4", example: R.tapTask("4/4", "", "q> q q q | q> q q q", bpm: 84)),
            R.tap("4/4", "Four beats per bar.", "q q e e q | h q q | e e e e q q | w", bpm: 84),
            L.info("3/4 — waltz time", """
            **3/4** has three quarter-note beats per bar: **strong** – weak – weak. It is the meter of the waltz and the minuet.

            A full bar of sound is a dotted half note (3 beats).
            """, glyph: "3/4", example: R.tuneTask("Waltz", "", "C4:q E4:q G4:q | C4:q E4:q G4:q | C5:h.", bpm: 96, meter: (3, 4))),
            R.tap("3/4", "Count **1** 2 3. The high click marks each bar.", "q q q | h q | q e e q | h.", bpm: 92, meter: (3, 4)),
            R.tune("A little waltz", "Three beats per bar on the keys.", "E4:q G4:q G4:q | F4:q A4:q A4:q | E4:q G4:q C5:q | G4:h.", bpm: 92, meter: (3, 4)),
            L.info("2/4 — march time", """
            **2/4** has two quarter-note beats per bar: **strong** – weak, like left-right marching. Bars go by quickly.
            """, glyph: "2/4", example: R.tapTask("2/4", "", "q q | e e q | q q | h", bpm: 96, meter: (2, 4))),
            R.tap("2/4", "Count **1** 2, **1** 2.", "q q | e e q | q e e | e e e e | q q | h", bpm: 92, meter: (2, 4)),
        ])

        let cut = lesson("rhythm.meter.cut", "Cut time (2/2)", "Feeling the half note as the beat.", [
            L.info("Cut time", """
            **2/2**, called **cut time** or *alla breve*, is written like 4/4 but felt in **two**: the **half note** gets the beat. Its symbol is a C with a vertical line through it.

            The page looks the same, but you tap your foot only twice per bar. Quarter notes are now half a beat each: “1 & 2 &”. It is used for fast marches and brisk classical movements.

            Here the metronome clicks half notes.
            """, glyph: "2/2", example: R.tapTask("Cut time", "", "h h | q q q q | h q q | w", bpm: 60, meter: (2, 2), unit: 2)),
            R.tap("Halves are the beat", "One half note per click. Whole notes last two clicks.", "h h | h h | w | h h | w", bpm: 60, meter: (2, 2), unit: 2),
            R.tap("Quarters go between", "Quarter notes are now “1 & 2 &” — two per click.", "h q q | q q h | q q q q | w", bpm: 60, meter: (2, 2), unit: 2),
            R.tune("Cut-time march", "Feel two big beats per bar, not four.", "C4:h G4:h | E4:q E4:q G4:h | F4:q E4:q D4:q E4:q | C4:w",
                   bpm: 66, meter: (2, 2), unit: 2),
        ])

        let sixEight = lesson("rhythm.meter.six-eight", "6/8", "Six eighths felt as two big beats.", [
            L.info("6/8", """
            **6/8** has six **eighth notes** per bar — but they are grouped in **two groups of three**: **1** 2 3 **4** 5 6.

            So you feel two big beats per bar, each a **dotted quarter** long, each dividing into three. That lilting, rocking feel is used in jigs, barcarolles and lullabies.

            In these exercises the metronome clicks every eighth note, with a higher click on 1 and 4.
            """, glyph: "6/8", example: R.tapTask("6/8", "", "e e e e e e | q. q.", bpm: 150, meter: (6, 8), unit: 8, accentBeats: [0, 3])),
            R.tap("Six eighths", "Count **1** 2 3 **4** 5 6 with a lean on 1 and 4.", "e e e e e e | e e e e e e | q. q. | h.",
                  bpm: 144, meter: (6, 8), unit: 8, accentBeats: [0, 3]),
            R.tap("The two big beats", "Dotted quarters land on 1 and 4 — the pulse you tap your foot to.", "q. q. | e e e q. | q. e e e | q. q.",
                  bpm: 150, meter: (6, 8), unit: 8, accentBeats: [0, 3]),
            R.tap("Long-short lilt", "Quarter + eighth is the classic 6/8 rocking rhythm.", "q e q e | q e q. | e e e q e | h.",
                  bpm: 150, meter: (6, 8), unit: 8, accentBeats: [0, 3]),
            R.tune("6/8 melody", "A rocking tune on the keys.", "C4:q E4:e G4:q E4:e | C5:q. G4:q. | A4:q G4:e F4:q D4:e | C4:h.",
                   bpm: 144, meter: (6, 8), unit: 8, accentBeats: [0, 3]),
        ])

        let nineTwelve = lesson("rhythm.meter.nine-twelve", "9/8 and 12/8", "Three and four big beats, each divided in three.", [
            L.info("9/8", """
            **9/8** is nine eighth notes grouped as **three groups of three**: **1** 2 3 **4** 5 6 **7** 8 9. You feel three dotted-quarter beats per bar — like a waltz where every beat rolls in three.
            """, glyph: "9/8", example: R.tapTask("9/8", "", "e e e e e e e e e | q. q. q.", bpm: 160, meter: (9, 8), unit: 8, accentBeats: [0, 3, 6])),
            R.tap("9/8", "Three big beats per bar.", "q. q. q. | e e e q e q. | q e q e q e | q. h.",
                  bpm: 156, meter: (9, 8), unit: 8, accentBeats: [0, 3, 6]),
            L.info("12/8", """
            **12/8** is twelve eighths in **four groups of three**: four dotted-quarter beats per bar. It sounds like 4/4 with every beat split into triplets — the feel of slow blues, doo-wop and many ballads.
            """, glyph: "12/8", example: R.tapTask("12/8", "", "q e q e q e q e | q. q. q. q.", bpm: 168, meter: (12, 8), unit: 8, accentBeats: [0, 3, 6, 9])),
            R.tap("12/8", "Four big beats per bar.", "q. q. q. q. | e e e q. e e e q. | q. q. h.",
                  bpm: 160, meter: (12, 8), unit: 8, accentBeats: [0, 3, 6, 9]),
            R.tap("12/8 shuffle", "Long-short on every beat: the slow-blues shuffle.", "q e q e q e q e | q e q e q. q.",
                  bpm: 168, meter: (12, 8), unit: 8, accentBeats: [0, 3, 6, 9]),
        ])

        let simpleCompound = lesson("rhythm.meter.simple-compound", "Simple vs. compound meter", "Does the beat split in two or in three?", [
            L.info("Two families of meter", """
            - In **simple** meters (2/4, 3/4, 4/4, 2/2) each beat divides into **two**. The beat is a plain note.
            - In **compound** meters (6/8, 9/8, 12/8) each beat divides into **three**. The beat is a **dotted** note.

            Quick test: if the top number is 6, 9 or 12, divide it by three to get the number of big beats — 2, 3 or 4.

            Simple duple 2/4 ↔ compound duple 6/8. Simple triple 3/4 ↔ compound triple 9/8. Simple quadruple 4/4 ↔ compound quadruple 12/8.
            """),
            L.info("3/4 or 6/8?", """
            A bar of 3/4 and a bar of 6/8 both contain six eighth notes — the difference is the **grouping**.

            - 3/4: **1** & **2** & **3** & — three beats, each split in two.
            - 6/8: **1** 2 3 **4** 5 6 — two beats, each split in three.

            Listen: first 3/4, then 6/8. Same number of notes, different accents.
            """, example: R.tapTask("3/4 then 6/8", "", "e> e e> e e> e | e> e e> e e> e | e> e e e> e e | e> e e e> e e",
                                    bpm: 168, meter: (6, 8), unit: 8, accentBeats: [0])),
            R.tap("Six eighths as 3/4", "Accent every **second** note: three beats per bar.", "e> e e> e e> e | e> e e> e e> e | q q q | h.",
                  bpm: 84, meter: (3, 4), rules: [.accents(minDiff: 6)]),
            R.tap("Six eighths as 6/8", "Accent every **third** note: two beats per bar.", "e> e e e> e e | e> e e e> e e | q. q. | h.",
                  bpm: 160, meter: (6, 8), unit: 8, accentBeats: [0, 3], rules: [.accents(minDiff: 6)]),
        ])

        let countingEvents = R.laLi(L.rhythm("e e e e e e | q e q e | e e e q. | h.", unit: 8, beatsPerBar: 6), beatsPerBar: 6)
        let counting = lesson("rhythm.meter.counting", "Counting systems", "1-e-&-a for simple time, 1-la-li for compound.", [
            L.info("Why count out loud?", """
            Counting aloud ties what you read to a steady pulse. Two systems cover almost everything:

            **Simple time — “1 e & a”**
            - quarters: 1, 2, 3, 4
            - eighths: 1 &, 2 &
            - sixteenths: 1 e & a, 2 e & a

            **Compound time and triplets — “1 la li”**
            - each beat splits in three: 1 la li, 2 la li

            The syllables under the rhythm lane show the count for every note.
            """),
            R.tap("1 e & a", "Say every syllable aloud while you play.", "q e e s s s s q | e s s s s e q q | s s s s s s s s e e q", bpm: 60),
            R.tap("Count the gaps too", "Keep saying “1 e & a” through held notes and rests; play only what is written.",
                  "e. s q re e q | s s e re e h", bpm: 60, pass: 0.75),
            L.timed("1 la li in 6/8", "The numbers are the two big beats; “la li” are the eighths in between. Say “1 la li 2 la li”.",
                    countingEvents, bpm: 144, meter: (6, 8), accentBeats: [0, 3], display: .rhythm),
            R.tap("1 la li on triplets", "The same syllables work for triplets in 4/4: three even notes per click.",
                  "3e 3e 3e 3e 3e 3e q q | 3e 3e 3e q 3e 3e 3e q", bpm: 66),
        ])

        let pickup = lesson("rhythm.meter.pickup", "Upbeats and pickup measures", "Starting before the first downbeat (anacrusis).", [
            L.info("Anacrusis", """
            Many tunes don't start on beat 1. One or more notes come **before** the first full bar — an **upbeat**, **pickup** or **anacrusis**. Think “**Hap-py** BIRTH-day”: the first two notes lead into the strong beat.

            The pickup is written as an incomplete bar. By convention the **last** bar of the piece is shortened by the same amount, so the two together make one full bar.

            To come in correctly, count the missing beats first. For a one-beat pickup in 4/4, count “1 2 3” and play on **4**. In these exercises you hear a full bar of count-in, then the beats before the pickup.
            """, example: R.tuneTask("Pickup", "", "G4:q C5:q C5:q D5:q D5:q E5:h.", bpm: 92, start: 3, total: 12)),
            R.tap("Pickup on beat 4", "After the count-in, wait three more beats and enter on **4**.", "q | q q q q | q h.", bpm: 84, start: 3, total: 12),
            R.tune("Pickup into a tune", "One upbeat note leading to each strong beat.", "G4:q | C5:q C5:q D5:q D5:q | E5:h. E5:q | F5:q E5:q D5:q C5:q | C5:h.",
                   bpm: 84, start: 3, total: 20),
            R.tune("Happy Birthday opening", "3/4 with a pickup on beat 3: count “1 2” and play the two eighths on 3.",
                   "G4:e G4:e A4:q G4:q C5:q B4:h", bpm: 84, meter: (3, 4), start: 2, total: 9),
            R.tune("Amazing Grace opening", "Another 3/4 pickup. The final bar is two beats long — it completes the pickup bar.",
                   "G4:q C5:h E5:e C5:e E5:h D5:q C5:h A4:q G4:h", bpm: 80, meter: (3, 4), start: 2, total: 15),
        ])
        return unit("rhythm.meter", "Time Signatures & Meter", [simple, cut, sixEight, nineTwelve, simpleCompound, counting, pickup])
    }

    // MARK: 5. Syncopation, tuplets, swing

    fileprivate static var rhythmFeel: CurriculumUnit {
        let syncopation = lesson("rhythm.feel.syncopation", "Syncopation", "Accents where you don't expect them.", [
            L.info("What is syncopation?", """
            **Syncopation** puts emphasis on weak beats or **between** beats, while the strong beats are left empty or held over. It gives ragtime, jazz, funk, Latin and pop their energy.

            Three ways to make it:

            - a long note starting on an off-beat (eighth–**quarter**–eighth)
            - a **tie** over a strong beat
            - a **rest** on a strong beat

            The pulse must stay rock-steady underneath — keep counting “1 & 2 &” and feel the clicks you *don't* play on.
            """, example: R.tapTask("Syncopation", "", "e q e q q | e q e h", bpm: 84)),
            R.tap("Eighth – quarter – eighth", "“1 **&** (2) **&** 3 4”: the quarter starts on the “&” and hangs over beat 2.", "e q e q q | e q e h | e q e q q | w", bpm: 76),
            R.tap("Tied over the beat", "The tie swallows beat 3. Feel it pass silently.", "q e e~e e q | q e e~e e q | e q e e q e | w", bpm: 76),
            R.tap("Rests on the beat", "Off-beat entries after eighth rests.", "re e re e q q | re e e e re e q | re e re e re e re e | w", bpm: 72),
            R.tap("Anticipation", "The last “&” of bar 1 is tied across the bar line — arriving early on the next downbeat.",
                  "q q q e e~q q h | q q q e e~w", bpm: 80),
            R.tune("Syncopated tune", "Syncopation on the keys.", "C4:e E4:q G4:e E4:q C4:q | D4:e F4:q A4:e G4:h | E4:e G4:q C5:e G4:e E4:q C4:e~h r:h",
                   bpm: 76),
        ])

        let triplets = lesson("rhythm.feel.triplets", "Triplets", "Three notes in the space of two.", [
            L.info("The triplet", """
            A **tuplet** squeezes an unusual number of notes into a beat. The most common is the **triplet**: **three** notes in the time of **two**, marked with a small **3**.

            An **eighth-note triplet** fills one quarter-note beat with three even notes. Count “**1** la li, **2** la li” (or “tri-po-let”).

            The trap: playing two fast and one slow. All three must be perfectly even.
            """, glyph: "3", example: R.tapTask("Triplets", "", "q q 3e 3e 3e q | 3e 3e 3e 3e 3e 3e h", bpm: 72)),
            R.tap("Eighth triplets", "Three even notes per click.", "q q 3e 3e 3e q | 3e 3e 3e q 3e 3e 3e q | 3e 3e 3e 3e 3e 3e h", bpm: 66),
            R.tap("Twos against threes in a row", "Switch between eighths (2 per beat) and triplets (3 per beat) without changing the pulse.",
                  "e e 3e 3e 3e e e 3e 3e 3e | 3e 3e 3e e e 3e 3e 3e q", bpm: 66),
            L.info("Quarter-note triplets", """
            A **quarter-note triplet** spreads three even notes across **two** beats. Only the first note lands on a click; the other two float either side of the next one.

            Feel it by thinking of six triplet eighths and playing every second one: **1** la **li** 2 **la** li.
            """, example: R.tapTask("Quarter triplets", "", "q q 3q 3q 3q | 3q 3q 3q h", bpm: 80)),
            R.tap("Quarter-note triplets", "Three evenly spaced notes over two clicks.", "q q 3q 3q 3q | 3q 3q 3q h | 3q 3q 3q 3q 3q 3q | w", bpm: 80),
            R.tune("Triplet tune", "Rolling triplets on the keys.", "C4:3e E4:3e G4:3e C5:q G4:3e E4:3e C4:3e G4:q | F4:3e A4:3e C5:3e A4:3e F4:3e A4:3e G4:h", bpm: 63),
        ])

        let duplets = lesson("rhythm.feel.duplets", "Duplets", "Two notes in the space of three.", [
            L.info("The duplet", """
            The **duplet** is the mirror image of the triplet: in **compound** time, where the beat normally splits in three, a duplet fits **two** even notes into one beat. It is marked with a small **2**.

            In 6/8, a duplet makes two notes last the whole dotted-quarter beat — each is worth 1½ eighths. It briefly makes compound time sound like simple time.

            Listen: normal 6/8 groups, then duplets.
            """, glyph: "2", example: R.tapTask("Duplets", "", "e e e e e e | 2e 2e 2e 2e | q. q.", bpm: 150, meter: (6, 8), unit: 8, accentBeats: [0, 3], count: false)),
            R.tap("Threes, then twos", "First three notes per big beat, then two. The big beats (higher clicks) don't change.",
                  "e e e e e e | 2e 2e 2e 2e | e e e e e e | 2e 2e q.", bpm: 138, meter: (6, 8), unit: 8, accentBeats: [0, 3], count: false),
            R.tap("Duplets in a phrase", "Switch within the bar.", "e e e 2e 2e | 2e 2e e e e | q e 2e 2e | h.",
                  bpm: 144, meter: (6, 8), unit: 8, accentBeats: [0, 3], count: false, pass: 0.75),
        ])

        let bigTuplets = lesson("rhythm.feel.quintuplets", "Quintuplets and sextuplets", "Five and six notes in one beat.", [
            L.info("Quintuplets", """
            A **quintuplet** fits **five** even notes into one beat (in the time of four sixteenths), marked with a **5**.

            There is no neat counting system — say a five-syllable word on each beat: “**u**-ni-ver-si-ty” or “**hip**-po-pot-a-mus”. Aim the first syllable at the click and spread the rest evenly.
            """, glyph: "5", example: R.tapTask("Quintuplets", "", "q 5s 5s 5s 5s 5s q q | 5s 5s 5s 5s 5s q h", bpm: 56, count: false)),
            R.tap("One quintuplet", "Five even notes inside one click, then land on the next beat.", "q 5s 5s 5s 5s 5s q q | q 5s 5s 5s 5s 5s h",
                  bpm: 54, count: false, pass: 0.75, total: 8),
            R.tap("Fours and fives", "Sixteenths (4 per beat) then a quintuplet (5 per beat): squeeze one more note in.",
                  "s s s s 5s 5s 5s 5s 5s q q | s s s s 5s 5s 5s 5s 5s h", bpm: 54, count: false, pass: 0.75),
            L.info("Sextuplets", """
            A **sextuplet** fits **six** even notes into one beat, marked with a **6**. Think of it as two triplets back to back (“1 la li & la li”) or three pairs.

            They are the usual way to write very fast rolling figures and arpeggios.
            """, glyph: "6", example: R.tapTask("Sextuplets", "", "q 6s 6s 6s 6s 6s 6s q q | 6s 6s 6s 6s 6s 6s q h", bpm: 56, count: false)),
            R.tap("One sextuplet", "Six even notes per click. Use alternating fingers or hands.", "q 6s 6s 6s 6s 6s 6s q q | q 6s 6s 6s 6s 6s 6s h",
                  bpm: 54, count: false, pass: 0.75),
            R.tap("Three, four, five, six", "A “rhythm pyramid”: each beat holds one more note than the last.",
                  "3e 3e 3e s s s s 5s 5s 5s 5s 5s 6s 6s 6s 6s 6s 6s | w", bpm: 52, count: false, pass: 0.7),
        ])

        let swing = lesson("rhythm.feel.swing", "Swing vs. straight eighths", "Long-short eighths: the sound of jazz and blues.", [
            L.info("Straight and swung", """
            **Straight eighths** split the beat exactly in half — everything you have played so far.

            **Swing eighths** are uneven: the first of each pair is **long**, the second **short**, roughly like the first and last notes of a triplet (“**doo**-ba, **doo**-ba”). The music is still *written* as plain eighths, with “Swing” marked at the top.

            The off-beat note is short but often slightly accented, which gives swing its forward lean. At faster tempos the ratio evens out.

            Listen: one bar straight, one bar swung.
            """, example: R.tapTask("Straight then swung", "", "e e e e e e e e | 3q 3e 3q 3e 3q 3e 3q 3e | w", bpm: 96, count: false)),
            R.tap("Straight eighths", "First, perfectly even pairs.", "e e e e e e e e | e e e e q q", bpm: 92, count: false),
            R.tap("Swing eighths", "Now long-short. Think of a triplet with the middle note missing.", "3q 3e 3q 3e 3q 3e 3q 3e | 3q 3e 3q 3e q q", bpm: 92, count: false),
            R.tap("Swing with quarters", "Quarter notes stay on the click; only the eighths swing.", "q 3q 3e q 3q 3e | 3q 3e q 3q 3e q | 3q 3e 3q 3e 3q 3e q | w", bpm: 100, count: false),
            R.tune("Swing line", "A bluesy line with swung eighths.", "C4:3q E4:3e G4:3q A4:3e Bb4:3q A4:3e G4:3q E4:3e | C4:q E4:3q G4:3e C5:h",
                   bpm: 96, flats: true),
            R.tap("Back to straight", "Switching feels on demand: one bar swung, one bar straight, twice.",
                  "3q 3e 3q 3e 3q 3e 3q 3e | e e e e e e e e | 3q 3e 3q 3e 3q 3e 3q 3e | e e e e h", bpm: 92, count: false, pass: 0.75),
        ])
        return unit("rhythm.feel", "Syncopation, Tuplets & Swing", [syncopation, triplets, duplets, bigTuplets, swing])
    }

    // MARK: 6. Polyrhythms

    fileprivate static var rhythmPoly: CurriculumUnit {
        let twoThree = lesson("rhythm.poly.two-three", "2 against 3", "Two even notes in one hand against three in the other.", [
            L.info("Polyrhythm", """
            A **polyrhythm** is two different even divisions of the same span of time played together. The first to learn is **2 against 3**.

            Take one bar of 3/4. The right hand plays **three** quarter notes. The left hand plays **two** evenly spaced notes in the same bar (dotted quarters).

            Count the bar in six eighths, “1 & 2 & 3 &”:

            - **1** — both hands together
            - **2** — right
            - **& of 2** — left
            - **3** — right

            The combined rhythm sounds like “**nice** cup **of** tea” (together, right, left, right).
            """, example: L.timedTask("2 against 3", "", R.poly(right: "q q q", left: "q. q.", bar: 3, times: 4), bpm: 96, meter: (3, 4), display: .rhythm)),
            L.timed("Right hand: three", "Right hand alone on G: three even notes per bar.",
                    L.loop(L.rhythm("q q q", note: 67, hand: .right), times: 4, length: 3), bpm: 88, meter: (3, 4), display: .rhythm),
            L.timed("Left hand: two", "Left hand alone on C: two even notes per bar — on beat 1 and on the “&” of 2.",
                    L.loop(L.rhythm("q. q.", note: 48, hand: .left, count: false), times: 4, length: 3), bpm: 88, meter: (3, 4), display: .rhythm),
            L.timed("Together, slowly", "“Nice cup of tea”: together – right – left – right. Top lane is the right hand, bottom lane the left.",
                    R.poly(right: "q q q", left: "q. q.", bar: 3, times: 4), bpm: 66, meter: (3, 4), display: .rhythm, pass: 0.75),
            L.timed("2 against 3 at tempo", "Let each hand flow evenly rather than thinking of the composite.",
                    R.poly(right: "q q q", left: "q. q.", bar: 3, times: 6), bpm: 92, meter: (3, 4), display: .rhythm, pass: 0.75),
            L.timed("Swap hands", "Now the left hand plays three and the right plays two.",
                    L.loop(L.together(L.rhythm("q. q.", note: 67, hand: .right, count: false), L.rhythm("q q q", note: 48, hand: .left, count: false)),
                           times: 4, length: 3), bpm: 80, meter: (3, 4), display: .rhythm, pass: 0.75),
        ])

        let threeFour = lesson("rhythm.poly.three-four", "3 against 4", "Three even notes against four.", [
            L.info("3 against 4", """
            Now a bar of 4/4: the right hand plays **four** quarter notes while the left plays **three** evenly spaced notes (a half-note triplet).

            The two hands only meet on beat 1. The exact grid has twelve slots per bar; the composite rhythm fits the phrase “**pass** the **gold**-en **but**-ter”:

            - **pass** — together
            - the — right
            - **gold** — left
            - en — right
            - **but** — left
            - ter — right

            Learn the sound of the composite first, then let each hand smooth out.
            """, example: L.timedTask("3 against 4", "", R.poly(right: "q q q q", left: "3h 3h 3h", bar: 4, times: 4), bpm: 92, display: .rhythm)),
            L.timed("Left hand: three in a bar", "Left hand alone: three even notes across four clicks. Only the first lands on a click.",
                    L.loop(L.rhythm("3h 3h 3h", note: 48, hand: .left, count: false), times: 4, length: 4), bpm: 88, display: .rhythm, pass: 0.75),
            L.timed("Together, slowly", "“Pass the golden butter.” Right hand follows the clicks; left hand floats in threes.",
                    R.poly(right: "q q q q", left: "3h 3h 3h", bar: 4, times: 4), bpm: 63, display: .rhythm, pass: 0.7, toleranceMs: 120),
            L.timed("3 against 4 at tempo", "Keep both lines even.",
                    R.poly(right: "q q q q", left: "3h 3h 3h", bar: 4, times: 4), bpm: 88, display: .rhythm, pass: 0.7),
            L.timed("Swap hands", "Left hand plays the four, right hand the three.",
                    L.loop(L.together(L.rhythm("3h 3h 3h", note: 67, hand: .right, count: false), L.rhythm("q q q q", note: 48, hand: .left, count: false)),
                           times: 4, length: 4), bpm: 76, display: .rhythm, pass: 0.7),
        ])
        return unit("rhythm.poly", "Polyrhythms", [twoThree, threeFour])
    }

    // MARK: 7. Tempo and expressive timing

    fileprivate static var rhythmTempo: CurriculumUnit {
        let melody = "C4:q E4:q G4:q E4:q | F4:q A4:q G4:h | E4:q G4:q C5:q G4:q | E4:q D4:q C4:h"
        let markings = lesson("rhythm.tempo.markings", "Tempo markings", "Italian tempo words from Largo to Presto.", [
            L.info("Tempo words", """
            Before metronomes, composers described speed with Italian words, still used today. Approximate ranges:

            - **Largo** — very slow and broad (40–60 BPM)
            - **Adagio** — slow, at ease (60–76)
            - **Andante** — walking pace (76–108)
            - **Moderato** — moderate (108–120)
            - **Allegro** — fast, lively (120–156)
            - **Vivace** — very lively (156–176)
            - **Presto** — very fast (168–200)

            These describe **character** as much as speed. A metronome mark such as ♩ = 120 gives an exact figure: 120 quarter notes per minute.

            You will play the same melody at five different tempos.
            """, glyph: "♩ = 120"),
            R.tune("Largo", "♩ = 50. Very slow: the hard part is not rushing. Feel the space between clicks.", melody, bpm: 50),
            R.tune("Adagio", "♩ = 69. Slow and calm.", melody, bpm: 69),
            R.tune("Andante", "♩ = 88. An easy walking pace.", melody, bpm: 88),
            R.tune("Moderato", "♩ = 112.", melody, bpm: 112),
            R.tune("Allegro", "♩ = 132. Fast and bright — keep the fingers close to the keys.", melody, bpm: 132),
            R.tune("Presto", "♩ = 172. Very fast. Stay loose; if it falls apart, lower the tempo with the − button and work back up.", melody, bpm: 172, pass: 0.75),
        ])

        let changes = lesson("rhythm.tempo.accel-rit", "Accelerando and ritardando", "Speeding up and slowing down gradually.", [
            L.info("Changing tempo", """
            - **Accelerando** (*accel.*) — gradually get **faster**.
            - **Ritardando** (*rit.*) or **rallentando** (*rall.*) — gradually get **slower**. Very common at the end of a piece.
            - **A tempo** — return to the original speed.

            The change should be smooth, like a car accelerating, not a sudden gear shift. In these exercises the metronome itself speeds up or slows down — follow it.
            """, glyph: "rit.", example: R.tapTask("Ritardando", "", "q q q q | q q q q | q q q q | w", bpm: 120, tempoEnd: 56)),
            R.tap("Accelerando", "The clicks speed up from 70 to 120. Stay with them — don't jump ahead.",
                  "q q q q | q q q q | q q q q | q q q q", bpm: 70, tol: 120, tempoEnd: 120),
            R.tap("Ritardando", "The clicks slow from 116 to 60. Each gap is a little longer than the last.",
                  "q q q q | q q q q | q q q q | q q q q", bpm: 116, tol: 120, tempoEnd: 60),
            R.tune("Accelerando with eighths", "A scale that gathers speed.", "C4:e D4:e E4:e F4:e G4:e F4:e E4:e D4:e | C4:e D4:e E4:e F4:e G4:e F4:e E4:e D4:e | C4:w",
                   bpm: 66, tol: 120, tempoEnd: 104),
            R.tune("Ritardando ending", "Slow down into the final note, as you would at the end of a piece.", "G4:q E4:q C4:q E4:q | G4:q F4:q E4:q D4:q | C4:w",
                   bpm: 108, tol: 130, tempoEnd: 54),
        ])

        let fermata = lesson("rhythm.tempo.fermata", "Fermata", "Holding a note beyond its written length.", [
            L.info("The fermata", """
            A **fermata** (“pause” or “bird's eye”) is an arc with a dot, placed over a note or rest. It means: **stop the pulse and hold** for longer than the written value — how long is up to you, often about twice as long.

            Counting stops during a fermata. Afterwards the beat starts again at the original tempo.

            Fermatas often follow a ritardando at the end of a phrase. Listen to the example: the pulse slows, the high note is held, then the phrase finishes.
            """, glyph: "𝄐", example: L.task("Fermata", "", R.free("C4 E4 G4 C5 G4 E4 C4", [1, 1, 1.15, 4, 1, 1, 3]))),
            L.play("Hold the fermata", """
            This step is untimed, so you control the pulse. Play C–E–G steadily, **hold the high C** for a long, calm fermata, then finish the phrase in tempo. Connect the notes smoothly.
            """, L.line("C4 E4 G4 C5 G4 E4 C4", fingers: "1 2 3 5 3 2 1"), display: .staff, rules: [.legato]),
            R.tune("Slow into the final hold", "A ritardando into a long last note. Hold the final C until the bar ends.",
                   "E4:q G4:q C5:q G4:q | E4:q D4:q C4:h~h r:h", bpm: 100, tol: 130, total: 12, tempoEnd: 56),
        ])

        let rubato = lesson("rhythm.tempo.rubato", "Rubato and expressive timing", "Bending time for expression.", [
            L.info("Tempo rubato", """
            **Rubato** means “robbed time”: subtly stretching some notes and hurrying others to shape a phrase, the way a good speaker varies their pace. It is central to Romantic music such as Chopin.

            Typical gestures:

            - **linger** on the most important note (often the highest) of a phrase
            - move forward gently towards it, relax away from it
            - take a little time at the end of a phrase, like breathing

            Rubato only works if you could also play it strictly. Time that is taken should be given back, so the overall pulse survives.

            Listen to the phrase played strictly in time.
            """, example: L.task("Strict", "", R.free("E4 G4 C5 E5 D5 C5 G4 E4 C4", [1, 1, 1, 1, 1, 1, 1, 1, 2]))),
            L.info("The same phrase with rubato", """
            Now with rubato: it moves ahead slightly on the way up, lingers on the top note, and relaxes at the end. No note is “wrong” — the timing is shaped.
            """, example: L.task("Rubato", "", R.free("E4 G4 C5 E5 D5 C5 G4 E4 C4", [1.05, 0.9, 0.85, 1.7, 1.0, 0.95, 1.05, 1.3, 3]))),
            R.tune("First, strictly", "Play the phrase exactly in time with the metronome. Rubato is built on this.",
                   "E4:q G4:q C5:q E5:q | D5:q C5:q G4:q E4:q | C4:w", bpm: 80),
            L.play("Now with your own rubato", """
            Untimed: no metronome and no timing score. Shape the phrase — lean towards the high E, linger on it, and take time at the end. Keep it **legato**; only the notes and the smooth connection are checked.

            Try it several ways with Restart and listen to how the character changes.
            """, L.line("E4 G4 C5 E5 D5 C5 G4 E4 C4", fingers: "1 2 3 5 4 3 2 1 1"), display: .staff, showFingers: false, rules: [.legato]),
            R.tune("Hold the tempo yourself", "The metronome only counts you in. Keep a steady inner pulse — the foundation that makes rubato sound intentional.",
                   "E4:q G4:q C5:q E5:q | D5:q C5:q G4:q E4:q | C4:w", bpm: 80, metronome: .countInOnly, tol: 140),
        ])
        return unit("rhythm.tempo", "Tempo & Expressive Timing", [markings, changes, fermata, rubato])
    }

    // MARK: 8. Odd and mixed meters

    fileprivate static var rhythmOdd: CurriculumUnit {
        let fiveFour = lesson("rhythm.odd.five-four", "5/4", "Five beats per bar, felt as 3+2 or 2+3.", [
            L.info("Odd meters", """
            **Odd** (or asymmetric) meters have bars that can't be split into equal groups. You count them as a mix of **twos and threes**.

            **5/4** has five quarter-note beats, usually grouped **3 + 2** (“**1** 2 3 **4** 5”) or **2 + 3** (“**1** 2 **3** 4 5”). Famous examples: “Take Five” and the *Mission: Impossible* theme.

            Here the higher click marks the start of each group.
            """, glyph: "5/4", example: R.tapTask("5/4 as 3+2", "", "q> q q q> q | q> q q q> q", bpm: 120, meter: (5, 4), accentBeats: [0, 3])),
            R.tap("5/4 as 3 + 2", "Count **1** 2 3 **4** 5.", "q q q q q | q q q q q | h. h | h. h", bpm: 108, meter: (5, 4), accentBeats: [0, 3]),
            R.tap("5/4 as 2 + 3", "Same bar length, other grouping: **1** 2 **3** 4 5.", "q q q q q | q q q q q | h h. | h h.", bpm: 108, meter: (5, 4), accentBeats: [0, 2]),
            R.tap("Five-beat groove", "Two dotted quarters then two quarters (3+2).", "q. q. q q | q. q. q q | q. q. q q | h. h", bpm: 112, meter: (5, 4), accentBeats: [0, 3], pass: 0.75),
            R.tune("5/4 melody", "A tune in five.", "C4:q E4:q G4:q F4:q D4:q | C4:q E4:q G4:q A4:h | G4:q E4:q C4:q D4:q B3:q | C4:h. r:h",
                   bpm: 104, meter: (5, 4), accentBeats: [0, 3]),
        ])

        let sevenEight = lesson("rhythm.odd.seven-eight", "7/8", "Seven quick eighths in groups of 2 and 3.", [
            L.info("7/8", """
            **7/8** has seven eighth notes per bar, grouped as two 2s and one 3. The common shapes:

            - **2 + 2 + 3** — “**1** 2 **1** 2 **1** 2 3”
            - **3 + 2 + 2** — “**1** 2 3 **1** 2 **1** 2”

            The bar feels like three beats, one of them longer — a limping, dancing rhythm heard all over Balkan folk music and progressive rock.

            Count the small groups (“1-2, 1-2, 1-2-3”) rather than up to seven.
            """, glyph: "7/8", example: R.tapTask("7/8", "", "e> e e> e e> e e | q q q.", bpm: 190, meter: (7, 8), unit: 8, accentBeats: [0, 2, 4], count: false)),
            R.tap("Every eighth (2+2+3)", "Higher clicks mark the groups. Count “1-2, 1-2, 1-2-3”.", "e e e e e e e | e e e e e e e | q q q. | q q q.",
                  bpm: 168, meter: (7, 8), unit: 8, accentBeats: [0, 2, 4], count: false),
            R.tap("Just the three beats", "Short – short – long.", "q q q. | q q q. | q q q. | q q q.", bpm: 180, meter: (7, 8), unit: 8, accentBeats: [0, 2, 4], count: false),
            R.tap("3 + 2 + 2", "Now the long beat comes first: long – short – short.", "q. q q | q. q q | e e e q q | q. q q",
                  bpm: 176, meter: (7, 8), unit: 8, accentBeats: [0, 3, 5], count: false),
            R.tune("7/8 tune", "Grouped 2+2+3.", "C4:q E4:q G4:e F4:e E4:e | D4:q F4:q A4:q. | G4:q E4:q C4:e D4:e E4:e | C4:q C4:q C4:q.",
                   bpm: 168, meter: (7, 8), unit: 8, accentBeats: [0, 2, 4], pass: 0.75),
        ])

        let mixed = lesson("rhythm.odd.mixed", "Mixed meters", "When the time signature changes from bar to bar.", [
            L.info("Changing meters", """
            In **mixed meter** the time signature changes during the piece — a new signature simply appears after a bar line and applies until the next change. Stravinsky and Bartók, film scores and musical theatre use it constantly.

            The rule that keeps you safe: **the small note value stays the same speed**. An eighth note in a 3/4 bar is as long as an eighth in a 6/8 bar; only the grouping changes.

            This app draws one repeating bar, so each exercise below shows a **pair** of bars joined into one long bar, with the higher click marking each group.
            """),
            L.info("4/4 + 3/4", """
            Alternating a bar of **4/4** with a bar of **3/4** makes a seven-beat cycle: “**1** 2 3 4 | **1** 2 3”. The quarter-note pulse never changes; the downbeat just arrives a beat sooner every other bar.
            """, example: R.tapTask("4/4 + 3/4", "", "q> q q q q> q q | q> q q q q> q q", bpm: 120, meter: (7, 4), accentBeats: [0, 4])),
            R.tap("4/4 + 3/4", "Count “1 2 3 4, 1 2 3”. The higher click starts each bar.", "q q q q q q q | h h h. | q q q q q q q | w h.",
                  bpm: 108, meter: (7, 4), accentBeats: [0, 4]),
            L.info("6/8 + 3/4 (hemiola)", """
            A favourite trick: alternate **6/8** (two beats of three eighths) with **3/4** (three beats of two eighths). Both bars hold six eighths, so the eighth stays constant while the accent shifts: “**1** 2 3 **4** 5 6 | **1** 2 **3** 4 **5** 6”.

            This two-against-three regrouping is called a **hemiola**. It drives a lot of Latin American and Spanish music.
            """, example: R.tapTask("6/8 + 3/4", "", "q. q. q q q | q. q. q q q", bpm: 200, meter: (12, 8), unit: 8, accentBeats: [0, 3, 6, 8, 10], count: false)),
            R.tap("6/8 + 3/4: every eighth", "Twelve eighths per cycle: 3 + 3, then 2 + 2 + 2. Lean on the first note of each group.",
                  "e> e e e> e e e> e e> e e> e | e> e e e> e e e> e e> e e> e", bpm: 168, meter: (12, 8), unit: 8,
                  accentBeats: [0, 3, 6, 8, 10], count: false, pass: 0.75),
            R.tap("6/8 + 3/4: the beats", "Two long beats, then three short ones.", "q. q. q q q | q. q. q q q | q. q. q q q | h. h.",
                  bpm: 184, meter: (12, 8), unit: 8, accentBeats: [0, 3, 6, 8, 10], count: false, pass: 0.75),
        ])
        return unit("rhythm.odd", "Odd & Mixed Meters", [fiveFour, sevenEight, mixed])
    }

    // MARK: 9. Timing lab (MIDI-measured skills)

    fileprivate static var rhythmLab: CurriculumUnit {
        let precision = lesson("rhythm.lab.precision", "Onset precision", "How close to the click can you land, in milliseconds?", [
            L.info("Measuring your timing", """
            Your keyboard reports the moment of every key press, so the app can measure exactly how far each note lands from the beat.

            - **Timing ±ms** — your average distance from the beat. Under 25 ms is excellent; under 45 ms is good.
            - **Early / late** — a consistent bias means you rush or drag.
            - **Steadiness** — the spread of your errors. A small spread with a bias is easy to fix; a large spread means the pulse isn't internalised yet.

            These drills have much **tighter tolerances** than normal lessons. If results always read late even when you feel accurate, check *Settings → Latency compensation* (Bluetooth headphones add delay).
            """),
            R.tap("Quarter notes within 60 ms", "Sixteen quarter notes. Average error must be under 60 ms.",
                  "q q q q | q q q q | q q q q | q q q q", bpm: 80, tol: 60, pass: 0.9),
            R.tap("Quarter notes within 40 ms", "Same again — tighter. Listen for your note and the click fusing into one sound.",
                  "q q q q | q q q q | q q q q | q q q q", bpm: 90, tol: 40, pass: 0.9),
            R.tap("Eighth notes within 45 ms", "The off-beats have no click to hide behind.",
                  "e e e e e e e e | e e e e e e e e | e e e e e e e e | e e e e h", bpm: 80, tol: 45, pass: 0.9),
            R.tap("Slow is harder", "At 48 BPM the gaps are long and rushing is tempting. Stay within 50 ms.",
                  "q q q q | q q q q | q q q q", bpm: 48, tol: 50, pass: 0.9),
            R.tap("Sixteenths within 40 ms", "Even fast notes can be precise.", "s s s s q s s s s q | s s s s s s s s h | s s s s q s s s s q | w",
                  bpm: 66, tol: 40, pass: 0.85),
        ])

        let stability = lesson("rhythm.lab.stability", "Tempo stability", "Keep the pulse when the metronome goes silent.", [
            L.info("Your inner metronome", """
            Playing *with* a click is one skill; **holding** a tempo alone is another. In these drills the metronome only counts you in and then stops. The app keeps timing against the silent beat.

            - If you finish **early**, you rushed; **late**, you dragged. The bias in your result tells you which.
            - Count subdivisions in your head (“1 & 2 &”) — smaller units drift less.
            - Most people rush fast, easy passages and drag slow or difficult ones.
            """),
            R.tap("Eight beats alone", "Count-in only, then keep 80 BPM for two bars.", "q q q q | q q q q", bpm: 80, metronome: .countInOnly, tol: 90),
            R.tap("Sixteen beats alone", "Four bars. Any drift now adds up.", "q q q q | q q q q | q q q q | q q q q", bpm: 80, metronome: .countInOnly, tol: 100),
            R.tap("Slow and silent", "60 BPM without a click: think “1 & 2 &” to fill the gaps.", "q q q q | q q q q | q q q q | q q q q", bpm: 60, metronome: .countInOnly, tol: 110),
            R.tap("Hold tempo through long notes", "Long notes and rests are where the pulse wanders. Keep counting.",
                  "q q h | h q q | q rq q rq | w | q q q q", bpm: 84, metronome: .countInOnly, tol: 110),
            R.tap("Eighths without a click", "Running eighths tend to speed up. Stay at 84.", "e e e e e e e e | e e e e q q | e e e e e e e e | e e e e h",
                  bpm: 84, metronome: .countInOnly, tol: 100),
            R.tune("A tune on your own pulse", "Count-in only, on the keys.", "C4:q E4:q G4:q E4:q | F4:e G4:e A4:q G4:h | E4:q G4:q C5:e B4:e A4:q | G4:q E4:q C4:h",
                   bpm: 84, metronome: .countInOnly, tol: 110),
        ])

        let patterns = lesson("rhythm.lab.patterns", "Rhythm pattern challenges", "Mixed patterns scored for accuracy.", [
            L.info("Putting it together", """
            Each challenge mixes several things you have learned. To pass you need **90% of the notes** in the right place, with few extra notes.

            Before pressing Start: scan the pattern, find the hardest beat, and count it through once in your head. Use the **Demo** button to hear it, and lower the tempo if you need to — then work back up.
            """),
            R.tap("Challenge 1: quarters, eighths, rests", "", "q e e rq q | e e q q rq | re e q e e q | h rq q", bpm: 84, pass: 0.9),
            R.tap("Challenge 2: dots and ties", "", "q. e q q | q e e~q q | q. e e e q | h. rq", bpm: 84, pass: 0.9),
            R.tap("Challenge 3: sixteenths", "", "e s s q s s e q | s s s s e e e. s q | e s s s s e q rq | w", bpm: 66, pass: 0.9),
            R.tap("Challenge 4: syncopation", "", "e q e e q e | re e re e q q | e q e q e e | h h", bpm: 84, pass: 0.9),
            R.tap("Challenge 5: triplets and duples", "", "e e 3e 3e 3e q e e | 3e 3e 3e e e 3q 3q 3q | q 3e 3e 3e h", bpm: 72, count: false, pass: 0.9),
            R.tap("Challenge 6: 6/8", "", "q e q e | e e e q. | q e e e e | q. q.", bpm: 150, meter: (6, 8), unit: 8, accentBeats: [0, 3], pass: 0.9),
            R.tap("Challenge 7: swing", "", "3q 3e q 3q 3e q | r3q 3e~q 3q 3e q | 3q 3e 3q 3e 3q 3e q | w", bpm: 100, count: false, pass: 0.85),
            R.tune("Challenge 8: everything, on the keys", "", "C4:q. E4:e G4:e G4:e r:e E4:e | F4:s G4:s A4:e G4:q E4:3e D4:3e E4:3e C4:q | D4:e F4:q E4:e~q D4:q | C4:w",
                   bpm: 72, pass: 0.85),
        ])
        return unit("rhythm.lab", "Timing Lab", [precision, stability, patterns])
    }
}
