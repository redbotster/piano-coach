import Foundation

/// Small DSL used by the curriculum files to describe lessons compactly.
///
/// Rhythm tokens: `w h q e s t` = whole, half, quarter, eighth, sixteenth, thirty-second.
///   - suffix `.` dots the value (`q.`), prefix `r` makes it a rest (`rq`)
///   - prefix `3` / `5` / `6` / `2` makes a triplet / quintuplet / sextuplet / duplet member (`3e`)
///   - `~` ties values into one note (`h~e`), suffix `>` accents, suffix `'` marks staccato
/// Melody tokens: `C4:q`, `E4+G4:h` (chord), `r:q` (rest), optional finger `C4:q:1`.
enum L {
    // MARK: Parsing

    struct Dur {
        var beats: Double
        var rest = false
        var accent = false
        var staccato = false
    }

    /// `unit` is the note value that gets one beat (4 = quarter, 8 = eighth, 2 = half).
    static func dur(_ token: String, unit: Int = 4) -> Dur {
        var t = token
        var d = Dur(beats: 0)
        if t.hasSuffix(">") { d.accent = true; t.removeLast() }
        if t.hasSuffix("'") { d.staccato = true; t.removeLast() }
        if t.hasPrefix("r") { d.rest = true; t.removeFirst() }
        for part in t.split(separator: "~") {
            var p = String(part)
            var scale = 1.0
            if let first = p.first, let n = Int(String(first)) {
                switch n {
                case 3: scale = 2.0 / 3.0
                case 5: scale = 4.0 / 5.0
                case 6: scale = 4.0 / 6.0
                case 2: scale = 3.0 / 2.0
                case 7: scale = 4.0 / 7.0
                default: scale = 1
                }
                p.removeFirst()
            }
            var dotted = 1.0
            while p.hasSuffix(".") { dotted = dotted == 1.0 ? 1.5 : 1.75; p.removeLast() }
            let base: Double
            switch p {
            case "w": base = 4
            case "h": base = 2
            case "q": base = 1
            case "e": base = 0.5
            case "s": base = 0.25
            case "t": base = 0.125
            default: base = Double(p) ?? 1
            }
            d.beats += base * dotted * scale
        }
        d.beats *= Double(unit) / 4.0
        return d
    }

    static func fingerList(_ text: String?) -> [Int]? {
        guard let text else { return nil }
        return text.split(separator: " ").compactMap { Int($0) }
    }

    /// Counting syllable for a beat position ("1 e & a", or "1 la li" for thirds).
    static func countLabel(_ beat: Double, beatsPerBar: Int) -> String {
        let whole = Int(floor(beat + 1e-6))
        let frac = beat - Double(whole)
        let number = "\(whole % max(1, beatsPerBar) + 1)"
        func near(_ x: Double) -> Bool { abs(frac - x) < 0.02 }
        if near(0) || near(1) { return number }
        if near(0.5) { return "&" }
        if near(0.25) { return "e" }
        if near(0.75) { return "a" }
        if near(1.0 / 3.0) { return "la" }
        if near(2.0 / 3.0) { return "li" }
        return "·"
    }

    // MARK: Event builders

    /// A rhythm on one pitch (or on any key when `note` is nil).
    static func rhythm(_ pattern: String, note: Int? = nil, hand: Hand = .right, unit: Int = 4,
                       count: Bool = true, beatsPerBar: Int = 4, start: Double = 0) -> [ExpectedEvent] {
        var beat = start
        var out: [ExpectedEvent] = []
        for token in pattern.split(separator: " ") where token != "|" {
            let d = dur(String(token), unit: unit)
            if !d.rest {
                var e = ExpectedEvent(notes: note.map { [NoteSpec(midi: $0, hand: hand)] } ?? [],
                                      beat: beat, duration: d.beats)
                e.accent = d.accent
                if d.staccato { e.articulation = .staccato }
                if count { e.label = countLabel(beat, beatsPerBar: beatsPerBar) }
                out.append(e)
            }
            beat += d.beats
        }
        return out
    }

    /// A pitched line with rhythm: "C4:q D4:q E4+G4:h r:q".
    static func melody(_ spec: String, hand: Hand = .right, unit: Int = 4, start: Double = 0) -> [ExpectedEvent] {
        var beat = start
        var out: [ExpectedEvent] = []
        for token in spec.split(separator: " ") where token != "|" {
            let parts = token.split(separator: ":").map(String.init)
            guard parts.count >= 2 else { continue }
            let d = dur(parts[1], unit: unit)
            if parts[0] != "r" && !d.rest {
                let fingers = parts.count > 2 ? parts[2].split(separator: "-").compactMap { Int($0) } : []
                let names = parts[0].split(separator: "+")
                var specs: [NoteSpec] = []
                for (i, name) in names.enumerated() {
                    specs.append(NoteSpec(midi: Music.midi(String(name)), hand: hand,
                                          finger: i < fingers.count ? fingers[i] : nil))
                }
                var e = ExpectedEvent(notes: specs, beat: beat, duration: d.beats)
                e.accent = d.accent
                if d.staccato { e.articulation = .staccato }
                out.append(e)
            }
            beat += d.beats
        }
        return out
    }

    /// One note per event, evenly spaced.
    static func line(_ notes: [Int], hand: Hand = .right, fingers: [Int]? = nil,
                     duration: Double = 1, start: Double = 0) -> [ExpectedEvent] {
        notes.enumerated().map { i, n in
            let f = fingers.flatMap { i < $0.count ? $0[i] : nil }
            return ExpectedEvent(notes: [NoteSpec(midi: n, hand: hand, finger: f)],
                                 beat: start + Double(i) * duration, duration: duration)
        }
    }

    static func line(_ names: String, hand: Hand = .right, fingers: String? = nil,
                     duration: Double = 1, start: Double = 0) -> [ExpectedEvent] {
        line(Music.notes(names), hand: hand, fingers: fingerList(fingers), duration: duration, start: start)
    }

    /// One chord per event, evenly spaced.
    static func chords(_ groups: [[Int]], hand: Hand = .right, fingers: [[Int]]? = nil,
                       duration: Double = 1, start: Double = 0, labels: [String]? = nil) -> [ExpectedEvent] {
        groups.enumerated().map { i, group in
            let specs = group.enumerated().map { j, n -> NoteSpec in
                let f = fingers.flatMap { i < $0.count && j < $0[i].count ? $0[i][j] : nil }
                return NoteSpec(midi: n, hand: hand, finger: f)
            }
            var e = ExpectedEvent(notes: specs, beat: start + Double(i) * duration, duration: duration)
            e.label = labels.flatMap { i < $0.count ? $0[i] : nil }
            return e
        }
    }

    /// Chords from note-name groups separated by commas: "C4 E4 G4, F4 A4 C5".
    static func chords(_ names: String, hand: Hand = .right, duration: Double = 1, start: Double = 0) -> [ExpectedEvent] {
        chords(names.split(separator: ",").map { Music.notes(String($0)) }, hand: hand, duration: duration, start: start)
    }

    /// Combine two parts (usually the two hands). Events on the same beat become one event.
    static func together(_ a: [ExpectedEvent], _ b: [ExpectedEvent]) -> [ExpectedEvent] {
        func stamped(_ events: [ExpectedEvent]) -> [ExpectedEvent] {
            events.map { event in
                var e = event
                e.notes = e.notes.map { var n = $0; n.duration = n.duration ?? event.duration; return n }
                return e
            }
        }
        var out = stamped(a)
        for e in stamped(b) {
            if let i = out.firstIndex(where: { abs($0.beat - e.beat) < 1e-4 }) {
                out[i].notes += e.notes
                out[i].duration = min(out[i].duration, e.duration)
                out[i].accent = out[i].accent || e.accent
            } else {
                out.append(e)
            }
        }
        return out.sorted { $0.beat < $1.beat }
    }

    /// Repeat a group of events `times` times, spaced `length` beats apart.
    static func loop(_ events: [ExpectedEvent], times: Int, length: Double) -> [ExpectedEvent] {
        var out: [ExpectedEvent] = []
        for t in 0..<times {
            out += events.map { var e = $0; e.beat += Double(t) * length; return e }
        }
        return out
    }

    static func keys(_ names: String, labels: Bool = true, hand: Hand = .either, flats: Bool = false) -> [KeyHighlight] {
        Music.notes(names).map {
            KeyHighlight(midi: $0, label: labels ? Music.name($0, flats: flats, octave: false) : nil, hand: hand)
        }
    }

    static func keys(_ notes: [Int], labels: [String]? = nil, hand: Hand = .either) -> [KeyHighlight] {
        notes.enumerated().map { i, n in
            KeyHighlight(midi: n, label: labels.flatMap { i < $0.count ? $0[i] : nil }, hand: hand)
        }
    }

    // MARK: Step builders

    static func info(_ title: String, _ body: String, glyph: String? = nil, keys: [KeyHighlight] = [],
                     example: PlayTask? = nil, links: [WebLink] = []) -> Step {
        .info(InfoStep(title: title, body: body, glyph: glyph, keys: keys, example: example, links: links))
    }

    static func checklist(_ title: String, _ body: String, items: [String], links: [WebLink] = []) -> Step {
        .checklist(ChecklistStep(title: title, body: body, items: items, links: links))
    }

    /// Untimed task: the app waits for each note.
    static func play(_ title: String, _ instructions: String, _ events: [ExpectedEvent],
                     display: DisplayMode = .keyboard, clef: ClefMode = .auto, key: Int = 0, flats: Bool = false,
                     showTargets: Bool = true, showFingers: Bool = true, anyOctave: Bool = false,
                     rules: [Rule] = [], pass: Double = 0.8) -> Step {
        .play(task(title, instructions, events, display: display, clef: clef, key: key, flats: flats,
                   showTargets: showTargets, showFingers: showFingers, anyOctave: anyOctave, rules: rules, pass: pass))
    }

    static func task(_ title: String, _ instructions: String, _ events: [ExpectedEvent],
                     display: DisplayMode = .keyboard, clef: ClefMode = .auto, key: Int = 0, flats: Bool = false,
                     showTargets: Bool = true, showFingers: Bool = true, anyOctave: Bool = false,
                     rules: [Rule] = [], pass: Double = 0.8) -> PlayTask {
        PlayTask(title: title, instructions: instructions, events: events, timing: .untimed, display: display,
                 clef: clef, keySignature: key, preferFlats: flats || key < 0, showTargets: showTargets,
                 showFingers: showFingers, anyOctave: anyOctave, rules: rules, passAccuracy: pass)
    }

    /// Timed task: played against the metronome and scored for timing.
    static func timed(_ title: String, _ instructions: String, _ events: [ExpectedEvent],
                      bpm: Double = 80, meter: (Int, Int) = (4, 4), countIn: Int? = nil,
                      metronome: MetronomeMode = .on, tempoEnd: Double? = nil, accentBeats: [Int] = [0],
                      totalBeats: Double? = nil,
                      display: DisplayMode = .rhythm, clef: ClefMode = .auto, key: Int = 0, flats: Bool = false,
                      showTargets: Bool = true, showFingers: Bool = true, anyOctave: Bool = false,
                      rules: [Rule] = [], pass: Double = 0.8, toleranceMs: Double = 110) -> Step {
        .play(timedTask(title, instructions, events, bpm: bpm, meter: meter, countIn: countIn,
                        metronome: metronome, tempoEnd: tempoEnd, accentBeats: accentBeats, totalBeats: totalBeats,
                        display: display, clef: clef, key: key, flats: flats, showTargets: showTargets,
                        showFingers: showFingers, anyOctave: anyOctave, rules: rules, pass: pass,
                        toleranceMs: toleranceMs))
    }

    static func timedTask(_ title: String, _ instructions: String, _ events: [ExpectedEvent],
                          bpm: Double = 80, meter: (Int, Int) = (4, 4), countIn: Int? = nil,
                          metronome: MetronomeMode = .on, tempoEnd: Double? = nil, accentBeats: [Int] = [0],
                          totalBeats: Double? = nil,
                          display: DisplayMode = .rhythm, clef: ClefMode = .auto, key: Int = 0, flats: Bool = false,
                          showTargets: Bool = true, showFingers: Bool = true, anyOctave: Bool = false,
                          rules: [Rule] = [], pass: Double = 0.8, toleranceMs: Double = 110) -> PlayTask {
        let config = TimedConfig(bpm: bpm, beatsPerBar: meter.0, beatUnit: meter.1,
                                 countInBeats: countIn ?? meter.0, metronome: metronome, tempoEnd: tempoEnd,
                                 accentBeats: accentBeats, totalBeats: totalBeats)
        return PlayTask(title: title, instructions: instructions, events: events, timing: .timed(config),
                        display: display, clef: clef, keySignature: key, preferFlats: flats || key < 0,
                        showTargets: showTargets, showFingers: showFingers, anyOctave: anyOctave, rules: rules,
                        passAccuracy: pass, timingToleranceMs: toleranceMs)
    }

    static func quiz(_ title: String, _ instructions: String, rounds: Int = 10,
                     make: @escaping (Int) -> PlayTask) -> Step {
        .quiz(QuizStep(title: title, instructions: instructions, rounds: rounds, make: make))
    }

    // MARK: Common velocity windows

    static let pp = Rule.velocityRange(min: 1, max: 38, name: "pp")
    static let p = Rule.velocityRange(min: 25, max: 58, name: "p")
    static let mp = Rule.velocityRange(min: 45, max: 72, name: "mp")
    static let mf = Rule.velocityRange(min: 60, max: 90, name: "mf")
    static let f = Rule.velocityRange(min: 80, max: 112, name: "f")
    static let ff = Rule.velocityRange(min: 100, max: 127, name: "ff")
}

// MARK: - Staff spelling

struct SpelledNote {
    /// Diatonic position: octave * 7 + letter (C = 0). Middle C = 28.
    let step: Int
    /// Accidental to draw before the note, if it differs from the key signature.
    let accidental: String?
}

enum Spelling {
    private static let letterPC = [0, 2, 4, 5, 7, 9, 11]
    private static let sharpOrder = [3, 0, 4, 1, 5, 2, 6]
    private static let flatOrder = [6, 2, 5, 1, 4, 0, 3]

    /// Accidental (-1, 0, +1) applied to each letter C...B by a key signature.
    static func keyAccidentals(fifths: Int) -> [Int] {
        var acc = [Int](repeating: 0, count: 7)
        if fifths > 0 { for i in 0..<min(fifths, 7) { acc[sharpOrder[i]] = 1 } }
        if fifths < 0 { for i in 0..<min(-fifths, 7) { acc[flatOrder[i]] = -1 } }
        return acc
    }

    static func spell(_ midi: Int, fifths: Int, preferFlats: Bool) -> SpelledNote {
        let pc = Music.pc(midi)
        let keyAcc = keyAccidentals(fifths: fifths)
        func make(_ letter: Int, _ accidental: Int, show: String?) -> SpelledNote {
            let natural = midi - accidental
            let octave = natural / 12 - 1
            return SpelledNote(step: octave * 7 + letter, accidental: show)
        }
        // In the key: no accidental needed.
        for letter in 0..<7 where ((letterPC[letter] + keyAcc[letter]) % 12 + 12) % 12 == pc {
            return make(letter, keyAcc[letter], show: nil)
        }
        // A white key that the key signature alters: needs a natural sign.
        if let letter = letterPC.firstIndex(of: pc) {
            return make(letter, 0, show: "♮")
        }
        // Raised 4th and 5th degrees of the major key (the raised 6th and leading note of its relative
        // minor) are written as sharps even in flat keys: F♯ in G minor, C♯ in D minor.
        let tonic = ((fifths * 7) % 12 + 12) % 12
        let degree = (pc - tonic + 12) % 12
        let raised = fifths != 0 && (degree == 6 || degree == 8)
        if (preferFlats || fifths < 0) && !raised {
            let letter = letterPC.firstIndex(of: (pc + 1) % 12) ?? 0
            return make(letter, -1, show: "♭")
        }
        let letter = letterPC.firstIndex(of: (pc + 11) % 12) ?? 0
        return make(letter, 1, show: "♯")
    }
}
