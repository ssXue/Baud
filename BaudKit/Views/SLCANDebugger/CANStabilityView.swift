import SwiftUI

public struct CANStabilityView: View {
    @Environment(CANBusAnalyzer.self) private var analyzer
    @Environment(SLCANManager.self) private var slcanManager
    @State private var searchText = ""

    public init() {}

    private var filteredStats: [CANIDStats] {
        let list = analyzer.statsList
        guard !searchText.isEmpty else { return list }
        let query = searchText.uppercased()
        return list.filter { String(format: "%03X", $0.arbitrationID).contains(query) }
    }

    public var body: some View {
        VStack(spacing: 0) {
            busLoadBar
            Divider()
            statsTable
        }
    }

    private var busLoadBar: some View {
        VStack(spacing: 4) {
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text("Bus Load")
                        .font(.system(.caption, design: .monospaced))
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.quaternary)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(busLoadColor)
                                .frame(width: geo.size.width * min(CGFloat(analyzer.busLoadPercent / 100.0), 1.0))
                            Text(String(format: "%.1f%%", analyzer.busLoadPercent))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(analyzer.busLoadPercent > 10 ? .white : .primary)
                                .padding(.leading, 4)
                        }
                    }
                    .frame(height: 16)
                }

                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(.caption2))
                    Text("\(analyzer.errorCount)")
                        .font(.system(.caption, design: .monospaced))
                }
                .foregroundStyle(analyzer.errorCount > 0 ? .red : .secondary)

                Spacer()

                @Bindable var slcanManager = slcanManager
                HStack(spacing: 4) {
                    Text("Bitrate:")
                        .font(.system(.caption2))
                        .foregroundStyle(.secondary)
                    Picker("", selection: $slcanManager.selectedBitrate) {
                        ForEach(SLCANBitrate.allCases) { bitrate in
                            Text(bitrate.display).tag(bitrate)
                        }
                    }
                    .frame(width: 100)
                    .labelsHidden()
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }

    private var busLoadColor: Color {
        let load = analyzer.busLoadPercent
        if load < 30 { return .green }
        if load < 60 { return .orange }
        return .red
    }

    private var statsTable: some View {
        Table(filteredStats) {
            TableColumn("ID") { stats in
                Text(stats.idHex)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.semibold)
            }
            .width(min: 36, ideal: 56, max: 72)

            TableColumn("Count") { stats in
                Text("\(stats.frameCount)")
                    .font(.system(.caption, design: .monospaced))
            }
            .width(48)

            TableColumn("Period") { stats in
                Text(formatInterval(stats.detectedPeriod))
                    .font(.system(.caption, design: .monospaced))
            }
            .width(56)

            TableColumn("Min") { stats in
                Text(formatInterval(stats.minInterval))
                    .font(.system(.caption, design: .monospaced))
            }
            .width(56)

            TableColumn("Max") { stats in
                Text(formatInterval(stats.maxInterval))
                    .font(.system(.caption, design: .monospaced))
            }
            .width(56)

            TableColumn("Jitter") { stats in
                Text(formatInterval(stats.jitter))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(jitterColor(stats))
            }
            .width(56)

            TableColumn("Stability") { stats in
                stabilityBadge(stats.stabilityStatus)
            }
            .width(56)

            TableColumn("Timeout") { stats in
                timeoutBadge(stats.timeoutStatus)
            }
            .width(56)
        }
        .tableStyle(.automatic)
        .searchable(text: $searchText, prompt: "Filter by ID")
    }

    private func formatInterval(_ interval: TimeInterval?) -> String {
        guard let interval else { return "—" }
        if interval < 1.0 {
            return String(format: "%.1fms", interval * 1000)
        }
        return String(format: "%.2fs", interval)
    }

    private func jitterColor(_ stats: CANIDStats) -> Color {
        switch stats.stabilityStatus {
        case .stable: return .green
        case .warning: return .orange
        case .unstable: return .red
        case .unknown: return .secondary
        }
    }

    private func stabilityBadge(_ status: StabilityStatus) -> some View {
        let color: Color = switch status {
        case .stable: .green
        case .warning: .orange
        case .unstable: .red
        case .unknown: .secondary
        }
        return Text(status.rawValue)
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(color)
    }

    private func timeoutBadge(_ status: TimeoutStatus) -> some View {
        let color: Color = switch status {
        case .ok: .green
        case .warning: .orange
        case .timeout, .lost: .red
        case .unknown: .secondary
        }
        return HStack(spacing: 2) {
            if status == .timeout || status == .lost {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(.caption2))
            }
            Text(status.rawValue)
                .font(.system(.caption2, design: .monospaced))
        }
        .foregroundStyle(color)
    }
}
