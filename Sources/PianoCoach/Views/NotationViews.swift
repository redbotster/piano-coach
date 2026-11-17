import SwiftUI

private let musicFont = "Apple Symbols"

private func statusColor(_ status: EventStatus, isCurrent: Bool, hand: Hand) -> Color {
    switch status {
    case .correct: return Palette.good
    case .wrong, .missed: return Palette.bad
    case .pending: return isCurrent ? Palette.hand(hand) : Color.primary
    }
}

// MARK: - Staff

struct StaffLayout {
    let task: PlayTask
    let width: CGFloat
    let hasTreble: Bool
    let hasBass: Bool
    let left: CGFloat
    let total: Double
    let beatsPerRow: Double
    let rows: Int
    let pxPerBeat: CGFloat
    let spacing: CGFloat = 10

    init(task: PlayTask, width: CGFloat) {
        self.task = task
        self.width = width
        let all = task.events.flatMap { $0.notes }
        let lowest = all.map { $0.midi }.min() ?? 60
        let highest = all.map { $0.midi }.max() ?? 72
        let usesLeft = all.contains { $0.hand == .left }
        let usesRight = all.contains { $0.hand == .right }
        switch task.clef {
        case .treble: hasTreble = true; hasBass = false
        case .bass: hasTreble = false; hasBass = true
        case .grand: hasTreble = true; hasBass = true
        case .auto:
            if usesLeft && usesRight { hasTreble = true; hasBass = true }
            else if lowest >= 55 { hasTreble = true; hasBass = false }
            else if highest <= 64 { hasTreble = false; hasBass = true }
            else { hasTreble = true; hasBass = true }
        }
        let timeSig: CGFloat = task.isTimed ? 26 : 0
        left = 52 + CGFloat(abs(task.keySignature)) * 10 + timeSig
        let lastEnd = task.events.map { $0.beat + $0.duration }.max() ?? 1
        total = max(task.isTimed ? task.totalBeats : lastEnd, 1)

        let beats = Array(Set(task.events.map { $0.beat })).sorted()
        var minGap = 1.0
        for i in beats.indices.dropFirst() { minGap = min(minGap, beats[i] - beats[i - 1]) }
        minGap = max(minGap, 0.125)
        let minPx = min(130, 26 / minGap)
        let available = max(120, width - left - 30)
        let fit = Double(available) / minPx
        if total <= fit {
            rows = 1
            beatsPerRow = total
            pxPerBeat = min(available / CGFloat(total), 95)
        } else {
            let bar = Double(task.timedConfig?.beatsPerBar ?? 1)
            beatsPerRow = max(bar, (fit / bar).rounded(.down) * bar)
            rows = Int((total / beatsPerRow).rounded(.up))
            pxPerBeat = available / CGFloat(beatsPerRow)
        }
    }

    var rowHeight: CGFloat { hasTreble && hasBass ? 196 : 118 }
    var height: CGFloat { CGFloat(rows) * rowHeight }

    func row(of beat: Double) -> Int { min(rows - 1, max(0, Int((beat + 1e-6) / beatsPerRow))) }

    func x(_ beat: Double, row: Int) -> CGFloat {
        left + 16 + CGFloat(beat - Double(row) * beatsPerRow) * pxPerBeat
    }

    /// Y of the top line of each staff inside a row.
    var trebleTop: CGFloat { 38 }
    var bassTop: CGFloat { hasTreble ? 38 + 4 * spacing + 62 : 38 }

    func y(step: Int, treble: Bool) -> CGFloat {
        treble ? trebleTop + CGFloat(38 - step) * spacing / 2 : bassTop + CGFloat(26 - step) * spacing / 2
    }

    func onTreble(_ spec: NoteSpec) -> Bool {
        if hasTreble && !hasBass { return true }
        if hasBass && !hasTreble { return false }
        switch spec.hand {
        case .left: return false
        case .right: return true
        case .either: return spec.midi >= 60
        }
    }
}

struct StaffView: View {
    let task: PlayTask
    var statuses: [EventStatus] = []
    var current: Int? = nil
    var clock: PlayheadClock? = nil
    var showPlayhead = false

    var body: some View {
        GeometryReader { geo in
            let layout = StaffLayout(task: task, width: geo.size.width)
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    for row in 0..<layout.rows {
                        context.translateBy(x: 0, y: CGFloat(row) * layout.rowHeight)
                        drawRow(&context, layout: layout, row: row)
                        context.translateBy(x: 0, y: -CGFloat(row) * layout.rowHeight)
                    }
                }
                if showPlayhead, task.isTimed, let clock {
                    StaffPlayhead(clock: clock, layout: layout)
                }
            }
        }
        .frame(height: StaffLayout(task: task, width: 900).height)
    }

    private func drawRow(_ context: inout GraphicsContext, layout l: StaffLayout, row: Int) {
        let ink = Color.primary
        let s = l.spacing
        let x0: CGFloat = 8
        let x1 = l.width - 8
        var tops: [(top: CGFloat, treble: Bool)] = []
        if l.hasTreble { tops.append((l.trebleTop, true)) }
        if l.hasBass { tops.append((l.bassTop, false)) }

        for staff in tops {
            for i in 0..<5 {
                let y = staff.top + CGFloat(i) * s
                context.stroke(Path { $0.move(to: CGPoint(x: x0, y: y)); $0.addLine(to: CGPoint(x: x1, y: y)) },
                               with: .color(ink.opacity(0.55)), lineWidth: 1)
            }
            // Clef
            if staff.treble {
                context.draw(Text("𝄞").font(.custom(musicFont, size: 62)).foregroundColor(ink),
                             at: CGPoint(x: x0 + 20, y: staff.top + 2.1 * s))
            } else {
                context.draw(Text("𝄢").font(.custom(musicFont, size: 46)).foregroundColor(ink),
                             at: CGPoint(x: x0 + 20, y: staff.top + 1.75 * s))
            }
            // Key signature
            let sharps = [38, 35, 39, 36, 33, 37, 34]
            let flats = [34, 37, 33, 36, 32, 35, 31]
            let count = min(7, abs(task.keySignature))
            for i in 0..<count {
                let trebleStep = task.keySignature > 0 ? sharps[i] : flats[i]
                let step = staff.treble ? trebleStep : trebleStep - 14
                let y = l.y(step: step, treble: staff.treble)
                context.draw(Text(task.keySignature > 0 ? "♯" : "♭").font(.system(size: 19)).foregroundColor(ink),
                             at: CGPoint(x: x0 + 42 + CGFloat(i) * 10, y: y - (task.keySignature > 0 ? 0 : 4)))
            }
            // Time signature
            if let config = task.timedConfig, row == 0 {
                let x = l.left - 12
                context.draw(Text("\(config.beatsPerBar)").font(.system(size: 23, weight: .heavy, design: .serif)).foregroundColor(ink),
                             at: CGPoint(x: x, y: staff.top + s))
                context.draw(Text("\(config.beatUnit)").font(.system(size: 23, weight: .heavy, design: .serif)).foregroundColor(ink),
                             at: CGPoint(x: x, y: staff.top + 3 * s))
            }
        }
        // Left bar and brace line for a grand staff, plus bar lines.
        let top = tops.first?.top ?? 0
        let bottom = (tops.last?.top ?? 0) + 4 * s
        func barLine(_ x: CGFloat, width: CGFloat = 1) {
            context.stroke(Path { $0.move(to: CGPoint(x: x, y: top)); $0.addLine(to: CGPoint(x: x, y: bottom)) },
                           with: .color(ink.opacity(0.7)), lineWidth: width)
        }
        barLine(x0)
        barLine(x1)
        if let config = task.timedConfig {
            let bar = Double(config.beatsPerBar)
            let first = Double(row) * l.beatsPerRow
            var b = first + bar
            while b < min(l.total, first + l.beatsPerRow) - 1e-6 {
                barLine(l.x(b, row: row) - min(22, max(12, l.pxPerBeat * 0.3)))
                b += bar
            }
        }

        // Rests (timed tasks only): silence on each staff, split at bar lines.
        if let config = task.timedConfig {
            let unitQ = 4 / Double(config.beatUnit)
            let bar = Double(config.beatsPerBar)
            let rowStart = Double(row) * l.beatsPerRow
            let rowEnd = min(l.total, rowStart + l.beatsPerRow)
            for staff in tops {
                var spans: [(Double, Double)] = []
                for event in task.events {
                    let mine = event.notes.filter { l.onTreble($0) == staff.treble }
                    guard let longest = mine.map({ $0.duration ?? event.duration }).max() else { continue }
                    spans.append((event.beat, event.beat + longest))
                }
                var barStart = rowStart
                while barStart < rowEnd - 1e-6 {
                    let barEnd = min(barStart + bar, rowEnd)
                    var cursor = barStart
                    var gaps: [(Double, Double)] = []
                    for span in spans.sorted(by: { $0.0 < $1.0 }) where span.1 > barStart + 1e-6 && span.0 < barEnd - 1e-6 {
                        if span.0 - cursor > 0.02 { gaps.append((cursor, span.0)) }
                        cursor = max(cursor, min(span.1, barEnd))
                    }
                    if barEnd - cursor > 0.02 { gaps.append((cursor, barEnd)) }
                    let midY = staff.top + 2 * s
                    for gap in gaps {
                        if gap.0 == barStart, abs(gap.1 - barStart - bar) < 0.01 {
                            let cx = (l.x(barStart, row: row) + l.x(barEnd, row: row)) / 2 - 10
                            NoteDraw.rest(&context, at: CGPoint(x: cx, y: midY), quarters: 4, color: ink.opacity(0.75))
                        } else {
                            for (offset, value) in NoteDraw.restValues((gap.1 - gap.0) * unitQ) {
                                NoteDraw.rest(&context, at: CGPoint(x: l.x(gap.0 + offset / unitQ, row: row), y: midY),
                                              quarters: value, color: ink.opacity(0.75))
                            }
                        }
                    }
                    barStart += bar
                }
            }
        }

        // Notes
        let unit = Double(task.timedConfig?.beatUnit ?? 4)
        for (i, event) in task.events.enumerated() where l.row(of: event.beat) == row {
            let status = i < statuses.count ? statuses[i] : .pending
            let x = l.x(event.beat, row: row)
            for spec in event.notes {
                let treble = l.onTreble(spec)
                let color = statusColor(status, isCurrent: current == i, hand: spec.hand)
                let spelled = Spelling.spell(spec.midi, fifths: task.keySignature, preferFlats: task.preferFlats)
                let y = l.y(step: spelled.step, treble: treble)
                drawLedgers(&context, layout: l, step: spelled.step, treble: treble, x: x)
                let noteQuarters = (spec.duration ?? event.duration) * 4 / unit
                NoteDraw.note(&context, at: CGPoint(x: x, y: y), quarters: noteQuarters, color: color,
                              stemUp: spelled.step < (treble ? 34 : 22))
                if let accidental = spelled.accidental {
                    context.draw(Text(accidental).font(.system(size: 17)).foregroundColor(color),
                                 at: CGPoint(x: x - 15, y: y - (accidental == "♭" ? 3 : 0)))
                }
                if task.showFingers, let finger = spec.finger {
                    let fy = treble ? l.trebleTop - 26 : l.bassTop + 4 * s + 26
                    context.draw(Text("\(finger)").font(.system(size: 11, weight: .semibold)).foregroundColor(color.opacity(0.9)),
                                 at: CGPoint(x: x, y: fy))
                }
                if event.articulation == .staccato {
                    let dot = CGRect(x: x - 2, y: y + (spelled.step < (treble ? 34 : 22) ? 9 : -13), width: 4, height: 4)
                    context.fill(Path(ellipseIn: dot), with: .color(color))
                }
                if event.accent {
                    context.draw(Text(">").font(.system(size: 13, weight: .bold)).foregroundColor(color),
                                 at: CGPoint(x: x, y: y + (spelled.step < (treble ? 34 : 22) ? 15 : -15)))
                }
            }
            if let label = event.label, task.display == .staff {
                context.draw(Text(label).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary),
                             at: CGPoint(x: x, y: bottom + 30))
            }
        }
    }

    private func drawLedgers(_ context: inout GraphicsContext, layout l: StaffLayout, step: Int, treble: Bool, x: CGFloat) {
        let topStep = treble ? 38 : 26
        let bottomStep = topStep - 8
        var steps: [Int] = []
        if step >= topStep + 2 { steps = Array(stride(from: topStep + 2, through: step, by: 2)) }
        if step <= bottomStep - 2 { steps = Array(stride(from: bottomStep - 2, through: step, by: -2)) }
        for ledger in steps {
            let y = l.y(step: ledger, treble: treble)
            context.stroke(Path { $0.move(to: CGPoint(x: x - 10, y: y)); $0.addLine(to: CGPoint(x: x + 10, y: y)) },
                           with: .color(Color.primary.opacity(0.7)), lineWidth: 1.2)
        }
    }

}

private struct StaffPlayhead: View {
    @ObservedObject var clock: PlayheadClock
    let layout: StaffLayout

    var body: some View {
        let beat = clock.beat
        if beat >= 0, beat <= layout.total {
            let row = layout.row(of: beat)
            Rectangle()
                .fill(Palette.right.opacity(0.55))
                .frame(width: 2, height: layout.rowHeight - 36)
                .offset(x: layout.x(beat, row: row) - 1, y: CGFloat(row) * layout.rowHeight + 18)
        }
    }
}


// MARK: - Shared note and rest drawing

/// Notes and rests drawn as paths, because the system fonts lack most music glyphs.
enum NoteDraw {
    static func isDotted(_ q: Double) -> Bool {
        [3.0, 1.5, 0.75, 0.375, 6.0].contains { abs($0 - q) < 0.01 }
    }

    static func isTuplet(_ q: Double) -> Bool {
        [1.0 / 3, 2.0 / 3, 4.0 / 3, 1.0 / 6, 0.2, 0.4, 0.8].contains { abs($0 - q) < 0.01 }
    }

    static func tupletNumber(_ q: Double) -> String {
        [0.2, 0.4, 0.8].contains { abs($0 - q) < 0.01 } ? "5" : abs(q - 1.0 / 6) < 0.01 ? "6" : "3"
    }

    /// `scale` 1 matches a staff with 10 pt line spacing.
    static func note(_ context: inout GraphicsContext, at p: CGPoint, quarters: Double, color: Color,
                     stemUp: Bool, scale k: CGFloat = 1) {
        let head = CGRect(x: p.x - 6.2 * k, y: p.y - 4.4 * k, width: 12.4 * k, height: 8.8 * k)
        let hollow = quarters >= 1.99
        var headContext = context
        headContext.translateBy(x: p.x, y: p.y)
        headContext.rotate(by: .degrees(-18))
        headContext.translateBy(x: -p.x, y: -p.y)
        if hollow {
            headContext.stroke(Path(ellipseIn: head.insetBy(dx: 0.9 * k, dy: 0.9 * k)), with: .color(color), lineWidth: 1.9 * k)
        } else {
            headContext.fill(Path(ellipseIn: head), with: .color(color))
        }
        if quarters < 3.99 {
            let sx = stemUp ? p.x + 5.6 * k : p.x - 5.6 * k
            let end = stemUp ? p.y - 33 * k : p.y + 33 * k
            context.stroke(Path { $0.move(to: CGPoint(x: sx, y: p.y)); $0.addLine(to: CGPoint(x: sx, y: end)) },
                           with: .color(color), lineWidth: 1.3 * k)
            let base = quarters / (isDotted(quarters) ? 1.5 : 1)
            let flags = base <= 0.13 ? 3 : base <= 0.26 ? 2 : base <= 0.51 ? 1 : 0
            for f in 0..<flags {
                let fy = end + CGFloat(f) * (stemUp ? 6 : -6) * k
                context.stroke(Path {
                    $0.move(to: CGPoint(x: sx, y: fy))
                    $0.addQuadCurve(to: CGPoint(x: sx + 8 * k, y: fy + (stemUp ? 12 : -12) * k),
                                    control: CGPoint(x: sx + 9 * k, y: fy + (stemUp ? 4 : -4) * k))
                }, with: .color(color), lineWidth: 1.6 * k)
            }
        }
        if isDotted(quarters) {
            context.fill(Path(ellipseIn: CGRect(x: p.x + 10 * k, y: p.y - 4 * k, width: 3.6 * k, height: 3.6 * k)), with: .color(color))
        }
        if isTuplet(quarters) {
            context.draw(Text(tupletNumber(quarters)).font(.system(size: 10 * k, weight: .semibold).italic()).foregroundColor(color),
                         at: CGPoint(x: p.x, y: p.y + (stemUp ? 16 : -16) * k))
        }
    }

    /// A rest centred on `p` (the middle staff line).
    static func rest(_ context: inout GraphicsContext, at p: CGPoint, quarters: Double, color: Color, scale k: CGFloat = 1) {
        if quarters >= 1.99 {
            let whole = quarters >= 3.99
            // Whole rest hangs below the 4th line; half rest sits on the middle line.
            let y = whole ? p.y - 10 * k : p.y - 5 * k
            context.fill(Path(CGRect(x: p.x - 6.5 * k, y: y, width: 13 * k, height: 5 * k)), with: .color(color))
            let lineY = whole ? p.y - 10 * k : p.y
            context.stroke(Path { $0.move(to: CGPoint(x: p.x - 10 * k, y: lineY)); $0.addLine(to: CGPoint(x: p.x + 10 * k, y: lineY)) },
                           with: .color(color), lineWidth: 1 * k)
        } else if quarters >= 0.99 {
            var path = Path()
            path.move(to: CGPoint(x: p.x - 3 * k, y: p.y - 14 * k))
            path.addLine(to: CGPoint(x: p.x + 4 * k, y: p.y - 5 * k))
            path.addLine(to: CGPoint(x: p.x - 3 * k, y: p.y + 2 * k))
            path.addLine(to: CGPoint(x: p.x + 4 * k, y: p.y + 9 * k))
            path.addQuadCurve(to: CGPoint(x: p.x + 1 * k, y: p.y + 16 * k), control: CGPoint(x: p.x - 8 * k, y: p.y + 7 * k))
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2.6 * k, lineCap: .round, lineJoin: .round))
        } else {
            let flags = quarters >= 0.49 ? 1 : quarters >= 0.24 ? 2 : 3
            context.stroke(Path {
                $0.move(to: CGPoint(x: p.x + 5 * k, y: p.y - 8 * k))
                $0.addLine(to: CGPoint(x: p.x - 2 * k, y: p.y + (6 + CGFloat(flags) * 5) * k))
            }, with: .color(color), lineWidth: 1.5 * k)
            for f in 0..<flags {
                let fy = p.y - 6 * k + CGFloat(f) * 6.5 * k
                let fx = p.x - 4 * k - CGFloat(f) * 1.2 * k
                context.fill(Path(ellipseIn: CGRect(x: fx - 2.6 * k, y: fy - 2.6 * k, width: 5.2 * k, height: 5.2 * k)), with: .color(color))
                context.stroke(Path {
                    $0.move(to: CGPoint(x: fx, y: fy + 1.5 * k))
                    $0.addQuadCurve(to: CGPoint(x: p.x + 4.2 * k - CGFloat(f) * 1.6 * k, y: fy - 1.5 * k),
                                    control: CGPoint(x: fx + 4 * k, y: fy + 3 * k))
                }, with: .color(color), lineWidth: 1.3 * k)
            }
        }
    }

    /// Break a silence into standard rest values. Returns (start offset in quarters, value in quarters).
    static func restValues(_ quarters: Double) -> [(Double, Double)] {
        var out: [(Double, Double)] = []
        var position = 0.0
        var remaining = quarters
        for value in [4.0, 2.0, 1.0, 0.5, 0.25, 0.125] {
            while remaining >= value - 0.01 {
                out.append((position, value))
                position += value
                remaining -= value
            }
        }
        return out
    }
}

/// Symbol shown beside lesson text. "note:q", "rest:e" (several allowed) are drawn; anything else is set as text.
struct GlyphView: View {
    let spec: String

    private var drawn: [(rest: Bool, quarters: Double)] {
        let tokens = spec.split(separator: " ").map(String.init)
        var out: [(Bool, Double)] = []
        for token in tokens {
            if token.hasPrefix("note:") { out.append((false, L.dur(String(token.dropFirst(5))).beats)) }
            else if token.hasPrefix("rest:") { out.append((true, L.dur(String(token.dropFirst(5))).beats)) }
            else { return [] }
        }
        return out
    }

    var body: some View {
        let items = drawn
        if items.isEmpty {
            Text(spec)
                .font(spec.unicodeScalars.allSatisfy({ $0.isASCII }) ? .system(size: spec.count > 4 ? 30 : 46, weight: .bold, design: .serif).italic()
                      : .custom("Apple Symbols", size: spec.count > 3 ? 44 : 64))
                .multilineTextAlignment(.center)
        } else {
            Canvas { context, size in
                let step = size.width / CGFloat(items.count)
                for (i, item) in items.enumerated() {
                    let p = CGPoint(x: step * (CGFloat(i) + 0.5), y: size.height / 2 + (item.rest ? 0 : 18))
                    if item.rest {
                        NoteDraw.rest(&context, at: p, quarters: item.quarters, color: .primary, scale: 1.5)
                    } else {
                        NoteDraw.note(&context, at: p, quarters: item.quarters, color: .primary, stemUp: true, scale: 1.5)
                    }
                }
            }
            .frame(width: CGFloat(max(1, items.count)) * 46, height: 96)
        }
    }
}

// MARK: - Rhythm lane

struct RhythmLaneView: View {
    let task: PlayTask
    var statuses: [EventStatus] = []
    var current: Int? = nil
    var hitMarks: [HitMark] = []
    var clock: PlayheadClock? = nil
    var showPlayhead = false

    private var hasTwoHands: Bool {
        let hands = Set(task.events.flatMap { $0.notes.map { $0.hand } })
        return hands.contains(.left) && hands.contains(.right)
    }

    private var total: Double { max(1, task.totalBeats) }
    private var laneHeight: CGFloat { 44 }
    private var height: CGFloat { 30 + (hasTwoHands ? laneHeight * 2 + 8 : laneHeight) + 24 }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in draw(&context, width: width) }
                if showPlayhead, task.isTimed, let clock {
                    LanePlayhead(clock: clock, total: total, width: width, height: height)
                }
            }
        }
        .frame(height: height)
    }

    private func x(_ beat: Double, _ width: CGFloat) -> CGFloat {
        14 + CGFloat(beat / total) * (width - 28)
    }

    private func draw(_ context: inout GraphicsContext, width: CGFloat) {
        let config = task.timedConfig
        let bar = config?.beatsPerBar ?? 4
        let unit = Double(config?.beatUnit ?? 4)
        let top: CGFloat = 26
        let lanes: [(hand: Hand?, y: CGFloat)] = hasTwoHands
            ? [(.right, top), (.left, top + laneHeight + 8)]
            : [(nil, top)]
        let bottom = (lanes.last?.y ?? top) + laneHeight

        for lane in lanes {
            let rect = CGRect(x: 8, y: lane.y, width: width - 16, height: laneHeight)
            context.fill(Path(roundedRect: rect, cornerRadius: 8), with: .color(Color.primary.opacity(0.06)))
            if let hand = lane.hand {
                context.draw(Text(hand == .right ? "RH" : "LH").font(.system(size: 9, weight: .bold))
                    .foregroundColor(Palette.hand(hand)), at: CGPoint(x: width - 22, y: lane.y + 9))
            }
        }
        // Beat grid
        for beat in 0...Int(total.rounded(.up)) {
            let bx = x(Double(beat), width)
            let isBar = beat % bar == 0
            context.stroke(Path { $0.move(to: CGPoint(x: bx, y: top - (isBar ? 6 : 0))); $0.addLine(to: CGPoint(x: bx, y: bottom)) },
                           with: .color(Color.primary.opacity(isBar ? 0.5 : 0.18)), lineWidth: isBar ? 1.5 : 1)
            if Double(beat) < total {
                context.draw(Text("\(beat % bar + 1)").font(.system(size: 10, weight: isBar ? .bold : .regular))
                    .foregroundColor(.secondary), at: CGPoint(x: bx + 7, y: 12))
            }
        }
        // Events
        for lane in lanes {
            var cursor = 0.0
            for (i, event) in task.events.enumerated() {
                let inLane = lane.hand == nil || event.notes.contains { $0.hand == lane.hand }
                guard inLane else { continue }
                if event.beat - cursor > 0.01 {
                    for (offset, value) in NoteDraw.restValues((event.beat - cursor) * 4 / unit) {
                        NoteDraw.rest(&context, at: CGPoint(x: x(cursor + offset * unit / 4, width) + 12, y: lane.y + laneHeight / 2),
                                      quarters: value, color: .secondary, scale: 0.85)
                    }
                }
                let length = event.notes.filter { lane.hand == nil || $0.hand == lane.hand }
                    .compactMap { $0.duration }.max() ?? event.duration
                cursor = max(cursor, event.beat + length)
                let status = i < statuses.count ? statuses[i] : .pending
                let hand = lane.hand ?? event.notes.first?.hand ?? .either
                let isCurrent = current == i
                let base: Color
                switch status {
                case .correct: base = Palette.good
                case .wrong, .missed: base = Palette.bad
                case .pending: base = Palette.hand(hand)
                }
                let x0 = x(event.beat, width)
                let x1 = x(event.beat + length, width)
                let rect = CGRect(x: x0 + 1, y: lane.y + 6, width: max(5, x1 - x0 - 3), height: laneHeight - 12)
                let path = Path(roundedRect: rect, cornerRadius: 5)
                context.fill(path, with: .color(base.opacity(status == .pending ? (isCurrent ? 0.95 : 0.55) : 0.9)))
                if event.accent {
                    context.draw(Text(">").font(.system(size: 12, weight: .heavy)).foregroundColor(.white),
                                 at: CGPoint(x: rect.minX + 7, y: rect.minY + 7))
                }
                if rect.width > 15 {
                    NoteDraw.note(&context, at: CGPoint(x: rect.minX + min(rect.width / 2, 13), y: rect.midY + 8),
                                  quarters: length * 4 / unit, color: .white, stemUp: true, scale: 0.6)
                }
                if let label = event.label, lane.hand == nil || lane.hand == .left || !hasTwoHands {
                    context.draw(Text(label).font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary),
                                 at: CGPoint(x: x0 + 6, y: bottom + 11))
                }
            }
            if total - cursor > 0.01, cursor > 0 || task.events.isEmpty {
                for (offset, value) in NoteDraw.restValues((total - cursor) * 4 / unit) {
                    NoteDraw.rest(&context, at: CGPoint(x: x(cursor + offset * unit / 4, width) + 12, y: lane.y + laneHeight / 2),
                                  quarters: value, color: .secondary, scale: 0.85)
                }
            }
        }
        // Where the learner actually played
        for mark in hitMarks {
            let mx = x(mark.beat, width)
            let color: Color
            if let d = mark.deviationMs {
                color = abs(d) <= 40 ? Palette.good : abs(d) <= 90 ? Palette.demo : Palette.left
            } else {
                color = Palette.bad
            }
            let laneY = hasTwoHands && mark.hand == .left ? top + laneHeight + 8 : top
            context.fill(Path(roundedRect: CGRect(x: mx - 1.5, y: laneY - 1, width: 3, height: laneHeight + 2), cornerRadius: 1.5),
                         with: .color(color))
            context.stroke(Path(roundedRect: CGRect(x: mx - 1.5, y: laneY - 1, width: 3, height: laneHeight + 2), cornerRadius: 1.5),
                           with: .color(.white.opacity(0.8)), lineWidth: 0.6)
        }
    }
}

private struct LanePlayhead: View {
    @ObservedObject var clock: PlayheadClock
    let total: Double
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let beat = clock.beat
        if beat >= 0, beat <= total {
            Rectangle()
                .fill(Color.primary.opacity(0.75))
                .frame(width: 2, height: height - 30)
                .offset(x: 14 + CGFloat(beat / total) * (width - 28) - 1, y: 18)
        }
    }
}
