import SwiftUI

public struct SerialConsoleView: View {
    @Environment(SerialDataManager.self) private var dataManager
    @Binding var displayMode: DisplayMode
    @Binding var autoScroll: Bool
    @Binding var searchText: String

    public init(displayMode: Binding<DisplayMode>, autoScroll: Binding<Bool>, searchText: Binding<String>) {
        self._displayMode = displayMode
        self._autoScroll = autoScroll
        self._searchText = searchText
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(dataManager.messages) { message in
                            MessageRow(message: message, displayMode: displayMode, searchText: searchText)
                                .id(message.id)
                        }
                    }
                    .padding(8)
                }
                .font(.system(.body, design: .monospaced))
                .focusable(false)
                .scrollDismissesKeyboard(.never)
                .onScrollPhaseChange { oldPhase, newPhase in
                    if newPhase == .interacting && oldPhase != .interacting {
                        autoScroll = false
                    }
                }
                .onChange(of: dataManager.messages.count) { _, _ in
                    guard autoScroll, let last = dataManager.messages.last else { return }
                    proxy.scrollTo(last.id, anchor: .bottom)
                }

                VStack(alignment: .trailing, spacing: 8) {
                    if !autoScroll {
                        Button {
                            autoScroll = true
                            if let last = dataManager.messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        } label: {
                            Image(systemName: "arrow.down.to.line")
                                .font(.system(.body))
                                .foregroundStyle(.secondary)
                                .padding(8)
                                .background(.regularMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity)
                    }
                }
                .padding(.trailing, 12)
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Display Mode

public enum DisplayMode: String, CaseIterable, Identifiable {
    case hexAscii = "HEX+ASCII"
    case hex = "HEX"
    case ascii = "ASCII"

    public var id: String { rawValue }
}

// MARK: - Message Row

private struct MessageRow: View {
    let message: SerialMessage
    let displayMode: DisplayMode
    let searchText: String

    var body: some View {
        HStack(spacing: 8) {
            Text(TimestampFormatter.string(from: message.timestamp))
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)

            Text(message.direction.label)
                .fontWeight(.semibold)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(message.direction == .sent ? Color.accentColor : Color.teal)
                )

            switch displayMode {
            case .hexAscii:
                coloredHexView(message.data, minWidth: 200)
                if searchText.isEmpty {
                    Text(message.asciiString)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    highlightedText(message.asciiString, search: searchText, baseFont: .system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            case .hex:
                coloredHexView(message.data, minWidth: nil)
            case .ascii:
                if searchText.isEmpty {
                    Text(message.asciiString)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    highlightedText(message.asciiString, search: searchText, baseFont: .system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(message.direction == .sent
                    ? Color.accentColor.opacity(0.1)
                    : Color.teal.opacity(0.1))
        )
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func coloredHexView(_ data: Data, minWidth: Int?) -> some View {
        let bytes = Array(data.prefix(32))
        HStack(spacing: 2) {
            ForEach(Array(bytes.enumerated()), id: \.offset) { _, byte in
                Text(hexLabel(byte))
                    .foregroundStyle(byteColor(byte))
            }
        }
        .font(.system(.caption, design: .monospaced))
        .frame(
            minWidth: minWidth.map { CGFloat($0) },
            maxWidth: minWidth == nil ? .infinity : nil,
            alignment: .leading
        )
    }

    private func hexLabel(_ byte: UInt8) -> String {
        switch byte {
        case 0x00: return "NUL"
        case 0x09: return "TAB"
        case 0x0A: return "LF"
        case 0x0D: return "CR"
        case 0x01...0x1F:
            return "C-\(Character(UnicodeScalar(byte + 0x40)))"
        case 0x7F: return "DEL"
        default: return String(format: "%02X", byte)
        }
    }

    private func byteColor(_ byte: UInt8) -> Color {
        switch byte {
        case 0x00: .secondary
        case 0x09, 0x0A, 0x0D: .blue
        case 0x01...0x1F: .orange
        case 0x7F: .red
        case 0x80...0xFF: .purple
        default: .primary
        }
    }
}
