import CoreMIDI
import Foundation

enum HostClock {
    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    static func now() -> Double { seconds(mach_absolute_time()) }

    static func seconds(_ ticks: UInt64) -> Double {
        Double(ticks) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000_000
    }

    static func ticks(_ seconds: Double) -> UInt64 {
        UInt64(max(0, seconds) * 1_000_000_000 * Double(timebase.denom) / Double(timebase.numer))
    }
}

enum InputEvent {
    case noteOn(note: Int, velocity: Int, time: Double)
    case noteOff(note: Int, time: Double)
    case pedal(down: Bool, time: Double)
}

/// Listens to every MIDI source and forwards notes and the sustain pedal on the main thread.
final class MIDIManager: ObservableObject {
    @Published var sourceNames: [String] = []
    @Published var launchkeyName: String?

    var onEvent: ((InputEvent) -> Void)?

    private var client = MIDIClientRef()
    private var inPort = MIDIPortRef()
    private var outPort = MIDIPortRef()
    private var connected: [MIDIEndpointRef] = []
    private var ignored: Set<MIDIEndpointRef> = []
    private var dawDestination: MIDIEndpointRef?
    private var dawModeOn = false

    init() {
        MIDIClientCreateWithBlock("PianoCoach" as CFString, &client) { [weak self] notification in
            if notification.pointee.messageID == .msgSetupChanged {
                DispatchQueue.main.async { self?.refresh() }
            }
        }
        MIDIInputPortCreateWithBlock(client, "PianoCoach In" as CFString, &inPort) { [weak self] list, _ in
            self?.receive(list)
        }
        MIDIOutputPortCreate(client, "PianoCoach Out" as CFString, &outPort)
        refresh()
    }

    var isConnected: Bool { !sourceNames.isEmpty }

    private func name(of endpoint: MIDIEndpointRef) -> String {
        var value: Unmanaged<CFString>?
        MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &value)
        return (value?.takeRetainedValue() as String?) ?? "MIDI device"
    }

    func refresh() {
        for source in connected { MIDIPortDisconnectSource(inPort, source) }
        connected = []
        var names: [String] = []
        var launchkey: String?
        for i in 0..<MIDIGetNumberOfSources() {
            let source = MIDIGetSource(i)
            let sourceName = name(of: source)
            // The Launchkey's second port carries DAW control data (pads, transport), not the keys.
            if sourceName.localizedCaseInsensitiveContains("DAW") { continue }
            MIDIPortConnectSource(inPort, source, nil)
            connected.append(source)
            names.append(sourceName)
            if sourceName.localizedCaseInsensitiveContains("Launchkey") { launchkey = sourceName }
        }
        dawDestination = nil
        for i in 0..<MIDIGetNumberOfDestinations() {
            let destination = MIDIGetDestination(i)
            let destName = name(of: destination)
            if destName.localizedCaseInsensitiveContains("Launchkey"), destName.localizedCaseInsensitiveContains("DAW") {
                dawDestination = destination
            }
        }
        sourceNames = names
        launchkeyName = launchkey
    }

    // MARK: Input

    private func receive(_ list: UnsafePointer<MIDIPacketList>) {
        var events: [InputEvent] = []
        for packet in list.unsafeSequence() {
            let length = Int(packet.pointee.length)
            let stamp = packet.pointee.timeStamp
            let time = stamp == 0 ? HostClock.now() : HostClock.seconds(stamp)
            let bytes = withUnsafeBytes(of: packet.pointee.data) { Array($0.prefix(min(length, 256))) }
            var i = 0
            var status: UInt8 = 0
            while i < bytes.count {
                let byte = bytes[i]
                if byte >= 0xF8 { i += 1; continue }                 // realtime
                if byte >= 0xF0 {                                     // sysex / system common: skip
                    i += 1
                    while i < bytes.count, bytes[i] < 0x80 { i += 1 }
                    status = 0
                    continue
                }
                if byte >= 0x80 { status = byte; i += 1 }
                guard status != 0 else { i += 1; continue }
                let kind = status & 0xF0
                let channel = status & 0x0F
                let size = (kind == 0xC0 || kind == 0xD0) ? 1 : 2
                guard i + size <= bytes.count else { break }
                let d1 = Int(bytes[i])
                let d2 = size == 2 ? Int(bytes[i + 1]) : 0
                i += size
                // Channel 10 is the drum pads; they would collide with the low keys.
                if channel == 9 { continue }
                switch kind {
                case 0x90 where d2 > 0: events.append(.noteOn(note: d1, velocity: d2, time: time))
                case 0x90, 0x80: events.append(.noteOff(note: d1, time: time))
                case 0xB0 where d1 == 64: events.append(.pedal(down: d2 >= 64, time: time))
                default: break
                }
            }
        }
        guard !events.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in
            for event in events { self?.onEvent?(event) }
        }
    }

    // MARK: Launchkey pad lights (experimental)

    private func send(_ bytes: [UInt8], to destination: MIDIEndpointRef) {
        var list = MIDIPacketList()
        var packet = MIDIPacketListInit(&list)
        packet = MIDIPacketListAdd(&list, MemoryLayout<MIDIPacketList>.size, packet, 0, bytes.count, bytes)
        MIDISend(outPort, destination, &list)
    }

    var canLightPads: Bool { dawDestination != nil }

    /// Puts the Launchkey into DAW mode so its 16 pads can be lit from the app.
    func setPadLights(enabled: Bool) {
        guard let destination = dawDestination else { return }
        if enabled, !dawModeOn {
            send([0x9F, 0x0C, 0x7F], to: destination)
            dawModeOn = true
        } else if !enabled, dawModeOn {
            fillPads(color: 0)
            send([0x9F, 0x0C, 0x00], to: destination)
            dawModeOn = false
        }
    }

    /// Novation palette indices: 0 off, 5 red, 9 orange, 13 yellow, 21 green, 45 blue, 3 white.
    func fillPads(color: UInt8) {
        guard dawModeOn, let destination = dawDestination else { return }
        for note in Array(0x60...0x67) + Array(0x70...0x77) {
            send([0x90, UInt8(note), color], to: destination)
        }
    }

    func flashPads(color: UInt8, duration: Double = 0.12) {
        guard dawModeOn else { return }
        fillPads(color: color)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in self?.fillPads(color: 0) }
    }
}
