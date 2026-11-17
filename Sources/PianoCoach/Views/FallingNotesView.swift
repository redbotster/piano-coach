import SwiftUI

/// Notes fall towards the keyboard and land on their key at the moment they should be played.
struct FallingNotesView: View {
    let task: PlayTask
    var statuses: [EventStatus]
    @ObservedObject var clock: PlayheadClock
    var bpm: Double

    /// Beats visible from top to bottom: about three seconds of music.
    private var windowBeats: Double { min(10, max(2.5, 3.0 * bpm / 60)) }

    var body: some View {
        Canvas { context, size in
            let layout = KeyLayout(size: CGSize(width: size.width, height: 170))
            let perBeat = size.height / CGFloat(windowBeats)
            let now = clock.beat
            let bar = Double(task.timedConfig?.beatsPerBar ?? 4)

            // Beat and bar lines
            var beat = max(0, now.rounded(.down))
            while beat <= now + windowBeats {
                let y = size.height - CGFloat(beat - now) * perBeat
                let isBar = beat.truncatingRemainder(dividingBy: bar) == 0
                context.stroke(Path { $0.move(to: CGPoint(x: 0, y: y)); $0.addLine(to: CGPoint(x: size.width, y: y)) },
                               with: .color(Color.primary.opacity(isBar ? 0.22 : 0.08)), lineWidth: 1)
                beat += 1
            }
            // Faint guide for each octave's C
            for note in stride(from: Music.lowestKey, through: Music.highestKey, by: 12) {
                let x = layout.whiteRect(note).minX
                context.stroke(Path { $0.move(to: CGPoint(x: x, y: 0)); $0.addLine(to: CGPoint(x: x, y: size.height)) },
                               with: .color(Color.primary.opacity(0.06)), lineWidth: 1)
            }

            for (i, event) in task.events.enumerated() {
                let status = i < statuses.count ? statuses[i] : .pending
                for spec in event.notes {
                    let length = spec.duration ?? event.duration
                    let bottom = size.height - CGFloat(event.beat - now) * perBeat
                    let top = bottom - CGFloat(length) * perBeat + 2
                    guard bottom > -4, top < size.height else { continue }
                    let key = layout.rect(spec.midi)
                    let width = Music.isBlack(spec.midi) ? key.width : key.width - 4
                    let rect = CGRect(x: key.midX - width / 2, y: top, width: width, height: max(6, bottom - top))
                    var color = Palette.hand(spec.hand)
                    var opacity = Music.isBlack(spec.midi) ? 1.0 : 0.85
                    switch status {
                    case .correct: color = Palette.good; opacity = 0.45
                    case .wrong, .missed: color = Palette.bad; opacity = 0.45
                    case .pending: break
                    }
                    let path = Path(roundedRect: rect, cornerRadius: 4)
                    context.fill(path, with: .color(color.opacity(opacity)))
                    context.stroke(path, with: .color(.white.opacity(0.5)), lineWidth: 0.8)
                    if let finger = spec.finger, task.showFingers, rect.height > 15, status == .pending {
                        context.draw(Text("\(finger)").font(.system(size: min(11, width * 0.8), weight: .bold)).foregroundColor(.white),
                                     at: CGPoint(x: rect.midX, y: rect.maxY - 8))
                    }
                }
            }
        }
        .background(Color.primary.opacity(0.035))
        .clipped()
    }
}
