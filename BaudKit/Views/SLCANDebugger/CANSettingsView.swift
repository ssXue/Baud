import SwiftUI

public struct CANSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SLCANManager.self) private var slcanManager

    @State private var codeText = "00000000"
    @State private var maskText = "FFFFFFFF"

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Text("CAN Settings")
                .font(.headline)

            Form {
                Section("CAN Bitrate") {
                    @Bindable var slcanManager = slcanManager
                    LabeledContent("Bitrate") {
                        Picker("", selection: $slcanManager.selectedBitrate) {
                            ForEach(SLCANBitrate.allCases) { bitrate in
                                Text(bitrate.display).tag(bitrate)
                            }
                        }
                    }
                }

                Section("CAN Acceptance Filter") {
                    LabeledContent("Acceptance Code") {
                        TextField("Hex value (8 chars)", text: $codeText)
                            .font(.system(.body, design: .monospaced))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 140)
                    }
                    LabeledContent("Acceptance Mask") {
                        TextField("Hex value (8 chars)", text: $maskText)
                            .font(.system(.body, design: .monospaced))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 140)
                    }
                }

                Section("Device Info") {
                    LabeledContent("Version") {
                        HStack {
                            Text(slcanManager.deviceVersion.isEmpty ? "—" : slcanManager.deviceVersion)
                                .font(.system(.body, design: .monospaced))
                            Button {
                                slcanManager.requestVersion()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    LabeledContent("Serial #") {
                        HStack {
                            Text(slcanManager.deviceSerialNumber.isEmpty ? "—" : slcanManager.deviceSerialNumber)
                                .font(.system(.body, design: .monospaced))
                            Button {
                                slcanManager.requestSerialNumber()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    LabeledContent("Status Flags") {
                        HStack {
                            Text(String(format: "0x%02X", slcanManager.statusFlags))
                                .font(.system(.body, design: .monospaced))
                            Button {
                                slcanManager.requestStatusFlags()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                if let error = slcanManager.lastError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Apply") {
                    if let code = UInt32(codeText, radix: 16),
                       let mask = UInt32(maskText, radix: 16) {
                        slcanManager.acceptanceCode = code
                        slcanManager.acceptanceMask = mask
                        slcanManager.setFilters()
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 480, height: 440)
        .onAppear {
            codeText = String(format: "%08X", slcanManager.acceptanceCode)
            maskText = String(format: "%08X", slcanManager.acceptanceMask)
        }
    }
}
