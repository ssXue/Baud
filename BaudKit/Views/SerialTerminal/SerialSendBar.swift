import SwiftUI

public struct SerialSendBar: View {
    @Environment(SerialPortManager.self) private var portManager
    @Environment(SerialDataManager.self) private var dataManager

    @State private var inputText = ""
    @AppStorage("baud.hexMode") private var isHexMode = false
    @AppStorage("baud.lineEnding") private var lineEnding: LineEnding = .lf
    @State private var isAutoSend = false
    @AppStorage("baud.autoSendInterval") private var intervalText = "1000"
    @State private var autoSendTimer: Timer?
    @FocusState private var isInputFocused: Bool

    public init() {}

    public var body: some View {
        HStack(spacing: 8) {
            TextField("Enter data to send...", text: $inputText)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .focused($isInputFocused)
                .onSubmit { send() }

            Toggle("Hex", isOn: $isHexMode)
                .toggleStyle(.checkbox)

            Picker("", selection: $lineEnding) {
                ForEach(LineEnding.allCases) { le in
                    Text(le.label).tag(le)
                }
            }
            .frame(width: 80)

            Toggle("Auto", isOn: $isAutoSend)
                .toggleStyle(.checkbox)

            if isAutoSend {
                TextField("ms", text: $intervalText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: intervalText) { _, _ in
                        if autoSendTimer != nil { startAutoSend() }
                    }
                Text("ms")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if autoSendTimer != nil {
                Button("Stop") {
                    stopAutoSend()
                }
                .buttonStyle(.glassProminent)
                .tint(.red)
            } else {
                Button("Send") {
                    send()
                    if isAutoSend { startAutoSend() }
                }
                .disabled(inputText.isEmpty || !portManager.isConnected)
                .buttonStyle(.glassProminent)
            }
        }
        .padding(8)
        .onAppear { isInputFocused = true }
        .onDisappear { stopAutoSend() }
    }

    private func send() {
        guard !inputText.isEmpty, portManager.isConnected else { return }

        var data: Data
        if isHexMode {
            guard let parsed = HexFormatter.hexToData(inputText) else { return }
            data = parsed
        } else {
            guard let encoded = inputText.data(using: .utf8) else { return }
            data = encoded
        }

        data.append(contentsOf: lineEnding.bytes)

        portManager.send(data: data)
        dataManager.appendSent(data: data)

        if !isAutoSend {
            inputText = ""
            isInputFocused = true
        }
    }

    private func startAutoSend() {
        stopAutoSend()
        guard !inputText.isEmpty,
              let interval = Double(intervalText),
              interval > 0
        else { return }
        autoSendTimer = Timer.scheduledTimer(withTimeInterval: interval / 1000.0, repeats: true) { _ in
            Task { @MainActor in
                self.send()
            }
        }
    }

    private func stopAutoSend() {
        autoSendTimer?.invalidate()
        autoSendTimer = nil
    }
}

// MARK: - Line Ending

public enum LineEnding: String, CaseIterable, Identifiable {
    case none = "None"
    case cr = "CR"
    case lf = "LF"
    case crlf = "CR+LF"

    public var id: String { rawValue }

    public var label: String { rawValue }

    public var bytes: [UInt8] {
        switch self {
        case .none: []
        case .cr: [0x0D]
        case .lf: [0x0A]
        case .crlf: [0x0D, 0x0A]
        }
    }
}
