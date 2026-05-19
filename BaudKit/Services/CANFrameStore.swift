import Foundation

public enum CANViewMode: String, CaseIterable {
    case trace
    case monitor
}

@Observable
@MainActor
public final class CANFrameStore {
    private(set) public var frames: [CANFrame] = []
    private(set) public var monitorFrames: [UInt32: CANFrame] = [:]
    public var selectedFrameID: UUID?
    public var filterText = ""
    public var viewMode: CANViewMode = .trace

    private let maxFrames = 10000

    public init() {}

    public var selectedFrame: CANFrame? {
        guard let id = selectedFrameID else { return nil }
        return frames.first { $0.id == id }
    }

    public var filteredFrames: [CANFrame] {
        guard !filterText.isEmpty else { return frames }
        let query = filterText.uppercased()
        return frames.filter { frame in
            frame.idHex.contains(query) || frame.dataHex.uppercased().contains(query)
        }
    }

    public var monitorFrameList: [CANFrame] {
        let list = monitorFrames.values.sorted { $0.timestamp > $1.timestamp }
        guard !filterText.isEmpty else { return list }
        let query = filterText.uppercased()
        return list.filter { frame in
            frame.idHex.contains(query) || frame.dataHex.uppercased().contains(query)
        }
    }

    public var frameCount: Int { frames.count }

    var framesPerSecond: Double {
        guard frames.count >= 2 else { return 0 }
        let span = frames.last!.timestamp.timeIntervalSince(frames.first!.timestamp)
        guard span > 0 else { return 0 }
        return Double(frames.count) / span
    }

    public func addFrame(_ frame: CANFrame) {
        frames.append(frame)
        if frames.count > maxFrames {
            frames.removeFirst(frames.count - maxFrames)
        }
        monitorFrames[frame.arbitrationID] = frame
    }

    public func clear() {
        frames.removeAll()
        monitorFrames.removeAll()
        selectedFrameID = nil
    }
}
