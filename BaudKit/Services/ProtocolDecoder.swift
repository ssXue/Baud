import Foundation

public final class ProtocolDecoder {
    private var buffer = Data()
    private let definition: ProtocolDefinition

    public init(definition: ProtocolDefinition) {
        self.definition = definition
    }

    public func feed(_ data: Data) -> [ProtocolFrame] {
        buffer.append(data)
        var frames: [ProtocolFrame] = []

        while true {
            guard let headerRange = findHeader() else { break }

            // Discard bytes before header
            if headerRange.lowerBound > 0 {
                buffer = buffer.subdata(in: headerRange.lowerBound..<buffer.endIndex)
            }

            let headerSize = definition.headerBytes.count
            let totalFrameLength: Int

            if definition.usesFixedLength {
                totalFrameLength = definition.fixedFrameLength
            } else {
                let lengthFieldStart = headerSize + definition.lengthFieldOffset
                let lengthFieldEnd = lengthFieldStart + definition.lengthFieldSize

                guard buffer.count >= lengthFieldEnd else { break }

                var lengthValue: Int = 0
                for i in 0..<definition.lengthFieldSize {
                    let byte = buffer[lengthFieldStart + i]
                    lengthValue = lengthValue << 8 | Int(byte)
                }

                if definition.lengthIncludesHeader {
                    totalFrameLength = lengthValue
                } else {
                    totalFrameLength = headerSize + definition.lengthFieldOffset + definition.lengthFieldSize + lengthValue
                }
            }

            guard totalFrameLength > headerSize, totalFrameLength <= 4096 else {
                // Invalid length, skip this header byte and retry
                buffer = buffer.subdata(in: 1..<buffer.endIndex)
                continue
            }

            guard buffer.count >= totalFrameLength else { break }

            let rawFrame = buffer.subdata(in: 0..<totalFrameLength)
            let payload: Data
            let checksumValid: Bool

            let checksumSize = definition.checksumType.checksumSize
            let payloadEnd = totalFrameLength - checksumSize

            if definition.usesFixedLength {
                let payloadStart = headerSize
                payload = rawFrame.subdata(in: payloadStart..<max(payloadStart, payloadEnd))
            } else {
                let payloadStart = headerSize + definition.lengthFieldOffset + definition.lengthFieldSize
                payload = rawFrame.subdata(in: payloadStart..<max(payloadStart, payloadEnd))
            }

            if checksumSize > 0 && payloadEnd > 0 {
                let dataToCheck = rawFrame.subdata(in: 0..<payloadEnd)
                let expectedChecksum = rawFrame.subdata(in: payloadEnd..<totalFrameLength)
                checksumValid = verifyChecksum(dataToCheck: dataToCheck, expected: expectedChecksum)
            } else {
                checksumValid = true
            }

            frames.append(ProtocolFrame(
                payload: payload,
                rawFrame: rawFrame,
                timestamp: Date(),
                checksumValid: checksumValid
            ))

            buffer = buffer.subdata(in: totalFrameLength..<buffer.endIndex)
        }

        // Keep buffer bounded
        if buffer.count > 4096 {
            buffer = buffer.subdata(in: buffer.count - 4096..<buffer.count)
        }

        return frames
    }

    public func reset() {
        buffer.removeAll(keepingCapacity: true)
    }

    private func findHeader() -> Range<Data.Index>? {
        guard !definition.headerBytes.isEmpty else { return buffer.startIndex..<buffer.startIndex }
        let pattern = Data(definition.headerBytes)
        return buffer.range(of: pattern)
    }

    private func verifyChecksum(dataToCheck: Data, expected: Data) -> Bool {
        switch definition.checksumType {
        case .none:
            return true
        case .xor:
            let result = dataToCheck.reduce(0, ^)
            return expected.first == result
        case .sum:
            let result = dataToCheck.reduce(0, { $0 + Int($1) }) & 0xFF
            return expected.first == UInt8(result)
        case .crc8:
            return expected.first == crc8(dataToCheck)
        case .crc16:
            let computed = crc16(dataToCheck)
            let expectedValue = Int(expected[0]) << 8 | Int(expected[1])
            return computed == expectedValue
        }
    }

    private func crc8(_ data: Data) -> UInt8 {
        var crc: UInt8 = 0
        for byte in data {
            crc ^= byte
            for _ in 0..<8 {
                if crc & 0x80 != 0 {
                    crc = (crc << 1) ^ 0x07
                } else {
                    crc <<= 1
                }
            }
        }
        return crc
    }

    private func crc16(_ data: Data) -> Int {
        var crc: UInt16 = 0xFFFF
        for byte in data {
            crc ^= UInt16(byte)
            for _ in 0..<8 {
                if crc & 0x0001 != 0 {
                    crc = (crc >> 1) ^ 0xA001
                } else {
                    crc >>= 1
                }
            }
        }
        return Int(crc)
    }
}
