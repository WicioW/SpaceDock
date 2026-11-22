# Alternative input sources that Mission Control accepts as real (no Karabiner, no Apple Developer account)

Context from the project's own tests (not re-verified here): Mission Control (com.apple.WindowManager on macOS 27) ignores every CGEventPost event, including a byte-exact replay with an attached IOHIDEvent and Hammerspoon. It accepts the Karabiner DriverKit virtual pointer, but only on the display Mission Control was opened from. CoreHID `HIDVirtualDevice` returns nil without the entitlement. With the entitlement, ad-hoc or self-signed, AMFI kills the process.

Research budget note: about 20 search/fetch calls. Many vendor-specific questions (BetterTouchTool, SteerMouse, Jump Desktop, Parsec, Switch Control internals) were not answered by any source I found. They are listed under Gaps rather than guessed.

## 1. Software virtual HID (DriverKit / CoreHID / IOHIDUserDevice) without our own Apple account

### Takeaway
The only supported software path to a real virtual HID pointer is CoreHID `HIDVirtualDevice`. It needs the restricted `com.apple.developer.hid.virtual.device` entitlement, which has no "development only" variant and needs a paid account and Apple approval. AMFI enforces it, so self-signing cannot work with SIP on (this matches the project's test). Practically, the only no-account route is to reuse a third party's notarized driver that exposes a pointer and has a usable client API. Karabiner's driver is the known one, and I found no documented alternative.

### Cited Findings
- `HIDVirtualDevice(properties:)` returns nil unless the code is signed with `com.apple.developer.hid.virtual.device`. Apple DTS (Kevin Elliott, Sep 2024) said this entitlement must be requested via the DriverKit/system-extensions request form and has no development-only variant. The only workaround he described was disabling AMFI, recommended only in a VM. — [Apple Dev Forums 764540](https://developer.apple.com/forums/thread/764540)
- Mar 2026 (DTS, accepted answer):
  - Both DriverKit and CoreHID virtual devices need restricted entitlements. DriverKit's "Development Only" variants need a paid membership. CoreHID virtual has no dev variant yet (r.173531752).
  - The restriction is intentional because "virtual HID devices can be used for attacks."
  - The alternatives offered were disabling SIP+AMFI (boot-level, not per session) or CGEvent injection.
  - Free-tier access is restricted on purpose.
  — [Apple Dev Forums 820708](https://developer.apple.com/forums/thread/820708)
- Aug 2026 (DTS):
  - `com.apple.developer.driverkit.family.hid.virtual.device` "does absolutely nothing" and is defunct.
  - CoreHID's virtual device API is the intended way to make virtual devices.
  - DEXT and CoreHID virtual devices "should provide identical capabilities."
  - The portal lists the CoreHID key as "HID Virtual Device" under Capability Requests.
  — [Apple Dev Forums 840311](https://developer.apple.com/forums/thread/840311)
- Evidence that a CoreHID virtual device behaves like hardware at the NX/AppKit level: in Sep 2026, a Developer ID-signed `HIDVirtualDevice` pen digitizer on macOS 26.2 delivered position, proximity and tip to `NSEvent`. Pressure was truncated to 0 by SkyLight's `EventTranslator::hidevent_to_nxevent_translation`, and DTS confirmed the bug (FB24785043). So virtual-device events go through the same SkyLight HID-to-NX translation as real hardware. — [Apple Dev Forums 845787](https://developer.apple.com/forums/thread/845787)
- Karabiner's DriverKit virtual HID driver says its virtual devices are recognized by macOS the same as physical hardware. kanata on macOS 11+ requires this same driver, so kanata is not an alternative. — [kanata README](https://www.github.com/jtroo/kanata); [Karabiner-DriverKit-VirtualHIDDevice](https://www.github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice); [DEV guide](https://dev.to/the_lazy_/setting-up-kanata-with-karabiner-driverkit-virtualhiddevice-on-macos-1o47)
- Karabiner driver forks (kmonad, xd2) exist, but releases are "not available" for some. You would have to build and notarize them yourself, which needs an account. — [kmonad fork](https://www.github.com/kmonad/Karabiner-DriverKit-VirtualHIDDevice); [xd2 fork](https://github.com/xd2/Karabiner-DriverKit-VirtualHIDDevice)
- Logitech G HUB ships a notarized DEXT, the "Logitech G HUB HID Driver Extension," approved under Login Items & Extensions on macOS 15. Its purpose per Logitech is communicating with supported devices. Nothing documents a virtual pointer or a client API. — [Logitech support](https://support.logi.com/hc/en-in/articles/26420719261207-Why-do-I-need-to-manually-go-to-System-Settings-and-give-permission-to-the-DEXT-driver-for-G-HUB)
- Ecosystem risk for any DriverKit virtual HID: a macOS 26.4 beta report said built-in keyboard events no longer reached DriverKit virtual HID layers. This is an unverified forum report. — [Apple Dev Forums 817009](https://developer.apple.com/forums/thread/817009)

### Inferences
- Without our own account, the options are limited:
  - Karabiner's driver, via its documented client protocol, which the project excludes.
  - Another vendor's notarized DEXT, which would need reverse-engineering its private user-client. That is fragile and possibly against its license. No candidate with a documented API was found.
  - Hardware (section 3).
- Unofficial reuse of the Karabiner DEXT through other frontends (kanata, kmonad, `karabiner-driverkit` Rust crate) still installs Karabiner's driver, so it does not satisfy "without Karabiner-DriverKit-VirtualHIDDevice."
- Cheap test of whether a vendor DEXT exposes a pointer: install it and run `ioreg -l -w0 | grep -i -E "virtual|PrimaryUsage"`, or `hidutil list`. Look for a GenericDesktop/Mouse (UsagePage 1, Usage 2) service owned by the vendor's DEXT.

### Gaps
- I found no source that BetterTouchTool, SteerMouse, USB Overdrive, Mac Mouse Fix, LinearMouse, Logitech Options+ or G HUB expose a programmable virtual pointer with a CLI or socket API.
- I found no source on whether Jump Desktop, Parsec, TeamViewer, AnyDesk, ShareMouse, Synergy or Deskflow install a virtual HID device on macOS or inject via CGEvent.
- I found no source on `IOHIDUserDevice` entitlement requirements on macOS 15–27. Historically it needed `com.apple.private.hid.*`-style entitlements; that is unverified and from training knowledge.

## 2. Remote-desktop, KVM and other third-party injectors: CGEvent or real HID?

### Takeaway
Every injector whose source I could inspect uses CGEvent or the older CGPostMouseEvent, so all of them should be rejected like Hammerspoon. One untested lead: Chrome Remote Desktop deliberately kept the deprecated `CGPostMouseEvent` on macOS ≤26 because it lets "the OS detect double-clicks and drags from low-level mouse state." It is a different code path from CGEventPost and is cheap to try.

### Cited Findings
- Chrome Remote Desktop host (current HEAD):
  - On macOS ≥27 it uses `CGEventCreateMouseEvent(nullptr, …)` and `CGEventPost(kCGSessionEventTap, …)`.
  - On macOS ≤26 it uses the deprecated `CGPostMouseEvent` "for safety… letting the OS detect double-clicks and drags from low-level mouse state" (crbug.com/677857).
  - There is no IOHIDPostEvent and no HIDSystemState source.
  — [input_injector_mac.cc](https://chromium.googlesource.com/chromium/src/+/HEAD/remoting/host/input_injector_mac.cc)
- Deskflow's macOS client simulates input via CGEventPost and captures via an HID-level event tap. This is a secondary source (a Chinese blog), not the code. — [CSDN Deskflow overview](https://damodev.csdn.net/6a433f3c662f9a54cb86503d.html)
- KDE Connect's macOS remote input and OpenLogi both use CGEvent on macOS. OpenLogi triggers Mission Control and Show Desktop via private SPIs rather than input. — [KDE macosremoteinput.mm](https://lxr.kde.org/source/network/kdeconnect-kde/plugins/mousepad/macosremoteinput.mm); [OpenLogi injection](https://instagit.com/AprilNEA/OpenLogi/openlogi-input-injection-methods/)
- WindowServer filters synthetic events:
  - `CGXSenderCanSynthesizeEvents()` checks the `hid-control` entitlement/sandbox. If it fails, WindowServer logs "Sender is prohibited from synthesizing events."
  - Protected UI drops mouse events whose "sender's PID … isn't 0 or self." Only PID-0 (OS-generated) events pass.
  - This is from the High Sierra/Mojave era, so possibly outdated, but it is the mechanism the project is likely hitting.
  — [Objective-See "Synthetic Reality"](https://objective-see.org/blog/blog_0x36.html)
- A 2026 macOS 26.5 write-up reached the same conclusion for Carbon hotkeys. CGEventPost events reach WindowServer but are dropped before the hotkey matcher. The two ways past it it names are a Mac App Store identity or a virtual HID device. — [nickboy "Tahoe hotkey dead end"](https://nickboy-github-io.pages.dev/posts/tahoe-hotkey-dead-end/)
- Mac Mouse Fix has its own "Click and Drag for Mission Control & Spaces" feature, with an open bug #1124 about it getting stuck. This is MMF's own gesture emulation, not a virtual HID device. — [MMF issues listing](https://issues.ecosyste.ms/hosts/GitHub/repositories/noah-nuebling%2Fmac-mouse-fix/issues); [MMF 3.0.0-Beta-7 notes](https://newreleases.io/project/github/noah-nuebling/mac-mouse-fix/release/3.0.0-Beta-7)
- Universal Control: the receiving Mac gets events over Rapport/AWDL ("Received event ID 'EVNT'") and turns them into actions "just as if… a locally-connected trackpad." The article does not say whether it injects through IOHIDEventSystem or into SkyLight. — [Eclectic Light "Inside Universal Control"](https://eclecticlight.co/2022/06/06/inside-universal-control/) (2022, possibly outdated)

### Inferences
- `CGPostMouseEvent` test (5 min). Call `CGPostMouseEvent(pt, true, 1, true)`, then move with the button held, then release, while Mission Control is open. It is deprecated but still exported. CRD dropping it at macOS 27 hints it may be broken or removed on 27, so try it on 26 as well. Likely outcome: rejected, because it probably ends in the same SkyLight post path. Not verified.
- Universal Control and macOS Screen Sharing are Apple-signed processes, possibly holding `hid-control` or posting as a trusted sender. They are the most plausible software paths that Mission Control would accept. But they are driven by a second Apple device (Mac or iPad) or a VNC client, not by our app on the same machine.
- A same-machine loopback is a possible test: a VNC client on localhost to `screensharingd`. macOS normally refuses or limits connecting to itself, so this is unverified. A second Mac or VM running a scripted VNC client is more realistic.
- Cheap test: enable Screen Sharing (System Settings > General > Sharing), connect from another Mac or iPad VNC client, open Mission Control on the target and drag a Space thumbnail. If that works, scripted VNC from another device is a viable but clunky input source. VNC clients are scriptable, for example `vncdotool` in Python.

### Gaps
- I found no source describing how `screensharingd` injects input: IOHIDEventSystem, a SkyLight private post, or CGEvent with the `hid-control` entitlement.
- I found no source on whether Mission Control space-drag works under Screen Sharing or Universal Control on macOS 26/27.
- I found no source on noswoosh, InstantSpaceSwitcher, DockDoor or Swish internals regarding Mission Control validation. A Jorvik Software note (Apr 2026) says synthetic Dock gesture events needed an active session-level event tap on a newer macOS. It covers gesture events, not drags, and was not fetched. — [Jorvik "When the Stars Align"](https://jorvik-software.pages.dev/notes/2026/04/10/when-the-stars-align)

## 3. Hardware HID: USB (RP2040 / CH9329 / Leonardo / ESP32-S2/S3) or BLE (ESP32)

### Takeaway
This is the most reliable route that needs no account. A USB HID mouse controlled over serial is real hardware to macOS: no entitlement, no driver, no TCC beyond serial port access. The cheapest ready-made option is a CH9329 UART-to-USB-HID module (about $3–6) with an absolute mouse and a documented serial protocol. A USB-UART dongle feeds it from our app. An RP2040 with TinyUSB, or the PiKVM "pico-hid" firmware, is the flexible DIY option. An iPhone cannot act as a BLE HID mouse.

### Cited Findings
- CH9329:
  - It is a UART-to-USB-HID bridge supporting absolute and relative mouse plus keyboard.
  - Absolute coordinates are 12-bit (0–4095 × 0–4095).
  - The datasheet recommends keyboard+mouse mode for "Linux/Android/MAC OS."
  - On the host it appears as `/dev/cu.*` via a USB-serial adapter.
  — [kvm-serial CH9329 guide](https://sjmf.github.io/kvm-serial/CH9329_GUIDE/); [CH9329 protocol](https://sjmf.github.io/kvm-serial/CH9329_PROTO/); [datasheet](https://git.imuslab.com/TC/RemdesKVM/raw/master/datasheets/ch9329.pdf); [pych9329-hid on PyPI](https://pypi.org/project/pych9329-hid/0.2.0/); [LCSC part](https://www.lcsc.com/product-detail/C2838834.html)
- PiKVM Pico HID (RP2040) emulates USB keyboard plus mouse in absolute and relative modes, controlled over SPI or UART. Absolute mode sends "the exact coordinates (X,Y) where the cursor should be moved." — [PiKVM pico_hid docs](https://git.blob42.xyz/Archives/pikvm/blame/commit/fbe9ea26560e8b18f52c0527b158f8e7788afd14/docs/pico_hid.md); [PiKVM mouse docs](https://git.blob42.xyz/Archives/pikvm/raw/commit/47aa69a161cffeb0c887a7b4d34caf1a4fe7a88c/docs/mouse.md)
- A CircuitPython absolute-mouse library exists for RP2040 and SAMD boards, and is a quick prototype path. — [Neradoc CircuitPython_Absolute_Mouse](https://github.com/Neradoc/CircuitPython_Absolute_Mouse/blob/main/README.rst)
- ESP32 BLE options:
  - AsTeRICS esp32_mouse_keyboard is a BLE HID mouse/keyboard with a serial API for external control.
  - HijelHID_BLEMouse (NimBLE) states macOS support.
  - hid-remapper (jfedor2) is a USB or nRF52840 BLE remapper, not serial-driven.
  — [asterics/esp32_mouse_keyboard](https://WWW.GITHUB.COM/asterics/esp32_mouse_keyboard); [HijelHID_BLEMouse](https://github.com/HijelHub/HijelHID_BLEMouse); [hid-remapper](https://github.com/jfedor2/hid-remapper)
- bt2usb (Pico W) notes that macOS does not support generic trackpads or high-resolution scroll HID devices. Use a plain mouse descriptor, not a digitizer or trackpad. — [bt2usb](https://gh.r-mj.com/timothyb89/bt2usb)
- macOS USB digitizer (absolute) support has had quirks. See the Apple forum thread on USB HID digitizer support on macOS. — [Apple Dev Forums 829408](https://developer.apple.com/forums/thread/829408)
- iPhone as HID: CoreBluetooth refuses to publish the HID service 0x1812 ("The specified UUID is not allowed for this operation"), so a stock iOS app cannot be a BLE mouse. — [Apple Dev Forums 725238](https://developer.apple.com/forums/thread/725238); [bluetooth-dev 2014](https://lists.apple.com/archives/bluetooth-dev/2014/Sep/msg00008.html)

### Inferences
- Hardware HID enters IOHIDFamily and IOHIDEventSystem exactly like a real mouse. It is the same layer at which the Karabiner virtual pointer was accepted, so Mission Control should accept it. The same "only on the display Mission Control was opened from" caveat probably applies.
- Absolute mode (0–4095) maps across the combined display bounds. Relative mode is subject to pointer acceleration and needs closed-loop correction: read `CGEventGetLocation` and adjust. Prefer absolute.
- Latency: USB full-speed HID polls at 1–8 ms, and 115200-baud UART adds under 1 ms per short frame, so expect under 10 ms end-to-end. This is an estimate, not measured. Reliability concerns are physical: the dongle occupies a USB port and must be plugged in.
- Cheap test (about 30 min, about $5–10): CH9329 plus a CP2102 or CH340 USB-UART. Plug the CH9329 into the Mac, `pip install pych9329-hid`, open Mission Control, send absolute move, left-down, a series of moves, then left-up across a Space thumbnail. An Arduino Leonardo or Pro Micro (ATmega32U4) with `Mouse.h` and a serial command loop works too, but it is relative-only out of the box.

### Gaps
- I found no 2024–2026 source explicitly showing a CH9329 or Pico absolute mouse working on macOS 26/27 Mission Control. The inference rests on it being genuine USB HID.
- No measured latency figures were found.

## 4. Apple accessibility input paths (Mouse Keys, Switch Control, Voice Control, Head Pointer) and AX/keyboard control of the Spaces bar

### Takeaway
Voice Control can drag via grid numbers ("Drag 3 to 14"). Custom commands can run Shortcuts, but there is no documented programmatic trigger for a drag. Mouse Keys driven by synthetic key events was the 2017 PID-0 bypass (CVE-2017-7150). Since Mojave, synthetic events are ignored unless the app is authorized, and whether Mouse Keys still reacts to CGEvent key posts on 26/27 is undocumented. Nothing documented exposes Space reordering via AX actions or keyboard.

### Cited Findings
- Voice Control supports "Drag [item] to [location]" and grid-number drags ("Drag 3 to 14"). Custom commands can be defined with an action, including running a Shortcut. — [Apple: Voice Control commands](https://support.apple.com/guide/mac-help/mh40719); [Apple: Customize Voice Control](https://support.apple.com/guide/mac-help/mchl9899c8a5)
- Mouse Keys:
  - Wardle (2017–18) enabled Mouse Keys and posted keypad-5 (keycode 87). The OS then generated a click with sender PID 0, accepted by protected UI.
  - Apple patched this as CVE-2017-7150.
  - Since Mojave, macOS "globally ignores synthetic events unless the user explicitly grants an application permission."
  — [Objective-See blog 0x36](https://objective-see.org/blog/blog_0x36.html); [Jamf "Synthetic Reality"](https://www.jamf.com/blog/synthetic-reality/) (old, possibly outdated)

### Inferences
- If Mouse Keys still converts CGEvent keypad presses into OS-generated pointer events on 26/27, it would be a pure-software, no-account path. The CVE fix suggests Apple now filters synthetic keys out of Mouse Keys, or marks the resulting events.
- Cheap test (5 min):
  1. Enable Mouse Keys (Accessibility > Pointer Control > Alternate Control Methods / Mouse Keys).
  2. Post `CGEventCreateKeyboardEvent(nil, 87, true/false)`, i.e. keypad 5, from a process with Accessibility permission.
  3. Check whether the pointer clicks. Also use keypad 0 for "press and hold" and keypad 8/2/4/6 to move.
  4. Repeat with Mission Control open.
- Voice Control test: open Mission Control, say "show grid," then "drag <n> to <m>." If it reorders a Space, Voice Control's injection path is accepted, but driving it from our app would need audio input. That is impractical; it is only useful as a diagnostic.
- Switch Control can use a keyboard key as a switch and has point scanning and drag. Synthetic CGEvent keys probably don't reach it for the same reason as Mouse Keys. Untested.

### Gaps
- I found no source on whether Mission Control's Spaces bar exposes AX actions beyond AXPress/AXRemoveDesktop, or keyboard shortcuts to reorder Spaces.
- I found no source on Switch Control or Head Pointer injection internals, or whether they can be driven by an app (custom switch via AppleScript).
- I found no source on whether Mouse Keys reacts to synthetic key events on macOS 14–27.
- I found no current documentation for `hidutil` creating virtual devices. Per thread 845787, `hidutil monitor` is gone on macOS 26.
