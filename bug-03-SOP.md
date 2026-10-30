# Bug 3: Icon State Out of Sync After Connecting — Troubleshooting Record

> 3. Start `smartcase` on iPhone, then connect to it from `app` on the Mac. The `app` doesn't show the same icons as `smartcase`. When changing icons from the `app`, everything is looking good, however when restarting the `app`, the icons are wrong again.

## 1. Pinned Version and Context

- Baseline branch / commit: `main` @ `ad26697` (Initial commit: fae-exercise-ios assignment)
- Change and commit status: the fix is committed as `a2be0f9` (line 63, imageIndex offset `+1` → `+0`, that single line only); the troubleshooting instrumentation has been removed; the extract-a-function-for-unit-tests approach was decided against and reverted, and the test file deleted (see section 5); this record plus `bug-03-assets/` were pending a `docs:` commit
- Fix branch: `fix/03-icon-state-sync-on-reconnect` (existing commit: `a2be0f9`)
- Environment: Mac (model / macOS) MacBook Air (MacBookAir10,1, Apple M1) / macOS 27.0.1 (26A434); iPhone (model / iOS) iPhone 14 / iOS 27.0.1 (same setup as Bug 2); Xcode 27.1 (27A9275), Swift 6.4 (measured on this machine)
- Bluetooth permission / initial button data: the permission wording is "…smart watches" (in Bug 4's scope); initial button data was not separately captured — the code defaults all four buttons to img 0 / RGB(32,32,32), and the state observed during the session is in the 3.2 egress payload check

> Do not use reset/clean to pin the version; do not upgrade dependencies or the OS while troubleshooting.

## 2. Symptom and Reproduction

- Expected / basis: README Assignment item 3 — after `app` connects to `smartcase`, it should show icons matching `smartcase`; actual: after connecting, the icons `app` shows do not match `smartcase`
- Last known-good time / version / configuration (to narrow the regression window): N/A (assignment baseline, no previously known-good version)
- Initial classification: suspected defect

| Step | Action | Expected | Actual |
| --- | --- | --- | --- |
| 1 | Start Mac `app` and iOS `smartcase` at the same time | — | — |
| 2 | Connect from the Mac to the iOS side | `app` shows the same button icons as `smartcase` | Icons on the two ends do not match |
| 3 | Tap and change a few buttons at random from the Mac | Both sides change in sync | Everything normal in this phase |
| 4 | Disconnect on the iOS side, then reconnect | Icons stay consistent on both ends | **Icons clearly inconsistent on the two ends** |
| 5 | Kill the `smartcase` process on iOS several times | — | The iOS-side icons stay **stable and unchanged** → suggests permanent storage on the iOS side, state surviving across processes |
| 6 | (Supplementary observation before the fix) while the two ends disagree, tap one of the mismatched buttons on the Mac | — | **The tapped button immediately matches the iOS side, while the untouched buttons stay mismatched**; after disconnecting and reconnecting on the Mac, the UI icons go wrong again |

- Reproduction count / minimal repro: reliably reproducible in practice (steps 1→4); minimal repro = start both ends, connect, make a few changes from the Mac, then disconnect and reconnect on iOS
- The step-6 observation matches the root-cause mechanism: a tap only updates the local state of the tapped button (the `setButtonImage` path does not go through response decoding), so untouched buttons still hold the wrong value from the last decode; after disconnect and reconnect the decode path runs again and the error returns
- Initial inference (recorded alongside the reproduction): the iOS icons do not change across repeated process kills, which suggests the iPhone side very likely persists button state — so the disagreement after reconnect is more likely on the Mac's data-fetch/rendering side
- Logs if needed: start capture before reproducing, stop after, keep only the relevant window, and redact before sharing. Not collected.

## 3. Layered Trace (easy → hard, stop once the fault is located)

**Initial line of thought (verbatim):**

> My gut on question 3 is that it's a sync problem — the first time the Mac connects to the iPhone, it should be pulling the button data from the iPhone side.

### 3.0 Mapping the value chain on both ends (2026-10-30)

**iOS side (where SmartCase state comes from)**:

- Button state is read from `buttons` on line 24 of `SmartCase`;
- the `SmartCase` singleton takes its values at initialization, going through the `loadButtons()` method;
- which in turn points at the `persistentButtons` variable;
- that value is handled by a propertyWrapper called `Persistent`, i.e. it **is persisted** (mutually corroborating the section-2 observation "repeated process kills, icons stay unchanged → suggests permanent storage").

**Mac side (chain for obtaining button state)**:

- once `selectedDevice` changes, the connection is initiated through `SmartCaseDevice`'s `connect()` method;
- inside `public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?)`, `updateButtons()` is called;
- which then does `let response = try await sendRequest(request)`, performing a `writeValue` on the peripheral;
- the iPhone side receives it via `handleRequest` → `handleWriteRequest` inside `func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest])`;
- finally `handleRequest` reads the values of the iOS-side `buttons`.

**Next action**: check this chain for any **value-passing or read error**.

### 3.1 App code layer (both Mac `app` and iPhone `smartcase`)

| What to check / where | Expected | Actual | Conclusion |
| --- | --- | --- | --- |
| `app/App/Views/DeviceDetailView.swift:76-86` | Icons/colors come from `device.buttons` | Confirmed it renders by reading `device.buttons[i]` directly, no separate cache in the UI layer | No anomaly seen (initial read-through) |
| iOS-side state source | Persisted, readable back after restart | `smartcase/SmartCase/Models/SmartCase.swift:44-59` uses `@Persistent(key: "buttons")` to persist and calls `loadButtons()` in init | No anomaly seen (initial read-through) |

### 3.2 SDK layer (SmartCaseKit: encoding, decoding, state)

| What to check / where | Expected | Actual | Conclusion |
| --- | --- | --- | --- |
| Whether button state is pulled after the connection is established (the core of the initial hypothesis) | After connecting, current button data should be fetched from the peripheral | `SmartCaseKit/SmartCaseDevice.swift`: inside `didDiscoverCharacteristicsFor` there is indeed `Task { try? await updateButtons() }`, and `getButtons` is in fact sent after connecting | Nothing missing |
| Encoding side of the `getButtons` response | Per `sbsc-protocol.md`: `[status, count, (img, R, G, B) × n]` | iPhone side `SmartCase.swift:64-70` assembles the packet byte by byte per the protocol | No anomaly seen |
| Decoding side of the `getButtons` response | imageIndex is the first byte of each button (offset +0) | `SmartCaseDevice.swift`: `imageIndex` originally read `payload[2+i*4+1]`, i.e. the **same byte** as `red` (also +1); per the protocol it should be `payload[2+i*4]`. The R/G/B channel offsets are correct | **Anomaly found (confirmed)**: the Mac side receives fine (`response.payload` is byte-for-byte identical to what the iOS side sent), so the divergence is proven to be in the decode offset. After changing the offset from `+1` to `+0` and re-testing, **the problem was resolved** |
| iOS-side egress check (measured, 2026-10-30) | The encoder packs per the protocol, imageIndex consistent with the iOS UI | Added `debugPrint(button.imageIndex)` on line 68 of `handleRequest`; the console printed `0 0 0 0`, matching the four-button state in the iOS UI before sending (screenshot `bug-03-assets/ios-smartcase-ui-icons.webp`: four buttons share one icon, backgrounds differ); the payload actually sent, byte by byte: `0:0, 1:4, 2:0, 3:60, 4:60, 5:20, 6:0, 7:20, 8:20, 9:20, 10:0, 11:60, 12:60` (screenshot `bug-03-assets/ios-getbuttons-payload-log.webp`). Reading: `[0]=status OK`, `[1]=4 buttons`, button 0 = img 0 + RGB(60,60,20), button 1 = img 0 + RGB(20,20,20), button 2 = img 0 + RGB(60,60,…) | **No anomaly seen (encoding side)**: imageIndex is 0 at every egress position and matches the UI, encoding follows the protocol. The byte listing stops at index 12 (the protocol calls for 18 bytes for 4 buttons) — in the post-fix regression screenshot (`after-fix-reconnect-icons-match.webp`) button 3's icon (Spotify) renders correctly, which shows button 3's img byte (payload[14]) arrived intact and decoded correctly, so the listing stopping at 12 is judged to be **log display truncation**, not payload truncation |

(Message ID / Action were not recorded; they do not affect the diagnosis. The Mac receive side was verified: `response.payload` is byte-for-byte identical to what iOS sent.)

### 3.3 iOS / macOS system layer (permissions, Bluetooth toggle, foreground/background, callbacks)

| Condition changed (one at a time) | Before | After | Conclusion |
| --- | --- | --- | --- |
| — | — | — | **N/A**: the iOS egress payload and the Mac received payload are byte-for-byte identical (see 3.2); there is no divergence anywhere along the transport chain, so the system layer is not the source of the discrepancy |

### 3.4 Hardware layer (distance / interference / swapped-device control)

| Control experiment | Conditions held constant | Actual result | Conclusion |
| --- | --- | --- | --- |
| — | — | — | **N/A**: same as 3.3 — the data has been proven intact in transit, and reproduction is 100% tied to the data content (only the imageIndex byte is misaligned); no sign of a hardware fault |

## 4. Root Cause and Fix

- Trigger condition / first point of failure (end, file, function): **Mac side (SmartCaseKit)**, `updateButtons()` in `smartcasekit/Sources/SmartCaseKit/SmartCaseDevice.swift` — triggered on every first button-state pull after a connection is established (both the initial connect and the reconnect after `app` restarts).
- Failure mechanism → how it produces the symptom: the iOS side packs `[status, count, (img, R, G, B) × 4]` per the protocol (proven by the egress check), and the Mac's received `response.payload` is byte-for-byte identical to what was sent (no divergence on the receive side); but at decode time `imageIndex` is read from `payload[2 + buttonIndex * 4 + 1]` — offset `+1` is the **red channel** position, while the real imageIndex sits at `+0`. So each button's "icon index" was read as the value of its background red, while the R/G/B offsets are all correct, which is exactly why **colors render fine and only the icons are wrong**. When changing an icon from `app`, `setButtonImage` updates the local `buttons` state directly and never goes through this decode path, hence "everything is fine while making changes", and only the tapped button snaps back into agreement (the step-6 observation in section 2); after restarting `app` or disconnecting/reconnecting on iOS, `updateButtons()` decodes again and the error returns.
- Evidence (screenshots / logs / breakpoint values): ① iOS egress check: `debugPrint(button.imageIndex)` inside `handleRequest` printed `0 0 0 0`, matching the UI; payload byte by byte `0:0, 1:4, 2:0, 3:60, 4:60, 5:20, 6:0, 7:20, 8:20, 9:20, 10:0, 11:60, 12:60` (screenshots `bug-03-assets/ios-smartcase-ui-icons.webp`, `bug-03-assets/ios-getbuttons-payload-log.webp`) — for button 0 the `+0` byte is 0 (the icon) and the `+1` byte is 60 (the red channel), so the old code would read the icon as 60; ② Mac receive side: printing `response.payload` gives the same bytes iOS sent; ③ post-fix re-test passed (see section 5).
- Minimal fix / why this side and not the other: change the decode offset from `+1` to `+0` (`payload[2 + buttonIndex * 4]`). The fix goes on the Mac decode side rather than the iOS encode side because the iOS encoding and persistence were both verified protocol-conformant, and this single decode offset is the only deviation from the protocol.
- How to revert this change: `git revert a2be0f9` (or set the offset on line 63 back to `+1`) restores the original defect; the instrumentation has already been removed, so nothing else to clean up.

## 5. Verification and Delivery

| Item | Pass criteria | Result after fix |
| --- | --- | --- |
| Original reproduction steps (start both ends → connect → several Mac-side changes → iOS disconnect/reconnect) | Icons match on both ends | **Passed (measured)**: after changing the offset to `+0` and re-testing, icons match on both ends; problem resolved |
| Unit tests (`swift test` in `smartcasekit`) | The decode function asserts byte by byte against a protocol payload and passes | **Not included in the delivery (decided)**: an "extract decode into a static function + 4 decode cases" approach was implemented and ran 6/6 green (including the 2 existing message cases; requires `swift test --disable-sandbox`), but it needed restructuring the source layout, so it was decided against and reverted — the source keeps only the one-line fix and the test file was deleted. Acceptance rests on the dual-device regression |
| Dual-device regression (as needed) | Icons match on both ends after initial connect, after changes, and after reconnect | **Passed (measured, 2026-10-30)**: several rounds of Mac-side taps and changes, then iOS disconnect/reconnect — icons and background colors match button by button (screenshot `bug-03-assets/after-fix-reconnect-icons-match.webp`: Mac `app` and iPhone side by side, all four buttons' icon/background pair up exactly) |
| Restart / reinstall `app` scenario (the original README symptom) | Icons still match on both ends after restarting `app` | **Passed (confirmed in practice)**: restarting `app`, and deleting `app` then reconnecting, both keep the icons correctly in sync. All scenarios in the original README symptom are covered |

- [x] The device regression covers real dual-end BLE behavior; anything not done is labeled as such (unit tests not included in the delivery).
- [x] Conclusions and applicability conditions shared (I am the person who made the fix); applicability: covers only the `getButtons` decode path — the `setButtonBackground` / `setButtonImage` paths are not affected by this fix.
- [x] Delivered on an independent branch (see [README delivery requirements](README.md#how-to-deliver-the-solutions)), not merged into main: the fix was committed as `fix(kit):` (`a2be0f9`, 1 file / 1 insertion / 1 deletion); this record and the evidence folder follow as a `docs:` commit. The branch has **not been pushed to origin**; push timing and delivery form (public repo / zip) still to be decided.
