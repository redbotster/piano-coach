import AVFoundation
import AudioToolbox

/// Built-in piano sound (the Launchkey makes no sound of its own) and a sample-accurate metronome.
final class AudioEngine {
    private let engine = AVAudioEngine()
    private let piano = AVAudioUnitSampler()
    private let clicker = AVAudioPlayerNode()
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

    func cancelClicks() {
        guard isRunning else { return }
        clicker.stop()
        clicker.play()
    }
}
