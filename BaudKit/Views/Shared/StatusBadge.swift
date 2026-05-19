import SwiftUI

public struct StatusBadge: View {
    let connected: Bool

    public init(connected: Bool) {
        self.connected = connected
    }

    public var body: some View {
        Circle()
            .fill(connected ? Color.green : Color.secondary.opacity(0.4))
            .frame(width: 10, height: 10)
            .accessibilityLabel(connected ? String(localized: "Connected") : String(localized: "Disconnected"))
    }
}

#Preview("Connected") {
    StatusBadge(connected: true)
        .padding()
}

#Preview("Disconnected") {
    StatusBadge(connected: false)
        .padding()
}
