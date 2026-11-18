import AVFoundation
import Accelerate
import Combine

/// One pitch reading from the microphone.
struct PitchFrame {
    /// Seconds on the `HostClock` timeline (the middle of the analysed window).
    var time: Double
    /// Fractional MIDI note number (69 = A 440), or nil when no clear pitch was heard.
    var midi: Double?
    /// Loudness, 0...1.
    var level: Double
    var clarity: Double

    static let silent = PitchFrame(time: 0, midi: nil, level: 0, clarity: 0)
}

/// Monophonic pitch detection (the YIN algorithm).
struct PitchDetector {
    let sampleRate: Double
    let window: Int
    private let tauMin: Int
    private let tauMax: Int
    private let span: Int

    init(sampleRate: Double, minHz: Double = 65, maxHz: Double = 1200) {
        self.sampleRate = sampleRate
        tauMax = Int(sampleRate / minHz)
        tauMin = max(2, Int(sampleRate / maxHz))
        window = max(Int(sampleRate * 0.046), tauMax * 2 + 64)
        span = window - tauMax
    }

    /// Analyse `window` samples. Returns nil for silence or noise.
    func detect(_ x: UnsafePointer<Float>, gate: Float = 0.006) -> (hz: Double, clarity: Double, rms: Double) {
        var rms: Float = 0
        vDSP_rmsqv(x, 1, &rms, vDSP_Length(window))
        guard rms > gate else { return (0, 0, Double(rms)) }

        // d(tau) = sum over the span of (x[j] - x[j + tau])^2 = e(0) + e(tau) - 2 r(tau)
        var e0: Float = 0
        vDSP_svesq(x, 1, &e0, vDSP_Length(span))
        var d = [Float](repeating: 0, count: tauMax + 1)
        var energy = e0
        for tau in 1...tauMax {
            energy += x[tau + span - 1] * x[tau + span - 1] - x[tau - 1] * x[tau - 1]
            var r: Float = 0
            vDSP_dotpr(x, 1, x + tau, 1, &r, vDSP_Length(span))
            d[tau] = max(0, e0 + energy - 2 * r)
        }
        // Cumulative mean normalised difference
        var running: Float = 0
        var cmnd = [Float](repeating: 1, count: tauMax + 1)
        for tau in 1...tauMax {
            running += d[tau]
            cmnd[tau] = running > 0 ? d[tau] * Float(tau) / running : 1
        }
        var best = -1
        var tau = tauMin
        while tau < tauMax {
            if cmnd[tau] < 0.15 {
                while tau + 1 < tauMax, cmnd[tau + 1] < cmnd[tau] { tau += 1 }
                best = tau
                break
            }
            tau += 1
        }
        if best < 0 {
            var lowest: Float = 1
            for t in tauMin..<tauMax where cmnd[t] < lowest { lowest = cmnd[t]; best = t }
            if lowest > 0.35 { return (0, Double(1 - lowest), Double(rms)) }
        }
        var refined = Double(best)
        if best > 1, best < tauMax {
            let a = Double(cmnd[best - 1]), b = Double(cmnd[best]), c = Double(cmnd[best + 1])
            let denominator = a - 2 * b + c
            if abs(denominator) > 1e-9 { refined += 0.5 * (a - c) / denominator }
        }
        return (sampleRate / refined, Double(1 - cmnd[best]), Double(rms))
    }

    static func midi(_ hz: Double) -> Double { 69 + 12 * log2(hz / 440) }
    static func hz(_ midi: Double) -> Double { 440 * pow(2, (midi - 69) / 12) }
}

/// Splits incoming audio into overlapping windows and reports a pitch for each.
final class PitchTracker {
    let detector: PitchDetector
    private let hop: Int
    private var buffer: [Float] = []
    private var recent: [Double?] = []

    init(sampleRate: Double) {
        detector = PitchDetector(sampleRate: sampleRate)
        hop = max(256, Int(sampleRate / 90))
    }

    /// Feed samples whose first sample was captured at `startTime`. Returns the new readings.
    func process(_ samples: UnsafeBufferPointer<Float>, startTime: Double) -> [PitchFrame] {
        let pending = buffer.count
        buffer.append(contentsOf: samples)
        var frames: [PitchFrame] = []
        var offset = 0
        while buffer.count - offset >= detector.window {
            let result = buffer.withUnsafeBufferPointer { detector.detect($0.baseAddress! + offset) }
            let centre = Double(offset - pending) + Double(detector.window) / 2
            var midi: Double? = result.hz > 0 && result.clarity > 0.8 ? PitchDetector.midi(result.hz) : nil
            // Median of three removes single-frame octave jumps.
            recent.append(midi)
            if recent.count > 3 { recent.removeFirst() }
            let voiced = recent.compactMap { $0 }.sorted()
            if midi != nil, voiced.count == 3 { midi = voiced[1] }
            frames.append(PitchFrame(time: startTime + centre / detector.sampleRate, midi: midi,
                                     level: min(1, result.rms * 6), clarity: result.clarity))
            offset += hop
        }
        if offset > 0 { buffer.removeFirst(offset) }
        return frames
    }

    func reset() {
        buffer = []
        recent = []
    }
}

/// Pitch-correction settings.
struct AutoTune: Equatable {
    enum Scale: String, CaseIterable, Identifiable {
        case chromatic = "Chromatic", major = "Major", minor = "Minor", pentatonic = "Pentatonic"
        var id: String { rawValue }
        var degrees: [Int] {
            switch self {
            case .chromatic: return Array(0..<12)
            case .major: return [0, 2, 4, 5, 7, 9, 11]
            case .minor: return [0, 2, 3, 5, 7, 8, 10]
            case .pentatonic: return [0, 2, 4, 7, 9]
            }
        }
    }

    enum Style: String, CaseIterable, Identifiable {
        case natural = "Natural", strong = "Strong", robot = "Robot"
        var id: String { rawValue }
        /// How much of the error is corrected, and how quickly the correction follows the voice (per reading).
        var strength: Double { self == .natural ? 0.85 : 1 }
        var speed: Double {
            switch self {
            case .natural: return 0.18
            case .strong: return 0.5
            case .robot: return 1
            }
        }
    }

    var key = 0
    var scale = Scale.major
    var style = Style.strong

    /// The nearest note of the scale to a sung pitch.
    func target(_ midi: Double) -> Double {
        let allowed = Set(scale.degrees.map { ($0 + key) % 12 })
        let nearest = Int(midi.rounded())
        var best = Double(nearest)
        var distance = Double.infinity
        for candidate in (nearest - 3)...(nearest + 3) where allowed.contains(((candidate % 12) + 12) % 12) {
            let gap = abs(Double(candidate) - midi)
            if gap < distance { distance = gap; best = Double(candidate) }
        }
        return best
    }

    /// Carries the smoothed correction from one reading to the next.
    struct State {
        var cents = 0.0
    }

    /// Pitch shift to apply, in cents, for one reading.
    func correction(_ midi: Double?, state: inout State) -> Double {
        guard let midi else { return state.cents }
        let wanted = (target(midi) - midi) * 100 * style.strength
        state.cents += (wanted - state.cents) * style.speed
        return max(-1200, min(1200, state.cents))
    }
}

/// A short recording of the singer with its pitch track.
struct VoiceTake {
    var samples: [Float]
    var sampleRate: Double
    /// Readings with `time` measured in seconds from the start of the take.
    var frames: [PitchFrame]
    var duration: Double { Double(samples.count) / sampleRate }

    /// Analyse a recording from scratch.
    static func analysed(_ samples: [Float], sampleRate: Double) -> VoiceTake {
        let tracker = PitchTracker(sampleRate: sampleRate)
        let frames = samples.withUnsafeBufferPointer { tracker.process($0, startTime: 0) }
        return VoiceTake(samples: samples, sampleRate: sampleRate, frames: frames)
    }

    /// Render the take with pitch correction applied (faster than real time).
    func tuned(_ settings: AutoTune) -> [Float]? {
        guard !samples.isEmpty, let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let source = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else { return nil }
        source.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let shifter = AVAudioUnitTimePitch()
        engine.attach(player)
        engine.attach(shifter)
        engine.connect(player, to: shifter, format: format)
        engine.connect(shifter, to: engine.mainMixerNode, format: format)
        let block: AVAudioFrameCount = 512
        do {
            try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: block)
            try engine.start()
        } catch {
            return nil
        }
        player.scheduleBuffer(source, at: nil, options: [], completionHandler: nil)
        player.play()
        guard let out = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: block) else { return nil }

        var result: [Float] = []
        result.reserveCapacity(samples.count)
        var state = AutoTune.State()
        var frameIndex = 0
        // The shifter delays its output a little; render that much extra and drop it from the front.
        let latency = Int(shifter.latency * sampleRate)
        let total = samples.count + latency
        while result.count < total {
            let now = Double(result.count) / sampleRate
            while frameIndex < frames.count, frames[frameIndex].time <= now {
                shifter.pitch = Float(settings.correction(frames[frameIndex].midi, state: &state))
                frameIndex += 1
            }
            let wanted = min(block, AVAudioFrameCount(total - result.count))
            guard let status = try? engine.renderOffline(wanted, to: out), status == .success, out.frameLength > 0 else { break }
            result.append(contentsOf: UnsafeBufferPointer(start: out.floatChannelData![0], count: Int(out.frameLength)))
        }
        player.stop()
        engine.stop()
        return Array(result.dropFirst(min(latency, result.count)))
    }
}

/// Publishes live readings separately, so only the pitch displays redraw for each one.
final class VoiceMeter: ObservableObject {
    @Published var frame = PitchFrame.silent
}

/// Microphone input: live pitch tracking, optional monitoring through headphones (plain or auto-tuned),
/// and short recordings.
final class VoiceEngine: ObservableObject {
    enum State: Equatable {
        case off, starting, running, denied
        case failed(String)
    }
    enum Monitor: String, CaseIterable, Identifiable {
        case off = "Off", plain = "My voice", tuned = "Auto-Tune"
        var id: String { rawValue }
    }

    @Published private(set) var state = State.off
    @Published var monitor = Monitor.off { didSet { applyMonitor() } }
    @Published var tune = AutoTune()
    @Published private(set) var isRecording = false
    @Published private(set) var isPlaying = false
    @Published private(set) var take: VoiceTake?
    @Published private(set) var canMonitor = false

    let meter = VoiceMeter()
    /// Called on the main thread for every reading.
    var onFrame: ((PitchFrame) -> Void)?

    private let engine = AVAudioEngine()
    private let shifter = AVAudioUnitTimePitch()
    private let monitorMixer = AVAudioMixerNode()
    /// Plays recorded takes (the app's main output).
    var output: AudioEngine?
    private var tracker: PitchTracker?
    private var tuneState = AutoTune.State()
    private var attached = false
    private var monitorConnected = false
    private var sampleRate = 48000.0

    // Written on the audio thread, read on the main thread.
    private let lock = NSLock()
    private var recording: [Float]?
    private var recordedFrames: [PitchFrame] = []
    private var recordStart = 0.0
    static let maxTakeSeconds = 90.0

    var isRunning: Bool { state == .running }

    /// Ask for the microphone if needed, then start listening.
    func start() {
        guard state != .running, state != .starting else { return }
        state = .starting
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            begin()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self, self.state == .starting else { return }
                    if granted { self.begin() } else { self.state = .denied }
                }
            }
        default:
            state = .denied
        }
    }

    private func begin() {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            state = .failed("No microphone was found.")
            return
        }
        sampleRate = format.sampleRate
        let tracker = PitchTracker(sampleRate: sampleRate)
        self.tracker = tracker

        if !attached {
            engine.attach(shifter)
            engine.attach(monitorMixer)
            attached = true
        }
        monitorMixer.outputVolume = 0
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, when in
            self?.capture(buffer, when: when, tracker: tracker)
        }
        // Lessons only listen. The path that plays the voice back out is added when monitoring is switched on.
        monitorConnected = false
        canMonitor = true
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            state = .failed("The microphone could not be started: \(error.localizedDescription)")
            return
        }
        state = .running
        applyMonitor()
    }

    /// Join microphone → pitch shifter → output. Some device pairs cannot be joined; then monitoring is unavailable.
    private func connectMonitor() -> Bool {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        engine.stop()
        engine.connect(input, to: shifter, format: format)
        engine.connect(shifter, to: monitorMixer, format: format)
        engine.connect(monitorMixer, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
            monitorConnected = true
            return true
        } catch {
            engine.disconnectNodeOutput(input)
            engine.disconnectNodeOutput(shifter)
            engine.disconnectNodeOutput(monitorMixer)
            canMonitor = false
            try? engine.start()
            if !engine.isRunning { state = .failed("The microphone stopped: \(error.localizedDescription)") }
            return false
        }
    }

    func stop() {
        stopPlayback()
        if isRecording { stopRecording() }
        if engine.isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        if monitorConnected {
            engine.disconnectNodeOutput(engine.inputNode)
            engine.disconnectNodeOutput(shifter)
            engine.disconnectNodeOutput(monitorMixer)
            monitorConnected = false
        }
        tracker = nil
        meter.frame = .silent
        if state == .running || state == .starting { state = .off }
    }

    private func applyMonitor() {
        if monitor != .off, isRunning, canMonitor, !monitorConnected, !connectMonitor() {
            monitor = .off
            return
        }
        monitorMixer.outputVolume = (monitor != .off && monitorConnected && isRunning) ? 1 : 0
        if monitor != .tuned {
            shifter.pitch = 0
            tuneState = AutoTune.State()
        }
    }

    private func capture(_ buffer: AVAudioPCMBuffer, when: AVAudioTime, tracker: PitchTracker) {
        guard let channel = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return }
        let samples = UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength))
        let start = when.isHostTimeValid ? HostClock.seconds(when.hostTime)
                                         : HostClock.now() - Double(buffer.frameLength) / sampleRate
        let frames = tracker.process(samples, startTime: start)
        lock.lock()
        if recording != nil {
            if recording!.isEmpty { recordStart = start }
            recording!.append(contentsOf: samples)
            recordedFrames += frames.map { PitchFrame(time: $0.time - recordStart, midi: $0.midi, level: $0.level, clarity: $0.clarity) }
        }
        let full = Double(recording?.count ?? 0) / sampleRate >= Self.maxTakeSeconds
        lock.unlock()
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isRunning else { return }
            for frame in frames {
                if self.monitor == .tuned {
                    self.shifter.pitch = Float(self.tune.correction(frame.midi, state: &self.tuneState))
                }
                self.onFrame?(frame)
            }
            if let last = frames.last { self.meter.frame = last }
            if full, self.isRecording { self.stopRecording() }
        }
    }

    // MARK: Takes

    func startRecording() {
        guard isRunning, !isRecording else { return }
        stopPlayback()
        lock.lock()
        recording = []
        recording?.reserveCapacity(Int(sampleRate * 30))
        recordedFrames = []
        lock.unlock()
        isRecording = true
    }

    func stopRecording() {
        guard isRecording else { return }
        lock.lock()
        let samples = recording ?? []
        let frames = recordedFrames
        recording = nil
        recordedFrames = []
        lock.unlock()
        isRecording = false
        if Double(samples.count) / sampleRate > 0.3 {
            take = VoiceTake(samples: samples, sampleRate: sampleRate, frames: frames.filter { $0.time >= 0 })
        }
    }

    /// Play the last take, as recorded or with pitch correction.
    func play(tuned: Bool) {
        guard let take, let output else { return }
        stopPlayback()
        let samples = tuned ? (take.tuned(tune) ?? take.samples) : take.samples
        isPlaying = true
        output.playSamples(samples, sampleRate: take.sampleRate) { [weak self] in self?.isPlaying = false }
    }

    func stopPlayback() {
        output?.stopSamples()
        isPlaying = false
    }

    /// Write the last take to a WAV file.
    @discardableResult
    func export(tuned: Bool, to url: URL) -> Bool {
        guard let take else { return false }
        let samples = tuned ? (take.tuned(tune) ?? take.samples) : take.samples
        guard let format = AVAudioFormat(standardFormatWithSampleRate: take.sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else { return false }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: take.sampleRate,
                                       AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16,
                                       AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false]
        do {
            let file = try AVAudioFile(forWriting: url, settings: settings)
            try file.write(from: buffer)
            return true
        } catch {
            return false
        }
    }

    // MARK: Self-test

    /// Synthesise a voice-like tone (harmonics plus optional vibrato).
    static func tone(_ midi: Double, seconds: Double, sampleRate: Double = 48000, vibratoCents: Double = 0) -> [Float] {
        var phase = 0.0
        var out: [Float] = []
        let count = Int(seconds * sampleRate)
        out.reserveCapacity(count)
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let wobble: Double = vibratoCents / 100 * sin(2 * Double.pi * 5.5 * t)
            let hz: Double = PitchDetector.hz(midi + wobble)
            phase += 2 * Double.pi * hz / sampleRate
            let value: Double = 0.25 * sin(phase) + 0.12 * sin(2 * phase) + 0.06 * sin(3 * phase)
            out.append(Float(value))
        }
        return out
    }

    static func selfTest() -> Bool {
        var failures = 0
        func expect(_ ok: Bool, _ name: String) {
            print("  \(ok ? "ok  " : "FAIL")  \(name)")
            if !ok { failures += 1 }
        }
        func median(_ take: VoiceTake) -> Double? {
            let voiced = take.frames.dropFirst(4).compactMap { $0.midi }.sorted()
            return voiced.isEmpty ? nil : voiced[voiced.count / 2]
        }
        for rate in [44100.0, 48000.0] {
            for midi in [40.0, 48.0, 57.3, 69.0, 76.5, 84.0] {
                let take = VoiceTake.analysed(tone(midi, seconds: 0.6, sampleRate: rate), sampleRate: rate)
                let found = median(take) ?? -1
                expect(abs(found - midi) < 0.05, "detects MIDI \(midi) at \(Int(rate)) Hz (heard \(String(format: "%.2f", found)))")
            }
        }
        let vibrato = VoiceTake.analysed(tone(64, seconds: 1.0, vibratoCents: 40), sampleRate: 48000)
        expect(abs((median(vibrato) ?? 0) - 64) < 0.3, "a note with vibrato centres on the note")
        var seed: UInt64 = 42
        let noise: [Float] = (0..<48000).map { _ in
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Float(Double(seed >> 33) / Double(1 << 31) - 0.5) * 0.3
        }
        let noisy = VoiceTake.analysed(noise, sampleRate: 48000)
        expect(noisy.frames.filter { $0.midi != nil }.count < noisy.frames.count / 10, "noise is not mistaken for a note")
        let quiet = VoiceTake.analysed([Float](repeating: 0, count: 24000), sampleRate: 48000)
        expect(quiet.frames.allSatisfy { $0.midi == nil }, "silence has no pitch")

        var tune = AutoTune(key: 0, scale: .major, style: .robot)
        expect(tune.target(61.4) == 62 && tune.target(60.6) == 60, "C major snaps C♯ to the nearest scale note")
        tune.scale = .chromatic
        expect(tune.target(61.4) == 61, "chromatic snaps to the nearest semitone")

        // A note sung 40 cents sharp comes out in tune.
        let sharp = VoiceTake.analysed(tone(69.4, seconds: 1.5), sampleRate: 48000)
        if let fixed = sharp.tuned(tune) {
            let after = VoiceTake.analysed(Array(fixed.dropFirst(12000)), sampleRate: 48000)
            let found = median(after) ?? -1
            expect(abs(found - 69) < 0.08, "auto-tune moves A +40 cents onto A (result \(String(format: "%.2f", found)))")
            expect(abs(fixed.count - sharp.samples.count) < 4800, "auto-tuned take keeps its length")
        } else {
            expect(false, "auto-tune renders a take")
        }
        print(failures == 0 ? "All voice checks passed" : "\(failures) voice check(s) FAILED")
        return failures == 0
    }
}
