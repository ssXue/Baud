import SwiftUI

struct SerialStatsBar: View {
    @Environment(SerialDataManager.self) private var dataManager

    private var receivedRate: Double {
        dataManager.receivedBytesPerSecond
    }

    var body: some View {
        HStack(spacing: 12) {
            // RX
            HStack(spacing: 4) {
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
                Text("RX: \(formatBytes(dataManager.totalReceivedBytes))")
                Text("(\(formatRate(receivedRate)))")
                    .foregroundStyle(.secondary)
                Text("\(dataManager.totalReceivedMessages) msgs")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // TX
            HStack(spacing: 4) {
                Circle()
                    .fill(.blue)
                    .frame(width: 6, height: 6)
                Text("TX: \(formatBytes(dataManager.totalSentBytes))")
                Text("\(dataManager.totalSentMessages) msgs")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(.caption2, design: .monospaced))
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(.quaternary)
        .frame(height: 20)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024.0) }
        return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
    }

    private func formatRate(_ bytesPerSec: Double) -> String {
        if bytesPerSec < 1024 { return String(format: "%.1f B/s", bytesPerSec) }
        return String(format: "%.1f KB/s", bytesPerSec / 1024.0)
    }
}
