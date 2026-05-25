import Testing
import Foundation
@testable import BaudKit

@Suite("ProtocolDecoder")
struct ProtocolDecoderTests {

    @Test("Parses fixed-length frames with header")
    func fixedLengthFrames() {
        let def = ProtocolDefinition(
            name: "Test",
            headerBytes: [0xAA, 0x55],
            lengthFieldSize: 0,
            fixedFrameLength: 6
        )
        let decoder = ProtocolDecoder(definition: def)

        // AA 55 01 02 03 04 — header(2) + payload(4) = 6
        let frames = decoder.feed(Data([0xAA, 0x55, 0x01, 0x02, 0x03, 0x04]))
        #expect(frames.count == 1)
        #expect(frames[0].payload == Data([0x01, 0x02, 0x03, 0x04]))
        #expect(frames[0].checksumValid == true)
    }

    @Test("Skips garbage bytes before header")
    func skipsGarbage() {
        let def = ProtocolDefinition(
            name: "Test",
            headerBytes: [0xAA, 0x55],
            lengthFieldSize: 0,
            fixedFrameLength: 4
        )
        let decoder = ProtocolDecoder(definition: def)

        let frames = decoder.feed(Data([0xFF, 0xFE, 0xAA, 0x55, 0x01, 0x02]))
        #expect(frames.count == 1)
        #expect(frames[0].payload == Data([0x01, 0x02]))
    }

    @Test("Parses multiple frames from single feed")
    func multipleFrames() {
        let def = ProtocolDefinition(
            name: "Test",
            headerBytes: [0xAA],
            lengthFieldSize: 0,
            fixedFrameLength: 3
        )
        let decoder = ProtocolDecoder(definition: def)

        let frames = decoder.feed(Data([0xAA, 0x01, 0x02, 0xAA, 0x03, 0x04]))
        #expect(frames.count == 2)
        #expect(frames[0].payload == Data([0x01, 0x02]))
        #expect(frames[1].payload == Data([0x03, 0x04]))
    }

    @Test("Parses frames across multiple feeds")
    func acrossFeeds() {
        let def = ProtocolDefinition(
            name: "Test",
            headerBytes: [0xAA, 0x55],
            lengthFieldSize: 0,
            fixedFrameLength: 4
        )
        let decoder = ProtocolDecoder(definition: def)

        let f1 = decoder.feed(Data([0xAA, 0x55]))
        #expect(f1.isEmpty) // incomplete

        let f2 = decoder.feed(Data([0x01, 0x02]))
        #expect(f2.count == 1)
        #expect(f2[0].payload == Data([0x01, 0x02]))
    }

    @Test("Parses 1-byte length field frames")
    func oneByteLengthField() {
        let def = ProtocolDefinition(
            name: "Test",
            headerBytes: [0xAA, 0x55],
            lengthFieldOffset: 0,
            lengthFieldSize: 1,
            lengthIncludesHeader: false
        )
        let decoder = ProtocolDecoder(definition: def)

        // header(2) + length(1, value=3) + payload(3) = 6
        let frames = decoder.feed(Data([0xAA, 0x55, 0x03, 0x01, 0x02, 0x03]))
        #expect(frames.count == 1)
        #expect(frames[0].payload == Data([0x01, 0x02, 0x03]))
    }

    @Test("Parses 2-byte length field frames (big endian)")
    func twoByteLengthField() {
        let def = ProtocolDefinition(
            name: "Test",
            headerBytes: [0xAA, 0x55],
            lengthFieldOffset: 0,
            lengthFieldSize: 2,
            lengthIncludesHeader: false
        )
        let decoder = ProtocolDecoder(definition: def)

        // header(2) + length(2, value=2) + payload(2) = 6
        let frames = decoder.feed(Data([0xAA, 0x55, 0x00, 0x02, 0xDE, 0xAD]))
        #expect(frames.count == 1)
        #expect(frames[0].payload == Data([0xDE, 0xAD]))
    }

    @Test("Length field includes header")
    func lengthIncludesHeader() {
        let def = ProtocolDefinition(
            name: "Test",
            headerBytes: [0xAA, 0x55],
            lengthFieldOffset: 0,
            lengthFieldSize: 1,
            lengthIncludesHeader: true
        )
        let decoder = ProtocolDecoder(definition: def)

        // header(2) + length(1, value=5, includes header) + payload(2) = 5
        let frames = decoder.feed(Data([0xAA, 0x55, 0x05, 0xDE, 0xAD]))
        #expect(frames.count == 1)
        #expect(frames[0].payload == Data([0xDE, 0xAD]))
    }

    @Test("Validates XOR checksum")
    func xorChecksum() {
        let def = ProtocolDefinition(
            name: "Test",
            headerBytes: [0xAA, 0x55],
            lengthFieldSize: 0,
            fixedFrameLength: 5,
            checksumType: .xor
        )
        let decoder = ProtocolDecoder(definition: def)

        // AA 55 01 02 [AA^55^01^02 = FC]
        let checksum: UInt8 = 0xAA ^ 0x55 ^ 0x01 ^ 0x02
        let frames = decoder.feed(Data([0xAA, 0x55, 0x01, 0x02, checksum]))
        #expect(frames.count == 1)
        #expect(frames[0].checksumValid == true)
    }

    @Test("Detects invalid checksum")
    func invalidChecksum() {
        let def = ProtocolDefinition(
            name: "Test",
            headerBytes: [0xAA, 0x55],
            lengthFieldSize: 0,
            fixedFrameLength: 5,
            checksumType: .xor
        )
        let decoder = ProtocolDecoder(definition: def)

        let frames = decoder.feed(Data([0xAA, 0x55, 0x01, 0x02, 0xFF]))
        #expect(frames.count == 1)
        #expect(frames[0].checksumValid == false)
    }

    @Test("No header bytes matches from buffer start")
    func noHeaderBytes() {
        let def = ProtocolDefinition(
            name: "Test",
            headerBytes: [],
            lengthFieldSize: 0,
            fixedFrameLength: 4
        )
        let decoder = ProtocolDecoder(definition: def)

        let frames = decoder.feed(Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]))
        #expect(frames.count == 2)
        #expect(frames[0].payload == Data([0x01, 0x02, 0x03, 0x04]))
        #expect(frames[1].payload == Data([0x05, 0x06, 0x07, 0x08]))
    }
}
