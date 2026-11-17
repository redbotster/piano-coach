import SwiftUI

/// Renders lesson text: blank lines separate paragraphs, "- " starts a bullet, inline markdown is supported.
struct RichText: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(text.components(separatedBy: "\n\n").enumerated()), id: \.offset) { _, block in
                let lines = block.split(separator: "\n").map(String.init)
                if lines.allSatisfy({ $0.hasPrefix("- ") }) {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("•").foregroundStyle(.secondary)
                                Text(markdown(String(line.dropFirst(2))))
                            }
                        }
                    }
                } else {
                    Text(markdown(lines.joined(separator: " ")))
                }
            }
        }
        .font(.system(size: 15))
        .lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)
        .textSelection(.enabled)
    }

    private func markdown(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(s)
    }
}

struct StarsView: View {
    let stars: Int
    var size: CGFloat = 12

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < stars ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(i < stars ? Palette.demo : Color.secondary.opacity(0.4))
            }
        }
    }
}

struct LinksView: View {
    let links: [WebLink]

    var body: some View {
        if !links.isEmpty {
            HStack(spacing: 10) {
                ForEach(links) { link in
                    if let url = URL(string: link.url) {
                        Link(destination: url) {
                            Label(link.title, systemImage: "play.rectangle")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }
}

// MARK: - Lesson screen

struct LessonView: View {
    @EnvironmentObject var app: AppModel
    let lesson: Lesson

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if app.lessonFinished {
                        LessonCompleteView(lesson: lesson)
                    } else if let step = app.step {
                        stepBody(step)
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            footer
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(app.breadcrumb).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline) {
                Text(lesson.title).font(.title2.weight(.semibold))
                Spacer()
                StepDots(lesson: lesson)
                let done = app.isCompleted(lesson.id)
                Button {
                    app.setCompleted(lesson.id, !done)
                } label: {
                    Label(done ? "Completed" : "Mark complete", systemImage: done ? "checkmark.circle.fill" : "circle")
                }
                .buttonStyle(.bordered)
                .tint(done ? Palette.good : nil)
                .help(done ? "Click to mark this lesson as not complete" : "Mark this lesson as complete without finishing every step")
                .padding(.leading, 10)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func stepBody(_ step: Step) -> some View {
        switch step {
        case .info(let info): InfoStepView(info: info)
        case .checklist(let list): ChecklistStepView(list: list)
        case .play:
            if let runner = app.runner { TaskView(runner: runner, task: runner.task, quiz: nil) }
        case .quiz(let quiz):
            if let runner = app.runner { TaskView(runner: runner, task: runner.task, quiz: quiz) }
        }
    }

    private var canContinue: Bool {
        if case .checklist(let list) = app.step { return app.checked.count >= list.items.count }
        return true
    }

    private var footer: some View {
        HStack {
            Button {
                app.previousStep()
            } label: { Label("Back", systemImage: "chevron.left") }
            .disabled(app.stepIndex == 0 && !app.lessonFinished)

            Spacer()
            if !app.lessonFinished {
                Text("Step \(app.stepIndex + 1) of \(lesson.steps.count)").font(.callout).foregroundStyle(.secondary)
            }
            Spacer()

            if app.lessonFinished {
                Button {
                    app.goToNextLesson()
                } label: { Label("Next lesson", systemImage: "arrow.right") }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
                .disabled(app.nextLessonID == nil)
            } else {
                let scoredButNotPassed = (app.step?.isScored ?? false) && !((app.lastResult?.passed ?? false) && !app.isPractice)
                Button {
                    app.nextStep()
                } label: {
                    Label(app.stepIndex + 1 == lesson.steps.count ? "Finish lesson" : (scoredButNotPassed ? "Skip" : "Continue"),
                          systemImage: "chevron.right")
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
                .tint(scoredButNotPassed ? .gray : .accentColor)
                .disabled(!canContinue)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
    }
}

struct StepDots: View {
    @EnvironmentObject var app: AppModel
    let lesson: Lesson

    var body: some View {
        let record = app.progress.record(lesson.id)
        HStack(spacing: 5) {
            ForEach(lesson.steps.indices, id: \.self) { i in
                let isCurrent = i == app.stepIndex && !app.lessonFinished
                let passed = (record.stepStars[i] ?? 0) > 0
                Circle()
                    .fill(isCurrent ? Color.accentColor : passed ? Palette.good : Color.secondary.opacity(lesson.steps[i].isScored ? 0.35 : 0.2))
                    .frame(width: isCurrent ? 11 : 8, height: isCurrent ? 11 : 8)
                    .onTapGesture { app.goToStep(i) }
                    .help(lesson.steps[i].title)
            }
        }
    }
}

struct LessonCompleteView: View {
    @EnvironmentObject var app: AppModel
    let lesson: Lesson

    var body: some View {
        let record = app.progress.record(lesson.id)
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 54)).foregroundStyle(Palette.good)
            Text("Lesson complete").font(.title.weight(.semibold))
            Text(lesson.title).foregroundStyle(.secondary)
            StarsView(stars: record.stars, size: 26)
            let scored = lesson.steps.indices.filter { lesson.steps[$0].isScored }
            if !scored.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(scored, id: \.self) { i in
                        HStack {
                            Text(lesson.steps[i].title).frame(maxWidth: 360, alignment: .leading)
                            StarsView(stars: record.stepStars[i] ?? 0)
                            if let bpm = record.bestBPM[i] {
                                Text("\(Int(bpm)) BPM").font(.caption).foregroundStyle(.secondary)
                            }
                            Button("Practice") { app.goToStep(i) }.buttonStyle(.link)
                        }
                    }
                }
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 30)
    }
}

// MARK: - Step kinds

struct InfoStepView: View {
    @EnvironmentObject var app: AppModel
    let info: InfoStep

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(info.title).font(.title3.weight(.semibold))
            HStack(alignment: .top, spacing: 20) {
                if let glyph = info.glyph {
                    GlyphView(spec: glyph)
                        .frame(minWidth: 96, minHeight: 96)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.06)))
                }
                RichText(text: info.body)
            }
            if let example = info.example {
                VStack(alignment: .leading, spacing: 10) {
                    NotationPanel(task: example, statuses: [], current: nil, hitMarks: [], clock: nil, running: false)
                    Button {
                        app.isDemoPlaying ? app.stopDemo() : app.playDemo()
                    } label: {
                        Label(app.isDemoPlaying ? "Stop" : "Listen", systemImage: app.isDemoPlaying ? "stop.fill" : "speaker.wave.2.fill")
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))
            }
            LinksView(links: info.links)
        }
    }
}

struct ChecklistStepView: View {
    @EnvironmentObject var app: AppModel
    let list: ChecklistStep

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(list.title).font(.title3.weight(.semibold))
            RichText(text: list.body)
            VStack(alignment: .leading, spacing: 10) {
                Text("Your keyboard can't sense these, so check each one yourself:")
                    .font(.callout).foregroundStyle(.secondary)
                ForEach(list.items.indices, id: \.self) { i in
                    Toggle(isOn: Binding(
                        get: { app.checked.contains(i) },
                        set: { on in if on { app.checked.insert(i) } else { app.checked.remove(i) } }
                    )) {
                        Text(list.items[i]).font(.system(size: 15))
                    }
                    .toggleStyle(.checkbox)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))
            LinksView(links: list.links)
        }
    }
}

/// Staff and/or rhythm lane for a task.
struct NotationPanel: View {
    let task: PlayTask
    var statuses: [EventStatus]
    var current: Int?
    var hitMarks: [HitMark]
    var clock: PlayheadClock?
    var running: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if task.display == .staff || task.display == .staffAndRhythm {
                StaffView(task: task, statuses: statuses, current: current, clock: clock, showPlayhead: running)
            }
            if task.display == .rhythm || task.display == .staffAndRhythm {
                RhythmLaneView(task: task, statuses: statuses, current: current, hitMarks: hitMarks,
                               clock: clock, showPlayhead: running)
            }
        }
    }
}

struct TaskView: View {
    @EnvironmentObject var app: AppModel
    @ObservedObject var runner: TaskRunner
    let task: PlayTask
    let quiz: QuizStep?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(quiz?.title ?? task.title).font(.title3.weight(.semibold))
                if let quiz, !app.quizDone {
                    Text("Round \(app.quizRound + 1) of \(quiz.rounds)  ·  \(app.quizCorrect) correct")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            RichText(text: quiz?.instructions ?? task.instructions)

            if quiz != nil, !app.quizDone {
                Text(task.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .padding(.vertical, 2)
            }

            if !(quiz != nil && app.quizDone) {
                if task.display != .keyboard {
                    NotationPanel(task: task, statuses: runner.statuses,
                                  current: runner.phase == .done ? nil : runner.index,
                                  hitMarks: runner.hitMarks, clock: runner.clock,
                                  running: runner.phase == .running || runner.phase == .countIn)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))
                        .overlay(alignment: .center) { countInOverlay }
                } else if runner.phase == .countIn {
                    countInOverlay.frame(maxWidth: .infinity)
                }
                if !runner.timedRun, quiz == nil, task.events.count > 1 {
                    ProgressView(value: Double(min(runner.index, task.events.count)), total: Double(task.events.count))
                        .frame(maxWidth: 420)
                }
                controls
                if quiz == nil, app.stepTask?.isTimed ?? false {
                    PracticeOptionsBar(runner: runner)
                }
            }

            if let result = app.lastResult {
                ResultView(result: result, task: task, isQuiz: quiz != nil, practice: app.isPractice && quiz == nil)
            }
        }
    }

    @ViewBuilder
    private var countInOverlay: some View {
        if runner.phase == .countIn, let beat = runner.countInBeat {
            Text("\(beat)")
                .font(.system(size: 64, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 26)
                .background(RoundedRectangle(cornerRadius: 16).fill(.regularMaterial))
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            if runner.timedRun {
                if runner.phase == .ready || runner.phase == .done {
                    Button {
                        app.startTask()
                    } label: {
                        Label(runner.phase == .done ? "Try again" : "Start", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .help("Space bar also starts")
                } else {
                    Button {
                        app.stopTask()
                    } label: { Label("Stop", systemImage: "stop.fill") }
                }
                TempoControl(runner: runner)
                if app.options.loopOn, app.loopPass > 0 {
                    Text("Loop pass \(app.loopPass + 1)").font(.callout).foregroundStyle(.secondary)
                }
            } else if quiz == nil {
                Button {
                    app.retryTask()
                } label: { Label("Restart", systemImage: "arrow.counterclockwise") }
            }
            if quiz == nil || task.listenFirst {
                Button {
                    app.isDemoPlaying ? app.stopDemo() : app.playDemo()
                } label: {
                    Label(app.isDemoPlaying ? "Stop" : (task.listenFirst ? "Hear again" : "Demo"),
                          systemImage: app.isDemoPlaying ? "stop.fill" : "speaker.wave.2.fill")
                }
                .disabled(runner.phase == .countIn || (runner.timedRun && runner.phase == .running))
            }
            Spacer()
            if !runner.timedRun, runner.phase == .running, quiz == nil {
                Text(!task.showTargets ? "Play what you read or hear — the lesson waits for you."
                     : task.events.count > 1 ? "Play the lit keys — the lesson waits for you." : "Play the lit key.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

/// Hand selection, wait mode, looping and the falling-notes toggle for timed tasks.
struct PracticeOptionsBar: View {
    @EnvironmentObject var app: AppModel
    @ObservedObject var runner: TaskRunner

    var body: some View {
        let idle = runner.phase == .ready || runner.phase == .done || !runner.timedRun
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                if app.taskHasBothHands {
                    Picker("Hands", selection: $app.options.hand) {
                        Text("Both").tag(Hand.either)
                        Text("Right").tag(Hand.right)
                        Text("Left").tag(Hand.left)
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                    .help("Practise one hand while the app plays the other")
                }
                Toggle("Wait for me", isOn: $app.options.wait)
                    .help("No metronome: the music pauses on each note until you play it")
                Toggle("Loop bars", isOn: $app.options.loopOn)
                    .disabled(app.options.wait)
                    .help("Repeat a few bars at a slower tempo")
                if app.options.loopOn, !app.options.wait {
                    Stepper("\(app.options.loopFrom)", value: $app.options.loopFrom, in: 1...max(1, app.options.loopTo))
                    Text("to")
                    Stepper("\(app.options.loopTo)", value: $app.options.loopTo, in: app.options.loopFrom...max(app.options.loopFrom, app.taskBarCount))
                    Toggle("Auto speed-up", isOn: $app.options.autoSpeed)
                        .help("Each clean pass raises the tempo by 4 BPM until you reach the target")
                }
                Spacer()
                Toggle("Falling notes", isOn: $app.fallingNotes)
            }
            .toggleStyle(.checkbox)
            .disabled(!idle)
            if app.isPractice {
                Label(practiceNote, systemImage: "figure.walk")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
    }

    private var practiceNote: String {
        var parts: [String] = []
        if app.options.hand == .right { parts.append("right hand only, the app plays the left") }
        if app.options.hand == .left { parts.append("left hand only, the app plays the right") }
        if app.options.wait { parts.append("the music waits for each note") }
        if app.options.loopOn, !app.options.wait {
            parts.append("looping bars \(app.options.loopFrom)–\(app.options.loopTo)" + (app.options.autoSpeed ? ", speeding up after each clean pass" : ""))
        }
        return "Practice mode: " + parts.joined(separator: "; ") + ". Stars are only earned with both hands, in time, on the whole passage."
    }
}

struct TempoControl: View {
    @EnvironmentObject var app: AppModel
    @ObservedObject var runner: TaskRunner

    var body: some View {
        let editable = runner.phase == .ready || runner.phase == .done
        HStack(spacing: 6) {
            Image(systemName: "metronome")
            Button { app.setTempo(runner.bpm - 4) } label: { Image(systemName: "minus") }.disabled(!editable)
            Text("\(Int(runner.bpm)) BPM").monospacedDigit().frame(width: 68)
            Button { app.setTempo(runner.bpm + 4) } label: { Image(systemName: "plus") }.disabled(!editable)
            if let config = runner.task.timedConfig, Int(config.bpm) != Int(runner.bpm) {
                Button("Reset") { app.setTempo(config.bpm) }.buttonStyle(.link).disabled(!editable)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
    }
}

struct ResultView: View {
    let result: TaskResult
    let task: PlayTask
    let isQuiz: Bool
    var practice: Bool = false

    private func timingWord(_ ms: Double) -> String {
        ms <= 25 ? "excellent" : ms <= 45 ? "good" : ms <= 80 ? "fair" : "loose"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: result.passed ? "checkmark.circle.fill" : "arrow.counterclockwise.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(result.passed ? Palette.good : Palette.left)
                Text(practice ? (result.passed ? "Clean practice run" : "Keep practising")
                     : result.passed ? "Passed" : "Not quite — try again").font(.headline)
                if !practice { StarsView(stars: result.stars, size: 16) }
            }
            HStack(alignment: .top, spacing: 26) {
                metric("Accuracy", "\(Int((result.accuracy * 100).rounded()))%",
                       isQuiz ? "\(result.correct) of \(result.total) first try" : "\(result.correct) of \(result.total) notes")
                if !isQuiz {
                    metric("Wrong notes", "\(result.wrongNotes)", result.wrongNotes == 0 ? "clean" : "extra or incorrect keys")
                }
                if let m = result.meanAbsDeviationMs {
                    let bias = result.meanDeviationMs ?? 0
                    metric("Timing", "±\(Int(m.rounded())) ms",
                           "\(timingWord(m)); " + (abs(bias) < 12 ? "centred on the beat" : bias > 0 ? "tending late (dragging)" : "tending early (rushing)"))
                }
                if let s = result.timingSpreadMs {
                    metric("Steadiness", "\(Int(s.rounded())) ms", "spread of your timing")
                }
                if let v = result.velocityMean, !isQuiz {
                    metric("Velocity", "\(Int(v.rounded()))", result.velocityStdDev.map { "evenness ±\(Int($0.rounded()))" } ?? "")
                }
                if let bpm = result.bpm {
                    metric("Tempo", "\(Int(bpm))", "BPM")
                }
            }
            ForEach(result.rules) { rule in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: rule.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(rule.passed ? Palette.good : Palette.bad)
                    Text(rule.name).fontWeight(.semibold)
                    Text(rule.detail).foregroundStyle(.secondary)
                }
                .font(.callout)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill((result.passed ? Palette.good : Palette.left).opacity(0.10)))
    }

    private func metric(_ name: String, _ value: String, _ note: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: 22, weight: .semibold, design: .rounded)).monospacedDigit()
            Text(note).font(.caption).foregroundStyle(.secondary)
        }
    }
}
