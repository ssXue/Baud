import Foundation

public struct CANIDStats: Identifiable, Sendable {
    public let id: UInt32
    public let arbitrationID: UInt32
    public var frameCount: Int
    public var intervals: [TimeInterval]
    public var lastTimestamp: Date?

    public var detectedPeriod: TimeInterval? {
        guard intervals.count >= 3 else { return nil }
        let sorted = intervals.sorted()
        return sorted[sorted.count / 2]
    }

    public var avgInterval: TimeInterval? {
        guard !intervals.isEmpty else { return nil }
        return intervals.reduce(0, +) / Double(intervals.count)
    }

    public var minInterval: TimeInterval? {
        intervals.min()
    }

    public var maxInterval: TimeInterval? {
        intervals.max()
    }

    public var jitter: TimeInterval? {
        guard intervals.count >= 2 else { return nil }
        let avg = intervals.reduce(0, +) / Double(intervals.count)
        let variance = intervals.reduce(0) { $0 + ($1 - avg) * ($1 - avg) } / Double(intervals.count)
        return sqrt(variance)
    }

    public var stabilityStatus: StabilityStatus {
        guard let period = detectedPeriod, let jitter else { return .unknown }
        let jitterRatio = jitter / period
        if jitterRatio < 0.1 { return .stable }
        if jitterRatio < 0.3 { return .warning }
        return .unstable
    }

    public var timeoutStatus: TimeoutStatus {
        guard let last = lastTimestamp, let period = detectedPeriod else { return .unknown }
        let elapsed = Date().timeIntervalSince(last)
        if elapsed > period * 5 { return .lost }
        if elapsed > period * 3 { return .timeout }
        if elapsed > period * 2 { return .warning }
        return .ok
    }

    public init(arbitrationID: UInt32) {
        self.id = arbitrationID
        self.arbitrationID = arbitrationID
        self.frameCount = 0
        self.intervals = []
    }

    public var idHex: String {
        String(format: "%03X", arbitrationID)
    }

    public static let maxIntervals = 100
}

public enum StabilityStatus: String, Sendable {
    case unknown = "—"
    case stable = "Stable"
    case warning = "Warning"
    case unstable = "Unstable"
}

public enum TimeoutStatus: String, Sendable {
    case unknown = "—"
    case ok = "OK"
    case warning = "Slow"
    case timeout = "Timeout"
    case lost = "Lost"
}

public struct CANErrorEvent: Identifiable, Sendable {
    public let id: UUID
    public let code: UInt8
    public let timestamp: Date

    public init(code: UInt8, timestamp: Date) {
        self.id = UUID()
        self.code = code
        self.timestamp = timestamp
    }

    public var description: String {
        switch code {
        case 0x01: return "Bit Error"
        case 0x02: return "Form Error"
        case 0x04: return "Stuff Error"
        case 0x08: return "CRC Error"
        case 0x10: return "ACK Error"
        case 0x20: return "Bit1 Error"
        case 0x40: return "Bit0 Error"
        case 0x80: return "Bus Off"
        default: return "Unknown (0x\(String(format: "%02X", code)))"
        }
    }
}
