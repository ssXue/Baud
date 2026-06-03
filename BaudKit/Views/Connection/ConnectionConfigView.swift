import SwiftUI

public struct ConnectionConfigView: View {
    @Environment(SerialPortManager.self) private var portManager

    public init() {}

    public var body: some View {
        @Bindable var portManager = portManager
        VStack(spacing: 0) {
            ConnectionHeroAnimation(config: portManager.config, isConnected: portManager.isConnected)
                .frame(height: 120)
                .padding(.horizontal, 24)
                .padding(.top, 16)

            Form {
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
    }
}
