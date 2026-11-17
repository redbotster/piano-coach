import Foundation

/// Songs the user imported from MIDI / MusicXML files. (Stub: replaced by the full implementation.)
final class SongLibrary: ObservableObject {
    /// Imports a file, stores it, and returns the id of the lesson created for it.
    func importFile(at url: URL) throws -> String { throw CocoaError(.fileReadUnsupportedScheme) }
    func remove(id: String) {}
    func contains(_ lessonID: String) -> Bool { false }
    /// The "My Songs" sidebar section, or nil when nothing has been imported.
    var section: CurriculumSection? { nil }
}
