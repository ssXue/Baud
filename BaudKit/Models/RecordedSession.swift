import Foundation

public struct RecordedEvent: Codable, Identifiable, Sendable {
    public let id: UUID
    public let offsetMs: Int64
    public let direction: Direction
    public let data: Data

    public enum Direction: String, Codable, Sendable {
        case sent
        case received
    }

    public init(offsetMs: Int64, direction: Direction, data: Data) {
        self.id = UUID()
        self.offsetMs = offsetMs
        self.direction = direction
        self.data = data
    }
}

public struct RecordedSession: Codable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let createdAt: Date
    public let portName: String
    public let events: [RecordedEvent]

    public init(name: String, portName: String, events: [RecordedEvent]) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.portName = portName
        self.events = events
    }

    public var durationMs: Int64 {
        events.last?.offsetMs ?? 0
    }

    public var eventCount: Int {
        events.count
    }
}
