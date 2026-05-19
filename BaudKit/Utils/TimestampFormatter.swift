import Foundation

public enum TimestampFormatter {
    static let shared: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    public static func string(from date: Date) -> String {
        shared.string(from: date)
    }

    public static func delta(from earlier: Date, to later: Date) -> String {
        let interval = later.timeIntervalSince(earlier)
        if interval < 0.001 {
            return "0.000s"
        }
        return String(format: "%.3fs", interval)
    }
}
