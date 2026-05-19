import SwiftUI

public struct CANFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SLCANManager.self) private var slcanManager

    @State private var codeText = "00000000"
    @State private var maskText = "FFFFFFFF"

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Text("CAN Acceptance Filter")
                .font(.headline)

            Form {
                Section("Acceptance Code") {
                    TextField("Hex value (8 chars)", text: $codeText)
                        .font(.system(.body, design: .monospaced))
                }
                Section("Acceptance Mask") {
                    TextField("Hex value (8 chars)", text: $maskText)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
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
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 400, height: 280)
    }
}
