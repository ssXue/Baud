import Foundation

@Observable
@MainActor
public final class SerialDataManager {
    private(set) public var messages: [SerialMessage] = []
    private(set) var receivedData = Data()
    private(set) public var protocolFrames: [ProtocolFrame] = []

    public var activeProtocol: ProtocolDefinition? {
        didSet {
            if let def = activeProtocol {
                protocolDecoder = ProtocolDecoder(definition: def)
            } else {
                protocolDecoder = nil
            }
        }
    }

    private var protocolDecoder: ProtocolDecoder?
    private let maxMessages = 10000
    private let maxProtocolFrames = 5000
    private let maxReceivedData = 1_000_000

    public init() {}

    public func appendReceived(data: Data) {
        receivedData.append(data)
        if receivedData.count > maxReceivedData {
            receivedData.removeFirst(receivedData.count - maxReceivedData)
        }
        let message = SerialMessage(data: data, direction: .received, timestamp: Date())
        appendMessage(message)
        if let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) {
            NotificationCenter.default.post(name: .serialDataReceived, object: self, userInfo: ["text": text])
        }

        if let decoder = protocolDecoder {
            let frames = decoder.feed(data)
            protocolFrames.append(contentsOf: frames)
            if protocolFrames.count > maxProtocolFrames {
                protocolFrames.removeFirst(protocolFrames.count - maxProtocolFrames)
            }
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

    public func clearProtocolFrames() {
        protocolFrames.removeAll()
    }

    private func appendMessage(_ message: SerialMessage) {
        messages.append(message)
        if messages.count > maxMessages {
            messages.removeFirst(messages.count - maxMessages)
        }
    }
}
