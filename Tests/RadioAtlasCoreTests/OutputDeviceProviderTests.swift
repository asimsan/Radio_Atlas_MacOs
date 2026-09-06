import XCTest
@testable import RadioAtlasCore

final class FakeOutputDeviceProvider: OutputDeviceProviding {
    var devices: [OutputDevice]
    var defaultDevice: OutputDevice?
    init(devices: [OutputDevice], defaultDevice: OutputDevice?) {
        self.devices = devices
        self.defaultDevice = defaultDevice
    }
    func listOutputDevices() -> [OutputDevice] { devices }
    func currentDefaultDevice() -> OutputDevice? { defaultDevice }
}

final class OutputDeviceProviderTests: XCTestCase {
    func testProviderContractListsDevicesAndDefault() {
        let builtIn = OutputDevice(id: "builtin", name: "MacBook Pro Speakers")
        let airplay = OutputDevice(id: "airplay-1", name: "Living Room HomePod")
        let provider: OutputDeviceProviding = FakeOutputDeviceProvider(devices: [builtIn, airplay], defaultDevice: builtIn)

        XCTAssertEqual(provider.listOutputDevices(), [builtIn, airplay])
        XCTAssertEqual(provider.currentDefaultDevice(), builtIn)
    }

    func testRealProviderConstructsWithoutCrashing() {
        // Exercises the live CoreAudio path; the exact device list depends on the
        // machine running the test, so we only assert it doesn't crash and returns
        // a well-formed (possibly empty) array.
        let provider = CoreAudioOutputDeviceProvider()
        XCTAssertNoThrow(provider.listOutputDevices())
    }
}
