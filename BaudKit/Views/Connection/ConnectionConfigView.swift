import SwiftUI

public struct ConnectionConfigView: View {
    @Environment(SerialPortManager.self) private var portManager
    @Environment(SerialPresetStore.self) private var presetStore
    @State private var showSavePreset = false
    @State private var presetName = ""

    public init() {}

    public var body: some View {
        @Bindable var portManager = portManager
        VStack(spacing: 0) {
            ConnectionHeroAnimation(config: portManager.config, isConnected: portManager.isConnected)
                .frame(height: 120)
                .padding(.horizontal, 24)
                .padding(.top, 16)

            Form {
                if !presetStore.presets.isEmpty {
                    Section("Presets") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(presetStore.presets) { preset in
                                    PresetChip(preset: preset) {
                                        applyPreset(preset)
                                    } onDelete: {
                                        presetStore.removePreset(id: preset.id)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Port") {
                    LabeledContent("Port") {
                        HStack {
                            Picker("", selection: $portManager.selectedPortPath) {
                                Text("None").tag(String?.none)
                                ForEach(portManager.availablePorts, id: \.path) { port in
                                    Text("\(port.name) (\(port.path))").tag(Optional(port.path))
                                }
                            }
                            Button {
                                portManager.refreshPorts()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .help("Refresh port list")
                        }
                    }
                }

                Section("Serial Configuration") {
                    LabeledContent("Baud Rate") {
                        Picker("", selection: $portManager.config.baudRate) {
                            ForEach(SerialPortConfig.BaudRate.allCases) { rate in
                                Text(rate.display).tag(rate)
                            }
                        }
                    }

                    LabeledContent("Data Bits") {
                        Picker("", selection: $portManager.config.dataBits) {
                            ForEach(SerialPortConfig.DataBits.allCases) { bits in
                                Text(bits.display).tag(bits)
                            }
                        }
                    }

                    LabeledContent("Parity") {
                        Picker("", selection: $portManager.config.parity) {
                            ForEach(SerialPortConfig.Parity.allCases) { p in
                                Text(p.rawValue).tag(p)
                            }
                        }
                    }

                    LabeledContent("Stop Bits") {
                        Picker("", selection: $portManager.config.stopBits) {
                            ForEach(SerialPortConfig.StopBits.allCases) { bits in
                                Text(bits.display).tag(bits)
                            }
                        }
                    }

                    LabeledContent("Flow Control") {
                        Picker("", selection: $portManager.config.flowControl) {
                            ForEach(SerialPortConfig.FlowControl.allCases) { fc in
                                Text(fc.rawValue).tag(fc)
                            }
                        }
                    }
                }

                Section {
                    HStack {
                        if portManager.isConnected {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            if let path = portManager.selectedPortPath,
                               let port = portManager.availablePorts.first(where: { $0.path == path }) {
                                Text("Connected to \(port.name)")
                                    .font(.headline)
                            } else {
                                Text("Connected")
                                    .font(.headline)
                            }
                        } else {
                            Text("")
                        }
                        Spacer()
                        Button {
                            showSavePreset = true
                        } label: {
                            Image(systemName: "text.badge.plus")
                        }
                        .help("Save current config as preset")

                        if portManager.isConnected {
                            Button("Disconnect", role: .destructive) {
                                portManager.disconnect()
                            }
                        } else {
                            Button("Connect") {
                                portManager.connect()
                            }
                            .buttonStyle(.glassProminent)
                            .disabled(portManager.selectedPortPath == nil)
                        }
                    }
                }

            }
            .formStyle(.grouped)
        }
        .navigationTitle("Connection")
        .alert("Save Preset", isPresented: $showSavePreset) {
            TextField("Name", text: $presetName)
            Button("Save") {
                let preset = SerialPreset(from: portManager.config, name: presetName.isEmpty ? portManager.config.baudRate.display : presetName)
                presetStore.addPreset(preset)
                presetName = ""
            }
            Button("Cancel", role: .cancel) {
                presetName = ""
            }
        } message: {
            Text("Save current serial configuration as a preset")
        }
    }

    private func applyPreset(_ preset: SerialPreset) {
        portManager.config.baudRate = preset.baudRate
        portManager.config.dataBits = preset.dataBits
        portManager.config.parity = preset.parity
        portManager.config.stopBits = preset.stopBits
        portManager.config.flowControl = preset.flowControl
    }
}

private struct PresetChip: View {
    let preset: SerialPreset
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button {
                onSelect()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .font(.system(.caption, weight: .medium))
                        .lineLimit(1)
                    Text(preset.summary)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(.caption2))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .background(.quaternary, in: Capsule())
    }
}
