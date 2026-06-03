import Foundation

public extension Notification.Name {
    static let serialDataReceived = Notification.Name("serialDataReceived")
    static let slcanFrameReceived = Notification.Name("slcanFrameReceived")
    static let slcanErrorFrameReceived = Notification.Name("slcanErrorFrameReceived")
    static let clearConsole = Notification.Name("clearConsole")
    static let projectImported = Notification.Name("projectImported")
    static let navigateToConnection = Notification.Name("navigateToConnection")
    static let navigateToTerminal = Notification.Name("navigateToTerminal")
    static let navigateToSLCAN = Notification.Name("navigateToSLCAN")
    static let navigateToRecorder = Notification.Name("navigateToRecorder")
    static let focusSearch = Notification.Name("focusSearch")
}
