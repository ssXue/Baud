import SwiftUI

public struct ProtocolConfigView: View {
    @AppStorage("baud.protocolDefinitions") private var storedDefinitions: Data = Data()
    @State private var definitions: [ProtocolDefinition] = []
    @State private var selectedID: UUID?
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Protocol Definitions")
                .font(.headline)

            HStack(spacing: 12) {
                List(definitions, selection: $selectedID) { def in
                    HStack {
                        Text(def.name)
                            .lineLimit(1)
                        Spacer()
                        if def.enabled {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                    }
                    .tag(def.id)
                }
                .frame(width: 160)

                if let idx = selectedIndex {
                    let definition = $definitions[idx]
                    Form {
                        Section("Basic") {
                            LabeledContent("Name") {
                                TextField("Protocol name", text: definition.name)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 160)
                            }
                            LabeledContent("Enabled") {
                                Toggle("", isOn: definition.enabled)
                            }
                        }

                        Section("Frame Header") {
                            LabeledContent("Header (hex)") {
                                TextField("e.g. AA 55", text: headerBinding(for: idx))
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(width: 120)
                            }
                        }

                        Section("Length") {
                            LabeledContent("Mode") {
                                Picker("", selection: definition.lengthFieldSize) {
                                    Text("Fixed Length").tag(0)
                                    Text("1 Byte").tag(1)
                                    Text("2 Bytes").tag(2)
                                }
                                .frame(width: 120)
                            }
                            if definitions[idx].lengthFieldSize > 0 {
                                LabeledContent("Length Offset") {
                                    Stepper(value: definition.lengthFieldOffset, in: 0...16) {
                                        TextField("", value: definition.lengthFieldOffset, format: .number)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 50)
                                    }
                                }
                                LabeledContent("Includes Header") {
                                    Toggle("", isOn: definition.lengthIncludesHeader)
                                }
                            } else {
                                LabeledContent("Frame Length") {
                                    Stepper(value: definition.fixedFrameLength, in: 2...256) {
                                        TextField("", value: definition.fixedFrameLength, format: .number)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 50)
                                    }
                                }
                            }
                        }

                        Section("Checksum") {
                            LabeledContent("Type") {
                                Picker("", selection: definition.checksumType) {
                                    ForEach(ChecksumType.allCases) { ct in
                                        Text(ct.displayName).tag(ct)
                                    }
                                }
                                .frame(width: 140)
                            }
                        }
                    }
                    .formStyle(.grouped)
                } else {
                    ContentUnavailableView(
                        "Select a Protocol",
                        systemImage: "gearshape",
                        description: Text("Select or add a protocol definition")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

        }
        .padding()
        .frame(minWidth: 600, minHeight: 420)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    addDefinition()
                } label: {
                    Label("Add", systemImage: "plus")
                }

                Button {
                    if let id = selectedID {
                        definitions.removeAll { $0.id == id }
                        selectedID = nil
                        saveDefinitions()
                    }
                } label: {
                    Label("Remove", systemImage: "minus")
                }
                .disabled(selectedID == nil)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .onAppear {
            loadDefinitions()
        }
        .onDisappear {
            saveDefinitions()
        }
    }

    private var selectedIndex: Int? {
        guard let id = selectedID else { return nil }
        return definitions.firstIndex(where: { $0.id == id })
    }

    private func headerBinding(for index: Int) -> Binding<String> {
        Binding<String>(
            get: {
                definitions[index].headerBytes.map { String(format: "%02X", $0) }.joined(separator: " ")
            },
            set: { newValue in
                definitions[index].headerBytes = HexFormatter.hexToData(newValue)?.map { $0 } ?? []
                saveDefinitions()
            }
        )
    }

    private func addDefinition() {
        let new = ProtocolDefinition()
        definitions.append(new)
        selectedID = new.id
        saveDefinitions()
    }

    private func saveDefinitions() {
        storedDefinitions = (try? JSONEncoder().encode(definitions)) ?? Data()
    }

    private func loadDefinitions() {
        definitions = (try? JSONDecoder().decode([ProtocolDefinition].self, from: storedDefinitions)) ?? []
    }
}
