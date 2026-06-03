import SwiftUI

public struct SerialTerminalView: View {
    @Environment(SerialPortManager.self) private var portManager
    @Environment(SerialDataManager.self) private var dataManager
    @AppStorage("baud.displayMode") private var displayMode: DisplayMode = .hexAscii
    @State private var autoScroll = true
    @State private var showQuickSend = false
    @State private var showProtocolFrames = false
    @State private var showProtocolConfig = false
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
                    if showProtocolFrames {
                        ProtocolFramesView()
                            .frame(height: 160)
                        Divider()
                    }
                    SerialSendBar()
                }
                .animation(.easeInOut(duration: 0.2), value: showQuickSend)
                .frame(minWidth: 400, idealWidth: geo.size.width * 0.618, maxWidth: geo.size.width * 0.8)

                SerialChartView()
                    .frame(minWidth: 250, idealWidth: geo.size.width * 0.382, maxWidth: geo.size.width * 0.6)
            }
        }
        .navigationTitle("Serial Terminal")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Picker("", selection: $displayMode) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)

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

                Button {
                    withAnimation { showProtocolFrames.toggle() }
                } label: {
                    Label("Protocol", systemImage: showProtocolFrames ? "chevron.up" : "chevron.down")
                }

                Button {
                    showProtocolConfig = true
                } label: {
                    Label("Protocol Config", systemImage: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showProtocolConfig) {
            ProtocolConfigView()
        }
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
                let text: String
                if mockCounter.truncatingRemainder(dividingBy: 3) == 0 {
                    text = String(format: "AT+READ:%04X\r\n", Int(mockCounter) % 256)
                } else if mockCounter.truncatingRemainder(dividingBy: 3) == 1 {
                    text = String(format: "OK:%04X\r\n", Int(mockCounter) % 4096)
                } else {
                    text = "HEX:" + (0..<4).map { _ in String(format: "%02X", Int.random(in: 0...255)) }.joined() + "\r\n"
                }
                dataManager.appendSent(data: text.data(using: .utf8) ?? Data())
                let response = "ACK:" + String(format: "%04X", Int(mockCounter) % 65536) + "\r\n"
                dataManager.appendReceived(data: response.data(using: .utf8) ?? Data())
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

        static let defaults: [Snippet] = [
            Snippet(id: UUID(), name: "AT", text: "AT\r\n", isHex: false),
            Snippet(id: UUID(), name: "Reset", text: "ATZ\r\n", isHex: false),
            Snippet(id: UUID(), name: "Version", text: "ATI\r\n", isHex: false),
        ]
    }

    private func loadSnippets() -> [Snippet] {
        guard !storedSnippets.isEmpty,
              let decoded = try? JSONDecoder().decode([Snippet].self, from: storedSnippets)
        else { return Snippet.defaults }
        return decoded
    }

    private func saveSnippets() {
        storedSnippets = (try? JSONEncoder().encode(snippets)) ?? Data()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Quick Send")
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation { showQuickSend = false }
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()

            List {
                ForEach($snippets) { $snippet in
                    HStack {
                        Text(snippet.name)
                            .lineLimit(1)
                        Spacer()
                        if snippet.isHex {
                            Text("HEX")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(RoundedRectangle(cornerRadius: 3).fill(.orange))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { sendSnippet(snippet) }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            Divider()

            VStack(spacing: 4) {
                TextField("Name", text: $newSnippetName)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    TextField("Data", text: $newSnippetText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addSnippet() }
                    Toggle("HEX", isOn: $newSnippetHex)
                        .toggleStyle(.checkbox)
                }
                Button("Add Snippet") {
                    addSnippet()
                }
                .buttonStyle(.borderless)
                .disabled(newSnippetName.isEmpty || newSnippetText.isEmpty)
            }
            .padding(8)
        }
        .frame(minWidth: 200)
        .onAppear {
            snippets = loadSnippets()
            isNewFieldFocused = true
        }
    }

    private func addSnippet() {
        guard !newSnippetName.isEmpty, !newSnippetText.isEmpty else { return }
        snippets.append(Snippet(id: UUID(), name: newSnippetName, text: newSnippetText, isHex: newSnippetHex))
        saveSnippets()
        newSnippetName = ""
        newSnippetText = ""
        newSnippetHex = false
    }

    private func sendSnippet(_ snippet: Snippet) {
        guard portManager.isConnected else { return }
        let data: Data
        if snippet.isHex {
            data = HexFormatter.hexToData(snippet.text) ?? Data()
        } else {
            data = snippet.text.data(using: .utf8) ?? Data()
        }
        dataManager.appendSent(data: data)
        portManager.send(data: data)
    }
}

#Preview {
    SerialTerminalView()
        .environment(SerialPortManager())
        .environment(SerialDataManager())
}
