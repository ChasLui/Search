# 上游同步记录：2026-11-22

## 基线与方法

- 上游：`origin/main` 与 `upstream/main` 同为 `c48f067`，满足 AGENTS.md 的镜像一致性前置条件；快进后两个远端 main 保持一致。
- fork：本 worktree 分支 `venomous-kolibri`，本轮同步起点 `e425496`（上一轮 2026-11-21 的记录见 `upstream-sync-2026-11-21.md`）。
- 范围：上游 `dbb8345..c48f067` 共 66 个提交，全部按顺序 `git cherry-pick -x`，保留上游提交粒度与来源；冲突逐个按语义合并，不机械覆盖 fork 已有实现。
- 结果：66/66 全部落地，没有 deferred 的提交。

## 提交记录

状态：全部为 `ported`；`Scope` 为上游提交改动的非 CHANGELOG 文件数，便于回查冲突面。

| Fork | Upstream | Change | Scope |
| --- | --- | --- | --- |
| beda037 | 17a7ddb | Shield: hide Reddit's promoted posts on reddit.com | 2 files |
| 0094966 | 8ae9bb6 | Inline predictions follow Search's own switch, off unless turned on (idea 842) | 7 files |
| a191397 | 07b9476 | Security keys work with Offer passkeys off (idea 846) | 4 files |
| 49f7fcb | bbba41c | The rows kept for a swipe between spaces are hidden at rest, not only moved aside (idea 847) | 3 files |
| f425ade | cf2d210 | YouTube's first video starts at once on a return visit with its pre-roll taken out (idea 852) | 3 files |
| 780c9f2 | 738db1e | A probe: what a site keeps survives ⌘Q and a relaunch, in an identifier store and the default one (idea 838) | 1 file |
| 76a9d37 | 8669621 | A probe: a click, or a key the page takes, counts as using the site for tracking prevention (idea 838) | 1 file |
| eb12909 | 32f7482 | Settings: say what Prevent cross-site tracking can cost a site reached from trackers (idea 838) | 1 file |
| 5bbbb22 | 675e95e | Extensions: chrome.i18n functions work called loose, so Monarch Money's options text shows (idea 812) | 2 files |
| 5ce503b | 1efc952 | Full screen: the top bars move down with the menu bar's reveal instead of lying under it (idea 854) | 5 files |
| d6764f0 | c722e6d | The window moves from above the tabs across the top (#1321) | 1 file |
| efa1380 | 4ef2a06 | A download into a folder Search can't write to asks where to save it (#1291) | 2 files |
| a168ed6 | 5afb34c | Extensions: bookmarks.get answers like Chrome, so Floccus can sync bookmarks (#1312) | 1 file |
| b250545 | 81db36f | fix(passkeys): allow sign-in from Peek and small windows (#1273) | 2 files |
| 1887796 | eb07238 | An extension worker's plain fetch to a granted site carries its cookies (#1331) | 3 files |
| 0bda575 | e9f7e6f | Similarweb's button opens its panel: an extension's page loads in a frame inside an empty frame (#1324) | 2 files |
| 237d6b0 | 5d309e4 | Keep a sleeping tab's sessionStorage (#1303) | 2 files |
| 7d186d9 | 6b33518 | An extension's popup opens from the first button at the column's foot again (#1323) | 2 files |
| c8462f1 | 294d6ed | YouTube's blocker tests pass, so its wall stays down (#1320) (#1327) | 2 files |
| d1fd303 | a1953c3 | Try HTTPS first for http:// pages (#1302) | 6 files |
| e708ec4 | fad2939 | Hide Elements hides on sites whose CSP limits styles (#1270) | 2 files |
| 68c86ab | 3782008 | Tests: above a tab across the top the window is movable (#1321) | 1 file |
| b4abd48 | 86e28d6 | Answer a site's request for a client certificate with one you choose (idea 536) | 8 files |
| 49f7d4f | ae6817f | The extensions button sits centred at the column's foot (#1281) | 2 files |
| 45f7441 | 17fe62e | A title bar double-click no longer bounces back to the old size (#1338) | 3 files |
| 4386e77 | 69c1b23 | Swipe back closes a tab a link opened, off unless turned on (#1337, idea 565) | 6 files |
| 40bb8fa | 292dbbf | A blank tab can show the Home bookmark folder as a grid, off unless turned on (#1316) | 8 files |
| 609b60e | 9d9eb3b | ⌘T finds your open tabs as you type, off unless turned on (#1288) | 8 files |
| dae797b | e1dcac2 | Several tabs picked: their menu acts on all of them (#1287) | 3 files |
| 2f3ae44 | 3df5362 | Pin a split as a split (#1286) | 11 files |
| 618af54 | 6e71d50 | One button per space beside the bookmarks, off unless turned on; a space's colour from the click (#1339) | 8 files |
| efce63a | 5b89262 | Spaces: any space can be deleted, the first included (#1326) | 8 files |
| b420ba0 | e5620f4 | Spaces turned on: no nameless card from a stroke with one space; a lone Arc space names it | 3 files |
| 401dd84 | f074c8d | Import: Arc's spaces replace an untouched first space instead of sitting beside it | 3 files |
| e24a4ed | 719f3a7 | Profiles: any order, moved with Move Left / Move Right across profiles | 3 files |
| cb0fa0d | da56032 | History: copy the pre-1.0.16 history once into each signed-out space (#1325) | 4 files |
| 6d2dbca | ec16f2a | ⌘O keeps a peek as a tab (#1340) | 3 files |
| 18e3469 | 8ccd05f | Settings: say what Tabs show chooses (#1276) | 1 file |
| 7d8e305 | e5483cc | Welcome: the pictures show what tabs wear (#1275) | 1 file |
| 4719c7a | df7eecb | Remove 28 declarations nothing refers to (#1280) | 15 files |
| be78e19 | 4295581 | Themes: an optional background for the blank tab, off unless chosen (#1318) | 12 files |
| 2e7d5f3 | 6f8a772 | Games can lock the pointer: the front tab, after a click, Esc gives it back (#1305) | 6 files |
| b0ea62d | 20d4e04 | Extension popups: classic scroll bars no longer add 17 points each way (#1311) | 2 files |
| 2b3e5c8 | fa3e432 | The site card hangs from its tab after a double-click (#1310) | 5 files |
| 90197d5 | d92086a | The bookmarks list is as tall as the rows it shows (#1309) | 3 files |
| 01f7b8f | 6f58803 | The last tab across the top is never cut off (#1295) | 5 files |
| e4fb5d3 | 6658f81 | A bookmarks folder of thousands opens at once: rows built as they show (#1306) | 3 files |
| 42018e2 | e818a00 | Tests: the Arc import test expects an untouched home replaced, and puts it back | 1 file |
| 3f85af3 | fd21c5c | Full screen reveal: the inset is set only when it moves | 1 file |
| 325d1b8 | 576a7fc | Bench: marks reads the Bookmarks menu as the menu bar in use would | 1 file |
| 325e3a8 | a986976 | A right-click on a tab group's name lands on the group, not on the popover's measuring view | 1 file |
| 3792ba7 | 6635c58 | Floating Downloads: shadow not clipped beside the column, one smooth height animation (idea 897) | 2 files |
| 8f0483e | 660e12f | Tests: space_roomy films the column in the light look | 1 file |
| b5fcabf | e045344 | Tests: local_paths keeps its files under the home folder | 1 file |
| e40a20e | a504a1d | Tests: settings_layout expects the Themes section (#1318) | 1 file |
| 418fe18 | ca659da | Tests: peek_stays expects a page kept beside to join the split it came from | 1 file |
| c15c5f4 | a60eb22 | Escape answers a website pop-up's camera question again | 1 file |
| f10c250 | 84110b7 | Tests: run-ci-tests isolates however many download cases there are | 1 file |
| 541c491 | 9173652 | Tests: link_menu and split_selected expect splits of up to four pages | 2 files |
| b1b03ce | 9577bc7 | Tests: little_switcher turns the switcher's keys off to test them off | 1 file |
| cdc52b6 | 7a66a39 | Tests: pin_tiers expects Clear to leave an empty tab in a group alone | 1 file |
| 6ec288e | 02cebc5 | Tests: the passkeys-off probes follow the kind of build they run | 2 files |
| bc393b1 | 1121e21 | ⇧⌘T puts a split's page back with its history | 1 file |
| a42e826 | 1f21a1c | Float a YouTube Music song as its cover, not the player's buttons | 2 files |
| fcdfcb1 | a6cac52 | ⌘S: the page keeps its own background while the column slides (idea 847) | 5 files |
| e30cc1a | c48f067 | Tests: little_window defines editor_ready where the last check needs it | 1 file |

## 冲突与语义适配

- **TabBar**：`TabMenu.body` 采用上游 `isPickedAmongOthers` 的 manyMenu/singleMenu 分流；singleMenu 的固定区接上游 `pinnableSplit` 分支，并重套 fork 的 `ui.pin_split_view`、`ui.pin`、`ui.pin_as_row` 键；共享固定项沿用上游 `pinnedPair(of:) == nil` 条件。`measures(...)` 保留 fork 的复杂签名与实现（含 `pinLine`），返回结构补上 `unaccounted`；`onGeometryChange` 里上游的 `content(in:each:)` 在 fork 不存在，改为 `measures(...).content - unaccounted` 计算 `worked`，并保留 #1295 的取整注释。
- **多选标签页菜单（manyMenu）**：按上游结构重写按钮动作（成批 pin/unpin/mute/sleep/close），文案全部改为 `CountText` 复数键与 `ui.*` 键；复用已有的 `count.open_split`、`count.close_tabs`，新增 `count.pin_tabs`、`count.pin_tabs_as_rows`、`count.unpin_tabs`、`count.mute_tabs`、`count.unmute_tabs`、`count.put_tabs_to_sleep`。
- **Spaces**：空间按钮公告采用上游 `showsSpaceButtons`/`SpaceButtons.count` 条件，并接 fork 的 `announce(name, localized:)`；删除空间用 `Spaces.ownsStore` 区分自有与共享存储，新增 `space.delete_detail_shared` 键；删除 Profile 块的三条文案改走 `profile.delete`、`profile.delete_confirm`、`profile.delete_last_space_detail`（与已有的 `profile.delete_detail` 区分：后者用于不需要“最后一个空间”说明的删除入口）。Move Left/Right 采用上游 `profileBeyond` 结构 + fork `localizedItem`。
- **App**：Spelling and Grammar 菜单合并后保留 fork 的 `ui.spelling_and_automatically`，并新增 `Toggle` 绑定 `prefs.inlinePredictions`（键 `ui.show_inline_predictions`）。
- **Welcome / WhatsNew**：Welcome 保留 fork 的 `welcome.layout.*` 图示键，补 `welcome.key.theme`；WhatsNew 新增 `swipe_back_closes` 开关，标题/说明在 `Localizable.strings` 中与英文原文逐字一致。
- **ExtensionPopup**：采用上游两遍 `const lay` 测量与 `Math.min(600, ...)` 高度上限，保留 fork 测试中 `overflow:hidden` + flex 的延迟内容用例。
- **Bench**：保留 fork 的 `menu(_:)` helper，加入上游 `dropdownHeld`；菜单匹配改为 `Language.matches($0.title, english: "Bookmarks")`。
- **Profiles**：保留 fork 的 `language` 观察对象，采用上游 `width: 26`。
- **Bookmarks**：采用上游 `row(_ line: Shown, arrows:folders:)`，删除 fork 旧 `rows` 函数；Move to 菜单用 `moveTargets()` 闭包。
- **run-ci-tests**：采用 fork 已有的 `isolated_suites` 泛化版本（上游“任意数量下载用例”的改动已被覆盖）。
- **构建修正**：冲突合并时 `Spaces.swift`、`TabBar.swift` 各多出一个右括号，已修正；`TabBar` 中上游 `content` 变量在 fork 不存在的作用域，按 `measures` 结果计算。

## 规格复核

按 AGENTS.md，同步时逐项复核 `docs/specs/` 下的既有规格：

- `tab-bar-grouping-performance.md`：`TabBar.measures` 保留 fork 的签名与实现，上游 #1295 的取整逻辑仍在；多选菜单的文案改动不影响分组与测量，`SpeedBenchTests` 在完整套件中运行。
- `interface-localization-upstream.md`：语言切换、资源包与翻译均按本轮“本地化收尾”逐项处理；`LanguageTests`（含设置目录逐条校验）通过。
- `extension-performance-upstream.md`：本批扩展改动（`chrome.i18n` 松散调用、`bookmarks.get`、worker fetch 带 Cookie、sleeping tab 的 sessionStorage）不触及 CRX3 校验、shim 生成与外发消息的核心路径，扩展测试由完整套件覆盖。
- `extension-popup-motion-upstream.md`：#1311（经典滚动条不再各加 17pt）与 #1324（空 frame 内的扩展页）按上游实现合入，`ExtensionPopup*` 测试由完整套件覆盖。
- `window-drag-tiling-upstream.md`：#1321（tabs across the top 之上可移动窗口）与 #1338（标题栏双击不再弹回旧尺寸）按上游实现合入，`WindowDragTests`、`OneWindow*` 等由完整套件覆盖。
- `local-cdn-upstream.md`：本批没有触及内置 CDN 替换的改动。

## 本地化收尾

- 新增 85 个字符串键、6 个复数键：en 与 zh-Hans 均从 2525 增至 2610 条字符串，复数表从 35 增至 41 条；四个资源文件 `plutil -lint` 通过，`python3 Tests/check-localization.py` 通过（参数占位一致）。
- 上游新增界面文件的结构化本地化：
  - `HomeTheme.swift`：`Family`、`HomeTheme`、`StickerPack`、`GradientPreset` 的 `title` 改为 `@MainActor` 并用 `Language.shared.text`（`themes.family.*`、`themes.wall.*`、`themes.pack.*`、`themes.gradient.*`），`NSOpenPanel.prompt` 复用 `ui.choose`。
  - `ThemesPage.swift`：家族选择、关闭说明、Shuffle、预览占位（复用 `address_line.placeholder`）、色板旁白、ColorPicker 的 Colour/From/To、Angle/Intensity/Density/Scale、Choose Image…/Remove、副本说明全部键化；新增 `language` 观察对象，切换语言即时刷新非 `Text` 来源的标题。
  - `PointerLock.swift`：提示胶囊拆为 `pointer_lock.press` / `pointer_lock.to_show`，VoiceOver 整句用 `pointer_lock.words`；`words` 改为 `@MainActor` 计算属性。
  - `ClientCertificates.swift`：`NSAlert` 标题/说明与按钮（复用 `Continue`/`Cancel`）、证书标签的“签发者/到期”、无名证书兜底（`client_cert.certificate`）全部键化；`matching` 标记 `@MainActor` 以读取语言。
  - `Browser.swift`：标签页移入空间后的 VoiceOver 公告改用 `announcement.moved_tabs`（`%1$ld`、`%2$@`）。
- 既有英文文案随上游更新：`settings.glyph.detail` 改为 “A letter or the site's icon”，旧文案移入新增的 `settings.glyph.more`；`settings.sites.keep.more` 补上 “On, as in Safari…” 首句（中文同步更新）。
- 新增 8 个设置条目的 title/detail/more 与 `settings.page.themes`、`settings.group.themes`，`LanguageTests.testSettingsCatalogHasTranslationsForItsDisplayedText` 逐项校验英文与中文资源存在且英文与目录文本一致。

## 验证

环境：macOS 27.2.1（Darwin 27.2.0）、Apple Silicon、Xcode 27.2 / Swift 6.4.2，`swift build` Debug。

- `swift build`：`ok (build complete)`，仅既有 `WKProcessPool` 弃用警告。
- `python3 Tests/check-localization.py`：通过（2610 strings / 41 plurals）。
- `plutil -lint`：en/zh 的 `.strings` 与 `.stringsdict` 均 OK。
- 针对性测试：`LanguageTests|SettingsIndexTests|HomeGridTests|PointerLockTests|SwipeBackClosesTests|ProfilesTests|PinSplitTests` 共 54 项通过；补 `client_cert.certificate` 后 `LanguageTests|ProfilesTests|PointerLockTests` 31 项再次通过；完整 CI 首轮后，`DownloadsOpeningTests|ExtensionPopupMotionTests|ExtensionPopupSizingTests` 20 项通过。
- 完整 `python3 Tests/run-ci-tests.py`：见下节“完整测试”。

## 完整测试

- 第一轮（2026-11-22 14:30–14:54）：本地化检查通过；主套件失败 4 项，均由这台 Mac 的环境或 #1311 的新语义引起，不是合并逻辑错误：
  - `DownloadsOpeningTests.testTheWindowResizesInSmallSteps`：这台 Mac 开启“减弱动态效果”，`Motion.reduced` 按设计让 `DownloadsFloat.move` 立即完成，帧数自然不足。测试内固定 `Motion.testReduceMotion = false`，结束恢复 nil。
  - `ExtensionPopupSizingTests.testBodyMarginDoesNotCauseScrollbarOscillation`：断言仍是 #1311 之前的 515×315（经典滚动条 17pt 留白）；#1311 后稳定为 500×300，已更新。
  - `ExtensionPopupMotionTests` 亮/暗两项：`overflow.html` 在 #1311 后先以声明的 500×300 打开，再于前 8 次跟踪内按内容长到 310；原断言要求 2.8 秒内尺寸完全不变。改为宽度不横跳、高度不回缩（仍能捕获修复前的 500↔515 回抖）。
- 第二轮（2026-11-22 14:57–15:21）：本地化检查通过（2610 strings / 41 plurals）；主套件 1262 项、27 项跳过、0 失败；43 个隔离用例全部通过；退出码 0。

## 未验收项

- macOS 14 实际启动与运行（构建目标为 14，但仅在 macOS 27.2.1 验证）。
- 真实物理鼠标/触控板的拖拽与系统平铺、真实 Fn/Control 快捷键、第三方窗口管理器。
- 触控板轻扫（swipe back closes）、真实指针锁定（游戏）、真实客户端证书站点：分别依赖触控板手势、WebKit pointer lock 授权与钥匙串中的真实身份，仅由探针与合成用例覆盖。
- 输入法与 VoiceOver 下新 Themes 页面、证书选择器与指针锁定提示的实际朗读顺序。
- 浅色/深色下 10 幅壁画、贴纸包与渐变的实机视觉检查。
- GitHub CI：本 worktree 尚未 push，远端结果未产生。
