import Testing
import Foundation
@testable import BaudKit

@Suite("HexFormatter")
struct HexFormatterTests {

    @Test("dataToHex converts bytes to spaced hex")
    func dataToHex() {
        let result = HexFormatter.dataToHex(Data([0xDE, 0xAD, 0x00, 0x01]))
        #expect(result == "DE AD 00 01")
    }

    @Test("dataToHex empty data")
    func dataToHexEmpty() {
        #expect(HexFormatter.dataToHex(Data()) == "")
    }

    @Test("hexToData converts valid hex string")
    func hexToData() {
        let result = HexFormatter.hexToData("DE AD 00 01")
        #expect(result == Data([0xDE, 0xAD, 0x00, 0x01]))
    }

    @Test("hexToData works without spaces")
    func hexToDataNoSpaces() {
        let result = HexFormatter.hexToData("DEAD0001")
        #expect(result == Data([0xDE, 0xAD, 0x00, 0x01]))
    }

    @Test("hexToData returns nil for odd-length hex")
    func hexToDataOddLength() {
        #expect(HexFormatter.hexToData("ABC") == nil)
    }

    @Test("hexToData returns nil for invalid hex characters")
    func hexToDataInvalid() {
        #expect(HexFormatter.hexToData("GHIJ") == nil)
    }

    @Test("hexToData empty string returns empty data")
    func hexToDataEmpty() {
        #expect(HexFormatter.hexToData("") == Data())
    }

    @Test("isValidHex accepts valid hex")
    func isValidHexTrue() {
        #expect(HexFormatter.isValidHex("DEAD"))
        #expect(HexFormatter.isValidHex("00 11 22"))
        #expect(HexFormatter.isValidHex("aabb"))
    }

    @Test("isValidHex rejects invalid input")
    func isValidHexFalse() {
        #expect(!HexFormatter.isValidHex("ZZ"))
        #expect(!HexFormatter.isValidHex("ABC"))  // odd length
    }

    @Test("round-trip: data → hex → data")
    func roundTrip() {
        let original = Data([0x00, 0x01, 0xFE, 0xFF])
        let hex = HexFormatter.dataToHex(original)
        let restored = HexFormatter.hexToData(hex)
        #expect(restored == original)
    }
}
