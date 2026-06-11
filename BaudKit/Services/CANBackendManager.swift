import Foundation

@Observable
@MainActor
public final class CANBackendManager {
    // MARK: - Observable State (synced from active backend)

    public var activeBackendType: CANBackendType {
        didSet {
            UserDefaults.standard.set(activeBackendType.rawValue, forKey: "baud.canBackend")
            syncState()
        }
    }

    public var isChannelOpen = false
    public var selectedBitrate: CANBitrate = .bps500k
    public var lastError: String?

    // MARK: - Backend Instances

    public let slcanManager: SLCANManager
    public private(set) var pcanBackend: PCANBackend?

    /// Whether PCAN library is available on this system
    public var pcanAvailable: Bool { PCANBackend.isLibraryAvailable }

    /// Backend types available on this system
    public var availableBackendTypes: [CANBackendType] {
        var types: [CANBackendType] = [.slcan]
        if pcanAvailable { types.append(.pcan) }
        return types
    }

    /// Bitrates supported by the active backend
    public var supportedBitrates: [CANBitrate] {
        switch activeBackendType {
        case .slcan: CANBitrate.slcanBitrates
        case .pcan: CANBitrate.pcanBitrates
        }
    }

    // MARK: - SLCAN-specific Access

    public var deviceVersion: String { slcanManager.deviceVersion }
    public var deviceSerialNumber: String { slcanManager.deviceSerialNumber }
    public var statusFlags: UInt8 { slcanManager.statusFlags }

    // MARK: - PCAN-specific Access

    public var pcanDevices: [PCANDevice] { pcanBackend?.devices ?? [] }
    public var selectedPCANChannel: UInt16? {
        get { pcanBackend?.selectedChannel }
        set { pcanBackend?.selectedChannel = newValue }
    }

    // MARK: - Init

    public init() {
        let saved = UserDefaults.standard.string(forKey: "baud.canBackend") ?? "slcan"
        activeBackendType = CANBackendType(rawValue: saved) ?? .slcan

        slcanManager = SLCANManager()

        if PCANBackend.isLibraryAvailable {
            pcanBackend = PCANBackend()
        }

        // Validate saved backend type
        if activeBackendType == .pcan && pcanBackend == nil {
            activeBackendType = .slcan
        }

        syncState()
    }

    // MARK: - Configuration

    public func configure(with portManager: SerialPortManager) {
        slcanManager.configure(with: portManager)
    }

    // MARK: - CAN Operations (delegate to active backend)

    public func openChannel() {
        switch activeBackendType {
        case .slcan:
            slcanManager.openChannel()
        case .pcan:
            pcanBackend?.openChannel()
        }
        syncState()
    }

    public func closeChannel() {
        switch activeBackendType {
        case .slcan:
            slcanManager.closeChannel()
        case .pcan:
            pcanBackend?.closeChannel()
        }
        syncState()
    }

    public func transmitFrame(_ frame: CANFrame) {
        switch activeBackendType {
        case .slcan:
            slcanManager.transmitFrame(frame)
        case .pcan:
            pcanBackend?.transmitFrame(frame)
        }
    }

    public func setFilters(code: UInt32, mask: UInt32) {
        switch activeBackendType {
        case .slcan:
            slcanManager.acceptanceCode = code
            slcanManager.acceptanceMask = mask
            slcanManager.setFilters()
        case .pcan:
            pcanBackend?.acceptanceCode = code
            pcanBackend?.acceptanceMask = mask
            pcanBackend?.setFilters()
        }
    }

    // MARK: - SLCAN-specific Operations

    public func requestVersion() {
        guard activeBackendType == .slcan else { return }
        slcanManager.requestVersion()
    }

    public func requestSerialNumber() {
        guard activeBackendType == .slcan else { return }
        slcanManager.requestSerialNumber()
    }

    public func requestStatusFlags() {
        guard activeBackendType == .slcan else { return }
        slcanManager.requestStatusFlags()
    }

    /// Process incoming serial data (SLCAN only)
    public func processIncomingData(_ data: Data) {
        guard activeBackendType == .slcan else { return }
        slcanManager.processIncomingData(data)
    }

    // MARK: - PCAN-specific Operations

    public func detectPCANDevices() {
        pcanBackend?.detectDevices()
    }

    // MARK: - State Sync

    /// Sync observable state from the active backend
    private func syncState() {
        switch activeBackendType {
        case .slcan:
            isChannelOpen = slcanManager.isChannelOpen
            selectedBitrate = slcanManager.selectedBitrate
            lastError = slcanManager.lastError
        case .pcan:
            isChannelOpen = pcanBackend?.isChannelOpen ?? false
            selectedBitrate = pcanBackend?.selectedBitrate ?? .bps500k
            lastError = pcanBackend?.lastError
        }
    }
}
