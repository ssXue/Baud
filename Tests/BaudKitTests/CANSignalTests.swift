import Testing
import Foundation
@testable import BaudKit

@Suite("CANSignal extractValue")
struct CANSignalTests {

    @Test("Little-endian unsigned single byte")
    func littleEndianUnsignedSingleByte() {
        let signal = CANSignal(
            name: "Test",
            arbitrationID: 0x123,
            startBit: 0,
            bitLength: 8,
            byteOrder: .littleEndian,
            signed: false,
            factor: 1.0,
            offset: 0.0
        )
        let value = signal.extractValue(from: [0x64])
        #expect(value == 100.0)
    }

    @Test("Little-endian unsigned multi-byte")
    func littleEndianUnsignedMultiByte() {
        let signal = CANSignal(
            name: "Test",
            arbitrationID: 0x123,
            startBit: 0,
            bitLength: 16,
            byteOrder: .littleEndian,
            signed: false,
            factor: 1.0,
            offset: 0.0
        )
        // 0xE8, 0x03 → little endian → 0x03E8 = 1000
        let value = signal.extractValue(from: [0xE8, 0x03])
        #expect(value == 1000.0)
    }

    @Test("Little-endian unsigned with non-zero startBit")
    func littleEndianWithStartBit() {
        let signal = CANSignal(
            name: "Test",
            arbitrationID: 0x123,
            startBit: 4,
            bitLength: 12,
            byteOrder: .littleEndian,
            signed: false,
            factor: 1.0,
            offset: 0.0
        )
        // byte0 = 0xAB → bits 4-7 = 0x0B, byte1 = 0xCD → bits 0-7 = 0xCD
        // little endian: value = 0xCD * 16 + 0x0B = 0xCD0B... wait, let me think again
        // startBit=4, bitLength=12: bits 4..15
        // bit 4-7 from byte0, bit 8-15 from byte1
        // little endian assembly: bit at startBit+i → position i in result
        // byte0=0xAB: bits 4-7 = 1011 → result bits 0-3 = 1011 = 0xB
        // byte1=0xCD: bits 0-7 = 11001101 → result bits 4-11 = 11001101 shifted
        // result = byte1 << 4 | (byte0 >> 4)
        let value = signal.extractValue(from: [0xAB, 0xCD])
        #expect(value == 0x0CDA as Double)
    }

    @Test("Big-endian unsigned")
    func bigEndianUnsigned() {
        let signal = CANSignal(
            name: "Test",
            arbitrationID: 0x123,
            startBit: 8,
            bitLength: 8,
            byteOrder: .bigEndian,
            signed: false,
            factor: 1.0,
            offset: 0.0
        )
        // startBit=8 → byte index 1, bit offset 7-0 reversed → bit 7
        // For big endian: bit at startBit+i, byteIndex = (startBit+i)/8, bitOffset = 7-((startBit+i)%8)
        // This reads byte 1 as big-endian byte value
        let value = signal.extractValue(from: [0x00, 0xFF])
        #expect(value == 255.0)
    }

    @Test("Signed negative value (little-endian)")
    func signedNegative() {
        let signal = CANSignal(
            name: "Test",
            arbitrationID: 0x123,
            startBit: 0,
            bitLength: 8,
            byteOrder: .littleEndian,
            signed: true,
            factor: 1.0,
            offset: 0.0
        )
        // 0xFF as signed 8-bit = -1
        let value = signal.extractValue(from: [0xFF])
        #expect(value == -1.0)
    }

    @Test("Signed 16-bit negative value")
    func signed16Negative() {
        let signal = CANSignal(
            name: "Test",
            arbitrationID: 0x123,
            startBit: 0,
            bitLength: 16,
            byteOrder: .littleEndian,
            signed: true,
            factor: 1.0,
            offset: 0.0
        )
        // 0xFFC0 as signed 16-bit = -64
        let value = signal.extractValue(from: [0xC0, 0xFF])
        #expect(value == -64.0)
    }

    @Test("Factor and offset applied")
    func factorAndOffset() {
        let signal = CANSignal(
            name: "Test",
            arbitrationID: 0x123,
            startBit: 0,
            bitLength: 8,
            byteOrder: .littleEndian,
            signed: false,
            factor: 0.5,
            offset: -40.0
        )
        // raw = 200, result = 200 * 0.5 + (-40) = 60
        let value = signal.extractValue(from: [0xC8])
        #expect(value == 60.0)
    }

    @Test("Returns nil when startBit+bitLength exceeds data")
    func outOfBounds() {
        let signal = CANSignal(
            name: "Test",
            arbitrationID: 0x123,
            startBit: 56,
            bitLength: 16,
            byteOrder: .littleEndian,
            signed: false
        )
        let value = signal.extractValue(from: [0, 0, 0, 0, 0, 0, 0, 0])
        #expect(value == nil)
    }

    @Test("Returns nil for zero bitLength")
    func zeroBitLength() {
        let signal = CANSignal(
            name: "Test",
            arbitrationID: 0x123,
            startBit: 0,
            bitLength: 0,
            byteOrder: .littleEndian,
            signed: false
        )
        let value = signal.extractValue(from: [0xFF])
        #expect(value == nil)
    }

    @Test("displayValue with valueTable returns label")
    func displayValueWithValueTable() {
        let signal = CANSignal(
            name: "Gear",
            arbitrationID: 0x100,
            startBit: 0,
            bitLength: 8,
            valueTable: [0: "Park", 1: "Reverse", 2: "Neutral", 3: "Drive"]
        )
        #expect(signal.displayValue(raw: 0.0) == "Park (0)")
        #expect(signal.displayValue(raw: 3.0) == "Drive (3)")
        #expect(signal.displayValue(raw: 1.0) == "Reverse (1)")
    }

    @Test("displayValue without valueTable returns formatted number")
    func displayValueWithoutValueTable() {
        let signal = CANSignal(
            name: "RPM",
            arbitrationID: 0x100,
            startBit: 0,
            bitLength: 16
        )
        #expect(signal.displayValue(raw: 3500.0) == "3500")
        #expect(signal.displayValue(raw: 3.14159) == "3.1416")
        #expect(signal.displayValue(raw: 0.0) == "0")
    }

    @Test("displayValue with unknown value returns formatted number")
    func displayValueWithUnknownValue() {
        let signal = CANSignal(
            name: "Gear",
            arbitrationID: 0x100,
            startBit: 0,
            bitLength: 8,
            valueTable: [0: "Park", 1: "Drive"]
        )
        #expect(signal.displayValue(raw: 5.0) == "5")
        #expect(signal.displayValue(raw: 2.5) == "2.5000")
    }
}
