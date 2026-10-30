# Bug 2: Disconnection Not Detected — Troubleshooting Record

> 2. `App` is connected to a `smartcase`. When terminating `smartcase` on the iPhone, `app` doesn't seem to notice it. `App` never reverts to disconnected state. Some delay noticing it would be acceptable, but nothing happened in the app, even after 30 seconds.

## 1. Pinned Version and Context

- Baseline branch / commit: main / `ad26697` (Initial commit: fae-exercise-ios assignment)
- Working-tree status: during troubleshooting there were uncommitted changes (`DeviceDetailView.swift`, +5 lines); they are now committed on `fix/02-connection-lost-detection` (`809fc18`), and the working tree is currently clean
- Fix branch: `fix/02-connection-lost-detection`
- Environment: Mac (MacBook Air M1 / MacBookAir10,1 / macOS 27.0.1); iPhone (iPhone 14 / iOS 27.0.1); Xcode 27.1 (27A9275)
- Bluetooth permission / initial button data: `INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription` = "Allow Bluetooth access to find and control nearby smart watches" (i.e. the wording Bug 4 is about, see `app/App.xcodeproj/project.pbxproj:399,429`); initial button data was not separately captured — to be added

> Do not use reset/clean to pin the version; do not upgrade dependencies or the OS while troubleshooting.

## 2. Symptom and Reproduction

- Expected / basis: after terminating `smartcase` on the iPhone, the Mac `App` should return to the disconnected state within an acceptable delay (basis: README bug report 2); actual: nothing changes in the App — still showing connected after 30 seconds.
- Last known-good time / version / configuration (to narrow the regression window): not done (first time picking this up, no historical known-good baseline)
- Initial classification: suspected defect

| Step | Action | Expected | Actual |
| --- | --- | --- | --- |
| 1 | Mac `App` scans and connects to `smartcase` on the iPhone | Connection succeeds, 4 buttons shown | Connection succeeds (reproduced 2026-10-30) |
| 2 | Terminate `smartcase` directly on the iPhone (kill the App) | App returns to the device list / disconnected state after a delay | App stays on the Smart Case Control detail page, the 4 buttons still render normally, no return to the device list (see screenshot below) |
| 3 | Keep waiting ≥30 seconds and observe | Should have reached the disconnected state (a delay is acceptable) | The UI stays on the detail page and does not return to the list; a follow-up observation confirmed the Connected label does flip to `No` on its own (the delay is a link-layer timeout), while the Disconnect button stays greyed out (reporter judged the reproduction successful) |

![Reproduction: after killing smartcase on the iPhone, the Mac App still sits on the button detail page](<bug-02-assets/repro-01-after-kill.webp>)

- Reproduction count / minimal repro: 1 time; minimal repro = after a successful connection, kill `smartcase` on the iPhone and watch the Mac App UI.
- Logs if needed: start capture before reproducing, stop after, keep only the relevant window, and redact before sharing.

Additional observations from the reporter (2026-10-30):

- The Connected field on the detail page flips from `Yes` to `No` automatically — which implies some internal timing mechanism exists (it waits a while before declaring a disconnect).
- Next direction: find that timing mechanism.
- ~~Timer-mechanism hypothesis~~ (refuted): tracing `SmartCaseDevice.isConnected` with the Xcode Call Hierarchy — `peripheralDidDisconnect()` assigns `false` to it directly, and its caller is `SmartCaseDeviceManager.centralManager(_:didDisconnectPeripheral:error:)`. Conclusion: the delay is not a timer inside the App, it is the **BLE link-layer supervision timeout (OS behavior)**.
- Supporting evidence: an explicit Disconnect click (which goes through `cancelPeripheralConnection` to tear the link down actively) causes `centralManager(_:didDisconnectPeripheral:error:)` to be called almost immediately; by contrast, the callback after killing the peer App is clearly delayed, which further confirms the delay comes from the link-layer supervision timeout.
- **PacketLogger HCI capture, hard evidence (2026-10-30)**: two Disconnection Complete events compared —
  - `12:03:55.589`, Connection Handle `0x0058`, Reason `0x16` (Connection Terminated By Local Host) = the Mac side initiated the disconnect **actively** (clicking Disconnect);
  - `12:08:58.078`, Connection Handle `0x004C`, Reason `0x13` (Remote User Terminated Connection) = the Mac **passively** received the teardown (peer killed, reported after a timeout).

  ![HCI capture: the two Disconnection Complete events compared — active disconnect 0x16 vs. passive teardown 0x13](<bug-02-assets/hci-disconnection-complete.webp>)

  Conclusion confirmed: one callback, two trigger paths — the difference in delay comes from link-layer behavior, not from an App timer.

## 3. Layered Trace (easy → hard, stop once the fault is located)

Fill four columns per layer; conclusions are: anomaly found / no anomaly seen / insufficient evidence / N/A.
Approach: follow "the value the upper layer sent → the value the lower layer received" and find the earliest boundary where they diverge.

### 3.1 App code layer (both Mac `app` and iPhone `smartcase`)

| What to check / where | Expected | Actual | Conclusion |
| --- | --- | --- | --- |
| UI-layer response to disconnection (`DeviceDetailView.swift`) | The UI should refresh after a disconnect (return to the device list) | The SDK-layer delegate and `isConnected` are both triggered correctly, but the UI layer neither observes it nor refreshes | Anomaly found (root cause lives here) |

### 3.2 SDK layer (SmartCaseKit: encoding, decoding, state)

| What to check / where | Expected | Actual | Conclusion |
| --- | --- | --- | --- |
| To be checked | | | Not done |

(Add BLE data if needed: message ID / Action / raw byte hex.)

### 3.3 iOS / macOS system layer (permissions, Bluetooth toggle, foreground/background, callbacks)

| Condition changed (one at a time) | Before | After | Conclusion |
| --- | --- | --- | --- |
| To be checked | | | Not done |

### 3.4 Hardware layer (distance / interference / swapped-device control)

| Control experiment | Conditions held constant | Actual result | Conclusion |
| --- | --- | --- | --- |
| N/A (pure software simulation, no hardware variable) | | | N/A |

> With no second device available, write "not verified"; never conclude a hardware fault purely by elimination.

## 4. Root Cause and Fix

- Trigger condition / first point of failure (end, file, function): Mac side `app` / `DeviceDetailView.swift` — the UI layer never hooks changes to `device.isConnected`.
- Failure mechanism → how it produces the symptom: in the SDK layer (SmartCaseKit) both the delegate and `isConnected` are triggered correctly (see the call chain and the HCI evidence in section 2), but the UI layer does not observe that state and does not refresh, so after the peer App is killed the detail page stays as it was — which looks like "disconnection not detected".
- Evidence (screenshots / logs / breakpoint values): Xcode Call Hierarchy trace (section 2), PacketLogger HCI capture (section 2), and before/after-fix screenshots.
- Minimal fix / why this side and not the other: after the `.padding()` on line 112 of `DeviceDetailView.swift`, add an `onChange` observer that clears the selected device (returning to the device list) when `isConnected` becomes `false`. Only the UI layer was touched because the SDK-layer delegate and state triggering are both already correct, so the SDK needs no change:

```swift
.onChange(of: device.isConnected) { _, newValue in
    if !newValue {
        selectedDevice = nil
    }
}
```

- Known side effect (introduced with the fix, arising from existing `ContentView` logic being activated by the new trigger chain): clearing `selectedDevice` on disconnect triggers `enableDiscovery(true)`, which rescans and empties the `devices` list — so after the peer is killed the user lands on an **empty list**, and the device only reappears once the peer advertises again. The behavior is acceptable and was written into the commit message.
- How to revert this change: revert the commit within the branch.

## 5. Verification and Delivery

| Item | Pass criteria | Result after fix |
| --- | --- | --- |
| Original reproduction steps | After killing smartcase, the App returns to the disconnected state within an acceptable delay | Passed: after rebuilding, the reproduction steps were repeated — killing `smartcase` on the iPhone, the App returned to the "Select a Smart Case" device list (see screenshot below, 2026-10-30) |
| Unit tests (`swift test` in `smartcasekit`, as needed) | All pass | Passed (2026-10-30): both cases `messageRoundTrip` and `messageTooShortIsRejected` green, 0 failures |
| Dual-device regression (as needed) | Full flow per README run steps 1-6 behaves normally | Passed (2026-10-30, confirmed by the reporter: after rebuilding, clicking Disconnect explicitly returns to the list normally; killing the peer twice more also returned to the list normally both times) |

![After the fix: killing smartcase on the iPhone brings the App back to the device list](<bug-02-assets/fix-01-after-fix.webp>)

- [ ] Passing unit tests ≠ dual-device BLE verified; leave "not done" for anything not attempted.
- [ ] Conclusions and applicability conditions shared with the reporter/QA; anything not re-tested stays "to be confirmed" with a follow-up agreed.
- [x] Delivered on an independent branch (see [README delivery requirements](README.md#how-to-deliver-the-solutions)), not merged into main; the commit message states what changed and why. (`809fc18`, not merged into main)
