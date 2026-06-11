import Testing
import Foundation
@testable import BaudKit

@Suite("CANBitrate")
struct CANBitrateTests {

    @Test("All bitrates have display names")
    func displayNames() {
        for bitrate in CANBitrate.allCases {
            #expect(!bitrate.display.isEmpty)
        }
    }

    @Test("SLCAN supported bitrates are subset of all bitrates")
    func slcanBitrates() {
        let slcan = CANBitrate.slcanBitrates
        #expect(slcan.allSatisfy { $0.isSLCANSuported })
        #expect(slcan.contains(.bps500k))
        #expect(!slcan.contains(.bps5k))
        #expect(!slcan.contains(.bps800k))
    }

    @Test("PCAN supported bitrates are subset of all bitrates")
    func pcanBitrates() {
        let pcan = CANBitrate.pcanBitrates
        #expect(pcan.allSatisfy { $0.isPCANSupported })
        #expect(pcan.contains(.bps500k))
        #expect(pcan.contains(.bps5k))
        #expect(pcan.contains(.bps800k))
        #expect(!pcan.contains(.bps750k))
    }

    @Test("SLCAN index mapping for 500k")
    func slcanIndex500k() {
        #expect(CANBitrate.bps500k.slcanIndex == 6)
    }

    @Test("SLCAN index returns nil for unsupported bitrates")
    func slcanIndexUnsupported() {
        #expect(CANBitrate.bps5k.slcanIndex == nil)
        #expect(CANBitrate.bps800k.slcanIndex == nil)
    }

    @Test("PCAN BTR mapping for 500k")
    func pcanBtr500k() {
        #expect(CANBitrate.bps500k.pcanBtr == 0x001C)
    }

    @Test("PCAN BTR returns nil for unsupported bitrates")
    func pcanBtrUnsupported() {
        #expect(CANBitrate.bps750k.pcanBtr == nil)
    }

    @Test("bps value matches raw value")
    func bpsValue() {
        #expect(CANBitrate.bps500k.bps == 500_000)
        #expect(CANBitrate.bps1M.bps == 1_000_000)
    }

    @Test("Common bitrates between SLCAN and PCAN")
    func commonBitrates() {
        let common = CANBitrate.allCases.filter(\.isSLCANSuported).filter(\.isPCANSupported)
        #expect(common.contains(.bps10k))
        #expect(common.contains(.bps125k))
        #expect(common.contains(.bps250k))
        #expect(common.contains(.bps500k))
        #expect(common.contains(.bps1M))
    }
}

@Suite("CANBackendType")
struct CANBackendTypeTests {

    @Test("All backend types have labels")
    func labels() {
        for type in CANBackendType.allCases {
            #expect(!type.label.isEmpty)
        }
    }

    @Test("All backend types have system images")
    func systemImages() {
        for type in CANBackendType.allCases {
            #expect(!type.systemImage.isEmpty)
        }
    }

    @Test("Backend type raw values")
    func rawValues() {
        #expect(CANBackendType.slcan.rawValue == "slcan")
        #expect(CANBackendType.pcan.rawValue == "pcan")
    }
}

@Suite("PCANDevice")
struct PCANDeviceTests {

    @Test("PCAN device has correct properties")
    func deviceProperties() {
        let device = PCANDevice(id: 0x0041, name: "PCAN-USB 1", deviceId: 12345)
        #expect(device.id == 0x0041)
        #expect(device.name == "PCAN-USB 1")
        #expect(device.deviceId == 12345)
    }
}

@Suite("PCANBackend")
struct PCANBackendTests {

    @Test("PCANBackend type is pcan")
    @MainActor
    func backendType() {
        let backend = PCANBackend()
        #expect(backend.backendType == .pcan)
    }

    @Test("PCANBackend starts with channel closed")
    @MainActor
    func startsClosed() {
        let backend = PCANBackend()
        #expect(!backend.isChannelOpen)
        #expect(backend.lastError == nil)
    }

    @Test("PCANBackend default bitrate is 500k")
    @MainActor
    func defaultBitrate() {
        let backend = PCANBackend()
        #expect(backend.selectedBitrate == .bps500k)
    }

    @Test("PCANBackend can change bitrate")
    @MainActor
    func changeBitrate() {
        let backend = PCANBackend()
        backend.selectedBitrate = .bps250k
        #expect(backend.selectedBitrate == .bps250k)
    }

    @Test("PCANBackend acceptance filter defaults")
    @MainActor
    func acceptanceDefaults() {
        let backend = PCANBackend()
        #expect(backend.acceptanceCode == 0)
        #expect(backend.acceptanceMask == 0xFFFFFFFF)
    }
}

@Suite("CANBackendManager")
struct CANBackendManagerTests {

    @Test("Manager defaults to SLCAN backend")
    @MainActor
    func defaultBackend() {
        UserDefaults.standard.removeObject(forKey: "baud.canBackend")
        let manager = CANBackendManager()
        #expect(manager.activeBackendType == .slcan)
    }

    @Test("Manager has slcanManager")
    @MainActor
    func hasSlcanManager() {
        let manager = CANBackendManager()
        #expect(manager.slcanManager.backendType == .slcan)
    }

    @Test("Manager available backends includes SLCAN")
    @MainActor
    func availableBackends() {
        let manager = CANBackendManager()
        #expect(manager.availableBackendTypes.contains(.slcan))
    }

    @Test("Manager supported bitrates match backend")
    @MainActor
    func supportedBitrates() {
        let manager = CANBackendManager()
        manager.activeBackendType = .slcan
        #expect(manager.supportedBitrates == CANBitrate.slcanBitrates)
    }

    @Test("Manager isChannelOpen starts false")
    @MainActor
    func startsClosed() {
        let manager = CANBackendManager()
        #expect(!manager.isChannelOpen)
    }
}
