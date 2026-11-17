import Foundation

// MARK: - Stored song model

/// One note of an imported song. Stored in JSON as `[beat, duration, midi, hand]` (hand: 0 = right, 1 = left).
struct ImportedNote: Codable, Equatable {
    var beat: Double
    var duration: Double
    var midi: Int
    var left: Bool

    init(beat: Double, duration: Double, midi: Int, left: Bool) {
        self.beat = beat
        self.duration = duration
        self.midi = midi
        self.left = left
    }

    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        beat = try c.decode(Double.self)
        duration = try c.decode(Double.self)
        midi = Int(try c.decode(Double.self))
        left = (try c.decode(Double.self)) >= 0.5
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(beat)
        try c.encode(duration)
        try c.encode(Double(midi))
        try c.encode(left ? 1.0 : 0.0)
    }

    var hand: Hand { left ? .left : .right }
}

/// A song imported from a MIDI or MusicXML file. Beats are counted in `beatUnit` notes (4 = quarter, 8 = eighth).
struct ImportedSong: Codable, Identifiable {
    var id: String
    var title: String
    var sourceFile: String
    var bpm: Double
    var beatsPerBar: Int
    var beatUnit: Int
    var fifths: Int
    var minor: Bool?
    var notes: [ImportedNote]

    var lessonID: String { "mysongs.\(id)" }
    var totalBeats: Double { notes.map { $0.beat + $0.duration }.max() ?? 0 }
    var totalBars: Int { max(1, Int((totalBeats / Double(beatsPerBar) - 1e-6).rounded(.up))) }
}

enum SongImportError: LocalizedError {
    case unreadable(String)
    case notMIDI(String)
    case noNotes
    case badMusicXML(String)
    case unsupported(String)

    var errorDescription: String? {
        switch self {
        case .unreadable(let why): return "The file could not be read (\(why))."
        case .notMIDI(let why): return "This is not a valid Standard MIDI File (\(why))."
        case .noNotes: return "No playable notes were found in the file (drum tracks are ignored)."
        case .badMusicXML(let why): return "The MusicXML could not be understood (\(why))."
        case .unsupported(let what): return "Unsupported file: \(what)."
        }
    }
}

// MARK: - Import

/// Reads Standard MIDI Files and MusicXML (plain or compressed .mxl) into `ImportedSong`s.
enum SongImport {
    /// A note as read from the file: positions in quarter notes, hand not necessarily known yet.
    struct RawNote {
        var start: Double
        var duration: Double
        var midi: Int
        /// Track/channel (MIDI) or part/staff (MusicXML) the note came from.
        var group: Int
        var hand: Hand?
    }

    struct RawSong {
        var title: String?
        var bpm: Double = 120
        var numerator: Int = 4
        var denominator: Int = 4
        var fifths: Int = 0
        var minor: Bool?
        var notes: [RawNote] = []
        var groupNames: [Int: String] = [:]
        var isXML = false
        var hasTuplets = false
        var hasFineValues = false
    }

    // MARK: Entry points

    static func load(url: URL) throws -> ImportedSong {
        let data: Data
        do { data = try Data(contentsOf: url) } catch { throw SongImportError.unreadable(error.localizedDescription) }
        return try parse(data: data, filename: url.lastPathComponent, url: url)
    }

    /// Parse file contents. `url` is only needed for compressed .mxl files (they are unzipped from disk).
    static func parse(data: Data, filename: String, url: URL? = nil) throws -> ImportedSong {
        guard data.count >= 4 else { throw SongImportError.unreadable("the file is empty") }
        let head = [UInt8](data.prefix(64))
        var raw: RawSong
        if indexOf("MThd", in: head) != nil {
            raw = try parseMIDI(data)
        } else if head[0] == 0x50, head[1] == 0x4B {
            guard let url else { throw SongImportError.unsupported("compressed MusicXML needs to be opened from a file") }
            raw = try parseMusicXML(try unzipMXL(url))
        } else {
            raw = try parseMusicXML(data)
        }
        return try finalize(raw, filename: filename)
    }

    private static func indexOf(_ tag: String, in bytes: [UInt8]) -> Int? {
        let t = Array(tag.utf8)
        guard bytes.count >= t.count else { return nil }
        for i in 0...(bytes.count - t.count) where Array(bytes[i..<i + t.count]) == t { return i }
        return nil
    }

    // MARK: Standard MIDI File

    static func parseMIDI(_ data: Data) throws -> RawSong {
        let bytes = [UInt8](data)
        guard let start = indexOf("MThd", in: Array(bytes.prefix(64))) else { throw SongImportError.notMIDI("missing MThd header") }
        func u16(_ i: Int) -> Int { (Int(bytes[i]) << 8) | Int(bytes[i + 1]) }
        func u32(_ i: Int) -> Int { (Int(bytes[i]) << 24) | (Int(bytes[i + 1]) << 16) | (Int(bytes[i + 2]) << 8) | Int(bytes[i + 3]) }
        guard bytes.count >= start + 14 else { throw SongImportError.notMIDI("header is truncated") }
        let headerLength = u32(start + 4)
        let format = u16(start + 8)
        let division = u16(start + 12)
        guard format <= 2 else { throw SongImportError.notMIDI("unknown format \(format)") }
        guard division & 0x8000 == 0, division > 0 else { throw SongImportError.unsupported("MIDI files with SMPTE timing") }

        struct TickNote { var start: Int; var end: Int; var midi: Int; var group: Int }
        var notes: [TickNote] = []
        var tempos: [(tick: Int, micros: Int)] = []
        var timeSignature: (Int, Int)?
        var keySignature: (Int, Bool)?
        var trackNames: [Int: String] = [:]

        var p = start + 8 + headerLength
        var track = 0
        while p + 8 <= bytes.count {
            let id = String(bytes: bytes[p..<p + 4], encoding: .ascii) ?? ""
            let length = u32(p + 4)
            let body = p + 8
            let end = min(bytes.count, body + max(0, length))
            if id == "MTrk" {
                var i = body
                var tick = 0
                var status: UInt8 = 0
                var open: [Int: [Int]] = [:]
                func vlq() -> Int {
                    var value = 0
                    while i < end {
                        let b = bytes[i]
                        i += 1
                        value = (value << 7) | Int(b & 0x7F)
                        if b & 0x80 == 0 { break }
                    }
                    return value
                }
                while i < end {
                    tick += vlq()
                    guard i < end else { break }
                    let b = bytes[i]
                    if b == 0xFF {
                        i += 1
                        guard i < end else { break }
                        let type = bytes[i]
                        i += 1
                        let length = vlq()
                        let dataEnd = min(end, i + length)
                        let payload = Array(bytes[i..<dataEnd])
                        switch type {
                        case 0x51 where payload.count >= 3:
                            tempos.append((tick, (Int(payload[0]) << 16) | (Int(payload[1]) << 8) | Int(payload[2])))
                        case 0x58 where payload.count >= 2:
                            if timeSignature == nil { timeSignature = (Int(payload[0]), 1 << Int(min(payload[1], 6))) }
                        case 0x59 where payload.count >= 2:
                            if keySignature == nil { keySignature = (Int(Int8(bitPattern: payload[0])), payload[1] == 1) }
                        case 0x03:
                            if trackNames[track] == nil, let name = String(bytes: payload, encoding: .utf8) ?? String(bytes: payload, encoding: .isoLatin1) {
                                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty { trackNames[track] = trimmed }
                            }
                        default: break
                        }
                        i = dataEnd
                        continue
                    }
                    if b == 0xF0 || b == 0xF7 {
                        i += 1
                        let length = vlq()
                        i = min(end, i + length)
                        continue
                    }
                    if b & 0x80 != 0 { status = b; i += 1 }
                    guard status >= 0x80 else { i += 1; continue }
                    let kind = status & 0xF0
                    let channel = Int(status & 0x0F)
                    let size = (kind == 0xC0 || kind == 0xD0) ? 1 : 2
                    guard i + size <= end else { break }
                    let d1 = Int(bytes[i])
                    let d2 = size == 2 ? Int(bytes[i + 1]) : 0
                    i += size
                    if channel == 9 { continue }
                    let key = channel * 128 + d1
                    if kind == 0x90, d2 > 0 {
                        open[key, default: []].append(tick)
                    } else if kind == 0x80 || kind == 0x90 {
                        if var starts = open[key], !starts.isEmpty {
                            let s = starts.removeFirst()
                            open[key] = starts
                            notes.append(TickNote(start: s, end: max(tick, s + 1), midi: d1, group: track * 16 + channel))
                        }
                    }
                }
                for (key, starts) in open {
                    for s in starts { notes.append(TickNote(start: s, end: max(tick, s + division / 4), midi: key % 128, group: track * 16 + key / 128)) }
                }
                track += 1
            }
            p = body + max(0, length)
        }
        guard track > 0 else { throw SongImportError.notMIDI("it contains no tracks") }

        var raw = RawSong()
        let firstTick = notes.map { $0.start }.min() ?? 0
        let sortedTempos = tempos.sorted { $0.tick < $1.tick }
        if let tempo = sortedTempos.last(where: { $0.tick <= firstTick }) ?? sortedTempos.first, tempo.micros > 0 {
            raw.bpm = 60_000_000 / Double(tempo.micros)
        }
        if let ts = timeSignature, ts.0 > 0 { raw.numerator = ts.0; raw.denominator = ts.1 }
        if let ks = keySignature { raw.fifths = ks.0; raw.minor = ks.1 }
        let ppq = Double(division)
        raw.notes = notes.map {
            RawNote(start: Double($0.start) / ppq, duration: Double($0.end - $0.start) / ppq, midi: $0.midi, group: $0.group, hand: nil)
        }
        for group in Set(notes.map { $0.group }) {
            if let name = trackNames[group / 16] { raw.groupNames[group] = name }
        }
        // In a format-1 file the first track's name is the song title.
        if let name = trackNames[0], handHint(name) == nil { raw.title = name }
        return raw
    }

    // MARK: MusicXML

    private static func unzipMXL(_ url: URL) throws -> Data {
        func unzip(_ arguments: [String]) -> Data? {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = arguments
            let out = Pipe()
            process.standardOutput = out
            process.standardError = Pipe()
            do { try process.run() } catch { return nil }
            let data = out.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return process.terminationStatus == 0 ? data : nil
        }
        var root: String?
        if let container = unzip(["-p", url.path, "META-INF/container.xml"]), let text = String(data: container, encoding: .utf8),
           let range = text.range(of: "full-path=\"") {
            let rest = text[range.upperBound...]
            if let end = rest.firstIndex(of: "\"") { root = String(rest[..<end]) }
        }
        if root == nil, let listing = unzip(["-Z1", url.path]), let text = String(data: listing, encoding: .utf8) {
            root = text.split(separator: "\n").map(String.init).first {
                !$0.hasPrefix("META-INF") && ($0.lowercased().hasSuffix(".xml") || $0.lowercased().hasSuffix(".musicxml"))
            }
        }
        guard let root, let data = unzip(["-p", url.path, root]), !data.isEmpty else {
            throw SongImportError.badMusicXML("the compressed .mxl archive has no score inside")
        }
        return data
    }

    private final class XMLReader: NSObject, XMLParserDelegate {
        var song = RawSong()
        var rootName: String?
        var partCount = 0
        var sawStaffTwo: Set<Int> = []

        private var stack: [String] = []
        private var text = ""
        private var divisions = 1.0
        private var part = -1
        private var cursor = 0.0
        private var measureStart = 0.0
        private var measureMax = 0.0
        private var lastOnset = 0.0
        private var measureIndex = 0
        private var firstMeasureLength: [Int: Double] = [:]
        private var firstMeasureImplicit: [Int: Bool] = [:]
        private var partNoteRange: [Int: Range<Int>] = [:]
        private var partStartIndex = 0
        private var openTies: [Int: Int] = [:]
        private var sawTempo = false
        private var sawKey = false
        private var sawTime = false
        private var beatUnitFactor = 1.0

        // Current <note>
        private var isRest = false, isChord = false, isGrace = false
        private var step = "", alter = 0.0, octave = 4, duration = 0.0, staff = 1
        private var tieStart = false, tieStop = false

        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?,
                    attributes: [String: String] = [:]) {
            if rootName == nil { rootName = name }
            stack.append(name)
            text = ""
            switch name {
            case "part":
                part += 1
                partCount = part + 1
                cursor = 0; measureStart = 0; measureMax = 0; lastOnset = 0; measureIndex = 0
                openTies = [:]
                partStartIndex = song.notes.count
            case "measure":
                cursor = measureStart
                measureMax = measureStart
                if measureIndex == 0 { firstMeasureImplicit[part] = attributes["implicit"] == "yes" }
            case "note":
                isRest = false; isChord = false; isGrace = false
                step = ""; alter = 0; octave = 4; duration = 0; staff = 1
                tieStart = false; tieStop = false
            case "rest": isRest = true
            case "chord": isChord = true
            case "grace": isGrace = true
            case "tie":
                if attributes["type"] == "start" { tieStart = true }
                if attributes["type"] == "stop" { tieStop = true }
            case "time-modification": song.hasTuplets = true
            case "sound":
                if !sawTempo, let t = attributes["tempo"].flatMap(Double.init), t > 0 { song.bpm = t; sawTempo = true }
            case "beat-unit-dot": beatUnitFactor *= 1.5
            default: break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
            let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let parent = stack.count >= 2 ? stack[stack.count - 2] : ""
            switch name {
            case "work-title": if !value.isEmpty { song.title = value }
            case "movement-title": if !value.isEmpty, song.title == nil { song.title = value }
            case "divisions": if let d = Double(value), d > 0 { divisions = d }
            case "fifths": if !sawKey, let f = Int(value) { song.fifths = f; sawKey = true }
            case "mode": if song.minor == nil { song.minor = value == "minor" }
            case "beats": if !sawTime, let b = Int(value), b > 0 { song.numerator = b }
            case "beat-type": if !sawTime, let b = Int(value), b > 0 { song.denominator = b; sawTime = true }
            case "beat-unit":
                switch value {
                case "half": beatUnitFactor = 2
                case "eighth": beatUnitFactor = 0.5
                case "16th": beatUnitFactor = 0.25
                case "whole": beatUnitFactor = 4
                default: beatUnitFactor = 1
                }
            case "per-minute":
                if !sawTempo, let t = Double(value), t > 0 { song.bpm = t * beatUnitFactor; sawTempo = true }
            case "step": step = value
            case "alter": alter = Double(value) ?? 0
            case "octave": octave = Int(value) ?? 4
            case "staff": if parent == "note" { staff = Int(value) ?? 1 }
            case "type": if parent == "note", ["32nd", "64th", "128th"].contains(value) { song.hasFineValues = true }
            case "duration":
                let d = (Double(value) ?? 0) / divisions
                if parent == "note" { duration = d }
                else if parent == "backup" { cursor = max(measureStart, cursor - d) }
                else if parent == "forward" { cursor += d; measureMax = max(measureMax, cursor) }
            case "note": finishNote()
            case "measure":
                if measureIndex == 0 { firstMeasureLength[part] = measureMax - measureStart }
                measureStart = measureMax
                measureIndex += 1
            case "part":
                partNoteRange[part] = partStartIndex..<song.notes.count
            default: break
            }
            stack.removeLast()
            text = ""
        }

        private func finishNote() {
            if isGrace { return }
            let onset: Double
            if isChord {
                onset = lastOnset
            } else {
                onset = cursor
                lastOnset = onset
                cursor += duration
                measureMax = max(measureMax, cursor)
            }
            guard !isRest, let pc = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11][step.uppercased()], duration > 0 else { return }
            let midi = (octave + 1) * 12 + pc + Int(alter.rounded())
            if staff >= 2 { sawStaffTwo.insert(part) }
            let tieKey = min(staff, 2) * 1000 + midi
            if tieStop, let index = openTies[tieKey], abs(song.notes[index].start + song.notes[index].duration - onset) < 0.01 {
                song.notes[index].duration += duration
                if !tieStart { openTies[tieKey] = nil }
                return
            }
            song.notes.append(RawNote(start: onset, duration: duration, midi: midi, group: part * 16 + min(staff, 2), hand: nil))
            if tieStart { openTies[tieKey] = song.notes.count - 1 } else { openTies[tieKey] = nil }
        }

        /// Shift each part so a pickup (short first measure) ends on a bar line, and fix hands where staves say so.
        func finish() {
            let bar = Double(song.numerator) * 4 / Double(song.denominator)
            for p in 0..<partCount {
                guard let range = partNoteRange[p] else { continue }
                if let length = firstMeasureLength[p], length > 0.01, length < bar - 0.01 {
                    for i in range { song.notes[i].start += bar - length }
                }
                if sawStaffTwo.contains(p) {
                    for i in range { song.notes[i].hand = song.notes[i].group % 16 >= 2 ? .left : .right }
                }
            }
        }
    }

    static func parseMusicXML(_ data: Data) throws -> RawSong {
        let reader = XMLReader()
        let parser = XMLParser(data: data)
        parser.delegate = reader
        let ok = parser.parse()
        if reader.rootName == "score-timewise" { throw SongImportError.unsupported("time-wise MusicXML (export as a part-wise score instead)") }
        guard reader.rootName == "score-partwise" else {
            throw SongImportError.badMusicXML(ok ? "it is not a MusicXML score" : (parser.parserError?.localizedDescription ?? "the XML is malformed"))
        }
        if !ok, reader.song.notes.isEmpty {
            throw SongImportError.badMusicXML(parser.parserError?.localizedDescription ?? "the XML is malformed")
        }
        reader.finish()
        var song = reader.song
        song.isXML = true
        return song
    }

    // MARK: Hands, quantizing, clean-up

    /// "left" / "right" if a track name says which hand it is.
    static func handHint(_ name: String) -> Hand? {
        let lower = name.lowercased()
        let words = Set(lower.split { !$0.isLetter }.map(String.init))
        if lower.contains("left") || words.contains("lh") || words.contains("l.h") || lower.contains("bass") { return .left }
        if lower.contains("right") || words.contains("rh") || lower.contains("treble") { return .right }
        return nil
    }

    private static func chooseGrid(_ raw: RawSong) -> Double {
        if raw.isXML {
            if raw.hasTuplets { return raw.hasFineValues ? 1.0 / 24 : 1.0 / 12 }
            return raw.hasFineValues ? 0.125 : 0.25
        }
        var triplet = 0, sixteenth = 0, fine = 0
        for note in raw.notes {
            let frac = note.start - note.start.rounded(.down)
            func near(_ x: Double, _ tolerance: Double = 0.045) -> Bool { abs(frac - x) < tolerance }
            if near(1.0 / 3) || near(2.0 / 3) || near(1.0 / 6, 0.03) || near(5.0 / 6, 0.03) { triplet += 1 }
            else if near(0.25) || near(0.75) { sixteenth += 1 }
            else if near(0.125, 0.03) || near(0.375, 0.03) || near(0.625, 0.03) || near(0.875, 0.03) { fine += 1 }
        }
        let count = max(1, raw.notes.count)
        if triplet > sixteenth, Double(triplet) / Double(count) >= 0.08 { return 1.0 / 6 }
        if Double(fine) / Double(count) >= 0.1 { return 0.125 }
        return 0.25
    }

    static func finalize(_ raw: RawSong, filename: String) throws -> ImportedSong {
        guard !raw.notes.isEmpty else { throw SongImportError.noNotes }
        let grid = chooseGrid(raw)

        struct Work { var slot: Int; var length: Int; var midi: Int; var group: Int; var hand: Hand? }
        var notes: [Work] = raw.notes.map { note in
            var midi = note.midi
            while midi < Music.lowestKey { midi += 12 }
            while midi > Music.highestKey { midi -= 12 }
            return Work(slot: Int((note.start / grid).rounded()), length: max(1, Int((note.duration / grid).rounded())),
                        midi: midi, group: note.group, hand: note.hand)
        }

        // --- Hands by group (track / part)
        let openGroups = Set(notes.filter { $0.hand == nil }.map { $0.group })
        func average(_ group: Int) -> Double {
            let pitches = notes.filter { $0.group == group }.map { Double($0.midi) }
            return pitches.reduce(0, +) / Double(max(1, pitches.count))
        }
        var groupHand: [Int: Hand] = [:]
        var splitSingle = false
        let allGroups = Set(notes.map { $0.group })
        if allGroups.count == 1, let only = openGroups.first {
            if raw.isXML { groupHand[only] = average(only) < 55 ? .left : .right } else if let hint = raw.groupNames[only].flatMap(handHint) {
                groupHand[only] = hint
            } else {
                splitSingle = true
            }
        } else if !openGroups.isEmpty {
            for group in openGroups { if let hint = raw.groupNames[group].flatMap(handHint) { groupHand[group] = hint } }
            var rightPitches: [Double] = [], leftPitches: [Double] = []
            for note in notes {
                if let hand = note.hand ?? groupHand[note.group] {
                    if hand == .left { leftPitches.append(Double(note.midi)) } else { rightPitches.append(Double(note.midi)) }
                }
            }
            let unnamed = openGroups.filter { groupHand[$0] == nil }.sorted { average($0) < average($1) }
            var rightAnchor = rightPitches.isEmpty ? nil : rightPitches.reduce(0, +) / Double(rightPitches.count)
            var leftAnchor = leftPitches.isEmpty ? nil : leftPitches.reduce(0, +) / Double(leftPitches.count)
            if rightAnchor == nil, leftAnchor == nil, unnamed.count >= 2 {
                leftAnchor = average(unnamed.first!)
                rightAnchor = average(unnamed.last!)
            }
            for group in unnamed {
                let a = average(group)
                switch (leftAnchor, rightAnchor) {
                case (let l?, let r?): groupHand[group] = abs(a - l) < abs(a - r) ? .left : .right
                case (let l?, nil): groupHand[group] = a > l ? .right : .left
                case (nil, let r?): groupHand[group] = a < r ? .left : .right
                default: groupHand[group] = a < 55 ? .left : .right
                }
            }
        }
        for i in notes.indices where notes[i].hand == nil { notes[i].hand = groupHand[notes[i].group] }

        // --- Group into onsets
        var bySlot: [Int: [Int]] = [:]
        for i in notes.indices { bySlot[notes[i].slot, default: []].append(i) }
        let slots = bySlot.keys.sorted()

        // --- Single track: split around Middle C, but keep each hand near where it has been playing.
        if splitSingle {
            var leftCentre = 48.0, rightCentre = 72.0
            for slot in slots {
                let indices = bySlot[slot]!.sorted { notes[$0].midi < notes[$1].midi }
                var leftCount = 0
                for i in indices {
                    let n = Double(notes[i].midi)
                    let dl = abs(n - leftCentre), dr = abs(n - rightCentre)
                    let isLeft = notes[i].midi >= Music.middleC ? dl + 4 < dr : !(dr + 4 < dl)
                    if isLeft { leftCount += 1 }
                }
                // Hands never interleave inside one chord: the lowest `leftCount` notes go to the left hand.
                for (k, i) in indices.enumerated() {
                    notes[i].hand = k < leftCount ? .left : .right
                    let n = Double(notes[i].midi)
                    if k < leftCount { leftCentre = leftCentre * 0.7 + n * 0.3 } else { rightCentre = rightCentre * 0.7 + n * 0.3 }
                }
            }
        }

        // --- Per onset: remove doubled keys, keep each hand within a 10th.
        var removed: Set<Int> = []
        for slot in slots {
            var seen: [Int: Int] = [:]
            for i in bySlot[slot]! {
                if let kept = seen[notes[i].midi] {
                    notes[kept].length = max(notes[kept].length, notes[i].length)
                    removed.insert(i)
                } else {
                    seen[notes[i].midi] = i
                }
            }
            func hand(_ h: Hand) -> [Int] {
                bySlot[slot]!.filter { !removed.contains($0) && notes[$0].hand == h }.sorted { notes[$0].midi < notes[$1].midi }
            }
            func span(_ indices: [Int]) -> Int { indices.isEmpty ? 0 : notes[indices.last!].midi - notes[indices.first!].midi }
            let limit = 16
            var right = hand(.right)
            while span(right) > limit { notes[right.removeFirst()].hand = .left }
            var left = hand(.left)
            while span(left) > limit { notes[left.removeLast()].hand = .right }
            right = hand(.right)
            while span(right) > limit { removed.insert(right.removeFirst()) }
        }

        // --- Convert to the meter's beat unit and trim leading empty bars.
        var numerator = max(1, raw.numerator)
        var denominator = [1, 2, 4, 8, 16, 32].contains(raw.denominator) ? raw.denominator : 4
        if numerator > 24 { numerator = 4; denominator = 4 }
        let scale = Double(denominator) / 4
        var bpm = raw.bpm * scale
        bpm = min(240, max(30, bpm))
        let bar = Double(numerator)
        let kept = notes.indices.filter { !removed.contains($0) }
        guard !kept.isEmpty else { throw SongImportError.noNotes }
        let first = kept.map { Double(notes[$0].slot) * grid * scale }.min() ?? 0
        let shift = (first / bar + 1e-6).rounded(.down) * bar
        func tidy(_ x: Double) -> Double { (x * 960).rounded() / 960 }
        var out: [ImportedNote] = kept.map { i in
            ImportedNote(beat: tidy(Double(notes[i].slot) * grid * scale - shift),
                         duration: tidy(Double(notes[i].length) * grid * scale),
                         midi: notes[i].midi, left: notes[i].hand == .left)
        }
        out.sort { $0.beat != $1.beat ? $0.beat < $1.beat : $0.midi < $1.midi }

        let base = (filename as NSString).deletingPathExtension
        // The file name is what the user chose, so it wins; names embedded in files are often
        // generic ("control track"). Fall back to the embedded title for generic file names.
        func isGeneric(_ name: String) -> Bool {
            let n = name.lowercased().trimmingCharacters(in: .whitespaces)
            return n.isEmpty || ["score", "xml_score", "untitled", "control track", "conductor", "tempo", "track 0", "track 1", "midi", "song", "export"].contains(n)
        }
        let embedded = raw.title.flatMap { isGeneric($0) ? nil : $0 }
        let title = !isGeneric(base) ? base : (embedded ?? "Imported song")
        return ImportedSong(id: UUID().uuidString, title: title, sourceFile: filename, bpm: bpm,
                            beatsPerBar: numerator, beatUnit: denominator, fifths: min(7, max(-7, raw.fifths)),
                            minor: raw.minor, notes: out)
    }

    // MARK: Events

    /// Chord events for the notes that start inside `range` (beats), shifted so the range starts at 0.
    static func events(for song: ImportedSong, in range: Range<Double>? = nil) -> [ExpectedEvent] {
        var groups: [Int: [ImportedNote]] = [:]
        let lower = range?.lowerBound ?? 0
        let upper = range?.upperBound ?? Double.greatestFiniteMagnitude
        for note in song.notes where note.beat >= lower - 1e-6 && note.beat < upper - 1e-6 {
            groups[Int((note.beat * 960).rounded()), default: []].append(note)
        }
        return groups.keys.sorted().map { key in
            let notes = groups[key]!.sorted { $0.midi < $1.midi }
            let beat = notes[0].beat - lower
            let specs = notes.map { note -> NoteSpec in
                let length = max(0.05, min(note.duration, upper - note.beat))
                return NoteSpec(midi: note.midi, hand: note.hand, finger: nil, duration: length)
            }
            return ExpectedEvent(notes: specs, beat: beat, duration: specs.compactMap { $0.duration }.min() ?? 1)
        }
    }

    // MARK: Self-test

    /// A human-readable summary of what a file imports as (for checking real files by hand).
    static func debugSummary(of url: URL) -> String {
        do {
            let song = try load(url: url)
            let right = song.notes.filter { !$0.left }.count
            let lesson = SongLibrary.lesson(for: song)
            return "\(song.title): \(song.beatsPerBar)/\(song.beatUnit), \(Int(song.bpm)) bpm, fifths \(song.fifths), "
                + "\(song.totalBars) bars, \(right) RH + \(song.notes.count - right) LH notes, \(lesson.steps.count) steps"
        } catch {
            return "FAILED \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }

    /// Parses a small in-memory MIDI file and MusicXML score and checks the result. Prints ok / FAIL lines.
    static func selfTest() -> Bool {
        var failures = 0
        func expect(_ condition: Bool, _ what: String) {
            print(condition ? "  ok    \(what)" : "  FAIL  \(what)")
            if !condition { failures += 1 }
        }
        func vlq(_ value: Int) -> [UInt8] {
            var parts = [UInt8(value & 0x7F)]
            var v = value >> 7
            while v > 0 { parts.insert(UInt8(v & 0x7F) | 0x80, at: 0); v >>= 7 }
            return parts
        }
        func chunk(_ id: String, _ body: [UInt8]) -> [UInt8] {
            let n = body.count
            return Array(id.utf8) + [UInt8(n >> 24 & 0xFF), UInt8(n >> 16 & 0xFF), UInt8(n >> 8 & 0xFF), UInt8(n & 0xFF)] + body
        }

        // --- MIDI: format 1, 480 ppq, tempo 100, 3/4, one flat; right-hand track and left-hand track.
        var t1: [UInt8] = []
        t1 += [0x00, 0xFF, 0x03, 0x05] + Array("Right".utf8)
        t1 += [0x00, 0xFF, 0x51, 0x03, 0x09, 0x27, 0xC0]
        t1 += [0x00, 0xFF, 0x58, 0x04, 0x03, 0x02, 0x18, 0x08]
        t1 += [0x00, 0xFF, 0x59, 0x02, 0xFF, 0x00]
        t1 += [0x00, 0x90, 72, 80]                    // C5 on
        t1 += vlq(470) + [72, 0]                      // C5 off by running status, velocity 0 (slightly short)
        t1 += vlq(10) + [74, 80] + vlq(480) + [74, 0] // D5
        t1 += [0x00, 76, 80, 0x00, 79, 80]            // E5 + G5 chord
        t1 += vlq(480) + [0x80, 76, 0, 0x00, 79, 0]   // real note-offs (running status on the second)
        t1 += [0x00, 0x99, 36, 100, 0x00, 0x89, 36, 0] // drum hit on channel 10: ignored
        t1 += [0x00, 0xFF, 0x2F, 0x00]
        var t2: [UInt8] = []
        t2 += [0x00, 0xFF, 0x03, 0x04] + Array("Left".utf8)
        t2 += [0x00, 0x90, 48, 70] + vlq(1440) + [0x80, 48, 0]
        t2 += [0x00, 0xFF, 0x2F, 0x00]
        let midi = chunk("MThd", [0, 1, 0, 2, 0x01, 0xE0]) + chunk("MTrk", t1) + chunk("MTrk", t2)
        do {
            let song = try parse(data: Data(midi), filename: "Test Waltz.mid")
            let events = SongImport.events(for: song)
            expect(abs(song.bpm - 100) < 0.01, "MIDI tempo 100 (got \(song.bpm))")
            expect(song.beatsPerBar == 3 && song.beatUnit == 4, "MIDI meter 3/4 (got \(song.beatsPerBar)/\(song.beatUnit))")
            expect(song.fifths == -1, "MIDI key signature of one flat")
            expect(song.title == "Test Waltz", "MIDI title falls back to the file name (got \(song.title))")
            expect(song.notes.count == 5, "MIDI has 5 notes, drums ignored (got \(song.notes.count))")
            expect(events.count == 3 && events.map { $0.beat } == [0, 1, 2], "MIDI events on beats 0, 1, 2 (got \(events.map { $0.beat }))")
            if events.count == 3 {
                expect(Set(events[0].notes.map { $0.midi }) == [48, 72], "beat 0 holds C3 and C5 together")
                expect(events[0].notes.first { $0.midi == 48 }?.hand == .left && events[0].notes.first { $0.midi == 72 }?.hand == .right,
                       "track names decide the hands")
                expect(events[0].notes.first { $0.midi == 48 }?.duration == 3 && events[0].notes.first { $0.midi == 72 }?.duration == 1,
                       "per-note durations are kept (quantized)")
                expect(events[2].notes.map { $0.midi } == [76, 79], "chord E5 + G5 on beat 2")
            }
            let lesson = SongLibrary.lesson(for: song)
            expect(lesson.steps.count >= 3, "MIDI song becomes a lesson with \(lesson.steps.count) steps")
        } catch {
            expect(false, "MIDI parses (\(error.localizedDescription))")
        }
        do {
            _ = try parse(data: Data("MThd-nonsense".utf8), filename: "bad.mid")
            expect(false, "corrupt MIDI is rejected")
        } catch {
            expect(true, "corrupt MIDI is rejected: \(error.localizedDescription)")
        }

        // --- MusicXML: two staves, a chord, a tie across the bar line, backups.
        func note(_ pitch: String?, _ duration: Int, staff: Int, chord: Bool = false, tie: String? = nil) -> String {
            var s = "<note>"
            if chord { s += "<chord/>" }
            if let pitch {
                let letter = String(pitch.prefix(1)), octave = String(pitch.suffix(1))
                s += "<pitch><step>\(letter)</step><octave>\(octave)</octave></pitch>"
            } else {
                s += "<rest/>"
            }
            s += "<duration>\(duration)</duration>"
            if let tie { s += "<tie type=\"\(tie)\"/>" }
            s += "<voice>\(staff)</voice><staff>\(staff)</staff></note>"
            return s
        }
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <score-partwise version="3.1">
          <work><work-title>Test Song</work-title></work>
          <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
          <part id="P1">
            <measure number="1">
              <attributes><divisions>2</divisions><key><fifths>-1</fifths></key>
                <time><beats>4</beats><beat-type>4</beat-type></time><staves>2</staves></attributes>
              <direction><sound tempo="90"/></direction>
              \(note("E5", 2, staff: 1))\(note("G5", 2, staff: 1, chord: true))\(note(nil, 2, staff: 1))\(note("C5", 4, staff: 1, tie: "start"))
              <backup><duration>8</duration></backup>
              \(note("F2", 8, staff: 2))
            </measure>
            <measure number="2">
              \(note("C5", 2, staff: 1, tie: "stop"))\(note("D5", 2, staff: 1))\(note(nil, 4, staff: 1))
              <backup><duration>8</duration></backup>
              \(note("G2", 8, staff: 2))
            </measure>
          </part>
        </score-partwise>
        """
        do {
            let song = try parse(data: Data(xml.utf8), filename: "score.musicxml")
            let events = SongImport.events(for: song)
            expect(song.title == "Test Song", "MusicXML title used when the file name is generic (got \(song.title))")
            expect(abs(song.bpm - 90) < 0.01 && song.fifths == -1 && song.beatsPerBar == 4, "MusicXML tempo 90, one flat, 4/4")
            expect(events.map { $0.beat } == [0, 2, 4, 5], "MusicXML events on beats 0, 2, 4, 5 (got \(events.map { $0.beat }))")
            if events.count == 4 {
                expect(events[0].notes.map { $0.midi } == [41, 76, 79], "beat 0 holds F2 with the E5 + G5 chord")
                expect(events[0].notes[0].hand == .left && events[0].notes[1].hand == .right, "staff 2 is the left hand")
                expect(events[1].notes.first?.midi == 72 && events[1].notes.first?.duration == 3, "tied C5 lasts 3 beats")
                expect(events[2].notes.map { $0.midi } == [43], "the tie's second half is not struck again")
            }
            expect(song.notes.count == 6, "MusicXML has 6 notes (got \(song.notes.count))")
            let data = try JSONEncoder().encode(song)
            let back = try JSONDecoder().decode(ImportedSong.self, from: data)
            expect(back.notes == song.notes && back.title == song.title, "song survives a JSON round trip")
        } catch {
            expect(false, "MusicXML parses (\(error.localizedDescription))")
        }
        do {
            _ = try parse(data: Data("<html><body>nope</body></html>".utf8), filename: "bad.xml")
            expect(false, "non-MusicXML is rejected")
        } catch {
            expect(true, "non-MusicXML is rejected: \(error.localizedDescription)")
        }

        // --- Single-track MIDI: split between the hands, wide chords kept within a 10th per hand.
        var single: [UInt8] = []
        single += [0x00, 0x90, 36, 80, 0x00, 60, 80, 0x00, 64, 80, 0x00, 84, 80]
        single += vlq(480) + [0x80, 36, 0, 0x00, 60, 0, 0x00, 64, 0, 0x00, 84, 0, 0x00, 0xFF, 0x2F, 0x00]
        do {
            let song = try parse(data: Data(chunk("MThd", [0, 0, 0, 1, 0x01, 0xE0]) + chunk("MTrk", single)), filename: "one.mid")
            let left = song.notes.filter { $0.left }.map { $0.midi }, right = song.notes.filter { !$0.left }.map { $0.midi }
            let spans = [left, right].map { ($0.max() ?? 0) - ($0.min() ?? 0) }
            expect(!left.isEmpty && !right.isEmpty && spans.allSatisfy { $0 <= 16 }, "single track split into hands within a 10th (LH \(left), RH \(right))")
        } catch {
            expect(false, "single-track MIDI parses (\(error.localizedDescription))")
        }

        print(failures == 0 ? "All song-import checks passed" : "\(failures) song-import check(s) failed")
        return failures == 0
    }
}
