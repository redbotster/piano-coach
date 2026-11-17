import Foundation

/// Songs the user imported from MIDI / MusicXML files, stored in Application Support and shown as "My Songs".
final class SongLibrary: ObservableObject {
    @Published private(set) var songs: [ImportedSong] = []

    private var lessons: [String: Lesson] = [:]
    private let directory: URL

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PianoCoach", isDirectory: true)
            .appendingPathComponent("Songs", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        let files = (try? FileManager.default.contentsOfDirectory(at: self.directory, includingPropertiesForKeys: [.creationDateKey])) ?? []
        var loaded: [(Date, ImportedSong)] = []
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file), let song = try? JSONDecoder().decode(ImportedSong.self, from: data),
                  !song.notes.isEmpty else { continue }
            let created = (try? file.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            loaded.append((created ?? Date.distantPast, song))
        }
        songs = loaded.sorted { $0.0 < $1.0 }.map { $0.1 }
    }

    /// Imports a file, stores it, and returns the id of the lesson created for it.
    @discardableResult
    func importFile(at url: URL) throws -> String {
        let song = try SongImport.load(url: url)
        let data = try JSONEncoder().encode(song)
        try data.write(to: directory.appendingPathComponent("\(song.id).json"), options: .atomic)
        songs.append(song)
        return song.lessonID
    }

    /// Accepts either the song id or its lesson id ("mysongs.<id>").
    func remove(id: String) {
        let songID = id.hasPrefix("mysongs.") ? String(id.dropFirst("mysongs.".count)) : id
        guard songs.contains(where: { $0.id == songID }) else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("\(songID).json"))
        lessons[songID] = nil
        songs.removeAll { $0.id == songID }
    }

    func contains(_ lessonID: String) -> Bool {
        songs.contains { $0.lessonID == lessonID }
    }

    /// The "My Songs" sidebar section, or nil when nothing has been imported.
    var section: CurriculumSection? {
        guard !songs.isEmpty else { return nil }
        let all = songs.map { song -> Lesson in
            if let cached = lessons[song.id] { return cached }
            let built = Self.lesson(for: song)
            lessons[song.id] = built
            return built
        }
        return CurriculumSection(id: "mysongs", title: "My Songs", symbol: "music.note.house",
                                 units: [CurriculumUnit(id: "mysongs.all", title: "Imported songs", lessons: all)])
    }

    // MARK: - Lesson generation

    private static let majorKeys = ["C♭", "G♭", "D♭", "A♭", "E♭", "B♭", "F", "C", "G", "D", "A", "E", "B", "F♯", "C♯"]
    private static let minorKeys = ["A♭", "E♭", "B♭", "F", "C", "G", "D", "A", "E", "B", "F♯", "C♯", "G♯", "D♯", "A♯"]

    static func keyName(_ song: ImportedSong) -> String {
        let i = min(14, max(0, song.fifths + 7))
        switch song.minor {
        case .some(true): return "\(minorKeys[i]) minor"
        case .some(false): return "\(majorKeys[i]) major"
        case .none: return "\(majorKeys[i]) major / \(minorKeys[i]) minor"
        }
    }

    static func signatureText(_ fifths: Int) -> String {
        if fifths == 0 { return "no sharps or flats" }
        let n = abs(fifths)
        return "\(n) \(fifths > 0 ? "sharp" : "flat")\(n == 1 ? "" : "s")"
    }

    /// Bar numbers (0-based, end exclusive) of practice sections of roughly 4–8 bars, at most 64 beats each.
    static func sections(for song: ImportedSong) -> [Range<Int>] {
        let bar = Double(song.beatsPerBar)
        let totalBars = song.totalBars
        let maxBars = max(1, min(8, Int(64 / bar)))
        let minBars = min(4, maxBars)
        let notes = song.notes

        func score(_ start: Int, _ end: Int) -> Double {
            let boundary = Double(end) * bar
            let before = notes.filter { $0.beat < boundary - 1e-6 }
            guard let lastEnd = before.map({ $0.beat + $0.duration }).max(), let lastOnset = before.map({ $0.beat }).max() else { return 0 }
            let silence = boundary - lastEnd
            let lastLength = before.filter { abs($0.beat - lastOnset) < 1e-6 }.map { $0.duration }.max() ?? 0
            var value = silence < -0.01 ? -2 : min(silence, 2)
            value += min(lastLength, 4) * 0.5
            if (end - start) % 4 == 0 { value += 0.6 }
            if end - start == 8 { value += 0.1 }
            return value
        }

        var result: [Range<Int>] = []
        var start = 0
        while start < totalBars {
            var end: Int
            if totalBars - start <= maxBars {
                end = totalBars
            } else {
                end = start + minBars
                var best = -Double.infinity
                for candidate in (start + minBars)...(start + maxBars) {
                    let s = score(start, candidate)
                    if s > best + 1e-9 { best = s; end = candidate }
                }
                // Don't strand a one-bar tail.
                if totalBars - end == 1, end - start < maxBars { end = totalBars }
                else if totalBars - end == 1 { end -= 1 }
            }
            end = max(start + 1, end)
            result.append(start..<end)
            start = end
        }
        return result
    }

    static func lesson(for song: ImportedSong) -> Lesson {
        let bar = Double(song.beatsPerBar)
        let totalBars = song.totalBars
        let meter = (song.beatsPerBar, song.beatUnit)
        let accents: [Int] = song.beatUnit >= 8 && song.beatsPerBar % 3 == 0 && song.beatsPerBar >= 6
            ? Array(stride(from: 0, to: song.beatsPerBar, by: 3)) : [0]
        let hasLeft = song.notes.contains { $0.left }
        let hasRight = song.notes.contains { !$0.left }
        func tempo(_ factor: Double) -> Double { min(240, max(30, (song.bpm * factor).rounded())) }
        let beatName = [1: "whole", 2: "half", 4: "quarter", 8: "eighth", 16: "sixteenth"][song.beatUnit] ?? "beat"

        func task(_ title: String, _ text: String, bars: Range<Int>, factor: Double) -> Step? {
            let range = Double(bars.lowerBound) * bar..<Double(bars.upperBound) * bar
            let events = SongImport.events(for: song, in: range)
            guard !events.isEmpty else { return nil }
            return L.timed(title, text, events, bpm: tempo(factor), meter: meter, accentBeats: accents,
                           totalBeats: range.upperBound - range.lowerBound, display: .staff, key: song.fifths,
                           pass: 0.8, toleranceMs: 130)
        }

        var body = "**\(song.title)** — imported from *\(song.sourceFile)*.\n\n"
        body += "- **Key:** \(keyName(song)) (\(signatureText(song.fifths)))\n"
        body += "- **Meter:** \(song.beatsPerBar)/\(song.beatUnit)\n"
        body += "- **Tempo:** \(Int(song.bpm.rounded())) \(beatName)-note beats per minute\n"
        body += "- **Length:** \(totalBars) bar\(totalBars == 1 ? "" : "s")\n"
        if !(hasLeft && hasRight) {
            body += "- **Hands:** this file has a part for the **\(hasLeft ? "left" : "right") hand only**\n"
        }
        body += "\nThe song is split into short sections at a slow tempo, followed by the whole song.\n\n"
        body += "How to practise each section:\n\n"
        if hasLeft && hasRight {
            body += "- Use the **hand selector** under the task to learn the right hand, then the left, then both\n"
        }
        body += "- Turn on **wait mode** to have the music pause until you find each note\n"
        body += "- **Loop** a difficult bar and raise the tempo with the BPM − / + buttons as it gets clean\n"
        body += "- Press **Demo** to hear a section before you play it"

        var steps: [Step] = [L.info("About this song", body)]
        let parts = sections(for: song)
        if parts.count > 1 {
            for part in parts {
                let title = part.count == 1 ? "Bar \(part.lowerBound + 1)" : "Bars \(part.lowerBound + 1)–\(part.upperBound)"
                if let step = task(title, "Slow practice tempo. Read ahead and keep going with the metronome.", bars: part, factor: 0.6) {
                    steps.append(step)
                }
            }
        }
        // Whole song, in as many pieces as needed to keep each task at 200 beats or fewer.
        let maxBarsPerTask = max(1, Int(200 / bar))
        let pieces = Int((Double(totalBars) / Double(maxBarsPerTask)).rounded(.up))
        let barsPerPiece = Int((Double(totalBars) / Double(max(1, pieces))).rounded(.up))
        for (label, factor) in [("75% tempo", 0.75), ("full tempo", 1.0)] {
            if parts.count == 1, factor == 0.75 {
                if let step = task("Full song — slow", "The whole song at a slow practice tempo.", bars: 0..<totalBars, factor: 0.6) { steps.append(step) }
            }
            for piece in 0..<max(1, pieces) {
                let range = piece * barsPerPiece..<min(totalBars, (piece + 1) * barsPerPiece)
                guard !range.isEmpty else { continue }
                let title = pieces <= 1 ? "Full song — \(label)"
                    : "Part \(piece + 1) of \(pieces) (bars \(range.lowerBound + 1)–\(range.upperBound)) — \(label)"
                let text = factor < 1 ? "Everything joined together, a little under tempo." : "Performance tempo. Enjoy it!"
                if let step = task(title, text, bars: range, factor: factor) { steps.append(step) }
            }
        }
        let summary = "\(keyName(song)), \(song.beatsPerBar)/\(song.beatUnit), \(totalBars) bars"
        return Lesson(id: song.lessonID, title: song.title, summary: summary, steps: steps)
    }
}
