import SwiftUI

public struct SLCANCommandPadView: View {
    @Environment(SLCANManager.self) private var slcanManager
    @Environment(CANFrameStore.self) private var frameStore

    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            Text("Quick Commands")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 8) {
                CommandButton(title: "Open CAN", icon: "play.circle") {
                    slcanManager.openChannel()
                }
                CommandButton(title: "Close CAN", icon: "stop.circle") {
                    slcanManager.closeChannel()
                }
                CommandButton(title: "Version", icon: "info.circle") {
                    slcanManager.requestVersion()
                }
                CommandButton(title: "Serial #", icon: "number.circle") {
                    slcanManager.requestSerialNumber()
                }
                CommandButton(title: "Status", icon: "flag.checkered") {
                    slcanManager.requestStatusFlags()
                }
                CommandButton(title: "Clear Log", icon: "trash") {
                    frameStore.clear()
                }
            }
        }
        .padding()
    }
}

private struct CommandButton: View {
    let title: LocalizedStringResource
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
        .controlSize(.regular)
    }
}
