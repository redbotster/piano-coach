import AVFoundation
import Accelerate
import Foundation

/// One note of the sung line found in a recording.
struct TrackNote: Codable, Equatable {
    var start: Double
    var length: Double
    var midi: Int
}

/// A recording the user imported to sing along with, plus what the analysis found in it.
struct VoiceTrack: Codable, Identifiable {
    var id: String
    var title: String
    /// Name of the copied audio file inside the tracks folder.
    var audioFile: String
    var sourceFile: String
    var duration: Double
    /// Pitch class of the key (0 = C) and whether it is minor.
    var keyTonic: Int
    var minor: Bool
    /// How clearly the key stood out, 0...1.
    var keyConfidence: Double
    /// How far the recording is tuned from concert pitch, in cents.
    var tuningCents: Double
    var notes: [TrackNote]

    var lessonID: String { "mytracks.\(id)" }

    static let pitchNames = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]
    var keyName: String { "\(Self.pitchNames[((keyTonic % 12) + 12) % 12]) \(minor ? "minor" : "major")" }
}

/// Finds the key and the main sung melody of a recording.
///
/// The voice is usually mixed to the centre, so sound that differs between left and right is turned down first.
/// Each moment is then searched for the pitch whose harmonics are strongest, and the most continuous path
/// through those pitches is taken as the melody. This is an estimate: it follows the most prominent pitched
/// sound, which is usually but not always the lead vocal.
enum TrackAnalyzer {
    struct Result {
        var notes: [TrackNote]
        var keyTonic: Int
        var minor: Bool
        var keyConfidence: Double
        var tuningCents: Double
        var duration: Double
    }

    enum Failure: LocalizedError {
        case unreadable, tooLong, tooShort
        var errorDescription: String? {
            switch self {
            case .unreadable: return "The file could not be read as audio."
            case .tooLong: return "The recording is longer than 12 minutes."
            case .tooShort: return "The recording is shorter than 3 seconds."
            }
        }
    }

    static let maxSeconds = 12.0 * 60

    /// Decode a sound file into left and right channels (right is nil for mono).
    static func load(_ url: URL) throws -> (left: [Float], right: [Float]?, sampleRate: Double) {
        guard let file = try? AVAudioFile(forReading: url) else { throw Failure.unreadable }
        let format = file.processingFormat
        let total = Int(file.length)
        guard format.sampleRate > 0, total > 0 else { throw Failure.unreadable }
        if Double(total) / format.sampleRate > maxSeconds { throw Failure.tooLong }
        if Double(total) / format.sampleRate < 3 { throw Failure.tooShort }
        var left = [Float](); left.reserveCapacity(total)
        var right = [Float]()
        let stereo = format.channelCount >= 2
        if stereo { right.reserveCapacity(total) }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1 << 16) else { throw Failure.unreadable }
        while file.framePosition < file.length {
            do { try file.read(into: buffer) } catch { break }
            let count = Int(buffer.frameLength)
            guard count > 0, let data = buffer.floatChannelData else { break }
            left.append(contentsOf: UnsafeBufferPointer(start: data[0], count: count))
            if stereo { right.append(contentsOf: UnsafeBufferPointer(start: data[1], count: count)) }
        }
        guard left.count > Int(format.sampleRate * 3) else { throw Failure.unreadable }
        return (left, stereo ? right : nil, format.sampleRate)
    }

    static func analyze(url: URL, progress: ((Double) -> Void)? = nil) throws -> Result {
        let audio = try load(url)
        progress?(0.1)
        return analyze(left: audio.left, right: audio.right, sampleRate: audio.sampleRate) { progress?(0.1 + 0.9 * $0) }
    }

    // Pitch grid: five steps per semitone from C2 to C6.
    private static let lowestMidi = 36.0
    private static let stepsPerSemitone = 5
    private static let candidates = 48 * stepsPerSemitone + 1

    static func analyze(left: [Float], right: [Float]?, sampleRate: Double, progress: ((Double) -> Void)? = nil) -> Result {
        let size = sampleRate > 30000 ? 4096 : 2048
        let hop = Int((sampleRate / 100).rounded())
        let frames = max(0, (left.count - size) / hop + 1)
        let duration = Double(left.count) / sampleRate
        guard frames > 20, let setup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(size), .FORWARD) else {
            return Result(notes: [], keyTonic: 0, minor: false, keyConfidence: 0, tuningCents: 0, duration: duration)
        }
        defer { vDSP_DFT_DestroySetup(setup) }

        let binHz = sampleRate / Double(size)
        let bins = min(size / 2 - 2, Int(5200 / binHz))
        var window = [Float](repeating: 0, count: size)
        vDSP_hann_window(&window, vDSP_Length(size), Int32(vDSP_HANN_NORM))

        // Weight that favours the band where a voice carries most of its energy and ignores bass.
        var weight = [Float](repeating: 0, count: bins)
        for b in 0..<bins {
            let f = Double(b) * binHz
            let lowCut = min(1, max(0, (f - 140) / 200))
            let highCut = f < 3000 ? 1 : max(0.2, 1 - (f - 3000) / 2500)
            weight[b] = Float(lowCut * highCut)
        }

        // Where each harmonic of each candidate pitch falls in the spectrum.
        let harmonics = 8
        var harmonicBin = [Int32](repeating: -1, count: candidates * harmonics)
        var harmonicFrac = [Float](repeating: 0, count: candidates * harmonics)
        var harmonicGain = [Float](repeating: 0, count: harmonics)
        for h in 0..<harmonics { harmonicGain[h] = powf(0.84, Float(h)) }
        for c in 0..<candidates {
            let f0 = 440 * pow(2, (lowestMidi + Double(c) / Double(stepsPerSemitone) - 69) / 12)
            for h in 0..<harmonics {
                let position = f0 * Double(h + 1) / binHz
                let whole = Int(position)
                guard whole + 1 < bins else { break }
                harmonicBin[c * harmonics + h] = Int32(whole)
                harmonicFrac[c * harmonics + h] = Float(position - Double(whole))
            }
        }

        // Pitch class of each bin, for the key.
        var binClass = [Int](repeating: -1, count: bins)
        for b in 0..<bins {
            let f = Double(b) * binHz
            if f >= 190, f <= 2100 { binClass[b] = ((Int((69 + 12 * log2(f / 440)).rounded()) % 12) + 12) % 12 }
        }
        var chroma = [Double](repeating: 0, count: 12)

        var salience = [Float](repeating: 0, count: frames * candidates)
        var frameMax = [Float](repeating: 0, count: frames)

        var inReal = [Float](repeating: 0, count: size), zeros = [Float](repeating: 0, count: size)
        var lRe = [Float](repeating: 0, count: size), lIm = [Float](repeating: 0, count: size)
        var rRe = [Float](repeating: 0, count: size), rIm = [Float](repeating: 0, count: size)
        var voice = [Float](repeating: 0, count: bins), mid = [Float](repeating: 0, count: bins)
        var sorted = [Float](repeating: 0, count: candidates)
        var exponent: Float = 0.6
        var count32 = Int32(bins)

        for frame in 0..<frames {
            let offset = frame * hop
            left.withUnsafeBufferPointer { vDSP_vmul($0.baseAddress! + offset, 1, window, 1, &inReal, 1, vDSP_Length(size)) }
            vDSP_DFT_Execute(setup, inReal, zeros, &lRe, &lIm)
            if let right {
                right.withUnsafeBufferPointer { vDSP_vmul($0.baseAddress! + offset, 1, window, 1, &inReal, 1, vDSP_Length(size)) }
                vDSP_DFT_Execute(setup, inReal, zeros, &rRe, &rIm)
                for b in 0..<bins {
                    let lr = lRe[b], li = lIm[b], rr = rRe[b], ri = rIm[b]
                    let power = lr * lr + li * li + rr * rr + ri * ri + 1e-12
                    // 1 when left and right carry the same sound (centre), near 0 when they differ.
                    let similarity = 2 * (lr * rr + li * ri) / power
                    let keep = min(1, max(0, (similarity - 0.55) / 0.4))
                    let mr = (lr + rr) / 2, mi = (li + ri) / 2
                    let magnitude = (mr * mr + mi * mi).squareRoot()
                    mid[b] = magnitude
                    voice[b] = magnitude * keep * keep
                }
            } else {
                for b in 0..<bins {
                    let magnitude = (lRe[b] * lRe[b] + lIm[b] * lIm[b]).squareRoot()
                    mid[b] = magnitude
                    voice[b] = magnitude
                }
            }

            // Key: add the spectral peaks to their pitch classes.
            for b in 2..<(bins - 1) where binClass[b] >= 0 && mid[b] > mid[b - 1] && mid[b] >= mid[b + 1] {
                chroma[binClass[b]] += Double(mid[b])
            }

            // Compress, so one loud partial does not swamp the rest, then apply the voice band.
            vvpowsf(&voice, &exponent, voice, &count32)
            vDSP_vmul(voice, 1, weight, 1, &voice, 1, vDSP_Length(bins))

            let row = frame * candidates
            for c in 0..<candidates {
                var sum: Float = 0
                for h in 0..<harmonics {
                    let b = Int(harmonicBin[c * harmonics + h])
                    if b < 0 { break }
                    let frac = harmonicFrac[c * harmonics + h]
                    sum += harmonicGain[h] * (voice[b] * (1 - frac) + voice[b + 1] * frac)
                }
                salience[row + c] = sum
            }
            // Take away the level that noise and drums add to every pitch alike.
            for c in 0..<candidates { sorted[c] = salience[row + c] }
            vDSP_vsort(&sorted, vDSP_Length(candidates), 1)
            let floor = sorted[candidates / 2]
            var best: Float = 0
            for c in 0..<candidates {
                let value = max(0, salience[row + c] - floor)
                salience[row + c] = value
                best = max(best, value)
            }
            frameMax[frame] = best
            if frame % 500 == 0 { progress?(0.8 * Double(frame) / Double(frames)) }
        }

        // Scale so that a clearly sung moment is about 1.
        var levels = frameMax
        vDSP_vsort(&levels, vDSP_Length(frames), 1)
        let reference = max(1e-9, levels[min(frames - 1, Int(Double(frames) * 0.9))])
        var scale = 1 / reference
        vDSP_vsmul(salience, 1, &scale, &salience, 1, vDSP_Length(salience.count))

        let path = track(salience: salience, frames: frames)
        progress?(0.95)

        // Pitch of each voiced frame, refined between grid steps.
        var contour = [Double?](repeating: nil, count: frames)
        for frame in 0..<frames {
            let c = path[frame]
            guard c >= 0 else { continue }
            var fine = Double(c)
            if c > 0, c < candidates - 1 {
                let a = Double(salience[frame * candidates + c - 1]), b = Double(salience[frame * candidates + c])
                let d = Double(salience[frame * candidates + c + 1])
                let denominator = a - 2 * b + d
                if denominator < 0 { fine += max(-0.5, min(0.5, 0.5 * (a - d) / denominator)) }
            }
            contour[frame] = lowestMidi + fine / Double(stepsPerSemitone)
        }

        // How far the recording sits from concert pitch.
        var sine = 0.0, cosine = 0.0
        for case let pitch? in contour {
            let angle = 2 * Double.pi * (pitch - pitch.rounded())
            sine += sin(angle); cosine += cos(angle)
        }
        let tuning = (sine == 0 && cosine == 0) ? 0 : atan2(sine, cosine) / (2 * Double.pi)

        let frameSeconds = Double(hop) / sampleRate
        let centre = Double(size) / 2 / sampleRate
        let notes = fixOctaves(segment(contour: contour, tuning: tuning, frameSeconds: frameSeconds, offset: centre))
        let key = findKey(chroma: chroma, notes: notes)
        progress?(1)
        return Result(notes: notes, keyTonic: key.tonic, minor: key.minor, keyConfidence: key.confidence,
                      tuningCents: tuning * 100, duration: duration)
    }

    /// The most continuous path through the strongest pitches; -1 marks frames with no singing.
    private static func track(salience: [Float], frames: Int) -> [Int] {
        let n = candidates
        let reach = 6                    // steps the pitch may slide between frames
        let slideCost: Float = 0.035     // per step
        let jumpCost: Float = 0.9        // leaping to any other pitch
        let switchCost: Float = 0.45     // starting or stopping
        let silent: Float = 0.33         // what a frame is worth with no voice
        var previous = [Float](repeating: 0, count: n), current = [Float](repeating: 0, count: n)
        var previousSilent: Float = 0
        var back = [Int16](repeating: -1, count: frames * n)
        var backSilent = [Int16](repeating: -1, count: frames)
        for c in 0..<n { previous[c] = salience[c] - switchCost }
        previousSilent = silent

        for frame in 1..<frames {
            var bestAny: Float = -.infinity
            var bestAnyIndex = 0
            for c in 0..<n where previous[c] > bestAny { bestAny = previous[c]; bestAnyIndex = c }
            let row = frame * n
            for c in 0..<n {
                var best = previousSilent - switchCost
                var from: Int16 = -1
                if bestAny - jumpCost > best { best = bestAny - jumpCost; from = Int16(bestAnyIndex) }
                let low = max(0, c - reach), high = min(n - 1, c + reach)
                for p in low...high {
                    let value = previous[p] - slideCost * Float(abs(p - c))
                    if value > best { best = value; from = Int16(p) }
                }
                current[c] = best + salience[row + c]
                back[row + c] = from
            }
            let stay = previousSilent, stop = bestAny - switchCost
            let nextSilent: Float
            if stay >= stop { nextSilent = stay + silent; backSilent[frame] = -1 }
            else { nextSilent = stop + silent; backSilent[frame] = Int16(bestAnyIndex) }
            swap(&previous, &current)
            previousSilent = nextSilent
        }

        var path = [Int](repeating: -1, count: frames)
        var state = -1
        var best = previousSilent
        for c in 0..<n where previous[c] > best { best = previous[c]; state = c }
        for frame in stride(from: frames - 1, through: 0, by: -1) {
            path[frame] = state
            if frame == 0 { break }
            state = state >= 0 ? Int(back[frame * n + state]) : Int(backSilent[frame])
        }
        return path
    }

    /// Turn the pitch curve into notes: steady stretches on one semitone.
    private static func segment(contour: [Double?], tuning: Double, frameSeconds: Double, offset: Double) -> [TrackNote] {
        let frames = contour.count
        // Nearest semitone for each frame, then the commonest value nearby, which steadies vibrato and slides.
        let raw: [Int?] = contour.map { $0.map { Int(($0 - tuning).rounded()) } }
        var steady = [Int?](repeating: nil, count: frames)
        let half = 6
        for frame in 0..<frames {
            guard raw[frame] != nil else { continue }
            var counts: [Int: Int] = [:]
            for k in max(0, frame - half)...min(frames - 1, frame + half) {
                if let value = raw[k] { counts[value, default: 0] += 1 }
            }
            steady[frame] = counts.max { $0.value != $1.value ? $0.value < $1.value : abs($0.key - raw[frame]!) > abs($1.key - raw[frame]!) }?.key
        }
        var notes: [TrackNote] = []
        var start = 0
        while start < frames {
            guard let pitch = steady[start] else { start += 1; continue }
            var end = start + 1
            while end < frames, steady[end] == pitch { end += 1 }
            notes.append(TrackNote(start: Double(start) * frameSeconds + offset, length: Double(end - start) * frameSeconds, midi: pitch))
            start = end
        }
        // Join pieces of one note split by a brief dropout, then drop anything too short to be sung.
        var joined: [TrackNote] = []
        for note in notes {
            if let last = joined.last, last.midi == note.midi, note.start - (last.start + last.length) <= 0.09 {
                joined[joined.count - 1].length = note.start + note.length - last.start
            } else {
                joined.append(note)
            }
        }
        return joined.filter { $0.length >= 0.11 }
    }

    /// Move notes that jumped an octave away from their neighbours back in line.
    private static func fixOctaves(_ notes: [TrackNote]) -> [TrackNote] {
        guard notes.count >= 5 else { return notes }
        var out = notes
        for i in notes.indices {
            let around = (max(0, i - 6)...min(notes.count - 1, i + 6)).filter { $0 != i }.map { notes[$0].midi }.sorted()
            let middle = around[around.count / 2]
            var pitch = notes[i].midi
            while pitch - middle > 9 { pitch -= 12 }
            while middle - pitch > 9 { pitch += 12 }
            out[i].midi = pitch
        }
        return out
    }

    private static let majorProfile = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
    private static let minorProfile = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]

    /// Compare how much each pitch class is used with the typical pattern of every major and minor key.
    static func findKey(chroma: [Double], notes: [TrackNote]) -> (tonic: Int, minor: Bool, confidence: Double) {
        var usage = chroma
        let total = usage.reduce(0, +)
        if total > 0 { usage = usage.map { $0 / total } }
        // The melody counts as well: time spent on each pitch class.
        var melody = [Double](repeating: 0, count: 12)
        for note in notes { melody[((note.midi % 12) + 12) % 12] += note.length }
        let melodyTotal = melody.reduce(0, +)
        if melodyTotal > 0 { for i in 0..<12 { usage[i] += 0.5 * melody[i] / melodyTotal } }

        func correlation(_ a: [Double], _ b: [Double]) -> Double {
            let ma = a.reduce(0, +) / 12, mb = b.reduce(0, +) / 12
            var top = 0.0, da = 0.0, db = 0.0
            for i in 0..<12 { top += (a[i] - ma) * (b[i] - mb); da += (a[i] - ma) * (a[i] - ma); db += (b[i] - mb) * (b[i] - mb) }
            return da > 0 && db > 0 ? top / (da * db).squareRoot() : 0
        }
        var scores: [(tonic: Int, minor: Bool, score: Double)] = []
        for tonic in 0..<12 {
            let rotated = (0..<12).map { usage[($0 + tonic) % 12] }
            scores.append((tonic, false, correlation(rotated, majorProfile)))
            scores.append((tonic, true, correlation(rotated, minorProfile)))
        }
        scores.sort { $0.score > $1.score }
        let confidence = max(0, min(1, (scores[0].score - scores[1].score) * 4 + max(0, scores[0].score - 0.5)))
        return (scores[0].tonic, scores[0].minor, confidence)
    }
}

// MARK: - Self-test

extension TrackAnalyzer {
    /// A made-up recording: a sung line in the centre over panned chords, a bass and drum noise.
    static func demoMix(melody: [(midi: Int?, beats: Double)], chords: [[Int]], bpm: Double = 100, sampleRate: Double = 44100,
                        vocalLevel: Float = 0.30, stereo: Bool = true) -> (left: [Float], right: [Float], truth: [TrackNote]) {
        let beat = 60 / bpm
        let total = melody.reduce(0) { $0 + $1.beats } * beat + 1
        let count = Int(total * sampleRate)
        var left = [Float](repeating: 0, count: count), right = [Float](repeating: 0, count: count)
        var truth: [TrackNote] = []
        func hz(_ midi: Double) -> Double { 440 * pow(2, (midi - 69) / 12) }
        var seed: UInt64 = 0x2545F4914F6CDD1D
        func noise() -> Float {
            seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
            return Float(Double(seed % 20001) / 10000 - 1)
        }

        // Voice: harmonics shaped by a broad formant, with vibrato and a soft start to each note.
        var cursor = 0.5
        for note in melody {
            let length = note.beats * beat
            if let midi = note.midi {
                truth.append(TrackNote(start: cursor, length: length * 0.92, midi: midi))
                let first = Int(cursor * sampleRate), samples = Int(length * 0.92 * sampleRate)
                var phase = 0.0
                for i in 0..<samples where first + i < count {
                    let t = Double(i) / sampleRate
                    let vibrato = 0.35 * min(1, t / 0.25) * sin(2 * Double.pi * 5.5 * t)
                    let f = hz(Double(midi) + vibrato)
                    phase += 2 * Double.pi * f / sampleRate
                    var value = 0.0
                    for h in 1...12 {
                        let partial = f * Double(h)
                        guard partial < 5000 else { break }
                        let formant = exp(-pow((partial - 700) / 900, 2)) + 0.5 * exp(-pow((partial - 2600) / 700, 2)) + 0.08
                        value += formant / Double(h).squareRoot() * sin(Double(h) * phase)
                    }
                    let envelope = min(1, t / 0.04) * min(1, (length * 0.92 - t) / 0.05)
                    let sample = vocalLevel * Float(value * envelope) * 0.5
                    left[first + i] += sample
                    right[first + i] += sample
                }
            }
            cursor += length
        }

        // Accompaniment: one chord per bar, each chord note panned to a different side; a bass on the root.
        let bar = 4 * beat
        for (index, chord) in chords.enumerated() {
            let first = Int((0.5 + Double(index) * bar) * sampleRate), samples = Int(bar * sampleRate)
            for (k, midi) in chord.enumerated() {
                let pan: Float = stereo ? (k % 2 == 0 ? 0.15 : 0.85) : 0.5
                let f = hz(Double(midi))
                for i in 0..<samples where first + i < count {
                    let t = Double(i) / sampleRate
                    var value = 0.0
                    for h in 1...6 { value += sin(2 * Double.pi * f * Double(h) * t) / Double(h * h) }
                    let sample = 0.10 * Float(value * exp(-t * 1.2))
                    left[first + i] += sample * (1 - pan) * 2
                    right[first + i] += sample * pan * 2
                }
            }
            if let root = chord.first {
                let f = hz(Double(root - 24))
                for i in 0..<samples where first + i < count {
                    let t = Double(i) / sampleRate
                    let sample = 0.22 * Float((sin(2 * Double.pi * f * t) + 0.4 * sin(4 * Double.pi * f * t)) * exp(-(t.truncatingRemainder(dividingBy: beat)) * 3))
                    left[first + i] += sample
                    right[first + i] += sample
                }
            }
        }
        // Drums: a burst of noise on every beat.
        var beatTime = 0.5
        while beatTime < total - 0.2 {
            let first = Int(beatTime * sampleRate)
            for i in 0..<Int(0.08 * sampleRate) where first + i < count {
                let sample = 0.12 * noise() * Float(exp(-Double(i) / sampleRate * 40))
                left[first + i] += sample
                right[first + i] += sample
            }
            beatTime += beat
        }
        return (left, right, truth)
    }

    /// Share of the true melody's time that the found notes cover with the right note name (any octave).
    static func coverage(found: [TrackNote], truth: [TrackNote]) -> (hit: Double, extra: Double) {
        var covered = 0.0, total = 0.0
        for note in truth {
            total += note.length
            for other in found where (other.midi - note.midi) % 12 == 0 {
                covered += max(0, min(note.start + note.length, other.start + other.length) - max(note.start, other.start))
            }
        }
        // Found notes that fall where nothing was sung, or on the wrong note.
        var stray = 0.0, foundTotal = 0.0
        for other in found {
            foundTotal += other.length
            var matched = 0.0
            for note in truth where (other.midi - note.midi) % 12 == 0 {
                matched += max(0, min(note.start + note.length, other.start + other.length) - max(note.start, other.start))
            }
            stray += max(0, other.length - matched)
        }
        return (total > 0 ? covered / total : 0, foundTotal > 0 ? stray / foundTotal : 0)
    }

    // "Twinkle" in C with a rest in each line, over C, F and G chords.
    static let demoTune: [(midi: Int?, beats: Double)] = [
        (60, 1), (60, 1), (67, 1), (67, 1), (69, 1), (69, 1), (67, 2),
        (65, 1), (65, 1), (64, 1), (64, 1), (62, 1), (62, 1), (60, 1), (nil, 1),
        (67, 1), (67, 1), (65, 1), (65, 1), (64, 1), (64, 1), (62, 2),
        (67, 1), (67, 1), (65, 1), (65, 1), (64, 1), (64, 1), (62, 1), (nil, 1),
    ]
    static let demoChords = [[48, 52, 55, 60], [53, 57, 60, 52], [53, 57, 60, 55], [43, 50, 59, 55],
                             [48, 52, 55, 64], [53, 57, 60, 65], [48, 55, 64, 60], [43, 47, 50, 59]]

    static func writeDemo(to url: URL) -> Bool {
        let mix = demoMix(melody: demoTune, chords: demoChords)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(mix.left.count)) else { return false }
        buffer.frameLength = AVAudioFrameCount(mix.left.count)
        mix.left.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: mix.left.count) }
        mix.right.withUnsafeBufferPointer { buffer.floatChannelData![1].update(from: $0.baseAddress!, count: mix.right.count) }
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 2,
                                       AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false]
        guard let file = try? AVAudioFile(forWriting: url, settings: settings) else { return false }
        return (try? file.write(from: buffer)) != nil
    }

    static func selfTest() -> Bool {
        let tune = demoTune, chords = demoChords
        var failures = 0
        func expect(_ ok: Bool, _ name: String) {
            print("  \(ok ? "ok  " : "FAIL")  \(name)")
            if !ok { failures += 1 }
        }
        for (name, stereo, level) in [("a stereo mix", true, Float(0.30)), ("a mono mix", false, Float(0.34)), ("a quiet vocal in stereo", true, Float(0.17))] {
            let mix = demoMix(melody: tune, chords: chords, vocalLevel: level, stereo: stereo)
            let started = Date()
            let result = analyze(left: mix.left, right: stereo ? mix.right : nil, sampleRate: 44100)
            let score = coverage(found: result.notes, truth: mix.truth)
            print(String(format: "        %@: %d notes found for %d sung, %.0f%% of the melody covered, %.0f%% stray, key %@, %.1f s",
                         name, result.notes.count, mix.truth.count, score.hit * 100, score.extra * 100,
                         VoiceTrack.pitchNames[result.keyTonic] + (result.minor ? " minor" : " major"), Date().timeIntervalSince(started)))
            expect(score.hit >= 0.8 && score.extra <= 0.25, "the sung line is found in \(name)")
            expect(result.keyTonic == 0 && !result.minor, "the key of \(name) is C major")
        }
        // A recording tuned a quarter-tone-ish sharp still lands on the right notes.
        let sharp = demoMix(melody: tune.map { ($0.midi, $0.beats) }, chords: chords)
        let resampled = analyze(left: sharp.left, right: sharp.right, sampleRate: 44100 * pow(2, 0.3 / 12))
        expect(abs(resampled.tuningCents - 30) < 12, String(format: "a recording 30 cents sharp is measured as such (%.0f)", resampled.tuningCents))
        let silence = analyze(left: [Float](repeating: 0, count: 44100 * 4), right: nil, sampleRate: 44100)
        expect(silence.notes.isEmpty, "silence gives no notes")
        print(failures == 0 ? "All track-analysis checks passed" : "\(failures) track-analysis check(s) FAILED")
        return failures == 0
    }
}
