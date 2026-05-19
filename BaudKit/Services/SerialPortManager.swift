import Foundation
import ORSSerial

@Observable
@MainActor
public final class SerialPortManager: NSObject, @unchecked Sendable {
    public var availablePorts: [ORSSerialPort] = []
    public var isConnected = false
    public var selectedPortPath: String? {
        didSet { UserDefaults.standard.set(selectedPortPath, forKey: "baud.selectedPortPath") }
    }
    public var config = SerialPortConfig() {
        didSet {
            if let data = try? JSONEncoder().encode(config) {
                UserDefaults.standard.set(data, forKey: "baud.serialConfig")
            }
        }
    }

    private var serialPort: ORSSerialPort?
    private var portPollingTimer: Timer?

    public override init() {
        super.init()
        loadSavedConfig()
        refreshPorts()
        startPortPolling()
    }

    private func loadSavedConfig() {
        if let data = UserDefaults.standard.data(forKey: "baud.serialConfig"),
           let saved = try? JSONDecoder().decode(SerialPortConfig.self, from: data) {
            config = saved
        }
        selectedPortPath = UserDefaults.standard.string(forKey: "baud.selectedPortPath")
    }

    public func refreshPorts() {
        availablePorts = ORSSerialPortManager.shared().availablePorts
            .sorted { $0.name < $1.name }
    }

    public func connect() {
        guard !isConnected else { return }
        guard let path = selectedPortPath else { return }

        let port = ORSSerialPort(path: path)
        port?.baudRate = NSNumber(value: config.baudRate.rawValue)
        port?.parity = config.parity.orssParity
        port?.numberOfStopBits = UInt(config.stopBits.rawValue)
        port?.numberOfDataBits = UInt(config.dataBits.rawValue)
        port?.usesRTSCTSFlowControl = config.flowControl == .rtsCts
        port?.delegate = self
        port?.open()

        serialPort = port
        isConnected = port?.isOpen ?? false
    }

    public func disconnect() {
        serialPort?.close()
        serialPort?.delegate = nil
        serialPort = nil
        isConnected = false
    }

    public func send(data: Data) {
        serialPort?.send(data)
    }

    public func send(string: String) {
        guard let data = string.data(using: .ascii) else { return }
        send(data: data)
    }

    public var onReceive: (@Sendable (Data) -> Void)?

    private func startPortPolling() {
        portPollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPorts()
            }
        }
    }
}

// MARK: - ORSSerialPortDelegate

extension SerialPortManager: ORSSerialPortDelegate {
    nonisolated public func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        Task { @MainActor in
            onReceive?(data)
        }
    }

    nonisolated public func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        Task { @MainActor in
            disconnect()
        }
    }

    nonisolated public func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
        Task { @MainActor in
            disconnect()
        }
    }
}

// MARK: - Config conversions

extension SerialPortConfig.Parity {
    var orssParity: ORSSerialPortParity {
        switch self {
        case .none: .none
        case .odd: .odd
        case .even: .even
        }
    }
}
