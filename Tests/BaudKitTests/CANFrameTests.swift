import Testing
import Foundation
@testable import BaudKit

@Suite("CANFrame formatting")
struct CANFrameTests {

    @Test("idHex for standard frame")
    func idHexStandard() {
        let frame = CANFrame(
            arbitrationID: 0x123,
            isExtended: false,
            isRemote: false,
            dlc: 8,
            data: [],
            direction: .received,
            timestamp: Date()
        )
        #expect(frame.idHex == "123")
    }

    @Test("idHex for extended frame")
    func idHexExtended() {
        let frame = CANFrame(
            arbitrationID: 0x12345678,
            isExtended: true,
            isRemote: false,
            dlc: 8,
            data: [],
            direction: .received,
            timestamp: Date()
        )
        #expect(frame.idHex == "12345678")
    }

    @Test("dataHex truncates to dlc")
    func dataHexTruncated() {
        let frame = CANFrame(
            arbitrationID: 0x100,
            isExtended: false,
            isRemote: false,
            dlc: 3,
            data: [0xDE, 0xAD, 0xBE, 0xEF],
            direction: .received,
            timestamp: Date()
        )
        #expect(frame.dataHex == "DE AD BE")
    }

    @Test("frameType for standard frame")
    func frameTypeStandard() {
        let frame = CANFrame(
            arbitrationID: 0x100,
            isExtended: false,
            isRemote: false,
            dlc: 0,
            data: [],
            direction: .received,
            timestamp: Date()
        )
        #expect(frame.frameType == "STD")
    }

    @Test("frameType for extended frame")
    func frameTypeExtended() {
        let frame = CANFrame(
            arbitrationID: 0x100,
            isExtended: true,
            isRemote: false,
            dlc: 0,
            data: [],
            direction: .received,
            timestamp: Date()
        )
        #expect(frame.frameType == "EXT")
    }

    @Test("frameType for RTR frame")
    func frameTypeRTR() {
        let frame = CANFrame(
            arbitrationID: 0x100,
            isExtended: false,
            isRemote: true,
            dlc: 0,
            data: [],
            direction: .received,
            timestamp: Date()
        )
        #expect(frame.frameType == "RTR")
    }

    @Test("direction label")
    func directionLabel() {
        #expect(CANFrame.Direction.sent.label == "TX")
        #expect(CANFrame.Direction.received.label == "RX")
    }
}
