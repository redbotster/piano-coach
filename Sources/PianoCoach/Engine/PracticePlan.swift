import Foundation

struct PlanItem: Identifiable, Codable, Equatable {
    enum Kind: String, Codable { case warmup, new, review, song }
    var id: String { lessonID }
    var lessonID: String
    var kind: Kind
    var reason: String
}

/// Builds the daily session (about 15–20 minutes) and schedules reviews with spaced repetition.
enum PracticePlan {
    static let coreSections = ["foundations", "rhythm", "reading", "technique", "earTraining"]
    static let songSections = ["songs", "mysongs"]
    static let warmupPrefixes = ["technique.major.", "technique.minor.", "technique.basic."]
    static let maxIntervalDays = 60.0

    // MARK: Spaced repetition

    /// SM-2 flavoured: good results push the next review further away, poor ones bring it back.
    static func reschedule(_ record: inout LessonRecord, stars: Int, now: Date) {
        let previous = record.reviewIntervalDays
        let first: Double = stars >= 3 ? 3 : stars == 2 ? 2 : stars == 1 ? 1 : 0
        var interval: Double
        if let last = record.lastPracticed, let previous, Calendar.current.isDate(last, inSameDayAs: now) {
            // Replaying on the same day must not keep multiplying the interval.
            interval = stars >= 2 ? max(previous, first) : first
        } else {
            switch stars {
            case 3...: interval = previous.map { max(first, $0 * 2.5) } ?? first
            case 2: interval = previous.map { max(first, $0 * 1.6) } ?? first
            case 1: interval = 1
            default: interval = 0
            }
        }
        interval = min(maxIntervalDays, interval)
        record.lastPracticed = now
        record.reviewIntervalDays = interval
        record.due = now.addingTimeInterval(interval * 86_400)
    }

    // MARK: Today's plan

    /// What the planner needs to know about one lesson.
    struct Candidate {
        var id: String
        var sectionID: String
        var sectionTitle: String
        var completed: Bool
        var stars: Int
        var due: Date?
        var lastPracticed: Date?
    }

    private struct Cache: Codable {
        var day: String
        var items: [PlanItem]
    }

    /// Set per profile so each person keeps their own plan for the day.
    static var profileKey = ""
    private static var cacheKey: String { "practicePlan.cache" + profileKey }

    private static func dayKey(_ date: Date, _ calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func candidates(app: AppModel) -> [Candidate] {
        var out: [Candidate] = []
        for section in app.sections {
            for unit in section.units {
                for lesson in unit.lessons where !lesson.id.contains(".stub") {
                    let record = app.progress.record(lesson.id)
                    out.append(Candidate(id: lesson.id, sectionID: section.id, sectionTitle: section.title,
                                         completed: record.completed, stars: record.stars, due: record.due,
                                         lastPracticed: record.lastPracticed))
                }
            }
        }
        return out
    }

    /// The plan is fixed for the day once made, so finishing an item ticks it off instead of reshuffling the list.
    /// When everything is ticked, one more new lesson is added.
    static func today(app: AppModel) -> [PlanItem] {
        let now = Date()
        let calendar = Calendar.current
        let key = dayKey(now, calendar)
        let all = candidates(app: app)
        let defaults = UserDefaults.standard

        var items: [PlanItem] = []
        if let data = defaults.data(forKey: cacheKey), let cache = try? JSONDecoder().decode(Cache.self, from: data),
           cache.day == key, !cache.items.isEmpty, cache.items.allSatisfy({ app.lessonIndex[$0.lessonID] != nil }) {
            items = cache.items
        } else {
            items = compose(all, now: now, calendar: calendar)
        }

        let doneToday: (PlanItem) -> Bool = { item in
            if let last = app.progress.record(item.lessonID).lastPracticed, calendar.isDate(last, inSameDayAs: now) { return true }
            return app.history.practiced(item.lessonID, on: now, calendar: calendar)
        }
        if !items.isEmpty, items.count < 8, items.allSatisfy(doneToday) {
            let planned = Set(items.map { $0.lessonID })
            if let extra = compose(all, now: now, calendar: calendar).first(where: { $0.kind == .new && !planned.contains($0.lessonID) }) {
                items.append(PlanItem(lessonID: extra.lessonID, kind: .new, reason: "Bonus — " + lowercasedFirst(extra.reason)))
            }
        }
        if let data = try? JSONEncoder().encode(Cache(day: key, items: items)) { defaults.set(data, forKey: cacheKey) }
        return items
    }

    /// Forget the cached plan (used when progress is reset).
    static func clearCache() { UserDefaults.standard.removeObject(forKey: cacheKey) }

    private static func lowercasedFirst(_ s: String) -> String {
        guard let first = s.first else { return s }
        return first.lowercased() + s.dropFirst()
    }

    private static func ago(_ date: Date?, now: Date, calendar: Calendar) -> String {
        guard let date else { return "not played yet" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ..<1: return "last played today"
        case 1: return "last played yesterday"
        default: return "last played \(days) days ago"
        }
    }

    private static func starText(_ stars: Int) -> String { stars == 1 ? "1 star" : "\(stars) stars" }

    /// Pure planner: lessons in course order in, today's items out.
    static func compose(_ lessons: [Candidate], now: Date, calendar: Calendar = .current) -> [PlanItem] {
        let core = lessons.filter { coreSections.contains($0.sectionID) }
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        var items: [PlanItem] = []
        var used: Set<String> = []
        func add(_ id: String, _ kind: PlanItem.Kind, _ reason: String) {
            guard !used.contains(id) else { return }
            used.insert(id)
            items.append(PlanItem(lessonID: id, kind: kind, reason: reason))
        }

        // A brand-new learner just needs a starting point.
        if !lessons.contains(where: { $0.completed || $0.lastPracticed != nil }) {
            if let first = core.first(where: { $0.sectionID == "foundations" }) ?? core.first ?? lessons.first {
                add(first.id, .new, "Start here — your first lesson")
            }
            return items
        }

        // (a) Warm-up: a scale or basic-technique lesson already learned, rotating daily.
        let warmups = core.filter { c in c.completed && warmupPrefixes.contains { c.id.hasPrefix($0) } }
        if !warmups.isEmpty {
            let dayNumber = calendar.dateComponents([.day], from: Date(timeIntervalSinceReferenceDate: 0), to: calendar.startOfDay(for: now)).day ?? 0
            add(warmups[((dayNumber % warmups.count) + warmups.count) % warmups.count].id, .warmup, "Warm-up — loosen up with something you know")
        }

        // (b) Reviews: due lessons first (most overdue first), then the weakest completed lessons.
        let completed = core.filter { $0.completed && !used.contains($0.id) }
        let due = completed.filter { ($0.due ?? .distantFuture) < endOfToday }
            .sorted { ($0.due ?? .distantPast) < ($1.due ?? .distantPast) }
        let weak = completed.filter { c in c.stars < 3 && !due.contains { $0.id == c.id } }
            .filter { c in !(c.lastPracticed.map { calendar.isDate($0, inSameDayAs: now) } ?? false) }
            .sorted { a, b in
                a.stars != b.stars ? a.stars < b.stars : (a.lastPracticed ?? .distantPast) < (b.lastPracticed ?? .distantPast)
            }
        for c in due.prefix(2) {
            add(c.id, .review, "Due for review — \(ago(c.lastPracticed, now: now, calendar: calendar)), \(starText(c.stars))")
        }
        for c in weak.prefix(max(0, 2 - min(2, due.count))) {
            add(c.id, .review, "Worth another go — \(starText(c.stars)) so far, \(ago(c.lastPracticed, now: now, calendar: calendar))")
        }

        // (c) New material: carry on where the learner last worked, plus one other section for variety.
        let recentSection = core.filter { $0.lastPracticed != nil }
            .max { ($0.lastPracticed ?? .distantPast) < ($1.lastPracticed ?? .distantPast) }?.sectionID ?? coreSections[0]
        let present = coreSections.filter { id in core.contains { $0.sectionID == id } }
        let start = present.firstIndex(of: recentSection) ?? 0
        let rotation = present.isEmpty ? [] : (0..<present.count).map { present[(start + $0) % present.count] }
        var newCount = 0
        for sectionID in rotation where newCount < 2 {
            guard let next = core.first(where: { $0.sectionID == sectionID && !$0.completed && !used.contains($0.id) }) else { continue }
            add(next.id, .new, newCount == 0 ? "Next in \(next.sectionTitle)" : "Something different — next in \(next.sectionTitle)")
            newCount += 1
        }

        // (d) A song: keep going with the latest one, or start the first unfinished one.
        let songs = lessons.filter { songSections.contains($0.sectionID) }
        let latest = songs.filter { $0.lastPracticed != nil }
            .max { ($0.lastPracticed ?? .distantPast) < ($1.lastPracticed ?? .distantPast) }
        if let latest, !(latest.completed && latest.stars >= 3) {
            add(latest.id, .song, "Keep polishing your song — \(ago(latest.lastPracticed, now: now, calendar: calendar))")
        } else if let next = songs.first(where: { !$0.completed }) {
            add(next.id, .song, latest == nil ? "Finish with a song" : "A new song to learn")
        } else if let latest {
            add(latest.id, .song, "Play a favourite to finish")
        }
        return items
    }

    // MARK: Self-test

    /// Checks the scheduling and planning logic with synthetic data. Wire into `--selftest`.
    static func selfTest() -> Bool {
        var failures = 0
        func expect(_ condition: Bool, _ what: String) {
            print(condition ? "  ok    \(what)" : "  FAIL  \(what)")
            if !condition { failures += 1 }
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let day0 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 18))!
        func day(_ n: Int) -> Date { calendar.date(byAdding: .day, value: n, to: day0)! }

        // Intervals
        var r = LessonRecord()
        reschedule(&r, stars: 3, now: day(0))
        expect(r.reviewIntervalDays == 3 && r.lastPracticed == day(0), "first 3-star review is due in 3 days")
        reschedule(&r, stars: 3, now: day(0))
        expect(r.reviewIntervalDays == 3, "replaying the same day does not stretch the interval")
        reschedule(&r, stars: 3, now: day(3))
        expect(r.reviewIntervalDays == 7.5, "3 stars multiplies the interval by 2.5")
        reschedule(&r, stars: 2, now: day(11))
        expect(abs((r.reviewIntervalDays ?? 0) - 12) < 0.001, "2 stars multiplies by 1.6")
        reschedule(&r, stars: 1, now: day(23))
        expect(r.reviewIntervalDays == 1, "1 star comes back tomorrow")
        reschedule(&r, stars: 0, now: day(24))
        expect(r.reviewIntervalDays == 0 && (r.due ?? .distantFuture) <= day(24), "0 stars is due again straight away")
        for i in 0..<8 { reschedule(&r, stars: 3, now: day(30 + i * 70)) }
        expect(r.reviewIntervalDays == maxIntervalDays, "interval is capped at 60 days")
        var two = LessonRecord()
        reschedule(&two, stars: 2, now: day(0))
        expect(two.reviewIntervalDays == 2, "first 2-star review is due in 2 days")

        // History helpers
        let t = day(0)
        let minutes = HistoryStore.minutes([t, t.addingTimeInterval(120), t.addingTimeInterval(240), t.addingTimeInterval(4000)])
        expect(abs(minutes - (45 + 240 + 45) / 60.0) < 0.001, "practice minutes ignore long gaps")
        let days: Set<Date> = [day(0), day(-1), day(-2), day(-4)]
        expect(HistoryStore.streak(days: days, now: day(0), calendar: calendar) == 3, "streak counts consecutive days")
        expect(HistoryStore.streak(days: days, now: day(1), calendar: calendar) == 3, "streak survives until the end of the next day")
        expect(HistoryStore.streak(days: days, now: day(2), calendar: calendar) == 0, "streak breaks after a missed day")
        let attempts = [0, 0, 1, 9].map { Attempt(date: day($0), lessonID: "x", step: 0, accuracy: $0 == 9 ? 0.5 : 1, timingMs: 20, evenness: nil, bpm: nil, stars: 2, passed: true) }
        let daily = HistoryStore.buckets(attempts, weekly: false, since: nil, calendar: calendar)
        expect(daily.count == 3 && daily.first?.attempts == 2 && daily.last?.accuracy == 0.5, "attempts bucket by day")
        expect(HistoryStore.buckets(attempts, weekly: false, since: day(1), calendar: calendar).count == 2, "buckets respect the start date")

        // Planner
        func make(_ id: String, _ section: String, done: Bool = false, stars: Int = 0, due: Int? = nil, last: Int? = nil) -> Candidate {
            Candidate(id: id, sectionID: section, sectionTitle: section.capitalized, completed: done, stars: stars,
                      due: due.map { day($0) }, lastPracticed: last.map { day($0) })
        }
        let fresh = [make("foundations.a", "foundations"), make("rhythm.a", "rhythm"), make("songs.a", "songs")]
        let first = compose(fresh, now: day(0), calendar: calendar)
        expect(first.count == 1 && first.first?.lessonID == "foundations.a", "a new learner gets the first Foundations lesson only")

        let course = [
            make("foundations.a", "foundations", done: true, stars: 3, due: 5, last: -2),
            make("foundations.b", "foundations", done: true, stars: 1, due: -1, last: -3),
            make("foundations.c", "foundations", done: true, stars: 2, due: -4, last: -6),
            make("foundations.d", "foundations"),
            make("rhythm.a", "rhythm", done: true, stars: 2, due: 9, last: -1),
            make("rhythm.b", "rhythm"),
            make("reading.a", "reading"),
            make("technique.basic.x", "technique", done: true, stars: 3, due: 20, last: -5),
            make("technique.major.c", "technique", done: true, stars: 3, due: 20, last: -5),
            make("technique.modes.d", "technique"),
            make("songs.a", "songs", done: true, stars: 2, last: -8),
            make("mysongs.b", "mysongs", last: -1),
        ]
        let plan = compose(course, now: day(0), calendar: calendar)
        let ids = plan.map { $0.lessonID }
        expect(plan.first?.kind == .warmup && ["technique.basic.x", "technique.major.c"].contains(ids.first ?? ""), "plan opens with a completed warm-up")
        let reviews = plan.filter { $0.kind == .review }.map { $0.lessonID }
        expect(reviews == ["foundations.c", "foundations.b"], "reviews are the due lessons, most overdue first")
        let new = plan.filter { $0.kind == .new }.map { $0.lessonID }
        expect(new == ["rhythm.b", "reading.a"], "new lessons continue the latest section, then a different one")
        expect(plan.last?.kind == .song && plan.last?.lessonID == "mysongs.b", "plan ends with the most recently practised song")
        expect(Set(ids).count == ids.count && (4...6).contains(ids.count), "plan has 4–6 distinct items (\(ids.count))")
        expect(compose(course, now: day(0), calendar: calendar) == plan, "plan is deterministic for a given day")
        let tomorrow = compose(course, now: day(1), calendar: calendar)
        expect(tomorrow.first?.lessonID != plan.first?.lessonID, "warm-up rotates from day to day")

        var noneDue = course
        for i in noneDue.indices { noneDue[i].due = day(30) }
        let filler = compose(noneDue, now: day(0), calendar: calendar).filter { $0.kind == .review }.map { $0.lessonID }
        expect(filler == ["foundations.b", "foundations.c"], "with nothing due, the weakest lessons are reviewed")

        print(failures == 0 ? "All practice-plan checks passed" : "\(failures) practice-plan check(s) failed")
        return failures == 0
    }
}
