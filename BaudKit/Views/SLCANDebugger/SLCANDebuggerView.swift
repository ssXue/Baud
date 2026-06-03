import SwiftUI

public struct SLCANDebuggerView: View {
    @Environment(SerialPortManager.self) private var portManager
    @Environment(SLCANManager.self) private var slcanManager
    @Environment(CANFrameStore.self) private var frameStore
    @Environment(CANSignalStore.self) private var signalStore
    @Environment(CANBusAnalyzer.self) private var analyzer

    @State private var showSendSheet = false
    @State private var showSettingsSheet = false
    @State private var showDBCImport = false
    @State private var mockTimer: Timer?
    @State private var mockCounter: Double = 0
    @AppStorage("developerMode") private var developerMode = false

    public init() {}

    public var body: some View {
        @Bindable var frameStore = frameStore

        GeometryReader { geo in
            HSplitView {
                VStack(spacing: 0) {
                    if frameStore.viewMode == .trace {
                        CANFrameListView()
                    } else if frameStore.viewMode == .monitor {
                        CANMonitorView()
                    } else {
                        CANStabilityView()
                    }

                    Divider()
                    if frameStore.viewMode != .stability, let frame = frameStore.selectedFrame {
                        CANFrameDetailView(frame: frame)
                            .frame(height: 180)
                    }
                }
                .frame(minWidth: 400, idealWidth: geo.size.width * 0.618, maxWidth: geo.size.width * 0.8)

                if frameStore.viewMode == .stability {
                    CANIntervalChartView()
                        .frame(minWidth: 250, idealWidth: geo.size.width * 0.382, maxWidth: geo.size.width * 0.6)
                } else {
                    CANChartView()
                        .frame(minWidth: 250, idealWidth: geo.size.width * 0.382, maxWidth: geo.size.width * 0.6)
                }
            }
        }
        .navigationTitle("SLCAN Debugger")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Picker("", selection: $frameStore.viewMode) {
                    ForEach(CANViewMode.allCases, id: \.self) { mode in
                        Text(mode == .trace ? "Trace" : mode == .monitor ? "Monitor" : "Stability").tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(minWidth: 180)

                if slcanManager.isChannelOpen {
                    Button {
                        slcanManager.closeChannel()
                    } label: {
                        Label("Close CAN", systemImage: "xmark.circle")
                    }
                } else {
                    Button {
                        slcanManager.openChannel()
                    } label: {
                        Label("Open CAN", systemImage: "play.circle")
                    }
                    .disabled(!portManager.isConnected)
                }

                Button {
                    showSendSheet = true
                } label: {
                    Label("Send Frame", systemImage: "paperplane")
                }
                .disabled(!slcanManager.isChannelOpen)

                Button {
                    showSettingsSheet = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }

                Button {
                    showDBCImport = true
                } label: {
                    Label("Import DBC", systemImage: "doc.text")
                }

                Button {
                    exportFrames()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.down")
                }
                .disabled(frameStore.frames.isEmpty)

                Button {
                    frameStore.clear()
                } label: {
                    Label("Clear", systemImage: "trash")
                }

                if developerMode {
                    Button {
                        toggleMock()
                    } label: {
                        Label(mockTimer == nil ? "Mock" : "Stop Mock", systemImage: mockTimer == nil ? "flask" : "stop.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showSendSheet) {
            CANSendView()
        }
        .sheet(isPresented: $showSettingsSheet) {
            CANSettingsView()
        }
        .sheet(isPresented: $showDBCImport) {
            DBCImportView()
        }
        .task {
            slcanManager.configure(with: portManager)
        }
        .onReceive(NotificationCenter.default.publisher(for: .slcanFrameReceived)) { notification in
            if let frame = notification.userInfo?["frame"] as? CANFrame {
                frameStore.addFrame(frame)
                signalStore.processFrame(frame)
                analyzer.processFrame(frame)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .slcanErrorFrameReceived)) { notification in
            if let code = notification.userInfo?["code"] as? UInt8 {
                analyzer.addError(code)
            }
        }
        .onDisappear {
            stopMock()
            analyzer.stopTimeoutChecker()
        }
        .onChange(of: slcanManager.isChannelOpen) { _, isOpen in
            if isOpen {
                analyzer.startTimeoutChecker()
            } else {
                analyzer.stopTimeoutChecker()
            }
        }
    }

    private func toggleMock() {
        if mockTimer != nil {
            stopMock()
        } else {
            startMock()
        }
    }

    private func startMock() {
        mockCounter = 0
        mockTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            Task { @MainActor in
                mockCounter += 1
                let t = mockCounter * 0.05

                let rpm = UInt16(abs(sin(t * 2.0) * 3000 + 3000))
                let speed = UInt16(abs(sin(t * 0.7) * 120 + 60))
                let temp = UInt8(min(255, max(0, 80 + sin(t * 0.3) * 30 + 20)))

                let rpmFrame = CANFrame(
                    arbitrationID: 0x0C4,
                    isExtended: false,
                    isRemote: false,
                    dlc: 8,
                    data: [UInt8(rpm & 0xFF), UInt8(rpm >> 8), 0, 0, 0, 0, 0, 0],
                    direction: .received,
                    timestamp: Date()
                )
                let speedFrame = CANFrame(
                    arbitrationID: 0x0C4,
                    isExtended: false,
                    isRemote: false,
                    dlc: 8,
                    data: [0, 0, UInt8(speed & 0xFF), UInt8(speed >> 8), temp, 0, 0, 0],
                    direction: .received,
                    timestamp: Date()
                )

                frameStore.addFrame(rpmFrame)
                frameStore.addFrame(speedFrame)
                signalStore.processFrame(rpmFrame)
                signalStore.processFrame(speedFrame)
                analyzer.processFrame(rpmFrame)
                analyzer.processFrame(speedFrame)
            }
        }
    }

    private func stopMock() {
        mockTimer?.invalidate()
        mockTimer = nil
    }

    private func exportFrames() {
        DataExporter.exportWithFormatPicker(frames: frameStore.filteredFrames, defaultName: "baud_can_frames")
    }
}
