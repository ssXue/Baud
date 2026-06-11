import SwiftUI

public struct CANFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CANBackendManager.self) private var backendManager

    @State private var codeText = UserDefaults.standard.string(forKey: "baud.canAcceptanceCode") ?? "00000000"
    @State private var maskText = UserDefaults.standard.string(forKey: "baud.canAcceptanceMask") ?? "FFFFFFFF"

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

        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply") {
                    if let code = UInt32(codeText, radix: 16),
                       let mask = UInt32(maskText, radix: 16) {
                        backendManager.setFilters(code: code, mask: mask)
                        UserDefaults.standard.set(codeText, forKey: "baud.canAcceptanceCode")
                        UserDefaults.standard.set(maskText, forKey: "baud.canAcceptanceMask")
                    }
                    dismiss()
                }
                .buttonStyle(.glassProminent)
            }
        }
        }
        .frame(width: 400, height: 280)
    }
}
