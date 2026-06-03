import SwiftUI

struct DBCImportView: View {
    @Environment(CANSignalStore.self) private var signalStore
    @State private var dbcFile: DBCFile?
    @State private var errorMessage: String?
    @State private var selectedMessageIDs = Set<UInt32>()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import DBC File")
                .font(.headline)

            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            if let dbc = dbcFile {
                Text("\(dbc.messages.count) messages, \(dbc.allSignals.count) signals found")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                List(dbc.messages, selection: $selectedMessageIDs) { msg in
                    HStack {
                        Text(String(format: "0x%X", msg.dbcID))
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 80, alignment: .leading)
                        Text(msg.name)
                            .frame(width: 150, alignment: .leading)
                        Text("\(msg.signals.count) signals")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Spacer()
                    }
                    .tag(msg.dbcID)
                }
            } else {
                ContentUnavailableView(
                    "No DBC File Loaded",
                    systemImage: "doc.text",
                    description: Text("Click Open to select a .dbc file")
                )
                .frame(maxHeight: .infinity)
            }

        }
        .padding()
        .frame(minWidth: 480, minHeight: 360)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    openFile()
                } label: {
                    Label("Open", systemImage: "folder")
                }
            }

            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            if dbcFile != nil {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        importSignals()
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedMessageIDs.isEmpty)
                }
            }
        }
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "dbc")].compactMap { $0 }
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            guard let parsed = DBCParser.parse(content) else {
                errorMessage = "Failed to parse DBC file"
                dbcFile = nil
                return
            }
            dbcFile = parsed
            errorMessage = nil
            selectedMessageIDs = []
        } catch {
            errorMessage = error.localizedDescription
            dbcFile = nil
        }
    }

    private func importSignals() {
        guard let dbc = dbcFile else { return }
        let filteredMessages: [DBCMessage]
        if selectedMessageIDs.isEmpty {
            filteredMessages = dbc.messages
        } else {
            filteredMessages = dbc.messages.filter { selectedMessageIDs.contains($0.dbcID) }
        }
        let filteredDBC = DBCFile(messages: filteredMessages)
        let signals = DBCParser.toCANSignals(filteredDBC)
        for signal in signals {
            signalStore.addSignal(signal)
        }
    }
}
