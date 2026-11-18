import AVFoundation
import AudioToolbox

/// Built-in piano sound (the Launchkey makes no sound of its own) and a sample-accurate metronome.
final class AudioEngine {
    private let engine = AVAudioEngine()
    private let piano = AVAudioUnitSampler()
    private let clicker = AVAudioPlayerNode()
    private let samplePlayer = AVAudioPlayerNode()
    private var sampleToken = 0
    private let clickFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    private var accentClick: AVAudioPCMBuffer!
    private var normalClick: AVAudioPCMBuffer!
    private(set) var isRunning = false

    var pianoVolume: Float = 0.9 { didSet { piano.volume = pianoVolume } }
    var clickVolume: Float = 0.7 { didSet { clicker.volume = clickVolume } }

    init() {
        accentClick = makeClick(frequency: 1760, length: 0.045)
        normalClick = makeClick(frequency: 1100, length: 0.035)
        engine.attach(piano)
        engine.attach(clicker)
        engine.attach(samplePlayer)
        engine.connect(piano, to: engine.mainMixerNode, format: nil)
        engine.connect(clicker, to: engine.mainMixerNode, format: clickFormat)
        do {
            try engine.start()
            isRunning = true
            loadInstrument(from: nil)
            clicker.play()
        } catch {
            NSLog("Audio engine failed to start: \(error)")
        }
        piano.volume = pianoVolume
        clicker.volume = clickVolume
    }

    static let builtInBank = URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")

    /// Load the piano from a SoundFont (.sf2) or DLS file; nil restores the built-in sound.
    @discardableResult
    func loadInstrument(from url: URL?) -> Bool {
        guard isRunning else { return false }
        do {
            try piano.loadSoundBankInstrument(at: url ?? Self.builtInBank, program: 0,
                                              bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                                              bankLSB: UInt8(kAUSampler_DefaultBankLSB))
            return true
        } catch {
            if url != nil { loadInstrument(from: nil) }
            return false
        }
    }

    private func makeClick(frequency: Double, length: Double) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(clickFormat.sampleRate * length)
        let buffer = AVAudioPCMBuffer(pcmFormat: clickFormat, frameCapacity: frames)!
        buffer.frameLength = frames
        let samples = buffer.floatChannelData![0]
        for i in 0..<Int(frames) {
            let t = Double(i) / clickFormat.sampleRate
            let envelope = exp(-t * 90)
            samples[i] = Float(sin(2 * .pi * frequency * t) * envelope * 0.8)
        }
        return buffer
    }

    func noteOn(_ note: Int, velocity: Int) {
        guard isRunning, (0...127).contains(note) else { return }
        piano.startNote(UInt8(note), withVelocity: UInt8(max(1, min(127, velocity))), onChannel: 0)
    }

    func noteOff(_ note: Int) {
        guard isRunning, (0...127).contains(note) else { return }
        piano.stopNote(UInt8(note), onChannel: 0)
    }

    func sustain(_ down: Bool) {
        guard isRunning else { return }
        piano.sendController(64, withValue: down ? 127 : 0, onChannel: 0)
    }

    func allNotesOff() {
        guard isRunning else { return }
        piano.sendController(64, withValue: 0, onChannel: 0)
        for note in 0..<128 { piano.stopNote(UInt8(note), onChannel: 0) }
    }

    /// Schedule metronome clicks at exact host times (seconds on the `HostClock` timeline).
    func scheduleClicks(_ clicks: [(time: Double, accent: Bool)]) {
        guard isRunning else { return }
        if !clicker.isPlaying { clicker.play() }
        let now = HostClock.now()
        for click in clicks where click.time > now {
            let when = AVAudioTime(hostTime: HostClock.ticks(click.time))
            clicker.scheduleBuffer(click.accent ? accentClick : normalClick, at: when, options: [], completionHandler: nil)
        }
    }

    /// Play a mono recording (for example a sung take) through the app's output.
    func playSamples(_ samples: [Float], sampleRate: Double, completion: @escaping () -> Void) {
        guard isRunning, !samples.isEmpty,
              let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
            completion()
            return
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
        samplePlayer.stop()
        engine.connect(samplePlayer, to: engine.mainMixerNode, format: format)
        sampleToken += 1
        let token = sampleToken
        samplePlayer.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
            DispatchQueue.main.async {
                guard let self, self.sampleToken == token else { return }
                completion()
            }
        }
        samplePlayer.play()
    }

    func stopSamples() {
        sampleToken += 1
        if isRunning, samplePlayer.engine != nil { samplePlayer.stop() }
    }

    func cancelClicks() {
        guard isRunning else { return }
        clicker.stop()
        clicker.play()
    }
}

/// Plays a list of notes at exact host times from a high-priority queue, so playback stays even
/// regardless of what the main thread is drawing.
final class NoteSequencer {
    struct Event {
        var time: Double      // seconds on the `HostClock` timeline
        var note: Int
        var velocity: Int     // 0 = note off
    }

    private let audio: AudioEngine
    private let queue = DispatchQueue(label: "pianocoach.sequencer", qos: .userInteractive)
    private var timer: DispatchSourceTimer?
    private var events: [Event] = []
    private var next = 0
    private var sounding: [Int: Int] = [:]

    /// Called on the sequencer queue with how late each event fired, in seconds (used by the self-test).
    var onFire: ((Double) -> Void)?

    init(audio: AudioEngine) { self.audio = audio }

    /// Fires silent events and checks they land on time.
    static func selfTest() -> Bool {
        let sequencer = NoteSequencer(audio: AudioEngine())
        var late: [Double] = []
        sequencer.onFire = { late.append($0) }
        let start = HostClock.now() + 0.05
        sequencer.play((0..<60).map { Event(time: start + Double($0) * 0.02, note: 60, velocity: 0) })
        Thread.sleep(forTimeInterval: 1.5)
        sequencer.stop()
        let worst = late.map { abs($0) }.max() ?? 1
        let ok = late.count == 60 && worst < 0.005
        print(String(format: "  %@  sequencer fired %d of 60 events, worst lateness %.2f ms", ok ? "ok  " : "FAIL", late.count, worst * 1000))
        return ok
    }

    func play(_ list: [Event]) {
        stop()
        // Note-offs before note-ons at the same instant, so repeated notes re-strike.
        let sorted = list.sorted { $0.time != $1.time ? $0.time < $1.time : $0.velocity < $1.velocity }
        queue.sync {
            events = sorted
            next = 0
            let t = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
            t.setEventHandler { [weak self] in self?.fire() }
            timer = t
            arm()
            t.resume()
        }
    }

    func stop() {
        queue.sync {
            timer?.cancel()
            timer = nil
            events = []
            next = 0
            for note in sounding.keys { audio.noteOff(note) }
            sounding = [:]
        }
    }

    private func arm() {
        guard let timer, next < events.count else { return }
        let delay = max(0, events[next].time - HostClock.now())
        timer.schedule(deadline: .now() + delay, repeating: .never, leeway: .nanoseconds(0))
    }

    private func fire() {
        let now = HostClock.now() + 0.0005
        while next < events.count, events[next].time <= now {
            let e = events[next]
            next += 1
            onFire?(HostClock.now() - e.time)
            if e.velocity > 0 {
                audio.noteOn(e.note, velocity: e.velocity)
                sounding[e.note, default: 0] += 1
            } else if let count = sounding[e.note] {
                if count <= 1 {
                    sounding[e.note] = nil
                    audio.noteOff(e.note)
                } else {
                    sounding[e.note] = count - 1
                }
            }
        }
        arm()
    }
}
