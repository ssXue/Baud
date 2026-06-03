import SwiftUI

public struct SerialConsoleView: View {
    @Environment(SerialDataManager.self) private var dataManager
    @Binding var displayMode: DisplayMode
    @Binding var autoScroll: Bool

    public init(displayMode: Binding<DisplayMode>, autoScroll: Binding<Bool>) {
        self._displayMode = displayMode
        self._autoScroll = autoScroll
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(dataManager.messages) { message in
                            MessageRow(message: message, displayMode: displayMode)
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
                        .fill(message.direction == .sent ? .blue : .green)
                )

            switch displayMode {
            case .hexAscii:
                Text(message.hexString)
                    .frame(minWidth: 200, alignment: .leading)
                Text(message.asciiString)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .hex:
                Text(message.hexString)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .ascii:
                Text(message.asciiString)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(message.direction == .sent
                    ? Color.blue.opacity(0.06)
                    : Color.green.opacity(0.06))
        )
        .textSelection(.enabled)
    }
}
