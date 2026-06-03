import Foundation

/// 差异比对的单条记录
public struct DiffEntry: Sendable {
    public let data: Data
    public let direction: SerialMessage.Direction
    public let timestamp: Date

    public init(data: Data, direction: SerialMessage.Direction, timestamp: Date) {
        self.data = data
        self.direction = direction
        self.timestamp = timestamp
    }
}

/// 单行差异结果
public struct DataDiffResult: Identifiable, Sendable {
    public let id = UUID()
    public let index: Int
    public let left: DiffEntry?
    public let right: DiffEntry?
    public let type: DiffType

    public enum DiffType: Sendable {
        case match      // 两边相同
        case mismatch   // 两边不同
        case leftOnly   // 只有左边有
        case rightOnly  // 只有右边有
    }
}

/// 差异比对计算
public enum DataDiff {
    /// 比较两个消息列表（按序号一一对照）
    public static func diff(left: [SerialMessage], right: [SerialMessage]) -> [DataDiffResult] {
        let maxCount = max(left.count, right.count)
        var results: [DataDiffResult] = []
        results.reserveCapacity(maxCount)

        for i in 0..<maxCount {
            let l = i < left.count ? left[i] : nil
            let r = i < right.count ? right[i] : nil

            let diffType: DataDiffResult.DiffType
            if let l, let r {
                diffType = l.data == r.data ? .match : .mismatch
            } else if l != nil {
                diffType = .leftOnly
            } else {
                diffType = .rightOnly
            }

            results.append(DataDiffResult(
                index: i,
                left: l.map { DiffEntry(data: $0.data, direction: $0.direction, timestamp: $0.timestamp) },
                right: r.map { DiffEntry(data: $0.data, direction: $0.direction, timestamp: $0.timestamp) },
                type: diffType
            ))
        }
        return results
    }
}
