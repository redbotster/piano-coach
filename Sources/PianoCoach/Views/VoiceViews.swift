import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// A scrolling piano roll of the voice: target notes as bars, the sung pitch as a line.
struct PitchRollView: View {
    @ObservedObject var runner: SingRunner
    /// Notes to show when the exercise has no targets of its own.
    var fallback: ClosedRange<Int>

    private let secondsVisible = 8.0
    private let gutter: CGFloat = 34

    private var range: ClosedRange<Int> {
        runner.targets.contains { $0.midi != nil } ? runner.displayRange : fallback
    }

    var body: some View {
        let range = range
        ZStack {
            // Rows and note names never move, so they are drawn once, not on every frame.
            Canvas { context, size in
                let rowHeight = size.height / CGFloat(range.count)
                func y(_ midi: Double) -> CGFloat { size.height - CGFloat(midi - Double(range.lowerBound) + 0.5) * rowHeight }
                for note in range {
                    let top = y(Double(note)) - rowHeight / 2
                    let rect = CGRect(x: 0, y: top, width: size.width, height: rowHeight)
                    if Music.isBlack(note) { context.fill(Path(rect), with: .color(Color.primary.opacity(0.055))) }
                    if Music.pc(note) == 0 {
                        context.stroke(Path { $0.move(to: CGPoint(x: 0, y: top + rowHeight)); $0.addLine(to: CGPoint(x: size.width, y: top + rowHeight)) },
                                       with: .color(Color.primary.opacity(0.18)), lineWidth: 1)
                    }
                    let showName = Music.pc(note) == 0 || (rowHeight >= 11 && !Music.isBlack(note))
                    if showName {
                        context.draw(Text(Music.name(note)).font(.system(size: min(10, max(7, rowHeight * 0.8)), weight: Music.pc(note) == 0 ? .bold : .regular))
                                        .foregroundColor(.secondary), at: CGPoint(x: gutter / 2, y: y(Double(note))))
                    }
                }
                context.stroke(Path { $0.move(to: CGPoint(x: gutter, y: 0)); $0.addLine(to: CGPoint(x: gutter, y: size.height)) },
                               with: .color(Color.primary.opacity(0.15)), lineWidth: 1)
            }
            // The moving part follows the display's own refresh, reading the time directly.
            // Runs on every display frame. The frame's date is used in the drawing so each frame really redraws.
            TimelineView(.animation) { timeline in
                let tick = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    draw(&context, size: size, range: range, now: runner.displayTime(), tick: tick)
                }
            }
        }
        .background(Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize, range: ClosedRange<Int>, now: Double, tick: Double) {
        _ = tick
        let rowHeight = size.height / CGFloat(range.count)
        let nowX = gutter + (size.width - gutter) * (runner.isTimed ? 0.3 : 0.82)
        let perSecond = (size.width - gutter) / CGFloat(secondsVisible)
        func y(_ midi: Double) -> CGFloat { size.height - CGFloat(midi - Double(range.lowerBound) + 0.5) * rowHeight }
        func x(_ time: Double) -> CGFloat { nowX + CGFloat(time - now) * perSecond }
        context.clip(to: Path(CGRect(x: gutter, y: 0, width: size.width - gutter, height: size.height)))

        // Target notes
        let barHeight = max(8, rowHeight)
        if runner.isTimed {
            for (i, target) in runner.targets.enumerated() {
                guard let midi = target.midi else { continue }
                let left = x(target.start), right = x(target.start + target.length)
                guard right > gutter, left < size.width else { continue }
                let rect = CGRect(x: left + 1, y: y(Double(midi)) - barHeight / 2, width: max(4, right - left - 2), height: barHeight)
                let status = i < runner.statuses.count ? runner.statuses[i] : .pending
                let color: Color = status == .correct ? Palette.good : status == .pending ? Palette.right : Palette.bad
                let path = Path(roundedRect: rect, cornerRadius: min(5, barHeight / 2))
                context.fill(path, with: .color(color.opacity(status == .pending ? 0.55 : 0.35)))
                context.stroke(path, with: .color(color.opacity(0.9)), lineWidth: 1)
                if let label = target.label, rect.width > 16 {
                    context.draw(Text(label).font(.system(size: 11, weight: .semibold)).foregroundColor(.primary),
                                 at: CGPoint(x: rect.minX + 5, y: rect.minY - 8), anchor: .leading)
                }
            }
        } else if runner.index < runner.targets.count, let midi = runner.targets[runner.index].midi, runner.phase != .done {
            let rect = CGRect(x: gutter, y: y(Double(midi)) - barHeight / 2, width: size.width - gutter, height: barHeight)
            context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(Palette.right.opacity(0.28)))
            context.stroke(Path(roundedRect: rect, cornerRadius: 4), with: .color(Palette.right.opacity(0.8)), lineWidth: 1)
            let name = [runner.targets[runner.index].label, Music.name(midi)].compactMap { $0 }.joined(separator: " · ")
            context.draw(Text(name).font(.system(size: 12, weight: .semibold)).foregroundColor(.primary),
                         at: CGPoint(x: gutter + 8, y: rect.minY - 9), anchor: .leading)
        }

        // The voice: one path per colour, so a long line costs three strokes, not hundreds.
        let trace = runner.trace
        let earliest = now - Double((nowX - gutter) / perSecond) - 0.2
        var low = 0, high = trace.count
        while low < high {
            let mid = (low + high) / 2
            if trace[mid].time < earliest { low = mid + 1 } else { high = mid }
        }
        var lines = [Path(), Path(), Path()]
        var dots = [Path(), Path(), Path()]
        var previous: SingRunner.TracePoint?
        for point in trace[low...] {
            let position = CGPoint(x: x(point.time), y: y(point.midi))
            let kind = point.good == true ? 0 : point.good == false ? 1 : 2
            if let last = previous, point.time - last.time < 0.07, abs(point.midi - last.midi) < 1.5 {
                lines[kind].move(to: CGPoint(x: x(last.time), y: y(last.midi)))
                lines[kind].addLine(to: position)
            } else {
                dots[kind].addEllipse(in: CGRect(x: position.x - 2, y: position.y - 2, width: 4, height: 4))
            }
            previous = point
        }
        let colors = [Palette.good, Palette.left, Palette.either]
        for kind in 0..<3 {
            context.stroke(lines[kind], with: .color(colors[kind]), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
            context.fill(dots[kind], with: .color(colors[kind]))
        }
        if let last = previous, now - last.time < 0.15 {
            let circle = Path(ellipseIn: CGRect(x: x(last.time) - 5, y: y(last.midi) - 5, width: 10, height: 10))
            context.fill(circle, with: .color(.white))
            context.stroke(circle, with: .color(Color.primary.opacity(0.7)), lineWidth: 1.5)
        }

        // "Now"
        context.stroke(Path { $0.move(to: CGPoint(x: nowX, y: 0)); $0.addLine(to: CGPoint(x: nowX, y: size.height)) },
                       with: .color(Color.primary.opacity(0.45)), lineWidth: 1.5)

        if runner.phase == .countIn {
            let beat = 60 / runner.bpm
            let count = max(1, Int((-now / beat).rounded(.up)))
            context.draw(Text("\(count)").font(.system(size: 64, weight: .bold, design: .rounded)).foregroundColor(Palette.right.opacity(0.8)),
                         at: CGPoint(x: gutter + (size.width - gutter) * 0.65, y: size.height / 2))
        }
    }
}

/// Live read-out of the note being sung and how far it is from being in tune.
struct VoiceReadout: View {
    @ObservedObject var meter: VoiceMeter
    var large = false

    var body: some View {
        let frame = meter.frame
        let nearest = frame.midi.map { Int($0.rounded()) }
        let cents = frame.midi.map { ($0 - $0.rounded()) * 100 } ?? 0
        HStack(spacing: 16) {
            Text(nearest.map { Music.name($0) } ?? "—")
                .font(.system(size: large ? 54 : 28, weight: .bold, design: .rounded))
                .frame(width: large ? 150 : 84, alignment: .leading)
                .foregroundStyle(nearest == nil ? Color.secondary : Color.primary)
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    let w = geo.size.width
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08))
                        Rectangle().fill(Palette.good.opacity(0.25)).frame(width: w * 0.3).offset(x: w * 0.35)
                        Rectangle().fill(Color.primary.opacity(0.4)).frame(width: 1.5).offset(x: w / 2)
                        if nearest != nil {
                            Circle().fill(abs(cents) <= 15 ? Palette.good : abs(cents) <= 35 ? Palette.demo : Palette.left)
                                .frame(width: 14, height: 14)
                                .offset(x: w / 2 + CGFloat(cents / 50) * (w / 2 - 7) - 7)
                        }
                    }
                }
                .frame(height: 14)
                HStack {
                    Text("flat").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text(nearest == nil ? "sing a note" : abs(cents) <= 15 ? "in tune" : String(format: "%+.0f cents", cents))
                        .font(.caption).monospacedDigit()
                        .foregroundStyle(nearest != nil && abs(cents) <= 15 ? Palette.good : Color.secondary)
                    Spacer()
                    Text("sharp").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 320)
            VStack(alignment: .leading, spacing: 4) {
                // Drawn by hand: the system progress bar is costly to update many times a second.
                Capsule().fill(Color.primary.opacity(0.1))
                    .frame(width: 90, height: 6)
                    .overlay(alignment: .leading) {
                        Capsule().fill(Color.accentColor).frame(width: max(0, 90 * CGFloat(min(1, frame.level))), height: 6)
                    }
                Text("Level").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

/// Explains what is wrong when the microphone is not delivering sound.
struct MicStatusView: View {
    @ObservedObject var voice: VoiceEngine

    var body: some View {
        switch voice.state {
        case .running:
            EmptyView()
        case .off, .starting:
            Label("Starting the microphone…", systemImage: "mic").foregroundStyle(.secondary)
        case .denied:
            banner("Piano Coach is not allowed to use the microphone. Allow it in System Settings › Privacy & Security › Microphone, then come back.") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                    NSWorkspace.shared.open(url)
                }
            }
        case .failed(let message):
            banner(message, action: nil)
        }
    }

    private func banner(_ text: String, action: (() -> Void)?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "mic.slash.fill").foregroundStyle(Palette.left)
            Text(text).fixedSize(horizontal: false, vertical: true)
            Spacer()
            if let action { Button("Open Settings", action: action) }
            Button("Try again") { voice.stop(); voice.start() }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Palette.left.opacity(0.14)))
    }
}

/// Headphones switch and voice-range menu shared by singing steps and the studio.
struct VoiceOptionsBar: View {
    @EnvironmentObject var app: AppModel

    var body: some View {
        HStack(spacing: 18) {
            Toggle(isOn: $app.headphones) { Label("Headphones", systemImage: "headphones") }
                .toggleStyle(.switch)
                .help("With headphones on, the piano plays along as a guide while you sing. Without them it stays silent so the microphone hears only you.")
            Menu {
                ForEach(VoiceRange.presets, id: \.name) { preset in
                    Button("\(preset.name) — \(preset.detail) (\(Music.name(preset.range.low))–\(Music.name(preset.range.high)))") {
                        app.setVoiceRange(preset.range)
                    }
                }
                if let lesson = app.lessonOrder.first(where: { $0.hasPrefix("voice.") }), app.selectedLessonID != lesson {
                    Divider()
                    Button("Find my range…") { app.selectedLessonID = lesson }
                }
            } label: {
                Label("Voice: \(app.voiceRange.name)", systemImage: "waveform")
            }
            .fixedSize()
            .help("Exercises are moved into this range. Any octave counts, so a rough choice is fine.")
            Spacer()
        }
        .font(.callout)
    }
}

/// One singing step of a lesson.
struct SingTaskView: View {
    @EnvironmentObject var app: AppModel
    @ObservedObject var runner: SingRunner

    var body: some View {
        let task = runner.task
        VStack(alignment: .leading, spacing: 14) {
            Text(task.title).font(.title3.weight(.semibold))
            RichText(text: task.instructions)
            MicStatusView(voice: app.voice)

            PitchRollView(runner: runner, fallback: fallbackRange)
                .frame(height: 280)
            VoiceReadout(meter: app.voice.meter)

            controls
            if runner.isTrack { trackOptions }
            VoiceOptionsBar()

            if let result = runner.result {
                SingResultView(result: result, task: task)
            }
        }
        .onAppear {
            if case .match = task.kind {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak runner] in
                    guard let runner, runner.phase == .running, runner.index == 0 else { return }
                    runner.playReference()
                }
            }
        }
    }

    /// Loudness of the recording, the piano guide, and a reminder about headphones.
    private var trackOptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                Label("Recording", systemImage: "speaker.wave.2").font(.callout)
                Slider(value: $app.trackVolume, in: 0...1).frame(width: 160)
                Toggle("Piano plays the notes too", isOn: $app.trackGuide)
                    .disabled(!app.headphones)
                    .help("Plays each detected note quietly on the piano as it goes by (headphones only)")
                Spacer()
            }
            if !app.headphones {
                Label("Without headphones the microphone hears the recording as well as you, so the pitch line and the score will be unreliable. Put headphones on and turn on the switch below.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.callout).foregroundStyle(Palette.left)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The range finder shows nearly every voice; sirens show the singer's own range.
    private var fallbackRange: ClosedRange<Int> {
        if case .range = runner.task.kind { return 36...84 }
        return (app.voiceRange.low - 5)...(app.voiceRange.high + 5)
    }

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 12) {
            switch runner.task.kind {
            case .timed:
                if runner.phase == .ready || runner.phase == .done {
                    Button {
                        runner.begin()
                    } label: { Label(runner.phase == .done ? "Sing again" : "Start", systemImage: "play.fill") }
                        .buttonStyle(.borderedProminent)
                        .disabled(!app.voice.isRunning)
                    Button {
                        runner.isListening ? runner.reset() : runner.listen()
                    } label: { Label(runner.isListening ? "Stop" : "Hear it", systemImage: runner.isListening ? "stop.fill" : "speaker.wave.2.fill") }
                    Text("or press space").font(.caption).foregroundStyle(.secondary)
                } else {
                    Button {
                        runner.reset()
                    } label: { Label("Stop", systemImage: "stop.fill") }
                    Text(runner.phase == .countIn ? "Listen for your starting note…" : "Sing!")
                        .font(.callout).foregroundStyle(.secondary)
                }
            case .track:
                if runner.phase == .ready || runner.phase == .done {
                    Button {
                        runner.begin()
                    } label: { Label(runner.phase == .done ? "Sing again" : "Start", systemImage: "play.fill") }
                        .buttonStyle(.borderedProminent)
                        .disabled(!app.voice.isRunning || runner.isListening)
                    Button {
                        runner.isListening ? runner.reset() : runner.listen()
                    } label: { Label(runner.isListening ? "Stop" : "Check the notes", systemImage: runner.isListening ? "stop.fill" : "ear") }
                        .help("Plays the recording with the detected notes on the piano over it, without scoring")
                } else {
                    Button {
                        runner.stopTrack()
                    } label: { Label("Stop", systemImage: "stop.fill") }
                        .help("Stops and scores what you have sung so far")
                }
                TrackPositionView(runner: runner)
            case .match:
                if runner.phase == .done {
                    Button {
                        runner.reset()
                        runner.playReference()
                    } label: { Label("Again", systemImage: "arrow.counterclockwise") }
                } else {
                    Button {
                        runner.playReference()
                    } label: { Label("Hear the note", systemImage: "speaker.wave.2.fill") }
                    Button("Skip") { runner.skip() }
                    ProgressView(value: runner.heldProgress).frame(width: 140)
                    Text("Note \(min(runner.index + 1, runner.targets.count)) of \(runner.targets.count) — hold it in tune")
                        .font(.callout).foregroundStyle(.secondary)
                }
            case .free(let seconds, let span):
                if runner.phase == .done {
                    Button {
                        runner.reset()
                    } label: { Label("Again", systemImage: "arrow.counterclockwise") }
                } else {
                    ProgressView(value: min(1, runner.freeSeconds / seconds)).frame(width: 140)
                    Text(String(format: "Sung %.0f of %.0f seconds · covered %.0f of %.0f semitones",
                                min(runner.freeSeconds, seconds), seconds, min(runner.freeSpan, span), span))
                        .font(.callout).foregroundStyle(.secondary).monospacedDigit()
                }
            case .range:
                if runner.phase == .done {
                    Button {
                        runner.reset()
                    } label: { Label("Measure again", systemImage: "arrow.counterclockwise") }
                } else {
                    Text(runner.stableNote.map { "Holding \(Music.name($0))" } ?? "Hold a note steady…")
                        .font(.callout.weight(.semibold)).frame(width: 150, alignment: .leading)
                    Button("Set as lowest\(runner.rangeLow.map { ": \(Music.name($0))" } ?? "")") { runner.rangeLow = runner.stableNote }
                        .disabled(runner.stableNote == nil)
                    Button("Set as highest\(runner.rangeHigh.map { ": \(Music.name($0))" } ?? "")") { runner.rangeHigh = runner.stableNote }
                        .disabled(runner.stableNote == nil)
                    Button("Save my range") { runner.finishRange() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!((runner.rangeLow ?? 0) + 5 <= (runner.rangeHigh ?? 0) && runner.rangeLow != nil))
                }
            }
            Spacer()
        }
    }
}

/// Where a recording is up to, and a slider to start from somewhere else.
struct TrackPositionView: View {
    @ObservedObject var runner: SingRunner

    private func clock(_ seconds: Double) -> String {
        let whole = Int(max(0, seconds))
        return "\(whole / 60):" + String(format: "%02d", whole % 60)
    }

    var body: some View {
        let total = max(1, runner.totalLength)
        if runner.isMoving {
            TimelineView(.periodic(from: .now, by: 0.25)) { timeline in
                // The date is read so that each tick really redraws.
                let now = min(total, max(0, runner.displayTime() + 0 * timeline.date.timeIntervalSinceReferenceDate))
                HStack(spacing: 8) {
                    ProgressView(value: now, total: total).frame(width: 220)
                    Text("\(clock(now)) / \(clock(total))").font(.callout).monospacedDigit().foregroundStyle(.secondary)
                }
            }
        } else {
            HStack(spacing: 8) {
                Slider(value: $runner.seekOffset, in: 0...total).frame(width: 220)
                    .help("Drag to start from a different place in the recording")
                Text("\(clock(runner.seekOffset)) / \(clock(total))").font(.callout).monospacedDigit().foregroundStyle(.secondary)
            }
        }
    }
}

struct SingResultView: View {
    let result: TaskResult
    let task: SingTask

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: result.passed ? "checkmark.circle.fill" : "arrow.counterclockwise.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(result.passed ? Palette.good : Palette.left)
                Text(result.passed ? "Nicely sung" : "Not quite — try again").font(.headline)
                StarsView(stars: result.stars, size: 16)
            }
            if result.total > 1 {
                Text("\(result.correct) of \(result.total) notes in tune (\(Int((result.accuracy * 100).rounded()))%)")
                    .font(.system(size: 18, weight: .semibold, design: .rounded)).monospacedDigit()
            }
            ForEach(result.rules) { rule in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
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
}

/// Free singing with a live tuner, recording and Auto-Tune.
struct VoiceStudioView: View {
    @EnvironmentObject var app: AppModel
    @ObservedObject var voice: VoiceEngine

    private let keys = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Voice studio").font(.largeTitle.weight(.bold))
                Text("Sing anything. The line shows the pitch of your voice, and the note you are singing lights up on the keyboard below.")
                    .foregroundStyle(.secondary)
                MicStatusView(voice: voice)

                if let runner = app.singRunner {
                    PitchRollView(runner: runner,
                                  fallback: (app.voiceRange.low - 7)...(app.voiceRange.high + 7))
                        .frame(height: 300)
                }
                VoiceReadout(meter: voice.meter, large: true)
                VoiceOptionsBar()

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 16) {
                            Picker("Key", selection: $voice.tune.key) {
                                ForEach(0..<12, id: \.self) { Text(keys[$0]).tag($0) }
                            }
                            .frame(width: 120)
                            Picker("Scale", selection: $voice.tune.scale) {
                                ForEach(AutoTune.Scale.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .frame(width: 190)
                            Picker("Style", selection: $voice.tune.style) {
                                ForEach(AutoTune.Style.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 260)
                            Spacer()
                        }
                        Text("Auto-Tune pulls each note you sing to the nearest note of the chosen scale. **Natural** nudges gently, **Robot** snaps instantly.")
                            .font(.callout).foregroundStyle(.secondary)

                        Divider()
                        HStack(spacing: 12) {
                            Text("Record a take").fontWeight(.semibold).frame(width: 130, alignment: .leading)
                            Button {
                                voice.isRecording ? voice.stopRecording() : voice.startRecording()
                            } label: {
                                Label(voice.isRecording ? "Stop recording" : "Record", systemImage: voice.isRecording ? "stop.circle.fill" : "record.circle")
                            }
                            .tint(voice.isRecording ? Palette.bad : nil)
                            .disabled(!voice.isRunning)
                            if let take = voice.take, !voice.isRecording {
                                Text(String(format: "%.0f s", take.duration)).monospacedDigit().foregroundStyle(.secondary)
                                Button { voice.play(tuned: false) } label: { Label("Play original", systemImage: "play.fill") }
                                Button { voice.play(tuned: true) } label: { Label("Play Auto-Tuned", systemImage: "wand.and.stars") }
                                    .buttonStyle(.borderedProminent)
                                if voice.isPlaying { Button("Stop") { voice.stopPlayback() } }
                                Button { save() } label: { Label("Save…", systemImage: "square.and.arrow.down") }
                            } else if voice.isRecording {
                                Text("Recording… up to \(Int(VoiceEngine.maxTakeSeconds)) seconds").foregroundStyle(Palette.bad)
                            }
                            Spacer()
                        }

                        Divider()
                        HStack(spacing: 12) {
                            Text("Hear yourself live").fontWeight(.semibold).frame(width: 130, alignment: .leading)
                            Picker("", selection: $voice.monitor) {
                                ForEach(VoiceEngine.Monitor.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 280)
                            .disabled(!app.headphones || !voice.canMonitor)
                            Text(!app.headphones ? "Turn on Headphones first, or the speakers will feed back into the microphone."
                                 : !voice.canMonitor ? "Live monitoring is not available with this microphone and output."
                                 : "Wired headphones work best; Bluetooth adds a delay.")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                    .padding(8)
                } label: {
                    Label("Auto-Tune", systemImage: "wand.and.stars").font(.headline)
                }
            }
            .padding(22)
            .frame(maxWidth: 1000, alignment: .leading)
        }
    }

    private func save() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.wav]
        panel.nameFieldStringValue = "My Auto-Tuned take.wav"
        if panel.runModal() == .OK, let url = panel.url { voice.export(tuned: true, to: url) }
    }
}
