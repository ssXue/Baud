import Testing
@testable import BaudKit

@Suite("SLCANCommand.commandString")
struct SLCANCommandTests {

    @Test("Open channel")
    func openChannel() {
        #expect(SLCANCommand.openChannel.commandString == "O\r")
    }

    @Test("Close channel")
    func closeChannel() {
        #expect(SLCANCommand.closeChannel.commandString == "C\r")
    }

    @Test("Set bitrate 500k")
    func setBitrate() {
        #expect(SLCANCommand.setBitrate(.bps500k).commandString == "S6\r")
    }

    @Test("Transmit standard frame")
    func transmitStandard() {
        let cmd = SLCANCommand.transmitStandard(id: 0x123, data: [0xDE, 0xAD])
        #expect(cmd.commandString == "t1232DEAD\r")
    }

    @Test("Transmit extended frame")
    func transmitExtended() {
        let cmd = SLCANCommand.transmitExtended(id: 0x00000123, data: [0x01, 0x02, 0x03, 0x04])
        #expect(cmd.commandString == "T00000123401020304\r")
    }

    @Test("Transmit standard RTR")
    func transmitStandardRTR() {
        let cmd = SLCANCommand.transmitStandardRTR(id: 0x123, dlc: 8)
        #expect(cmd.commandString == "r1238\r")
    }

    @Test("Transmit extended RTR")
    func transmitExtendedRTR() {
        let cmd = SLCANCommand.transmitExtendedRTR(id: 0x00000123, dlc: 4)
        #expect(cmd.commandString == "R000001234\r")
    }

    @Test("Set acceptance code")
    func setAcceptanceCode() {
        let cmd = SLCANCommand.setAcceptanceCode(0x00000000)
        #expect(cmd.commandString == "M00000000\r")
    }

    @Test("Set acceptance mask")
    func setAcceptanceMask() {
        let cmd = SLCANCommand.setAcceptanceMask(0xFFFFFFFF)
        #expect(cmd.commandString == "mFFFFFFFF\r")
    }

    @Test("Get version")
    func getVersion() {
        #expect(SLCANCommand.getVersion.commandString == "V\r")
    }

    @Test("Get serial number")
    func getSerialNumber() {
        #expect(SLCANCommand.getSerialNumber.commandString == "N\r")
    }

    @Test("Get status flags")
    func getStatusFlags() {
        #expect(SLCANCommand.getStatusFlags.commandString == "F\r")
    }

    @Test("Set timestamp on")
    func setTimestampOn() {
        #expect(SLCANCommand.setTimestamp(true).commandString == "Z1\r")
    }

    @Test("Set timestamp off")
    func setTimestampOff() {
        #expect(SLCANCommand.setTimestamp(false).commandString == "Z0\r")
    }

    @Test("Set BTR")
    func setBTR() {
        let cmd = SLCANCommand.setBTR(btr0: 0x09, btr1: 0x1F)
        #expect(cmd.commandString == "s091F\r")
    }
}
