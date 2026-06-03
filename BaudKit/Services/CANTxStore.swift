import Foundation

@Observable
@MainActor
public final class CANTxStore {
    public var messages: [CANTxMessage] = [] {
        didSet { saveMessages() }
    }

    private var timers: [UUID: Timer] = [:]
    private var startTime: Date = .now
    private weak var slcanManager: SLCANManager?

    public init() {
        loadMessages()
        NotificationCenter.default.addObserver(
            forName: .projectImported, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.reloadFromDefaults() }
        }
    }

    public func reloadFromDefaults() {
        loadMessages()
    }

    public func configure(with slcanManager: SLCANManager) {
        self.slcanManager = slcanManager
    }

    public func addMessage(_ msg: CANTxMessage = CANTxMessage()) {
        messages.append(msg)
        if msg.isEnabled {
            startTimer(for: msg.id)
        }
    }

    public func removeMessage(id: UUID) {
        stopTimer(for: id)
        messages.removeAll { $0.id == id }
    }

    public func updateMessage(_ msg: CANTxMessage) {
        guard let idx = messages.firstIndex(where: { $0.id == msg.id }) else { return }
        let wasEnabled = messages[idx].isEnabled
        messages[idx] = msg
        if msg.isEnabled && !wasEnabled {
            startTimer(for: msg.id)
        } else if !msg.isEnabled && wasEnabled {
            stopTimer(for: msg.id)
        }
    }

    public func toggleEnabled(id: UUID) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[idx].isEnabled.toggle()
        if messages[idx].isEnabled {
            startTimer(for: id)
        } else {
            stopTimer(for: id)
        }
        saveMessages()
    }

    public func sendOnce(id: UUID) {
        guard let msg = messages.first(where: { $0.id == id }) else { return }
        transmit(msg)
    }

    public func stopAll() {
        for id in messages.map(\.id) {
            stopTimer(for: id)
        }
    }

    public func startAll() {
        for msg in messages where msg.isEnabled {
            startTimer(for: msg.id)
        }
    }

    private func startTimer(for id: UUID) {
        stopTimer(for: id)
        guard let msg = messages.first(where: { $0.id == id }) else { return }
        guard msg.periodMs > 0 else { return }

        startTime = .now
        let interval = TimeInterval(msg.periodMs) / 1000.0
        timers[id] = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fireTimer(for: id)
            }
        }
    }

    private func stopTimer(for id: UUID) {
        timers[id]?.invalidate()
        timers.removeValue(forKey: id)
    }

    private func fireTimer(for id: UUID) {
        guard let msg = messages.first(where: { $0.id == id }) else {
            stopTimer(for: id)
            return
        }
        transmit(msg)
    }

    private func transmit(_ msg: CANTxMessage) {
        var data = msg.data
        if let gen = msg.signalGenerator, gen.waveform != .none {
            let elapsed = Date.now.timeIntervalSince(startTime)
            data = gen.apply(to: data, at: elapsed)
        }

        let frame = CANFrame(
            arbitrationID: msg.arbitrationID,
            isExtended: msg.isExtended,
            isRemote: msg.isRemote,
            dlc: UInt8(msg.isRemote ? max(data.count, 1) : data.count),
            data: msg.isRemote ? [] : data,
            direction: .sent,
            timestamp: Date()
        )
        slcanManager?.transmitFrame(frame)
    }

    private func saveMessages() {
        let data = (try? JSONEncoder().encode(messages)) ?? Data()
        UserDefaults.standard.set(data, forKey: "canTxMessages")
    }

    private func loadMessages() {
        guard let data = UserDefaults.standard.data(forKey: "canTxMessages") else { return }
        messages = (try? JSONDecoder().decode([CANTxMessage].self, from: data)) ?? []
    }

    nonisolated deinit {
        // Timer 在 MainActor 上失效，Runloop 会自动释放
    }
}
