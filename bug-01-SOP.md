# Bug 01: Button Background Color Drift (app dark red → device dark olive) — Troubleshooting Record

> 1. When changing button icon and background from `app`, the background color on `smartcase` seems to be slightly wrong. For example when `app` shows a dark red background, device shows dark olive.

## 1. Pinned Version and Context

- Baseline branch / commit: `main` @ `ad26697` (Initial commit). Fix commit `8291c95` touches only line 104 of `SmartCase.swift`, changing how `green` is read from `payload[1]` to `payload[2]`.
- Uncommitted changes and how they were saved: clean. The fix lives in `8291c95`, this record goes in a separate `docs:` commit, and the breakpoints used during troubleshooting were never meant to be committed anyway.
- Fix branch: `fix/01-button-color-encoding`. Per the README requirement to deliver each bug independently, this one is not merged back into `main`.
- Environment: Mac is a MacBook Air (MacBookAir10,1, Apple M1) / macOS 27.0.1 (26A434); iPhone is a physical iPhone 14 (iPhone14,7) / iOS 27.0.1 (Build 24A446), Developer Mode enabled (checked with `devicectl`), Bluetooth paired; Xcode 27.1 (27A9275).
- Bluetooth permission / initial button data: I did not verify the permission separately, because this bug is only visible once connected — if the permission had failed, the scan step would have broken, which does not match the observed symptom, so it presumably passed. Icons and the color table are hard-coded in `app/App/Views/DeviceDetailView.swift:24-42`: icons use `iconIndices = 0..<16`, the `backgroundColors` table has 16 colors, and the first one, (60,20,20), is the dark red QA reported. I kept no record of the initial state of the four buttons on the smartcase side.
- Supporting tools: Xcode Debug View Hierarchy to locate the color-read point on both ends, and breakpoint Log Message / Debugger Command to capture values (configuration in 3.1).

> Do not use reset/clean to pin the version; do not upgrade dependencies or the OS while troubleshooting.

## 2. Symptom and Reproduction

- Expected / basis: the button background color chosen in `app` should appear verbatim on `smartcase`. Basis: README run step 4, "The change appears on the simulated case", plus QA report item 1 (README line 59). It actually drifts: `app` shows dark red, the device shows dark olive. This is the "slightly wrong" kind of drift, not total garbage.
- Last known-good time / version / configuration (to narrow the regression window): unknown. Repository history contains only `ad26697` and my own fix commit, so there is no earlier version I can point at as still-working. I treated it as present since the initial commit.
- Initial classification: defect. However, before confirming the wrong channel index, I did not rule out color-space conversion either — that belongs to layer 3 of the trace.

| Step | Action | Expected | Actual |
| --- | --- | --- | --- |
| 1 | Run `SmartCase` on iPhone, `App` on Mac, select the device in the sidebar and connect | Connection succeeds, four buttons listed | Normal (this step has not been re-verified on device by me) |
| 2 | Tap a button in `App`, switch it to dark red | iPhone shows the same dark red within ~1 second | iPhone shows dark olive |
| 3 | Send two known colors once each (pure red #FF0000 / pure green #00FF00) | Each renders as its own pure color | Not done. This step would directly confirm whether R and G are swapped |

- Reproduction count / minimal repro: I did not systematically count attempts; the symptom QA reported is stable, not intermittent. The minimal repro is step 2 of the table above: one click, one dark red.
- Logs if needed: start capture before reproducing, stop after, keep only the relevant window, and redact before sharing. Not collected.

## 3. Layered Trace (easy → hard, stop once the fault is located)

Fill four columns per layer; conclusions are: anomaly found / no anomaly seen / insufficient evidence / N/A.
Approach: follow "the value the upper layer sent → the value the lower layer received" and find the earliest boundary where they diverge.

### 3.1 App code layer (both Mac `app` and iPhone `smartcase`)

| What to check / where | Expected | Actual | Conclusion |
| --- | --- | --- | --- |
| Locate the color-read point on both ends with Debug View Hierarchy: on iOS `SmartCaseView.swift:49`, `.background(Color(red:...))` (the breakpoint actually landed on `let svg` at :47, same scope, so `button` is still reachable); on macOS `DeviceDetailView.swift:94`, `nextColor`, with the color table hard-coded at :25 | Read points findable on both ends | Both found | No anomaly seen |
| Capture values at breakpoints: print `nextColor` on the Mac side, print the button background RGB on the iOS side | (60,20,20) on both ends | Mac (60,20,20); iOS (60,60,20) — the green channel is wrong | Anomaly found |

The iOS breakpoint was configured like this (`SmartCaseView.swift:47`, named Color): Action = Log Message with the text `----------`, plus three Debugger Commands, `po button.backgroundRed` / `po button.backgroundGreen` / `po button.backgroundBlue`, with "Automatically continue after evaluating actions" checked, so it prints on hit without pausing. On the Mac side, `nextColor` was printed around `DeviceDetailView.swift:94`.

### 3.2 SDK layer (SmartCaseKit: encoding, decoding, state)

| What to check / where | Expected | Actual | Conclusion |
| --- | --- | --- | --- |
| Check the sender's encoding against the protocol: [SBSC protocol](sbsc-protocol.md) "Set Button Background Color" specifies payload = [button, red, green, blue], one byte each. Working backwards from the iOS breakpoint values, red=60 is correct and blue=20 is correct — only green is wrong | Bytes arrive in full and in protocol order | red/blue are both correct, which means encoding and BLE transport are fine | No anomaly seen |

(BLE data: Action = SetButtonBackground = 0x03, payload 4 bytes.)

### 3.3 iOS / macOS system layer (permissions, Bluetooth toggle, foreground/background, callbacks)

| Condition changed (one at a time) | Before | After | Conclusion |
| --- | --- | --- | --- |
| N/A. The data provably arrived at the receiver intact and was parsed (red/blue are both correct), so this has nothing to do with permissions or system state — the fault point was already pinned to the parsing code | | | N/A |

### 3.4 Hardware layer (distance / interference / swapped-device control)

| Control experiment | Conditions held constant | Actual result | Conclusion |
| --- | --- | --- | --- |
| N/A. The breakpoint values already proved a purely software defect; no hardware control was needed | | | N/A |

> With no second device available, write "not verified"; never conclude a hardware fault purely by elimination.

## 4. Root Cause and Fix

- Trigger condition / first point of failure (end, file, function): a button tap in `app` sends SetButtonBackground (Action 0x03). On the iPhone side: `smartcase/SmartCase/Models/SmartCase.swift` → `SmartCase.handleRequest(_:)` (L61) → `case .setButtonBackground` (L93); the error is at L104.
- Failure mechanism → how it produces the symptom: the protocol specifies payload = [button, red, green, blue] ([SBSC protocol](sbsc-protocol.md), "Set Button Background Color"). Before the fix, L104 read `let green = request.payload[1]` — that is the red byte — so green always equalled red. The dark red (60,20,20) was parsed as (60,60,20), which is exactly the "dark red shown as dark olive" QA reported.
- Evidence (screenshots / logs / breakpoint values): Mac breakpoint `nextColor` = (60,20,20); iOS breakpoint = red 60 / green 60 / blue 20; the fix diff is one line (`payload[1]` → `payload[2]`); after the fix iOS = (60,20,20), matching Mac.
- Minimal fix / why this side and not the other: change the index on L104 from 1 to 2. The sending side (Mac app + kit) encodes per the protocol, and the byte order is backed up by breakpoint values; the mistake is the receiver's parsing index, so one line in `smartcase` is enough.
- How to revert this change: `git revert` the fix commit, or `git checkout ad26697 -- smartcase/SmartCase/Models/SmartCase.swift` to restore the original version and commit that. One caveat: since the fix is already committed, a plain `git checkout -- <file>` only restores the fixed HEAD, which amounts to not reverting at all.
- Correction to my initial hypothesis: I first assumed the "R/G channels were swapped". That is not it — green and red read the same index. The channel count is right, the subscript is wrong.
- Sibling index audit: `case .setButtonImage` (L72-78) reads `payload[0]` = button and `payload[1]` = imageIndex, which matches the protocol's payload = [button, image index]. No similar typo there.

## 5. Verification and Delivery

| Item | Pass criteria | Result after fix |
| --- | --- | --- |
| Original reproduction steps (table in section 2) | Colors identical on both ends | Passed, but only the first palette entry was verified: Mac (60,20,20) = iOS (60,20,20), re-tested by me on 2026-10-29 |
| Full palette regression (`backgroundColors` in `DeviceDetailView.swift:25`) | Every color in the palette identical on both ends | Static reasoning only (see note below); per-color device verification not done |
| Unit tests (`swift test` in `smartcasekit`, as needed) | Tests pass | Passed: on 2026-10-29 `swift test`, both cases green (messageRoundTrip / messageTooShortIsRejected, exit 0). But the kit tests cannot reach the parsing in the `smartcase` app layer where the bug lives |
| Dual-device regression (as needed) | The reliable reproduction no longer reproduces | Only the single color 60,20,20 was verified |

> Full-palette reasoning (before the fix green≡red, so it displayed as (red, red, blue)): of the 16 colors, 14 have R≠G and render wrong immediately, e.g. (60,20,20)→(60,60,20), (60,20,60)→(60,60,60), (20,60,20)→(20,20,20). Only (20,20,60) and (60,60,20) are naturally immune because R=G. So a regression that happens to pick only colors with R=G could never catch this class of bug.
