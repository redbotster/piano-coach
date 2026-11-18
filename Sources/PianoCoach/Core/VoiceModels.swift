import Foundation

/// One note of a singing exercise, written relative to a tonic so it can be moved into any voice range.
struct SingNote {
    /// Semitones above the tonic ("do"); nil is a rest.
    var semitone: Int?
    var beats: Double = 1
    /// Text shown on the note: a solfège syllable, a lyric, or a vowel.
    var label: String? = nil
}

enum SingKind {
    /// Untimed: each note must be held in tune for `hold` seconds before the next one appears.
    case match(hold: Double)
    /// Notes scroll past at a tempo and are scored as they go by.
    case timed(bpm: Double)
    /// Unscored exploration (sirens, lip trills): passes after `seconds` of singing covering `span` semitones.
    case free(seconds: Double, span: Double)
    /// Finds the singer's lowest and highest comfortable notes.
    case range
    /// Sing along with an imported recording; the notes come from analysing it.
    case track
}

/// An imported recording and where its sound file is.
struct TrackRef {
    var track: VoiceTrack
    var audio: URL
}

struct SingTask {
    var title: String
    var instructions: String
    var notes: [SingNote] = []
    var kind: SingKind
    /// How far from the note still counts as in tune.
    var toleranceCents: Double = 50
    /// Fraction of notes that must be in tune to pass.
    var pass: Double = 0.6
    /// Repeat the pattern at each of these transpositions (semitones), as in a vocal warm-up.
    var shifts: [Int] = [0]
    /// Beats of rest between repetitions.
    var shiftGap: Double = 2
    /// Count the right note in any octave.
    var anyOctave: Bool = true
    /// Play the notes on the piano while singing (only when the singer wears headphones).
    var guide: Bool = true
    /// The recording to sing with, for `.track`.
    var track: TrackRef? = nil

    /// True when notes go by on a clock (a tempo or a recording).
    var isTimed: Bool {
        switch kind {
        case .timed, .track: return true
        default: return false
        }
    }

    /// The pattern with every repetition written out.
    var expanded: [SingNote] {
        var out: [SingNote] = []
        for (i, shift) in shifts.enumerated() {
            if i > 0, shiftGap > 0 { out.append(SingNote(semitone: nil, beats: shiftGap)) }
            out += notes.map { SingNote(semitone: $0.semitone.map { $0 + shift }, beats: $0.beats, label: $0.label) }
        }
        return out
    }

    /// Lowest and highest semitone used, relative to the tonic.
    var span: ClosedRange<Int> {
        let all = expanded.compactMap { $0.semitone }
        return (all.min() ?? 0)...(all.max() ?? 0)
    }
}

/// A singer's comfortable range, as MIDI note numbers.
struct VoiceRange: Codable, Equatable {
    var low: Int
    var high: Int

    static let presets: [(name: String, detail: String, range: VoiceRange)] = [
        ("Low", "bass / baritone", VoiceRange(low: 43, high: 62)),
        ("Medium-low", "tenor / low alto", VoiceRange(low: 48, high: 67)),
        ("Medium-high", "alto / mezzo", VoiceRange(low: 55, high: 74)),
        ("High", "soprano / child", VoiceRange(low: 60, high: 79)),
    ]
    static let standard = presets[1].range

    var name: String {
        Self.presets.first { $0.range == self }?.name ?? "\(Music.name(low))–\(Music.name(high))"
    }

    /// The tonic (MIDI) that places a pattern in the middle of this range.
    func tonic(for span: ClosedRange<Int>) -> Int {
        let centre = Double(low + high) / 2
        let pattern = Double(span.lowerBound + span.upperBound) / 2
        var tonic = Int((centre - pattern).rounded())
        if tonic + span.upperBound > high { tonic = high - span.upperBound }
        if tonic + span.lowerBound < low { tonic = max(tonic, low - span.lowerBound) }
        // A pattern wider than the range sits centred instead.
        if span.upperBound - span.lowerBound > high - low { tonic = Int((centre - pattern).rounded()) }
        return min(84, max(24, tonic))
    }
}

/// Builders for singing steps. Notes are written as scale degrees of a major scale:
/// `1 2 3`, `b3`, `#4`, `1'` (octave up), `5,` (octave down), `r` (rest),
/// with an optional length (`:h`, `:q.`, `:e` — default quarter) and text (`=la`).
enum V {
    private static let major = [0, 2, 4, 5, 7, 9, 11]
    private static let solfege = [0: "do", 2: "re", 4: "mi", 5: "fa", 7: "sol", 9: "la", 11: "ti"]

    static func beats(_ code: String) -> Double {
        var value: Double
        switch code.first {
        case "w": value = 4
        case "h": value = 2
        case "e": value = 0.5
        case "s": value = 0.25
        default: value = 1
        }
        let dots = code.filter { $0 == "." }.count
        if dots == 1 { value *= 1.5 } else if dots >= 2 { value *= 1.75 }
        return value
    }

    static func notes(_ text: String, syllable: String? = nil) -> [SingNote] {
        text.split(whereSeparator: { $0 == " " || $0 == "|" || $0 == "\n" }).map { raw in
            var token = String(raw)
            var label: String? = nil
            if let eq = token.firstIndex(of: "=") {
                label = String(token[token.index(after: eq)...])
                token = String(token[..<eq])
            }
            var length = 1.0
            if let colon = token.firstIndex(of: ":") {
                length = beats(String(token[token.index(after: colon)...]))
                token = String(token[..<colon])
            }
            if token == "r" { return SingNote(semitone: nil, beats: length) }
            var shift = 0
            while let first = token.first, first == "b" || first == "#" {
                shift += first == "b" ? -1 : 1
                token.removeFirst()
            }
            let up = token.filter { $0 == "'" }.count
            let down = token.filter { $0 == "," }.count
            let degree = Int(token.filter { $0.isNumber }) ?? 1
            let semitone = major[(max(1, min(7, degree))) - 1] + shift + 12 * (up - down)
            let name = label ?? syllable ?? solfege[((semitone % 12) + 12) % 12]
            return SingNote(semitone: semitone, beats: length, label: name)
        }
    }

    /// Turn a keyboard melody into a singing line relative to `tonic` (a MIDI note).
    static func notes(from events: [ExpectedEvent], tonic: Int) -> [SingNote] {
        var out: [SingNote] = []
        var cursor = 0.0
        for event in events.sorted(by: { $0.beat < $1.beat }) {
            guard let top = event.notes.map({ $0.midi }).max() else { continue }
            if event.beat > cursor + 0.01 { out.append(SingNote(semitone: nil, beats: event.beat - cursor)) }
            out.append(SingNote(semitone: top - tonic, beats: event.duration))
            cursor = event.beat + event.duration
        }
        return out
    }

    static func match(_ title: String, _ text: String, _ pattern: String, hold: Double = 1.0, syllable: String? = nil,
                      tolerance: Double = 50) -> Step {
        .sing(SingTask(title: title, instructions: text, notes: notes(pattern, syllable: syllable),
                       kind: .match(hold: hold), toleranceCents: tolerance, pass: 0.99))
    }

    static func pattern(_ title: String, _ text: String, _ pattern: String, bpm: Double, shifts: [Int] = [0],
                        syllable: String? = nil, tolerance: Double = 50, pass: Double = 0.6, guide: Bool = true) -> Step {
        .sing(SingTask(title: title, instructions: text, notes: notes(pattern, syllable: syllable),
                       kind: .timed(bpm: bpm), toleranceCents: tolerance, pass: pass, shifts: shifts, guide: guide))
    }

    static func song(_ title: String, _ text: String, _ notes: [SingNote], bpm: Double, pass: Double = 0.6) -> Step {
        .sing(SingTask(title: title, instructions: text, notes: notes, kind: .timed(bpm: bpm), pass: pass))
    }

    static func free(_ title: String, _ text: String, seconds: Double = 10, span: Double = 5) -> Step {
        .sing(SingTask(title: title, instructions: text, kind: .free(seconds: seconds, span: span)))
    }

    static func range(_ title: String, _ text: String) -> Step {
        .sing(SingTask(title: title, instructions: text, kind: .range))
    }
}
