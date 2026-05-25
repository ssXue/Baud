import SwiftUI

struct ProtocolFramesView: View {
    @Environment(SerialDataManager.self) private var dataManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Decoded Frames")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(dataManager.protocolFrames.count) frames")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Button {
                    dataManager.clearProtocolFrames()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            if dataManager.protocolFrames.isEmpty {
                Text("Waiting for protocol frames...")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let recentFrames = Array(dataManager.protocolFrames.suffix(500))
                Table(of: ProtocolFrame.self, selection: .constant(Set<UUID>())) {
                    TableColumn("Time") { (f: ProtocolFrame) in
                        Text(TimestampFormatter.string(from: f.timestamp))
                            .font(.system(.caption, design: .monospaced))
                    }
                    .width(min: 80, ideal: 90)

                    TableColumn("Payload") { (f: ProtocolFrame) in
                        Text(f.payloadHex)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }

                    TableColumn("Status") { (f: ProtocolFrame) in
                        Image(systemName: f.checksumValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(f.checksumValid ? .green : .red)
                            .font(.caption)
                    }
                    .width(min: 50, ideal: 50)
                } rows: {
                    ForEach(recentFrames) { frame in
                        TableRow(frame)
                    }
                }
                .tableStyle(.automatic)
            }
        }
    }
}
