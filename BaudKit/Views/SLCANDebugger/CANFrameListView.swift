import SwiftUI

public struct CANFrameListView: View {
    @Environment(CANFrameStore.self) private var frameStore
    @State private var autoScroll = true
    @State private var scrollProxy: TableScrollProxy?

    public init() {}

    public var body: some View {
        @Bindable var frameStore = frameStore
        ZStack(alignment: .bottomTrailing) {
            Table(frameStore.filteredFrames, selection: $frameStore.selectedFrameID) {
                TableColumn("Time") { frame in
                    Text(TimestampFormatter.string(from: frame.timestamp))
                        .font(.system(.caption, design: .monospaced))
                }
                .width(88)

                TableColumn("Dir") { frame in
                    Text(frame.direction.label)
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundStyle(frame.direction == .sent ? .blue : .green)
                }
                .width(28)

                TableColumn("ID") { frame in
                    Text(frame.idHex)
                        .font(.system(.caption, design: .monospaced))
                }
                .width(min: 36, ideal: 56, max: 72)

                TableColumn("Type") { frame in
                    Text(frame.frameType)
                        .font(.system(.caption, design: .monospaced))
                }
                .width(30)

                TableColumn("DLC") { frame in
                    Text("\(frame.dlc)")
                        .font(.system(.caption, design: .monospaced))
                }
                .width(24)

                TableColumn("Data") { frame in
                    Text(frame.dataHex)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }


            }
        .tableStyle(.automatic)
        .background(TableScrollReader(proxy: $scrollProxy))
            .onScrollPhaseChange { oldPhase, newPhase in
                if newPhase == .interacting && oldPhase != .interacting {
                    autoScroll = false
                }
            }

            if !autoScroll {
                Button {
                    autoScroll = true
                    scrollToBottom()
                } label: {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(.body))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .help("Auto Scroll")
                .transition(.opacity)
                .padding(.trailing, 12)
                .padding(.bottom, 8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: autoScroll)
        .onAppear {
            scrollToBottomIfNeeded()
        }
        .onChange(of: frameStore.filteredFrames.last?.id) { _, _ in
            scrollToBottomIfNeeded()
        }
        .onChange(of: frameStore.filterText) { _, _ in
            scrollToBottomIfNeeded()
        }
    }

    private func scrollToBottomIfNeeded() {
        guard autoScroll else { return }
        scrollToBottom()
    }

    private func scrollToBottom() {
        scrollProxy?.scheduleScroll(to: .bottom)
    }
}
