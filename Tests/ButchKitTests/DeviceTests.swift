import Testing
@testable import ButchKit

@Suite("Device")
struct DeviceTests {
    @Test("Answers yes to exactly its own product class", arguments: Device.allCases)
    func answersOnlyItsOwnClass(device: Device) {
        #expect(device.isiPhone == (device == .iPhone))
        #expect(device.isiPad == (device == .iPad))
        #expect(device.isMac == (device == .mac))
    }
}
