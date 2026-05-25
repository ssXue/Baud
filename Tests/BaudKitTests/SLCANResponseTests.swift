import Testing
@testable import BaudKit

@Suite("SLCANResponse.parse")
struct SLCANResponseTests {

    @Test("Standard data frame")
    func standardFrame() {
        let result = SLCANResponse.parse("t1234DEADBEEF")
        switch result {
        case .receivedStandardFrame(let id, let dlc, let data):
            #expect(id == 0x123)
            #expect(dlc == 4)
            #expect(data == [0xDE, 0xAD, 0xBE, 0xEF])
        default:
            Issue.record("Expected receivedStandardFrame, got \(result)")
        }
    }

    @Test("Extended data frame")
    func extendedFrame() {
        let result = SLCANResponse.parse("T0000012380102030405060708")
        switch result {
        case .receivedExtendedFrame(let id, let dlc, let data):
            #expect(id == 0x00000123)
            #expect(dlc == 8)
            #expect(data == [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
        default:
            Issue.record("Expected receivedExtendedFrame, got \(result)")
        }
    }

    @Test("Standard RTR frame")
    func standardRTR() {
        let result = SLCANResponse.parse("r1238")
        switch result {
        case .receivedStandardRTR(let id, let dlc):
            #expect(id == 0x123)
            #expect(dlc == 8)
        default:
            Issue.record("Expected receivedStandardRTR, got \(result)")
        }
    }

    @Test("Extended RTR frame")
    func extendedRTR() {
        let result = SLCANResponse.parse("R000001238")
        switch result {
        case .receivedExtendedRTR(let id, let dlc):
            #expect(id == 0x00000123)
            #expect(dlc == 8)
        default:
            Issue.record("Expected receivedExtendedRTR, got \(result)")
        }
    }

    @Test("Status flags")
    func statusFlags() {
        let result = SLCANResponse.parse("F08")
        switch result {
        case .statusFlags(let flags):
            #expect(flags == 0x08)
        default:
            Issue.record("Expected statusFlags, got \(result)")
        }
    }

    @Test("Version")
    func version() {
        let result = SLCANResponse.parse("V0130")
        switch result {
        case .version(let hw, let sw):
            #expect(hw == "01")
            #expect(sw == "30")
        default:
            Issue.record("Expected version, got \(result)")
        }
    }

    @Test("Serial number")
    func serialNumber() {
        let result = SLCANResponse.parse("N12345")
        switch result {
        case .serialNumber(let sn):
            #expect(sn == "12345")
        default:
            Issue.record("Expected serialNumber, got \(result)")
        }
    }

    @Test("Error bell character")
    func error() {
        let result = SLCANResponse.parse("\u{07}")
        switch result {
        case .error:
            #expect(true)
        default:
            Issue.record("Expected error, got \(result)")
        }
    }

    @Test("Unknown input")
    func unknown() {
        let result = SLCANResponse.parse("XYZ123")
        switch result {
        case .unknown:
            #expect(true)
        default:
            Issue.record("Expected unknown, got \(result)")
        }
    }

    @Test("Empty string")
    func emptyString() {
        let result = SLCANResponse.parse("")
        switch result {
        case .unknown:
            #expect(true)
        default:
            Issue.record("Expected unknown for empty string, got \(result)")
        }
    }

    @Test("Standard frame too short")
    func standardFrameTooShort() {
        let result = SLCANResponse.parse("t12")
        switch result {
        case .unknown:
            #expect(true)
        default:
            Issue.record("Expected unknown for short standard frame, got \(result)")
        }
    }
}
