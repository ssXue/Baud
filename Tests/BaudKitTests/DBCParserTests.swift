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

    // MARK: - VAL_ Value Tables

    @Test("Parses VAL_ entries for signal values")
    func parsesValEntries() {
        let content = """
BO_ 100 Status: 8 ECU
 SG_ Gear : 0|3@1+ (1,0) [0|7] "" ECU

VAL_ 100 Gear 0 "Park" 1 "Reverse" 2 "Neutral" 3 "Drive" ;
"""
        let result = DBCParser.parse(content)!
        let key = DBCFile.SignalValueKey(messageID: 100, signalName: "Gear")
        #expect(result.signalValues[key] != nil)
        let table = result.signalValues[key]!
        #expect(table[0] == "Park")
        #expect(table[1] == "Reverse")
        #expect(table[2] == "Neutral")
        #expect(table[3] == "Drive")
    }

    @Test("VAL_ values are transferred to CANSignal.valueTable via toCANSignals")
    func valTransferredToSignal() {
        let content = """
BO_ 100 Status: 8 ECU
 SG_ Gear : 0|3@1+ (1,0) [0|7] "" ECU

VAL_ 100 Gear 0 "Park" 1 "Drive" ;
"""
        let result = DBCParser.parse(content)!
        let signals = DBCParser.toCANSignals(result)
        let gear = signals.first { $0.name == "Gear" }!
        #expect(gear.valueTable[0] == "Park")
        #expect(gear.valueTable[1] == "Drive")
    }

    // MARK: - VAL_TABLE_

    @Test("Parses VAL_TABLE_ entries")
    func parsesValTable() {
        let content = """
VAL_TABLE_ ActiveState 0 "Inactive" 1 "Active" 2 "Error" ;

BO_ 100 Status: 8 ECU
 SG_ State : 0|2@1+ (1,0) [0|3] "" ECU
"""
        let result = DBCParser.parse(content)!
        #expect(result.valueTables["ActiveState"] != nil)
        let table = result.valueTables["ActiveState"]!
        #expect(table[0] == "Inactive")
        #expect(table[1] == "Active")
        #expect(table[2] == "Error")
    }

    // MARK: - Multiplexer Signals

    @Test("Parses multiplexor signal (M)")
    func parsesMultiplexor() {
        let content = """
BO_ 100 Multiplexed: 8 ECU
 SG_ mux M : 0|4@1+ (1,0) [0|15] "" ECU
 SG_ sig1 m0 : 8|8@1+ (1,0) [0|255] "" ECU
 SG_ sig2 m1 : 8|8@1+ (1,0) [0|255] "" ECU
"""
        let result = DBCParser.parse(content)!
        let signals = result.messages[0].signals
        let mux = signals.first { $0.name == "mux" }!
        #expect(mux.multiplexMode == "M")

        let sig1 = signals.first { $0.name == "sig1" }!
        #expect(sig1.multiplexMode == "m0")

        let sig2 = signals.first { $0.name == "sig2" }!
        #expect(sig2.multiplexMode == "m1")
    }

    @Test("Normal signal has nil multiplexMode")
    func normalSignalNoMultiplex() {
        let result = DBCParser.parse(Self.sampleDBC)!
        let rpm = result.messages[0].signals[0]
        #expect(rpm.multiplexMode == nil)
    }

    // MARK: - BA_ GenMsgCycleTime

    @Test("Parses GenMsgCycleTime attribute")
    func parsesCycleTime() {
        let content = """
BO_ 100 Cyclic: 8 ECU
 SG_ Value : 0|8@1+ (1,0) [0|255] "" ECU

BA_ "GenMsgCycleTime" BO_ 100 100;
"""
        let result = DBCParser.parse(content)!
        #expect(result.cycleTimes[100] == 100)
    }

    @Test("Ignores unrelated BA_ attributes")
    func ignoresOtherBA() {
        let content = """
BO_ 100 Test: 8 ECU
 SG_ Value : 0|8@1+ (1,0) [0|255] "" ECU

BA_ "GenMsgSendType" BO_ 100 0;
"""
        let result = DBCParser.parse(content)!
        #expect(result.cycleTimes.isEmpty)
    }
}
