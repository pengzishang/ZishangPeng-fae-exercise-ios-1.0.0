# Bug 3：连接后图标状态不同步 排查记录

> 3. Start `smartcase` on iPhone, then connect to it from `app` on the Mac. The `app` doesn't show the same icons as `smartcase`. When changing icons from the `app`, everything is looking good, however when restarting the `app`, the icons are wrong again.

*本文件为中文版；English version: [bug-03-SOP.md.en.md](bug-03-SOP.md.en.md)*

## 1. 固定版本与现场

- 基线分支 / 提交号：`main` @ `ad26697`（Initial commit: fae-exercise-ios assignment）
- 改动与提交状态：修复已提交 `a2be0f9`（第 63 行 imageIndex 偏移 `+1` → `+0`，仅此一行）；排查插桩已移除；为单测的抽函数方案拍板退回、测试文件已删（见第 5 节）；本记录与 `bug-03-assets/` 待按 `docs:` 提交
- 修复分支：`fix/03-icon-state-sync-on-reconnect`（现有提交：`a2be0f9`）
- 环境：Mac（机型 / macOS）MacBook Air（MacBookAir10,1，Apple M1）/ macOS 27.0.1（26A434）；iPhone（机型 / iOS）iPhone 14 / iOS 27.0.1（与 Bug 2 现场一致）；Xcode 27.1（27A9275）、Swift 6.4（本机实测）
- 蓝牙权限 / 初始按钮数据：权限文案为 "…smart watches"（属 Bug 4 范围）；初始按钮数据未单独取证，代码默认四按钮 img 0 / RGB(32,32,32)，会话中实测状态见 3.2 出口核验 payload

> 不用 reset/clean 固定版本；排查期间不升级依赖和系统。

## 2. 现象与复现

- 预期 / 依据：README Assignment 第 3 条——`app` 连上 `smartcase` 后应显示与 `smartcase` 一致的图标；实际：连接后 `app` 显示的图标与 `smartcase` 不一致
- 最近一次正常的时间 / 版本 / 配置（缩小回归范围）：不适用（作业基线，此前无已知正常版本）
- 初步分类：疑似缺陷

| 步骤 | 操作 | 预期 | 实际 |
| --- | --- | --- | --- |
| 1 | 同时启动 Mac 端 `app` 和 iOS 端 `smartcase` | — | — |
| 2 | Mac 端连接 iOS 端 | `app` 显示与 `smartcase` 相同的按钮图标 | 两端图标不一致 |
| 3 | Mac 端随意点击改动几次 | 双方同步变化 | 此阶段一切正常 |
| 4 | iOS 端断开后再重新连上 | 两端图标保持一致 | **两端图标明显不一致** |
| 5 | iOS 端反复杀掉 `smartcase` 进程几次 | — | iOS 端图标**稳定不变** → 疑似 iOS 端存在永久储存，状态跨进程存活 |
| 6 | （修复前补充观察）两端不一致时，在 Mac 端点击其中某个不一致的按钮 | — | **被点击的按钮立即与 iOS 端一致，其余未点击的按钮仍保持不一致**；Mac 端断开重新连接后，界面图标又重新变乱 |

- 复现次数 / 最小复现：实测可稳定复现（步骤 1→4）；最小复现 = 同时启动两端、连接、Mac 端改动几次、iOS 端断开重连
- 步骤 6 观察与根因机制吻合：点击仅更新被点按钮的本地状态（`setButtonImage` 路径不经过响应解码），未点击的按钮仍持有上一次解码的错误值；断开重连后重新走一遍解码，错误再次复现
- 初步推断（随复现记录）：iOS 端反复杀进程图标不变，说明 iPhone 侧按钮状态大概率有持久化存储，断开重连后不一致的差距更可能出在 Mac 端取数/呈现侧
- 如需日志：复现前开始、复现后停止，只留相关时段；共享前脱敏。未采集。

## 3. 分层排查（从易到难，做到定位即止）

**初步思路（原话）**：

> 我感觉第三题是一个同步问题，第一次 mac 连接 iPhone 的时候，应该是要从 iPhone 那边取到 iPhone 那边按钮的数据。

### 3.0 两端取值链梳理（2026-10-30）

**iOS 端（SmartCase 状态来源）**：

- 按钮状态从 `SmartCase` 的第 24 行 `buttons` 读取；
- `SmartCase` 这个单例在初始化时取值，走 `loadButtons()` 方法；
- 进一步指向 `persistentButtons` 变量；
- 该值由 `Persistent` 这个 propertyWrapper 处理，**永久化了**（与第 2 节“反复杀进程图标稳定不变 → 疑似永久储存”的观察互相印证）。

**Mac 端（按钮状态获取链）**：

- `selectedDevice` 值改变后，通过 `SmartCaseDevice` 的 `connect()` 方法发起连接；
- 在 `public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?)` 中调用 `updateButtons()`；
- 继而 `let response = try await sendRequest(request)` 对 peripheral 进行 `writeValue` 操作；
- iPhone 端经 `func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest])` 中 `handleRequest` → `handleWriteRequest` 接收；
- 最终在 `handleRequest` 取到 iOS 端 `buttons` 的值。

**下一步行动**：检查这条链路中是否有**值传递或者读取错误**。

### 3.1 App 代码层（Mac `app` 与 iPhone `smartcase` 都看）

| 查什么 / 在哪查 | 预期 | 实际 | 结论 |
| --- | --- | --- | --- |
| `app/App/Views/DeviceDetailView.swift:76-86` | 图标/颜色来自 `device.buttons` | 确认直接读 `device.buttons[i]` 渲染，UI 层无独立缓存 | 未见异常（初步阅读） |
| iPhone 端状态来源 | 持久化、重启后可读回 | `smartcase/SmartCase/Models/SmartCase.swift:44-59` 用 `@Persistent(key: "buttons")` 持久化并在 init 时 `loadButtons()` | 未见异常（初步阅读） |

### 3.2 SDK 层（SmartCaseKit：编码、解码、状态）

| 查什么 / 在哪查 | 预期 | 实际 | 结论 |
| --- | --- | --- | --- |
| 连接建立后是否拉取按钮状态（初步思路的核心） | 连接后应从 peripheral 取当前按钮数据 | `SmartCaseKit/SmartCaseDevice.swift`：`didDiscoverCharacteristicsFor` 里确有 `Task { try? await updateButtons() }`，连接后确实发送了 `getButtons` | 未见缺失 |
| `getButtons` 应答的编码侧 | 按 `sbsc-protocol.md`：`[status, count, (img, R, G, B) × n]` | iPhone 端 `SmartCase.swift:64-70` 逐字节按协议组包 | 未见异常 |
| `getButtons` 应答的解码侧 | imageIndex 取每按钮第 1 字节（偏移 +0） | `SmartCaseDevice.swift`：`imageIndex` 原读 `payload[2+i*4+1]`，与 `red`（同为 +1）读到**同一字节**；按协议应为 `payload[2+i*4]`。R/G/B 三通道偏移正确 | **发现异常（已实锤）**：Mac 端接收正常（`response.payload` 与 iOS 端发出值逐字节相同），确认差异出在解码偏移。将偏移 `+1` 改为 `+0` 后复测，**问题解决** |
| iOS 端出口核验（实测，2026-10-30） | 编码侧按协议组包，imageIndex 与 iOS UI 一致 | 在 `handleRequest` 第 68 行加 `debugPrint(button.imageIndex)`，console 输出 `0 0 0 0`，与发送前 iOS UI 四按钮状态一致（截图 `bug-03-assets/ios-smartcase-ui-icons.webp`：四按钮同一图标、背景色各异）；实际发出的 payload 逐字节：`0:0, 1:4, 2:0, 3:60, 4:60, 5:20, 6:0, 7:20, 8:20, 9:20, 10:0, 11:60, 12:60`（截图 `bug-03-assets/ios-getbuttons-payload-log.webp`）。解读：`[0]=status OK`、`[1]=4 按钮`、按钮 0 = img 0 + RGB(60,60,20)、按钮 1 = img 0 + RGB(20,20,20)、按钮 2 = img 0 + RGB(60,60,…) | **未见异常（编码侧）**：imageIndex 出口全 0 且与 UI 相符，编码按协议。payload 清单止于索引 12（协议 4 按钮应为 18 字节）——修复后回归截图（`after-fix-reconnect-icons-match.webp`）中按钮 3 图标（Spotify）显示正确，说明按钮 3 的 img 字节（payload[14]）完整到达并被正确解码，判定当初清单止于 12 为**日志展示截断**而非载荷截断 |

（消息 ID / Action 未记录，对定位无影响；Mac 端接收侧已核验：`response.payload` 与 iOS 端发出值逐字节相同。）

### 3.3 iOS / macOS 系统层（权限、蓝牙开关、前后台、回调）

| 改变的条件（一次一个） | 操作前 | 操作后 | 结论 |
| --- | --- | --- | --- |
| — | — | — | **不适用**：iOS 端出口 payload 与 Mac 端接收 payload 逐字节一致（见 3.2），数据在整个传递链路上无差异，系统层不是差异来源 |

### 3.4 硬件层（距离 / 干扰 / 换设备对照）

| 对照实验 | 保持不变的条件 | 实际结果 | 结论 |
| --- | --- | --- | --- |
| — | — | — | **不适用**：同 3.3——传递过程数据已证明无问题，且复现 100% 与数据内容相关（仅 imageIndex 字节错位），无硬件故障迹象 |

## 4. 根因与修复

- 触发条件 / 首次出错位置（端、文件、函数）：**Mac 端（SmartCaseKit）**，`smartcasekit/Sources/SmartCaseKit/SmartCaseDevice.swift` 的 `updateButtons()`——每次连接建立后初次拉取按钮状态（含初连与 `app` 重启后重连）时触发。
- 出错机制 → 如何导致现象：iOS 端按协议组包 `[status, count, (img, R, G, B) × 4]`（出口核验已证），Mac 端接收的 `response.payload` 与发出值逐字节相同（接收侧无差异）；但解码时 `imageIndex` 读的是 `payload[2 + buttonIndex * 4 + 1]`——偏移 `+1` 是**红色通道**的位置，真正的 imageIndex 在 `+0`。于是每个按钮的“图标索引”被错读成背景红色的数值，而 R/G/B 三通道偏移都正确，所以**颜色显示正常、唯独图标错**。从 `app` 改图标时 `setButtonImage` 直接更新本地 `buttons` 状态、不经过这条解码路径，所以“改动期间一切正常”，且只有被点击的按钮恢复一致（第 2 节步骤 6 观察）；重启 `app` / iOS 端断开重连后重新走 `updateButtons()` 解码，错误复现。
- 证据（截图 / 日志 / 断点值）：①iOS 端出口核验：`handleRequest` 内 `debugPrint(button.imageIndex)` 输出 `0 0 0 0` 与 UI 一致；payload 逐字节 `0:0, 1:4, 2:0, 3:60, 4:60, 5:20, 6:0, 7:20, 8:20, 9:20, 10:0, 11:60, 12:60`（截图 `bug-03-assets/ios-smartcase-ui-icons.webp`、`bug-03-assets/ios-getbuttons-payload-log.webp`）——按钮 0 的 `+0` 字节是 0（图标），`+1` 字节是 60（红通道），旧代码会把图标读成 60；②Mac 端接收侧：打印 `response.payload` 与 iOS 发出值相同；③修复后复测通过（见第 5 节）。
- 最小修复 / 为什么改这里而不是另一端：将解码处偏移 `+1` 改为 `+0`（`payload[2 + buttonIndex * 4]`）。改 Mac 端解码侧而非 iOS 端编码侧，因为 iOS 端编码与持久化均已按协议核验无误，唯一偏离协议的位置就是这一处解码偏移。
- 如何撤销本次修改：`git revert a2be0f9`（或把第 63 行偏移改回 `+1`）即可复现原始缺陷；插桩已移除，无需处理。

## 5. 验证与交付

| 项目 | 通过标准 | 修复后结果 |
| --- | --- | --- |
| 原复现步骤（同时启动两端 → 连接 → Mac 端改动几次 → iOS 端断开重连） | 两端图标一致 | **通过（实测）**：偏移改 `+0` 后复测，两端图标一致，问题解决 |
| 单测（`smartcasekit` 内 `swift test`） | 解码函数对协议 payload 逐字节断言通过 | **未纳入交付（拍板）**：曾实现“解码抽静态函数 + 4 个解码用例”方案并跑通 6/6（含既有 2 个消息用例，运行需 `swift test --disable-sandbox`），但该方案需要重构源码结构，拍板退回——源码只保留单行修复，测试文件已删除。验收以双端真机回归为准 |
| 双端真机回归（按需） | 初连 / 改动 / 重连后两端图标均一致 | **通过（实测，2026-10-30）**：Mac 端点击多轮改动后 iOS 端断开重连，两端图标与背景色逐按钮一致（截图 `bug-03-assets/after-fix-reconnect-icons-match.webp`：Mac `app` 与 iPhone 同屏对照，四按钮 图标/背景 完全对应） |
| 重启 / 重装 `app` 场景（README 原始症状） | 重启 `app` 后两端图标仍一致 | **通过（实测确认）**：重启 `app`、删除 `app` 后重新连接，图标仍正常一致。README 原始症状的全部场景已覆盖 |

- [x] 真机回归已覆盖双端 BLE 实际行为；未做项已如实标注（单测未纳入交付）。
- [x] 结论与适用条件已同步（本人即修复执行人）；适用条件：仅覆盖 `getButtons` 解码路径，`setButtonBackground` / `setButtonImage` 路径不受本修复影响。
- [x] 独立分支交付（见 [README 交付要求](README.md#how-to-deliver-the-solutions)），不合并进 main：修复已按 `fix(kit):` 规格提交（`a2be0f9`，1 file / 1 insertion / 1 deletion）；本记录与证据目录随后按 `docs:` 提交。分支**未推送 origin**，推送时机与交付形式（公开仓库 / zip）待定。
