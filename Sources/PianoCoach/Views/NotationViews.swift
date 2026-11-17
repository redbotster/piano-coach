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
    /// Space above the top staff line of a row (grows when markers / ornaments need room).
    let topPad: CGFloat
    /// Space below the bottom staff line of a row.
    let bottomPad: CGFloat
    /// Distance above the top staff / below the bottom staff at which marker text is centred.
    let markerAboveOffset: CGFloat
    let markerBelowOffset: CGFloat
    /// Whether finger numbers are printed above the top (treble) staff.
    let fingersAbove: Bool

    init(task: PlayTask, width: CGFloat) {
        self.task = task
        self.width = width
        let all = task.events.flatMap { $0.notes }
        let lowest = all.map { $0.midi }.min() ?? 60
        let highest = all.map { $0.midi }.max() ?? 72
        let usesLeft = all.contains { $0.hand == .left }
        let usesRight = all.contains { $0.hand == .right }
        let treble: Bool
        let bass: Bool
        switch task.clef {
        case .treble: treble = true; bass = false
        case .bass: treble = false; bass = true
        case .grand: treble = true; bass = true
        case .auto:
            if usesLeft && usesRight { treble = true; bass = true }
            else if lowest >= 55 { treble = true; bass = false }
            else if highest <= 64 { treble = false; bass = true }
            else { treble = true; bass = true }
        }
        hasTreble = treble
        hasBass = bass
        let timeSig: CGFloat = task.isTimed ? 26 : 0
        let repeatPad: CGFloat = task.repeats.isEmpty ? 0 : 12
        left = 52 + CGFloat(abs(task.keySignature)) * 10 + timeSig + repeatPad
        let lastEnd = task.events.map { $0.beat + $0.duration }.max() ?? 1
        total = max(task.isTimed ? task.totalBeats : lastEnd, 1)

        let beats = Array(Set(task.events.filter { $0.ornament != .acciaccatura && $0.ornament != .appoggiatura }.map { $0.beat })).sorted()
        var minGap = 1.0
        for i in beats.indices.dropFirst() { minGap = min(minGap, beats[i] - beats[i - 1]) }
        minGap = max(minGap, 0.125)
        let minPx = min(130, 26 / minGap)
        let available = max(120, width - left - 30)
        let fit = Double(available) / minPx
        if total <= fit {
            rows = 1
            beatsPerRow = total
            pxPerBeat = min(available / CGFloat(total), task.timedConfig?.beatUnit == 2 ? 190 : 95)
        } else {
            let bar = Double(task.timedConfig?.beatsPerBar ?? 1)
            beatsPerRow = max(bar, (fit / bar).rounded(.down) * bar)
            rows = Int((total / beatsPerRow).rounded(.up))
            pxPerBeat = available / CGFloat(beatsPerRow)
        }

        // Vertical room for things printed outside the staff.
        func isOnTreble(_ spec: NoteSpec) -> Bool {
            if treble && !bass { return true }
            if bass && !treble { return false }
            switch spec.hand {
            case .left: return false
            case .right: return true
            case .either: return spec.midi >= 60
            }
        }
        let fingered = task.showFingers ? all.filter { $0.finger != nil } : []
        let above = treble && fingered.contains { isOnTreble($0) }
        let fingersBelow = fingered.contains { !isOnTreble($0) }
        fingersAbove = above
        func isSign(_ o: Ornament?) -> Bool { o == .trill || o == .mordent || o == .turn }
        let anySign = task.events.contains { isSign($0.ornament) || $0.fermata }
        let stacked = task.events.contains { isSign($0.ornament) && $0.fermata }
        let markersAbove = task.markers.contains { !$0.below }
        let markersBelow = task.markers.contains { $0.below }
        let signBand: CGFloat = (above ? 42 : 24) + (stacked ? 14 : 0)
        let aboveOffset: CGFloat = 26 + (above ? 16 : 0) + (anySign ? 16 + (stacked ? 14 : 0) : 0)
        markerAboveOffset = aboveOffset
        topPad = max(38, markersAbove ? aboveOffset + 14 : 0, anySign ? signBand + 14 : 0)
        let labels = task.display == .staff && task.events.contains { $0.label != nil }
        let belowOffset: CGFloat = 24 + (fingersBelow ? 16 : 0) + (labels ? 16 : 0)
        markerBelowOffset = belowOffset
        let basePad: CGFloat = (treble && bass) ? 16 : 40
        bottomPad = max(basePad, (fingersBelow || labels) ? 40 : 0, markersBelow ? belowOffset + 14 : 0)
    }

    var rowHeight: CGFloat { topPad + (hasTreble && hasBass ? 142 : 40) + bottomPad }
    var height: CGFloat { CGFloat(rows) * rowHeight }

    func row(of beat: Double) -> Int { min(rows - 1, max(0, Int((beat + 1e-6) / beatsPerRow))) }

    func x(_ beat: Double, row: Int) -> CGFloat {
        left + 16 + CGFloat(beat - Double(row) * beatsPerRow) * pxPerBeat
    }

    /// Y of the top line of each staff inside a row.
    var trebleTop: CGFloat { topPad }
    var bassTop: CGFloat { hasTreble ? topPad + 4 * spacing + 62 : topPad }

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

    /// Distance from a beat to the bar line drawn just before it.
    var barLineOffset: CGFloat { min(22, max(12, pxPerBeat * 0.3)) }
}

/// The notes of one event that sit on one staff: a single note or a chord sharing a stem.
private struct NoteStack {
    var event: Int
    var treble: Bool
    var row: Int
    var x: CGFloat
    var beat: Double
    var beats: Double
    var quarters: Double
    var ys: [CGFloat] = []
    var steps: [Int] = []
    var colors: [Color] = []
    var accidentals: [String?] = []
    var fingers: [Int?] = []
    var noteQuarters: [Double] = []
    var stemUp = true
    var tipY: CGFloat = 0
    var beamed = false
    var grace = false

    var topY: CGFloat { ys.min() ?? 0 }
    var bottomY: CGFloat { ys.max() ?? 0 }
    var color: Color { colors.first ?? .primary }
    var stemX: CGFloat { stemUp ? x + 5.6 : x - 5.6 }
    /// Highest / lowest point of the stack including its stem.
    var upperExtent: CGFloat { min(topY - 5, stemUp ? tipY : topY - 5) }
    var lowerExtent: CGFloat { max(bottomY + 5, stemUp ? bottomY + 5 : tipY) }
}

private struct BeamGroup {
    var members: [Int]
    var stemUp: Bool
    var x0: CGFloat
    var y0: CGFloat
    var slope: CGFloat
    func y(at x: CGFloat) -> CGFloat { y0 + (x - x0) * slope }
}

private struct StaffModel {
    var stacks: [NoteStack] = []
    var groups: [BeamGroup] = []
    /// Pairs of stack indices joined by a slur.
    var slurs: [(Int, Int)] = []
}

struct StaffView: View {
    let task: PlayTask
    var statuses: [EventStatus] = []
    var current: Int? = nil
    var clock: PlayheadClock? = nil
    var showPlayhead = false

    /// Last measured width, so the view can reserve exactly the height its rows need.
    @State private var measuredWidth: CGFloat = 900

    var body: some View {
        GeometryReader { geo in
            let layout = StaffLayout(task: task, width: geo.size.width)
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    let model = buildModel(layout)
                    for row in 0..<layout.rows {
                        context.translateBy(x: 0, y: CGFloat(row) * layout.rowHeight)
                        drawRow(&context, layout: layout, row: row, model: model)
                        context.translateBy(x: 0, y: -CGFloat(row) * layout.rowHeight)
                    }
                }
                if showPlayhead, task.isTimed, let clock {
                    StaffPlayhead(clock: clock, layout: layout)
                }
            }
            .onAppear { if abs(measuredWidth - geo.size.width) > 0.5 { measuredWidth = geo.size.width } }
            .onChange(of: geo.size.width) { _, new in measuredWidth = new }
        }
        .frame(height: StaffLayout(task: task, width: measuredWidth).height)
    }

    // MARK: Model

    private var beatUnit: Double { Double(task.timedConfig?.beatUnit ?? 4) }

    private func isGrace(_ event: ExpectedEvent) -> Bool {
        event.ornament == .acciaccatura || event.ornament == .appoggiatura
    }

    /// Bar and beat-group a beat falls in; notes are only beamed inside one group.
    private func beamKey(_ beat: Double) -> (Int, Int) {
        guard let config = task.timedConfig else { return (0, Int(floor(beat + 1e-6))) }
        let bar = Double(config.beatsPerBar)
        let barIndex = Int(floor((beat + 1e-6) / bar))
        let position = beat - Double(barIndex) * bar
        if config.beatUnit == 8 {
            let accents = config.accentBeats.sorted()
            if accents.count > 1 { return (barIndex, accents.filter { Double($0) <= position + 1e-6 }.count) }
            return (barIndex, Int((position + 1e-6) / (config.beatsPerBar % 3 == 0 ? 3 : 2)))
        }
        return (barIndex, Int(floor(position + 1e-6)))
    }

    private func buildModel(_ l: StaffLayout) -> StaffModel {
        var model = StaffModel()
        let unit = beatUnit
        var stackOfEvent: [Int: [Int]] = [:]

        for (i, event) in task.events.enumerated() where !event.notes.isEmpty {
            let status = i < statuses.count ? statuses[i] : .pending
            let row = l.row(of: event.beat)
            for treble in [true, false] {
                let specs = event.notes.filter { l.onTreble($0) == treble }
                guard let first = specs.first else { continue }
                let beats = first.duration ?? event.duration
                var stack = NoteStack(event: i, treble: treble, row: row, x: l.x(event.beat, row: row), beat: event.beat,
                                      beats: beats, quarters: beats * 4 / unit)
                stack.grace = isGrace(event)
                for spec in specs {
                    let spelled = Spelling.spell(spec.midi, fifths: task.keySignature, preferFlats: task.preferFlats)
                    stack.steps.append(spelled.step)
                    stack.ys.append(l.y(step: spelled.step, treble: treble))
                    stack.colors.append(statusColor(status, isCurrent: current == i, hand: spec.hand))
                    stack.accidentals.append(spelled.accidental)
                    stack.fingers.append(spec.finger)
                    stack.noteQuarters.append((spec.duration ?? event.duration) * 4 / unit)
                }
                let middle = Double(treble ? 34 : 22)
                let average = Double(stack.steps.reduce(0, +)) / Double(stack.steps.count)
                stack.stemUp = stack.grace || average < middle
                let midLine = (treble ? l.trebleTop : l.bassTop) + 2 * l.spacing
                stack.tipY = stack.stemUp ? min(stack.topY - 33, midLine) : max(stack.bottomY + 33, midLine)
                if stack.grace { stack.tipY = stack.topY - 21 }
                if stack.quarters >= 3.99 { stack.tipY = stack.stemUp ? stack.topY - 5 : stack.bottomY + 5 }
                stackOfEvent[i, default: []].append(model.stacks.count)
                model.stacks.append(stack)
            }
        }

        for treble in [true, false] {
            let line = model.stacks.indices.filter { model.stacks[$0].treble == treble }
                .sorted { model.stacks[$0].beat < model.stacks[$1].beat }
            // Grace notes hug the note they decorate.
            for (n, index) in line.enumerated() where model.stacks[index].grace && n + 1 < line.count {
                let next = model.stacks[line[n + 1]]
                if next.row == model.stacks[index].row, next.x - model.stacks[index].x > 15 {
                    model.stacks[index].x = next.x - 15
                }
            }
            // Beam groups
            var run: [Int] = []
            func flush() {
                if run.count > 1 { model.groups.append(makeGroup(run, &model.stacks, l)) }
                run = []
            }
            for index in line {
                let stack = model.stacks[index]
                guard !stack.grace, NoteDraw.beamCount(stack.quarters) > 0 else { flush(); continue }
                if let last = run.last {
                    let previous = model.stacks[last]
                    let contiguous = abs(stack.beat - (previous.beat + previous.beats)) < 0.02
                    if !(contiguous && previous.row == stack.row && beamKey(previous.beat) == beamKey(stack.beat)) { flush() }
                }
                run.append(index)
            }
            flush()
        }

        // Slurs are drawn on the staff holding the first note of the starting event.
        var open: Int?
        for (i, event) in task.events.enumerated() {
            if event.slurEnd, let start = open {
                if let a = stackOfEvent[start]?.first {
                    let treble = model.stacks[a].treble
                    let b = stackOfEvent[i]?.first { model.stacks[$0].treble == treble } ?? stackOfEvent[i]?.first
                    if let b, model.stacks[b].treble == treble { model.slurs.append((a, b)) }
                }
                open = nil
            }
            if event.slurStart, stackOfEvent[i] != nil { open = i }
        }
        return model
    }

    private func makeGroup(_ members: [Int], _ stacks: inout [NoteStack], _ l: StaffLayout) -> BeamGroup {
        let treble = stacks[members[0]].treble
        let steps = members.flatMap { stacks[$0].steps }
        let average = Double(steps.reduce(0, +)) / Double(max(1, steps.count))
        let up = average < Double(treble ? 34 : 22)
        for m in members { stacks[m].stemUp = up; stacks[m].beamed = true }
        let first = stacks[members[0]]
        let last = stacks[members[members.count - 1]]
        func ideal(_ s: NoteStack) -> CGFloat { up ? s.topY - 31 : s.bottomY + 31 }
        let x0 = first.stemX
        let span = max(1, last.stemX - x0)
        var rise = ideal(last) - ideal(first)
        rise = max(-12, min(12, rise))
        // An inner note that sticks out past both ends flattens the beam.
        let inner = members.dropFirst().dropLast().map { ideal(stacks[$0]) }
        if let extreme = up ? inner.min() : inner.max(),
           up ? extreme < min(ideal(first), ideal(last)) : extreme > max(ideal(first), ideal(last)) { rise = 0 }
        let slope = rise / span
        var y0 = ideal(first)
        // Every stem must keep a minimum length.
        for m in members {
            let s = stacks[m]
            let beamY = y0 + (s.stemX - x0) * slope
            if up { let limit = s.topY - 27; if beamY > limit { y0 -= beamY - limit } }
            else { let limit = s.bottomY + 27; if beamY < limit { y0 += limit - beamY } }
        }
        let midLine = (treble ? l.trebleTop : l.bassTop) + 2 * l.spacing
        let centre = y0 + span * slope / 2
        if up, centre > midLine + 2 { y0 -= centre - midLine - 2 }
        if !up, centre < midLine - 2 { y0 += midLine - 2 - centre }
        let group = BeamGroup(members: members, stemUp: up, x0: x0, y0: y0, slope: slope)
        for m in members { stacks[m].tipY = group.y(at: stacks[m].stemX) }
        return group
    }

    // MARK: Drawing

    private func drawRow(_ context: inout GraphicsContext, layout l: StaffLayout, row: Int, model: StaffModel) {
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
                let x = 52 + CGFloat(abs(task.keySignature)) * 10 + 14
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
                           with: .color(ink.opacity(width > 1 ? 0.9 : 0.7)), lineWidth: width)
        }
        let rowStart = Double(row) * l.beatsPerRow
        let rowEnd = min(l.total, rowStart + l.beatsPerRow)
        barLine(x0)
        barLine(x1)
        if let config = task.timedConfig {
            let bar = Double(config.beatsPerBar)
            var b = rowStart + bar
            while b < rowEnd - 1e-6 {
                barLine(l.x(b, row: row) - l.barLineOffset)
                b += bar
            }
        }

        // Repeat signs
        func repeatDots(_ x: CGFloat) {
            for staff in tops {
                for offset in [1.5, 2.5] {
                    let dot = CGRect(x: x - 2, y: staff.top + CGFloat(offset) * s - 2, width: 4, height: 4)
                    context.fill(Path(ellipseIn: dot), with: .color(ink.opacity(0.9)))
                }
            }
        }
        for span in task.repeats {
            if span.start >= rowStart - 1e-6, span.start < rowEnd - 1e-6 {
                let atEdge = abs(span.start - rowStart) < 1e-6
                let x = atEdge ? l.left - 2 : l.x(span.start, row: row) - l.barLineOffset - 5
                barLine(x, width: 3.2)
                barLine(x + 5)
                repeatDots(atEdge ? x + 10 : x + 9.5)
            }
            if span.end > rowStart + 1e-6, span.end <= rowEnd + 1e-6 {
                let atEdge = abs(span.end - rowEnd) < 1e-6
                let x = atEdge ? x1 - 1.6 : l.x(span.end, row: row) - l.barLineOffset + 4.5
                barLine(x, width: 3.2)
                barLine(x - (atEdge ? 5 : 4.5))
                repeatDots(x - 10)
            }
        }

        // Rests (timed tasks only): silence on each staff, split at bar lines.
        if let config = task.timedConfig {
            let unitQ = 4 / Double(config.beatUnit)
            let bar = Double(config.beatsPerBar)
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
        for stack in model.stacks where stack.row == row {
            let event = task.events[stack.event]
            let x = stack.x
            let staffTop = stack.treble ? l.trebleTop : l.bassTop
            for n in stack.ys.indices {
                let y = stack.ys[n]
                let color = stack.colors[n]
                drawLedgers(&context, layout: l, step: stack.steps[n], treble: stack.treble, x: x, small: stack.grace)
                NoteDraw.head(&context, at: CGPoint(x: x, y: y), quarters: stack.grace ? 0.5 : stack.noteQuarters[n],
                              color: color, scale: stack.grace ? 0.62 : 1)
                if let accidental = stack.accidentals[n] {
                    context.draw(Text(accidental).font(.system(size: stack.grace ? 12 : 17)).foregroundColor(color),
                                 at: CGPoint(x: x - (stack.grace ? 10 : 15), y: y - (accidental == "♭" ? 3 : 0)))
                }
                if task.showFingers, let finger = stack.fingers[n], !stack.grace {
                    // Finger numbers sit in a fixed band, moving out of the way of very high or low notes.
                    let fy = stack.treble ? min(l.trebleTop - 26, stack.upperExtent - 10)
                                          : max(l.bassTop + 4 * s + 26, stack.lowerExtent + 10)
                    context.draw(Text("\(finger)").font(.system(size: 11, weight: .semibold)).foregroundColor(color.opacity(0.9)),
                                 at: CGPoint(x: x, y: fy))
                }
            }
            let color = stack.color
            if stack.grace {
                drawGraceStem(&context, stack, slashed: event.ornament == .acciaccatura)
                continue
            }
            if !stack.beamed { drawStem(&context, stack) }

            // Articulation sits on the notehead side, away from the stem.
            let headY = stack.stemUp ? stack.bottomY : stack.topY
            let away: CGFloat = stack.stemUp ? 1 : -1
            if event.articulation == .staccato {
                context.fill(Path(ellipseIn: CGRect(x: x - 2, y: headY + away * 11 - 2, width: 4, height: 4)), with: .color(color))
            }
            if event.articulation == .tenuto {
                context.stroke(Path { $0.move(to: CGPoint(x: x - 6, y: headY + away * 11)); $0.addLine(to: CGPoint(x: x + 6, y: headY + away * 11)) },
                               with: .color(color), lineWidth: 1.6)
            }
            if event.accent {
                let ay = headY + away * (event.articulation == nil ? 14 : 20)
                context.stroke(Path {
                    $0.move(to: CGPoint(x: x - 6, y: ay - 4))
                    $0.addLine(to: CGPoint(x: x + 6, y: ay))
                    $0.addLine(to: CGPoint(x: x - 6, y: ay + 4))
                }, with: .color(color), style: StrokeStyle(lineWidth: 1.5, lineJoin: .miter))
            }

            // Ornament signs and fermata go above the note.
            let isTopStaff = stack.treble || !l.hasTreble
            let band = staffTop - (isTopStaff ? (l.fingersAbove ? 42 : 24) : 16)
            var signY = min(band, stack.upperExtent - 12)
            if task.showFingers, stack.treble, stack.fingers.contains(where: { $0 != nil }) {
                signY = min(signY, min(l.trebleTop - 26, stack.upperExtent - 10) - 15)
            }
            if let ornament = event.ornament {
                drawOrnament(&context, ornament, at: CGPoint(x: x, y: signY), color: color)
                signY -= 14
            }
            if event.fermata { drawFermata(&context, at: CGPoint(x: x, y: signY), color: color) }
        }

        // Beams
        for group in model.groups where model.stacks[group.members[0]].row == row {
            drawBeams(&context, group, model.stacks)
        }

        // Slurs
        for (a, b) in model.slurs {
            let first = model.stacks[a]
            let last = model.stacks[b]
            guard row >= first.row, row <= last.row else { continue }
            let above = !first.stemUp
            func anchor(_ stack: NoteStack) -> CGPoint {
                CGPoint(x: stack.x, y: above ? stack.topY - 10 : stack.bottomY + 10)
            }
            var p0 = anchor(first)
            var p1 = anchor(last)
            if first.row != row { p0 = CGPoint(x: l.left + 2, y: first.row == last.row ? p0.y : anchor(last).y) }
            if last.row != row { p1 = CGPoint(x: x1 - 6, y: p0.y) }
            if first.row != row, last.row != row {
                let mid = (tops.first { $0.treble == first.treble }?.top ?? top) + (above ? -12 : 4 * s + 12)
                p0.y = mid
                p1.y = mid
            }
            // Clear everything in between.
            var extreme: CGFloat?
            for stack in model.stacks where stack.row == row && stack.treble == first.treble
                && stack.x > p0.x + 1 && stack.x < p1.x - 1 {
                var edge = above ? stack.upperExtent : stack.lowerExtent
                let marked = task.events[stack.event].articulation != nil || task.events[stack.event].accent
                if marked, stack.stemUp != above { edge += above ? -14 : 14 }
                extreme = extreme.map { above ? min($0, edge) : max($0, edge) } ?? edge
            }
            drawSlur(&context, from: p0, to: p1, above: above, clear: extreme, color: ink.opacity(0.85))
        }

        // Markers and hairpins
        for (m, marker) in task.markers.enumerated() where l.row(of: marker.beat) == row {
            let y = marker.below ? bottom + l.markerBelowOffset : top - l.markerAboveOffset
            let x = l.x(marker.beat, row: row)
            if marker.text == "cresc<" || marker.text == "dim>" {
                let next = task.markers.enumerated()
                    .filter { $0.offset != m && $0.element.below == marker.below && $0.element.beat > marker.beat + 1e-6 }
                    .map { $0.element.beat }.min()
                let endBeat = next ?? (marker.beat + 2)
                let endX = endBeat >= rowEnd - 1e-6 && (next == nil || l.row(of: endBeat) != row)
                    ? min(x1 - 8, l.x(min(endBeat, rowEnd), row: row) - 6)
                    : l.x(endBeat, row: row) - (next == nil ? 6 : 14)
                let startX = x - 5
                guard endX - startX > 8 else { continue }
                let open: CGFloat = 6
                let opening = marker.text == "cresc<"
                context.stroke(Path {
                    if opening {
                        $0.move(to: CGPoint(x: endX, y: y - open)); $0.addLine(to: CGPoint(x: startX, y: y)); $0.addLine(to: CGPoint(x: endX, y: y + open))
                    } else {
                        $0.move(to: CGPoint(x: startX, y: y - open)); $0.addLine(to: CGPoint(x: endX, y: y)); $0.addLine(to: CGPoint(x: startX, y: y + open))
                    }
                }, with: .color(ink.opacity(0.85)), style: StrokeStyle(lineWidth: 1.2, lineJoin: .miter))
                continue
            }
            let dynamics: Set<String> = ["ppp", "pp", "p", "mp", "mf", "f", "ff", "fff", "sfz", "sf", "fz", "fp", "sfp", "rfz",
                                         "cresc.", "dim.", "decresc."]
            let isDynamic = dynamics.contains(marker.text)
            let short = marker.text.count <= 3
            let font: Font = isDynamic
                ? .system(size: short ? 17 : 14, weight: short ? .bold : .semibold, design: .serif).italic()
                : .system(size: 13, weight: .medium, design: .serif).italic()
            let text = Text(marker.text).font(font).foregroundColor(ink)
            if short {
                context.draw(text, at: CGPoint(x: x, y: y))
            } else {
                context.draw(text, at: CGPoint(x: x - 7, y: y), anchor: .leading)
            }
        }

        // Labels
        for (i, event) in task.events.enumerated() where l.row(of: event.beat) == row {
            _ = i
            if let label = event.label, task.display == .staff {
                context.draw(Text(label).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary),
                             at: CGPoint(x: l.x(event.beat, row: row), y: bottom + (l.hasBass && task.showFingers && l.bottomPad >= 40 && l.markerBelowOffset >= 56 ? 42 : 30)))
            }
        }
    }

    private func drawLedgers(_ context: inout GraphicsContext, layout l: StaffLayout, step: Int, treble: Bool, x: CGFloat,
                             small: Bool = false) {
        let topStep = treble ? 38 : 26
        let bottomStep = topStep - 8
        var steps: [Int] = []
        if step >= topStep + 2 { steps = Array(stride(from: topStep + 2, through: step, by: 2)) }
        if step <= bottomStep - 2 { steps = Array(stride(from: bottomStep - 2, through: step, by: -2)) }
        let half: CGFloat = small ? 7 : 10
        for ledger in steps {
            let y = l.y(step: ledger, treble: treble)
            context.stroke(Path { $0.move(to: CGPoint(x: x - half, y: y)); $0.addLine(to: CGPoint(x: x + half, y: y)) },
                           with: .color(Color.primary.opacity(0.7)), lineWidth: 1.2)
        }
    }

    /// Stem (and flags) of a note or chord that is not part of a beam.
    private func drawStem(_ context: inout GraphicsContext, _ stack: NoteStack) {
        let q = stack.quarters
        let color = stack.color
        if q < 3.99 {
            let sx = stack.stemX
            let from = stack.stemUp ? stack.bottomY : stack.topY
            let tip = stack.tipY
            context.stroke(Path { $0.move(to: CGPoint(x: sx, y: from)); $0.addLine(to: CGPoint(x: sx, y: tip)) },
                           with: .color(color), lineWidth: 1.3)
            for f in 0..<NoteDraw.beamCount(q) {
                let fy = tip + CGFloat(f) * (stack.stemUp ? 6 : -6)
                context.stroke(Path {
                    $0.move(to: CGPoint(x: sx, y: fy))
                    $0.addQuadCurve(to: CGPoint(x: sx + 8, y: fy + (stack.stemUp ? 12 : -12)),
                                    control: CGPoint(x: sx + 9, y: fy + (stack.stemUp ? 4 : -4)))
                }, with: .color(color), lineWidth: 1.6)
            }
        }
        if NoteDraw.isTuplet(q) {
            let y = stack.stemUp ? stack.bottomY + 16 : stack.topY - 16
            context.draw(Text(NoteDraw.tupletNumber(q)).font(.system(size: 10, weight: .semibold).italic()).foregroundColor(color),
                         at: CGPoint(x: stack.x, y: y))
        }
    }

    private func drawGraceStem(_ context: inout GraphicsContext, _ stack: NoteStack, slashed: Bool) {
        let color = stack.color
        let sx = stack.x + 3.5
        let tip = stack.tipY
        context.stroke(Path { $0.move(to: CGPoint(x: sx, y: stack.bottomY)); $0.addLine(to: CGPoint(x: sx, y: tip)) },
                       with: .color(color), lineWidth: 1)
        context.stroke(Path {
            $0.move(to: CGPoint(x: sx, y: tip))
            $0.addQuadCurve(to: CGPoint(x: sx + 5.5, y: tip + 9), control: CGPoint(x: sx + 6.5, y: tip + 3))
        }, with: .color(color), lineWidth: 1.2)
        if slashed {
            context.stroke(Path { $0.move(to: CGPoint(x: sx - 5, y: tip + 13)); $0.addLine(to: CGPoint(x: sx + 7, y: tip + 4)) },
                           with: .color(color), lineWidth: 1)
        }
    }

    private func drawBeams(_ context: inout GraphicsContext, _ group: BeamGroup, _ stacks: [NoteStack]) {
        let members = group.members.map { stacks[$0] }
        guard let first = members.first, let last = members.last else { return }
        let up = group.stemUp
        let thickness: CGFloat = 4.6
        let gap: CGFloat = 7.2
        let inward: CGFloat = up ? 1 : -1      // direction from the beam towards the noteheads
        let ink = first.colors.allSatisfy({ $0 == first.color }) && members.allSatisfy({ $0.color == first.color })
            ? first.color : Color.primary

        for stack in members {
            let from = up ? stack.bottomY : stack.topY
            context.stroke(Path { $0.move(to: CGPoint(x: stack.stemX, y: from)); $0.addLine(to: CGPoint(x: stack.stemX, y: group.y(at: stack.stemX))) },
                           with: .color(stack.color), lineWidth: 1.3)
        }
        func segment(_ xa: CGFloat, _ xb: CGFloat, level: Int, color: Color) {
            let offset = CGFloat(level) * gap * inward
            let ya = group.y(at: xa) + offset
            let yb = group.y(at: xb) + offset
            var path = Path()
            path.move(to: CGPoint(x: xa, y: ya))
            path.addLine(to: CGPoint(x: xb, y: yb))
            path.addLine(to: CGPoint(x: xb, y: yb + thickness * inward))
            path.addLine(to: CGPoint(x: xa, y: ya + thickness * inward))
            path.closeSubpath()
            context.fill(path, with: .color(color))
        }
        segment(first.stemX - 0.65, last.stemX + 0.65, level: 0, color: ink)
        let counts = members.map { NoteDraw.beamCount($0.quarters) }
        for level in 1..<3 {
            for i in members.indices where counts[i] > level {
                if i + 1 < members.count, counts[i + 1] > level {
                    segment(members[i].stemX - 0.65, members[i + 1].stemX + 0.65, level: level, color: ink)
                } else if !(i > 0 && counts[i - 1] > level) {
                    let stub: CGFloat = i == 0 ? 9 : -9
                    let xa = members[i].stemX
                    segment(min(xa, xa + stub), max(xa, xa + stub), level: level, color: ink)
                }
            }
        }
        if members.allSatisfy({ NoteDraw.isTuplet($0.quarters) }) {
            let mx = (first.stemX + last.stemX) / 2
            context.draw(Text(NoteDraw.tupletNumber(first.quarters)).font(.system(size: 11, weight: .semibold).italic()).foregroundColor(ink),
                         at: CGPoint(x: mx, y: group.y(at: mx) - inward * 9))
        }
    }

    private func drawSlur(_ context: inout GraphicsContext, from p0: CGPoint, to p1: CGPoint, above: Bool,
                          clear: CGFloat?, color: Color) {
        let length = p1.x - p0.x
        guard length > 4 else { return }
        let sign: CGFloat = above ? -1 : 1
        var bow = min(20, max(7, length * 0.13))
        if let clear {
            // The curve's apex sits about 0.75 × bow beyond the line between its ends.
            let base = above ? min(p0.y, p1.y) : max(p0.y, p1.y)
            let needed = (above ? base - clear : clear - base) + 5
            if needed > 0 { bow = min(46, max(bow, needed / 0.75)) }
        }
        func curve(_ depth: CGFloat) -> (CGPoint, CGPoint) {
            (CGPoint(x: p0.x + length * 0.22, y: p0.y + sign * depth), CGPoint(x: p1.x - length * 0.22, y: p1.y + sign * depth))
        }
        let outer = curve(bow)
        let inner = curve(bow - 2.6)
        var path = Path()
        path.move(to: p0)
        path.addCurve(to: p1, control1: outer.0, control2: outer.1)
        path.addCurve(to: p0, control1: inner.1, control2: inner.0)
        path.closeSubpath()
        context.fill(path, with: .color(color))
        context.stroke(path, with: .color(color), lineWidth: 0.5)
    }

    private func drawOrnament(_ context: inout GraphicsContext, _ ornament: Ornament, at p: CGPoint, color: Color) {
        switch ornament {
        case .trill:
            context.draw(Text("tr").font(.system(size: 16, weight: .bold, design: .serif).italic()).foregroundColor(color), at: p)
        case .mordent:
            var path = Path()
            path.move(to: CGPoint(x: p.x - 9, y: p.y + 3))
            for (i, dx) in [-4.5, 0, 4.5, 9].enumerated() {
                path.addLine(to: CGPoint(x: p.x + CGFloat(dx), y: p.y + (i % 2 == 0 ? -3 : 3)))
            }
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            context.stroke(Path { $0.move(to: CGPoint(x: p.x, y: p.y - 7)); $0.addLine(to: CGPoint(x: p.x, y: p.y + 7)) },
                           with: .color(color), lineWidth: 1.2)
        case .turn:
            var path = Path()
            path.move(to: CGPoint(x: p.x - 8, y: p.y + 2))
            path.addCurve(to: CGPoint(x: p.x, y: p.y), control1: CGPoint(x: p.x - 9, y: p.y - 8), control2: CGPoint(x: p.x - 2, y: p.y - 6))
            path.addCurve(to: CGPoint(x: p.x + 8, y: p.y - 2), control1: CGPoint(x: p.x + 2, y: p.y + 6), control2: CGPoint(x: p.x + 9, y: p.y + 8))
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            context.fill(Path(ellipseIn: CGRect(x: p.x - 9.6, y: p.y + 0.4, width: 3.6, height: 3.6)), with: .color(color))
            context.fill(Path(ellipseIn: CGRect(x: p.x + 6, y: p.y - 4, width: 3.6, height: 3.6)), with: .color(color))
        case .acciaccatura, .appoggiatura:
            break   // drawn as small notes
        }
    }

    private func drawFermata(_ context: inout GraphicsContext, at p: CGPoint, color: Color) {
        var arc = Path()
        arc.addArc(center: CGPoint(x: p.x, y: p.y + 4), radius: 9, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        context.stroke(arc, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        context.fill(Path(ellipseIn: CGRect(x: p.x - 2, y: p.y + 1, width: 4, height: 4)), with: .color(color))
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

    /// Number of beams (or flags) a note of this length carries.
    static func beamCount(_ q: Double) -> Int {
        if isTuplet(q) {
            if abs(q - 1.0 / 3) < 0.01 || abs(q - 0.4) < 0.01 { return 1 }
            if abs(q - 1.0 / 6) < 0.01 || abs(q - 0.2) < 0.01 { return 2 }
            return 0
        }
        let base = q / (isDotted(q) ? 1.5 : 1)
        return base <= 0.13 ? 3 : base <= 0.26 ? 2 : base <= 0.51 ? 1 : 0
    }

    /// Just the notehead (and augmentation dot), for notes whose stems and beams are drawn separately.
    static func head(_ context: inout GraphicsContext, at p: CGPoint, quarters: Double, color: Color, scale k: CGFloat = 1) {
        let head = CGRect(x: p.x - 6.2 * k, y: p.y - 4.4 * k, width: 12.4 * k, height: 8.8 * k)
        var headContext = context
        headContext.translateBy(x: p.x, y: p.y)
        headContext.rotate(by: .degrees(-18))
        headContext.translateBy(x: -p.x, y: -p.y)
        if quarters >= 1.99 {
            headContext.stroke(Path(ellipseIn: head.insetBy(dx: 0.9 * k, dy: 0.9 * k)), with: .color(color), lineWidth: 1.9 * k)
        } else {
            headContext.fill(Path(ellipseIn: head), with: .color(color))
        }
        if isDotted(quarters) {
            context.fill(Path(ellipseIn: CGRect(x: p.x + 10 * k, y: p.y - 4 * k, width: 3.6 * k, height: 3.6 * k)), with: .color(color))
        }
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
