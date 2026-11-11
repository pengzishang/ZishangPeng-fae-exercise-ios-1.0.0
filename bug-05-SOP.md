# Bug 5：smartcase 长按按钮在 app 无反馈 排查记录

> 5. Clicking on a `smartcase` button is visible in the `app`, but holding down the button and releasing later is not visible. Feels like a bug, but maybe this is by design?

*本文件为中文版；English version: [bug-05-SOP.md.en.md](bug-05-SOP.md.en.md)*

## 1. 固定版本与现场

- 基线分支 / 提交号：`fix/05-long-press-button-events`；基线提交 `ad26697`（Initial commit: fae-exercise-ios assignment）
- 未提交改动及保存方式：仅本文件 `bug-05-SOP.md`（未跟踪、未提交）；产品代码零改动
- 修复分支：不适用（判定为非缺陷，不修）
- 环境：Mac（MacBookAir10,1 / macOS 27.0.1，Build 26A434）；iPhone（iPhone 14 / iOS 27.0.1）；Xcode 27.1（Build 27A9275）
- 蓝牙权限 / 初始按钮数据：不适用（本现象与蓝牙权限状态及初始按钮数据无关）

> 不用 reset/clean 固定版本；排查期间不升级依赖和系统。

## 2. 现象与复现

- 预期 / 依据：依据 `sbsc-protocol.md` v0.1（Button Event 只定义 `ButtonTap = 0x00`）和 `README.md` L48（只描述 tap 显示橙框半秒），预期为无反馈；实际长按后松开，Mac 端没有任何反应，与预期一致。
- 最近一次正常的时间 / 版本 / 配置（缩小回归范围）：不适用（基线版本即如此，非回归引入）
- 初步分类：可能设计如此（结论：设计如此，非缺陷，见第 4 节）

| 步骤 | 操作 | 预期 | 实际 |
| --- | --- | --- | --- |
| 1 | 单击 iPhone 端（右）第一个按钮 | Mac 端（左）对应按钮出现橙色边框 | 有非常清晰的边框显示（与 README 描述一致） |
| 2 | 长按 iPhone 端同一按钮约 2 秒、手指不动、慢慢松开 | 无反馈（协议未定义长按事件） | Mac 端没有任何反应 |
| 3 | 长按结束后不重连，立刻正常单击同一按钮 | Mac 端恢复橙色边框 | 正常出现橙色边框 |

- 复现次数 / 最小复现：容易复现；最小复现即同一按钮「单击 vs 长按松开」对比。第 2 步确认零反应成立，第 3 步排除了手势卡死或链路故障。
- 如需日志：复现前开始、复现后停止，只留相关时段；共享前脱敏。

## 3. 分层排查（从易到难，做到定位即止）

每层填四格；结论选：发现异常 / 未见异常 / 证据不足 / 不适用。
思路：沿“上层送出的值 → 下层收到的值”找最早出差异的边界。

### 3.1 App 代码层（Mac `app` 与 iPhone `smartcase` 都看）

| 查什么 / 在哪查 | 预期 | 实际 | 结论 |
| --- | --- | --- | --- |
| iPhone 端按钮手势（`smartcase/SmartCase/Views/SmartCaseView.swift` L55） | 若支持长按，应有 `onLongPressGesture` | 只有 `onTapGesture`，无长按手势 | 未见异常（与协议只定义 tap 一致） |
| 全仓关键词检索（排除 `.git`、`.build`） | 若实现或预留过长按，应能搜到相关标识 | `longPress`/`long_press` 源码零命中；`hold` 在 `*.swift` 零命中；`press` 仅 2 条且均为 `ExpressibleByIntegerLiteral` 子串（假阳性） | 未见异常（无长按相关代码） |
| 全仓手势修饰符清点（`*.swift`） | 若存在手势竞争，应出现 longPress/drag/simultaneous 等 | 仅 2 处 `onTapGesture`：`DeviceDetailView` L84（Mac 端改图标）、`SmartCaseView` L55（iOS 端）；其余手势修饰符均无 | 未见异常（无手势竞争、无长按入口） |
| iOS 端按住时的视觉反馈 | 若 UI 暗示可长按，按住应有变暗/缩小/高亮 | 按钮本身无任何视觉变化，与未按一致 | 未见异常（UI 未暗示长按） |

### 3.2 SDK 层（SmartCaseKit：编码、解码、状态）

| 查什么 / 在哪查 | 预期 | 实际 | 结论 |
| --- | --- | --- | --- |
| 协议定义（`sbsc-protocol.md` L110-120「Button Event」） | 若支持长按，事件枚举应有长按值 | 仅 `ButtonTap = 0x00`，无长按/按下/松开事件；字段为 1 字节枚举，v0.1 只定义了这一个值 | 未见异常（协议本身不定义长按） |
| Mac 端接收→渲染链路：`peripheralManager.updateValue` → `SmartCaseDevice` L178 → `lastNotification` → `DeviceDetailView` L115 | 若支持长按，链路应有独立分支或预留位 | 未见任何针对长按的独特代码或预留代码，链路只处理点击事件 | 未见异常（整条链路无长按语义） |

（需要时补 BLE 数据：消息 ID / Action / 原始字节十六进制。）

### 3.3 iOS / macOS 系统层（权限、蓝牙开关、前后台、回调）

| 改变的条件（一次一个） | 操作前 | 操作后 | 结论 |
| --- | --- | --- | --- |
| 是否需要下探系统层 | — | 不需要：长按无反馈已由「协议未定义长按事件、iOS 端无长按手势」完整解释，与权限、蓝牙开关、前后台回调无关 | 不适用 |

### 3.4 硬件层（距离 / 干扰 / 换设备对照）

| 对照实验 | 保持不变的条件 | 实际结果 | 结论 |
| --- | --- | --- | --- |
| 换设备 / 换距离对照 | — | 未做：现象已由协议与代码完整解释，与射频、距离、干扰无关 | 未验证（不适用） |

> 没有对照设备就写“未验证”；不凭排除法判硬件故障。

## 4. 根因与修复

- 触发条件 / 首次出错位置（端、文件、函数）：不适用。结论是非缺陷，设计本来如此，无出错位置。现象起点是 iOS 端 `SmartCaseView` L55 只注册 `onTapGesture`，该实现与协议一致。
- 出错机制 → 如何导致现象：长按时 iOS 端无对应手势识别器，不产生 Button Event 通知；Mac 端收不到消息，`lastNotification` 不更新，`DeviceDetailView` L115 边框条件不满足，于是无反馈。整条链路按「协议只定义 ButtonTap」正常运转。
- 证据（截图 / 日志 / 断点值）：① 产品规格 `README.md` L48 只描述 tap 显示橙框半秒，未定义长按；② 协议 `sbsc-protocol.md` v0.1 L110-120 事件枚举仅 `ButtonTap = 0x00`；③ iOS 端 `SmartCaseView` L55 仅 `onTapGesture`，全仓检索 `longPress`/`hold` 零命中；④ Mac 端 `updateValue` → `SmartCaseDevice` L178 → `lastNotification` → `DeviceDetailView` L115 无长按分支；⑤ 实测：长按 2 秒松手无边框，随后单击正常出现边框。复现现场截图为 Mac 端已连接、第 1 个按钮带橙框，iPhone 端 4 个按钮。
- 最小修复 / 为什么改这里而不是另一端：不适用，本题不修。若未来要支持长按，先升协议（「按钮事件」1 字节枚举可扩展，如 `ButtonHold = 0x01`），再由双端各自跟进。
- 如何撤销本次修改：不适用（排查未改动任何产品代码；本文件为新增记录，删除 `bug-05-SOP.md` 即完全撤销）。

## 5. 验证与交付

| 项目 | 通过标准 | 修复后结果 |
| --- | --- | --- |
| 原复现步骤 | 复现结果与判定一致 | 已复测：长按无反应、随后单击正常，与判定一致；本项无需修复 |
| 单测（`smartcasekit` 内 `swift test`，按需） | 未改代码则无需执行 | 未做（不适用：未改动产品代码） |
| 双端真机回归（按需） | 未改代码则无需回归 | 未做（不适用：未改动产品代码） |

- [x] 单测通过 ≠ 双端 BLE 已验证；没做的留“未做”。本次单测、双端回归均未做（不适用）。
- [ ] 已向报告人/QA 同步结论与适用条件；未复测的保持“待确认”并约定跟进。未做，面试条件受限，未同步。
- [x] 独立分支交付（见 [README 交付要求](README.md#how-to-deliver-the-solutions)），不合并进 main；提交说明写清改了什么、为什么。无代码改动，分支 `fix/05-long-press-button-events` 仅承载本记录。
