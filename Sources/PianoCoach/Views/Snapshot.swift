import AppKit
import SwiftUI

/// Renders lesson steps to PNG files for visual checking: `PianoCoach --snapshot <dir> [lessonID]`.
@MainActor
enum Snapshot {
    struct StepShot: View {
        @ObservedObject var app: AppModel
        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                if let step = app.step {
                    switch step {
                    case .info(let info): InfoStepView(info: info)
                    case .checklist(let list): ChecklistStepView(list: list)
                    case .play(let task): if let r = app.runner { TaskView(runner: r, task: task, quiz: nil) }
                    case .quiz(let quiz): if let r = app.runner { TaskView(runner: r, task: r.task, quiz: quiz) }
                    case .sing: if let r = app.singRunner { SingTaskView(runner: r) }
                    }
                }
                if let runner = app.runner, runner.task.isTimed, runner.task.showTargets {
                    FallingNotesView(task: runner.task, statuses: runner.statuses, clock: runner.clock, bpm: runner.bpm)
                        .frame(height: 130)
                }
                KeyboardView(marks: app.keyMarks, pressed: app.pressed, labelMode: .cOnly).frame(height: 170)
            }
            .padding(20)
            .frame(width: 1100)
            .background(Color.white)
            .environmentObject(app)
            .environment(\.colorScheme, .light)
        }
    }

    static func render(to directory: String, lessonID: String?) {
        AppModel.headless = true
        let app = AppModel()
        app.soundOn = false
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let id = lessonID ?? app.lessonOrder.first
        app.selectedLessonID = id
        guard let lesson = app.lesson else { print("no such lesson"); return }
        for i in lesson.steps.indices {
            app.goToStep(i)
            let renderer = ImageRenderer(content: StepShot(app: app))
            renderer.scale = 1.5
            guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) else { continue }
            let path = "\(directory)/\(lesson.id)-\(i).png"
            try? png.write(to: URL(fileURLWithPath: path))
            print(path)
        }
    }
}

/// App icon artwork, rendered by `PianoCoach --icon <png>` during packaging.
struct AppIconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 225, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.20, green: 0.42, blue: 0.98), Color(red: 0.42, green: 0.22, blue: 0.80)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            HStack(spacing: 14) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(i == 2 ? Color(red: 1.0, green: 0.80, blue: 0.25) : Color.white)
                        .frame(width: 124, height: 560)
                }
            }
            .offset(y: 60)
            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(white: 0.10))
                        .frame(width: 84, height: 340)
                        .opacity(i == 1 ? 0 : 1)
                        .padding(.horizontal, 27)
                }
            }
            .offset(y: -50)
        }
        .frame(width: 824, height: 824)
        .padding(100)
    }
}

extension Snapshot {
    static func renderIcon(to path: String) {
        let renderer = ImageRenderer(content: AppIconView())
        renderer.scale = 1
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }
}
