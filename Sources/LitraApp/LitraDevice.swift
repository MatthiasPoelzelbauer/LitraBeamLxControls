import Foundation
import IOKit.hid
import LitraCore
import Observation

/// Finds the Litra Beam LX via IOHIDManager and sends output reports to it.
@MainActor
@Observable
final class LitraDevice {
    private(set) var isConnected = false
    /// "USB" or "Bluetooth"
    private(set) var connection = ""
    @ObservationIgnored var onConnect: (() -> Void)?
    @ObservationIgnored var onReport: (([UInt8]) -> Void)?

    @ObservationIgnored private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    @ObservationIgnored private var device: IOHIDDevice?
    @ObservationIgnored private let writer = ReportWriter()
    @ObservationIgnored private let inputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)

    init() {
        // Over Bluetooth the HID++ collection is not the primary usage, so match on any usage page of the device.
        let matching: [[String: Int]] = LitraProtocol.productIDs.map { productID in
            [
                kIOHIDVendorIDKey: LitraProtocol.vendorID,
                kIOHIDProductIDKey: productID,
                kIOHIDDeviceUsagePageKey: LitraProtocol.usagePage,
            ]
        }
        IOHIDManagerSetDeviceMatchingMultiple(manager, matching as CFArray)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, device in
            let litra = Unmanaged<LitraDevice>.fromOpaque(context!).takeUnretainedValue()
            MainActor.assumeIsolated { litra.attach(device) }
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            let litra = Unmanaged<LitraDevice>.fromOpaque(context!).takeUnretainedValue()
            MainActor.assumeIsolated { litra.detach(device) }
        }, context)

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    /// Queues reports for sending. Reports still waiting under the same key are replaced, so only the latest value is sent.
    func send(_ reports: [[UInt8]], key: String) {
        writer.enqueue(reports, key: key)
    }

    private func attach(_ device: IOHIDDevice) {
        self.device = device
        writer.device = device
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(device, inputBuffer, 64, { context, _, _, _, _, report, length in
            let litra = Unmanaged<LitraDevice>.fromOpaque(context!).takeUnretainedValue()
            let bytes = Array(UnsafeBufferPointer(start: report, count: length))
            MainActor.assumeIsolated { litra.onReport?(bytes) }
        }, context)
        let transport = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String ?? ""
        connection = transport.contains("Bluetooth") ? "Bluetooth" : "USB"
        isConnected = true
        onConnect?()
    }

    private func detach(_ device: IOHIDDevice) {
        guard device == self.device else { return }
        self.device = nil
        writer.device = nil
        isConnected = false
    }
}

/// Writes reports on a background queue, because IOHIDDeviceSetReport blocks for ~60–230 ms per report over Bluetooth.
private final class ReportWriter: @unchecked Sendable {
    private let queue = DispatchQueue(label: "LitraApp.ReportWriter")
    private let lock = NSLock()
    private var pending: [(key: String, reports: [[UInt8]])] = []
    private var isWriting = false
    private var currentDevice: IOHIDDevice?

    var device: IOHIDDevice? {
        get { lock.withLock { currentDevice } }
        set {
            lock.withLock {
                currentDevice = newValue
                pending = []
            }
        }
    }

    func enqueue(_ reports: [[UInt8]], key: String) {
        let startWriting = lock.withLock {
            if let index = pending.firstIndex(where: { $0.key == key }) {
                pending[index].reports = reports
            } else {
                pending.append((key, reports))
            }
            defer { isWriting = true }
            return !isWriting
        }
        if startWriting {
            queue.async { self.writePending() }
        }
    }

    private func writePending() {
        while let (device, report) = nextReport() {
            report.withUnsafeBufferPointer { buffer in
                _ = IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, CFIndex(LitraProtocol.reportID), buffer.baseAddress!, buffer.count)
            }
        }
    }

    private func nextReport() -> (IOHIDDevice, [UInt8])? {
        lock.withLock {
            guard let device = currentDevice, !pending.isEmpty else {
                isWriting = false
                return nil
            }
            let report = pending[0].reports.removeFirst()
            if pending[0].reports.isEmpty {
                pending.removeFirst()
            }
            return (device, report)
        }
    }
}
