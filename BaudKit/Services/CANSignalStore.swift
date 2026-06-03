import Foundation

@Observable
@MainActor
public final class CANSignalStore {
    public var signals: [CANSignal] = [] {
        didSet { saveSignals() }
    }

    @ObservationIgnored public var chartData: [UUID: [SignalDataPoint]] = [:]
    public var maxPoints = 200
    public var chartRevision = 0

    private let maxDataPoints = 1000
    private var lastFrameTime: Date = .distantPast
    private var chartUpdateTimer: Timer?
    private var needsChartUpdate = false

    public init() {
        loadSignals()
        startChartTimer()
        NotificationCenter.default.addObserver(
            forName: .projectImported, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.reloadFromDefaults() }
        }
    }

    public func reloadFromDefaults() {
        loadSignals()
    }


    public func addSignal(_ signal: CANSignal) {
        signals.append(signal)
        chartData[signal.id] = []
    }

    public func removeSignal(id: UUID) {
        signals.removeAll { $0.id == id }
        chartData.removeValue(forKey: id)
    }

    public func processFrame(_ frame: CANFrame) {
        guard frame.direction == .received else { return }

        let now = frame.timestamp
        if now.timeIntervalSince(lastFrameTime) > 0.5 {
            clearChartData()
        }
        lastFrameTime = now

        for signal in signals where signal.enabled && signal.arbitrationID == frame.arbitrationID {
            guard let value = signal.extractValue(from: frame.data) else { continue }
            let newIndex = (chartData[signal.id]?.last?.index ?? -1) + 1
            let point = SignalDataPoint(index: newIndex, value: value, timestamp: frame.timestamp)

            if chartData[signal.id] == nil {
                chartData[signal.id] = []
            }
            chartData[signal.id]!.append(point)

            if chartData[signal.id]!.count > maxDataPoints {
                chartData[signal.id]!.removeFirst(chartData[signal.id]!.count - maxDataPoints)
            }
        }
        needsChartUpdate = true
    }

    public func clearChartData() {
        for key in chartData.keys {
            chartData[key] = []
        }
        chartRevision += 1
        needsChartUpdate = false
    }

    private func startChartTimer() {
        chartUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.needsChartUpdate else { return }
                self.needsChartUpdate = false
                self.chartRevision += 1
            }
        }
    }

    private func saveSignals() {
        if let data = try? JSONEncoder().encode(signals) {
            UserDefaults.standard.set(data, forKey: "baud.canSignals")
        }
    }

    private func loadSignals() {
        if let data = UserDefaults.standard.data(forKey: "baud.canSignals"),
           let saved = try? JSONDecoder().decode([CANSignal].self, from: data) {
            signals = saved
            for signal in signals {
                chartData[signal.id] = []
            }
        }
    }
}

public struct SignalDataPoint {
    public let index: Int
    public let value: Double
    public let timestamp: Date
}
