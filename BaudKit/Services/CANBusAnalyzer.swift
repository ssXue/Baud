import Foundation

@Observable
@MainActor
public final class CANBusAnalyzer {
    @ObservationIgnored private(set) public var idStats: [UInt32: CANIDStats] = [:]
    private(set) public var errorEvents: [CANErrorEvent] = []
    private(set) public var totalBitsSent: Int = 0
    public var busLoadBitrate: Int = 500_000

    private(set) public var busLoadPercent: Double = 0
    private(set) public var timeoutWarnings: [CANIDStats] = []

    public var statsRevision = 0

    private let busLoadWindow: TimeInterval = 1.0
    private var busLoadBitEvents: [(timestamp: Date, bits: Int)] = []
    private var timeoutCheckTimer: Timer?
    private var statsUpdateTimer: Timer?
    private var needsStatsUpdate = false

    public init() {
        startStatsTimer()
    }


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
        needsStatsUpdate = true
    }

    public func addError(_ code: UInt8) {
        let event = CANErrorEvent(code: code, timestamp: Date())
        errorEvents.append(event)
    }

    public func clearIntervals() {
        for key in idStats.keys {
            idStats[key]?.intervals.removeAll()
        }
        statsRevision += 1
        needsStatsUpdate = false
    }

    private func updateBusLoad() {
        let cutoff = Date().addingTimeInterval(-busLoadWindow)
        busLoadBitEvents = busLoadBitEvents.filter { $0.timestamp > cutoff }
        let bitsInWindow = busLoadBitEvents.reduce(0) { $0 + $1.bits }
        busLoadPercent = Double(bitsInWindow) / Double(busLoadBitrate) * 100.0
    }

    private func checkTimeouts() {
        let now = Date()
        let warnings = idStats.values.filter { stats in
            guard let last = stats.lastTimestamp else { return false }
            return now.timeIntervalSince(last) > 2.0 && stats.frameCount > 5
        }
        timeoutWarnings = warnings
    }

    public func startTimeoutChecker() {
        stopTimeoutChecker()
        timeoutCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateBusLoad()
                self?.checkTimeouts()
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
        timeoutWarnings.removeAll()
        statsRevision += 1
        needsStatsUpdate = false
    }

    private func estimateFrameBits(id: UInt32, isExtended: Bool, isRemote: Bool, dlc: UInt8) -> Int {
        let baseBits = isExtended ? 67 : 47
        let stuffBits = (baseBits + Int(dlc) * 8) / 5
        return baseBits + Int(dlc) * 8 + stuffBits + 19
    }

    private func startStatsTimer() {
        statsUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.needsStatsUpdate else { return }
                self.needsStatsUpdate = false
                self.statsRevision += 1
            }
        }
    }
}
