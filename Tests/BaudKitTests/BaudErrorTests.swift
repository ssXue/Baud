import Testing
import Foundation
@testable import BaudKit

@Suite("BaudError")
struct BaudErrorTests {

    @Test("All cases have non-empty error descriptions")
    func allHaveDescriptions() {
        let errors: [BaudError] = [
            .portNotFound(path: "/dev/test"),
            .portOpenFailed(path: "/dev/test", reason: "busy"),
            .portNotConnected,
            .sendFailed(reason: "timeout"),
            .canChannelNotOpen,
            .canCommandFailed(command: "O", reason: "error"),
            .invalidCANFrame(raw: "T123"),
            .invalidCANData(hex: "ZZ"),
            .fileNotFound(path: "/tmp/test"),
            .fileReadFailed(path: "/tmp/test", reason: "permission"),
            .fileWriteFailed(path: "/tmp/test", reason: "disk full"),
            .invalidFileFormat(expected: "baud"),
            .dbcParseError(line: 10, reason: "bad format"),
            .dbcInvalidSignal(name: "Test"),
            .sessionNotFound(id: UUID()),
            .sessionPlaybackError(reason: "corrupt"),
            .projectExportFailed(reason: "encode error"),
            .projectImportFailed(reason: "bad data"),
            .projectInvalidFormat,
            .exportFailed(reason: "no data"),
            .exportNoData
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("isUserFacing classification is correct")
    func userFacingClassification() {
        #expect(BaudError.portNotConnected.isUserFacing == true)
        #expect(BaudError.canChannelNotOpen.isUserFacing == true)
        #expect(BaudError.exportNoData.isUserFacing == true)
        #expect(BaudError.projectInvalidFormat.isUserFacing == true)

        #expect(BaudError.invalidCANFrame(raw: "").isUserFacing == false)
        #expect(BaudError.invalidCANData(hex: "").isUserFacing == false)
        #expect(BaudError.sessionNotFound(id: UUID()).isUserFacing == false)
        #expect(BaudError.dbcInvalidSignal(name: "").isUserFacing == false)
    }
}

@Suite("SerialPreset")
struct SerialPresetTests {

    @Test("Creates preset from SerialPortConfig")
    func fromConfig() {
        var config = SerialPortConfig()
        config.baudRate = .baud115200
        config.dataBits = .eight
        config.parity = .none
        config.stopBits = .one
        config.flowControl = .rtsCts

        let preset = SerialPreset(from: config, name: "Fast UART")
        #expect(preset.name == "Fast UART")
        #expect(preset.baudRate == .baud115200)
        #expect(preset.dataBits == .eight)
        #expect(preset.flowControl == .rtsCts)
    }

    @Test("Summary string format")
    func summary() {
        let preset = SerialPreset(
            name: "Test",
            baudRate: .baud9600,
            dataBits: .seven,
            parity: .even,
            stopBits: .two,
            flowControl: .xonXoff
        )
        #expect(preset.summary.contains("9600"))
        #expect(preset.summary.contains("7"))
        #expect(preset.summary.contains("XON/XOFF"))
    }

    @Test("Preset store add and remove")
    @MainActor
    func storeCRUD() async {
        let store = SerialPresetStore()
        #expect(store.presets.isEmpty)

        let preset = SerialPreset(name: "P1", baudRate: .baud115200, dataBits: .eight, parity: .none, stopBits: .one, flowControl: .none)
        store.addPreset(preset)
        #expect(store.presets.count == 1)

        store.removePreset(id: preset.id)
        #expect(store.presets.isEmpty)
    }
}
