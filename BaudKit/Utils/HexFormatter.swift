import Foundation

public enum HexFormatter {
    public static func dataToHex(_ data: Data) -> String {
        data.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    public static func hexToData(_ hex: String) -> Data? {
        let cleaned = hex.replacingOccurrences(of: " ", with: "")
        guard cleaned.count % 2 == 0 else { return nil }
        var data = Data()
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let nextIndex = cleaned.index(index, offsetBy: 2)
            let byteStr = String(cleaned[index..<nextIndex])
            guard let byte = UInt8(byteStr, radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        return data
    }

    public static func isValidHex(_ text: String) -> Bool {
        let cleaned = text.replacingOccurrences(of: " ", with: "")
        return cleaned.allSatisfy { $0.isHexDigit } && cleaned.count % 2 == 0
    }
}
