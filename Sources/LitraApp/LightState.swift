import AppKit
import LitraCore
import Observation

/// Light settings. Changes are persisted and sent to the device; on connect the current state is read back.
@MainActor
@Observable
final class LightState {
    let device = LitraDevice()

    var frontOn: Bool { didSet { changed(frontOn, "frontOn", [LitraProtocol.frontPower(frontOn)]) } }
    var frontLumen: Int { didSet { changed(frontLumen, "frontLumen", [LitraProtocol.frontBrightness(lumen: frontLumen)]) } }
    var frontKelvin: Int { didSet { changed(frontKelvin, "frontKelvin", [LitraProtocol.frontTemperature(kelvin: frontKelvin)]) } }
    var backOn: Bool { didSet { changed(backOn, "backOn", [LitraProtocol.backPower(backOn)]) } }
    var backPercent: Int { didSet { changed(backPercent, "backPercent", [LitraProtocol.backBrightness(percent: backPercent)]) } }
    /// 0xRRGGBB
    var backColor: Int { didSet { changed(backColor, "backColor", backColorReports) } }

    @ObservationIgnored private let defaults = UserDefaults.standard
    /// True while applying values that are already on the device, so they are not sent again.
    @ObservationIgnored private var isSyncing = false
    /// Lights that were on when the Mac went to sleep, restored after wake.
    @ObservationIgnored private var lightsBeforeSleep: (front: Bool, back: Bool)?
    @ObservationIgnored private var wokeAt: Date?

    init() {
        defaults.register(defaults: [
            "frontOn": true, "frontLumen": 200, "frontKelvin": 4500,
            "backOn": false, "backPercent": 50, "backColor": 0xFF8000,
        ])
        frontOn = defaults.bool(forKey: "frontOn")
        frontLumen = defaults.integer(forKey: "frontLumen")
        frontKelvin = defaults.integer(forKey: "frontKelvin")
        backOn = defaults.bool(forKey: "backOn")
        backPercent = defaults.integer(forKey: "backPercent")
        backColor = defaults.integer(forKey: "backColor")

        device.onConnect = { [weak self] in
            self?.restoreAfterSleep()
            self?.readFromDevice()
        }
        device.onReport = { [weak self] in self?.apply($0) }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.turnOffForSleep() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.wokeAt = Date()
                self?.restoreAfterSleep()
            }
        }
    }

    /// Turns both lights off when the Mac goes to sleep, e.g. when the lid is closed.
    private func turnOffForSleep() {
        lightsBeforeSleep = (frontOn, backOn)
        wokeAt = nil
        device.sendNow([LitraProtocol.frontPower(false), LitraProtocol.backPower(false)])
        isSyncing = true
        defer { isSyncing = false }
        frontOn = false
        backOn = false
    }

    /// Switches the lights back on after wake. Over Bluetooth the light often reconnects a few seconds
    /// after wake, so a reconnect within 30 seconds restores them as well.
    private func restoreAfterSleep() {
        guard let lights = lightsBeforeSleep, let wokeAt, Date().timeIntervalSince(wokeAt) < 30, device.isConnected else { return }
        frontOn = lights.front
        backOn = lights.back
    }

    func readFromDevice() {
        device.send(LitraProtocol.stateQueries, key: "state")
    }

    private func apply(_ report: [UInt8]) {
        guard let setting = LitraProtocol.parse(report) else { return }
        isSyncing = true
        defer { isSyncing = false }
        switch setting {
        case .frontOn(let on): frontOn = on
        case .frontLumen(let lumen): frontLumen = lumen
        case .frontKelvin(let kelvin): frontKelvin = kelvin
        case .backOn(let on): backOn = on
        case .backPercent(let percent): backPercent = percent
        }
    }

    private var backColorReports: [[UInt8]] {
        LitraProtocol.backColor(
            red: UInt8((backColor >> 16) & 0xFF),
            green: UInt8((backColor >> 8) & 0xFF),
            blue: UInt8(backColor & 0xFF)
        )
    }

    private func changed(_ value: Any, _ key: String, _ reports: [[UInt8]]) {
        defaults.set(value, forKey: key)
        if !isSyncing { device.send(reports, key: key) }
    }
}
