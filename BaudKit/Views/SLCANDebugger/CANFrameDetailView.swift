import SwiftUI

public struct CANFrameDetailView: View {
    @Environment(CANSignalStore.self) private var signalStore
    let frame: CANFrame

    public init(frame: CANFrame) {
        self.frame = frame
    }

    private var decodedSignals: [(signal: CANSignal, value: Double)] {
        signalStore.signals
            .filter { $0.enabled && $0.arbitrationID == frame.arbitrationID }
            .compactMap { signal in
                guard let value = signal.extractValue(from: frame.data) else { return nil }
                return (signal, value)
            }
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                LabeledContent("Arbitration ID") {
                    Text("0x\(frame.idHex)")
                        .font(.system(.caption, design: .monospaced))
                }
                LabeledContent("Type", value: frame.frameType)
                LabeledContent("Direction") {
                    Text(frame.direction.label)
                        .foregroundStyle(frame.direction == .sent ? .blue : .green)
                }
                LabeledContent("DLC", value: "\(frame.dlc)")
                LabeledContent("Timestamp") {
                    Text(TimestampFormatter.string(from: frame.timestamp))
                        .font(.system(.caption, design: .monospaced))
                }
            }

            Divider()
                .frame(maxHeight: 60)

            VStack(alignment: .leading, spacing: 4) {
                LabeledContent("Data (Hex)") {
                    Text(frame.dataHex)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }

                if !decodedSignals.isEmpty {
                    Divider()
                        .padding(.vertical, 2)

                    ForEach(decodedSignals, id: \.signal.id) { entry in
                        HStack(spacing: 8) {
                            Text(entry.signal.name)
                                .frame(width: 80, alignment: .leading)
                            Text(formatValue(entry.value))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .font(.system(.caption))
        .padding(8)
    }

    private func formatValue(_ value: Double) -> String {
        if value == floor(value) && abs(value) < 1_000_000 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.4f", value)
    }
}
