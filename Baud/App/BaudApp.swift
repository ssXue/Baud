import SwiftUI
import BaudKit
import Sparkle

@main
struct BaudApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var portManager = SerialPortManager()
    @State private var serialDataManager = SerialDataManager()
    @State private var slcanManager = SLCANManager()
    @State private var canFrameStore = CANFrameStore()
    @State private var canSignalStore = CANSignalStore()
    @State private var sessionRecorder = SessionRecorder()
    @State private var sessionManager = SessionManager()

    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(portManager)
                .environment(serialDataManager)
                .environment(slcanManager)
                .environment(canFrameStore)
                .environment(canSignalStore)
                .environment(sessionRecorder)
                .environment(sessionManager)
                .task {
                    slcanManager.configure(with: portManager)
                    portManager.onReceive = { data in
                        Task { @MainActor in
                            serialDataManager.appendReceived(data: data)
                            slcanManager.processIncomingData(data)
                        }
                    }
                }
        }
        .defaultSize(width: 960, height: 640)
        .commands {
            BaudCommands(updater: updaterController.updater)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        return true
    }
}

struct BaudCommands: Commands {
    let updater: SPUUpdater

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Clear Console") {
                NotificationCenter.default.post(name: .clearConsole, object: nil)
            }
            .keyboardShortcut("k", modifiers: .command)
        }
        CommandMenu("Help") {
            Button("Check for Updates...") {
                updater.checkForUpdates()
            }
        }
    }
}
