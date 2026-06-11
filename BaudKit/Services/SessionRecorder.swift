import Foundation

@Observable
@MainActor
public final class SessionRecorder {
    public var isRecording = false
    public private(set) var recordedEvents: [RecordedEvent] = []
    public private(set) var recordingStartTime: Date?
    public private(set) var segmentIndex = 0
    public private(set) var autoSavedSessions: [RecordedSession] = []

    /// Maximum events per segment before auto-splitting (0 = unlimited)
    public var maxEventsPerSegment: Int = 5000
    /// Maximum duration in seconds before auto-splitting (0 = unlimited)
    public var maxDurationPerSegment: TimeInterval = 300 // 5 minutes

    private var serialObserver: NSObjectProtocol?
    private var canObserver: NSObjectProtocol?
    private weak var sessionManager: SessionManager?

    public init() {}

    public func configure(with sessionManager: SessionManager) {
        self.sessionManager = sessionManager
    }

    public func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        recordedEvents.removeAll()
        segmentIndex = 0
        autoSavedSessions.removeAll()
        recordingStartTime = Date()

        serialObserver = NotificationCenter.default.addObserver(forName: .serialDataReceived, object: nil, queue: .main) { [weak self] notification in
            let text = notification.userInfo?["text"] as? String
            Task { @MainActor [weak self] in
                guard let self, self.isRecording, let text, let data = text.data(using: .utf8) else { return }
                let offset = Int64(Date().timeIntervalSince(self.recordingStartTime!) * 1000)
                self.recordedEvents.append(RecordedEvent(offsetMs: offset, direction: .received, data: data))
                self.checkAutoSplit()
            }
        }

        canObserver = NotificationCenter.default.addObserver(forName: .canFrameReceived, object: nil, queue: .main) { [weak self] notification in
            let frame = notification.userInfo?["frame"] as? CANFrame
            Task { @MainActor [weak self] in
                guard let self, self.isRecording, let frame else { return }
                let offset = Int64(Date().timeIntervalSince(self.recordingStartTime!) * 1000)
                guard let encoded = try? JSONEncoder().encode(CodableCANFrame(frame)) else { return }
                self.recordedEvents.append(RecordedEvent(offsetMs: offset, direction: frame.direction == .sent ? .sent : .received, data: frame.dataHex.data(using: .utf8) ?? Data(), eventType: .can, canFrameData: encoded))
                self.checkAutoSplit()
            }
        }
    }

    public func stopRecording() -> RecordedSession? {
        guard isRecording else { return nil }
        isRecording = false

        if let serialObserver {
            NotificationCenter.default.removeObserver(serialObserver)
            self.serialObserver = nil
        }
        if let canObserver {
            NotificationCenter.default.removeObserver(canObserver)
            self.canObserver = nil
        }

        guard !recordedEvents.isEmpty else { return nil }

        let session = RecordedSession(
            name: "Session \(formatDate(Date()))",
            portName: "Serial",
            events: recordedEvents
        )
        recordedEvents.removeAll()
        recordingStartTime = nil

        // Also collect any auto-saved segments
        for autoSession in autoSavedSessions {
            sessionManager?.addSession(autoSession)
        }
        autoSavedSessions.removeAll()

        return session
    }

    private func checkAutoSplit() {
        let shouldSplitByCount = maxEventsPerSegment > 0 && recordedEvents.count >= maxEventsPerSegment
        let elapsed = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let shouldSplitByTime = maxDurationPerSegment > 0 && elapsed >= maxDurationPerSegment

        guard shouldSplitByCount || shouldSplitByTime else { return }

        let segment = RecordedSession(
            name: "Session \(formatDate(recordingStartTime!)) [\(segmentIndex + 1)]",
            portName: "Serial",
            events: recordedEvents
        )

        // Auto-save segment to SessionManager
        sessionManager?.addSession(segment)
        autoSavedSessions.append(segment)

        // Reset for next segment
        segmentIndex += 1
        recordedEvents.removeAll()
        recordingStartTime = Date()
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }
}

/// 用于序列化 CAN 帧到 RecordedEvent.canFrameData 的轻量类型
struct CodableCANFrame: Codable, Sendable {
    let arbitrationID: UInt32
    let isExtended: Bool
    let isRemote: Bool
    let dlc: UInt8
    let data: [UInt8]

    init(_ frame: CANFrame) {
        self.arbitrationID = frame.arbitrationID
        self.isExtended = frame.isExtended
        self.isRemote = frame.isRemote
        self.dlc = frame.dlc
        self.data = frame.data
    }

    func toCANFrame(direction: CANFrame.Direction, timestamp: Date) -> CANFrame {
        CANFrame(arbitrationID: arbitrationID, isExtended: isExtended, isRemote: isRemote, dlc: dlc, data: data, direction: direction, timestamp: timestamp)
    }
}
