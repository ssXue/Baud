import Foundation

@Observable
@MainActor
public final class SessionRecorder {
    public var isRecording = false
    public private(set) var recordedEvents: [RecordedEvent] = []
    public private(set) var recordingStartTime: Date?

    private var observer: NSObjectProtocol?

    public init() {}

    public func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        recordedEvents.removeAll()
        recordingStartTime = Date()

        observer = NotificationCenter.default.addObserver(forName: .serialDataReceived, object: nil, queue: .main) { notification in
            let text = notification.userInfo?["text"] as? String
            Task { @MainActor [weak self] in
                guard let self, self.isRecording, let text, let data = text.data(using: .utf8) else { return }
                let offset = Int64(Date().timeIntervalSince(self.recordingStartTime!) * 1000)
                self.recordedEvents.append(RecordedEvent(offsetMs: offset, direction: .received, data: data))
            }
        }
    }

    public func stopRecording() -> RecordedSession? {
        guard isRecording else { return nil }
        isRecording = false

        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
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
