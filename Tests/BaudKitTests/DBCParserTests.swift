import Testing
import Foundation
@testable import BaudKit

@Suite("DBCParser")
struct DBCParserTests {

    private static let sampleDBC = """
VERSION ""

NS_ :
    Test

BS_:

BU_: ECU

BO_ 196 RPM_Temp: 8 ECU
 SG_ RPM : 0|16@1+ (1,0) [0|8000] "rpm" ECU
 SG_ Speed : 16|16@1+ (1,0) [0|300] "km/h" ECU
 SG_ Temp : 32|8@1+ (1,-40) [-40|215] "C" ECU

BO_ 100 WheelSpeed: 8 ECU
 SG_ FL : 0|16@1+ (0.01,0) [0|655.35] "km/h" ECU
 SG_ FR : 16|16@1+ (0.01,0) [0|655.35] "km/h" ECU
 SG_ RL : 32|16@1+ (0.01,0) [0|655.35] "km/h" ECU
 SG_ RR : 48|16@1+ (0.01,0) [0|655.35] "km/h" ECU

BO_ 200 EngineStatus: 4 ECU
 SG_ EngineRunning : 0|1@1+ (1,0) [0|1] "" ECU
 SG_ CoolantTemp : 8|8@1- (1,-40) [-40|215] "C" ECU
 SG_ BatteryVoltage : 16|16@1+ (0.001,0) [0|65.535] "V" ECU
"""

    @Test("Parses all messages")
    func parsesMessages() {
        let result = DBCParser.parse(Self.sampleDBC)
        #expect(result != nil)
        #expect(result!.messages.count == 3)
    }

    @Test("Parses message fields correctly")
    func parsesMessageFields() {
        let result = DBCParser.parse(Self.sampleDBC)!
        let msg = result.messages[0]
        #expect(msg.dbcID == 196)
        #expect(msg.name == "RPM_Temp")
        #expect(msg.length == 8)
        #expect(msg.sender == "ECU")
        #expect(msg.signals.count == 3)
    }

    @Test("Parses signal fields correctly")
    func parsesSignalFields() {
        let result = DBCParser.parse(Self.sampleDBC)!
        let rpm = result.messages[0].signals[0]
        #expect(rpm.name == "RPM")
        #expect(rpm.startBit == 0)
        #expect(rpm.bitLength == 16)
        #expect(rpm.byteOrder == .littleEndian)
        #expect(rpm.signed == false)
        #expect(rpm.factor == 1.0)
        #expect(rpm.offset == 0.0)
        #expect(rpm.min == 0.0)
        #expect(rpm.max == 8000.0)
        #expect(rpm.unit == "rpm")
    }

    @Test("Parses signed signal")
    func parsesSignedSignal() {
        let result = DBCParser.parse(Self.sampleDBC)!
        let coolant = result.messages[2].signals[1]
        #expect(coolant.name == "CoolantTemp")
        #expect(coolant.byteOrder == .littleEndian)
        #expect(coolant.signed == true)
        #expect(coolant.offset == -40.0)
        #expect(coolant.unit == "C")
    }

    @Test("Parses big endian signal")
    func parsesBigEndian() {
        let bigEndianDBC = """
BO_ 100 Test: 8 ECU
 SG_ Value : 0|16@0+ (1,0) [0|65535] "" ECU
"""
        let result = DBCParser.parse(bigEndianDBC)
        #expect(result != nil)
        #expect(result!.messages[0].signals[0].byteOrder == .bigEndian)
    }

    @Test("Parses signal with factor")
    func parsesFactor() {
        let result = DBCParser.parse(Self.sampleDBC)!
        let fl = result.messages[1].signals[0]
        #expect(fl.name == "FL")
        #expect(fl.factor == 0.01)
        #expect(fl.bitLength == 16)
        #expect(fl.startBit == 0)
    }

    @Test("allSignals aggregates across messages")
    func allSignalsCount() {
        let result = DBCParser.parse(Self.sampleDBC)!
        #expect(result.allSignals.count == 10) // 3 + 4 + 3
    }

    @Test("toCANSignals maps correctly")
    func toCANSignals() {
        let result = DBCParser.parse(Self.sampleDBC)!
        let signals = DBCParser.toCANSignals(result)
        #expect(signals.count == result.allSignals.count)

        let rpm = signals[0]
        #expect(rpm.name == "RPM")
        #expect(rpm.arbitrationID == 196)
        #expect(rpm.startBit == 0)
        #expect(rpm.bitLength == 16)
        #expect(rpm.byteOrder == .littleEndian)
        #expect(rpm.signed == false)
        #expect(rpm.factor == 1.0)
        #expect(rpm.offset == 0.0)
        #expect(rpm.minDisplay == 0.0)
        #expect(rpm.maxDisplay == 8000.0)
    }

    @Test("Returns nil for empty content")
    func returnsNilEmpty() {
        #expect(DBCParser.parse("") == nil)
        #expect(DBCParser.parse("// just a comment") == nil)
    }

    @Test("Returns nil for no valid BO_ lines")
    func returnsNilNoMessages() {
        let content = """
VERSION ""
NS_ :
    Test
"""
        #expect(DBCParser.parse(content) == nil)
    }

    @Test("Skips comments and empty lines")
    func skipsComments() {
        let content = """
// This is a comment
BO_ 100 Test: 8 ECU
// Another comment

 SG_ Value : 0|8@1+ (1,0) [0|255] "" ECU
"""
        let result = DBCParser.parse(content)
        #expect(result != nil)
        #expect(result!.messages.count == 1)
        #expect(result!.messages[0].signals.count == 1)
    }

    @Test("Signal without unit parses correctly")
    func parsesEmptyUnit() {
        let result = DBCParser.parse(Self.sampleDBC)!
        let engineRunning = result.messages[2].signals[0]
        #expect(engineRunning.name == "EngineRunning")
        #expect(engineRunning.unit == "")
        #expect(engineRunning.bitLength == 1)
    }
}
