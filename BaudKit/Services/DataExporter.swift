import Foundation
import AppKit

public enum DataExporter {
    public enum ExportFormat: String, CaseIterable {
        case text = "txt"
        case csv = "csv"
        case json = "json"
    }

    public static func exportMessages(_ messages: [SerialMessage], format: ExportFormat) -> String {
        switch format {
        case .text:
            return messages.map { msg in
                let ts = TimestampFormatter.string(from: msg.timestamp)
                return "\(ts) \(msg.direction.label)  \(msg.hexString)  \(msg.asciiString)"
            }.joined(separator: "\n")
        case .csv:
            var lines = ["Timestamp,Direction,Hex,ASCII"]
            for msg in messages {
                let ts = ISO8601DateFormatter().string(from: msg.timestamp)
                let ascii = msg.asciiString.replacingOccurrences(of: "\"", with: "\"\"")
                lines.append("\(ts),\(msg.direction.label),\(msg.hexString),\"\(ascii)\"")
            }
            return lines.joined(separator: "\n")
        case .json:
            struct Entry: Encodable {
                let timestamp: String
                let direction: String
                let hex: String
                let ascii: String
            }
            let items = messages.map { Entry(
                timestamp: ISO8601DateFormatter().string(from: $0.timestamp),
                direction: $0.direction.label,
                hex: $0.hexString,
                ascii: $0.asciiString
            ) }
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = (try? encoder.encode(items)) ?? Data()
            return String(data: data, encoding: .utf8) ?? "[]"
        }
    }

    public static func exportCANFrames(_ frames: [CANFrame], format: ExportFormat) -> String {
        switch format {
        case .text:
            return frames.map { frame in
                let ts = TimestampFormatter.string(from: frame.timestamp)
                return "\(ts) \(frame.direction.label) \(frame.idHex) \(frame.frameType) DLC:\(frame.dlc) \(frame.dataHex)"
            }.joined(separator: "\n")
        case .csv:
            var lines = ["Timestamp,ID,Type,DLC,Data,Direction"]
            for frame in frames {
                let ts = ISO8601DateFormatter().string(from: frame.timestamp)
                lines.append("\(ts),\(frame.idHex),\(frame.frameType),\(frame.dlc),\(frame.dataHex),\(frame.direction.label)")
            }
            return lines.joined(separator: "\n")
        case .json:
            struct Entry: Encodable {
                let timestamp: String
                let id: String
                let type: String
                let dlc: Int
                let data: String
                let direction: String
            }
            let items = frames.map { Entry(
                timestamp: ISO8601DateFormatter().string(from: $0.timestamp),
                id: String(format: "0x%@", $0.idHex),
                type: $0.frameType,
                dlc: Int($0.dlc),
                data: $0.dataHex,
                direction: $0.direction.label
            ) }
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = (try? encoder.encode(items)) ?? Data()
            return String(data: data, encoding: .utf8) ?? "[]"
        }
    }

    public static func exportSession(_ session: RecordedSession, format: ExportFormat) -> String {
        switch format {
        case .text:
            return session.events.map { event in
                let dir = event.direction == .sent ? "TX" : "RX"
                let data = event.data.map { String(format: "%02X", $0) }.joined(separator: " ")
                return String(format: "%.3fs %@  %@", Double(event.offsetMs) / 1000.0, dir, data)
            }.joined(separator: "\n")
        case .csv:
            var lines = ["Offset(s),Direction,Hex,Length"]
            for event in session.events {
                let dir = event.direction == .sent ? "TX" : "RX"
                let hex = event.data.map { String(format: "%02X", $0) }.joined(separator: " ")
                lines.append(String(format: "%.3f,%@,%@,%d", Double(event.offsetMs) / 1000.0, dir, hex, event.data.count))
            }
            return lines.joined(separator: "\n")
        case .json:
            struct EventEntry: Encodable {
                let offset: String
                let direction: String
                let hex: String
                let length: Int
            }
            let items = session.events.map { event in
                EventEntry(
                    offset: String(format: "%.3f", Double(event.offsetMs) / 1000.0),
                    direction: event.direction == .sent ? "TX" : "RX",
                    hex: event.data.map { String(format: "%02X", $0) }.joined(separator: " "),
                    length: event.data.count
                )
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = (try? encoder.encode(items)) ?? Data()
            return String(data: data, encoding: .utf8) ?? "[]"
        }
    }

    @MainActor
    public static func exportWithFormatPicker(
        messages: [SerialMessage],
        defaultName: String
    ) -> Bool {
        guard !messages.isEmpty else { return false }
        let format = pickFormat()
        let content = exportMessages(messages, format: format)
        return saveToFileInternal(content, suggestedName: "\(defaultName).\(format.rawValue)")
    }

    @MainActor
    public static func exportWithFormatPicker(
        session: RecordedSession,
        defaultName: String
    ) -> Bool {
        guard !session.events.isEmpty else { return false }
        let format = pickFormat()
        let content = exportSession(session, format: format)
        return saveToFileInternal(content, suggestedName: "\(defaultName).\(format.rawValue)")
    }

    @MainActor
    public static func exportWithFormatPicker(
        frames: [CANFrame],
        defaultName: String
    ) -> Bool {
        guard !frames.isEmpty else { return false }
        let format = pickFormat()
        let content = exportCANFrames(frames, format: format)
        return saveToFileInternal(content, suggestedName: "\(defaultName).\(format.rawValue)")
    }

    @MainActor
    private static func pickFormat() -> ExportFormat {
        let alert = NSAlert()
        alert.messageText = "Export Format"
        alert.addButton(withTitle: "Plain Text")
        alert.addButton(withTitle: "CSV")
        alert.addButton(withTitle: "JSON")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn: return .text
        case .alertSecondButtonReturn: return .csv
        case .alertThirdButtonReturn: return .json
        default: return .csv
        }
    }

    @MainActor
    private static func saveToFileInternal(_ content: String, suggestedName: String) -> Bool {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }
}
