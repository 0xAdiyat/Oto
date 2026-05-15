import Foundation
import Network
import Observation
import AppKit
import Darwin

/// Live, passive throughput meter for the system's primary network path.
///
/// Reads cumulative per-interface byte counters via `getifaddrs(3)` once per
/// second, subtracts the previous sample, and publishes a smoothed
/// bytes-per-second rate. `NWPathMonitor` is used only to *select* the active
/// interface (en0, en1, …) and to detect "offline" — it does not expose byte
/// counters itself.
///
/// **Lifecycle is view-scoped.** `start()` and `stop()` are called by the
/// SwiftUI section's `.onAppear` / `.onDisappear`. When the popover is closed,
/// the timer is invalidated and this object costs nothing. Oto is always
/// running in the menu bar, so anything that polls on a wall-clock interval
/// needs to be visibility-gated.
@Observable
@MainActor
final class NetworkThroughputMonitor {

    // MARK: - Public state

    /// Smoothed download rate, bytes/sec. `nil` until the second sample lands.
    var downBytesPerSec: Double?
    /// Smoothed upload rate, bytes/sec. `nil` until the second sample lands.
    var upBytesPerSec: Double?
    /// BSD name of the interface currently being measured (e.g. "en0"). `nil`
    /// when offline.
    var interfaceName: String?
    /// `NWInterface` type — drives the label ("Wi-Fi" / "Ethernet" / …).
    var interfaceKind: NWInterface.InterfaceType?
    /// `true` when `NWPathMonitor` reports a satisfied path. When `false`, the
    /// timer is stopped and rates are cleared.
    var isOnline: Bool = false

    // MARK: - Internals

    @ObservationIgnored private let path = NWPathMonitor()
    @ObservationIgnored private let pathQueue = DispatchQueue(label: "Oto.NetworkThroughputMonitor.path")
    @ObservationIgnored private var timer: DispatchSourceTimer?

    /// Last raw counter sample for the currently-tracked interface. Nil after
    /// any reset (start, interface change, wake) so the next tick is treated
    /// as a baseline, not a delta.
    @ObservationIgnored private var lastSample: (rx: UInt64, tx: UInt64, at: TimeInterval)?

    @ObservationIgnored private var ringDown: [Double] = []
    @ObservationIgnored private var ringUp: [Double] = []
    @ObservationIgnored private let ringCapacity = 30

    @ObservationIgnored private var wakeObserver: NSObjectProtocol?
    @ObservationIgnored private var sleepObserver: NSObjectProtocol?

    /// EMA smoothing factor. 0.3 = ~70% weight on the existing average, 30%
    /// on the new sample — responsive enough to feel live, smooth enough that
    /// a single burst doesn't make the number jump.
    @ObservationIgnored private let smoothingAlpha: Double = 0.3

    @ObservationIgnored private var running: Bool = false

    init() {
        path.pathUpdateHandler = { [weak self] newPath in
            Task { @MainActor in
                self?.handlePathUpdate(newPath)
            }
        }
        path.start(queue: pathQueue)
    }

    deinit {
        // Snapshot stored properties; we can't touch main-actor state from
        // a nonisolated deinit on Swift 6. The Network framework cancels
        // safely from any queue.
        path.cancel()
        timer?.cancel()
        if let w = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(w)
        }
        if let s = sleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(s)
        }
    }

    // MARK: - Lifecycle

    /// Begin sampling. Idempotent — calling twice is safe.
    func start() {
        guard !running else { return }
        running = true

        installWakeObservers()
        resetBaseline()
        scheduleTimer()
    }

    /// Stop sampling. Clears smoothed rates so a reopened popover shows
    /// "Measuring…" rather than a stale number.
    func stop() {
        guard running else { return }
        running = false

        timer?.cancel()
        timer = nil
        downBytesPerSec = nil
        upBytesPerSec = nil
        lastSample = nil
        ringDown.removeAll(keepingCapacity: true)
        ringUp.removeAll(keepingCapacity: true)

        if let w = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(w)
            wakeObserver = nil
        }
        if let s = sleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(s)
            sleepObserver = nil
        }
    }

    // MARK: - Path updates

    private func handlePathUpdate(_ newPath: NWPath) {
        let satisfied = newPath.status == .satisfied
        let primary = newPath.availableInterfaces.first

        let nameChanged = primary?.name != interfaceName
        isOnline = satisfied && primary != nil
        interfaceName = primary?.name
        interfaceKind = primary?.type

        if !isOnline {
            // Lost connectivity — clear rates but keep the timer paused
            // rather than torn down, so a path-back event resumes cleanly.
            downBytesPerSec = nil
            upBytesPerSec = nil
            lastSample = nil
            return
        }

        if nameChanged {
            // Switched interfaces (Wi-Fi → Ethernet, etc.). Drop the
            // previous counter baseline so we don't subtract en0's bytes
            // from en1's bytes and emit a spike.
            resetBaseline()
        }
    }

    // MARK: - Timer

    private func scheduleTimer() {
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + .seconds(1), repeating: .seconds(1))
        t.setEventHandler { [weak self] in
            self?.sample()
        }
        t.resume()
        timer = t
    }

    private func sample() {
        guard running, isOnline, let name = interfaceName else { return }
        guard let counters = Self.readCounters(for: name) else { return }
        let now = Date().timeIntervalSince1970

        defer {
            lastSample = (rx: counters.rx, tx: counters.tx, at: now)
        }

        guard let prev = lastSample else {
            // First sample — establish baseline only, don't emit.
            return
        }

        let dt = now - prev.at
        guard dt > 0 else { return }

        // Counter rollover or interface reset: ifi_*bytes is u_int64 on
        // macOS so true rollover is astronomical, but cable-pull / kernel
        // reset can still snap the counter back. Treat any decrease as a
        // fresh baseline rather than emitting a negative rate.
        let rawDown: Double
        let rawUp: Double
        if counters.rx < prev.rx || counters.tx < prev.tx {
            rawDown = 0
            rawUp = 0
        } else {
            rawDown = Double(counters.rx - prev.rx) / dt
            rawUp   = Double(counters.tx - prev.tx) / dt
        }

        downBytesPerSec = ema(prev: downBytesPerSec, next: rawDown)
        upBytesPerSec   = ema(prev: upBytesPerSec,   next: rawUp)

        appendRing(&ringDown, rawDown)
        appendRing(&ringUp,   rawUp)
    }

    private func ema(prev: Double?, next: Double) -> Double {
        guard let prev else { return next }
        return prev + smoothingAlpha * (next - prev)
    }

    private func appendRing(_ ring: inout [Double], _ value: Double) {
        if ring.count >= ringCapacity {
            ring.removeFirst(ring.count - ringCapacity + 1)
        }
        ring.append(value)
    }

    // MARK: - Baseline / wake

    private func resetBaseline() {
        lastSample = nil
        downBytesPerSec = nil
        upBytesPerSec = nil
    }

    private func installWakeObservers() {
        guard wakeObserver == nil else { return }
        let nc = NSWorkspace.shared.notificationCenter
        wakeObserver = nc.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Without this, the first post-wake tick would compute a delta
            // across the sleep interval — minutes or hours of bytes shown
            // as a single second of throughput. Reset the baseline so the
            // next tick is a no-op and the one after is a real reading.
            Task { @MainActor in self?.resetBaseline() }
        }
        sleepObserver = nc.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.resetBaseline() }
        }
    }

    // MARK: - getifaddrs

    /// Returns cumulative received/transmitted bytes for the given BSD
    /// interface name. Walks the `getifaddrs` linked list looking for the
    /// `AF_LINK` entry whose `ifa_name` matches and pulls `ifi_ibytes` /
    /// `ifi_obytes` from its `if_data` payload. Returns `nil` if the
    /// interface is gone or has no link-layer entry.
    nonisolated private static func readCounters(for name: String) -> (rx: UInt64, tx: UInt64)? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let head else { return nil }
        defer { freeifaddrs(head) }

        var rx: UInt64 = 0
        var tx: UInt64 = 0
        var found = false

        var cursor: UnsafeMutablePointer<ifaddrs>? = head
        while let p = cursor {
            let entry = p.pointee
            let family = Int32(entry.ifa_addr?.pointee.sa_family ?? 0)
            if family == AF_LINK,
               let cName = entry.ifa_name,
               String(cString: cName) == name,
               let data = entry.ifa_data {
                let info = data.assumingMemoryBound(to: if_data.self).pointee
                rx = UInt64(info.ifi_ibytes)
                tx = UInt64(info.ifi_obytes)
                found = true
                break
            }
            cursor = entry.ifa_next
        }

        return found ? (rx, tx) : nil
    }
}

extension NWInterface.InterfaceType {
    /// User-facing label for the interface kind. Matches the wording Apple
    /// uses in System Settings → Network.
    var otoDisplayName: String {
        switch self {
        case .wifi:           return "Wi-Fi"
        case .wiredEthernet:  return "Ethernet"
        case .cellular:       return "Cellular"
        case .loopback:       return "Loopback"
        case .other:          return "Other"
        @unknown default:     return "Network"
        }
    }
}
