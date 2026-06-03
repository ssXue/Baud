import Foundation

public struct BaudProject: Codable {
    public var serialConfig: Data?
    public var displayMode: String?
    public var hexMode: Bool?
    public var lineEnding: String?
    public var autoSendInterval: String?
    public var canSignals: Data?
    public var canTxMessages: Data?
    public var protocolDefinitions: Data?
    public var quickSendSnippets: Data?
    public var version: Int = 1
}

public extension Notification.Name {
    static let projectImported = Notification.Name("projectImported")
}

@Observable
@MainActor
public final class ProjectManager {
    public init() {}

    public func exportProject(to url: URL) throws {
        let defaults = UserDefaults.standard
        let project = BaudProject(
            serialConfig: defaults.data(forKey: "baud.serialConfig"),
            displayMode: defaults.string(forKey: "baud.displayMode"),
            hexMode: defaults.object(forKey: "baud.hexMode") as? Bool,
            lineEnding: defaults.string(forKey: "baud.lineEnding"),
            autoSendInterval: defaults.string(forKey: "baud.autoSendInterval"),
            canSignals: defaults.data(forKey: "baud.canSignals"),
            canTxMessages: defaults.data(forKey: "canTxMessages"),
            protocolDefinitions: defaults.data(forKey: "baud.protocolDefinitions"),
            quickSendSnippets: defaults.data(forKey: "quickSendSnippets")
        )
        let data = try JSONEncoder().encode(project)
        try data.write(to: url, options: .atomic)
    }

    public func importProject(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let project = try JSONDecoder().decode(BaudProject.self, from: data)
        let defaults = UserDefaults.standard

        if let v = project.serialConfig { defaults.set(v, forKey: "baud.serialConfig") }
        if let v = project.displayMode { defaults.set(v, forKey: "baud.displayMode") }
        if let v = project.hexMode { defaults.set(v, forKey: "baud.hexMode") }
        if let v = project.lineEnding { defaults.set(v, forKey: "baud.lineEnding") }
        if let v = project.autoSendInterval { defaults.set(v, forKey: "baud.autoSendInterval") }
        if let v = project.canSignals { defaults.set(v, forKey: "baud.canSignals") }
        if let v = project.canTxMessages { defaults.set(v, forKey: "canTxMessages") }
        if let v = project.protocolDefinitions { defaults.set(v, forKey: "baud.protocolDefinitions") }
        if let v = project.quickSendSnippets { defaults.set(v, forKey: "quickSendSnippets") }

        NotificationCenter.default.post(name: .projectImported, object: nil)
    }
}
