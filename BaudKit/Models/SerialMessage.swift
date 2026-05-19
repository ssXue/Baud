import Foundation

public struct SerialMessage: Identifiable, Sendable {
    public let id = UUID()
    public let data: Data
    public let direction: Direction
    public let timestamp: Date

    public init(data: Data, direction: Direction, timestamp: Date) {
        self.data = data
        self.direction = direction
        self.timestamp = timestamp
    }

    public enum Direction: Sendable {
        case sent
        case received

        public var label: String {
            switch self {
            case .sent: "TX"
            case .received: "RX"
            }
        }

        public var systemImageName: String {
            switch self {
            case .sent: "arrow.up"
            case .received: "arrow.down"
            }
        }
    }

    public var hexString: String {
        data.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    public var asciiString: String {
        if let str = String(data: data, encoding: .utf8) {
            return String(str.map { ch in
                ch == "\n" ? "⏎" : (ch.asciiValue.map { $0 >= 0x20 && $0 < 0x7F } == true || ch.utf8.count > 1 ? ch : ".")
            })
        }
        return data.map { byte in
            byte >= 0x20 && byte < 0x7F ? String(UnicodeScalar(byte)) : "."
        }.joined()
    }
}
