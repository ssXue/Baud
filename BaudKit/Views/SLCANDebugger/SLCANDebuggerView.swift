import SwiftUI

public struct SLCANDebuggerView: View {
    @Environment(SerialPortManager.self) private var portManager
    @Environment(SLCANManager.self) private var slcanManager
    @Environment(CANFrameStore.self) private var frameStore
    @Environment(CANSignalStore.self) private var signalStore

    @State private var showSendSheet = false
    @State private var showSettingsSheet = false
    @State private var mockTimer: Timer?
    @State private var mockCounter: Double = 0

    public init() {}

    public var body: some View {
        GeometryReader { geo in
            HSplitView {
                VStack(spacing: 0) {
                    @Bindable var frameStore = frameStore
                    HStack(spacing: 6) {
                        Picker("", selection: $frameStore.viewMode) {
                            ForEach(CANViewMode.allCases, id: \.self) { mode in
                                Text(mode == .trace ? "Trace" : "Monitor").tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160)
                        Spacer()
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
                            frameStore.clear()
                        } label: {
                            Label("Clear", systemImage: "trash")
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

                    if frameStore.viewMode == .trace {
                        CANFrameListView()
                    } else {
                        CANMonitorView()
                    }

                    Divider()
                    if let frame = frameStore.selectedFrame {
                        CANFrameDetailView(frame: frame)
                            .frame(height: 180)
                    }
                }
                .frame(idealWidth: geo.size.width * 0.618)

                CANChartView()
                    .frame(idealWidth: geo.size.width * 0.382)
            }
        }
        .navigationTitle("SLCAN Debugger")
        .sheet(isPresented: $showSendSheet) {
            CANSendView()
        }
        .sheet(isPresented: $showSettingsSheet) {
            CANSettingsView()
        }
        .task {
            slcanManager.configure(with: portManager)
        }
        .onReceive(NotificationCenter.default.publisher(for: .slcanFrameReceived)) { notification in
            if let frame = notification.userInfo?["frame"] as? CANFrame {
                frameStore.addFrame(frame)
                signalStore.processFrame(frame)
            }
        }
        .onDisappear {
            stopMock()
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
            }
        }
    }

    private func stopMock() {
        mockTimer?.invalidate()
        mockTimer = nil
    }
}
