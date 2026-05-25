import Foundation

public struct ProtocolDefinition: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var enabled: Bool
    public var headerBytes: [UInt8]
    public var lengthFieldOffset: Int
    public var lengthFieldSize: Int
    public var lengthIncludesHeader: Bool
    public var fixedFrameLength: Int
    public var checksumType: ChecksumType

    public init(
        id: UUID = UUID(),
        name: String = "New Protocol",
        enabled: Bool = true,
        headerBytes: [UInt8] = [0xAA, 0x55],
        lengthFieldOffset: Int = 0,
        lengthFieldSize: Int = 1,
        lengthIncludesHeader: Bool = false,
        fixedFrameLength: Int = 10,
        checksumType: ChecksumType = .none
    ) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.headerBytes = headerBytes
        self.lengthFieldOffset = lengthFieldOffset
        self.lengthFieldSize = lengthFieldSize
        self.lengthIncludesHeader = lengthIncludesHeader
        self.fixedFrameLength = fixedFrameLength
        self.checksumType = checksumType
    }

    public var usesFixedLength: Bool { lengthFieldSize == 0 }
}

public enum ChecksumType: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case xor
    case sum
    case crc8
    case crc16

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .none: "None"
        case .xor: "XOR"
        case .sum: "Sum (mod 256)"
        case .crc8: "CRC-8"
        case .crc16: "CRC-16"
        }
    }

    public var checksumSize: Int {
        switch self {
        case .none: 0
        case .xor, .sum, .crc8: 1
        case .crc16: 2
        }
    }
}

public struct ProtocolFrame: Identifiable, Sendable {
    public let id: UUID
    public let payload: Data
    public let rawFrame: Data
    public let timestamp: Date
    public let checksumValid: Bool

    public init(payload: Data, rawFrame: Data, timestamp: Date, checksumValid: Bool) {
        self.id = UUID()
        self.payload = payload
        self.rawFrame = rawFrame
        self.timestamp = timestamp
        self.checksumValid = checksumValid
    }

    public var payloadHex: String {
        payload.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
