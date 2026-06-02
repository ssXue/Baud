import Foundation

@Observable
@MainActor
public final class CANBusAnalyzer {
    private(set) public var idStats: [UInt32: CANIDStats] = [:]
    private(set) public var errorEvents: [CANErrorEvent] = []
    private(set) public var totalBitsSent: Int = 0
    public var busLoadBitrate: Int = 500_000

    private(set) public var busLoadPercent: Double = 0
    private(set) public var timeoutWarnings: [CANIDStats] = []

    private let busLoadWindow: TimeInterval = 1.0
    private var busLoadBitEvents: [(timestamp: Date, bits: Int)] = []
    private var timeoutCheckTimer: Timer?

    public init() {}

    public var errorCount: Int { errorEvents.count }

    public var statsList: [CANIDStats] {
        idStats.values.sorted { $0.arbitrationID < $1.arbitrationID }
    }

    public func processFrame(_ frame: CANFrame) {
        guard frame.direction == .received else { return }

        let id = frame.arbitrationID
        let now = frame.timestamp

        if idStats[id] == nil {
            idStats[id] = CANIDStats(arbitrationID: id)
        }

        var stats = idStats[id]!

        if let last = stats.lastTimestamp {
            let interval = now.timeIntervalSince(last)
            if interval > 0 {
                stats.intervals.append(interval)
                if stats.intervals.count > CANIDStats.maxIntervals {
                    stats.intervals.removeFirst(stats.intervals.count - CANIDStats.maxIntervals)
                }
            }
        }

        stats.frameCount += 1
        stats.lastTimestamp = now
        idStats[id] = stats

        let frameBits = estimateFrameBits(id: id, isExtended: frame.isExtended, isRemote: frame.isRemote, dlc: frame.dlc)
        totalBitsSent += frameBits
        busLoadBitEvents.append((timestamp: now, bits: frameBits))
    }

    public func addError(_ code: UInt8) {
        let event = CANErrorEvent(code: code, timestamp: Date())
        errorEvents.append(event)
        if errorEvents.count > 1000 {
            errorEvents.removeFirst(errorEvents.count - 1000)
        }
    }

    public func clearIntervals() {
        for id in idStats.keys {
            idStats[id]?.intervals.removeAll()
        }
    }

    private func updateBusLoad() {
        let cutoff = Date().addingTimeInterval(-busLoadWindow)
        busLoadBitEvents.removeAll { $0.timestamp < cutoff }
        let bitsInWindow = busLoadBitEvents.reduce(0) { $0 + $1.bits }
        guard busLoadBitrate > 0 else { busLoadPercent = 0; return }
        busLoadPercent = min(100.0, Double(bitsInWindow) / Double(busLoadBitrate) * 100.0)
    }

    private func checkTimeouts() {
        timeoutWarnings = idStats.values.filter {
            $0.timeoutStatus == .warning || $0.timeoutStatus == .timeout || $0.timeoutStatus == .lost
        }.sorted { $0.arbitrationID < $1.arbitrationID }
    }

    public func startTimeoutChecker() {
        stopTimeoutChecker()
        timeoutCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor in
                self.updateBusLoad()
                self.checkTimeouts()
            }
        }
    }

    public func stopTimeoutChecker() {
        timeoutCheckTimer?.invalidate()
        timeoutCheckTimer = nil
    }

    public func clear() {
        idStats.removeAll()
        errorEvents.removeAll()
        totalBitsSent = 0
        busLoadBitEvents.removeAll()
        busLoadPercent = 0
        timeoutWarnings = []
    }

    private func estimateFrameBits(id: UInt32, isExtended: Bool, isRemote: Bool, dlc: UInt8) -> Int {
        let arbBits = isExtended ? 29 : 11
        let controlBits = isExtended ? 6 : 4
        let dataBits = isRemote ? 0 : Int(dlc) * 8
        let overhead = 1 + 4 + 15 + 2 + 7 + 3
        let base = arbBits + controlBits + dataBits + overhead
        return base + base / 5
    }
}
