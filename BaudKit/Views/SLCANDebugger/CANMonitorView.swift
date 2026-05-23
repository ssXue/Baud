import SwiftUI

public struct CANMonitorView: View {
    @Environment(CANFrameStore.self) private var frameStore
    @State private var selectedID: UUID?
    @State private var autoScroll = true
    @State private var scrollProxy: TableScrollProxy?

    public init() {}

    public var body: some View {
        @Bindable var frameStore = frameStore
        ZStack(alignment: .topTrailing) {
            Table(frameStore.monitorFrameList, selection: $selectedID) {
                TableColumn("ID") { frame in
                    Text(frame.idHex)
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.semibold)
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

                TableColumn("Time") { frame in
                    Text(TimestampFormatter.string(from: frame.timestamp))
                        .font(.system(.caption, design: .monospaced))
                }
                .width(88)
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
                    scrollToTop()
                } label: {
                    Image(systemName: "arrow.up.to.line")
                        .font(.system(.body))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .help("Auto Scroll")
                .transition(.opacity)
                .padding(.trailing, 12)
                .padding(.top, 8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: autoScroll)
        .onAppear {
            scrollToTopIfNeeded()
        }
        .onChange(of: frameStore.monitorFrameList.first?.id) { _, _ in
            scrollToTopIfNeeded()
        }
        .onChange(of: frameStore.filterText) { _, _ in
            scrollToTopIfNeeded()
        }
        .onChange(of: selectedID) { _, newID in
            if let newID {
                if let frame = frameStore.monitorFrameList.first(where: { $0.id == newID }) {
                    frameStore.selectedFrameID = frame.id
                }
            } else {
                frameStore.selectedFrameID = nil
            }
        }
    }

    private func scrollToTopIfNeeded() {
        guard autoScroll else { return }
        scrollToTop()
    }

    private func scrollToTop() {
        scrollProxy?.scheduleScroll(to: .top)
    }
}
