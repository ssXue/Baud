import Foundation

@Observable
@MainActor
public final class SerialDataManager {
    private(set) public var messages: [SerialMessage] = []
    private(set) var receivedData = Data()

    private let maxMessages = 10000

    public init() {}

    public func appendReceived(data: Data) {
        receivedData.append(data)
        let message = SerialMessage(data: data, direction: .received, timestamp: Date())
        appendMessage(message)
        if let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) {
            NotificationCenter.default.post(name: .serialDataReceived, object: self, userInfo: ["text": text])
        }
    }

    public func appendSent(data: Data) {
        let message = SerialMessage(data: data, direction: .sent, timestamp: Date())
        appendMessage(message)
    }

    public func clear() {
        messages.removeAll()
        receivedData.removeAll(keepingCapacity: true)
    }

    private func appendMessage(_ message: SerialMessage) {
        messages.append(message)
        if messages.count > maxMessages {
            messages.removeFirst(messages.count - maxMessages)
        }
    }
}
