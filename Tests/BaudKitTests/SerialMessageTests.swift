import Testing
import Foundation
@testable import BaudKit

@Suite("SerialMessage formatting")
struct SerialMessageTests {

    @Test("hexString produces uppercase hex bytes separated by spaces")
    func hexString() {
        let msg = SerialMessage(data: Data([0xDE, 0xAD, 0x00, 0x01]), direction: .received, timestamp: Date())
        #expect(msg.hexString == "DE AD 00 01")
    }

    @Test("asciiString shows printable ASCII characters")
    func asciiStringPrintable() {
        let msg = SerialMessage(data: Data("Hello".utf8), direction: .received, timestamp: Date())
        #expect(msg.asciiString == "Hello")
    }

    @Test("asciiString replaces non-printable bytes with dots")
    func asciiStringNonPrintable() {
        let msg = SerialMessage(data: Data([0x41, 0x00, 0x01, 0x0A, 0x42]), direction: .received, timestamp: Date())
        let result = msg.asciiString
        #expect(result == "A..⏎B")
    }

    @Test("direction label")
    func directionLabel() {
        #expect(SerialMessage.Direction.sent.label == "TX")
        #expect(SerialMessage.Direction.received.label == "RX")
    }

    @Test("direction systemImageName")
    func directionImageName() {
        #expect(SerialMessage.Direction.sent.systemImageName == "arrow.up")
        #expect(SerialMessage.Direction.received.systemImageName == "arrow.down")
    }
}
