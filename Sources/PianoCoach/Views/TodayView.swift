import SwiftUI

/// Home screen: today's practice plan, streak, and progress through each section.
struct TodayView: View {
    @EnvironmentObject var app: AppModel

    var body: some View {
        ScrollView {
            TodayContent(app: app, history: app.history, progress: app.progress)
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// The scrolling content, separate so it can observe the stores (and be rendered on its own).
struct TodayContent: View {
    @ObservedObject var app: AppModel
    @ObservedObject var history: HistoryStore
    @ObservedObject var progress: ProgressStore

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private func doneToday(_ id: String) -> Bool {
        let now = Date()
        if let last = progress.record(id).lastPracticed, Calendar.current.isDate(last, inSameDayAs: now) { return true }
        return history.practiced(id, on: now)
    }

    var body: some View {
        let plan = PracticePlan.today(app: app)
        let done = plan.filter { doneToday($0.lessonID) }.count
        let isNewLearner = history.attempts.isEmpty && !progress.records.values.contains { $0.completed }

        VStack(alignment: .leading, spacing: 22) {
            header

            if !app.midi.isConnected {
                Label("No MIDI keyboard detected. Connect the Launchkey by USB — it appears automatically. Meanwhile, click the on-screen keys or type A S D F G H J K (W E T Y U for black keys).",
                      systemImage: "cable.connector")
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Palette.left.opacity(0.14)))
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Today's practice").font(.title2.weight(.semibold))
                    if !plan.isEmpty {
                        Text("\(done) of \(plan.count) done")
                            .font(.callout).foregroundStyle(done == plan.count ? Palette.good : .secondary)
                    }
                    Spacer()
                    Text("About \(max(5, plan.count * 4)) minutes").font(.callout).foregroundStyle(.secondary)
                }
                if isNewLearner {
                    Text("Welcome! Each day this page suggests a short session: a warm-up, a couple of reviews of things you've learned, and something new. Reviews come back just as you'd start to forget them — sooner if a lesson went badly, later if it went well. For now there is just one thing to do: your first lesson.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 680, alignment: .leading)
                }
                if plan.isEmpty {
                    Text("Nothing planned — you have finished every lesson. Pick anything from the sidebar, or play freely.")
                        .foregroundStyle(.secondary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.05)))
                }
                ForEach(Array(plan.enumerated()), id: \.element.id) { index, item in
                    PlanCard(app: app, item: item, number: index + 1, done: doneToday(item.lessonID),
                             isNext: !doneToday(item.lessonID) && !plan.prefix(index).contains { !doneToday($0.lessonID) })
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Your course").font(.title2.weight(.semibold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 14)], spacing: 14) {
                    ForEach(app.sections) { section in
                        SectionCard(app: app, section: section, progress: progress)
                    }
                }
            }
        }
    }

    private var header: some View {
        let streak = history.streak()
        let minutes = history.minutes(on: Date())
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Piano Coach").font(.callout.weight(.semibold)).foregroundStyle(.secondary)
                Text(greeting).font(.largeTitle.weight(.bold))
            }
            Spacer()
            HStack(spacing: 12) {
                statTile(icon: "flame.fill", tint: streak > 0 ? Palette.left : .secondary,
                         value: "\(streak)", label: streak == 1 ? "day streak" : "day streak")
                statTile(icon: "clock.fill", tint: Palette.right,
                         value: "\(Int(minutes.rounded()))", label: "min today")
                statTile(icon: "checkmark.seal.fill", tint: Palette.good,
                         value: "\(progress.records.values.filter { $0.completed }.count)", label: "lessons done")
            }
        }
    }

    private func statTile(icon: String, tint: Color, value: String, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 20)).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.system(size: 22, weight: .semibold, design: .rounded)).monospacedDigit()
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.05)))
    }
}

private struct PlanCard: View {
    @ObservedObject var app: AppModel
    let item: PlanItem
    let number: Int
    let done: Bool
    let isNext: Bool

    private var badge: (text: String, color: Color, icon: String) {
        switch item.kind {
        case .warmup: return ("Warm-up", Palette.left, "flame")
        case .review: return ("Review", Palette.either, "arrow.triangle.2.circlepath")
        case .new: return ("New", Palette.right, "sparkles")
        case .song: return ("Song", Palette.info, "music.note")
        }
    }

    var body: some View {
        let entry = app.lessonIndex[item.lessonID]
        let record = app.progress.record(item.lessonID)
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(done ? Palette.good : Color.primary.opacity(0.08)).frame(width: 34, height: 34)
                if done {
                    Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                } else {
                    Text("\(number)").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Label(badge.text, systemImage: badge.icon)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .foregroundStyle(badge.color)
                        .background(Capsule().fill(badge.color.opacity(0.15)))
                    if let entry {
                        Text("\(entry.section.title)  ›  \(entry.unit.title)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Text(entry?.lesson.title ?? item.lessonID).font(.headline)
                Text(item.reason).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if record.completed, entry?.lesson.steps.contains(where: { $0.isScored }) ?? false {
                StarsView(stars: record.stars, size: 13)
            }
            if isNext {
                Button(done ? "Again" : "Start") { app.selectedLessonID = item.lessonID }
                    .buttonStyle(.borderedProminent)
            } else {
                Button(done ? "Again" : "Start") { app.selectedLessonID = item.lessonID }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(isNext ? 0.07 : 0.04)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isNext ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1.5))
        .opacity(done ? 0.75 : 1)
    }
}

private struct SectionCard: View {
    @ObservedObject var app: AppModel
    let section: CurriculumSection
    @ObservedObject var progress: ProgressStore

    var body: some View {
        let lessons = section.units.flatMap { $0.lessons }
        let done = lessons.filter { progress.record($0.id).completed }.count
        VStack(alignment: .leading, spacing: 8) {
            Label(section.title, systemImage: section.symbol).font(.headline).lineLimit(1)
            ProgressView(value: Double(done), total: Double(max(1, lessons.count)))
                .tint(done == lessons.count && !lessons.isEmpty ? Palette.good : .accentColor)
            Text("\(done) of \(lessons.count) lessons").font(.caption).foregroundStyle(.secondary)
            Button(done == 0 ? "Start" : done == lessons.count ? "Revisit" : "Continue") {
                app.selectedLessonID = (lessons.first { !progress.record($0.id).completed } ?? lessons.first)?.id
            }
            .disabled(lessons.isEmpty)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.05)))
    }
}
