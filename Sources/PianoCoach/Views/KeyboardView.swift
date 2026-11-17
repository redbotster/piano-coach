import SwiftUI

enum Palette {
    static let right = Color(red: 0.16, green: 0.50, blue: 0.96)
    static let left = Color(red: 0.96, green: 0.55, blue: 0.13)
    static let either = Color(red: 0.55, green: 0.38, blue: 0.93)
    static let info = Color(red: 0.10, green: 0.68, blue: 0.72)
    static let demo = Color(red: 0.93, green: 0.76, blue: 0.16)
    static let good = Color(red: 0.20, green: 0.74, blue: 0.38)
    static let bad = Color(red: 0.92, green: 0.26, blue: 0.24)

    static func hand(_ hand: Hand) -> Color {
        switch hand {
        case .right: return right
        case .left: return left
        case .either: return either
        }
    }

    static func mark(_ mark: KeyMark) -> Color {
        switch mark.kind {
        case .target: return hand(mark.hand)
        case .info: return mark.hand == .either ? info : hand(mark.hand)
        case .demo: return demo
        case .good: return good
        case .bad: return bad
        }
    }
}

/// The full 61-key keyboard (C2–C7), drawn to match the Launchkey 61.
struct KeyboardView: View {
    var marks: [Int: KeyMark]
    var pressed: [Int: Int]
    var labelMode: LabelMode
    var low: Int = Music.lowestKey
    var high: Int = Music.highestKey
    var onPress: ((Int) -> Void)? = nil
    var onRelease: ((Int) -> Void)? = nil

    @State private var mouseNote: Int?

    private var whiteKeys: [Int] { (low...high).filter { !Music.isBlack($0) } }

    private struct Layout {
        let whiteWidth: CGFloat
        let blackWidth: CGFloat
        let blackHeight: CGFloat
        let height: CGFloat
        let whites: [Int]
        let low: Int
        let high: Int

        func whiteRect(_ note: Int) -> CGRect {
            let i = whites.firstIndex(of: note) ?? 0
            return CGRect(x: CGFloat(i) * whiteWidth, y: 0, width: whiteWidth, height: height)
        }

        func blackRect(_ note: Int) -> CGRect {
            let below = whites.firstIndex(of: note - 1) ?? 0
            // Black keys sit slightly off-centre, like a real keyboard.
            let nudge: CGFloat
            switch Music.pc(note) {
            case 1, 6: nudge = -0.08
            case 3, 10: nudge = 0.08
            default: nudge = 0
            }
            let centre = CGFloat(below + 1) * whiteWidth + nudge * whiteWidth
            return CGRect(x: centre - blackWidth / 2, y: 0, width: blackWidth, height: blackHeight)
        }

        func note(at point: CGPoint) -> Int? {
            guard point.x >= 0, point.y >= 0, point.y <= height else { return nil }
            if point.y <= blackHeight {
                for n in low...high where Music.isBlack(n) && blackRect(n).contains(point) { return n }
            }
            let i = Int(point.x / whiteWidth)
            return whites.indices.contains(i) ? whites[i] : nil
        }
    }

    private func layout(_ size: CGSize) -> Layout {
        let whites = whiteKeys
        let w = size.width / CGFloat(max(1, whites.count))
        return Layout(whiteWidth: w, blackWidth: w * 0.6, blackHeight: size.height * 0.62, height: size.height,
                      whites: whites, low: low, high: high)
    }

    var body: some View {
        GeometryReader { geo in
            let l = layout(geo.size)
            Canvas { context, size in
                draw(&context, layout: l)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let note = l.note(at: value.location)
                        if note != mouseNote {
                            if let old = mouseNote { onRelease?(old) }
                            if let note { onPress?(note) }
                            mouseNote = note
                        }
                    }
                    .onEnded { _ in
                        if let old = mouseNote { onRelease?(old) }
                        mouseNote = nil
                    }
            )
        }
    }

    private func showLabel(_ note: Int) -> Bool {
        switch labelMode {
        case .none: return false
        case .cOnly: return Music.pc(note) == 0
        case .all: return true
        }
    }

    private func draw(_ context: inout GraphicsContext, layout l: Layout) {
        let corner = CGSize(width: 3, height: 3)
        // White keys
        for note in l.whites {
            let rect = l.whiteRect(note).insetBy(dx: 0.6, dy: 0)
            let path = Path(roundedRect: rect, cornerSize: corner)
            let isDown = pressed[note] != nil
            var fill = Color(white: isDown ? 0.80 : 0.985)
            if let mark = marks[note] {
                fill = Palette.mark(mark).opacity(isDown ? 1.0 : 0.82)
            }
            context.fill(path, with: .color(fill))
            context.stroke(path, with: .color(Color(white: 0.35)), lineWidth: 0.8)
            if note == Music.middleC {
                let dot = CGRect(x: rect.midX - 2.5, y: rect.maxY - 34, width: 5, height: 5)
                context.fill(Path(ellipseIn: dot), with: .color(Color(white: 0.25).opacity(marks[note] == nil ? 0.55 : 0.9)))
            }
            let mark = marks[note]
            if let text = mark?.label ?? (showLabel(note) ? (Music.pc(note) == 0 ? Music.name(note) : Music.name(note, octave: false)) : nil) {
                let label = Text(text).font(.system(size: min(11, l.whiteWidth * 0.42), weight: mark?.label != nil ? .bold : .medium))
                    .foregroundColor(mark != nil ? .white : Color(white: 0.3))
                context.draw(label, at: CGPoint(x: rect.midX, y: rect.maxY - 12))
            }
            if let finger = mark?.finger {
                drawFinger(&context, finger, at: CGPoint(x: rect.midX, y: l.blackHeight + (l.height - l.blackHeight) * 0.38), size: l.whiteWidth)
            }
        }
        // Black keys
        for note in l.low...l.high where Music.isBlack(note) {
            let rect = l.blackRect(note)
            let path = Path(roundedRect: rect, cornerSize: corner)
            let isDown = pressed[note] != nil
            var fill = Color(white: isDown ? 0.32 : 0.10)
            let mark = marks[note]
            if let mark {
                fill = Palette.mark(mark)
            }
            context.fill(path, with: .color(fill))
            context.stroke(path, with: .color(.black), lineWidth: 0.8)
            if mark == nil, !isDown {
                let shine = CGRect(x: rect.minX + 2, y: rect.minY + 2, width: rect.width - 4, height: rect.height * 0.82)
                context.fill(Path(roundedRect: shine, cornerSize: corner), with: .color(Color(white: 0.2)))
            }
            if let text = mark?.label {
                let label = Text(text).font(.system(size: min(9.5, l.blackWidth * 0.5), weight: .bold)).foregroundColor(.white)
                context.draw(label, at: CGPoint(x: rect.midX, y: rect.maxY - 11))
            }
            if let finger = mark?.finger {
                drawFinger(&context, finger, at: CGPoint(x: rect.midX, y: rect.maxY - 30), size: l.whiteWidth)
            }
        }
    }

    private func drawFinger(_ context: inout GraphicsContext, _ finger: Int, at point: CGPoint, size: CGFloat) {
        let d = min(20, size * 0.78)
        let circle = CGRect(x: point.x - d / 2, y: point.y - d / 2, width: d, height: d)
        context.fill(Path(ellipseIn: circle), with: .color(.white))
        context.stroke(Path(ellipseIn: circle), with: .color(Color(white: 0.2)), lineWidth: 1)
        context.draw(Text("\(finger)").font(.system(size: d * 0.62, weight: .bold)).foregroundColor(.black), at: point)
    }
}
