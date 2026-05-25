import SwiftUI

public struct SerialTerminalView: View {
    @Environment(SerialPortManager.self) private var portManager
    @Environment(SerialDataManager.self) private var dataManager
    @AppStorage("baud.displayMode") private var displayMode: DisplayMode = .hexAscii
    @State private var autoScroll = true
    @State private var showQuickSend = false
    @State private var mockTimer: Timer?
    @State private var mockCounter: Double = 0

    public init() {}

    public var body: some View {
        GeometryReader { geo in
            HSplitView {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        SerialConsoleView(displayMode: $displayMode, autoScroll: $autoScroll)
                        if showQuickSend {
                            Divider()
                            QuickSendPad(showQuickSend: $showQuickSend)
                                .frame(width: 260)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    HStack(spacing: 6) {
                        Picker("", selection: $displayMode) {
                            ForEach(DisplayMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 240)
                        Spacer()
                        Button {
                            showQuickSend.toggle()
                        } label: {
                            Label("Quick Send", systemImage: showQuickSend ? "text.bubble.fill" : "text.bubble")
                        }
                        Button {
                            exportConsole()
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.down")
                        }
                        .disabled(dataManager.messages.isEmpty)
                        Button {
                            dataManager.clear()
                        } label: {
                            Label("Clear Console", systemImage: "trash")
                        }
                        Button {
                            toggleMock()
                        } label: {
                            Label(mockTimer == nil ? "Mock" : "Stop Mock", systemImage: mockTimer == nil ? "flask" : "stop.circle")
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    Divider()
                    SerialSendBar()
                }
                .animation(.easeInOut(duration: 0.2), value: showQuickSend)
                .frame(idealWidth: geo.size.width * 0.618)

                SerialChartView()
                    .frame(idealWidth: geo.size.width * 0.382)
            }
        }
        .navigationTitle("Serial Terminal")
        .onReceive(NotificationCenter.default.publisher(for: .clearConsole)) { _ in
            dataManager.clear()
        }
        .onDisappear {
            stopMock()
        }
    }

    private func toggleMock() {
        if mockTimer != nil { stopMock() } else { startMock() }
    }

    private func startMock() {
        mockCounter = 0
        mockTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                mockCounter += 1
                let t = mockCounter * 0.1
                let line = String(format: "%.2f, %.2f, %.2f\n",
                    sin(t * 2.0) * 100,
                    cos(t * 0.7) * 50 + 25,
                    sin(t * 1.3 + 1.0) * 30 + 60
                )
                if let data = line.data(using: .utf8) {
                    dataManager.appendReceived(data: data)
                }
            }
        }
    }

    private func stopMock() {
        mockTimer?.invalidate()
        mockTimer = nil
    }

    private func exportConsole() {
        DataExporter.exportWithFormatPicker(messages: dataManager.messages, defaultName: "baud_console")
    }
}

private struct QuickSendPad: View {
    @Environment(SerialPortManager.self) private var portManager
    @Environment(SerialDataManager.self) private var dataManager
    @AppStorage("quickSendSnippets") private var storedSnippets: Data = Data()
    @Binding var showQuickSend: Bool
    @State private var snippets: [Snippet] = Snippet.defaults
    @State private var newSnippetName = ""
    @State private var newSnippetText = ""
    @State private var newSnippetHex = false
    @FocusState private var isNewFieldFocused: Bool

    private struct Snippet: Codable, Identifiable {
        let id: UUID
        var name: String
        var text: String
        var isHex: Bool

        init(id: UUID = UUID(), name: String = "", text: String, isHex: Bool = false) {
            self.id = id
            self.name = name
            self.text = text
            self.isHex = isHex
        }

        static let defaults: [Snippet] = [
            Snippet(name: "Test AT", text: "AT", isHex: false),
            Snippet(name: "Reset", text: "AT+RST", isHex: false),
            Snippet(name: "Version", text: "AT+GMR", isHex: false),
            Snippet(name: "UART Config", text: "AT+UART?", isHex: false),
            Snippet(name: "Custom Hex", text: "AA BB CC DD", isHex: true),
        ]
    }

    private func loadSnippets() -> [Snippet] {
        guard let decoded = try? JSONDecoder().decode([Snippet].self, from: storedSnippets) else {
            return Snippet.defaults
        }
        return decoded
    }

    private func saveSnippets() {
        storedSnippets = (try? JSONEncoder().encode(snippets)) ?? Data()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Quick Send")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showQuickSend = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            List {
                ForEach(snippets) { snippet in
                    HStack {
                        Button {
                            sendSnippet(snippet)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(snippet.name.isEmpty ? snippet.text : snippet.name)
                                    .font(.system(.body))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                HStack(spacing: 6) {
                                    if snippet.isHex {
                                        Text("HEX")
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(RoundedRectangle(cornerRadius: 3).fill(.orange))
                                    }
                                    Text(snippet.text)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(!portManager.isConnected)

                        Spacer()

                        Button {
                            snippets.removeAll { $0.id == snippet.id }
                            saveSnippets()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(.caption2))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            Divider()

            VStack(spacing: 6) {
                TextField("Note (optional)", text: $newSnippetName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body))

                HStack(spacing: 6) {
                    TextField("Add snippet...", text: $newSnippetText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .focused($isNewFieldFocused)
                        .onSubmit { addSnippet() }

                    Toggle("Hex", isOn: $newSnippetHex)
                        .toggleStyle(.checkbox)
                        .font(.system(.caption))

                    Button {
                        addSnippet()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newSnippetText.isEmpty)
                    .buttonStyle(.borderless)
                }
            }
            .padding(12)
        }
        .onAppear {
            snippets = loadSnippets()
        }
    }

    private func addSnippet() {
        guard !newSnippetText.isEmpty else { return }
        snippets.append(Snippet(name: newSnippetName, text: newSnippetText, isHex: newSnippetHex))
        saveSnippets()
        newSnippetName = ""
        newSnippetText = ""
        newSnippetHex = false
        isNewFieldFocused = true
    }

    private func sendSnippet(_ snippet: Snippet) {
        guard portManager.isConnected else { return }

        var data: Data
        if snippet.isHex {
            guard let parsed = HexFormatter.hexToData(snippet.text) else { return }
            data = parsed
        } else {
            guard let encoded = snippet.text.data(using: .utf8) else { return }
            data = encoded
        }

        data.append(0x0A)
        portManager.send(data: data)
        dataManager.appendSent(data: data)
    }
}

#Preview {
    SerialTerminalView()
        .environment(SerialPortManager())
        .environment(SerialDataManager())
}
