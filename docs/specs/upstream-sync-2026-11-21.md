# 上游同步记录：2026-11-21

## 基线与方法

- 上游：`origin/main` 与 `upstream/main` 同为 `dbb8345`，满足 AGENTS.md 的镜像一致性前置条件。
- fork：本 worktree 分支 `venomous-kolibri`，同步起点 `ae5b13a`（`origin/chaslui-dev` tip）。
- 方式：按上游顺序对 103 个提交逐个 `git cherry-pick -x`，保留上游提交粒度与来源；冲突逐个按语义合并，不机械覆盖 fork 已有实现。
- 结果：103/103 全部落地，没有 deferred 的提交。同步后另有 8 个本地提交：本地化收尾（`c42eec3`）、`DownloadsFloat` 构建修正（`e1b1688`）、`WindowDragTests` 标题带适配（`bf05575`、`8efbfe9`）、CHANGELOG 恢复（`7f28fd9`）、`canBringLine` 固定英文（`b69f6d0`）、`ICloudSyncTests` 固定英文文案（`2acb94b`）、历史记录“其他设备上的标签页”分区标题本地化（`75e1dda`）。本记录文档单独提交。

## 提交记录

状态：`ported` 表示该提交已以 `-x` 落地并按 fork 适配；`Scope` 为上游提交改动的非 CHANGELOG 文件数，便于回查冲突面。

| Fork | Upstream | Change | Scope |
| --- | --- | --- | --- |
| b476eea | dbb8345 | PinDragTests: wake the pin before carrying it out among the rows | 1 file |
| db44944 | 2a45297 | FollowFileTests names the look and layout settings read again since | 1 file |
| 0fdd722 | f1dc308 | Tests: put pins down and close windows between sidebar tests | 2 files |
| 7ff5efd | b0935a8 | The column's address, a pin's letter and a group's name keep their field again | 3 files |
| 5da7ad9 | 558d6f3 | Spaces: one stroke, one slide, its glide included (idea 834) | 3 files |
| 7d5586a | e709891 | Split: Settings stays in its own pane, never over the column or the page beside it (idea 833) | 2 files |
| 7ab705a | 074c6b5 | Say under each browser found what can come over from it | 7 files |
| 4a81fb5 | 9cc5f07 | Safari directly when its files can be read, else one sentence and the steps to export | 5 files |
| 36d254a | 7ab361e | Import from more browsers: Thorium, Whale, Island, Sidekick, Yandex, ChatGPT Atlas, Floorp, LibreWolf, Waterfox, Mullvad Browser and Orion | 6 files |
| 310a595 | c634093 | Open tabs and tab groups come over from Firefox and Zen | 6 files |
| 0f02c83 | 4946a3b | Zen's spaces, pinned tabs, folders and Essentials come over, the way Arc's do | 8 files |
| 730a62d | f0e42a6 | Stylus's button opens its popup and manager: a probe pins it (idea 827) | 1 file |
| 2dff6b9 | ca6128c | Search 1.0.16 | 3 files |
| 7e064a3 | 6ce89b6 | Ask which space a link from another app opens in, off unless turned on (#1175) | 18 files |
| 78419d9 | 681cbc5 | Buttons at the top, off by default; the column's edge keeps up with the pointer | 7 files |
| a1c8010 | 9bebf8f | Give sidebar tab groups an optional colour (#1237) | 5 files |
| 4e067a3 | 2c37a80 | The window moves from more of its top (#1257) | 4 files |
| b3a881f | d2d02b0 | Resizing pages: no dark strip at a page's edge while WebKit catches up (#1250) | 1 file |
| 2ccae53 | c4d4275 | Split: a page SwiftUI draws (Settings, History) follows the divider (#1251) | 1 file |
| cda16a1 | 999eb0f | Tests: settings_layout expects the rows Settings has now (#1239) | 1 file |
| 97a9a5d | e02e997 | Glass window and Liquid Glass tab, both off unless turned on | 11 files |
| 1fc15bd | 281b975 | CHANGELOG: Sync with iCloud | CHANGELOG only |
| c27db5e | c1b8741 | Sync with iCloud: never await CKSyncEngine from inside its callbacks | 2 files |
| 4ae8aba | 92beb2c | Sync with iCloud: follow SYNC.md's answers (9247300) | 3 files |
| 1ab9018 | d087c76 | Sync with iCloud: the Mac side of SYNC.md, off by default | 12 files |
| 1cf4e55 | c1f75db | Always show the address bar, off unless turned on (#1227, #1240) | 9 files |
| 7d85190 | 3f05163 | Handoff, off by default: the page in front to your devices, and pages from them (#1256, #1235) | 8 files |
| f1e76cb | f927f6e | Zotero Connector starts: an extension's page and worker talk over a handed-over port (#1258) | 2 files |
| 72f2b70 | 84e18d0 | Shield: the first pages after launch wait for the block list (#1248) | 2 files |
| a558832 | 568fa5f | A middle-click's window goes behind; the pinned rows' drop mark goes (#1243, #1245) | 6 files |
| 155809c | 319ef8b | Clear › Cache takes Cache Storage too, so a service worker's old copy goes (idea 793) | 4 files |
| 5b7c52e | 859c951 | Tests: little_window presses keys where this Mac's layout has them | 2 files |
| 913406a | c47c937 | uBlock Origin MV2 says it can't block requests here; its alarms run (#1208) | 5 files |
| 1dffe13 | cbc8316 | Spaces: quick, smooth switching with many tabs (#1213) | 12 files |
| b5c60b7 | 70ed3ba | Probe: single-page apps go back by swipe, ⌘[ and Back (idea 748) | 1 file |
| 37bc1b5 | a0a2e76 | A sideways scroll scrolls what is under it before it means Back (idea 751) | 3 files |
| 5b6e33d | 5fd4e2e | A PDF zooms in with ⌘+ as far as its own bar does (idea 749) | 3 files |
| e1a1bf4 | 04194e9 | Bench "rate": an extension's new tab animates as often as a web page | 2 files |
| 698b2ec | 2cf92db | An extension that couldn't start says why in Settings (#1208) | 4 files |
| c88696e | 70b9303 | View › Enter Full Screen is back, on ⌃⌘F (#1176) | 3 files |
| 1b9b6d1 | c1136ce | A probe for a worker's port to an app staying open while idle (#1122) | 2 files |
| 35a438f | c9f9fe8 | More of an extension's request rules load as Chrome takes them (#1168) | 2 files |
| c3ec48a | 3f78027 | A long accounts list under a sign-in box scrolls (#1215) | 3 files |
| 0bad33c | 1323fdc | Popover arrows stay clear of their corners near the screen's edge (#1188) | 12 files |
| 2d053a6 | 8167b5d | An extension's pages framed in websites share one localStorage, as in Chrome (#1086) | 2 files |
| bec6249 | adca12d | View › Actual Size names the page zoom it goes to when that isn't 100% (#1210) | 4 files |
| 60a532f | 3be9280 | ⌘1–⌘9 pass over a folded group holding no page (#1186) | 2 files |
| a9fcbb1 | 957ef04 | A tab in the small window, from a tab's menu (#1119) | 10 files |
| 1d3a5fd | f5f2b69 | An extension's content scripts can read the extension's own Blob URLs (#1148) | 11 files |
| d71e0ee | fe3cbd9 | Extension messages keep their reply when a relayed copy arrives first (#1147) | 3 files |
| 57158c4 | 119740c | An extension's new tab shows its title, not "Extension page" (#1214) | 2 files |
| 82d1ef4 | 035f250 | Downloads: hairlines edge to edge, and a fade at the list's foot (#1190) | 1 file |
| d685745 | 3c37a51 | Dim sleeping tabs, off by default (#1131) | 8 files |
| fd633ab | 1856774 | High contrast text for tabs, off by default (#1218) | 8 files |
| 3d07428 | 0a5ee67 | A signed-out space keeps its own history (#758, #1166) | 6 files |
| a3f8f7c | 2903b0f | Fresh extension installs hear onInstalled("install") (#1165) | 2 files |
| 6ebb547 | ad2bd16 | The Settings sidebar slides its highlight to the chosen section (#1169) | 1 file |
| 98ce66e | e9269fd | Answer a framed site asking for its cookies, as Safari does (idea 745) | 3 files |
| 7552589 | f5bfd6d | The hidden column comes out at once for a pointer pinned to the screen's edge (#1170) | 1 file |
| 6dd3437 | ccbc039 | Passwords: ↓, ↑ and Return walk the accounts under a sign-in box (#1199) | 4 files |
| aae392d | 3a54617 | No crash comparing dates on macOS 27.2 (26B5091g) (#1201) | 1 file |
| a21cf66 | 02336c8 | Extensions can ask for one site under their optional host wildcards after a click (#1217) | 2 files |
| 5a49cb0 | 3bcc988 | Window managers can move the window from its title bar (idea 744) | 3 files |
| 4b5ecec | 9c5e32f | Autocorrect switched off stays off in every page (idea 743) | 6 files |
| 42be8de | 954e3dc | ⌘S: the folded column or strip stays folded after a relaunch (idea 738) | 4 files |
| 3dd57d9 | 64cd7dd | Floating Downloads: as tall as its list, and not cut off by the column (idea 739) | 2 files |
| de5b164 | 1b70afc | Fields: the caret and the last letter of a long query stay in sight (idea 736) | 4 files |
| 5267b65 | 05d957a | Slide the column in and out: a fade under Reduce Motion, where it did nothing | 6 files |
| 76a6ce3 | 99d506a | ⌘S: no dark block on the far side while a slow page catches up (idea 737) | 3 files |
| 9356a30 | 88db2e0 | Search 1.0.15 | 3 files |
| b56593d | ef98d73 | Extensions: a popup from a shortcut opens with the tabs folded away | 5 files |
| f0e100d | efcff5c | Extensions: no welcome tab again on every launch | 3 files |
| 71abcb2 | 1ff2033 | Tests: extension_frame_focus gives the page the keys before pressing T | 1 file |
| 6f690e9 | 1799f74 | Bookmarks: a new bookmark goes to the folder picked last | 3 files |
| b7b703a | f23e5b9 | Profiles in one window: the swapped-in window joins the current desktop | 2 files |
| 3440f28 | 6e4aa55 | ⌘1–⌘9 can switch spaces, tabs on ⌃1–⌃9, as in Arc | 11 files |
| 7adf631 | cc2441d | Email links open in a webmail: Gmail, Outlook.com, Fastmail, Proton Mail | 10 files |
| 8958b21 | 9c9aee6 | Agent control: Stop suspends from the first session, and the review's low items | 5 files |
| 308376f | 9270425 | Agent control: the security review's fixes to "Always allow" | 9 files |
| 79960bb | 61367d6 | Agent control: "Always allow" by code signature, and Stop off the page | 14 files |
| bfd67fe | d0e01cc | Space look: a Strength, Subtle, Rich or Vivid, for a colour or a gradient | 10 files |
| 2cd5d9e | 7cb3208 | From any app: open the page in a small window, as Little Arc's ⌥⌘N | 7 files |
| 4e2f8a8 | 4811fdf | A right-click anywhere in the column has a menu | 5 files |
| d9d3cf1 | 8703267 | Capture…: a click takes its element, and the outline shows in dark mode | 3 files |
| 6726cde | 51e942a | Slide the column in and out: an eased slide for the column (off by default) | 7 files |
| 7b714c0 | 2b4baef | ⌘S: no bar of empty page while the column folds away | 5 files |
| 1ab5c67 | c3421ba | Pin folders: a folder moves by dragging its heading | 7 files |
| f41c55c | 6c90abd | Pin folders: opening one no longer scrolls the column | 2 files |
| d87809f | 29ee471 | Pin folders: folder rows take a tab row's metrics | 5 files |
| 94271da | c7c3d20 | Pins: no spinner left on a pin closed mid-load | 2 files |
| a7f8f0e | 0cfc5bf | Site style editor: resizable from its corner, size kept | 4 files |
| 70b0a11 | 6a5e6ed | Passkeys off: keep the passkey object, saying there are none | 3 files |
| 0b1ae58 | c0fffad | Extensions: a frame's own request meets initiatorDomains as in Chrome (idea 712) | 2 files |
| ac97e20 | 3838087 | ⌥-click a link can open it in Split View (off by default) | 5 files |
| 488ff5f | 2386e8f | Tests: X's sign-in page, checked live in a hidden probe | 1 file |
| 26e7537 | 2361d0f | Header rules and page script: re-review follow-ups | 5 files |
| 7ecd2d9 | cf2fb58 | Header rules: matching that can't hang, Chrome's precedence, no loopback | 4 files |
| c932c40 | 74890b1 | Page script: run only in the document asked from, from content scripts | 5 files |
| 54f55d9 | 5164efc | An extension's own header rules reach its fetches the browser sends | 4 files |
| 403626a | 4a8bd3e | An extension's own script runs in a page whose policy refuses it | 3 files |
| 9179c76 | 38a6d18 | A background page isn't restarted for asking itself | 2 files |
| cc8dd13 | 0710498 | Claude in Chrome's side panel no longer blank once signed in (idea 686) | 3 files |
| 1b0ab44 | 862d812 | Extensions: permission changes don't run content scripts again in open pages | 6 files |

## 冲突与语义适配

以下位置不能按上游原文照搬，已按“理解后移植”处理：

- **标签栏/侧栏性能**：`TabBar.swift` 合并上游新的 `fit` 限额与 fork 的 `SplitItems`/`splits:`，保留 `LazyHStack`；`Side.swift` 保留 `LazyVStack`，同时接上游 `LooseRow` 与 `browser.rowKey`。规格见 `tab-bar-grouping-performance.md`。
- **Stage / 窗口拖动**：采用上游 `2c37a80`（#1257）的 `aim`/`hold` 与 `holdsWindow` 语义——只有指针位于标题带内的标签/按钮上时窗口不可移动，其余区域可移动；保留 fork 的 `_ = Strip.shortcuts` 与 Command/Option/Control 快捷键放行监控。`WindowDragTests` 原先把“进入 strip 即锁窗口”当作前提，现改为在标题带内进入，并使用 full-size content view，与真实窗口一致。规格见 `window-drag-tiling-upstream.md`。
- **Agent 使用提示**：上游删除了 fork 曾本地化的 `AgentPill`，整块按上游移除；`AgentBanner` 的新文案（停止、自动允许、拒绝原因、帮助）全部改用语义键。
- **Accounts**：按上游的 ↓/↑/Return 键盘行走与长列表滚动结构重写，重新套用 fork 的 `account.*`、`ui.*` 键。
- **ImportPanel**：采用上游新增的 `%3$@`（收藏项）与 `%1$@`（来源名）参数及 Safari 导出步骤，重套 fork 的 `import.*` 语义键。
- **Settings**：多轮冲突合并后保留 `title`/`detail` 变量与 `relabel` 结构；新增 `mail.default`、`spaces.commandNumbers`、`tabs.highContrast`、`sidebar.doorsUp` 等条目；`language` 与 `icloud` 两个观察对象并存。`settings.icloud.erase.title` 在设置行与确认框里被上游复用于不同文案（有/无问号），fork 为确认框另立 `settings.icloud.erase.confirm`，避免同一键两种英文。
- **测试**：`PinDragTests` 改用上游的 `wake(_:then:in:)` helper，保留 fork 的 `selectLoadedPinForDrag` 供 `PinStuckTests` 使用；`FollowFileTests`、`SidebarPressTests` 的清理逻辑按上游更新。
- **构建修正**：`DownloadsFloat.swift` 在合并 `LanguageRoot` 包裹时多了一个右括号，`e1b1688` 修正。

## 本地化收尾

- 新增 215 个键（agent/iCloud/Handoff/link chooser/import/mail/glass/shortcuts 等），en 与 zh-Hans 均为 2525 条，字符串表格式与参数一致，`Localizable.stringsdict` 35 条复数表未变。
- 结构化适配而非字符串拼装：
  - `AgentTrust.swift` 新增 `Refusal` 枚举，把“为什么不能记住”从英文句子变成可本地化的原因；`AgentLauncher.unrememberable` 保留英文供 bench/测试，`AgentSession.noAlways` 显示时用 `Refusal.localized`。
  - `Extensions.cantDo` 保留英文供 bench；界面改用 `localizedCantDo`，`reason` 局部化为 `@MainActor` 并翻译“未知错误”。
  - `ImportSource.localizedCanBringLine` 用 `Language.shared.locale` 的 `ListFormatter` 连接本地化词条，Welcome 与导入面板共用。
  - `ICloudSync` 的 summary/say/title/suggestion 全部走 `Language.shared`；`deletedElsewhere` 常量仍作文本标记，显示时映射为 `icloud.off.deleted_elsewhere`。
- 原生字符串键（如 `Stop`、`Disconnect it...`、`Opened by a script`）继续使用 en 资源作为键，补上 `bundle: Language.resources`，保证跟随应用内语言而不是系统语言。
- 上游新增的 iCloud 历史分区原先是 `Section("Tabs on Your Other Devices")`，没有资源键也不会跟随应用内语言；改为 `Section { … } header: { Text("history.other_devices", bundle: Language.resources) }`。
- 资源检查：`python3 Tests/check-localization.py` 通过（2525 strings / 35 plurals）；`plutil -lint` 四个资源文件通过。

## CHANGELOG

冲突中 CHANGELOG 一律取上游版本，fork 自己的 Unreleased 条目因此丢失；已按原意并回 `### Fixed`（21 条，含扩展、标签栏、窗口拖动、图片复制、密码等），保持仓库单行条目风格。

## 验证

环境：macOS 27.2.1（Darwin 27.2.0）、Apple Silicon、Xcode 27.2 / Swift 6.4.2，`swift build` Debug。

会话中途主仓从 `/Volumes/mbp14-fast/x-repo/github.com/ChasLui/Search` 移到 `~/.x-repo/github.com/ChasLui/Search`，本 worktree 的 `.git` 指针已改指新位置；移动前后的构建、测试与提交均正常。

- `swift build`：`Build complete!`（48.29 秒，i18n 收尾后）。
- `python3 Tests/check-localization.py`：通过。
- `plutil -lint`：en/zh 的 `.strings` 与 `.stringsdict` 均 OK。
- 针对性测试（单项或单类运行，避免共享 AppKit/prefs 状态互相污染）：
  - `AgentTrustTests|AgentControlTests|LanguageTests|SettingsIndexTests`：70 项通过。
  - `WindowDragTests`：4 项通过（已按标题带语义调整事件坐标）。
  - `SidebarPressTests/testPressThenDragStillReordersWithoutEditing`、`testStripPillPressThenDragStillReorders`：分别独立运行通过。
  - `ShortcutTests/testReboundArrowsYieldWhileTyping`、`AddressCommandTests`、`ProxyTests`、`TabGroupDropTests`、`RowCarryTests`、`TabGroupDragOutTests`、`SplitManyTests`、`SpeedBenchTests/testStripGrouped200`、`TabShortcutHintTests`：通过。
  - `Extension|Crx|Popup`：176 项通过，1 项跳过。
- 观察：把 `TabShortcutHintTests` 与 `SpeedBenchTests` 等类放在同一 `swift test` 进程里运行时，`testFoldedGroupHoldingNoPageIsPassedOver` 曾因共享状态失败；单独运行该类与单独运行该用例均通过。`Tests/run-ci-tests.py` 按仓库约定做进程隔离。
- 第一次完整 `python3 Tests/run-ci-tests.py`（2026-11-21 15:37–15:57）退出码 1，失败分四类，据此修正：
  - `BrowserDiscoveryTests/testMoreBrowsersAreFoundOnceEach`：`canBringLine` 用系统 locale 连接英语词条，中文 Mac 上不再以 “Bookmarks, history” 开头。改为固定 `en` locale；界面本就用 `localizedCanBringLine`。
  - `ICloudSyncTests` 两项：summary 已本地化，测试仍与英文比较。两项改为临时 `language.select(.english)` 并在 `defer` 恢复，沿用仓库既有测试写法。
  - `WindowDragTests/testBrowserHandsWindowShortcutToAppKit`：只在同进程全量运行时失败，固定 x=20 可能落在红黄绿按钮而非标签上。测试改为沿标题带试探，直到指针落在会锁窗的位置。
  - `FloatUnseenTests` 四个隔离用例：WebKit 在 `canvas.captureStream` 视频上抛 `InvalidTransition { phase: idle, targetPhase: failed(deinit) }`。本次同步没有任何提交触及 Float/媒体/播放器代码，先在单测进程复现，判断为这台 Mac 上 WebKit 媒体管线的环境问题，未计入同步回归；仍列为未验收。
- 第二次完整 `python3 Tests/run-ci-tests.py`（2026-11-21 16:05–16:26）：主套件 1230 项、27 项跳过、1 项失败；43 个隔离用例中 4 项失败。退出码 1。
  - 主套件唯一失败为 `BookmarkFolderMemoryTests/testEachProfileRemembersItsOwn`（“kept across launches”），该用例单独运行时 2 项全过；第一次完整运行时也通过。判为共享 `Store.world` 下的偶发失败，未改动相关代码。
  - 隔离用例仍为前述 `FloatUnseenTests` 四项，原因不变。
  - 第一轮的四类失败中，`BrowserDiscoveryTests`、`ICloudSyncTests`、`WindowDragTests` 已在第二轮通过。

## 未验收项

- macOS 14 实际启动与运行（构建目标为 14，但仅在 macOS 27.2.1 验证）。
- 真实物理鼠标/触控板的拖拽与系统平铺、真实 Fn/Control 快捷键、第三方窗口管理器。
- 真实输入法下的快捷键录制、VoiceOver 朗读顺序、语言切换后的整窗重绘。
- 动画与玻璃/渐变在浅色与深色下的实机视觉检查（`ExtensionPopupMotionTests` 等合成用例已通过）。
- GitHub CI：本 worktree 未 push，远端结果未产生。

## 后续

- 把本记录与 `docs/specs/` 下六份规格一并复核；若上游继续推进，按相同流程比较后决定保留、迁移或替换。
