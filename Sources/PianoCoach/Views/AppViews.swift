import SwiftUI

struct ContentView: View {
    @EnvironmentObject var app: AppModel

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 250, ideal: 290, max: 380)
        } detail: {
            VStack(spacing: 0) {
                Group {
                    if let lesson = app.lesson {
                        LessonView(lesson: lesson).id(lesson.id)
                    } else if app.selectedLessonID == AppModel.progressID {
                        ProgressDashboard()
                    } else if app.selectedLessonID == AppModel.freePlayID {
                        FreePlayView()
                    } else {
                        TodayView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                KeyboardPanel()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    app.selectedLessonID = AppModel.todayID
                } label: { Label("Today", systemImage: "sun.max") }
                .help("Today's practice plan")
            }
            ToolbarItemGroup(placement: .primaryAction) {
                MIDIStatusView()
                Toggle(isOn: $app.soundOn) {
                    Label("Piano sound", systemImage: app.soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                }
                .help("Play a piano sound through the Mac when you press keys")
                Picker("Key names", selection: $app.labelMode) {
                    ForEach(LabelMode.allCases) { Text("Names: \($0.rawValue)").tag($0) }
                }
                .help("Note names printed on the on-screen keys")
            }
        }
    }
}

struct MIDIStatusView: View {
    @EnvironmentObject var app: AppModel

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(app.midi.isConnected ? Palette.good : Palette.bad).frame(width: 9, height: 9)
            Text(app.midi.launchkeyName ?? app.midi.sourceNames.first ?? "No MIDI keyboard")
                .font(.callout)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .help(app.midi.isConnected
              ? "Connected: " + app.midi.sourceNames.joined(separator: ", ")
              : "Plug in your Launchkey by USB. Until then you can click the keys or type A S D F G H J K (W E T Y U for black keys, Z/X to change octave).")
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject var app: AppModel
    @State private var expanded: Set<String> = []

    var body: some View {
        List(selection: $app.selectedLessonID) {
            Section {
                Label("Today", systemImage: "sun.max").tag(Optional(AppModel.todayID))
                Label("Progress", systemImage: "chart.line.uptrend.xyaxis").tag(Optional(AppModel.progressID))
                Label("Free play", systemImage: "pianokeys").tag(Optional(AppModel.freePlayID))
                Button {
                    app.importSong()
                } label: { Label("Import a song…", systemImage: "square.and.arrow.down") }
                .buttonStyle(.plain)
                .help("Add a MIDI or MusicXML file to My Songs")
            }
            ForEach(app.sections) { section in
                Section {
                    ForEach(section.units) { unit in
                        DisclosureGroup(isExpanded: binding(unit.id)) {
                            ForEach(unit.lessons) { lesson in
                                LessonRow(lesson: lesson).tag(Optional(lesson.id))
                                    .contextMenu {
                                        if app.library.contains(lesson.id) {
                                            Button("Remove from My Songs", role: .destructive) { app.removeImportedSong(lesson.id) }
                                        }
                                    }
                            }
                        } label: {
                            HStack {
                                Text(unit.title).fontWeight(.medium)
                                Spacer()
                                let done = unit.lessons.filter { app.progress.record($0.id).completed }.count
                                Text("\(done)/\(unit.lessons.count)")
                                    .font(.caption).monospacedDigit()
                                    .foregroundStyle(done == unit.lessons.count ? Palette.good : .secondary)
                            }
                        }
                    }
                } header: {
                    Label(section.title, systemImage: section.symbol)
                }
            }
        }
        .listStyle(.sidebar)
        .onAppear { revealSelection() }
        .onChange(of: app.selectedLessonID) { _, _ in revealSelection() }
    }

    private func revealSelection() {
        if let id = app.selectedLessonID, let entry = app.lessonIndex[id] {
            expanded.insert(entry.unit.id)
        } else if expanded.isEmpty, let first = app.sections.first?.units.first {
            expanded.insert(first.id)
        }
    }

    private func binding(_ id: String) -> Binding<Bool> {
        Binding(get: { expanded.contains(id) },
                set: { open in if open { expanded.insert(id) } else { expanded.remove(id) } })
    }
}

struct LessonRow: View {
    @EnvironmentObject var app: AppModel
    let lesson: Lesson

    var body: some View {
        let record = app.progress.record(lesson.id)
        HStack(spacing: 8) {
            Image(systemName: record.completed ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(record.completed ? Palette.good : Color.secondary.opacity(0.5))
            Text(lesson.title).lineLimit(2)
            Spacer()
            if record.completed, lesson.steps.contains(where: { $0.isScored }) {
                StarsView(stars: record.stars, size: 9)
            }
        }
        .help(lesson.summary)
    }
}

// MARK: - Keyboard panel

struct KeyboardPanel: View {
    @EnvironmentObject var app: AppModel

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 14) {
                legend(Palette.right, "Right hand")
                legend(Palette.left, "Left hand")
                legend(Palette.good, "Correct")
                legend(Palette.bad, "Wrong")
                Spacer()
                if app.outOfRange {
                    Label("That note is outside the 61 keys shown — press Octave +/− on the Launchkey until both lights are off.",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(Palette.left)
                }
                if let chord = Music.identifyChord(Array(app.pressed.keys)) {
                    Text(chord).font(.system(size: 15, weight: .bold, design: .rounded))
                } else if app.pressed.count == 1, let note = app.pressed.keys.first {
                    Text(Music.isBlack(note) ? Music.bothNames(note) : Music.name(note))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                if let velocity = app.lastVelocity {
                    HStack(spacing: 4) {
                        Text("Velocity").font(.caption).foregroundStyle(.secondary)
                        ProgressView(value: Double(velocity), total: 127).frame(width: 70)
                        Text("\(velocity)").font(.caption).monospacedDigit().frame(width: 26, alignment: .trailing)
                    }
                }
                Label("Pedal", systemImage: app.pedalDown ? "rectangle.fill" : "rectangle")
                    .font(.caption)
                    .foregroundStyle(app.pedalDown ? Palette.right : Color.secondary.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .frame(height: 22)

            KeyboardView(marks: app.keyMarks, pressed: app.pressed, labelMode: app.labelMode,
                         onPress: { app.handle(.noteOn(note: $0, velocity: 80, time: HostClock.now())) },
                         onRelease: { app.handle(.noteOff(note: $0, time: HostClock.now())) })
                .frame(height: 170)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
        }
        .padding(.top, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Free play / overview

struct FreePlayView: View {
    @EnvironmentObject var app: AppModel

    private var allLessons: [Lesson] { app.sections.flatMap { $0.units.flatMap { $0.lessons } } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Piano Coach").font(.largeTitle.weight(.bold))
                Text("Pick a lesson in the sidebar, or just play. The keyboard below mirrors your Launchkey 61: keys light up in blue for the right hand and orange for the left.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 640, alignment: .leading)

                if !app.midi.isConnected {
                    Label("No MIDI keyboard detected. Connect the Launchkey by USB — it appears here automatically. Meanwhile, click the keys or type A S D F G H J K.",
                          systemImage: "cable.connector")
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Palette.left.opacity(0.14)))
                }

                HStack(spacing: 14) {
                    ForEach(app.sections) { section in
                        let lessons = section.units.flatMap { $0.lessons }
                        let done = lessons.filter { app.progress.record($0.id).completed }.count
                        VStack(alignment: .leading, spacing: 8) {
                            Label(section.title, systemImage: section.symbol).font(.headline)
                            ProgressView(value: Double(done), total: Double(max(1, lessons.count)))
                            Text("\(done) of \(lessons.count) lessons").font(.caption).foregroundStyle(.secondary)
                            Button(done == 0 ? "Start" : "Continue") {
                                app.selectedLessonID = (lessons.first { !app.progress.record($0.id).completed } ?? lessons.first)?.id
                            }
                            .disabled(lessons.isEmpty)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.05)))
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Live readout").font(.headline)
                    HStack(spacing: 28) {
                        readout("Holding", app.pressed.isEmpty ? "—" : app.pressed.keys.sorted().map { Music.name($0) }.joined(separator: " "))
                        readout("Chord", Music.identifyChord(Array(app.pressed.keys)) ?? "—")
                        readout("Last velocity", app.lastVelocity.map { "\($0)" } ?? "—")
                        readout("Evenness (last \(app.recentVelocities.count))", evenness)
                    }
                    VelocityBars(values: app.recentVelocities)
                        .frame(height: 70)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.05)))
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var evenness: String {
        let v = app.recentVelocities.map(Double.init)
        guard v.count > 2 else { return "—" }
        let mean = v.reduce(0, +) / Double(v.count)
        let sd = sqrt(v.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(v.count))
        return String(format: "±%.0f", sd)
    }

    private func readout(_ name: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: 20, weight: .semibold, design: .rounded)).lineLimit(1)
        }
    }
}

struct VelocityBars: View {
    let values: [Int]

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Palette.right.opacity(0.75))
                        .frame(width: 10, height: max(2, geo.size.height * CGFloat(value) / 127))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject var app: AppModel
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section("Sound") {
                Toggle("Play piano sound through the Mac", isOn: $app.soundOn)
                Text("The Launchkey makes no sound of its own. Turn this off if you are also running a DAW or synth.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Timing") {
                HStack {
                    Text("Latency compensation")
                    Slider(value: $app.latencyMs, in: 0...80, step: 5)
                    Text("\(Int(app.latencyMs)) ms").monospacedDigit().frame(width: 50)
                }
                Text("If timing results always say you are late even when you feel on the beat (common with Bluetooth headphones), raise this.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Launchkey") {
                Toggle("Flash the pads green / red for right and wrong notes (experimental)", isOn: $app.padLights)
                    .disabled(!app.midi.canLightPads)
                Text(app.midi.canLightPads
                     ? "Uses the Launchkey's DAW port. The keys themselves have no lights, so the on-screen keyboard shows what to play."
                     : "Available when a Launchkey is connected. The keys themselves have no lights, so the on-screen keyboard shows what to play.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Progress") {
                Button("Reset all progress…", role: .destructive) { confirmReset = true }
                    .confirmationDialog("Erase all lesson progress and stars?", isPresented: $confirmReset) {
                        Button("Erase progress", role: .destructive) { app.progress.reset() }
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 430)
    }
}
