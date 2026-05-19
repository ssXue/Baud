import SwiftUI

public enum NavigationPage: String, CaseIterable, Identifiable {
    case connection
    case terminal
    case slcan
    case recorder

    public var id: String { rawValue }

    public var label: LocalizedStringResource {
        switch self {
        case .terminal: "Terminal"
        case .slcan: "SLCAN"
        case .connection: "Connection"
        case .recorder: "Recorder"
        }
    }

    public var systemImage: String {
        switch self {
        case .terminal: "terminal"
        case .slcan: "bus"
        case .connection: "externaldrive.connected.to.line.below"
        case .recorder: "record.circle"
        }
    }
}

public struct ContentView: View {
    @Environment(SerialPortManager.self) private var portManager
    @State private var selectedPage: NavigationPage = .connection

    public init() {}

    public var body: some View {
        NavigationSplitView {
            List(NavigationPage.allCases, selection: $selectedPage) { page in
                if page == .connection {
                    Label {
                        HStack(spacing: 6) {
                            Text(page.label)
                            StatusBadge(connected: portManager.isConnected)
                        }
                    } icon: {
                        Image(systemName: page.systemImage)
                    }
                    .tag(page)
                } else {
                    Label(page.label, systemImage: page.systemImage)
                        .tag(page)
                }
            }
            .navigationTitle("Baud")
            .listStyle(.sidebar)
        } detail: {
            switch selectedPage {
            case .connection:
                ConnectionConfigView()
            case .terminal:
                SerialTerminalView()
            case .slcan:
                SLCANDebuggerView()
            case .recorder:
                RecorderView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(SerialPortManager())
        .environment(SerialDataManager())
        .environment(SLCANManager())
        .environment(CANFrameStore())
        .environment(CANSignalStore())
}
