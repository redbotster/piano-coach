import Foundation

// MARK: - Curriculum structure

struct CurriculumSection: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let units: [CurriculumUnit]
}

struct CurriculumUnit: Identifiable {
    let id: String
    let title: String
    let lessons: [Lesson]
}

struct Lesson: Identifiable {
    let id: String
    let title: String
    let summary: String
    let steps: [Step]
}

enum Step {
    case info(InfoStep)
    case checklist(ChecklistStep)
    case play(PlayTask)
    case quiz(QuizStep)

    var title: String {
        switch self {
        case .info(let s): return s.title
        case .checklist(let s): return s.title
        case .play(let s): return s.title
        case .quiz(let s): return s.title
        }
    }

    var isScored: Bool {
        switch self {
        case .play, .quiz: return true
        default: return false
        }
    }
}

struct WebLink: Identifiable {
    var id: String { url }
    let title: String
    let url: String

    /// A YouTube search link, used for things MIDI can't detect (posture, hand shape).
    static func video(_ query: String) -> WebLink {
        let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return WebLink(title: "Watch: \(query)", url: "https://www.youtube.com/results?search_query=\(q)")
    }
}

/// Explanation shown to the learner, optionally with keys lit up and a playable example.
struct InfoStep {
    var title: String
    var body: String
    /// Large notation symbol(s) shown beside the text.
    var glyph: String? = nil
    /// Keys to light up while reading, with optional labels.
    var keys: [KeyHighlight] = []
    /// An example that is drawn (staff / rhythm) and can be played back by the app.
    var example: PlayTask? = nil
    var links: [WebLink] = []
}

struct KeyHighlight {
    var midi: Int
    var label: String? = nil
    var hand: Hand = .either
}

/// Things MIDI cannot verify: the learner confirms each item.
struct ChecklistStep {
    var title: String
    var body: String
    var items: [String]
    var links: [WebLink] = []
}

/// A generated series of short tasks (note finding, sight-reading flashcards...).
struct QuizStep {
    var title: String
    var instructions: String
    var rounds: Int
    var make: (Int) -> PlayTask
}

// MARK: - Play tasks

struct NoteSpec: Hashable {
    var midi: Int
    var hand: Hand = .right
    var finger: Int? = nil
    /// Set when hands are combined and this note's length differs from the event's.
    var duration: Double? = nil
}

enum Articulation {
    case staccato, tenuto, accent
}

/// Ornament sign drawn above a note (the events themselves hold the notes actually played).
enum Ornament {
    case trill, mordent, turn, acciaccatura, appoggiatura
}

/// Text placed above (or below) the staff at a beat: "p", "cresc.", "Fine", "D.C. al Fine", "8va", "1.", "Ped."
struct StaffMarker {
    var beat: Double
    var text: String
    var below: Bool = false
}

/// A repeated passage: repeat signs are drawn at `start` and `end` (in beats).
struct RepeatSpan {
    var start: Double
    var end: Double
}

/// Something the learner must play: one note, a chord, or (when `notes` is empty) any key.
struct ExpectedEvent {
    var notes: [NoteSpec]
    /// Position in beats from the start of the task (used by timed tasks and for drawing).
    var beat: Double
    /// Length in beats.
    var duration: Double = 1
    var label: String? = nil
    var accent: Bool = false
    var articulation: Articulation? = nil
    /// A slur begins / ends on this event (drawn on the staff).
    var slurStart: Bool = false
    var slurEnd: Bool = false
    var ornament: Ornament? = nil
    var fermata: Bool = false

    var isAnyKey: Bool { notes.isEmpty }
}

enum MetronomeMode {
    case on
    /// Clicks during the count-in, then silence: the learner must hold the tempo alone.
    case countInOnly
    case off
}

struct TimedConfig {
    var bpm: Double = 80
    var beatsPerBar: Int = 4
    var beatUnit: Int = 4
    var countInBeats: Int = 4
    var metronome: MetronomeMode = .on
    /// If set, tempo changes linearly from `bpm` to this value across the task.
    var tempoEnd: Double? = nil
    /// Beats that get an accented click, e.g. [0, 3] for 6/8 felt in two. Defaults to the downbeat.
    var accentBeats: [Int] = [0]
    /// Length of the whole task in beats; defaults to the end of the last event rounded up to a bar.
    var totalBeats: Double? = nil
}

enum Timing {
    case untimed
    case timed(TimedConfig)
}

enum DisplayMode {
    case keyboard        // only the keyboard lights up
    case staff           // notation
    case rhythm          // rhythm lane
    case staffAndRhythm
}

enum ClefMode {
    case auto, treble, bass, grand
}

enum Rule {
    /// Velocity standard deviation across all notes must stay under the limit.
    case evenVelocity(maxStdDev: Double)
    /// Most notes must land inside a velocity window (a dynamic level).
    case velocityRange(min: Int, max: Int, name: String)
    case crescendo
    case diminuendo
    /// In chords, the top note must be louder than the others.
    case voicingTop(minDiff: Int)
    /// One hand (the melody) must be louder than the other.
    case handBalance(melody: Hand, minDiff: Int)
    /// Accented events must be louder than the rest.
    case accents(minDiff: Int)
    /// Each note connects to the next with no gap.
    case legato
    /// Notes are released quickly.
    case staccato
    /// Sustain pedal is changed (lifted and re-pressed) right after each new event.
    case pedalChange
}

struct PlayTask {
    var title: String
    var instructions: String
    var events: [ExpectedEvent]
    var timing: Timing = .untimed
    var display: DisplayMode = .keyboard
    var clef: ClefMode = .auto
    /// Sharps (positive) or flats (negative) in the key signature.
    var keySignature: Int = 0
    var preferFlats: Bool = false
    /// Light up the target keys. Turned off for reading and ear drills.
    var showTargets: Bool = true
    var showFingers: Bool = true
    /// Accept the right note name in any octave.
    var anyOctave: Bool = false
    var rules: [Rule] = []
    var passAccuracy: Double = 0.8
    var timingToleranceMs: Double = 110
    /// Notation extras drawn on the staff.
    var markers: [StaffMarker] = []
    var repeats: [RepeatSpan] = []
    /// Ear training: the app plays the prompt automatically before the learner answers.
    var listenFirst: Bool = false
    /// What Listen/Demo plays, when it differs from `events` (e.g. a reference note then the answer).
    var prompt: [ExpectedEvent]? = nil

    var isTimed: Bool {
        if case .timed = timing { return true }
        return false
    }

    var timedConfig: TimedConfig? {
        if case .timed(let c) = timing { return c }
        return nil
    }

    var totalBeats: Double {
        let end = events.map { $0.beat + $0.duration }.max() ?? 0
        if let c = timedConfig {
            if let t = c.totalBeats { return t }
            let bar = Double(c.beatsPerBar)
            return (end / bar).rounded(.up) * bar
        }
        return end
    }
}

// MARK: - Results

struct RuleResult: Identifiable {
    let id = UUID()
    let name: String
    let passed: Bool
    let detail: String
}

struct TaskResult {
    var accuracy: Double
    var correct: Int
    var total: Int
    var wrongNotes: Int
    var meanAbsDeviationMs: Double?
    var meanDeviationMs: Double?
    var timingSpreadMs: Double?
    var velocityMean: Double?
    var velocityStdDev: Double?
    var bpm: Double?
    var rules: [RuleResult]
    var passed: Bool
    var stars: Int
}
