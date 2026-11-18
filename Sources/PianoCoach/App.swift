import AVFoundation
import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var onQuit: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) { onQuit?() }
}

struct PianoCoachApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var app = AppModel()

    var body: some Scene {
        WindowGroup("Piano Coach") {
            ContentView()
                .environmentObject(app)
                .frame(minWidth: 1180, minHeight: 760)
                .onAppear { delegate.onQuit = { [weak app] in app?.shutdown() } }
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Lesson") {
                Button("Next Step") { app.nextStep() }.keyboardShortcut(.rightArrow, modifiers: .command)
                Button("Previous Step") { app.previousStep() }.keyboardShortcut(.leftArrow, modifiers: .command)
                Button("Restart Step") { app.retryTask() }.keyboardShortcut("r", modifiers: .command)
                Button("Mark Lesson Complete / Not Complete") {
                    if let id = app.lesson?.id { app.setCompleted(id, !app.isCompleted(id)) }
                }
                .keyboardShortcut("k", modifiers: .command)
                Button("Play Demo") { app.playDemo() }.keyboardShortcut("d", modifiers: .command)
                Divider()
                Button("Next Lesson") { app.goToNextLesson() }.keyboardShortcut(.rightArrow, modifiers: [.command, .shift])
                Button("Today") { app.selectedLessonID = AppModel.todayID }.keyboardShortcut("1", modifiers: .command)
                Button("Import a Song…") { app.importSong() }.keyboardShortcut("i", modifiers: .command)
                Button("Free Play") { app.selectedLessonID = AppModel.freePlayID }.keyboardShortcut("0", modifiers: .command)
            }
        }
        Settings {
            SettingsView().environmentObject(app)
        }
    }
}

@main
enum Main {
    static func main() {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--check") {
            exit(Curriculum.selfCheck(verbose: args.count > i + 1 && args[i + 1] == "-v") ? 0 : 1)
        }
        if let i = args.firstIndex(of: "--snapshot"), args.count > i + 1 {
            MainActor.assumeIsolated { Snapshot.render(to: args[i + 1], lessonID: args.count > i + 2 ? args[i + 2] : nil) }
            exit(0)
        }
        if args.contains("--selftest") {
            let engine = SelfTest.run()
            let importer = SongImport.selfTest()
            let plan = PracticePlan.selfTest()
            let profiles = ProfileStore.selfTest()
            let sequencer = NoteSequencer.selfTest()
            let voice = VoiceEngine.selfTest()
            let singing = SingRunner.selfTest()
            exit(engine && importer && plan && profiles && sequencer && voice && singing ? 0 : 1)
        }
        if let i = args.firstIndex(of: "--import-info"), args.count > i + 1 {
            for path in args[(i + 1)...] { print(SongImport.debugSummary(of: URL(fileURLWithPath: path))) }
            exit(0)
        }
        if let i = args.firstIndex(of: "--import"), args.count > i + 1 {
            // Adds files to "My Songs" without opening the window. Restart the app to see them.
            let library = SongLibrary()
            var failed = false
            for path in args[(i + 1)...] {
                let url = URL(fileURLWithPath: path)
                if library.songs.contains(where: { $0.sourceFile == url.lastPathComponent }) {
                    print("skipped (already imported): \(url.lastPathComponent)")
                    continue
                }
                do {
                    try library.importFile(at: url)
                    print("imported: \(url.lastPathComponent)")
                } catch {
                    failed = true
                    print("FAILED: \(url.lastPathComponent) — \(error)")
                }
            }
            exit(failed ? 1 : 0)
        }
        if args.contains("--voice-probe") {
            // Opens the microphone for two seconds and reports what it hears (only if access was already granted).
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            print("microphone access: \(status == .authorized ? "granted" : status == .notDetermined ? "not asked yet" : "denied")")
            guard status == .authorized else { exit(2) }
            let voice = VoiceEngine()
            var frames = 0, voiced = 0, peak = 0.0
            voice.onFrame = { frame in
                frames += 1
                if frame.midi != nil { voiced += 1 }
                peak = max(peak, frame.level)
            }
            voice.start()
            RunLoop.main.run(until: Date().addingTimeInterval(2))
            print("state: \(voice.state), live monitoring available: \(voice.canMonitor)")
            print("readings: \(frames), with a pitch: \(voiced), peak level: \(String(format: "%.3f", peak))")
            voice.monitor = .tuned
            RunLoop.main.run(until: Date().addingTimeInterval(0.5))
            voice.stop()
            exit(voice.state == .off && frames > 0 ? 0 : 1)
        }
        if let i = args.firstIndex(of: "--icon"), args.count > i + 1 {
            MainActor.assumeIsolated { Snapshot.renderIcon(to: args[i + 1]) }
            exit(0)
        }
        PianoCoachApp.main()
    }
}
