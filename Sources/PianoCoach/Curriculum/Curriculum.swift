import Foundation

/// The whole course. Each section lives in its own file as an extension.
enum Curriculum {
    static let sections: [CurriculumSection] = [foundations, rhythm, reading, technique, earTraining, songs, voice]

    static func lesson(_ id: String, _ title: String, _ summary: String, _ steps: [Step]) -> Lesson {
        Lesson(id: id, title: title, summary: summary, steps: steps)
    }

    static func unit(_ id: String, _ title: String, _ lessons: [Lesson]) -> CurriculumUnit {
        CurriculumUnit(id: id, title: title, lessons: lessons)
    }

    /// Validates every lesson: unique ids, playable ranges, sane timing. Run with `PianoCoach --check`.
    static func selfCheck(verbose: Bool) -> Bool {
        var problems: [String] = []
        var seen: Set<String> = []
        var lessons = 0, steps = 0, tasks = 0

        func check(_ task: PlayTask, _ place: String) {
            tasks += 1
            if task.events.isEmpty { problems.append("\(place): task '\(task.title)' has no events") }
            var last = -1.0
            for event in task.events {
                if event.beat < last - 1e-6 { problems.append("\(place): '\(task.title)' events out of order at beat \(event.beat)") }
                last = event.beat
                if event.duration <= 0 { problems.append("\(place): '\(task.title)' non-positive duration") }
                for spec in event.notes where spec.midi < Music.lowestKey || spec.midi > Music.highestKey {
                    problems.append("\(place): '\(task.title)' note \(spec.midi) is off the 61-key keyboard")
                }
                if Set(event.notes.map { $0.midi }).count != event.notes.count {
                    problems.append("\(place): '\(task.title)' duplicate note inside one event at beat \(event.beat)")
                }
                let left = event.notes.filter { $0.hand == .left }.map { $0.midi }
                let right = event.notes.filter { $0.hand == .right }.map { $0.midi }
                if let lo = left.min(), let hi = left.max(), hi - lo > 16 { problems.append("\(place): '\(task.title)' left-hand stretch of \(hi - lo) semitones") }
                if let lo = right.min(), let hi = right.max(), hi - lo > 16 { problems.append("\(place): '\(task.title)' right-hand stretch of \(hi - lo) semitones") }
                for spec in event.notes { if let f = spec.finger, !(1...5).contains(f) { problems.append("\(place): '\(task.title)' bad finger \(f)") } }
            }
            if let config = task.timedConfig {
                if config.bpm < 30 || config.bpm > 240 { problems.append("\(place): '\(task.title)' bpm \(config.bpm)") }
                if task.totalBeats > 200 { problems.append("\(place): '\(task.title)' is \(task.totalBeats) beats long") }
            }
        }

        for section in sections {
            if section.units.isEmpty { problems.append("section \(section.id) has no units") }
            for unit in section.units {
                if !seen.insert("unit:" + unit.id).inserted { problems.append("duplicate unit id \(unit.id)") }
                if unit.lessons.isEmpty { problems.append("unit \(unit.id) has no lessons") }
                for lesson in unit.lessons {
                    lessons += 1
                    if !seen.insert(lesson.id).inserted { problems.append("duplicate lesson id \(lesson.id)") }
                    if lesson.steps.isEmpty { problems.append("lesson \(lesson.id) has no steps") }
                    for (i, step) in lesson.steps.enumerated() {
                        steps += 1
                        let place = "\(lesson.id)[\(i)]"
                        switch step {
                        case .info(let info):
                            if info.body.isEmpty { problems.append("\(place): empty info") }
                            for key in info.keys where key.midi < Music.lowestKey || key.midi > Music.highestKey {
                                problems.append("\(place): highlighted key \(key.midi) off keyboard")
                            }
                            if let example = info.example { check(example, place) }
                        case .checklist(let list):
                            if list.items.isEmpty { problems.append("\(place): empty checklist") }
                        case .play(let task): check(task, place)
                        case .quiz(let quiz):
                            if quiz.rounds < 1 { problems.append("\(place): quiz without rounds") }
                            for round in 0..<min(quiz.rounds, 40) { check(quiz.make(round), place + " round \(round)") }
                        case .sing(let task):
                            tasks += 1
                            let notes = task.expanded
                            switch task.kind {
                            case .match, .timed:
                                if notes.compactMap({ $0.semitone }).isEmpty { problems.append("\(place): sing task '\(task.title)' has no notes") }
                                if notes.contains(where: { $0.beats <= 0 }) { problems.append("\(place): sing task '\(task.title)' has a zero-length note") }
                                if task.span.upperBound - task.span.lowerBound > 19 { problems.append("\(place): sing task '\(task.title)' spans more than an octave and a fifth") }
                                if case .timed(let bpm) = task.kind, bpm < 30 || bpm > 200 { problems.append("\(place): sing task '\(task.title)' bpm \(bpm)") }
                            case .free, .range, .track:
                                break
                            }
                        }
                    }
                    if verbose { print("  \(lesson.id): \(lesson.title) — \(lesson.steps.count) steps") }
                }
            }
        }
        print("\(sections.count) sections, \(lessons) lessons, \(steps) steps, \(tasks) playable tasks checked")
        for p in problems { print("PROBLEM: \(p)") }
        return problems.isEmpty
    }
}
