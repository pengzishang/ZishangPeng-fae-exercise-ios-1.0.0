# Bug 01：按钮背景颜色偏差（app 深红 → 设备深橄榄）排查记录

> 1. When changing button icon and background from `app`, the background color on `smartcase` seems to be slightly wrong. For example when `app` shows a dark red background, device shows dark olive.

*本文件为中文版；English version: [bug-01-SOP.md.en.md](bug-01-SOP.md.en.md)*

## 1. 固定版本与现场

- 基线分支 / 提交号：`main` @ `ad26697`（Initial commit）。修复提交 `8291c95`，只动了 `SmartCase.swift` 第 104 行，green 的取值从 `payload[1]` 改成 `payload[2]`。
- 未提交改动及保存方式：干净。修复在 `8291c95` 里，这份记录走单独的 `docs:` 提交，排查时下的断点本来就不入库。
- 修复分支：`fix/01-button-color-encoding`。按 README 要求各 bug 独立交付，这条不合回 main。
- 环境：Mac 是 MacBook Air（MacBookAir10,1，Apple M1）/ macOS 27.0.1（26A434）；iPhone 是 iPhone 14（iPhone14,7）真机 / iOS 27.0.1（Build 24A446），开发者模式已开（`devicectl` 查的），蓝牙已配对；Xcode 27.1（27A9275）。
- 蓝牙权限 / 初始按钮数据：权限我没单独验，因为这个 bug 得连上才看得见颜色，权限没过的话扫描那步就挂了，跟现象对不上，估计是通过的。图标和色表写死在 `app/App/Views/DeviceDetailView.swift:24-42`：图标 `iconIndices = 0..<16`，色表 `backgroundColors` 16 个色，第一个 (60,20,20) 就是 QA 报的那个深红。smartcase 端四个按钮的初始状态我没留记录。
- 辅助工具：Xcode Debug View Hierarchy 定位双端取色点，断点 Log Message / Debugger Command 取值（配置见 3.1）。

> 不用 reset/clean 固定版本；排查期间不升级依赖和系统。

## 2. 现象与复现

- 预期 / 依据：`app` 选的按钮背景色，应该原样出现在 `smartcase` 上。依据是 README 运行步骤 4「The change appears on the simulated case」和 QA 报告第 1 条（README 第 59 行）。实际偏了：`app` 深红，设备显示深橄榄。是「slightly wrong」那种偏，不是彻底乱套。
- 最近一次正常的时间 / 版本 / 配置（缩小回归范围）：不知道。仓库历史只有 `ad26697` 和我的修复提交，定位不到上一版还是好的。我按初始提交就带病处理。
- 初步分类：缺陷。不过在确认是通道索引取错之前，色彩空间转换我也没排除，这属于第 3 层要查的事。

| 步骤 | 操作 | 预期 | 实际 |
| --- | --- | --- | --- |
| 1 | iPhone 跑 `SmartCase`，Mac 跑 `App`，侧边栏选中设备连上 | 连接成功，列出四个按钮 | 正常（这步我还没真机复核） |
| 2 | 在 `App` 点某个按钮，切到深红 | iPhone 端约 1 秒内显示同样深红 | iPhone 端显示深橄榄 |
| 3 | 换已知颜色（纯红 #FF0000 / 纯绿 #00FF00）各发一次 | 显示对应纯色 | 没做。这一步能直接验是不是 R/G 换位 |

- 复现次数 / 最小复现：次数我没系统统计，QA 报的现象是稳定的，不是偶发。最小复现就是上表第 2 步：一次点击、一个深红。
- 如需日志：复现前开始、复现后停止，只留相关时段；共享前脱敏。未采集。

## 3. 分层排查（从易到难，做到定位即止）

每层填四格；结论选：发现异常 / 未见异常 / 证据不足 / 不适用。
思路：沿“上层送出的值 → 下层收到的值”找最早出差异的边界。

### 3.1 App 代码层（Mac `app` 与 iPhone `smartcase` 都看）

| 查什么 / 在哪查 | 预期 | 实际 | 结论 |
| --- | --- | --- | --- |
| 用 Debug View Hierarchy 定位双端取色点：iOS 在 `SmartCaseView.swift:49` 的 `.background(Color(red:...))`（断点实际打在 :47 的 `let svg`，同作用域能取到 `button`）；macOS 在 `DeviceDetailView.swift:94` 的 `nextColor`，色表写死在 :25 | 两端取色点能找到 | 都找到了 | 未见异常 |
| 断点取值：mac 端打印 `nextColor`，iOS 端打印按钮背景 RGB | 双端都是 (60,20,20) | mac (60,20,20)；iOS (60,60,20)，green 通道不对 | 发现异常 |

iOS 断点这么配的（`SmartCaseView.swift:47`，命名 Color）：Action 选 Log Message「----------」，再加三条 Debugger Command，`po button.backgroundRed` / `po button.backgroundGreen` / `po button.backgroundBlue`，勾上 Automatically continue after evaluating actions，命中就打值不暂停。mac 端在 `DeviceDetailView.swift:94` 附近打印 `nextColor`。

### 3.2 SDK 层（SmartCaseKit：编码、解码、状态）

| 查什么 / 在哪查 | 预期 | 实际 | 结论 |
| --- | --- | --- | --- |
| 拿发送端编码对照协议：[SBSC 协议](sbsc-protocol.md)「Set Button Background Color」写的是 payload = [button, red, green, blue]，各 1 字节。再从 iOS 断点值反推，red=60 对、blue=20 对，只有 green 错 | 字节按协议顺序完整送达 | red/blue 都对，说明编码和 BLE 传输没问题 | 未见异常 |

（BLE 数据：Action = SetButtonBackground = 0x03，payload 4 字节。）

### 3.3 iOS / macOS 系统层（权限、蓝牙开关、前后台、回调）

| 改变的条件（一次一个） | 操作前 | 操作后 | 结论 |
| --- | --- | --- | --- |
| 不适用。数据是完整到达接收端并解析了的（red/blue 都对），跟权限和系统状态没关系，故障点已经锁在解析代码上 | | | 不适用 |

### 3.4 硬件层（距离 / 干扰 / 换设备对照）

| 对照实验 | 保持不变的条件 | 实际结果 | 结论 |
| --- | --- | --- | --- |
| 不适用。断点值已经把纯软件缺陷实锤了，不需要硬件对照 | | | 不适用 |

> 没有对照设备就写“未验证”；不凭排除法判硬件故障。

## 4. 根因与修复

- 触发条件 / 首次出错位置（端、文件、函数）：app 端点按钮，发出 SetButtonBackground（Action 0x03）之后。iPhone 端 `smartcase/SmartCase/Models/SmartCase.swift` → `SmartCase.handleRequest(_:)`（L61）→ `case .setButtonBackground`（L93），错在 L104。
- 出错机制 → 如何导致现象：协议说 payload = [button, red, green, blue]（[SBSC 协议](sbsc-protocol.md)「Set Button Background Color」）。修复前 L104 写的是 `let green = request.payload[1]`，取的是 red 那个字节，于是 green 永远等于 red。深红 (60,20,20) 被解析成 (60,60,20)，正好就是 QA 说的深红显示为深橄榄。
- 证据（截图 / 日志 / 断点值）：mac 断点 `nextColor` = (60,20,20)；iOS 断点 = red 60 / green 60 / blue 20；修复 diff 只有 1 行（`payload[1]` → `payload[2]`）；修复后 iOS = (60,20,20)，跟 mac 一致。
- 最小修复 / 为什么改这里而不是另一端：L104 索引 1 改成 2。发送端（mac app + kit）编码是照协议来的，字节序有断点值作证；错的是接收端的解析索引，所以 smartcase 改一行就够。
- 如何撤销本次修改：`git revert` 修复提交；或者 `git checkout ad26697 -- smartcase/SmartCase/Models/SmartCase.swift` 拿回初始版本再提交。提醒一句，修复已经入库了，光 `git checkout -- <file>` 只会恢复出带修复的 HEAD，等于没撤。
- 初判假设修正：早期我以为是「R/G 通道互换」，不对。实际是 green 和 red 取了同一个索引，通道数没错，是下标写错。
- 同族索引核查：`case .setButtonImage`（L72-78）取 `payload[0]`=button、`payload[1]`=imageIndex，跟协议 payload = [button, image index] 对得上，没同类 typo。

## 5. 验证与交付

| 项目 | 通过标准 | 修复后结果 |
| --- | --- | --- |
| 原复现步骤（第 2 节表） | 双端颜色一致 | 通过，但只验了色表首项：mac (60,20,20) = iOS (60,20,20)，2026-10-29 我复测的 |
| 全色表回归（`DeviceDetailView.swift:25` `backgroundColors`） | 色表里每个颜色双端一致 | 只做了静态推演（见下注），真机逐色没验 |
| 单测（`smartcasekit` 里 `swift test`，按需） | 测试通过 | 通过：2026-10-29 `swift test` 两个用例全过（messageRoundTrip / messageTooShortIsRejected，exit 0）。但 kit 测试盖不到 bug 所在的 smartcase app 层解析 |
| 双端真机回归（按需） | 稳定复现消失 | 只验了 60,20,20 这一个色 |

> 全色表推演（修复前 green≡red，实际显示成 (red, red, blue)）：16 个色里 14 个 R≠G，一显示就错，比如 (60,20,20)→(60,60,20)、(60,20,60)→(60,60,60)、(20,60,20)→(20,20,20)。只有 (20,20,60) 和 (60,60,20) 因为 R=G 天然免疫。所以回归要是只挑到 R=G 的颜色，根本测不出这类 bug。
