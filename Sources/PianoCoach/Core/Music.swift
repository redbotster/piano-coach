import Foundation

enum Hand: String {
    case left, right, either
}

/// Music theory helpers. Middle C = C4 = MIDI 60.
enum Music {
    static let sharpNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    static let flatNames = ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"]

    /// The Launchkey 61 range with no octave shift.
    static let lowestKey = 36   // C2
    static let highestKey = 96  // C7
    static let middleC = 60

    static func pc(_ midi: Int) -> Int { ((midi % 12) + 12) % 12 }
    static func octave(_ midi: Int) -> Int { midi / 12 - 1 }
    static func isBlack(_ midi: Int) -> Bool { [1, 3, 6, 8, 10].contains(pc(midi)) }

    static func name(_ midi: Int, flats: Bool = false, octave showOctave: Bool = true) -> String {
        let base = (flats ? flatNames : sharpNames)[pc(midi)]
        return showOctave ? "\(base)\(octave(midi))" : base
    }

    /// Both spellings for black keys, e.g. "C♯/D♭".
    static func bothNames(_ midi: Int) -> String {
        isBlack(midi) ? "\(sharpNames[pc(midi)])/\(flatNames[pc(midi)])" : sharpNames[pc(midi)]
    }

    /// Parse "C4", "F#3", "Bb2", "Eb5", "C♯4". Octave defaults to 4.
    static func midi(_ text: String) -> Int {
        let chars = Array(text.trimmingCharacters(in: .whitespaces))
        guard let first = chars.first else { return 60 }
        let letters: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        var value = letters[Character(first.uppercased())] ?? 0
        var i = 1
        while i < chars.count, "#♯b♭".contains(chars[i]) {
            value += (chars[i] == "#" || chars[i] == "♯") ? 1 : -1
            i += 1
        }
        let octave = Int(String(chars[i...])) ?? 4
        return (octave + 1) * 12 + value
    }

    /// Parse a space separated list of note names.
    static func notes(_ text: String) -> [Int] {
        text.split(separator: " ").map { midi(String($0)) }
    }

    static func scale(root: Int, type: ScaleType, octaves: Int = 1, descend: Bool = false) -> [Int] {
        var up: [Int] = []
        for o in 0..<octaves {
            for i in type.intervals { up.append(root + o * 12 + i) }
        }
        up.append(root + octaves * 12)
        return descend ? up + up.dropLast().reversed() : up
    }

    static func chord(root: Int, type: ChordType, inversion: Int = 0) -> [Int] {
        var notes = type.intervals.map { root + $0 }
        for _ in 0..<max(0, inversion) {
            let first = notes.removeFirst()
            notes.append(first + 12)
        }
        return notes
    }

    /// Arpeggio through `octaves` octaves ending on the top root.
    static func arpeggio(root: Int, type: ChordType, octaves: Int = 1, descend: Bool = false) -> [Int] {
        var up: [Int] = []
        for o in 0..<octaves {
            for i in type.intervals where i < 12 { up.append(root + o * 12 + i) }
        }
        up.append(root + octaves * 12)
        return descend ? up + up.dropLast().reversed() : up
    }

    /// Whether a key (by tonic pitch class) is conventionally written with flats.
    static func prefersFlats(tonicPC: Int, minor: Bool = false) -> Bool {
        minor ? [0, 2, 3, 5, 7, 10].contains(tonicPC) : [1, 3, 5, 8, 10].contains(tonicPC)
    }

    /// Number of sharps (positive) or flats (negative) for a major key.
    static func fifths(majorTonicPC pc: Int) -> Int {
        [0: 0, 7: 1, 2: 2, 9: 3, 4: 4, 11: 5, 6: 6, 1: -5, 8: -4, 3: -3, 10: -2, 5: -1][pc] ?? 0
    }

    static func fifths(minorTonicPC pc: Int) -> Int {
        fifths(majorTonicPC: (pc + 3) % 12)
    }

    /// Name the chord formed by a set of held notes, if recognisable.
    static func identifyChord(_ held: [Int]) -> String? {
        let sorted = held.sorted()
        let pcs = Set(sorted.map { pc($0) })
        guard pcs.count >= 3, let bass = sorted.first else { return nil }
        for type in ChordType.recognitionOrder {
            for root in 0..<12 {
                let target = Set(type.intervals.map { (root + $0) % 12 })
                if target == pcs {
                    let flats = prefersFlats(tonicPC: root)
                    let rootName = (flats ? flatNames : sharpNames)[root]
                    var text = rootName + type.symbol
                    if pc(bass) != root { text += "/" + (flats ? flatNames : sharpNames)[pc(bass)] }
                    return text
                }
            }
        }
        return nil
    }
}

enum ScaleType: String, CaseIterable {
    case major, naturalMinor, harmonicMinor, melodicMinor
    case chromatic, majorPentatonic, minorPentatonic, blues, wholeTone
    case dorian, phrygian, lydian, mixolydian, aeolian, locrian
    case bebopDominant, bebopMajor, altered, diminishedHalfWhole, diminishedWholeHalf

    var intervals: [Int] {
        switch self {
        case .major: return [0, 2, 4, 5, 7, 9, 11]
        case .naturalMinor, .aeolian: return [0, 2, 3, 5, 7, 8, 10]
        case .harmonicMinor: return [0, 2, 3, 5, 7, 8, 11]
        case .melodicMinor: return [0, 2, 3, 5, 7, 9, 11]
        case .chromatic: return Array(0..<12)
        case .majorPentatonic: return [0, 2, 4, 7, 9]
        case .minorPentatonic: return [0, 3, 5, 7, 10]
        case .blues: return [0, 3, 5, 6, 7, 10]
        case .wholeTone: return [0, 2, 4, 6, 8, 10]
        case .dorian: return [0, 2, 3, 5, 7, 9, 10]
        case .phrygian: return [0, 1, 3, 5, 7, 8, 10]
        case .lydian: return [0, 2, 4, 6, 7, 9, 11]
        case .mixolydian: return [0, 2, 4, 5, 7, 9, 10]
        case .locrian: return [0, 1, 3, 5, 6, 8, 10]
        case .bebopDominant: return [0, 2, 4, 5, 7, 9, 10, 11]
        case .bebopMajor: return [0, 2, 4, 5, 7, 8, 9, 11]
        case .altered: return [0, 1, 3, 4, 6, 8, 10]
        case .diminishedHalfWhole: return [0, 1, 3, 4, 6, 7, 9, 10]
        case .diminishedWholeHalf: return [0, 2, 3, 5, 6, 8, 9, 11]
        }
    }

    var displayName: String {
        switch self {
        case .major: return "major"
        case .naturalMinor: return "natural minor"
        case .harmonicMinor: return "harmonic minor"
        case .melodicMinor: return "melodic minor"
        case .chromatic: return "chromatic"
        case .majorPentatonic: return "major pentatonic"
        case .minorPentatonic: return "minor pentatonic"
        case .blues: return "blues"
        case .wholeTone: return "whole-tone"
        case .dorian: return "Dorian"
        case .phrygian: return "Phrygian"
        case .lydian: return "Lydian"
        case .mixolydian: return "Mixolydian"
        case .aeolian: return "Aeolian"
        case .locrian: return "Locrian"
        case .bebopDominant: return "bebop dominant"
        case .bebopMajor: return "bebop major"
        case .altered: return "altered"
        case .diminishedHalfWhole: return "diminished (half-whole)"
        case .diminishedWholeHalf: return "diminished (whole-half)"
        }
    }

    var isMinor: Bool {
        [.naturalMinor, .harmonicMinor, .melodicMinor, .aeolian, .dorian, .phrygian, .locrian,
         .minorPentatonic, .blues].contains(self)
    }
}

enum ChordType: String, CaseIterable {
    case major, minor, diminished, augmented, sus2, sus4
    case dom7, maj7, min7, halfDim7, dim7, minMaj7, six, min6
    case dom7b9, dom7sharp9, dom9, maj9, min9

    var intervals: [Int] {
        switch self {
        case .major: return [0, 4, 7]
        case .minor: return [0, 3, 7]
        case .diminished: return [0, 3, 6]
        case .augmented: return [0, 4, 8]
        case .sus2: return [0, 2, 7]
        case .sus4: return [0, 5, 7]
        case .dom7: return [0, 4, 7, 10]
        case .maj7: return [0, 4, 7, 11]
        case .min7: return [0, 3, 7, 10]
        case .halfDim7: return [0, 3, 6, 10]
        case .dim7: return [0, 3, 6, 9]
        case .minMaj7: return [0, 3, 7, 11]
        case .six: return [0, 4, 7, 9]
        case .min6: return [0, 3, 7, 9]
        case .dom7b9: return [0, 4, 7, 10, 13]
        case .dom7sharp9: return [0, 4, 7, 10, 15]
        case .dom9: return [0, 4, 7, 10, 14]
        case .maj9: return [0, 4, 7, 11, 14]
        case .min9: return [0, 3, 7, 10, 14]
        }
    }

    /// Suffix used in a chord symbol: C, Cm, C7, Cmaj7...
    var symbol: String {
        switch self {
        case .major: return ""
        case .minor: return "m"
        case .diminished: return "dim"
        case .augmented: return "aug"
        case .sus2: return "sus2"
        case .sus4: return "sus4"
        case .dom7: return "7"
        case .maj7: return "maj7"
        case .min7: return "m7"
        case .halfDim7: return "m7♭5"
        case .dim7: return "dim7"
        case .minMaj7: return "m(maj7)"
        case .six: return "6"
        case .min6: return "m6"
        case .dom7b9: return "7♭9"
        case .dom7sharp9: return "7♯9"
        case .dom9: return "9"
        case .maj9: return "maj9"
        case .min9: return "m9"
        }
    }

    var displayName: String {
        switch self {
        case .major: return "major"
        case .minor: return "minor"
        case .diminished: return "diminished"
        case .augmented: return "augmented"
        case .sus2: return "sus2"
        case .sus4: return "sus4"
        case .dom7: return "dominant 7th"
        case .maj7: return "major 7th"
        case .min7: return "minor 7th"
        case .halfDim7: return "half-diminished 7th"
        case .dim7: return "diminished 7th"
        case .minMaj7: return "minor-major 7th"
        case .six: return "major 6th"
        case .min6: return "minor 6th"
        case .dom7b9: return "dominant 7th ♭9"
        case .dom7sharp9: return "dominant 7th ♯9"
        case .dom9: return "dominant 9th"
        case .maj9: return "major 9th"
        case .min9: return "minor 9th"
        }
    }

    /// Order matters: 6th chords and minor 7ths share pitch classes, prefer the 7th reading.
    static let recognitionOrder: [ChordType] = [
        .major, .minor, .diminished, .augmented, .dom7, .maj7, .min7, .halfDim7, .dim7, .minMaj7,
        .dom9, .maj9, .min9, .dom7b9, .dom7sharp9, .sus4, .sus2, .six, .min6,
    ]
}

/// Standard one-octave scale fingerings, ascending, indexed by tonic pitch class.
enum Fingering {
    private static let rhMajor: [Int: [Int]] = [
        0: [1, 2, 3, 1, 2, 3, 4, 5], 7: [1, 2, 3, 1, 2, 3, 4, 5], 2: [1, 2, 3, 1, 2, 3, 4, 5],
        9: [1, 2, 3, 1, 2, 3, 4, 5], 4: [1, 2, 3, 1, 2, 3, 4, 5], 11: [1, 2, 3, 1, 2, 3, 4, 5],
        5: [1, 2, 3, 4, 1, 2, 3, 4], 10: [2, 1, 2, 3, 1, 2, 3, 4], 3: [3, 1, 2, 3, 4, 1, 2, 3],
        8: [3, 4, 1, 2, 3, 1, 2, 3], 1: [2, 3, 1, 2, 3, 4, 1, 2], 6: [2, 3, 4, 1, 2, 3, 1, 2],
    ]
    private static let lhMajor: [Int: [Int]] = [
        0: [5, 4, 3, 2, 1, 3, 2, 1], 7: [5, 4, 3, 2, 1, 3, 2, 1], 2: [5, 4, 3, 2, 1, 3, 2, 1],
        9: [5, 4, 3, 2, 1, 3, 2, 1], 4: [5, 4, 3, 2, 1, 3, 2, 1], 11: [4, 3, 2, 1, 4, 3, 2, 1],
        5: [5, 4, 3, 2, 1, 3, 2, 1], 10: [3, 2, 1, 4, 3, 2, 1, 3], 3: [3, 2, 1, 4, 3, 2, 1, 3],
        8: [3, 2, 1, 4, 3, 2, 1, 3], 1: [3, 2, 1, 4, 3, 2, 1, 3], 6: [4, 3, 2, 1, 3, 2, 1, 4],
    ]
    private static let rhMinor: [Int: [Int]] = [
        9: [1, 2, 3, 1, 2, 3, 4, 5], 4: [1, 2, 3, 1, 2, 3, 4, 5], 11: [1, 2, 3, 1, 2, 3, 4, 5],
        2: [1, 2, 3, 1, 2, 3, 4, 5], 7: [1, 2, 3, 1, 2, 3, 4, 5], 0: [1, 2, 3, 1, 2, 3, 4, 5],
        5: [1, 2, 3, 4, 1, 2, 3, 4], 6: [3, 4, 1, 2, 3, 1, 2, 3], 1: [3, 4, 1, 2, 3, 1, 2, 3],
        8: [3, 4, 1, 2, 3, 1, 2, 3], 3: [3, 1, 2, 3, 4, 1, 2, 3], 10: [2, 1, 2, 3, 1, 2, 3, 4],
    ]
    private static let lhMinor: [Int: [Int]] = [
        9: [5, 4, 3, 2, 1, 3, 2, 1], 4: [5, 4, 3, 2, 1, 3, 2, 1], 11: [4, 3, 2, 1, 4, 3, 2, 1],
        2: [5, 4, 3, 2, 1, 3, 2, 1], 7: [5, 4, 3, 2, 1, 3, 2, 1], 0: [5, 4, 3, 2, 1, 3, 2, 1],
        5: [5, 4, 3, 2, 1, 3, 2, 1], 6: [4, 3, 2, 1, 3, 2, 1, 4], 1: [3, 2, 1, 4, 3, 2, 1, 3],
        8: [3, 2, 1, 3, 2, 1, 4, 3], 3: [2, 1, 4, 3, 2, 1, 3, 2], 10: [2, 1, 3, 2, 1, 4, 3, 2],
    ]

    /// Ascending fingering for one octave (8 notes) of a 7-note scale, or nil if no standard table applies.
    static func scale(tonicPC: Int, type: ScaleType, hand: Hand) -> [Int]? {
        guard type.intervals.count == 7 else { return nil }
        switch type {
        case .major:
            return hand == .left ? lhMajor[tonicPC] : rhMajor[tonicPC]
        case .naturalMinor, .harmonicMinor, .melodicMinor, .aeolian:
            return hand == .left ? lhMinor[tonicPC] : rhMinor[tonicPC]
        default:
            // Modes starting on a white key with mostly white notes use the C-major shape.
            guard !Music.isBlack(tonicPC) else { return nil }
            return hand == .left ? lhMajor[0] : rhMajor[0]
        }
    }

    /// Fingering for a full run of `count` notes (multi-octave, optionally there-and-back).
    static func scaleRun(tonicPC: Int, type: ScaleType, hand: Hand, octaves: Int, descend: Bool) -> [Int]? {
        guard let one = scale(tonicPC: tonicPC, type: type, hand: hand) else { return nil }
        // Inner octaves start on the finger that ends the shape; right-hand shapes that begin on the
        // thumb (C and F types) cross to the thumb again instead.
        let inner = (hand != .left && one[0] == 1) ? 1 : one[7]
        var up: [Int] = []
        for o in 0..<octaves {
            var chunk = Array(one.dropLast())
            if o > 0 { chunk[0] = inner }
            up += chunk
        }
        up.append(one[7])
        return descend ? up + up.dropLast().reversed() : up
    }
}
