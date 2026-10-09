/// HID++ output reports for the Logitech Litra Beam LX.
/// Byte layout taken from https://github.com/timrogers/litra-rs
public enum LitraProtocol {
    public static let vendorID = 0x046D
    /// USB and Bluetooth LE
    public static let productIDs = [0xC903, 0xB903]
    public static let usagePage = 0xFF43
    public static let reportID: UInt8 = 0x11

    public static let brightnessRange = 30...400
    public static let temperatureRange = 2700...6500
    public static let temperatureStep = 100
    public static let backBrightnessRange = 1...100
    public static let backZones: ClosedRange<UInt8> = 1...7

    /// Has to be sent after every back color report to apply it.
    public static let backColorCommit: [UInt8] = [0x11, 0xFF, 0x0C, 0x7B, 0x00, 0x00, 0x01, 0x00, 0x00]

    public static func frontPower(_ on: Bool) -> [UInt8] {
        report([0x11, 0xFF, 0x06, 0x1C, on ? 0x01 : 0x00])
    }

    public static func frontBrightness(lumen: Int) -> [UInt8] {
        report([0x11, 0xFF, 0x06, 0x4C] + bigEndian(lumen.clamped(to: brightnessRange)))
    }

    public static func frontTemperature(kelvin: Int) -> [UInt8] {
        let rounded = (kelvin + temperatureStep / 2) / temperatureStep * temperatureStep
        return report([0x11, 0xFF, 0x06, 0x9C] + bigEndian(rounded.clamped(to: temperatureRange)))
    }

    public static func backPower(_ on: Bool) -> [UInt8] {
        report([0x11, 0xFF, 0x0A, 0x4B, on ? 0x01 : 0x00])
    }

    public static func backBrightness(percent: Int) -> [UInt8] {
        report([0x11, 0xFF, 0x0A, 0x2B] + bigEndian(percent.clamped(to: backBrightnessRange)))
    }

    /// Reports (color + commit for each zone) that set all back zones to one color.
    public static func backColor(red: UInt8, green: UInt8, blue: UInt8) -> [[UInt8]] {
        backZones.flatMap { zone in
            [backColor(zone: zone, red: red, green: green, blue: blue), backColorCommit]
        }
    }

    public static func backColor(zone: UInt8, red: UInt8, green: UInt8, blue: UInt8) -> [UInt8] {
        // The device misbehaves on 0 values, so they are raised to 1.
        [
            0x11, 0xFF, 0x0C, 0x1B, zone, max(red, 1), max(green, 1), max(blue, 1),
            0xFF, 0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00,
        ]
    }

    public enum Setting: Equatable {
        case frontOn(Bool), frontLumen(Int), frontKelvin(Int), backOn(Bool), backPercent(Int)
    }

    /// Queries for the current state, answered with input reports parsed by `parse(_:)`.
    /// The back color cannot be read from the device.
    public static let stateQueries: [[UInt8]] = [
        report([0x11, 0xFF, 0x06, 0x01]),
        report([0x11, 0xFF, 0x06, 0x31]),
        report([0x11, 0xFF, 0x06, 0x81]),
        report([0x11, 0xFF, 0x0A, 0x3B]),
        report([0x11, 0xFF, 0x0A, 0x1B]),
    ]

    public static func parse(_ response: [UInt8]) -> Setting? {
        guard response.count >= 6, response[0] == reportID, response[1] == 0xFF else { return nil }
        let value = Int(response[4]) << 8 | Int(response[5])
        switch (response[2], response[3]) {
        case (0x06, 0x01): return .frontOn(response[4] == 1)
        case (0x06, 0x31): return .frontLumen(value)
        case (0x06, 0x81): return .frontKelvin(value)
        case (0x0A, 0x3B): return .backOn(response[4] == 1)
        case (0x0A, 0x1B): return .backPercent(value)
        default: return nil
        }
    }

    private static func report(_ bytes: [UInt8]) -> [UInt8] {
        bytes + Array(repeating: 0x00, count: 20 - bytes.count)
    }

    private static func bigEndian(_ value: Int) -> [UInt8] {
        [UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
    }
}

extension Comparable {
    public func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
