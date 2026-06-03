import SwiftUI

public struct CANMonitorView: View {
    @Environment(CANFrameStore.self) private var frameStore
    @Environment(CANSignalStore.self) private var signalStore
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
                    MonitoredFrameDataCell(frame: frame, signals: signalStore.signals)
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
                        .background(.regularMaterial, in: Circle())
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

private struct MonitoredFrameDataCell: View {
    let frame: CANFrame
    let signals: [CANSignal]

    private var matchedSignals: [CANSignal] {
        signals.filter { $0.enabled && $0.arbitrationID == frame.arbitrationID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(frame.dataHex)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
            ForEach(matchedSignals, id: \.id) { signal in
                SignalDecodeRow(signal: signal, data: frame.data)
            }
        }
    }
}

private struct SignalDecodeRow: View {
    let signal: CANSignal
    let data: [UInt8]

    var body: some View {
        if let value = signal.extractValue(from: data) {
            let text = signal.name + ": " + signal.displayValue(raw: value)
            Text(text)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.blue)
        }
    }
}
