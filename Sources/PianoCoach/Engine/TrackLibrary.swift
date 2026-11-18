import Foundation

/// Recordings imported to sing along with, kept in Application Support and shown as "My Tracks".
final class TrackLibrary: ObservableObject {
    @Published private(set) var tracks: [VoiceTrack] = []

    private var lessons: [String: Lesson] = [:]
    let directory: URL

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PianoCoach", isDirectory: true)
            .appendingPathComponent("Tracks", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        let files = (try? FileManager.default.contentsOfDirectory(at: self.directory, includingPropertiesForKeys: [.creationDateKey])) ?? []
        var loaded: [(Date, VoiceTrack)] = []
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file), let track = try? JSONDecoder().decode(VoiceTrack.self, from: data),
                  FileManager.default.fileExists(atPath: self.directory.appendingPathComponent(track.audioFile).path) else { continue }
            let created = (try? file.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? nil
            loaded.append((created ?? Date.distantPast, track))
        }
        tracks = loaded.sorted { $0.0 < $1.0 }.map { $0.1 }
    }

    func audioURL(_ track: VoiceTrack) -> URL { directory.appendingPathComponent(track.audioFile) }

    /// Analyse a recording and copy it into the library. Slow: call off the main thread, then `add` on it.
    func prepare(_ url: URL, progress: ((Double) -> Void)? = nil) throws -> VoiceTrack {
        let result = try TrackAnalyzer.analyze(url: url, progress: progress)
        let id = UUID().uuidString.prefix(8).lowercased()
        let ext = url.pathExtension.isEmpty ? "audio" : url.pathExtension.lowercased()
        let audioFile = "\(id).\(ext)"
        try FileManager.default.copyItem(at: url, to: directory.appendingPathComponent(audioFile))
        let track = VoiceTrack(id: String(id), title: url.deletingPathExtension().lastPathComponent, audioFile: audioFile,
                               sourceFile: url.lastPathComponent, duration: result.duration, keyTonic: result.keyTonic,
                               minor: result.minor, keyConfidence: result.keyConfidence, tuningCents: result.tuningCents,
                               notes: result.notes)
        try JSONEncoder().encode(track).write(to: directory.appendingPathComponent("\(id).json"), options: .atomic)
        return track
    }

    func add(_ track: VoiceTrack) { tracks.append(track) }

    /// Accepts either the track id or its lesson id ("mytracks.<id>").
    func remove(id: String) {
        let trackID = id.hasPrefix("mytracks.") ? String(id.dropFirst("mytracks.".count)) : id
        guard let track = tracks.first(where: { $0.id == trackID }) else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("\(trackID).json"))
        try? FileManager.default.removeItem(at: audioURL(track))
        lessons[trackID] = nil
        tracks.removeAll { $0.id == trackID }
    }

    func contains(_ lessonID: String) -> Bool { tracks.contains { $0.lessonID == lessonID } }

    /// The "My Tracks" sidebar section, or nil when nothing has been imported.
    var section: CurriculumSection? {
        guard !tracks.isEmpty else { return nil }
        let all = tracks.map { track -> Lesson in
            if let cached = lessons[track.id] { return cached }
            let built = Self.lesson(for: track, audio: audioURL(track))
            lessons[track.id] = built
            return built
        }
        return CurriculumSection(id: "mytracks", title: "My Tracks", symbol: "waveform.and.mic",
                                 units: [CurriculumUnit(id: "mytracks.all", title: "Sing along", lessons: all)])
    }

    static func lesson(for track: VoiceTrack, audio: URL) -> Lesson {
        let minutes = Int(track.duration) / 60, seconds = Int(track.duration) % 60
        let pitches = track.notes.map { $0.midi }
        var text = "Imported from *\(track.sourceFile)* — \(minutes):\(String(format: "%02d", seconds)) long.\n\n"
        text += "- **Key:** \(track.keyName)\(track.keyConfidence < 0.25 ? " (not certain)" : "")\n"
        if let low = pitches.min(), let high = pitches.max() {
            text += "- **Sung line:** \(track.notes.count) notes, from \(Music.name(low)) to \(Music.name(high))\n"
        } else {
            text += "- **Sung line:** no clear melody was found in this recording\n"
        }
        if abs(track.tuningCents) >= 15 {
            text += "- **Tuning:** the recording is about \(Int(abs(track.tuningCents).rounded())) cents \(track.tuningCents > 0 ? "sharp" : "flat") of concert pitch; the notes allow for that\n"
        }
        text += "\nThe notes were worked out by listening for the most prominent pitched sound, which is usually the lead voice. "
        text += "Expect some wrong or missing notes, most often where instruments play alone or the mix is busy. "
        text += "**Wear headphones** so the microphone hears only you. Singing an octave lower or higher counts."
        let task = SingTask(title: track.title, instructions: text, kind: .track, pass: 0.5,
                            track: TrackRef(track: track, audio: audio))
        return Lesson(id: track.lessonID, title: track.title,
                      summary: "Sing along with your recording (\(track.keyName))", steps: [.sing(task)])
    }
}
