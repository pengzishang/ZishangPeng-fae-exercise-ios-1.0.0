# Bug 5: Long-Pressing a smartcase Button Gives No Feedback in the app — Troubleshooting Record

> 5. Clicking on a `smartcase` button is visible in the `app`, but holding down the button and releasing later is not visible. Feels like a bug, but maybe this is by design?

## 1. Pinned Version and Context

- Baseline branch / commit: `fix/05-long-press-button-events`; baseline commit `ad26697` (Initial commit: fae-exercise-ios assignment)
- Uncommitted changes and how they were saved: only this file `bug-05-SOP.md` (untracked, uncommitted); zero changes to product code
- Fix branch: N/A (judged not a defect, so not fixed)
- Environment: Mac (MacBookAir10,1 / macOS 27.0.1, Build 26A434); iPhone (iPhone 14 / iOS 27.0.1); Xcode 27.1 (Build 27A9275)
- Bluetooth permission / initial button data: N/A (this symptom is unrelated to Bluetooth authorization state or initial button data)

> Do not use reset/clean to pin the version; do not upgrade dependencies or the OS while troubleshooting.

## 2. Symptom and Reproduction

- Expected / basis: per `sbsc-protocol.md` v0.1 (Button Event defines only `ButtonTap = 0x00`) and `README.md` L48 (which describes only a tap showing an orange border for half a second), the expectation is no feedback; actual: after long-pressing and releasing, the Mac side does nothing at all — consistent with the expectation.
- Last known-good time / version / configuration (to narrow the regression window): N/A (the baseline behaves this way, not introduced by a regression)
- Initial classification: possibly by design (conclusion: by design, not a defect — see section 4)

| Step | Action | Expected | Actual |
| --- | --- | --- | --- |
| 1 | Single-tap the first button on the iPhone (right) | The corresponding button on the Mac (left) shows an orange border | A clearly visible border appears (consistent with the README description) |
| 2 | Long-press the same button on the iPhone for about 2 seconds, keep the finger still, release slowly | No feedback (the protocol defines no long-press event) | Nothing happens on the Mac side |
| 3 | Without reconnecting after the long press ends, immediately single-tap the same button normally | The Mac side shows the orange border again | The orange border appears normally |

- Reproduction count / minimal repro: easy to reproduce; the minimal repro is the "single tap vs. long-press-and-release" comparison on the same button. Step 2 confirms that zero response holds, and step 3 rules out a stuck gesture or a broken link.
- Logs if needed: start capture before reproducing, stop after, keep only the relevant window, and redact before sharing.

## 3. Layered Trace (easy → hard, stop once the fault is located)

Fill four columns per layer; conclusions are: anomaly found / no anomaly seen / insufficient evidence / N/A.
Approach: follow "the value the upper layer sent → the value the lower layer received" and find the earliest boundary where they diverge.

### 3.1 App code layer (both Mac `app` and iPhone `smartcase`)

| What to check / where | Expected | Actual | Conclusion |
| --- | --- | --- | --- |
| iPhone-side button gesture (`smartcase/SmartCase/Views/SmartCaseView.swift` L55) | If long press were supported, there should be an `onLongPressGesture` | Only `onTapGesture`, no long-press gesture | No anomaly seen (consistent with the protocol defining tap only) |
| Repo-wide keyword search (excluding `.git`, `.build`) | If long press had been implemented or reserved, related identifiers should be findable | Zero source hits for `longPress`/`long_press`; zero hits for `hold` in `*.swift`; `press` has only 2 hits and both are substrings of `ExpressibleByIntegerLiteral` (false positives) | No anomaly seen (no long-press-related code anywhere) |
| Repo-wide inventory of gesture modifiers (`*.swift`) | If a gesture conflict existed, longPress/drag/simultaneous etc. would appear | Only 2 `onTapGesture` sites: `DeviceDetailView` L84 (Mac side, changes the icon) and `SmartCaseView` L55 (iOS side); no other gesture modifiers at all | No anomaly seen (no gesture conflict, no long-press entry point) |
| Visual feedback while holding on iOS | If the UI hinted at long press, holding should dim/shrink/highlight | The button itself shows no visual change whatsoever, identical to not pressing | No anomaly seen (the UI does not hint at long press) |

### 3.2 SDK layer (SmartCaseKit: encoding, decoding, state)

| What to check / where | Expected | Actual | Conclusion |
| --- | --- | --- | --- |
| Protocol definition (`sbsc-protocol.md` L110-120, "Button Event") | If long press were supported, the event enum should have a long-press value | Only `ButtonTap = 0x00`, with no long-press/press-down/release event; the field is a 1-byte enum and v0.1 defines only this one value | No anomaly seen (the protocol itself does not define long press) |
| Mac-side receive→render chain: `peripheralManager.updateValue` → `SmartCaseDevice` L178 → `lastNotification` → `DeviceDetailView` L115 | If long press were supported, the chain should have its own branch or a reserved slot | No code specific to long press, and no reserved code, anywhere in the chain; the chain handles tap events only | No anomaly seen (the whole chain has no long-press semantics) |

(Add BLE data if needed: message ID / Action / raw byte hex.)

### 3.3 iOS / macOS system layer (permissions, Bluetooth toggle, foreground/background, callbacks)

| Condition changed (one at a time) | Before | After | Conclusion |
| --- | --- | --- | --- |
| Whether digging into the system layer is needed | — | Not needed: the absence of long-press feedback is fully explained by "the protocol defines no long-press event, and the iOS side has no long-press gesture"; it has nothing to do with permissions, the Bluetooth toggle, or foreground/background callbacks | N/A |

### 3.4 Hardware layer (distance / interference / swapped-device control)

| Control experiment | Conditions held constant | Actual result | Conclusion |
| --- | --- | --- | --- |
| Swapped device / changed distance control | — | Not done: the symptom is already fully explained by the protocol and the code, and has nothing to do with RF, distance, or interference | Not verified (N/A) |

> With no second device available, write "not verified"; never conclude a hardware fault purely by elimination.

## 4. Root Cause and Fix

- Trigger condition / first point of failure (end, file, function): N/A. The conclusion is that this is not a defect — the design is exactly as intended, so there is no point of failure. The symptom starts from the iOS side `SmartCaseView` L55 registering only `onTapGesture`, and that implementation is consistent with the protocol.
- Failure mechanism → how it produces the symptom: on a long press the iOS side has no matching gesture recognizer, so no Button Event notification is produced; the Mac side receives no message, `lastNotification` is not updated, and the border condition at `DeviceDetailView` L115 is not satisfied — hence no feedback. The entire chain is operating normally according to "the protocol defines only ButtonTap".
- Evidence (screenshots / logs / breakpoint values): ① the product spec `README.md` L48 describes only a tap showing an orange border for half a second and defines no long press; ② the protocol `sbsc-protocol.md` v0.1 L110-120 defines the event enum as `ButtonTap = 0x00` only; ③ the iOS side `SmartCaseView` L55 has only `onTapGesture`, and a repo-wide search for `longPress`/`hold` returns zero hits; ④ the Mac-side chain `updateValue` → `SmartCaseDevice` L178 → `lastNotification` → `DeviceDetailView` L115 has no long-press branch; ⑤ measured: long-pressing for 2 seconds and releasing gives no border, and a single tap immediately afterwards shows the border normally. The reproduction screenshot shows the Mac side connected with the first button bordered in orange, and the iPhone showing its 4 buttons.
- Minimal fix / why this side and not the other: N/A, this item is not fixed. If long press is to be supported later, raise the protocol version first (the "Button Event" 1-byte enum is extensible, e.g. `ButtonHold = 0x01`), then have both ends follow up accordingly.
- How to revert this change: N/A (troubleshooting changed no product code; this file is a newly added record, so deleting `bug-05-SOP.md` reverts everything).

## 5. Verification and Delivery

| Item | Pass criteria | Result after fix |
| --- | --- | --- |
| Original reproduction steps | The reproduction result matches the judgement | Re-tested: long press gives no response, a subsequent single tap works normally — consistent with the judgement; nothing to fix for this item |
| Unit tests (`swift test` in `smartcasekit`, as needed) | Not required if no code was changed | Not done (N/A: no product code changed) |
| Dual-device regression (as needed) | Not required if no code was changed | Not done (N/A: no product code changed) |

- [x] Passing unit tests ≠ dual-device BLE verified; leave "not done" for anything not attempted. Both unit tests and dual-device regression were not done here (N/A).
- [ ] Conclusions and applicability conditions shared with the reporter/QA; anything not re-tested stays "to be confirmed" with a follow-up agreed. Not done — constraints of the interview setting prevented sharing.
- [x] Delivered on an independent branch (see [README delivery requirements](README.md#how-to-deliver-the-solutions)), not merged into main; the commit message states what changed and why. No code change; branch `fix/05-long-press-button-events` carries this record only.
