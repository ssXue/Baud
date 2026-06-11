import SwiftUI

// MARK: - CAN Bus Load Badge

struct BusLoadBadge: View {
    let analyzer: CANBusAnalyzer

    private var loadColor: Color {
        let pct = analyzer.busLoadPercent
        if pct < 30 { return .green }
        if pct < 60 { return .yellow }
        if pct < 80 { return .orange }
        return .red
    }

    private var loadLabel: String {
        String(format: "Bus %.1f%%", analyzer.busLoadPercent)
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(loadColor)
                .frame(width: 8, height: 8)
            Text(loadLabel)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .help("CAN Bus Load (based on \(analyzer.busLoadBitrate) bps)")
    }
}

public struct StatusBadge: View {
    let connected: Bool

    public init(connected: Bool) {
        self.connected = connected
    }

    public var body: some View {
        Circle()
            .fill(connected ? Color.green : Color.secondary.opacity(0.4))
            .frame(width: 10, height: 10)
            .accessibilityLabel(connected ? String(localized: "Connected") : String(localized: "Disconnected"))
    }
}

#Preview("Connected") {
    StatusBadge(connected: true)
        .padding()
}

#Preview("Disconnected") {
    StatusBadge(connected: false)
        .padding()
}
