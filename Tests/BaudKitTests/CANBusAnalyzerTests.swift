import Testing
import Foundation
@testable import BaudKit

@Suite("CANIDStats")
struct CANIDStatsTests {
    @Test("Initial stats have no period or jitter")
    func initialValues() {
        let stats = CANIDStats(arbitrationID: 0x100)
        #expect(stats.detectedPeriod == nil)
        #expect(stats.jitter == nil)
        #expect(stats.minInterval == nil)
        #expect(stats.maxInterval == nil)
        #expect(stats.avgInterval == nil)
        #expect(stats.stabilityStatus == .unknown)
        #expect(stats.frameCount == 0)
    }

    @Test("detectedPeriod returns median of intervals")
    func detectedPeriod() {
        var stats = CANIDStats(arbitrationID: 0x100)
        stats.intervals = [0.010, 0.012, 0.011, 0.020, 0.010]
        // sorted: [0.010, 0.010, 0.011, 0.012, 0.020], median = 0.011
        #expect(stats.detectedPeriod == 0.011)
    }

    @Test("jitter computes standard deviation")
    func jitter() {
        var stats = CANIDStats(arbitrationID: 0x100)
        stats.intervals = [0.010, 0.010, 0.010]
        #expect(stats.jitter! < 0.001)
    }

    @Test("stabilityStatus returns stable for low jitter")
    func stableStatus() {
        var stats = CANIDStats(arbitrationID: 0x100)
        stats.intervals = [0.010, 0.010, 0.010]
        #expect(stats.stabilityStatus == .stable)
    }

    @Test("stabilityStatus returns unstable for high jitter")
    func unstableStatus() {
        var stats = CANIDStats(arbitrationID: 0x100)
        stats.intervals = [0.010, 0.050, 0.010]
        #expect(stats.stabilityStatus == .unstable)
    }

    @Test("min/max/avg intervals")
    func intervalStats() {
        var stats = CANIDStats(arbitrationID: 0x100)
        stats.intervals = [0.010, 0.020, 0.030]
        #expect(stats.minInterval == 0.010)
        #expect(stats.maxInterval == 0.030)
        #expect(stats.avgInterval == 0.020)
    }

    @Test("idHex formatting")
    func idHexFormat() {
        let stats = CANIDStats(arbitrationID: 0x0C4)
        #expect(stats.idHex == "0C4")
    }

    @Test("maxIntervals is 100")
    func maxIntervals() {
        #expect(CANIDStats.maxIntervals == 100)
    }
}

@Suite("CANErrorEvent")
struct CANErrorEventTests {
    @Test("Error descriptions")
    func errorDescriptions() {
        #expect(CANErrorEvent(code: 0x01, timestamp: Date()).description == "Bit Error")
        #expect(CANErrorEvent(code: 0x08, timestamp: Date()).description == "CRC Error")
        #expect(CANErrorEvent(code: 0x10, timestamp: Date()).description == "ACK Error")
        #expect(CANErrorEvent(code: 0x80, timestamp: Date()).description == "Bus Off")
        #expect(CANErrorEvent(code: 0xFF, timestamp: Date()).description == "Unknown (0xFF)")
    }
}

@Suite("SLCANResponse error frame")
struct SLCANErrorFrameTests {
    @Test("Parse error frame")
    func parseErrorFrame() {
        let result = SLCANResponse.parse("e08")
        if case .errorFrame(let code) = result {
            #expect(code == 0x08)
        } else {
            Issue.record("Expected errorFrame, got \(result)")
        }
    }

    @Test("Unknown error code falls back")
    func parseUnknownError() {
        let result = SLCANResponse.parse("eGG")
        if case .unknown = result {
            // expected
        } else {
            Issue.record("Expected unknown for invalid hex")
        }
    }
}
