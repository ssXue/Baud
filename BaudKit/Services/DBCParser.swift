import Foundation

public struct DBCFile {
    public var messages: [DBCMessage]
    public var valueTables: [String: [Int: String]]       // table name → raw values
    public var signalValues: [SignalValueKey: [Int: String]] // (msgID, signalName) → values
    public var cycleTimes: [UInt32: Int]                  // msgID → cycle time ms

    public var allSignals: [DBCSignal] {
        messages.flatMap(\.signals)
    }

    public struct SignalValueKey: Hashable {
        public let messageID: UInt32
        public let signalName: String
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
    /// Multiplexer mode: nil = normal, "M" = multiplexor, "mN" = multiplexed (switch value N)
    public var multiplexMode: String?
}

public enum DBCParser {
    public static func parse(_ content: String) -> DBCFile? {
        var messages: [DBCMessage] = []
        var currentMessage: DBCMessage?
        var valueTables: [String: [Int: String]] = [:]
        var signalValues: [DBCFile.SignalValueKey: [Int: String]] = [:]
        var cycleTimes: [UInt32: Int] = [:]

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
            } else if trimmed.hasPrefix("VAL_TABLE_ ") {
                if let (name, table) = parseValTableLine(trimmed) {
                    valueTables[name] = table
                }
            } else if trimmed.hasPrefix("VAL_ ") {
                if let (key, values) = parseValLine(trimmed) {
                    signalValues[key] = values
                }
            } else if trimmed.hasPrefix("BA_ ") && trimmed.contains("GenMsgCycleTime") {
                if let (msgID, cycleTime) = parseCycleTimeLine(trimmed) {
                    cycleTimes[msgID] = cycleTime
                }
            }
        }

        if let msg = currentMessage {
            messages.append(msg)
        }

        guard !messages.isEmpty else { return nil }
        return DBCFile(
            messages: messages,
            valueTables: valueTables,
            signalValues: signalValues,
            cycleTimes: cycleTimes
        )
    }

    public static func toCANSignals(_ dbc: DBCFile) -> [CANSignal] {
        dbc.messages.flatMap { msg in
            msg.signals.map { sig in
                let key = DBCFile.SignalValueKey(messageID: msg.dbcID, signalName: sig.name)
                let valueTable = dbc.signalValues[key] ?? [:]
                return CANSignal(
                    name: sig.name,
                    arbitrationID: msg.dbcID,
                    startBit: sig.startBit,
                    bitLength: sig.bitLength,
                    byteOrder: sig.byteOrder,
                    signed: sig.signed,
                    factor: sig.factor,
                    offset: sig.offset,
                    minDisplay: sig.min,
                    maxDisplay: sig.max,
                    valueTable: valueTable
                )
            }
        }
    }

    // MARK: - Message Parsing

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

    // MARK: - Signal Parsing

    private static func parseSignalLine(_ line: String) -> DBCSignal? {
        // SG_ <name> [M|mN] : <startBit>|<bitLength>@<byteOrder><signed> (<factor>,<offset>) [<min>|<max>] "<unit>"
        guard line.hasPrefix("SG_ ") else { return nil }
        let trimmed = String(line.dropFirst(4))

        // Split by " : " to separate name from value spec
        guard let colonRange = trimmed.range(of: " : ") else { return nil }
        let namePart = String(trimmed[..<colonRange.lowerBound])
        let specPart = String(trimmed[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)

        // Parse name and optional multiplexer indicator (M or mN)
        let nameTokens = namePart.split(separator: " ", omittingEmptySubsequences: true)
        let name = String(nameTokens.first ?? "")
        var multiplexMode: String? = nil
        if nameTokens.count > 1 {
            let mode = String(nameTokens[1])
            if mode == "M" || mode.hasPrefix("m") {
                multiplexMode = mode
            }
        }

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
            unit: unit,
            multiplexMode: multiplexMode
        )
    }

    // MARK: - VAL_TABLE_ Parsing
    // VAL_TABLE_ <name> <value1> "label1" <value2> "label2" ;

    private static func parseValTableLine(_ line: String) -> (String, [Int: String])? {
        // VAL_TABLE_ <name> <val> "label" ... ;
        let content = String(line.dropFirst("VAL_TABLE_ ".count))
        var parts = content.split(separator: " ", omittingEmptySubsequences: true)
        guard !parts.isEmpty else { return nil }

        // Remove trailing semicolon
        if let last = parts.last, last.hasSuffix(";") {
            if last == ";" {
                parts.removeLast()
            } else {
                parts[parts.count - 1] = last.dropLast()
            }
        }

        let name = String(parts[0])
        var table: [Int: String] = [:]

        var i = 1
        while i + 1 < parts.count {
            if let val = Int(parts[i]) {
                let label = String(parts[i + 1]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                table[val] = label
                i += 2
            } else {
                i += 1
            }
        }

        guard !table.isEmpty else { return nil }
        return (name, table)
    }

    // MARK: - VAL_ Parsing
    // VAL_ <msgID> <signalName> <val> "label" ... ;

    private static func parseValLine(_ line: String) -> (DBCFile.SignalValueKey, [Int: String])? {
        let content = String(line.dropFirst("VAL_ ".count))
        var parts = content.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 4 else { return nil }

        guard let msgID = UInt32(parts[0]) else { return nil }
        let signalName = String(parts[1])

        // Remove trailing semicolon
        if let last = parts.last, last.hasSuffix(";") {
            if last == ";" {
                parts.removeLast()
            } else {
                parts[parts.count - 1] = last.dropLast()
            }
        }

        var table: [Int: String] = [:]
        var i = 2
        while i + 1 < parts.count {
            if let val = Int(parts[i]) {
                let label = String(parts[i + 1]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                table[val] = label
                i += 2
            } else {
                i += 1
            }
        }

        guard !table.isEmpty else { return nil }
        return (DBCFile.SignalValueKey(messageID: msgID, signalName: signalName), table)
    }

    // MARK: - BA_ Cycle Time Parsing
    // BA_ "GenMsgCycleTime" BO_ <msgID> <value>;

    private static func parseCycleTimeLine(_ line: String) -> (UInt32, Int)? {
        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 5,
              parts[0] == "BA_",
              parts[1].hasPrefix("\"GenMsgCycleTime\"") || parts[1] == "\"GenMsgCycleTime\"",
              parts[2] == "BO_",
              let msgID = UInt32(parts[3]) else { return nil }

        let valueStr = parts[4].trimmingCharacters(in: CharacterSet(charactersIn: ";"))
        guard let value = Int(valueStr) else { return nil }
        return (msgID, value)
    }
}
