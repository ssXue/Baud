import Foundation

public enum CANViewMode: String, CaseIterable {
    case trace
    case monitor
    case stability
}

@Observable
@MainActor
public final class CANFrameStore {
    private(set) public var frames: [CANFrame] = []
    private(set) public var monitorFrames: [UInt32: CANFrame] = [:]
    public var selectedFrameID: UUID? {
        didSet { updateSelectedFrame() }
    }
    public var filterText = "" {
        didSet {
            updateFiltered()
            UserDefaults.standard.set(filterText, forKey: "baud.canFilterText")
        }
    }
    public var viewMode: CANViewMode = .trace

    private let maxFrames = 10000

    private(set) public var filteredFrames: [CANFrame] = []
    private(set) public var monitorFrameList: [CANFrame] = []
    private(set) public var selectedFrame: CANFrame?

    public init() {
        filterText = UserDefaults.standard.string(forKey: "baud.canFilterText") ?? ""
    }

    public func addFrame(_ frame: CANFrame) {
        frames.append(frame)
        if frames.count > maxFrames {
            let dropCount = frames.count - maxFrames
            frames.removeFirst(dropCount)
        }
        monitorFrames[frame.arbitrationID] = frame
        updateFiltered()
    }

    public func clear() {
        frames.removeAll()
        monitorFrames.removeAll()
        selectedFrameID = nil
        filterText = ""
        filteredFrames = []
        monitorFrameList = []
        selectedFrame = nil
    }

    public var frameCount: Int { frames.count }

    var framesPerSecond: Double {
        guard frames.count >= 2 else { return 0 }
        let span = frames.last!.timestamp.timeIntervalSince(frames.first!.timestamp)
        guard span > 0 else { return 0 }
        return Double(frames.count) / span
    }

    private func updateFiltered() {
        let query = filterText.uppercased()
        if query.isEmpty {
            filteredFrames = frames
        } else {
            filteredFrames = frames.filter { frame in
                frame.idHex.contains(query) || frame.dataHex.uppercased().contains(query)
            }
        }

        let list = monitorFrames.values.sorted { $0.timestamp > $1.timestamp }
        if query.isEmpty {
            monitorFrameList = list
        } else {
            monitorFrameList = list.filter { frame in
                frame.idHex.contains(query) || frame.dataHex.uppercased().contains(query)
            }
        }
    }

    private func updateSelectedFrame() {
        guard let id = selectedFrameID else {
            selectedFrame = nil
            return
        }
        selectedFrame = frames.first { $0.id == id }
    }
}
