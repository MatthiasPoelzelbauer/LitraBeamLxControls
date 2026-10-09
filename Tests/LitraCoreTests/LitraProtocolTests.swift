import Testing
@testable import LitraCore

struct LitraProtocolTests {
    @Test func reportsArePaddedTo20Bytes() {
        #expect(LitraProtocol.frontPower(true).count == 20)
        #expect(LitraProtocol.backBrightness(percent: 50).count == 20)
    }

    @Test func frontPower() {
        #expect(Array(LitraProtocol.frontPower(true).prefix(5)) == [0x11, 0xFF, 0x06, 0x1C, 0x01])
        #expect(Array(LitraProtocol.frontPower(false).prefix(5)) == [0x11, 0xFF, 0x06, 0x1C, 0x00])
    }

    @Test func frontBrightnessIsBigEndianAndClamped() {
        #expect(Array(LitraProtocol.frontBrightness(lumen: 400).prefix(6)) == [0x11, 0xFF, 0x06, 0x4C, 0x01, 0x90])
        #expect(Array(LitraProtocol.frontBrightness(lumen: 10).prefix(6)) == [0x11, 0xFF, 0x06, 0x4C, 0x00, 0x1E])
    }

    @Test func frontTemperatureIsRoundedAndClamped() {
        #expect(Array(LitraProtocol.frontTemperature(kelvin: 2700).prefix(6)) == [0x11, 0xFF, 0x06, 0x9C, 0x0A, 0x8C])
        #expect(Array(LitraProtocol.frontTemperature(kelvin: 9000).prefix(6)) == [0x11, 0xFF, 0x06, 0x9C, 0x19, 0x64])
        #expect(Array(LitraProtocol.frontTemperature(kelvin: 4520).prefix(6)) == [0x11, 0xFF, 0x06, 0x9C, 0x11, 0x94])
    }

    @Test func backBrightnessIsClamped() {
        #expect(Array(LitraProtocol.backBrightness(percent: 0).prefix(6)) == [0x11, 0xFF, 0x0A, 0x2B, 0x00, 0x01])
    }

    @Test func backColorCoversAllZonesWithCommits() {
        let reports = LitraProtocol.backColor(red: 255, green: 0, blue: 128)
        #expect(reports.count == 14)
        #expect(Array(reports[0].prefix(8)) == [0x11, 0xFF, 0x0C, 0x1B, 0x01, 0xFF, 0x01, 0x80])
        #expect(reports[1] == LitraProtocol.backColorCommit)
        #expect(reports[12][4] == 7)
    }

    @Test func parsesStateResponses() {
        let pad = Array(repeating: UInt8(0), count: 14)
        #expect(LitraProtocol.parse([0x11, 0xFF, 0x06, 0x01, 0x01, 0x00] + pad) == .frontOn(true))
        #expect(LitraProtocol.parse([0x11, 0xFF, 0x06, 0x31, 0x01, 0x90] + pad) == .frontLumen(400))
        #expect(LitraProtocol.parse([0x11, 0xFF, 0x06, 0x81, 0x0B, 0xB8] + pad) == .frontKelvin(3000))
        #expect(LitraProtocol.parse([0x11, 0xFF, 0x0A, 0x1B, 0x00, 0x32] + pad) == .backPercent(50))
        #expect(LitraProtocol.parse([0x11, 0xFF, 0x06, 0x4C, 0x00, 0x32] + pad) == nil)
    }
}
