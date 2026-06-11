import Testing
import Foundation
@testable import BaudKit

@Suite("DataExporter PCAP")
struct DataExporterTests {

    private func makeFrame(id: UInt32, data: [UInt8], isExtended: Bool = false, isRemote: Bool = false) -> CANFrame {
        CANFrame(
            arbitrationID: id,
            isExtended: isExtended,
            isRemote: isRemote,
            dlc: UInt8(data.count),
            data: data,
            direction: .received,
            timestamp: Date(timeIntervalSince1970: 1700000000)
        )
    }

    @Test("PCAP global header has correct magic number")
    func pcapMagicNumber() {
        let frames = [makeFrame(id: 0x123, data: [0x01, 0x02])]
        let data = DataExporter.exportCANFramesPCAP(frames)

        // First 4 bytes should be 0xa1b2c3d4 little-endian
        let magic = data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        #expect(magic == 0xa1b2c3d4)
    }

    @Test("PCAP global header has correct link type 227")
    func pcapLinkType() {
        let frames = [makeFrame(id: 0x100, data: [0xAA])]
        let data = DataExporter.exportCANFramesPCAP(frames)

        // Link type is at offset 20 (24 bytes header, link type is last 4)
        let linkType = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 20, as: UInt32.self) }
        #expect(linkType == 227)
    }

    @Test("PCAP contains correct number of packet records")
    func pcapPacketCount() {
        let frames = [
            makeFrame(id: 0x100, data: [0x01]),
            makeFrame(id: 0x200, data: [0x02, 0x03]),
            makeFrame(id: 0x300, data: [0x04, 0x05, 0x06])
        ]
        let data = DataExporter.exportCANFramesPCAP(frames)

        // Global header = 24 bytes, each packet = 16 header + 16 payload
        let expectedSize = 24 + frames.count * (16 + 16)
        #expect(data.count == expectedSize)
    }

    @Test("PCAP packet contains correct CAN ID")
    func pcapCANID() {
        let frames = [makeFrame(id: 0x123, data: [0xAA, 0xBB])]
        let data = DataExporter.exportCANFramesPCAP(frames)

        // Packet data starts at offset 24 (global header) + 16 (packet header) = 40
        let canID = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 40, as: UInt32.self) }
        #expect(canID == 0x123)
    }

    @Test("PCAP sets extended frame flag")
    func pcapExtendedFlag() {
        let frames = [makeFrame(id: 0x12345, data: [0x01], isExtended: true)]
        let data = DataExporter.exportCANFramesPCAP(frames)

        let canID = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 40, as: UInt32.self) }
        #expect(canID & 0x80000000 != 0)
        #expect(canID & 0x7FFFFFFF == 0x12345)
    }

    @Test("PCAP sets remote frame flag")
    func pcapRemoteFlag() {
        let frames = [makeFrame(id: 0x100, data: [], isRemote: true)]
        let data = DataExporter.exportCANFramesPCAP(frames)

        let canID = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 40, as: UInt32.self) }
        #expect(canID & 0x20000000 != 0)
    }

    @Test("PCAP data is zero-padded to 8 bytes")
    func pcapPadding() {
        let frames = [makeFrame(id: 0x100, data: [0xAA])]
        let data = DataExporter.exportCANFramesPCAP(frames)

        // Data bytes start at offset 40 + 4 (CAN ID) + 1 (DLC) + 3 (pad) = 48
        #expect(data[48] == 0xAA)
        for i in 49..<56 {
            #expect(data[i] == 0)
        }
    }

    @Test("PCAP with empty frame list produces valid global header only")
    func pcapEmpty() {
        let data = DataExporter.exportCANFramesPCAP([])
        #expect(data.count == 24) // global header only
    }
}
