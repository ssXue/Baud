import SwiftUI

public struct CANSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CANBackendManager.self) private var backendManager

    @State private var codeText = "00000000"
    @State private var maskText = "FFFFFFFF"

    public init() {}

    public var body: some View {
        @Bindable var backendManager = backendManager

        VStack(spacing: 16) {
            Text("CAN Settings")
                .font(.headline)

            Form {
                Section("CAN Backend") {
                    LabeledContent("Backend") {
                        Picker("", selection: $backendManager.activeBackendType) {
                            ForEach(backendManager.availableBackendTypes) { type in
                                Label(type.label, systemImage: type.systemImage).tag(type)
                            }
                        }
                        .onChange(of: backendManager.activeBackendType) { _, _ in
                            // Update bitrate if current one is not supported by new backend
                            if !backendManager.supportedBitrates.contains(backendManager.selectedBitrate) {
                                backendManager.selectedBitrate = backendManager.supportedBitrates.first ?? .bps500k
                            }
                        }
                    }
                }

                Section("CAN Bitrate") {
                    LabeledContent("Bitrate") {
                        Picker("", selection: bitrateBinding) {
                            ForEach(backendManager.supportedBitrates) { bitrate in
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

                if backendManager.activeBackendType == .pcan {
                    pcanDeviceSection
                }

                if backendManager.activeBackendType == .slcan {
                    slcanDeviceInfoSection
                }

                if let error = backendManager.lastError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    @AppStorage("developerMode") var developerMode = false
                    Toggle("Developer Mode", isOn: $developerMode)
                } header: {
                    Text("Advanced")
                } footer: {
                    Text("Enables Mock data generation for testing.")
                }
            }
            .formStyle(.grouped)

        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply") {
                    if let code = UInt32(codeText, radix: 16),
                       let mask = UInt32(maskText, radix: 16) {
                        backendManager.setFilters(code: code, mask: mask)
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.glassProminent)
            }
        }
        .frame(width: 480, height: 520)
        .onAppear {
            // Get acceptance filter from active backend
            let code: UInt32
            let mask: UInt32
            switch backendManager.activeBackendType {
            case .slcan:
                code = backendManager.slcanManager.acceptanceCode
                mask = backendManager.slcanManager.acceptanceMask
            case .pcan:
                code = backendManager.pcanBackend?.acceptanceCode ?? 0
                mask = backendManager.pcanBackend?.acceptanceMask ?? 0xFFFFFFFF
            }
            codeText = String(format: "%08X", code)
            maskText = String(format: "%08X", mask)
        }
    }

    // MARK: - SLCAN Device Info

    private var slcanDeviceInfoSection: some View {
        Section("SLCAN Device Info") {
            LabeledContent("Version") {
                HStack {
                    Text(backendManager.deviceVersion.isEmpty ? "—" : backendManager.deviceVersion)
                        .font(.system(.body, design: .monospaced))
                    Button {
                        backendManager.requestVersion()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                }
            }
            LabeledContent("Serial #") {
                HStack {
                    Text(backendManager.deviceSerialNumber.isEmpty ? "—" : backendManager.deviceSerialNumber)
                        .font(.system(.body, design: .monospaced))
                    Button {
                        backendManager.requestSerialNumber()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                }
            }
            LabeledContent("Status Flags") {
                HStack {
                    Text(String(format: "0x%02X", backendManager.statusFlags))
                        .font(.system(.body, design: .monospaced))
                    Button {
                        backendManager.requestStatusFlags()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    // MARK: - PCAN Device Section

    private var pcanDeviceSection: some View {
        Section("PCAN Device") {
            if backendManager.pcanDevices.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("No PCAN-USB device detected")
                        .foregroundStyle(.secondary)
                    Button("Rescan") {
                        backendManager.detectPCANDevices()
                    }
                }
            } else {
                LabeledContent("Device") {
                    Picker("", selection: pcanChannelBinding) {
                        ForEach(backendManager.pcanDevices) { device in
                            Text(device.name).tag(device.id)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Bindings

    private var bitrateBinding: Binding<CANBitrate> {
        Binding(
            get: { backendManager.selectedBitrate },
            set: { newBitrate in
                backendManager.selectedBitrate = newBitrate
                switch backendManager.activeBackendType {
                case .slcan:
                    backendManager.slcanManager.selectedBitrate = newBitrate
                case .pcan:
                    backendManager.pcanBackend?.selectedBitrate = newBitrate
                }
            }
        )
    }

    private var pcanChannelBinding: Binding<UInt16> {
        Binding(
            get: { backendManager.selectedPCANChannel ?? 0x0041 },
            set: { backendManager.selectedPCANChannel = $0 }
        )
    }
}
