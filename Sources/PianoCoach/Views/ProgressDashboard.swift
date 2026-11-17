import Charts
import SwiftUI

/// Progress over time: totals, charts of practice and accuracy, best tempos, and weak spots.
struct ProgressDashboard: View {
    @EnvironmentObject var app: AppModel

    var body: some View {
        ScrollView {
            ProgressContent(app: app, history: app.history, progress: app.progress)
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

enum ProgressRange: String, CaseIterable, Identifiable {
    case month = "30 days", quarter = "12 weeks", all = "All time"
    var id: String { rawValue }
}

struct ProgressContent: View {
    @ObservedObject var app: AppModel
    @ObservedObject var history: HistoryStore
    @ObservedObject var progress: ProgressStore
    @State var range: ProgressRange = .month
    @State private var showMinutes = true

    private var allLessons: [Lesson] { app.sections.flatMap { $0.units.flatMap { $0.lessons } } }

    private var buckets: [PracticeBucket] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        switch range {
        case .month:
            return history.buckets(weekly: false, since: calendar.date(byAdding: .day, value: -29, to: today))
        case .quarter:
            return history.buckets(weekly: true, since: calendar.date(byAdding: .weekOfYear, value: -11, to: today))
        case .all:
            // Daily points get crowded after a couple of months.
            let span = history.attempts.first.map { today.timeIntervalSince($0.date) / 86_400 } ?? 0
            return history.buckets(weekly: span > 60, since: nil)
        }
    }

    private var unit: Calendar.Component { range == .month ? .day : (buckets.count > 1 && isWeekly ? .weekOfYear : .day) }
    private var isWeekly: Bool {
        if range == .quarter { return true }
        if range == .month { return false }
        let span = history.attempts.first.map { Date().timeIntervalSince($0.date) / 86_400 } ?? 0
        return span > 60
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Progress").font(.largeTitle.weight(.bold))
            tiles
            if history.attempts.isEmpty {
                emptyState
            } else {
                charts
            }
            HStack(alignment: .top, spacing: 14) {
                sectionBreakdown
                bestTempos
            }
            weakest
        }
    }

    // MARK: Tiles

    private var tiles: some View {
        let lessons = allLessons
        let completed = lessons.filter { progress.record($0.id).completed }
        let stars = completed.filter { $0.steps.contains { $0.isScored } }.reduce(0) { $0 + progress.record($1.id).stars }
        let minutes = history.totalMinutes
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            tile("Lessons completed", "\(completed.count)", "of \(lessons.count)", "checkmark.seal.fill", Palette.good)
            tile("Stars earned", "\(stars)", "across scored lessons", "star.fill", Palette.demo)
            tile("Streak", "\(history.streak())", "days in a row", "flame.fill", Palette.left)
            tile("Practice days", "\(history.practiceDays.count)", "days with practice", "calendar", Palette.right)
            tile("Time practised", minutes >= 90 ? String(format: "%.1f h", minutes / 60) : "\(Int(minutes.rounded())) min", "estimated", "clock.fill", Palette.info)
            tile("Attempts", "\(history.attempts.count)", "scored tasks played", "pianokeys", Palette.either)
        }
    }

    private func tile(_ name: String, _ value: String, _ note: String, _ icon: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(name, systemImage: icon).font(.caption).foregroundStyle(.secondary).labelStyle(TintedIconLabel(tint: tint))
            Text(value).font(.system(size: 26, weight: .semibold, design: .rounded)).monospacedDigit()
            Text(note).font(.caption).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.05)))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 40)).foregroundStyle(.secondary)
            Text("No practice recorded yet").font(.headline)
            Text("Play any scored step in a lesson and your accuracy, timing and evenness will be charted here.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Go to today's plan") { app.selectedLessonID = AppModel.todayID }
        }
        .padding(30)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.05)))
    }

    // MARK: Charts

    private var charts: some View {
        let data = buckets
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Over time").font(.title2.weight(.semibold))
                Spacer()
                Picker("Range", selection: $range) {
                    ForEach(ProgressRange.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 280)
            }
            if data.isEmpty {
                Text("No practice in this period.").foregroundStyle(.secondary)
                    .padding(20).frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.05)))
            } else {
                chartCard(title: showMinutes ? "Practice time" : "Attempts",
                          subtitle: isWeekly ? "per week" : "per day",
                          trailing: AnyView(Picker("", selection: $showMinutes) {
                              Text("Minutes").tag(true)
                              Text("Attempts").tag(false)
                          }.pickerStyle(.segmented).labelsHidden().frame(width: 170))) {
                    Chart(data) { bucket in
                        BarMark(x: .value("Date", bucket.start, unit: unit),
                                y: .value(showMinutes ? "Minutes" : "Attempts", showMinutes ? bucket.minutes : Double(bucket.attempts)))
                            .foregroundStyle(Palette.right.gradient)
                            .cornerRadius(3)
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 14)], spacing: 14) {
                    lineCard("Accuracy", "average, higher is better", data.compactMap { b in b.accuracy.map { (b.start, $0 * 100) } },
                             color: Palette.good, suffix: "%", domain: 0...100)
                    lineCard("Timing error", "average ms off the beat, lower is better", data.compactMap { b in b.timingMs.map { (b.start, $0) } },
                             color: Palette.left, suffix: " ms", domain: nil)
                    lineCard("Velocity evenness", "average ± spread, lower is better", data.compactMap { b in b.evenness.map { (b.start, $0) } },
                             color: Palette.either, suffix: "", domain: nil)
                }
            }
        }
    }

    private func chartCard<Content: View>(title: String, subtitle: String, trailing: AnyView? = nil,
                                          @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let trailing { trailing }
            }
            content().frame(height: 170)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.05)))
    }

    private func lineCard(_ title: String, _ subtitle: String, _ points: [(Date, Double)], color: Color,
                          suffix: String, domain: ClosedRange<Double>?) -> some View {
        let latest = points.last.map { String(format: "%.0f", $0.1) + suffix }
        return chartCard(title: title, subtitle: subtitle,
                         trailing: latest.map { AnyView(Text($0).font(.system(size: 17, weight: .semibold, design: .rounded)).monospacedDigit()) }) {
            if points.isEmpty {
                Text("No data in this period yet.").font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let chart = Chart(Array(points.enumerated()), id: \.offset) { _, point in
                    LineMark(x: .value("Date", point.0), y: .value(title, point.1))
                        .foregroundStyle(color)
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Date", point.0), y: .value(title, point.1))
                        .foregroundStyle(color)
                        .symbolSize(points.count > 20 ? 14 : 30)
                }
                if let domain {
                    chart.chartYScale(domain: domain)
                } else {
                    chart
                }
            }
        }
    }

    // MARK: Lists

    private static func daysAgo(_ date: Date) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: Date())).day ?? 0
        return days <= 0 ? "today" : days == 1 ? "yesterday" : "\(days) days ago"
    }

    private var sectionBreakdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("By section").font(.headline)
            ForEach(app.sections) { section in
                let lessons = section.units.flatMap { $0.lessons }
                let done = lessons.filter { progress.record($0.id).completed }.count
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Label(section.title, systemImage: section.symbol).lineLimit(1)
                        Spacer()
                        Text("\(done)/\(lessons.count)").font(.callout).monospacedDigit().foregroundStyle(.secondary)
                    }
                    ProgressView(value: Double(done), total: Double(max(1, lessons.count)))
                        .tint(done == lessons.count && !lessons.isEmpty ? Palette.good : .accentColor)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.05)))
    }

    private struct TempoRow: Identifiable {
        let id: String
        let lessonID: String
        let step: Int
        let title: String
        let lesson: String
        let bpm: Double
    }

    private var tempoRows: [TempoRow] {
        var rows: [TempoRow] = []
        for (id, record) in progress.records {
            guard let lesson = app.lessonIndex[id]?.lesson else { continue }
            for (step, bpm) in record.bestBPM where lesson.steps.indices.contains(step) && bpm > 0 {
                rows.append(TempoRow(id: "\(id)#\(step)", lessonID: id, step: step, title: lesson.steps[step].title,
                                     lesson: lesson.title, bpm: bpm))
            }
        }
        return Array(rows.sorted { $0.bpm != $1.bpm ? $0.bpm > $1.bpm : $0.id < $1.id }.prefix(8))
    }

    private var bestTempos: some View {
        let rows = tempoRows
        return VStack(alignment: .leading, spacing: 8) {
            Text("Best clean tempos").font(.headline)
            if rows.isEmpty {
                Text("Pass a metronome task and its fastest clean tempo appears here.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            ForEach(rows) { row in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.title).lineLimit(1)
                        Text(row.lesson).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Text("\(Int(row.bpm)) BPM").font(.system(size: 14, weight: .semibold, design: .rounded)).monospacedDigit()
                    Button {
                        app.selectedLessonID = row.lessonID
                        app.goToStep(row.step)
                    } label: { Image(systemName: "arrow.right.circle") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Open this step")
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.05)))
    }

    private var weakest: some View {
        let candidates = allLessons
            .filter { $0.steps.contains { $0.isScored } && progress.record($0.id).completed && progress.record($0.id).stars < 3 }
            .sorted { a, b in
                let ra = progress.record(a.id), rb = progress.record(b.id)
                return ra.stars != rb.stars ? ra.stars < rb.stars : (ra.lastPracticed ?? .distantPast) < (rb.lastPracticed ?? .distantPast)
            }
            .prefix(6)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Worth revisiting").font(.headline)
            if candidates.isEmpty {
                Text(progress.records.values.contains { $0.completed }
                     ? "Every completed lesson has three stars. Nice work."
                     : "Completed lessons with fewer than three stars will be listed here.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            ForEach(Array(candidates)) { lesson in
                let record = progress.record(lesson.id)
                HStack(spacing: 10) {
                    StarsView(stars: record.stars, size: 12)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(lesson.title).lineLimit(1)
                        if let entry = app.lessonIndex[lesson.id] {
                            Text("\(entry.section.title)  ›  \(entry.unit.title)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Spacer()
                    if let last = record.lastPracticed {
                        Text(Self.daysAgo(last)).font(.caption).foregroundStyle(.secondary)
                    }
                    Button("Practise") { app.selectedLessonID = lesson.id }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.05)))
    }
}

private struct TintedIconLabel: LabelStyle {
    let tint: Color
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon.foregroundStyle(tint)
            configuration.title
        }
    }
}
