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
    @State private var canBusAnalyzer = CANBusAnalyzer()
    @State private var sessionRecorder = SessionRecorder()
    @State private var sessionManager = SessionManager()
    @State private var canTxStore = CANTxStore()
    @State private var projectManager = ProjectManager()

    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
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
                .environment(canBusAnalyzer)
                .environment(sessionRecorder)
                .environment(sessionManager)
                .environment(canTxStore)
                .environment(projectManager)
                .task {
                    slcanManager.configure(with: portManager)
                    canTxStore.configure(with: slcanManager)
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
            BaudCommands(updater: updaterController.updater, projectManager: projectManager)
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
    let projectManager: ProjectManager

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Clear Console") {
                NotificationCenter.default.post(name: .clearConsole, object: nil)
            }
            .keyboardShortcut("k", modifiers: .command)
        }
        CommandGroup(replacing: .saveItem) {
            Button("Save Project...") {
                saveProject()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            Button("Open Project...") {
                openProject()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
        }
        CommandMenu("Navigation") {
            Button("Connection") {
                NotificationCenter.default.post(name: .navigateToConnection, object: nil)
            }
            .keyboardShortcut("1", modifiers: .command)
            Button("Terminal") {
                NotificationCenter.default.post(name: .navigateToTerminal, object: nil)
            }
            .keyboardShortcut("2", modifiers: .command)
            Button("SLCAN") {
                NotificationCenter.default.post(name: .navigateToSLCAN, object: nil)
            }
            .keyboardShortcut("3", modifiers: .command)
            Button("Recorder") {
                NotificationCenter.default.post(name: .navigateToRecorder, object: nil)
            }
            .keyboardShortcut("4", modifiers: .command)
        }
        CommandGroup(after: .toolbar) {
            Button("Find...") {
                NotificationCenter.default.post(name: .focusSearch, object: nil)
            }
            .keyboardShortcut("f", modifiers: .command)
        }
        CommandMenu("Help") {
            Button("Check for Updates...") {
                updater.checkForUpdates()
            }
        }
    }

    private func saveProject() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "baud")!]
        panel.nameFieldStringValue = "BaudProject.baud"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? projectManager.exportProject(to: url)
    }

    private func openProject() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "baud")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? projectManager.importProject(from: url)
    }
}
