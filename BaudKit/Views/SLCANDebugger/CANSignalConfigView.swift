import SwiftUI

public struct CANSignalConfigView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CANSignalStore.self) private var signalStore

    @State private var name = ""
    @State private var arbitrationID = ""
    @State private var startBit = 0
    @State private var bitLength = 8
    @State private var byteOrder: CANSignal.ByteOrder = .littleEndian
    @State private var isSigned = false
    @State private var factor = 1.0
    @State private var offset = 0.0
    @State private var minDisplay = 0.0
    @State private var maxDisplay = 100.0
    @State private var valueTable: [Int: String] = [:]
    @State private var newRawValue = ""
    @State private var newLabel = ""
    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Text("Add Signal")
                .font(.headline)

            Form {
                Section("Signal") {
                    LabeledContent("Name") {
                        TextField("e.g. Engine RPM", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                    }
                    LabeledContent("CAN ID (hex)") {
                        TextField("e.g. 0C4", text: $arbitrationID)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 120)
                    }
                }

                Section("Bit Layout") {
                    LabeledContent("Start Bit") {
                        Stepper(value: $startBit, in: 0...63) {
                            TextField("", value: $startBit, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                        }
                    }
                    LabeledContent("Bit Length") {
                        Stepper(value: $bitLength, in: 1...64) {
                            TextField("", value: $bitLength, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                        }
                    }
                    LabeledContent("Byte Order") {
                        Picker("", selection: $byteOrder) {
                            ForEach(CANSignal.ByteOrder.allCases) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                        .frame(width: 200)
                    }
                    LabeledContent("Signed") {
                        Toggle("", isOn: $isSigned)
                    }
                }

                Section("Scaling") {
                    LabeledContent("Factor") {
                        TextField("", value: $factor, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    LabeledContent("Offset") {
                        TextField("", value: $offset, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    LabeledContent("Display Min") {
                        TextField("", value: $minDisplay, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    LabeledContent("Display Max") {
                        TextField("", value: $maxDisplay, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                }
            }
            .formStyle(.grouped)

            Section(String(localized: "Value Table")) {
                if valueTable.isEmpty {
                    Text("No mappings")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    List {
                        ForEach(valueTable.sorted { $0.key < $1.key }, id: \.key) { raw, label in
                            HStack {
                                Text("\(raw)")
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(width: 40, alignment: .leading)
                                Text("→")
                                    .foregroundStyle(.secondary)
                                Text(label)
                            }
                        }
                        .onDelete { indexSet in
                            let sorted = valueTable.sorted { $0.key < $1.key }
                            for index in indexSet {
                                valueTable.removeValue(forKey: sorted[index].key)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .frame(height: CGFloat(max(valueTable.count, 1)) * 24, alignment: .top)
                }

                HStack {
                    TextField(String(localized: "Raw Value"), text: $newRawValue)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    TextField(String(localized: "Label"), text: $newLabel)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        guard let raw = Int(newRawValue), !newLabel.isEmpty else { return }
                        valueTable[raw] = newLabel
                        newRawValue = ""
                        newLabel = ""
                    } label: {
                        Text("Add")
                    }
                    .disabled(Int(newRawValue) == nil || newLabel.isEmpty)
                }
            }
        }
        .frame(width: 480, height: 620)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    addSignal()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.glassProminent)
                .disabled(!isValid)
            }
        }
    }

    private var isValid: Bool {
        guard !name.isEmpty, !arbitrationName.isEmpty,
              let _ = UInt32(arbitrationID, radix: 16),
              bitLength > 0, startBit >= 0, startBit + bitLength <= 64
        else { return false }
        return true
    }

    private var arbitrationName: String { arbitrationID }

    private func addSignal() {
        guard let canID = UInt32(arbitrationID, radix: 16) else { return }
        let signal = CANSignal(
            name: name,
            arbitrationID: canID,
            startBit: startBit,
            bitLength: bitLength,
            byteOrder: byteOrder,
            signed: isSigned,
            factor: factor,
            offset: offset,
            minDisplay: minDisplay,
            maxDisplay: maxDisplay,
            valueTable: valueTable
        )
        signalStore.addSignal(signal)
        dismiss()
    }
}
