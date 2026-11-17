import Foundation

/// One scored attempt at a lesson step.
struct Attempt: Codable {
    var date: Date
    var lessonID: String
    var step: Int
    var accuracy: Double
    var timingMs: Double?
    var evenness: Double?
    var bpm: Double?
    var stars: Int
    var passed: Bool
}

/// Append-only log of attempts, used for progress charts. (Stub: replaced by the full implementation.)
final class HistoryStore: ObservableObject {
    @Published private(set) var attempts: [Attempt] = []
    func record(_ attempt: Attempt) { attempts.append(attempt) }
    func reset() { attempts = [] }
}
