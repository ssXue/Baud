import Foundation

@Observable
@MainActor
public final class SessionManager {
    public var sessions: [RecordedSession] = []
    public var selectedSessionID: UUID?

    private let storageKey = "baud.recordedSessions"

    public init() {
        loadSessions()
    }

    public func addSession(_ session: RecordedSession) {
        sessions.insert(session, at: 0)
        saveSessions()
    }

    public func deleteSession(id: UUID) {
        sessions.removeAll { $0.id == id }
        if selectedSessionID == id { selectedSessionID = nil }
        saveSessions()
    }

    public var selectedSession: RecordedSession? {
        guard let id = selectedSessionID else { return nil }
        return sessions.first { $0.id == id }
    }

    private func saveSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([RecordedSession].self, from: data) else { return }
        sessions = decoded
    }
}
