import Foundation

public extension Notification.Name {
    static let serialDataReceived = Notification.Name("serialDataReceived")
    static let canFrameReceived = Notification.Name("canFrameReceived")
    static let canErrorFrameReceived = Notification.Name("canErrorFrameReceived")
    static let clearConsole = Notification.Name("clearConsole")
    static let projectImported = Notification.Name("projectImported")
    static let navigateToConnection = Notification.Name("navigateToConnection")
    static let navigateToTerminal = Notification.Name("navigateToTerminal")
    static let navigateToSLCAN = Notification.Name("navigateToSLCAN")
    static let navigateToRecorder = Notification.Name("navigateToRecorder")
    static let focusSearch = Notification.Name("focusSearch")

    // Legacy aliases for backward compatibility
    static let slcanFrameReceived = Notification.Name("canFrameReceived")
    static let slcanErrorFrameReceived = Notification.Name("canErrorFrameReceived")
}
