import Foundation

@Observable
@MainActor
public final class SerialDataManager {
    private(set) public var messages: [SerialMessage] = []
    private(set) var receivedData = Data()
    private(set) public var protocolFrames: [ProtocolFrame] = []
    public private(set) var totalReceivedBytes: Int64 = 0
    public private(set) var totalSentBytes: Int64 = 0
    public private(set) var totalReceivedMessages: Int64 = 0
    public private(set) var totalSentMessages: Int64 = 0
    private var recentReceivedBytes: [(time: Date, bytes: Int)] = []

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

        totalReceivedBytes += Int64(data.count)
        totalReceivedMessages += 1
        let now = Date()
        recentReceivedBytes.append((now, data.count))
        recentReceivedBytes = recentReceivedBytes.filter { now.timeIntervalSince($0.time) < 3.0 }

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
        totalSentBytes += Int64(data.count)
        totalSentMessages += 1
    }

    public func clear() {
        messages.removeAll()
        receivedData.removeAll(keepingCapacity: true)
        totalReceivedBytes = 0
        totalSentBytes = 0
        totalReceivedMessages = 0
        totalSentMessages = 0
        recentReceivedBytes.removeAll()
    }

    public func clearProtocolFrames() {
        protocolFrames.removeAll()
    }


    public var receivedBytesPerSecond: Double {
        let now = Date()
        let recent = recentReceivedBytes.filter { now.timeIntervalSince($0.time) < 3.0 }
        let totalBytes = recent.reduce(0) { $0 + $1.bytes }
        guard let oldest = recent.first?.time else { return 0 }
        let duration = now.timeIntervalSince(oldest)
        guard duration > 0 else { return 0 }
        return Double(totalBytes) / duration
    }
    private func appendMessage(_ message: SerialMessage) {
        messages.append(message)
        if messages.count > maxMessages {
            messages.removeFirst(messages.count - maxMessages)
        }
    }
}
