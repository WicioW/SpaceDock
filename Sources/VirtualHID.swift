import AppKit

// Experiment P1g: real HID mouse input through Karabiner's virtual HID device.
// Mission Control on macOS 27 ignores every CGEventPost'ed event (T21), but input coming from
// a HID device is real input. Karabiner-DriverKit-VirtualHIDDevice (installed with
// Karabiner-Elements) exposes a virtual pointing device through a root-only socket.
//
// Wire format (Karabiner-DriverKit-VirtualHIDDevice v8.5.0, pqrs unix_domain_stream):
//   frame   = u32 BE body size | u8 message type (4 = request) | u64 BE request id | data
//   data    = u16 client protocol version (7, native order) | u8 request | payload
//   request : 3 = virtual_hid_pointing_initialize, 11 = post_pointing_input_report
//   pointing_input (packed) = u32 buttons | i8 x | i8 y | i8 vertical wheel | i8 horizontal wheel
// The device lives only while the socket stays connected.

/// The binary `sudo` runs for the virtual mouse. A password-free sudoers rule must point at a
/// root-owned copy: a rule for the build output (user-writable) would let anything running as
/// the user swap the file and get root. See docs/app.md, "Wirtualna mysz bez hasła".
let installedHelper = "/usr/local/libexec/spaces-layout"
let rootHelperBinary = FileManager.default.isExecutableFile(atPath: installedHelper) ? installedHelper : CommandLine.arguments[0]

private let vhidSocket = "/Library/Application Support/org.pqrs/tmp/rootonly/karabiner_virtual_hid_device_service.sock"

final class VirtualMouse {
    private let fd: Int32
    private var requestID: UInt64 = 0

    init?() {
        fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let path = Array(vhidSocket.utf8CString)
        guard path.count <= MemoryLayout.size(ofValue: addr.sun_path) else { close(fd); return nil }
        withUnsafeMutableBytes(of: &addr.sun_path) { raw in
            path.withUnsafeBytes { raw.copyMemory(from: $0) }
        }
        let ok = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) == 0
            }
        }
        guard ok else {
            print("Nie mogę połączyć się z \(vhidSocket) (errno \(errno)). Uruchom przez sudo.")
            close(fd); return nil
        }
        // Read the daemon's status frames (also keeps its writes from blocking). Status data is
        // (response, value) byte pairs; response 5 = virtual_hid_pointing_ready.
        let fd = self.fd, ready = pointingReady
        Thread.detachNewThread {
            var buf = [UInt8](repeating: 0, count: 1024), pending: [UInt8] = []
            while true {
                let n = read(fd, &buf, buf.count)
                if n <= 0 { return }
                pending += buf[0..<n]
                while pending.count >= 4 {
                    let size = Int(pending[0]) << 24 | Int(pending[1]) << 16 | Int(pending[2]) << 8 | Int(pending[3])
                    guard pending.count >= 4 + size, size >= 1 else { break }
                    let body = Array(pending[4..<4 + size])
                    pending.removeFirst(4 + size)
                    let data = body[0] >= 4 ? Array(body.dropFirst(9)) : Array(body.dropFirst()) // request/response carry an id
                    for i in stride(from: 0, to: data.count - 1, by: 2) where data[i] == 5 && data[i + 1] == 1 {
                        ready.signal()
                    }
                }
            }
        }
    }

    private let pointingReady = DispatchSemaphore(value: 0)

    deinit { close(fd) }

    private func send(_ request: UInt8, _ payload: [UInt8] = []) {
        requestID += 1
        var data: [UInt8] = [7, 0, request] + payload   // protocol version 7, little-endian u16
        let body = UInt32(1 + 8 + data.count)
        var frame: [UInt8] = [UInt8(body >> 24), UInt8(body >> 16 & 0xff), UInt8(body >> 8 & 0xff), UInt8(body & 0xff), 4]
        for shift in stride(from: 56, through: 0, by: -8) { frame.append(UInt8(requestID >> UInt64(shift) & 0xff)) }
        frame += data
        data.removeAll()
        _ = frame.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
    }

    /// Creates the virtual pointing device; returns once the daemon reports it ready
    /// (falls back to 1.5 s if no status arrives).
    func initialize() {
        send(3)
        if pointingReady.wait(timeout: .now() + 1.5) == .success {
            Thread.sleep(forTimeInterval: 0.15) // let the HID system pick the device up
        }
    }

    func report(pressed: Bool, dx: Int = 0, dy: Int = 0) {
        let x = UInt8(bitPattern: Int8(clamping: dx)), y = UInt8(bitPattern: Int8(clamping: dy))
        send(11, [pressed ? 1 : 0, 0, 0, 0, x, y, 0, 0])
    }

    /// Moves the real cursor to `target` with small relative reports (pointer acceleration
    /// applies, so it steers by the current position instead of precomputing steps).
    func move(to target: CGPoint, pressed: Bool) {
        for _ in 0..<600 {
            let now = CGEvent(source: nil)?.location ?? target
            let dx = target.x - now.x, dy = target.y - now.y
            if abs(dx) < 2, abs(dy) < 2 { return }
            // Big steps while far, small ones near the target (acceleration overshoots otherwise).
            // While a thumbnail is held, Mission Control's drag ghost lags behind fast moves and
            // the drop lands in the wrong slot, so dragging stays at the speed that worked (T29).
            let far = max(abs(dx), abs(dy))
            let limit = far > 200 && !pressed ? 30 : far > 60 ? 14 : 5
            report(pressed: pressed, dx: Int((dx / 3).rounded()).clamped(-limit, limit), dy: Int((dy / 3).rounded()).clamped(-limit, limit))
            Thread.sleep(forTimeInterval: 0.006)
        }
    }

    func click(at p: CGPoint) {
        move(to: p, pressed: false)
        report(pressed: true); Thread.sleep(forTimeInterval: 0.08)
        report(pressed: false)
    }

    func drag(from a: CGPoint, to b: CGPoint) {
        move(to: a, pressed: false)
        report(pressed: true); Thread.sleep(forTimeInterval: 0.15)
        move(to: b, pressed: true)
        // ponytail: fixed pause for the bar to open a gap. 0.18 s merged into Split View (T30),
        // 0.3 s worked (T29). restore-drag detects a merge and stops.
        Thread.sleep(forTimeInterval: 0.3)
        report(pressed: false)
    }
}

/// Root side of a long-lived helper: one `sudo`, one virtual mouse, commands on stdin
/// (`click X Y`, `drag X1 Y1 X2 Y2`, `quit`), one `ok` line back per command.
func vhidServe() {
    guard let mouse = VirtualMouse() else { exit(1) }
    mouse.initialize()
    print("ready"); fflush(stdout)
    while let line = readLine() {
        let parts = line.split(separator: " ")
        let n = parts.dropFirst().compactMap { Double($0) }
        switch parts.first {
        case "click" where n.count == 2: mouse.click(at: CGPoint(x: n[0], y: n[1]))
        case "move" where n.count == 2: mouse.move(to: CGPoint(x: n[0], y: n[1]), pressed: false)
        case "drag" where n.count == 4: mouse.drag(from: CGPoint(x: n[0], y: n[1]), to: CGPoint(x: n[2], y: n[3]))
        case "quit": return
        default: break
        }
        print("ok"); fflush(stdout)
    }
}

/// User side of the helper.
final class MouseHelper {
    private let process = Process()
    private let input = Pipe(), output = Pipe()
    private var buffer = Data()

    /// Starts the helper without waiting, so the virtual mouse comes up while Mission
    /// Control opens; call `waitReady()` before the first command.
    init?() {
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", rootHelperBinary, "vhid-serve"]
        process.standardInput = input
        process.standardOutput = output
        guard (try? process.run()) != nil else { print("Nie da się uruchomić sudo"); return nil }
    }

    func waitReady() -> Bool {
        guard readLine() == "ready" else { print("Wirtualna mysz nie wystartowała (najpierw: sudo -v)"); return false }
        return true
    }

    private func readLine() -> String? {
        while true {
            if let nl = buffer.firstIndex(of: 0x0A) {
                let line = String(decoding: buffer[..<nl], as: UTF8.self)
                buffer.removeSubrange(...nl)
                return line
            }
            let chunk = output.fileHandleForReading.availableData
            if chunk.isEmpty { return nil }
            buffer += chunk
        }
    }

    /// false when the helper is gone (a write to its closed pipe would otherwise kill this
    /// process with SIGPIPE, silently: that is how the app vanished in T38).
    @discardableResult
    func send(_ command: String) -> Bool {
        guard process.isRunning, (try? input.fileHandleForWriting.write(contentsOf: Data((command + "\n").utf8))) != nil else {
            print("✗ wirtualna mysz przestała działać"); return false
        }
        return readLine() == "ok"
    }

    func quit() {
        guard process.isRunning else { return }
        try? input.fileHandleForWriting.write(contentsOf: Data("quit\n".utf8))
        process.waitUntilExit()
    }
}

private extension Int {
    func clamped(_ lo: Int, _ hi: Int) -> Int { Swift.min(Swift.max(self, lo), hi).nonZero(sign: self) }
    func nonZero(sign original: Int) -> Int { self == 0 && original != 0 ? (original > 0 ? 1 : -1) : self }
}

/// Root-side commands, run as: sudo spaces-layout vhid-click X Y | vhid-drag X1 Y1 X2 Y2
func vhidCommand(_ args: [String]) {
    let n = args.dropFirst().compactMap { Double($0) }
    guard let mouse = VirtualMouse() else { exit(1) }
    mouse.initialize()
    switch args.first {
    case "vhid-click" where n.count == 2:
        mouse.move(to: CGPoint(x: n[0], y: n[1]), pressed: false)
        mouse.report(pressed: true); Thread.sleep(forTimeInterval: 0.08)
        mouse.report(pressed: false)
    case "vhid-drag" where n.count == 4:
        mouse.move(to: CGPoint(x: n[0], y: n[1]), pressed: false)
        mouse.report(pressed: true); Thread.sleep(forTimeInterval: 0.15)
        mouse.move(to: CGPoint(x: n[2], y: n[3]), pressed: true)
        Thread.sleep(forTimeInterval: 0.3)
        mouse.report(pressed: false)
    default:
        print("Użycie: sudo spaces-layout vhid-click X Y | vhid-drag X1 Y1 X2 Y2"); exit(1)
    }
    Thread.sleep(forTimeInterval: 0.3) // let the last report land before the device goes away
}

/// User-side: opens Mission Control, finds coordinates, then runs the root part via `sudo -n`
/// (run `sudo -v` first so it doesn't prompt with Mission Control open).
func runAsRoot(_ args: [String]) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
    p.arguments = ["-n", rootHelperBinary] + args
    try? p.run()
    p.waitUntilExit()
    if p.terminationStatus != 0 { print("sudo nie przeszło (najpierw: sudo -v)") }
}

/// Thumbnail centers of the Spaces bar after opening Mission Control and hovering it.
func openBarCenters() -> (thumbs: [CGPoint], row: CGFloat)? {
    openMissionControl()
    guard waitUntil(timeout: 2, { !spaceThumbnails().isEmpty }) else { closeMissionControl(); return nil }
    Thread.sleep(forTimeInterval: 0.3)
    CGWarpMouseCursorPosition(CGPoint(x: 756, y: 20)) // a warp is not an event; it just places the cursor
    CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: 756, y: 20), mouseButton: .left)?
        .post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.6)
    guard let bar = spacesList().flatMap(frame) else { return nil }
    let centers = spaceThumbnails().compactMap(frame).map { CGPoint(x: $0.midX, y: bar.midY) }
    return (centers, bar.midY)
}

/// Where to release so the dragged Space is inserted at slot `to` instead of being dropped
/// *onto* that Space (which merges the two full-screen apps into one Split View Space):
/// the gap on the side of the target facing where the thumbnail came from.
func dropPoint(_ centers: [CGPoint], from: Int, to: Int) -> CGPoint {
    let i = to - 1, row = centers[i].y
    let half = centers.count > 1 ? abs(centers[1].x - centers[0].x) / 2 : 84
    return CGPoint(x: from > to ? centers[i].x - half : centers[i].x + half, y: row)
}

func mcclickV(_ n: Int) {
    guard let (thumbs, _) = openBarCenters(), thumbs.indices.contains(n - 1) else { print("Brak paska"); return }
    let p = thumbs[n - 1]
    runAsRoot(["vhid-click", "\(p.x)", "\(p.y)"])
    Thread.sleep(forTimeInterval: 1)
    print(spacesList() == nil ? "Klik zadziałał (Mission Control zamknięte)" : "Mission Control dalej otwarte: klik zignorowany")
    if spacesList() != nil { closeMissionControl() }
}

func mcdragV(_ from: Int, _ to: Int) {
    let t0 = Date()
    guard let (thumbs, _) = openBarCenters(), thumbs.indices.contains(from - 1), thumbs.indices.contains(to - 1) else {
        print("Brak paska albo złe numery"); return
    }
    let a = thumbs[from - 1], b = dropPoint(thumbs, from: from, to: to)
    print("Przeciągam z (\(Int(a.x)), \(Int(a.y))) na szczelinę (\(Int(b.x)), \(Int(b.y)))")
    runAsRoot(["vhid-drag", "\(a.x)", "\(a.y)", "\(b.x)", "\(b.y)"])
    Thread.sleep(forTimeInterval: 0.4)
    if spacesList() != nil { closeMissionControl() }
    Thread.sleep(forTimeInterval: 0.5)
    print(String(format: "Gotowe w %.1f s", Date().timeIntervalSince(t0)))
}
