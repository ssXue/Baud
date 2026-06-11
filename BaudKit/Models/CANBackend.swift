import Foundation

// MARK: - CAN Backend Type

/// Available CAN bus communication backend types
public enum CANBackendType: String, CaseIterable, Identifiable, Sendable {
    case slcan
    case pcan

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .slcan: "SLCAN (Serial)"
        case .pcan: "PEAK PCAN-USB"
        }
    }

    public var systemImage: String {
        switch self {
        case .slcan: "cable.connector"
        case .pcan: "usb"
        }
    }
}

// MARK: - CAN Bitrate

/// Common CAN bus bitrates supported across backends
public enum CANBitrate: Int, CaseIterable, Identifiable, Sendable, Codable {
    case bps5k = 5000
    case bps10k = 10000
    case bps20k = 20000
    case bps50k = 50000
    case bps100k = 100000
    case bps125k = 125000
    case bps250k = 250000
    case bps500k = 500000
    case bps750k = 750000
    case bps800k = 800000
    case bps1M = 1000000

    public var id: Int { rawValue }

    public var display: String {
        switch self {
        case .bps5k: "5 kbps"
        case .bps10k: "10 kbps"
        case .bps20k: "20 kbps"
        case .bps50k: "50 kbps"
        case .bps100k: "100 kbps"
        case .bps125k: "125 kbps"
        case .bps250k: "250 kbps"
        case .bps500k: "500 kbps"
        case .bps750k: "750 kbps"
        case .bps800k: "800 kbps"
        case .bps1M: "1 Mbps"
        }
    }

    public var bps: Int { rawValue }

    /// SLCAN command index for bitrate setting (nil if not supported by SLCAN)
    var slcanIndex: UInt8? {
        switch self {
        case .bps10k: 0
        case .bps20k: 1
        case .bps50k: 2
        case .bps100k: 3
        case .bps125k: 4
        case .bps250k: 5
        case .bps500k: 6
        case .bps750k: 7
        case .bps1M: 8
        default: nil
        }
    }

    /// PCAN BTR register value (nil if not supported by PCAN standard bitrates)
    var pcanBtr: UInt16? {
        switch self {
        case .bps5k: 0x7F7F
        case .bps10k: 0x672F
        case .bps20k: 0x532F
        case .bps50k: 0x472F
        case .bps100k: 0x432F
        case .bps125k: 0x031C
        case .bps250k: 0x011C
        case .bps500k: 0x001C
        case .bps800k: 0x0016
        case .bps1M: 0x0014
        default: nil
        }
    }

    /// Whether this bitrate is supported by the SLCAN backend
    public var isSLCANSuported: Bool { slcanIndex != nil }

    /// Whether this bitrate is supported by the PCAN backend
    public var isPCANSupported: Bool { pcanBtr != nil }

    /// Bitrates supported by SLCAN
    public static let slcanBitrates = allCases.filter(\.isSLCANSuported)

    /// Bitrates supported by PCAN
    public static let pcanBitrates = allCases.filter(\.isPCANSupported)
}

// MARK: - CAN Backend Protocol

/// Protocol for CAN bus communication backends
@MainActor public protocol CANBackend: AnyObject {
    /// Type identifier for this backend
    var backendType: CANBackendType { get }

    /// Whether the CAN channel is currently open
    var isChannelOpen: Bool { get set }

    /// Currently selected bitrate
    var selectedBitrate: CANBitrate { get set }

    /// Acceptance filter code
    var acceptanceCode: UInt32 { get set }

    /// Acceptance filter mask
    var acceptanceMask: UInt32 { get set }

    /// Last error message from the backend
    var lastError: String? { get }

    /// Open the CAN channel
    func openChannel()

    /// Close the CAN channel
    func closeChannel()

    /// Transmit a CAN frame
    func transmitFrame(_ frame: CANFrame)

    /// Apply acceptance filter settings
    func setFilters()
}

// MARK: - PCAN Device Info

/// Information about a detected PCAN USB device
public struct PCANDevice: Identifiable, Sendable {
    public let id: UInt16          // PCAN channel handle (e.g. PCAN_USBBUS1 = 0x0041)
    public let name: String        // Display name
    public let deviceId: UInt32    // Device ID / serial number

    public init(id: UInt16, name: String, deviceId: UInt32 = 0) {
        self.id = id
        self.name = name
        self.deviceId = deviceId
    }
}
