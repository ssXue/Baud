import Foundation

public struct SerialPortConfig: Equatable, Sendable, Codable {
    public var path: String = ""
    public var baudRate: BaudRate = .baud115200
    public var dataBits: DataBits = .eight
    public var parity: Parity = .none
    public var stopBits: StopBits = .one
    public var flowControl: FlowControl = .none

    public init() {}

    public enum BaudRate: Int, CaseIterable, Identifiable, Sendable, Codable {
        case baud9600 = 9600
        case baud19200 = 19200
        case baud38400 = 38400
        case baud57600 = 57600
        case baud115200 = 115200
        case baud230400 = 230400
        case baud460800 = 460800
        case baud921600 = 921600

        public var id: Int { rawValue }

        public var display: String {
            switch self {
            case .baud9600: "9600"
            case .baud19200: "19.2K"
            case .baud38400: "38.4K"
            case .baud57600: "57.6K"
            case .baud115200: "115.2K"
            case .baud230400: "230.4K"
            case .baud460800: "460.8K"
            case .baud921600: "921.6K"
            }
        }
    }

    public enum DataBits: Int, CaseIterable, Identifiable, Sendable, Codable {
        case five = 5
        case six = 6
        case seven = 7
        case eight = 8

        public var id: Int { rawValue }
        public var display: String { "\(rawValue)" }
    }

    public enum Parity: String, CaseIterable, Identifiable, Sendable, Codable {
        case none = "None"
        case odd = "Odd"
        case even = "Even"

        public var id: String { rawValue }
    }

    public enum StopBits: Int, CaseIterable, Identifiable, Sendable, Codable {
        case one = 1
        case two = 2

        public var id: Int { rawValue }
        public var display: String { "\(rawValue)" }
    }

    public enum FlowControl: String, CaseIterable, Identifiable, Sendable, Codable {
        case none = "None"
        case rtsCts = "RTS/CTS"
        case xonXoff = "XON/XOFF"

        public var id: String { rawValue }
    }
}
