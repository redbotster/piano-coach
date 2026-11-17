import Foundation

struct PlanItem: Identifiable {
    enum Kind { case warmup, new, review }
    var id: String { lessonID }
    var lessonID: String
    var kind: Kind
    var reason: String
}

/// Builds the daily session and schedules reviews. (Stub: replaced by the full implementation.)
enum PracticePlan {
    static func today(app: AppModel) -> [PlanItem] { [] }
    static func reschedule(_ record: inout LessonRecord, stars: Int, now: Date) { record.lastPracticed = now }
}
