import Foundation

@Observable
@MainActor
public final class SessionRecorder {
    public var isRecording = false
    public private(set) var recordedEvents: [RecordedEvent] = []
    public private(set) var recordingStartTime: Date?

    private var serialObserver: NSObjectProtocol?
    private var canObserver: NSObjectProtocol?

    public init() {}

    public func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        recordedEvents.removeAll()
        recordingStartTime = Date()

        serialObserver = NotificationCenter.default.addObserver(forName: .serialDataReceived, object: nil, queue: .main) { [weak self] notification in
            let text = notification.userInfo?["text"] as? String
            Task { @MainActor [weak self] in
                guard let self, self.isRecording, let text, let data = text.data(using: .utf8) else { return }
                let offset = Int64(Date().timeIntervalSince(self.recordingStartTime!) * 1000)
                self.recordedEvents.append(RecordedEvent(offsetMs: offset, direction: .received, data: data))
            }
        }

        canObserver = NotificationCenter.default.addObserver(forName: .slcanFrameReceived, object: nil, queue: .main) { [weak self] notification in
            let frame = notification.userInfo?["frame"] as? CANFrame
            Task { @MainActor [weak self] in
                guard let self, self.isRecording, let frame else { return }
                let offset = Int64(Date().timeIntervalSince(self.recordingStartTime!) * 1000)
                guard let encoded = try? JSONEncoder().encode(CodableCANFrame(frame)) else { return }
                self.recordedEvents.append(RecordedEvent(offsetMs: offset, direction: frame.direction == .sent ? .sent : .received, data: frame.dataHex.data(using: .utf8) ?? Data(), eventType: .can, canFrameData: encoded))
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
        return session
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
