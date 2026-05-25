import Foundation

public struct DBCFile {
    public var messages: [DBCMessage]

    public var allSignals: [DBCSignal] {
        messages.flatMap(\.signals)
    }
}

public struct DBCMessage: Identifiable {
    public var id: UInt32 { dbcID }
    public let dbcID: UInt32
    public var name: String
    public var length: UInt8
    public var sender: String
    public var signals: [DBCSignal]
}

public struct DBCSignal {
    public var name: String
    public var startBit: Int
    public var bitLength: Int
    public var byteOrder: CANSignal.ByteOrder
    public var signed: Bool
    public var factor: Double
    public var offset: Double
    public var min: Double
    public var max: Double
    public var unit: String
}

public enum DBCParser {
    public static func parse(_ content: String) -> DBCFile? {
        var messages: [DBCMessage] = []
        var currentMessage: DBCMessage?

        for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("//") {
                continue
            }

            if trimmed.hasPrefix("BO_ ") {
                if let msg = currentMessage {
                    messages.append(msg)
                }
                currentMessage = parseMessageLine(trimmed)
            } else if trimmed.hasPrefix("SG_ "), let signal = parseSignalLine(trimmed) {
                currentMessage?.signals.append(signal)
            }
        }

        if let msg = currentMessage {
            messages.append(msg)
        }

        guard !messages.isEmpty else { return nil }
        return DBCFile(messages: messages)
    }

    public static func toCANSignals(_ dbc: DBCFile) -> [CANSignal] {
        dbc.messages.flatMap { msg in
            msg.signals.map { sig in
                CANSignal(
                    name: sig.name,
                    arbitrationID: msg.dbcID,
                    startBit: sig.startBit,
                    bitLength: sig.bitLength,
                    byteOrder: sig.byteOrder,
                    signed: sig.signed,
                    factor: sig.factor,
                    offset: sig.offset,
                    minDisplay: sig.min,
                    maxDisplay: sig.max
                )
            }
        }
    }

    private static func parseMessageLine(_ line: String) -> DBCMessage? {
        // BO_ <id> <name>: <length> <sender>
        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 5, parts[0] == "BO_" else { return nil }
        guard let id = UInt32(parts[1]) else { return nil }
        let nameWithColon = String(parts[2])
        let name = nameWithColon.hasSuffix(":") ? String(nameWithColon.dropLast()) : nameWithColon
        guard let length = UInt8(parts[3]) else { return nil }
        let sender = parts.count > 4 ? String(parts[4]) : ""
        return DBCMessage(dbcID: id, name: name, length: length, sender: sender, signals: [])
    }

    private static func parseSignalLine(_ line: String) -> DBCSignal? {
        // SG_ <name> [M|m<receiver>] : <startBit>|<bitLength>@<byteOrder><signed> (<factor>,<offset>) [<min>|<max>] "<unit>"
        guard line.hasPrefix("SG_ ") else { return nil }
        let trimmed = String(line.dropFirst(4))

        // Split by " : " to separate name from value spec
        guard let colonRange = trimmed.range(of: " : ") else { return nil }
        let namePart = String(trimmed[..<colonRange.lowerBound])
        let specPart = String(trimmed[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)

        // Name might have multiplexer indicator (M or mN), strip it
        let name = namePart.split(separator: " ").first.map(String.init) ?? namePart

        // Parse: <startBit>|<bitLength>@<byteOrder><signed> (<factor>,<offset>) [<min>|<max>] "<unit>"
        let specParts = specPart.split(separator: " ", omittingEmptySubsequences: true)
        guard specParts.count >= 4 else { return nil }

        // Part 0: startBit|bitLength@byteOrderSigned
        let bitSpec = String(specParts[0])
        guard let atIndex = bitSpec.firstIndex(of: "@"),
              let pipeIndex = bitSpec.firstIndex(of: "|") else { return nil }

        let startBitStr = String(bitSpec[..<pipeIndex])
        let bitLengthRange = bitSpec[bitSpec.index(after: pipeIndex)..<atIndex]
        let byteOrderSigned = String(bitSpec[bitSpec.index(after: atIndex)...])

        guard let startBit = Int(startBitStr),
              let bitLength = Int(bitLengthRange),
              byteOrderSigned.count == 2 else { return nil }

        let byteOrderChar = byteOrderSigned.first!
        let signedChar = byteOrderSigned.last!

        let byteOrder: CANSignal.ByteOrder = byteOrderChar == "0" ? .bigEndian : .littleEndian
        let signed = signedChar == "-"

        // Part 1: (factor,offset)
        let factorOffsetStr = String(specParts[1])
        let foContent = factorOffsetStr.trimmingCharacters(in: CharacterSet(charactersIn: "()"))
        let foParts = foContent.split(separator: ",", omittingEmptySubsequences: true)
        let factor = foParts.count > 0 ? Double(foParts[0]) ?? 1.0 : 1.0
        let offset = foParts.count > 1 ? Double(foParts[1]) ?? 0.0 : 0.0

        // Part 2: [min|max]
        let minMaxStr = String(specParts[2])
        let mmContent = minMaxStr.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        let mmParts = mmContent.split(separator: "|", omittingEmptySubsequences: true)
        let min = mmParts.count > 0 ? Double(mmParts[0]) ?? 0.0 : 0.0
        let max = mmParts.count > 1 ? Double(mmParts[1]) ?? 100.0 : 100.0

        // Part 3: "unit"
        let unitStr = specParts.count > 3 ? String(specParts[3]) : "\"\""
        let unit = unitStr.trimmingCharacters(in: CharacterSet(charactersIn: "\""))

        return DBCSignal(
            name: name,
            startBit: startBit,
            bitLength: bitLength,
            byteOrder: byteOrder,
            signed: signed,
            factor: factor,
            offset: offset,
            min: min,
            max: max,
            unit: unit
        )
    }
}
