import Foundation

public struct RecordedEvent: Codable, Identifiable, Sendable {
    public let id: UUID
    public let offsetMs: Int64
    public let direction: Direction
    public let data: Data
    public var eventType: EventType
    public var canFrameData: Data?

    public enum Direction: String, Codable, Sendable {
        case sent
        case received
    }

    public enum EventType: String, Codable, Sendable {
        case serial
        case can
    }

    public init(offsetMs: Int64, direction: Direction, data: Data, eventType: EventType = .serial, canFrameData: Data? = nil) {
        self.id = UUID()
        self.offsetMs = offsetMs
        self.direction = direction
        self.data = data
        self.eventType = eventType
        self.canFrameData = canFrameData
    }

    /// 向后兼容：旧数据没有 eventType 字段时默认为 serial
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        offsetMs = try container.decode(Int64.self, forKey: .offsetMs)
        direction = try container.decode(Direction.self, forKey: .direction)
        data = try container.decode(Data.self, forKey: .data)
        eventType = (try? container.decode(EventType.self, forKey: .eventType)) ?? .serial
        canFrameData = try? container.decodeIfPresent(Data.self, forKey: .canFrameData)
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
