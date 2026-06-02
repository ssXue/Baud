import Foundation

enum SLCANCommand: Equatable, Sendable {
    // Channel control
    case openChannel
    case closeChannel

    // Bitrate
    case setBitrate(SLCANBitrate)
    case setBTR(btr0: UInt8, btr1: UInt8)

    // Transmit
    case transmitStandard(id: UInt32, data: [UInt8])
    case transmitExtended(id: UInt32, data: [UInt8])
    case transmitStandardRTR(id: UInt32, dlc: UInt8)
    case transmitExtendedRTR(id: UInt32, dlc: UInt8)

    // Filters
    case setAcceptanceCode(UInt32)
    case setAcceptanceMask(UInt32)

    // Info
    case getVersion
    case getSerialNumber
    case getStatusFlags

    // Timestamp
    case setTimestamp(Bool)

    var commandString: String {
        switch self {
        case .openChannel:
            return "O\r"
        case .closeChannel:
            return "C\r"
        case .setBitrate(let bitrate):
            return "S\(bitrate.rawValue)\r"
        case .setBTR(let btr0, let btr1):
            return String(format: "s%02X%02X\r", btr0, btr1)
        case .transmitStandard(let id, let data):
            let idStr = String(format: "%03X", id)
            let dataStr = data.map { String(format: "%02X", $0) }.joined()
            return "t\(idStr)\(data.count)\(dataStr)\r"
        case .transmitExtended(let id, let data):
            let idStr = String(format: "%08X", id)
            let dataStr = data.map { String(format: "%02X", $0) }.joined()
            return "T\(idStr)\(data.count)\(dataStr)\r"
        case .transmitStandardRTR(let id, let dlc):
            let idStr = String(format: "%03X", id)
            return "r\(idStr)\(dlc)\r"
        case .transmitExtendedRTR(let id, let dlc):
            let idStr = String(format: "%08X", id)
            return "R\(idStr)\(dlc)\r"
        case .setAcceptanceCode(let code):
            return String(format: "M%08X\r", code)
        case .setAcceptanceMask(let mask):
            return String(format: "m%08X\r", mask)
        case .getVersion:
            return "V\r"
        case .getSerialNumber:
            return "N\r"
        case .getStatusFlags:
            return "F\r"
        case .setTimestamp(let on):
            return on ? "Z1\r" : "Z0\r"
        }
    }
}

public enum SLCANBitrate: Int, CaseIterable, Identifiable, Sendable {
    case bps10k = 0
    case bps20k = 1
    case bps50k = 2
    case bps100k = 3
    case bps125k = 4
    case bps250k = 5
    case bps500k = 6
    case bps750k = 7
    case bps1M = 8

    public var id: Int { rawValue }

    public var display: String {
        switch self {
        case .bps10k: "10 kbps"
        case .bps20k: "20 kbps"
        case .bps50k: "50 kbps"
        case .bps100k: "100 kbps"
        case .bps125k: "125 kbps"
        case .bps250k: "250 kbps"
        case .bps500k: "500 kbps"
        case .bps750k: "750 kbps"
        case .bps1M: "1 Mbps"
        }
    }

    public var bps: Int {
        switch self {
        case .bps10k: 10_000
        case .bps20k: 20_000
        case .bps50k: 50_000
        case .bps100k: 100_000
        case .bps125k: 125_000
        case .bps250k: 250_000
        case .bps500k: 500_000
        case .bps750k: 750_000
        case .bps1M: 1_000_000
        }
    }
}

enum SLCANResponse: Equatable, Sendable {
    case receivedStandardFrame(id: UInt32, dlc: UInt8, data: [UInt8])
    case receivedExtendedFrame(id: UInt32, dlc: UInt8, data: [UInt8])
    case receivedStandardRTR(id: UInt32, dlc: UInt8)
    case receivedExtendedRTR(id: UInt32, dlc: UInt8)
    case statusFlags(UInt8)
    case version(hardware: String, software: String)
    case serialNumber(String)
    case ok
    case error
    case errorFrame(code: UInt8)
    case unknown(String)

    static func parse(_ line: String) -> SLCANResponse {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return .unknown(line) }

        switch first {
        case "t":
            return parseStandardFrame(trimmed)
        case "T":
            return parseExtendedFrame(trimmed)
        case "r":
            return parseStandardRTR(trimmed)
        case "R":
            return parseExtendedRTR(trimmed)
        case "F":
            if trimmed.count >= 3 {
                let hex = String(trimmed.dropFirst())
                if let flags = UInt8(hex, radix: 16) {
                    return .statusFlags(flags)
                }
            }
            return .unknown(line)
        case "V":
            if trimmed.count >= 5 {
                let payload = String(trimmed.dropFirst())
                let hw = String(payload.prefix(2))
                let sw = String(payload.dropFirst(2).prefix(2))
                return .version(hardware: hw, software: sw)
            }
            return .unknown(line)
        case "N":
            if trimmed.count > 1 {
                return .serialNumber(String(trimmed.dropFirst()))
            }
            return .unknown(line)
        case "e":
            let hex = String(trimmed.dropFirst())
            if let code = UInt8(hex, radix: 16) {
                return .errorFrame(code: code)
            }
            return .unknown(line)
        case "\u{07}":
            return .error
        case "\r":
            return .ok
        default:
            return .unknown(line)
        }
    }

    private static func parseStandardFrame(_ s: String) -> SLCANResponse {
        // tiiildd...
        let hex = String(s.dropFirst())
        guard hex.count >= 4 else { return .unknown(s) }
        let idStr = String(hex.prefix(3))
        let dlcStr = String(hex.dropFirst(3).prefix(1))
        guard let id = UInt32(idStr, radix: 16),
              let dlc = UInt8(dlcStr)
        else { return .unknown(s) }
        let dataHex = String(hex.dropFirst(4))
        let data = parseHexBytes(dataHex)
        return .receivedStandardFrame(id: id, dlc: dlc, data: data)
    }

    private static func parseExtendedFrame(_ s: String) -> SLCANResponse {
        // Tiiiiiiiildd...
        let hex = String(s.dropFirst())
        guard hex.count >= 9 else { return .unknown(s) }
        let idStr = String(hex.prefix(8))
        let dlcStr = String(hex.dropFirst(8).prefix(1))
        guard let id = UInt32(idStr, radix: 16),
              let dlc = UInt8(dlcStr)
        else { return .unknown(s) }
        let dataHex = String(hex.dropFirst(9))
        let data = parseHexBytes(dataHex)
        return .receivedExtendedFrame(id: id, dlc: dlc, data: data)
    }

    private static func parseStandardRTR(_ s: String) -> SLCANResponse {
        // riiil
        let hex = String(s.dropFirst())
        guard hex.count >= 4 else { return .unknown(s) }
        let idStr = String(hex.prefix(3))
        let dlcStr = String(hex.dropFirst(3).prefix(1))
        guard let id = UInt32(idStr, radix: 16),
              let dlc = UInt8(dlcStr)
        else { return .unknown(s) }
        return .receivedStandardRTR(id: id, dlc: dlc)
    }

    private static func parseExtendedRTR(_ s: String) -> SLCANResponse {
        // Riiiiiiiil
        let hex = String(s.dropFirst())
        guard hex.count >= 9 else { return .unknown(s) }
        let idStr = String(hex.prefix(8))
        let dlcStr = String(hex.dropFirst(8).prefix(1))
        guard let id = UInt32(idStr, radix: 16),
              let dlc = UInt8(dlcStr)
        else { return .unknown(s) }
        return .receivedExtendedRTR(id: id, dlc: dlc)
    }

    private static func parseHexBytes(_ hex: String) -> [UInt8] {
        var bytes: [UInt8] = []
        var remaining = hex
        while remaining.count >= 2 {
            let byteStr = String(remaining.prefix(2))
            if let byte = UInt8(byteStr, radix: 16) {
                bytes.append(byte)
            }
            remaining = String(remaining.dropFirst(2))
        }
        return bytes
    }
}
