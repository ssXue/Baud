import SwiftUI

public struct CANSendView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CANTxStore.self) private var txStore
    @Environment(CANBackendManager.self) private var backendManager

    @State private var editingMessage: CANTxMessage?
    @State private var showEditor = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if txStore.messages.isEmpty {
                emptyState
            } else {
                messageTable
            }
        }
        .frame(minWidth: 700, minHeight: 360)
        .sheet(isPresented: $showEditor) {
            if let msg = editingMessage {
                CANTxMessageEditor(message: msg) { saved in
                    if let idx = txStore.messages.firstIndex(where: { $0.id == saved.id }) {
                        txStore.updateMessage(saved)
                    } else {
                        txStore.addMessage(saved)
                    }
                    editingMessage = nil
                    showEditor = false
                }
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button {
                editingMessage = CANTxMessage()
                showEditor = true
            } label: {
                Label("Add Message", systemImage: "plus")
            }

            Button {
                if let last = txStore.messages.last {
                    txStore.removeMessage(id: last.id)
                }
            } label: {
                Label("Remove Last", systemImage: "minus")
            }
            .disabled(txStore.messages.isEmpty)

            Spacer()

            Button {
                for msg in txStore.messages {
                    txStore.sendOnce(id: msg.id)
                }
            } label: {
                Label("Send All", systemImage: "paperplane")
            }
            .disabled(txStore.messages.isEmpty || !backendManager.isChannelOpen)

            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(12)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "paperplane")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No messages configured")
                .font(.headline)
            Text("Click + to add a CAN message")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var messageTable: some View {
        Table(of: CANTxMessage.self) {
            TableColumn("Enabled") { msg in
                Toggle("", isOn: Binding(
                    get: { msg.isEnabled },
                    set: { _ in txStore.toggleEnabled(id: msg.id) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }
            .width(60)

            TableColumn("ID") { msg in
                Text(msg.idHex)
                    .font(.system(.body, design: .monospaced))
            }
            .width(80)

            TableColumn("Type") { msg in
                Text(msg.isExtended ? "EXT" : "STD")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(msg.isExtended ? Color.orange.opacity(0.15) : Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())
            }
            .width(55)

            TableColumn("Data") { msg in
                Text(msg.isRemote ? "RTR" : msg.dataHex)
                    .font(.system(.body, design: .monospaced))
            }
            .width(min: 160)

            TableColumn("Period") { msg in
                if msg.periodMs > 0 {
                    Text("\(msg.periodMs) ms")
                } else {
                    Text("Manual")
                        .foregroundStyle(.secondary)
                }
            }
            .width(80)

            TableColumn("Waveform") { msg in
                if let gen = msg.signalGenerator, gen.waveform != .none {
                    Label(gen.waveform.rawValue, systemImage: gen.waveform.systemImage)
                        .font(.caption)
                } else {
                    Text("—")
                        .foregroundStyle(.secondary)
                }
            }

            TableColumn("") { msg in
                HStack(spacing: 4) {
                    Button {
                        txStore.sendOnce(id: msg.id)
                    } label: {
                        Image(systemName: "paperplane")
                    }
                    .buttonStyle(.borderless)
                    .disabled(!backendManager.isChannelOpen)

                    Button {
                        editingMessage = msg
                        showEditor = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)

                    Button {
                        txStore.removeMessage(id: msg.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .width(100)
        } rows: {
            ForEach(txStore.messages) { msg in
                TableRow(msg)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }
}

private struct CANTxMessageEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var message: CANTxMessage
    private let onSave: (CANTxMessage) -> Void

    init(message: CANTxMessage, onSave: @escaping (CANTxMessage) -> Void) {
        _message = State(initialValue: message)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Message")
                .font(.headline)

            Form {
                Section("Frame") {
                    HStack {
                        TextField("ID (hex)", text: Binding(
                            get: { String(format: "%X", message.arbitrationID) },
                            set: { message.arbitrationID = UInt32($0, radix: 16) ?? 0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)

                        Picker("Format", selection: $message.isExtended) {
                            Text("STD (11-bit)").tag(false)
                            Text("EXT (29-bit)").tag(true)
                        }
                        .frame(width: 140)

                        Toggle("RTR", isOn: $message.isRemote)
                    }

                    if !message.isRemote {
                        TextField("Data (hex)", text: Binding(
                            get: { message.dataHex },
                            set: { text in
                                let hex = text.replacingOccurrences(of: " ", with: "")
                                message.data = hex.matches(of: /[0-9A-Fa-f]{2}/).map {
                                    UInt8(String($0.output), radix: 16) ?? 0
                                }
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }
                }

                Section("Transmission") {
                    HStack {
                        TextField("Period (ms)", value: $message.periodMs, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Text("ms")
                            .foregroundStyle(.secondary)

                        Spacer()

                        Toggle("Enabled", isOn: $message.isEnabled)
                    }
                }

                Section("Signal Generator") {
                    Picker("Waveform", selection: waveformBinding) {
                        ForEach(SignalGenerator.Waveform.allCases) { w in
                            Label(w.rawValue, systemImage: w.systemImage).tag(w)
                        }
                    }
                    .frame(width: 160)

                    if message.signalGenerator?.waveform != .none && message.signalGenerator != nil {
                        HStack {
                            Picker("Target Byte", selection: Binding(
                                get: { message.signalGenerator?.targetByteIndex ?? 0 },
                                set: { message.signalGenerator?.targetByteIndex = $0 }
                            )) {
                                ForEach(0..<max(message.data.count, 1), id: \.self) { i in
                                    Text("Byte \(i)").tag(i)
                                }
                            }
                            .frame(width: 100)

                            TextField("Amplitude", value: Binding(
                                get: { message.signalGenerator?.amplitude ?? 127 },
                                set: { message.signalGenerator?.amplitude = $0 }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)

                            TextField("Offset", value: Binding(
                                get: { message.signalGenerator?.offset ?? 128 },
                                set: { message.signalGenerator?.offset = $0 }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)

                            TextField("Freq (Hz)", value: Binding(
                                get: { message.signalGenerator?.frequencyHz ?? 1.0 },
                                set: { message.signalGenerator?.frequencyHz = $0 }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    onSave(message)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(width: 560)
    }

    private var waveformBinding: Binding<SignalGenerator.Waveform> {
        Binding(
            get: { message.signalGenerator?.waveform ?? .none },
            set: { waveform in
                if waveform == .none {
                    message.signalGenerator = nil
                } else if message.signalGenerator == nil {
                    message.signalGenerator = SignalGenerator(waveform: waveform)
                } else {
                    message.signalGenerator?.waveform = waveform
                }
            }
        )
    }

    private var isValid: Bool {
        if message.isExtended {
            guard message.arbitrationID <= 0x1FFFFFFF else { return false }
        } else {
            guard message.arbitrationID <= 0x7FF else { return false }
        }
        if !message.isRemote {
            guard message.data.count <= 8 else { return false }
        }
        return true
    }
}
