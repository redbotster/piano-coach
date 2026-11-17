import Foundation

/// One person using the app. Each profile has its own progress, history and practice plan.
struct Profile: Codable, Identifiable, Equatable {
    var id: String
    var name: String
}

/// The list of household profiles and where each one's data lives.
final class ProfileStore: ObservableObject {
    @Published private(set) var profiles: [Profile] = []
    @Published private(set) var currentID: String = ""

    private let root: URL
    private var indexURL: URL { root.appendingPathComponent("profiles.json") }

    private struct Index: Codable {
        var profiles: [Profile]
        var current: String
    }

    /// `root` is the app's Application Support folder (overridable for tests).
    init(root: URL = ProfileStore.defaultRoot) {
        self.root = root
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: indexURL), let index = try? JSONDecoder().decode(Index.self, from: data),
           !index.profiles.isEmpty {
            profiles = index.profiles
            currentID = index.profiles.contains { $0.id == index.current } ? index.current : index.profiles[0].id
        } else {
            // First launch with profiles: adopt any existing single-user data.
            let first = Profile(id: UUID().uuidString, name: "Me")
            profiles = [first]
            currentID = first.id
            let folder = self.folder(for: first.id)
            for file in ["progress.json", "history.json"] {
                let old = root.appendingPathComponent(file)
                if FileManager.default.fileExists(atPath: old.path) {
                    try? FileManager.default.moveItem(at: old, to: folder.appendingPathComponent(file))
                }
            }
            save()
        }
    }

    static var defaultRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PianoCoach", isDirectory: true)
    }

    var current: Profile { profiles.first { $0.id == currentID } ?? profiles[0] }

    func folder(for id: String) -> URL {
        let url = root.appendingPathComponent("Profiles", isDirectory: true).appendingPathComponent(id, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    var progressURL: URL { folder(for: currentID).appendingPathComponent("progress.json") }
    var historyURL: URL { folder(for: currentID).appendingPathComponent("history.json") }

    private func save() {
        if let data = try? JSONEncoder().encode(Index(profiles: profiles, current: currentID)) {
            try? data.write(to: indexURL, options: .atomic)
        }
    }

    private func cleaned(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return String((trimmed.isEmpty ? "Player \(profiles.count + 1)" : trimmed).prefix(30))
    }

    @discardableResult
    func add(name: String) -> Profile {
        let profile = Profile(id: UUID().uuidString, name: cleaned(name))
        profiles.append(profile)
        currentID = profile.id
        save()
        return profile
    }

    func select(_ id: String) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        currentID = id
        save()
    }

    func rename(_ id: String, to name: String) {
        guard let i = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[i].name = cleaned(name)
        save()
    }

    /// Deletes a profile and its data. The last remaining profile cannot be deleted.
    func delete(_ id: String) {
        guard profiles.count > 1, let i = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles.remove(at: i)
        try? FileManager.default.removeItem(at: root.appendingPathComponent("Profiles").appendingPathComponent(id))
        if currentID == id { currentID = profiles[0].id }
        save()
    }

    static func selfTest() -> Bool {
        var failures = 0
        func expect(_ ok: Bool, _ what: String) { print(ok ? "  ok    \(what)" : "  FAIL  \(what)"); if !ok { failures += 1 } }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("pianocoach-profiles-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try? Data("{\"old.lesson\":{\"completed\":true,\"stars\":2,\"stepStars\":{},\"bestBPM\":{}}}".utf8)
            .write(to: root.appendingPathComponent("progress.json"))

        let store = ProfileStore(root: root)
        expect(store.profiles.count == 1, "first launch creates one profile")
        let migrated = ProgressStore(url: store.progressURL)
        expect(migrated.record("old.lesson").stars == 2, "existing progress moves into the first profile")

        let firstID = store.currentID
        let second = store.add(name: "  Sam ")
        expect(second.name == "Sam" && store.currentID == second.id, "adding a profile switches to it")
        let fresh = ProgressStore(url: store.progressURL)
        expect(!fresh.record("old.lesson").completed, "a new profile starts with no progress")
        fresh.update("new.lesson") { $0.completed = true }

        store.select(firstID)
        expect(ProgressStore(url: store.progressURL).record("old.lesson").completed, "switching back restores the first profile's progress")
        expect(!ProgressStore(url: store.progressURL).record("new.lesson").completed, "profiles do not share progress")

        let reloaded = ProfileStore(root: root)
        expect(reloaded.profiles.count == 2 && reloaded.currentID == firstID, "profiles persist across launches")
        reloaded.delete(second.id)
        expect(reloaded.profiles.count == 1, "a profile can be deleted")
        reloaded.delete(firstID)
        expect(reloaded.profiles.count == 1, "the last profile cannot be deleted")
        // Manual completion marks persist and can be cleared.
        let marks = ProgressStore(url: reloaded.progressURL)
        marks.update("some.lesson") { $0.completed = true; $0.stars = 2 }
        expect(ProgressStore(url: reloaded.progressURL).record("some.lesson").completed, "marking a lesson complete is saved")
        marks.update("some.lesson") { $0.completed = false }
        let cleared = ProgressStore(url: reloaded.progressURL).record("some.lesson")
        expect(!cleared.completed && cleared.stars == 2, "unmarking keeps the stars already earned")
        print(failures == 0 ? "All profile checks passed" : "\(failures) profile check(s) failed")
        return failures == 0
    }
}
