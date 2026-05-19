import SwiftUI

public struct CANSendView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SLCANManager.self) private var slcanManager

    @State private var idText = ""
    @State private var dataText = ""
    @State private var isExtended = false
    @State private var isRemote = false

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Text("Send CAN Frame")
                .font(.headline)

            Form {
                Section("Frame Configuration") {
                    LabeledContent("Arbitration ID (hex)") {
                        TextField("e.g. 123 or 00123456", text: $idText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 200)
                    }

                    LabeledContent("Format") {
                        Picker("", selection: $isExtended) {
                            Text("Standard (11-bit)").tag(false)
                            Text("Extended (29-bit)").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 280)
                    }

                    LabeledContent("Frame Type") {
                        Picker("", selection: $isRemote) {
                            Text("Data").tag(false)
                            Text("Remote (RTR)").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160)
                    }

                    if !isRemote {
                        LabeledContent("Data (hex, space-separated)") {
                            TextField("e.g. 01 02 03 AA FF", text: $dataText)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 260)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Send") { sendFrame() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 520)
    }

    private var isValid: Bool {
        guard let id = UInt32(idText, radix: 16) else { return false }
        if isExtended {
            guard id <= 0x1FFFFFFF else { return false }
        } else {
            guard id <= 0x7FF else { return false }
        }
        if !isRemote {
            guard HexFormatter.isValidHex(dataText) else { return false }
            let bytes = dataText.replacingOccurrences(of: " ", with: "")
            return bytes.count <= 16 // max 8 bytes = 16 hex chars
        }
        return true
    }

    private func sendFrame() {
        guard let id = UInt32(idText, radix: 16) else { return }

        let frame: CANFrame
        if isRemote {
            frame = CANFrame(
                arbitrationID: id,
                isExtended: isExtended,
                isRemote: true,
                dlc: 0,
                data: [],
                direction: .sent,
                timestamp: Date()
            )
        } else {
            let data = HexFormatter.hexToData(dataText)?.map { $0 } ?? []
            frame = CANFrame(
                arbitrationID: id,
                isExtended: isExtended,
                isRemote: false,
                dlc: UInt8(data.count),
                data: data,
                direction: .sent,
                timestamp: Date()
            )
        }

        slcanManager.transmitFrame(frame)
        dismiss()
    }
}
