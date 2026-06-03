import Foundation

@Observable
@MainActor
public final class SLCANManager {
    public var isChannelOpen = false
    public var selectedBitrate: SLCANBitrate = .bps500k
    public var acceptanceCode: UInt32 = 0
    public var acceptanceMask: UInt32 = 0xFFFFFFFF
    public var deviceVersion: String = ""
    public var deviceSerialNumber: String = ""
    public var statusFlags: UInt8 = 0
    public var lastError: String?

    private weak var portManager: SerialPortManager?
    private var lineBuffer = ""

    public init() {}

    public func configure(with portManager: SerialPortManager) {
        self.portManager = portManager
    }

    public func openChannel() {
        guard portManager != nil, !isChannelOpen else { return }
        // Configure bitrate first, then open
        sendCommand(.setBitrate(selectedBitrate))
        sendCommand(.openChannel)
        isChannelOpen = true
    }

    public func closeChannel() {
        guard isChannelOpen else { return }
        sendCommand(.closeChannel)
        isChannelOpen = false
    }

    public func transmitFrame(_ frame: CANFrame) {
        let command: SLCANCommand
        if frame.isRemote {
            if frame.isExtended {
                command = .transmitExtendedRTR(id: frame.arbitrationID, dlc: frame.dlc)
            } else {
                command = .transmitStandardRTR(id: frame.arbitrationID, dlc: frame.dlc)
            }
        } else {
            if frame.isExtended {
                command = .transmitExtended(id: frame.arbitrationID, data: frame.data)
            } else {
                command = .transmitStandard(id: frame.arbitrationID, data: frame.data)
            }
        }
        sendCommand(command)
    }

    public func requestVersion() {
        sendCommand(.getVersion)
    }

    public func requestSerialNumber() {
        sendCommand(.getSerialNumber)
    }

    public func requestStatusFlags() {
        sendCommand(.getStatusFlags)
    }

    public func setFilters() {
        sendCommand(.setAcceptanceCode(acceptanceCode))
        sendCommand(.setAcceptanceMask(acceptanceMask))
    }

    // Call this from SerialPortManager's onReceive callback
    public func processIncomingData(_ data: Data) {
        guard let text = String(data: data, encoding: .ascii) else { return }
        lineBuffer.append(text)

        while let crRange = lineBuffer.range(of: "\r") {
            let line = String(lineBuffer[..<crRange.lowerBound])
            lineBuffer = String(lineBuffer[crRange.upperBound...])

            guard !line.isEmpty else { continue }
            let response = SLCANResponse.parse(line)
            handleResponse(response, raw: line)
        }
    }

    private func sendCommand(_ command: SLCANCommand) {
        portManager?.send(string: command.commandString)
    }

    private func handleResponse(_ response: SLCANResponse, raw: String) {
        switch response {
        case .ok:
            break
        case .error:
            lastError = "Device returned error for last command"
        case .receivedStandardFrame(let id, let dlc, let data):
            postCANFrame(id: id, isExtended: false, isRemote: false, dlc: dlc, data: data)
        case .receivedExtendedFrame(let id, let dlc, let data):
            postCANFrame(id: id, isExtended: true, isRemote: false, dlc: dlc, data: data)
        case .receivedStandardRTR(let id, let dlc):
            postCANFrame(id: id, isExtended: false, isRemote: true, dlc: dlc, data: [])
        case .receivedExtendedRTR(let id, let dlc):
            postCANFrame(id: id, isExtended: true, isRemote: true, dlc: dlc, data: [])
        case .statusFlags(let flags):
            statusFlags = flags
        case .errorFrame(let code):
            NotificationCenter.default.post(name: .slcanErrorFrameReceived, object: nil, userInfo: ["code": code])
        case .version(let hw, let sw):
            deviceVersion = "HW:\(hw) SW:\(sw)"
        case .serialNumber(let sn):
            deviceSerialNumber = sn
        case .unknown:
            break
        }
    }

    private func postCANFrame(id: UInt32, isExtended: Bool, isRemote: Bool, dlc: UInt8, data: [UInt8]) {
        let frame = CANFrame(
            arbitrationID: id,
            isExtended: isExtended,
            isRemote: isRemote,
            dlc: dlc,
            data: data,
            direction: .received,
            timestamp: Date()
        )
        NotificationCenter.default.post(
            name: .slcanFrameReceived,
            object: nil,
            userInfo: ["frame": frame]
        )
    }
}

