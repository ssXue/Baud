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
        case .slcan: "CAN"
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
    @State private var selectedPage: NavigationPage = {
        if let raw = UserDefaults.standard.string(forKey: "baud.selectedPage"),
           let page = NavigationPage(rawValue: raw) {
            return page
        }
        return .connection
    }()

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
            .navigationSplitViewColumnWidth(180)
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
        .onReceive(NotificationCenter.default.publisher(for: .navigateToConnection)) { _ in
            selectedPage = .connection
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToTerminal)) { _ in
            selectedPage = .terminal
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToSLCAN)) { _ in
            selectedPage = .slcan
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToRecorder)) { _ in
            selectedPage = .recorder
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusSearch)) { _ in
            NotificationCenter.default.post(
                name: Notification.Name("focusSearch_\(selectedPage.rawValue)"),
                object: nil
            )
        }
        .onChange(of: selectedPage) { _, new in
            UserDefaults.standard.set(new.rawValue, forKey: "baud.selectedPage")
        }
    }
}

#Preview {
    ContentView()
        .environment(SerialPortManager())
        .environment(SerialDataManager())
        .environment(CANBackendManager())
        .environment(CANFrameStore())
        .environment(CANSignalStore())
        .environment(CANBusAnalyzer())
}
