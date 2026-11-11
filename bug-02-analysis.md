# Bug 2：断连无感知 排查记录

> 2. `App` is connected to a `smartcase`. When terminating `smartcase` on the iPhone, `app` doesn't seem to notice it. `App` never reverts to disconnected state. Some delay noticing it would be acceptable, but nothing happened in the app, even after 30 seconds.

*本文件为中文版；English version: [bug-02-analysis.md.en.md](bug-02-analysis.md.en.md)*

## 1. 固定版本与现场

- 基线分支 / 提交号：main / `ad26697`（Initial commit: fae-exercise-ios assignment）
- 工作区状态：排查期间曾有未提交改动（`DeviceDetailView.swift` +5 行），已提交至 `fix/02-connection-lost-detection`（`809fc18`），当前工作区干净
- 修复分支：`fix/02-connection-lost-detection`
- 环境：Mac（MacBook Air M1 / MacBookAir10,1 / macOS 27.0.1）；iPhone（iPhone 14 / iOS 27.0.1）；Xcode 27.1（27A9275）
- 蓝牙权限 / 初始按钮数据：`INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription` = "Allow Bluetooth access to find and control nearby smart watches"（即 Bug 4 所述问题文案，见 `app/App.xcodeproj/project.pbxproj:399,429`）；初始按钮数据未单独取证，待补

> 不用 reset/clean 固定版本；排查期间不升级依赖和系统。

## 2. 现象与复现

- 预期 / 依据：iPhone 上终止 `smartcase` 后，Mac 端 `App` 应在可接受的延迟内回到未连接（disconnected）状态（依据 README Bug 报告 2）；实际：App 无任何变化，30 秒后仍显示已连接。
- 最近一次正常的时间 / 版本 / 配置（缩小回归范围）：未做（首次接手，无历史正常基线）
- 初步分类：疑似缺陷

| 步骤 | 操作 | 预期 | 实际 |
| --- | --- | --- | --- |
| 1 | Mac 端 `App` 扫描并连接 iPhone 端 `smartcase` | 连接成功，显示 4 个按钮 | 连接成功（2026-10-30 复现） |
| 2 | iPhone 上直接终止 `smartcase`（杀掉 App） | App 延迟后回到设备列表 / 断连状态 | App 仍停留在 Smart Case Control 详情页，4 个按钮照常显示，未回设备列表（见下方截图） |
| 3 | 继续等待 ≥30 秒并观察 | 已回断连状态（延迟可接受） | 界面停留详情页不回列表；补充观察确认 Connected 文案会自动翻为 `No`（延迟为链路层超时）， Disconnect 按钮置灰（用户判定复现成功） |

![复现截图：杀掉 iPhone 端 smartcase 后，Mac App 仍停留在按钮详情页](<bug-02-assets/repro-01-after-kill.webp>)

- 复现次数 / 最小复现：1 次；最小复现 = 连接成功后直接杀掉 iPhone 端 `smartcase`，观察 Mac App 界面。
- 如需日志：复现前开始、复现后停止，只留相关时段；共享前脱敏。

用户补充观察（2026-10-30）：

- 详情页 Connected 位置会自动由 `Yes` 转为 `No`——说明内部存在一个计时机制（等待一段时间后才判定断连）。
- 下一步方向：找到这个计时机制。
- ~~计时机制假设~~（已推翻）：对 `SmartCaseDevice.isConnected` 做 Xcode Call Hierarchy 跟踪——`peripheralDidDisconnect()` 直接给它赋 `false`，其调用方为 `SmartCaseDeviceManager.centralManager(_:didDisconnectPeripheral:error:)`。结论：延迟不是 App 内计时器，而是 **BLE 链路层的 supervision timeout（系统行为）**。
- 佐证：如果是主动点击 Disconnect（走 `cancelPeripheralConnection` 主动断链），`centralManager(_:didDisconnectPeripheral:error:)` 几乎立刻被调用；对比之下杀掉对端 App 后的回调明显延迟，进一步印证延迟来自链路层 supervision timeout。
- **PacketLogger HCI 抓包实证（2026-10-30）**：两条 Disconnection Complete 事件对照——
  - `12:03:55.589`，Connection Handle `0x0058`，Reason `0x16`（Connection Terminated By Local Host）＝ Mac 端**主动**发起断开（点 Disconnect）；
  - `12:08:58.078`，Connection Handle `0x004C`，Reason `0x13`（Remote User Terminated Connection）＝ Mac **被动**收到断链（对端被杀、超时后上报）。

  ![HCI 抓包：主动断开 0x16 与被动断链 0x13 两条 Disconnection Complete 对照](<bug-02-assets/hci-disconnection-complete.webp>)

  结论坐实：同一回调两种触发路径，延迟差异来自链路层行为，非 App 计时器。

## 3. 分层排查（从易到难，做到定位即止）

每层填四格；结论选：发现异常 / 未见异常 / 证据不足 / 不适用。
思路：沿“上层送出的值 → 下层收到的值”找最早出差异的边界。

### 3.1 App 代码层（Mac `app` 与 iPhone `smartcase` 都看）

| 查什么 / 在哪查 | 预期 | 实际 | 结论 |
| --- | --- | --- | --- |
| UI 层对断连的响应（`DeviceDetailView.swift`） | 断连后界面应刷新（回设备列表） | SDK 层代理与 `isConnected` 均被正确触发，但 UI 层没有监听、没有刷新 | 发现异常（根因所在） |

### 3.2 SDK 层（SmartCaseKit：编码、解码、状态）

| 查什么 / 在哪查 | 预期 | 实际 | 结论 |
| --- | --- | --- | --- |
| 待查 | | | 未做 |

（需要时补 BLE 数据：消息 ID / Action / 原始字节十六进制。）

### 3.3 iOS / macOS 系统层（权限、蓝牙开关、前后台、回调）

| 改变的条件（一次一个） | 操作前 | 操作后 | 结论 |
| --- | --- | --- | --- |
| 待查 | | | 未做 |

### 3.4 硬件层（距离 / 干扰 / 换设备对照）

| 对照实验 | 保持不变的条件 | 实际结果 | 结论 |
| --- | --- | --- | --- |
| 不适用（纯软件模拟，无硬件变量） | | | 不适用 |

> 没有对照设备就写“未验证”；不凭排除法判硬件故障。

## 4. 根因与修复

- 触发条件 / 首次出错位置（端、文件、函数）：Mac 端 `app` / `DeviceDetailView.swift`——UI 层没有 hook `device.isConnected` 的变化。
- 出错机制 → 如何导致现象：SDK 层（SmartCaseKit）的 delegate 与 `isConnected` 均被正确触发（见第 2 节调用链与 HCI 实证），但 UI 层未监听该状态、未刷新，导致杀掉对端 App 后详情页停留原状，看似"未感知断连"。
- 证据（截图 / 日志 / 断点值）：Xcode Call Hierarchy 跟踪（第 2 节）、PacketLogger HCI 抓包（第 2 节）、修复前后截图对照。
- 最小修复 / 为什么改这里而不是另一端：在 `DeviceDetailView.swift` 第 112 行 `.padding()` 之后追加 `onChange` 监听，`isConnected` 变为 `false` 时清空选中设备（回设备列表）。只改 UI 层是因为 SDK 层代理与状态触发均已正确，无需动 SDK：

```swift
.onChange(of: device.isConnected) { _, newValue in
    if !newValue {
        selectedDevice = nil
    }
}
```

- 已知副作用（随修复引入，属既有 `ContentView` 逻辑被新触发链激活）：断连清空 `selectedDevice` 会触发 `enableDiscovery(true)` 重扫并清空 `devices` 列表——杀掉对端后用户回到的是**空列表**，需对端重新广播后才出现。行为可接受，写入提交说明。
- 如何撤销本次修改：分支内 revert 该提交即可。

## 5. 验证与交付

| 项目 | 通过标准 | 修复后结果 |
| --- | --- | --- |
| 原复现步骤 | 杀掉 smartcase 后 App 在可接受延迟内回到断连状态 | 通过：重新编译后重复复现步骤，杀掉 iPhone 端 `smartcase`，App 回到 "Select a Smart Case" 设备列表（见下方截图，2026-10-30） |
| 单测（`smartcasekit` 内 `swift test`，按需） | 全部通过 | 通过（2026-10-30）：2 个用例 `messageRoundTrip`、`messageTooShortIsRejected` 全绿，0 失败 |
| 双端真机回归（按需） | 按 README 运行步骤 1-6 全流程正常 | 通过（2026-10-30，报告人确认：重编译后主动点 Disconnect 正常回列表；重复杀对端 2 次均正常回列表） |

![修复后：杀掉 iPhone 端 smartcase，App 回到设备列表](<bug-02-assets/fix-01-after-fix.webp>)

- [ ] 单测通过 ≠ 双端 BLE 已验证；没做的留“未做”。
- [ ] 已向报告人/QA 同步结论与适用条件；未复测的保持“待确认”并约定跟进。
- [x] 独立分支交付（见 [README 交付要求](README.md#how-to-deliver-the-solutions)），不合并进 main；提交说明写清改了什么、为什么。（`809fc18`，未合并进 main）
