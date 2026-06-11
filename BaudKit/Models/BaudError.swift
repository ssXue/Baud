import Foundation

/// Unified error type for Baud application
public enum BaudError: LocalizedError, Sendable {
    // Serial port errors
    case portNotFound(path: String)
    case portOpenFailed(path: String, reason: String)
    case portNotConnected
    case sendFailed(reason: String)

    // CAN/SLCAN errors
    case canChannelNotOpen
    case canCommandFailed(command: String, reason: String)
    case invalidCANFrame(raw: String)
    case invalidCANData(hex: String)

    // File/IO errors
    case fileNotFound(path: String)
    case fileReadFailed(path: String, reason: String)
    case fileWriteFailed(path: String, reason: String)
    case invalidFileFormat(expected: String)

    // DBC errors
    case dbcParseError(line: Int, reason: String)
    case dbcInvalidSignal(name: String)

    // Session errors
    case sessionNotFound(id: UUID)
    case sessionPlaybackError(reason: String)

    // Project errors
    case projectExportFailed(reason: String)
    case projectImportFailed(reason: String)
    case projectInvalidFormat

    // Export errors
    case exportFailed(reason: String)
    case exportNoData

    public var errorDescription: String? {
        switch self {
        case .portNotFound(let path):
            "Serial port not found: \(path)"
        case .portOpenFailed(let path, let reason):
            "Failed to open \(path): \(reason)"
        case .portNotConnected:
            "Not connected to a serial port"
        case .sendFailed(let reason):
            "Send failed: \(reason)"

        case .canChannelNotOpen:
            "CAN channel is not open"
        case .canCommandFailed(let cmd, let reason):
            "CAN command '\(cmd)' failed: \(reason)"
        case .invalidCANFrame(let raw):
            "Invalid CAN frame: \(raw)"
        case .invalidCANData(let hex):
            "Invalid CAN data: \(hex)"

        case .fileNotFound(let path):
            "File not found: \(path)"
        case .fileReadFailed(let path, let reason):
            "Failed to read \(path): \(reason)"
        case .fileWriteFailed(let path, let reason):
            "Failed to write \(path): \(reason)"
        case .invalidFileFormat(let expected):
            "Invalid file format, expected \(expected)"

        case .dbcParseError(let line, let reason):
            "DBC parse error at line \(line): \(reason)"
        case .dbcInvalidSignal(let name):
            "Invalid DBC signal: \(name)"

        case .sessionNotFound(let id):
            "Session not found: \(id)"
        case .sessionPlaybackError(let reason):
            "Playback error: \(reason)"

        case .projectExportFailed(let reason):
            "Project export failed: \(reason)"
        case .projectImportFailed(let reason):
            "Project import failed: \(reason)"
        case .projectInvalidFormat:
            "Invalid project file format"

        case .exportFailed(let reason):
            "Export failed: \(reason)"
        case .exportNoData:
            "No data to export"
        }
    }

    /// Whether this error should be shown to the user as an alert
    public var isUserFacing: Bool {
        switch self {
        case .portNotFound, .portOpenFailed, .portNotConnected, .sendFailed,
             .canChannelNotOpen, .canCommandFailed,
             .fileNotFound, .fileReadFailed, .fileWriteFailed, .invalidFileFormat,
             .dbcParseError,
             .projectExportFailed, .projectImportFailed, .projectInvalidFormat,
             .exportFailed, .exportNoData:
            true
        case .invalidCANFrame, .invalidCANData,
             .dbcInvalidSignal,
             .sessionNotFound, .sessionPlaybackError:
            false
        }
    }
}

// MARK: - User Alert Helper

import AppKit

extension BaudError {
    /// Show this error as a standard macOS alert
    @MainActor
    public func showAlert() {
        guard isUserFacing else { return }
        let alert = NSAlert()
        alert.messageText = "Baud"
        alert.informativeText = errorDescription ?? "Unknown error"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
