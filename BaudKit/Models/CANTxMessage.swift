import Foundation

public struct CANTxMessage: Codable, Identifiable {
    public let id: UUID
    public var arbitrationID: UInt32
    public var isExtended: Bool
    public var isRemote: Bool
    public var data: [UInt8]
    public var periodMs: Int
    public var isEnabled: Bool
    public var signalGenerator: SignalGenerator?

    public init(
        id: UUID = UUID(),
        arbitrationID: UInt32 = 0x123,
        isExtended: Bool = false,
        isRemote: Bool = false,
        data: [UInt8] = [],
        periodMs: Int = 1000,
        isEnabled: Bool = false,
        signalGenerator: SignalGenerator? = nil
    ) {
        self.id = id
        self.arbitrationID = arbitrationID
        self.isExtended = isExtended
        self.isRemote = isRemote
        self.data = data
        self.periodMs = periodMs
        self.isEnabled = isEnabled
        self.signalGenerator = signalGenerator
    }

    public var idHex: String {
        if isExtended {
            return String(format: "%08X", arbitrationID)
        }
        return String(format: "%03X", arbitrationID)
    }

    public var dataHex: String {
        data.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

public struct SignalGenerator: Codable, Sendable {
    public var targetByteIndex: Int
    public var waveform: Waveform
    public var amplitude: Double
    public var offset: Double
    public var frequencyHz: Double

    public init(
        targetByteIndex: Int = 0,
        waveform: Waveform = .none,
        amplitude: Double = 127,
        offset: Double = 128,
        frequencyHz: Double = 1.0
    ) {
        self.targetByteIndex = targetByteIndex
        self.waveform = waveform
        self.amplitude = amplitude
        self.offset = offset
        self.frequencyHz = frequencyHz
    }

    public func value(at time: TimeInterval) -> Double {
        let phase = time * frequencyHz * 2 * .pi
        switch waveform {
        case .none:
            return offset
        case .sine:
            return offset + amplitude * sin(phase)
        case .square:
            return offset + amplitude * (sin(phase) >= 0 ? 1 : -1)
        case .triangle:
            let t = time * frequencyHz
            let p = t.truncatingRemainder(dividingBy: 1.0)
            return offset + amplitude * (4 * abs(p - 0.5) - 1)
        case .sawtooth:
            let t = time * frequencyHz
            let p = t.truncatingRemainder(dividingBy: 1.0)
            return offset + amplitude * (2 * p - 1)
        }
    }

    public func apply(to data: [UInt8], at time: TimeInterval) -> [UInt8] {
        guard !data.isEmpty else { return data }
        var result = data
        let idx = min(targetByteIndex, result.count - 1)
        let v = value(at: time)
        result[idx] = UInt8(clamping: Int(round(v)))
        return result
    }

    public enum Waveform: String, Codable, CaseIterable, Identifiable, Sendable {
        case none = "None"
        case sine = "Sine"
        case square = "Square"
        case triangle = "Triangle"
        case sawtooth = "Sawtooth"

        public var id: String { rawValue }

        public var systemImage: String {
            switch self {
            case .none: "minus"
            case .sine: "waveform.path"
            case .square: "rectangle"
            case .triangle: "triangle"
            case .sawtooth: "chart.line.uptrend.xyaxis"
            }
        }
    }
}
