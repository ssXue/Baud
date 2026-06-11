import Foundation

// MARK: - PCAN C Types

/// PCAN message structure matching PCBUSB-Library layout
struct TPCANMsg {
    var id: UInt32
    var msgType: UInt8
    var len: UInt8
    var data: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
}

/// PCAN timestamp structure matching PCBUSB-Library layout
struct TPCANTimestamp {
    var millis: UInt32
    var millisOverflow: UInt16
    var micros: UInt16
}

// MARK: - PCAN Constants

/// PCAN USB channel handles
enum PCANChannel: UInt16, CaseIterable {
    case usbbus1 = 0x0051
    case usbbus2 = 0x0052
    case usbbus3 = 0x0053
    case usbbus4 = 0x0054
    case usbbus5 = 0x0055
    case usbbus6 = 0x0056
    case usbbus7 = 0x0057
    case usbbus8 = 0x0058
}

/// PCAN message type flags
private enum PCANMsgType: UInt8 {
    case standard = 0x00
    case rtr = 0x01
    case extended = 0x02
}

/// PCAN status codes (from PCBUSB.h)
private enum PCANStatus {
    static let ok: UInt32 = 0x00000
    static let xmtFull: UInt32 = 0x00001
    static let overrun: UInt32 = 0x00002
    static let busLight: UInt32 = 0x00004
    static let busHeavy: UInt32 = 0x00008
    static let busOff: UInt32 = 0x00010
    static let qRcvEmpty: UInt32 = 0x00020
    static let qOverrun: UInt32 = 0x00040
    static let qXmtFull: UInt32 = 0x00080
    static let regTest: UInt32 = 0x00100
    static let noDriver: UInt32 = 0x00200
    static let hwInUse: UInt32 = 0x00400
    static let illHw: UInt32 = 0x01400
    static let illNet: UInt32 = 0x01800
    static let illClient: UInt32 = 0x01C00
    static let illHandle: UInt32 = 0x01C00  // illHw | illNet | illClient
    static let resource: UInt32 = 0x02000
    static let illParamType: UInt32 = 0x04000
    static let illParamVal: UInt32 = 0x08000
    static let unknown: UInt32 = 0x10000
    static let illData: UInt32 = 0x20000
    static let illMode: UInt32 = 0x80000
    static let initialize: UInt32 = 0x4000000
    static let illOperation: UInt32 = 0x8000000
}

/// PCAN parameter IDs for GetValue/SetValue
private enum PCANParameter: UInt8 {
    case deviceNumber = 0x01
    case channelId = 0x02
    case attachedChannels = 0x0A
    case channelCondition = 0x13
}

/// PCAN filter modes
private enum PCANFilterMode: UInt8 {
    case custom = 0x01
    case open = 0x02
}

// MARK: - dlsym Function Pointer Types

private typealias PCAN_InitializeFunc = @convention(c) (UInt16, UInt16, UInt8, UInt32, UInt16) -> UInt32
private typealias PCAN_UninitializeFunc = @convention(c) (UInt16) -> UInt32
private typealias PCAN_ReadFunc = @convention(c) (UInt16, UnsafeMutableRawPointer, UnsafeMutableRawPointer?) -> UInt32
private typealias PCAN_WriteFunc = @convention(c) (UInt16, UnsafeMutableRawPointer) -> UInt32
private typealias PCAN_GetValueFunc = @convention(c) (UInt16, UInt8, UnsafeMutableRawPointer, UInt32) -> UInt32
private typealias PCAN_SetValueFunc = @convention(c) (UInt16, UInt8, UnsafeMutableRawPointer, UInt32) -> UInt32
private typealias PCAN_FilterMessagesFunc = @convention(c) (UInt16, UInt32, UInt32, UInt8) -> UInt32
private typealias PCAN_GetStatusFunc = @convention(c) (UInt16) -> UInt32

// MARK: - Diagnostic Logging

/// Log file path for PCAN diagnostics (readable via PCANBackend.dumpLog())
private let pcanLogFile = "/tmp/baud_pcan.log"

/// Background queue for diagnostic logging to avoid main thread I/O
private let pcanLogQueue = DispatchQueue(label: "com.baud.pcan.log", qos: .utility)

private func pcanLog(_ message: String) {
    let line = "[PCAN] \(message)\n"
    pcanLogQueue.async {
        if let data = line.data(using: .utf8) {
            let fm = FileManager.default
            if fm.fileExists(atPath: pcanLogFile) {
                if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: pcanLogFile)) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: URL(fileURLWithPath: pcanLogFile))
            }
        }
    }
    print("[PCAN] \(message)")
}

// MARK: - PCANBackend

@Observable
@MainActor
public final class PCANBackend: CANBackend {
    public let backendType: CANBackendType = .pcan

    public var isChannelOpen = false
    public var selectedBitrate: CANBitrate = .bps500k
    public var acceptanceCode: UInt32 = 0
    public var acceptanceMask: UInt32 = 0xFFFFFFFF
    public var lastError: String?

    /// Detected PCAN devices on this system
    public private(set) var devices: [PCANDevice] = []

    /// Currently selected PCAN channel handle
    public var selectedChannel: UInt16? {
        didSet { UserDefaults.standard.set(selectedChannel, forKey: "baud.pcan.selectedChannel") }
    }

    /// Whether the PCBUSB library was successfully loaded
    public static var isLibraryAvailable: Bool {
        let path = librarySearchPath
        for searchPath in [path, "libPCBUSB.dylib"] {
            if dlopen(searchPath, RTLD_LAZY | RTLD_NOLOAD) != nil { return true }
            if let h = dlopen(searchPath, RTLD_LAZY) {
                dlclose(h)
                return true
            }
        }
        return false
    }

    /// Path to libPCBUSB.dylib inside the app bundle's Frameworks directory
    private static var librarySearchPath: String {
        "@executable_path/../Frameworks/libPCBUSB.dylib"
    }

    /// Dump the diagnostic log for debugging
    public static func dumpLog() -> String {
        (try? String(contentsOfFile: pcanLogFile)) ?? "(no log file at \(pcanLogFile))"
    }

    // dlsym-loaded function pointers
    private var pcanInitialize: PCAN_InitializeFunc?
    private var pcanUninitialize: PCAN_UninitializeFunc?
    private var pcanRead: PCAN_ReadFunc?
    private var pcanWrite: PCAN_WriteFunc?
    private var pcanGetValue: PCAN_GetValueFunc?
    private var pcanSetValue: PCAN_SetValueFunc?
    private var pcanFilterMessages: PCAN_FilterMessagesFunc?
    private var pcanGetStatus: PCAN_GetStatusFunc?

    nonisolated(unsafe) private var libraryHandle: UnsafeMutableRawPointer?
    private let readQueue = DispatchQueue(label: "com.baud.pcan.read", qos: .userInteractive)
    nonisolated(unsafe) private var shouldRead = false

    public init() {
        // Clear previous log
        try? FileManager.default.removeItem(atPath: pcanLogFile)
        let t0 = CFAbsoluteTimeGetCurrent()
        loadLibrary()
        let t1 = CFAbsoluteTimeGetCurrent()
        if libraryHandle != nil {
            detectDevices()
            let t2 = CFAbsoluteTimeGetCurrent()
            restoreSelectedChannel()
            let t3 = CFAbsoluteTimeGetCurrent()
            pcanLog(String(format: "Init timing: loadLibrary=%.1fms detectDevices=%.1fms restore=%.1fms total=%.1fms",
                (t1-t0)*1000, (t2-t1)*1000, (t3-t2)*1000, (t3-t0)*1000))
        }
    }

    nonisolated deinit {
        shouldRead = false
        if let handle = libraryHandle {
            dlclose(handle)
        }
    }

    // MARK: - CANBackend Protocol

    public func openChannel() {
        guard !isChannelOpen else { return }
        guard let channel = selectedChannel else {
            lastError = "No PCAN device selected"
            return
        }
        guard let initialize = pcanInitialize,
              let bitrate = selectedBitrate.pcanBtr else {
            lastError = "PCAN library not loaded or bitrate not supported"
            return
        }

        pcanLog("Opening channel 0x\(String(channel, radix: 16)) bitrate=\(selectedBitrate.display)")
        let status = initialize(channel, bitrate, 0, 0, 0)
        if status == PCANStatus.ok {
            isChannelOpen = true
            lastError = nil
            pcanLog("Channel opened successfully")

            if acceptanceMask != 0xFFFFFFFF {
                _ = pcanFilterMessages?(channel, acceptanceCode, acceptanceMask, PCANFilterMode.custom.rawValue)
            }
            startReadLoop()
        } else {
            lastError = "PCAN initialize failed: \(Self.statusString(status))"
            pcanLog("Open failed: \(lastError!)")
        }
    }

    public func closeChannel() {
        guard isChannelOpen else { return }
        stopReadLoop()
        if let channel = selectedChannel, let uninitialize = pcanUninitialize {
            _ = uninitialize(channel)
        }
        isChannelOpen = false
        pcanLog("Channel closed")
    }

    private let writeQueue = DispatchQueue(label: "com.baud.pcan.write", qos: .userInitiated)

    public func transmitFrame(_ frame: CANFrame) {
        guard isChannelOpen, let channel = selectedChannel, let write = pcanWrite else { return }

        // Build message on main thread (frame is from @Observable context)
        var msg = TPCANMsg(
            id: frame.arbitrationID,
            msgType: 0,
            len: frame.dlc,
            data: (0, 0, 0, 0, 0, 0, 0, 0)
        )

        if frame.isExtended { msg.msgType |= PCANMsgType.extended.rawValue }
        if frame.isRemote { msg.msgType |= PCANMsgType.rtr.rawValue }

        if !frame.isRemote {
            for i in 0..<min(Int(frame.dlc), 8) {
                withUnsafeMutablePointer(to: &msg.data) { ptr in
                    ptr.withMemoryRebound(to: UInt8.self, capacity: 8) { bytes in
                        bytes[i] = i < frame.data.count ? frame.data[i] : 0
                    }
                }
            }
        }

        // Perform USB write on background queue to avoid blocking main thread
        writeQueue.async { [self] in
            let t0 = CFAbsoluteTimeGetCurrent()
            let status = withUnsafeMutablePointer(to: &msg) { ptr in
                write(channel, ptr)
            }
            let elapsed = (CFAbsoluteTimeGetCurrent() - t0) * 1000
            if status == PCANStatus.ok {
                pcanLog("Write OK id=0x\(String(msg.id, radix: 16)) len=\(msg.len) \(Self.hexDump(msg: msg))")
            } else if status & PCANStatus.qXmtFull != 0 || status & PCANStatus.xmtFull != 0 {
                pcanLog("Write queue full — USB write stalled \(String(format: "%.1f", elapsed))ms (no CAN ACK? check bus termination)")
                Task { @MainActor [weak self] in
                    self?.lastError = "CAN transmit queue full — check bus connection and termination (120Ω)"
                }
            } else {
                pcanLog("Write FAILED status=0x\(String(status, radix: 16)) \(Self.statusString(status)) (\(String(format: "%.1f", elapsed))ms)")
                if status & PCANStatus.busOff != 0 {
                    Task { @MainActor [weak self] in
                        self?.handleBusError("Bus off detected on write")
                    }
                } else {
                    Task { @MainActor [weak self] in
                        self?.lastError = "PCAN write failed: \(Self.statusString(status))"
                    }
                }
            }
        }
    }

    public func setFilters() {
        guard isChannelOpen, let channel = selectedChannel else { return }
        if acceptanceMask == 0xFFFFFFFF {
            _ = pcanFilterMessages?(channel, 0, 0xFFFFFFFF, PCANFilterMode.open.rawValue)
        } else {
            _ = pcanFilterMessages?(channel, acceptanceCode, acceptanceMask, PCANFilterMode.custom.rawValue)
        }
    }

    // MARK: - Device Detection

    public func detectDevices() {
        devices = []
        guard let initialize = pcanInitialize, let uninitialize = pcanUninitialize else {
            pcanLog("detectDevices skipped — library functions not loaded")
            return
        }

        pcanLog("Scanning for devices on \(PCANChannel.allCases.count) channels (probe via CAN_Initialize)...")
        for bus in PCANChannel.allCases {
            let handle = bus.rawValue

            // Probe: try to initialize with 500k bitrate
            let tProbe = CFAbsoluteTimeGetCurrent()
            let status = initialize(handle, CANBitrate.bps500k.pcanBtr!, 0, 0, 0)
            let elapsed = (CFAbsoluteTimeGetCurrent() - tProbe) * 1000

            pcanLog(String(format: "  Channel 0x%02X: %.1fms status=0x%X %@", handle, elapsed, status, Self.statusString(status)))

            if status == PCANStatus.ok {
                // Device found — immediately release it
                _ = uninitialize(handle)
                devices.append(PCANDevice(
                    id: handle,
                    name: "PCAN-USB \(handle - 0x0050)",
                    deviceId: 0
                ))
                pcanLog("  → Device found!")
            } else if status == PCANStatus.hwInUse {
                // Device exists but already in use by another process
                devices.append(PCANDevice(
                    id: handle,
                    name: "PCAN-USB \(handle - 0x0050) (in use)",
                    deviceId: 0
                ))
                pcanLog("  → Device found but in use")
            }
            // NODRIVER, ILLHANDLE, etc. → no device on this channel
        }
        pcanLog("Found \(devices.count) device(s)")
    }

    // MARK: - Read Loop

    private func startReadLoop() {
        shouldRead = true
        guard let read = pcanRead, let channel = selectedChannel else { return }
        readQueue.async { [weak self] in
            self?.readLoop(read: read, channel: channel)
        }
    }

    private func stopReadLoop() {
        shouldRead = false
    }

    private nonisolated func readLoop(read: PCAN_ReadFunc, channel: UInt16) {
        var msg = TPCANMsg(id: 0, msgType: 0, len: 0, data: (0, 0, 0, 0, 0, 0, 0, 0))
        var timestamp = TPCANTimestamp(millis: 0, millisOverflow: 0, micros: 0)
        var lastLoggedStatus: UInt32 = 0

        while shouldRead {
            let status = withUnsafeMutablePointer(to: &msg) { msgPtr in
                withUnsafeMutablePointer(to: &timestamp) { tsPtr in
                    read(channel, msgPtr, tsPtr)
                }
            }

            if status == PCANStatus.ok {
                let frame = Self.parseMessage(msg)
                Task { @MainActor [weak self] in
                    guard self?.shouldRead == true else { return }
                    NotificationCenter.default.post(
                        name: .canFrameReceived,
                        object: nil,
                        userInfo: ["frame": frame]
                    )
                }
                lastLoggedStatus = 0
            } else if status & PCANStatus.qRcvEmpty != 0 {
                // Normal: no message available yet
                Thread.sleep(forTimeInterval: 0.001)
                lastLoggedStatus = 0
            } else if status & PCANStatus.busOff != 0 {
                pcanLog("Read: BUS OFF (status=0x\(String(status, radix: 16)))")
                Task { @MainActor [weak self] in
                    self?.handleBusError("Bus off")
                }
                break
            } else if status & PCANStatus.busHeavy != 0 {
                // Log bus heavy only on state change
                if lastLoggedStatus != status {
                    pcanLog("Read: BusHeavy \(Self.statusString(status))")
                    lastLoggedStatus = status
                }
                Thread.sleep(forTimeInterval: 0.001)
            } else if status & (PCANStatus.overrun | PCANStatus.qOverrun) != 0 {
                if lastLoggedStatus != status {
                    pcanLog("Read: Overrun \(Self.statusString(status))")
                    lastLoggedStatus = status
                }
                Thread.sleep(forTimeInterval: 0.001)
            } else if status != 0 {
                if lastLoggedStatus != status {
                    pcanLog("Read: unexpected status=0x\(String(status, radix: 16)) \(Self.statusString(status))")
                    lastLoggedStatus = status
                }
                Thread.sleep(forTimeInterval: 0.01)
            }
        }
    }

    private func handleBusError(_ message: String) {
        lastError = message
        pcanLog("Bus error: \(message)")
        closeChannel()
    }

    // MARK: - Message Parsing

    private nonisolated static func parseMessage(_ msg: TPCANMsg) -> CANFrame {
        let isExtended = (msg.msgType & PCANMsgType.extended.rawValue) != 0
        let isRemote = (msg.msgType & PCANMsgType.rtr.rawValue) != 0

        var data = [UInt8]()
        if !isRemote {
            data.reserveCapacity(Int(msg.len))
            withUnsafePointer(to: msg.data) { ptr in
                ptr.withMemoryRebound(to: UInt8.self, capacity: 8) { bytes in
                    for i in 0..<min(Int(msg.len), 8) {
                        data.append(bytes[i])
                    }
                }
            }
        }

        return CANFrame(
            arbitrationID: msg.id,
            isExtended: isExtended,
            isRemote: isRemote,
            dlc: msg.len,
            data: data,
            direction: .received,
            timestamp: Date()
        )
    }

    // MARK: - Library Loading

    private func loadLibrary() {
        let path = Self.librarySearchPath
        libraryHandle = dlopen(path, RTLD_LAZY | RTLD_GLOBAL)
        if libraryHandle != nil {
            pcanLog("Library loaded from bundle: \(path)")
        } else {
            let err = String(cString: dlerror())
            pcanLog("Bundle load failed for '\(path)': \(err)")
            libraryHandle = dlopen("libPCBUSB.dylib", RTLD_LAZY | RTLD_GLOBAL)
            if libraryHandle != nil {
                pcanLog("Library loaded from system path")
            }
        }
        guard let handle = libraryHandle else {
            pcanLog("Library not found — PCAN backend unavailable")
            return
        }

        pcanInitialize = Self.loadSymbol(handle, "CAN_Initialize")
        pcanUninitialize = Self.loadSymbol(handle, "CAN_Uninitialize")
        pcanRead = Self.loadSymbol(handle, "CAN_Read")
        pcanWrite = Self.loadSymbol(handle, "CAN_Write")
        pcanGetValue = Self.loadSymbol(handle, "CAN_GetValue")
        pcanSetValue = Self.loadSymbol(handle, "CAN_SetValue")
        pcanFilterMessages = Self.loadSymbol(handle, "CAN_FilterMessages")
        pcanGetStatus = Self.loadSymbol(handle, "CAN_GetStatus")

        if pcanInitialize == nil || pcanRead == nil || pcanWrite == nil || pcanGetValue == nil {
            lastError = "PCAN library loaded but required functions not found"
            pcanLog("ERROR: Missing functions — Init:\(pcanInitialize != nil) Read:\(pcanRead != nil) Write:\(pcanWrite != nil) GetValue:\(pcanGetValue != nil)")
            pcanInitialize = nil
            pcanRead = nil
            pcanWrite = nil
            pcanGetValue = nil
        } else {
            pcanLog("All function pointers loaded successfully")
        }
    }

    private nonisolated static func loadSymbol<T>(_ handle: UnsafeMutableRawPointer, _ name: String) -> T? {
        guard let sym = dlsym(handle, name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }

    // MARK: - Utilities

    private func restoreSelectedChannel() {
        let saved = UserDefaults.standard.object(forKey: "baud.pcan.selectedChannel") as? UInt16
        if let saved, devices.contains(where: { $0.id == saved }) {
            selectedChannel = saved
        } else if let first = devices.first {
            selectedChannel = first.id
        }
    }

    private nonisolated static func hexDump(msg: TPCANMsg) -> String {
        var parts: [String] = []
        withUnsafePointer(to: msg.data) { ptr in
            ptr.withMemoryRebound(to: UInt8.self, capacity: 8) { bytes in
                for i in 0..<min(Int(msg.len), 8) {
                    parts.append(String(format: "%02X", bytes[i]))
                }
            }
        }
        return parts.joined(separator: " ")
    }

    private nonisolated static func statusString(_ status: UInt32) -> String {
        if status == PCANStatus.ok { return "OK" }
        var parts: [String] = []
        if status & PCANStatus.xmtFull != 0 { parts.append("XmtFull") }
        if status & PCANStatus.overrun != 0 { parts.append("Overrun") }
        if status & PCANStatus.busLight != 0 { parts.append("BusLight") }
        if status & PCANStatus.busHeavy != 0 { parts.append("BusHeavy") }
        if status & PCANStatus.busOff != 0 { parts.append("BusOff") }
        if status & PCANStatus.qRcvEmpty != 0 { parts.append("QRcvEmpty") }
        if status & PCANStatus.qOverrun != 0 { parts.append("QOverrun") }
        if status & PCANStatus.qXmtFull != 0 { parts.append("QXmtFull") }
        if status & PCANStatus.noDriver != 0 { parts.append("NoDriver") }
        if status & PCANStatus.hwInUse != 0 { parts.append("HwInUse") }
        if status & PCANStatus.illHw != 0 { parts.append("IllHw") }
        if status & PCANStatus.illNet != 0 { parts.append("IllNet") }
        if status & PCANStatus.illClient != 0 { parts.append("IllClient") }
        if status & PCANStatus.resource != 0 { parts.append("Resource") }
        if status & PCANStatus.illParamType != 0 { parts.append("IllParamType") }
        if status & PCANStatus.illParamVal != 0 { parts.append("IllParamVal") }
        if status & PCANStatus.unknown != 0 { parts.append("Unknown") }
        if status & PCANStatus.illData != 0 { parts.append("IllData") }
        if status & PCANStatus.regTest != 0 { parts.append("RegTest") }
        if parts.isEmpty { return "0x\(String(status, radix: 16))" }
        return parts.joined(separator: "|")
    }
}
