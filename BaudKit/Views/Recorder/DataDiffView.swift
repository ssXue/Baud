import SwiftUI

/// 数据差异比对视图：并排显示两个 session 的消息差异
public struct DataDiffView: View {
    @Environment(SessionManager.self) private var sessionManager

    @State private var leftSessionID: UUID?
    @State private var rightSessionID: UUID?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            sessionPickerRow
                .padding(12)

            Divider()

            if let leftSession, let rightSession {
                makeDiffContent(left: leftSession, right: rightSession)
            } else {
                Text("Select sessions to compare")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(minWidth: 640, minHeight: 400)
    }

    private var sessionPickerRow: some View {
        HStack(spacing: 24) {
            Picker(selection: $leftSessionID) {
                Text("None").tag(UUID?.none)
                ForEach(sessionManager.sessions) { s in
                    Text(s.name).tag(Optional(s.id))
                }
            } label: {
                Text("Left")
            }
            Picker(selection: $rightSessionID) {
                Text("None").tag(UUID?.none)
                ForEach(sessionManager.sessions) { s in
                    Text(s.name).tag(Optional(s.id))
                }
            } label: {
                Text("Right")
            }
        }
    }

    private var leftSession: RecordedSession? {
        guard let id = leftSessionID else { return nil }
        return sessionManager.sessions.first { $0.id == id }
    }

    private var rightSession: RecordedSession? {
        guard let id = rightSessionID else { return nil }
        return sessionManager.sessions.first { $0.id == id }
    }

    @ViewBuilder
    private func makeDiffContent(left: RecordedSession, right: RecordedSession) -> some View {
        let leftMsg = left.events.filter { $0.eventType == .serial }.map { $0.asSerialMessage }
        let rightMsg = right.events.filter { $0.eventType == .serial }.map { $0.asSerialMessage }
        let results = DataDiff.diff(left: leftMsg, right: rightMsg)
        let matchCount = results.filter { $0.type == .match }.count
        let mismatchCount = results.filter { $0.type == .mismatch }.count
        let leftOnly = results.filter { $0.type == .leftOnly }.count
        let rightOnly = results.filter { $0.type == .rightOnly }.count

        VStack(spacing: 0) {
            // 统计栏
            HStack(spacing: 16) {
                Text(verbatim: "✓ \(matchCount) Match").foregroundStyle(.green)
                Text(verbatim: "⚠ \(mismatchCount) Mismatch").foregroundStyle(.orange)
                Text(verbatim: "← \(leftOnly) Only Left").foregroundStyle(.red)
                Text(verbatim: "→ \(rightOnly) Only Right").foregroundStyle(.blue)
                Spacer()
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            if results.isEmpty {
                Text("No data")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(.tertiary)
            } else {
                Table(results) {
                    TableColumn("#") { row in
                        Text(verbatim: "\(row.index + 1)")
                            .monospaced()
                    }
                    .width(40)

                    TableColumn("Status") { row in
                        diffTypeIcon(row.type)
                    }
                    .width(80)

                    TableColumn("Left") { row in
                        makeEntryLabel(row.left)
                    }

                    TableColumn("Right") { row in
                        makeEntryLabel(row.right)
                    }
                }
                .tableStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private func diffTypeIcon(_ type: DataDiffResult.DiffType) -> some View {
        switch type {
        case .match:
            Label("Match", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .mismatch:
            Label("Mismatch", systemImage: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
        case .leftOnly:
            Label("Only Left", systemImage: "arrow.left.circle.fill")
                .foregroundStyle(.red)
        case .rightOnly:
            Label("Only Right", systemImage: "arrow.right.circle.fill")
                .foregroundStyle(.blue)
        }
    }

    @ViewBuilder
    private func makeEntryLabel(_ entry: DiffEntry?) -> some View {
        if let entry {
            HStack(spacing: 4) {
                Image(systemName: entry.direction.systemImageName)
                    .foregroundStyle(entry.direction == .sent ? .blue : .green)
                Text(verbatim: entry.data.hexString)
                    .monospaced()
                    .lineLimit(1)
            }
        } else {
            Text("—").foregroundStyle(.tertiary)
        }
    }
}

// MARK: - RecordedEvent → SerialMessage 转换

private extension RecordedEvent {
    var asSerialMessage: SerialMessage {
        let dir: SerialMessage.Direction = direction == .sent ? .sent : .received
        return SerialMessage(
            data: data,
            direction: dir,
            timestamp: Date(timeIntervalSince1970: Double(offsetMs) / 1000.0)
        )
    }
}

private extension Data {
    var hexString: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
