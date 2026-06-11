import Foundation

public struct SerialPreset: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var baudRate: SerialPortConfig.BaudRate
    public var dataBits: SerialPortConfig.DataBits
    public var parity: SerialPortConfig.Parity
    public var stopBits: SerialPortConfig.StopBits
    public var flowControl: SerialPortConfig.FlowControl

    public init(
        name: String,
        baudRate: SerialPortConfig.BaudRate,
        dataBits: SerialPortConfig.DataBits,
        parity: SerialPortConfig.Parity,
        stopBits: SerialPortConfig.StopBits,
        flowControl: SerialPortConfig.FlowControl
    ) {
        self.id = UUID()
        self.name = name
        self.baudRate = baudRate
        self.dataBits = dataBits
        self.parity = parity
        self.stopBits = stopBits
        self.flowControl = flowControl
    }

    public init(from config: SerialPortConfig, name: String) {
        self.id = UUID()
        self.name = name
        self.baudRate = config.baudRate
        self.dataBits = config.dataBits
        self.parity = config.parity
        self.stopBits = config.stopBits
        self.flowControl = config.flowControl
    }

    public var summary: String {
        "\(baudRate.display) \(dataBits.display)\(parity.rawValue.prefix(1))\(stopBits.display) \(flowControl.rawValue)"
    }
}

@Observable
@MainActor
public final class SerialPresetStore {
    public var presets: [SerialPreset] = [] {
        didSet { saveToDefaults() }
    }

    private let storageKey = "baud.serialPresets"

    public init() {
        loadFromDefaults()
    }

    public func addPreset(_ preset: SerialPreset) {
        presets.append(preset)
    }

    public func removePreset(id: UUID) {
        presets.removeAll { $0.id == id }
    }

    public func updatePreset(_ preset: SerialPreset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
        }
    }

    private func saveToDefaults() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadFromDefaults() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SerialPreset].self, from: data) else { return }
        presets = decoded
    }
}
