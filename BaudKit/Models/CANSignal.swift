import Foundation

public struct CANSignal: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var arbitrationID: UInt32
    public var startBit: Int
    public var bitLength: Int
    public var byteOrder: ByteOrder
    public var signed: Bool
    public var factor: Double
    public var offset: Double
    public var minDisplay: Double
    public var maxDisplay: Double
    public var enabled: Bool
    public var valueTable: [Int: String]

    public enum ByteOrder: String, Codable, CaseIterable, Identifiable, Sendable {
        case bigEndian = "Big Endian (Motorola)"
        case littleEndian = "Little Endian (Intel)"

        public var id: String { rawValue }
    }

    public init(
        id: UUID = UUID(),
        name: String,
        arbitrationID: UInt32,
        startBit: Int = 0,
        bitLength: Int = 8,
        byteOrder: ByteOrder = .littleEndian,
        signed: Bool = false,
        factor: Double = 1.0,
        offset: Double = 0.0,
        minDisplay: Double = 0.0,
        maxDisplay: Double = 100.0,
        enabled: Bool = true,
        valueTable: [Int: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.arbitrationID = arbitrationID
        self.startBit = startBit
        self.bitLength = bitLength
        self.byteOrder = byteOrder
        self.signed = signed
        self.factor = factor
        self.offset = offset
        self.minDisplay = minDisplay
        self.maxDisplay = maxDisplay
        self.enabled = enabled
        self.valueTable = valueTable
    }

    public func extractValue(from data: [UInt8]) -> Double? {
        guard bitLength > 0, bitLength <= 64 else { return nil }

        let totalBits = data.count * 8
        guard startBit + bitLength <= totalBits else { return nil }

        var raw: UInt64 = 0
        switch byteOrder {
        case .littleEndian:
            for i in 0..<bitLength {
                let bitIndex = startBit + i
                let byteIndex = bitIndex / 8
                let bitOffset = bitIndex % 8
                if data[byteIndex] & (1 << bitOffset) != 0 {
                    raw |= (1 as UInt64) << i
                }
            }
        case .bigEndian:
            for i in 0..<bitLength {
                let bitIndex = startBit + i
                let byteIndex = bitIndex / 8
                let bitOffset = 7 - (bitIndex % 8)
                if data[byteIndex] & (1 << bitOffset) != 0 {
                    raw |= (1 as UInt64) << (bitLength - 1 - i)
                }
            }
        }

        if signed && bitLength < 64 {
            let signBit: UInt64 = 1 << (bitLength - 1)
            if raw & signBit != 0 {
                raw |= ~(((1 as UInt64) << bitLength) - 1)
                let signedVal = Int64(bitPattern: raw)
                return Double(signedVal) * factor + offset
            }
        }

        return Double(raw) * factor + offset
    }

    public func displayValue(raw: Double) -> String {
        let intVal = Int(raw)
        if let label = valueTable[intVal] {
            return "\(label) (\(intVal))"
        }
        if raw == floor(raw) && abs(raw) < 1_000_000 {
            return String(format: "%.0f", raw)
        }
        return String(format: "%.4f", raw)
    }
}
