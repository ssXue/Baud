import Foundation

public struct CANFrame: Identifiable, Sendable {
    public let id: UUID
    public let arbitrationID: UInt32
    public let isExtended: Bool
    public let isRemote: Bool
    public let dlc: UInt8
    public let data: [UInt8]
    public let direction: Direction
    public let timestamp: Date

    public init(arbitrationID: UInt32, isExtended: Bool, isRemote: Bool, dlc: UInt8, data: [UInt8], direction: Direction, timestamp: Date) {
        self.id = UUID()
        self.arbitrationID = arbitrationID
        self.isExtended = isExtended
        self.isRemote = isRemote
        self.dlc = dlc
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
    }

    public var idHex: String {
        if isExtended {
            return String(format: "%08X", arbitrationID)
        }
        return String(format: "%03X", arbitrationID)
    }

    public var dataHex: String {
        data.prefix(Int(dlc)).map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    public var dataASCII: String {
        let bytes = data.prefix(Int(dlc))
        return String(bytes.map { byte in
            byte >= 0x20 && byte < 0x7F ? Character(UnicodeScalar(byte)) : "."
        })
    }

    public var frameType: String {
        if isRemote { return "RTR" }
        return isExtended ? "EXT" : "STD"
    }
}
