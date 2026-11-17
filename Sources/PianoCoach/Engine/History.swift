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

/// Practice totals for one calendar day (or one week, when bucketed).
struct PracticeBucket: Identifiable {
    var id: Date { start }
    var start: Date
    var attempts: Int
    var minutes: Double
    var accuracy: Double?
    var timingMs: Double?
    var evenness: Double?
}

/// Append-only log of attempts, used for the practice plan and progress charts.
final class HistoryStore: ObservableObject {
    @Published private(set) var attempts: [Attempt] = []

    static let maxAttempts = 20_000

    private let url: URL?
    private var saveWork: DispatchWorkItem?

    /// `url: nil` keeps the log in memory only (tests, previews).
    init(url: URL? = HistoryStore.defaultURL) {
        self.url = url
        guard let url, let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Attempt].self, from: data) else { return }
        attempts = decoded.sorted { $0.date < $1.date }
    }

    static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PianoCoach", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("history.json")
    }

    func record(_ attempt: Attempt) {
        attempts.append(attempt)
        if attempts.count > Self.maxAttempts { attempts.removeFirst(attempts.count - Self.maxAttempts) }
        scheduleSave()
    }

    func reset() {
        attempts = []
        saveWork?.cancel()
        if let url { try? FileManager.default.removeItem(at: url) }
    }

    /// Writes are debounced so a burst of quiz rounds costs one disk write.
    private func scheduleSave() {
        guard url != nil else { return }
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    func saveNow() {
        saveWork?.cancel()
        guard let url, let data = try? JSONEncoder().encode(attempts) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: Queries

    func attempts(on day: Date, calendar: Calendar = .current) -> [Attempt] {
        attempts.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }

    func practiced(_ lessonID: String, on day: Date, calendar: Calendar = .current) -> Bool {
        // Recent attempts are at the end, so search backwards and stop once we pass the day.
        let start = calendar.startOfDay(for: day)
        for attempt in attempts.reversed() {
            if attempt.date < start { return false }
            if attempt.lessonID == lessonID, calendar.isDate(attempt.date, inSameDayAs: day) { return true }
        }
        return false
    }

    func minutes(on day: Date, calendar: Calendar = .current) -> Double {
        Self.minutes(attempts(on: day, calendar: calendar).map { $0.date })
    }

    var practiceDays: Set<Date> {
        let calendar = Calendar.current
        return Set(attempts.map { calendar.startOfDay(for: $0.date) })
    }

    func streak(now: Date = Date()) -> Int {
        Self.streak(days: practiceDays, now: now)
    }

    var totalMinutes: Double {
        buckets(weekly: false).reduce(0) { $0 + $1.minutes }
    }

    /// Attempts grouped per day (or per week), oldest first. Days without practice are omitted.
    func buckets(weekly: Bool, since: Date? = nil, calendar: Calendar = .current) -> [PracticeBucket] {
        Self.buckets(attempts, weekly: weekly, since: since, calendar: calendar)
    }

    // MARK: Pure helpers (unit-testable)

    /// Estimated practice time: gaps under five minutes count as continuous playing,
    /// and every separate sitting gets 45 seconds for the attempt that opened it.
    static func minutes(_ dates: [Date]) -> Double {
        let sorted = dates.sorted()
        var seconds = 0.0
        for i in sorted.indices {
            let gap = i == 0 ? .infinity : sorted[i].timeIntervalSince(sorted[i - 1])
            seconds += gap < 300 ? gap : 45
        }
        return seconds / 60
    }

    /// Consecutive practice days ending today, or yesterday if today has no practice yet.
    static func streak(days: Set<Date>, now: Date, calendar: Calendar = .current) -> Int {
        let normalized = Set(days.map { calendar.startOfDay(for: $0) })
        var day = calendar.startOfDay(for: now)
        if !normalized.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day), normalized.contains(yesterday) else { return 0 }
            day = yesterday
        }
        var count = 0
        while normalized.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    static func buckets(_ attempts: [Attempt], weekly: Bool, since: Date?, calendar: Calendar = .current) -> [PracticeBucket] {
        func key(_ date: Date) -> Date {
            if weekly, let week = calendar.dateInterval(of: .weekOfYear, for: date) { return week.start }
            return calendar.startOfDay(for: date)
        }
        var groups: [Date: [Attempt]] = [:]
        for attempt in attempts where since == nil || attempt.date >= since! {
            groups[key(attempt.date), default: []].append(attempt)
        }
        func average(_ values: [Double]) -> Double? {
            values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        }
        return groups.keys.sorted().map { start in
            let group = groups[start] ?? []
            // Minutes are summed per day so a weekly bucket doesn't bridge overnight gaps.
            var perDay: [Date: [Date]] = [:]
            for attempt in group { perDay[calendar.startOfDay(for: attempt.date), default: []].append(attempt.date) }
            let minutes = perDay.values.reduce(0) { $0 + Self.minutes($1) }
            return PracticeBucket(start: start, attempts: group.count, minutes: minutes,
                                  accuracy: average(group.map { $0.accuracy }),
                                  timingMs: average(group.compactMap { $0.timingMs }),
                                  evenness: average(group.compactMap { $0.evenness }))
        }
    }
}
