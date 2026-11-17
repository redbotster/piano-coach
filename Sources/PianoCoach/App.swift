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
            exit(engine && importer && plan && profiles ? 0 : 1)
        }
        if let i = args.firstIndex(of: "--import-info"), args.count > i + 1 {
            for path in args[(i + 1)...] { print(SongImport.debugSummary(of: URL(fileURLWithPath: path))) }
            exit(0)
        }
        if let i = args.firstIndex(of: "--icon"), args.count > i + 1 {
            MainActor.assumeIsolated { Snapshot.renderIcon(to: args[i + 1]) }
            exit(0)
        }
        PianoCoachApp.main()
    }
}
