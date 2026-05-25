import Foundation

@Observable
@MainActor
public final class SessionManager {
    public var sessions: [RecordedSession] = []
    public var selectedSessionID: UUID?

    private let storageKey = "baud.recordedSessions"
    private let migrationKey = "baud.sessionsMigrated"

    private var sessionsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Baud/Sessions", isDirectory: true)
    }

    public init() {
        migrateIfNeeded()
        loadSessions()
    }

    public func addSession(_ session: RecordedSession) {
        sessions.insert(session, at: 0)
        saveSessionToFile(session)
    }

    public func deleteSession(id: UUID) {
        sessions.removeAll { $0.id == id }
        if selectedSessionID == id { selectedSessionID = nil }
        deleteSessionFile(id: id)
    }

    public var selectedSession: RecordedSession? {
        guard let id = selectedSessionID else { return nil }
        return sessions.first { $0.id == id }
    }

    private func saveSessionToFile(_ session: RecordedSession) {
        ensureDirectoryExists()
        let url = sessionsDirectory.appendingPathComponent("\(session.id.uuidString).json")
        guard let data = try? JSONEncoder().encode(session) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func deleteSessionFile(id: UUID) {
        let url = sessionsDirectory.appendingPathComponent("\(id.uuidString).json")
        try? FileManager.default.removeItem(at: url)
    }

    private func loadSessions() {
        ensureDirectoryExists()
        guard let files = try? FileManager.default.contentsOfDirectory(at: sessionsDirectory, includingPropertiesForKeys: nil) else { return }
        var loaded: [RecordedSession] = []
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let session = try? JSONDecoder().decode(RecordedSession.self, from: data) else { continue }
            loaded.append(session)
        }
        sessions = loaded.sorted { $0.createdAt > $1.createdAt }
    }

    private func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
    }

    private func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let oldSessions = try? JSONDecoder().decode([RecordedSession].self, from: data),
              !oldSessions.isEmpty else {
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        ensureDirectoryExists()
        for session in oldSessions {
            saveSessionToFile(session)
        }
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.set(true, forKey: migrationKey)
    }
}
