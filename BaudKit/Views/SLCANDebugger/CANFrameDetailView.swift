import SwiftUI

public struct CANFrameDetailView: View {
    let frame: CANFrame

    public init(frame: CANFrame) {
        self.frame = frame
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

            }
        }
        .font(.system(.caption))
        .padding(8)
    }
}

private extension String {
    func leftPad(to length: Int) -> String {
        let padCount = max(0, length - count)
        return String(repeating: "0", count: padCount) + self
    }
}
