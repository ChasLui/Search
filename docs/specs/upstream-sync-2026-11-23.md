# 2026-11-23 上游同步记录

本次同步把上游 `driceroland/Search:main` 新增的 100 个提交迁移到 fork 的
`chaslui-dev`（本次工作分支 `venomous-kolibri`），逐提交 cherry-pick，冲突按
fork 的架构与国际化实现解决。

- 上游基线：`7c1c0ec`（上一轮同步后的上游 main）
- 上游目标：`6f2b186`（`Sleeping pins no longer open blank ...`）
- fork 同步前提交：`e11d739`（PR #16 合并后的 `chaslui-dev`）
- 本轮 100 个提交（`git rev-list --count 7c1c0ec..upstream/main`）

## 迁移方式

`git rev-list --reverse 7c1c0ec..upstream/main` 后逐个 `git cherry-pick -x`。
每个提交保持上游作者与提交信息；发生冲突时按 fork 的结构解决再继续，不使用
upstream 的文件整体覆盖。

- 全部 100 个提交均已落地；其中 `5eab022`（What's New 只留一个 swipe-back 开关）
  解决后为空提交（fork 此前已经用 keyed 开关实现同一内容），以
  `git cherry-pick --skip` 跳过，效果已存在。
- `4fd56b6`（撤回 ⌘S 页面跟随滑动）随后完整落地，包含删除
  `Tests/fold_follow.py` 等；fork 原有的 FollowFile 测试在构建中仍通过。

## 冲突与适配

### 横向标签栏与分组色带

- `1f747c9`、`7586f94`：上游给展开的分组画一条色带（`GroupBand`），并给色带后
  留 10 点空气。fork 的横向栏按 `Browser.GroupedTabRow`、`SplitItems` 和
  `rowItem(tab, splits:activeID:)` 组织，保留这套结构：
  - 遍历仍用 `grouped.groups`，成员为 `group.tabs`，额外计算
    `banded`、`spaced`（`GroupBand.spaced(grouped.groups.map(\.group), ...)`）。
  - `topTab` 增加 `band:`/`last:`，保留 `splits:`，色带背景叠加在 Carried 之后。
  - 色带空气并入 fork 的 `measures(...)`（上游的 `content(in:)`/`width(in:)` 在
    fork 中已由 `Measures` 取代），`fixed` 加 `bandAir`。
  - 折叠分组的绘制不变；`GroupBand.Air`/`spaced` 与 bench 的
    `drawnBands`/`drawnItems` 保留。
- `8aab55d`：分组标题菜单新增 `New Tab in Group`，用 `ui.new_tab_in_group` 本地化。
- `9a33d6c`：分组标签的关闭按钮在顶部栏改为一枚减号（Put Away），文案已有资源。

### 标签栏与标签宽度

- `5cc68f6`：标题只剩「…」时只画图标。fork 用 `tab.displayLabel`，合并时保留它并
  追加 `record: tab.id`；阈值计算（`Metrics.tabFixed`/`tabTitleRoom`）原样应用。
- `f09b123`：点按当前标签页只编辑地址。fork 菜单用的是
  `Text("ui.site_information")` 标签形式，保留它并调用
  `beginTabEdit(tab, card: true)`。
- `1f747c9` 同时让分组标题菜单的 Colour… 在顶部栏也出现，fork 保留本地化按钮并去掉
  `if showsColour`。

### What's New 与欢迎页

- `b7a0690`（1.0.17）、`394d855`（1.0.18）新增开关与发布说明；fork 的开关均为
  keyed 形式，新开关补 `key:`：
  `sync_icloud`、`fold_button`、`narrows_to_icons`（1.0.18）以及
  `arc_tab_popup`、`home_grid`、`space_buttons`、`https_first`（1.0.17）。
- `86d05dc`：What's New 增加 leading 开关（Sync with iCloud、Handoff 置顶），并新增
  `rows(for:prefs:)`；卡片把 OptIn 区块钉在滚动区之外。fork 保留本地化的
  `Caption("ui.from_earlier_versions_in_case_you_missed_them")`。
- `de14b04`：OptIn 区块与欢迎页末页引入；卡片结构按上游（外层 `VStack` + 内层
  `ScrollView`），标题/说明走本地化键。
- `5eab022`：见上，空提交跳过。
- `dac42b0`：Apple Passwords 行合并 `.idle, .starting`，fork 的
  `Line(..., localizedTitle:true)`/`Pill("ui.connect")` 与
  `ui.try_again_042c86` 保留，新增 refused 说明键 `ui.macos_stops_apple_helper`。
- `e6b0f74`：站点快捷方式表单示例改为斜体 prompt；`settings.keyword.explain`
  英文同步更新，新增 `ui.word`、`settings.keyword.address_example`。
- `7b625d7`：设置搜索把「Always on」行单列；标题键
  `ui.always_on_nothing_to_set`。
- `9b1810c`：新增 `helm.shown`、`foot.shown` 两行 Ticks；`Ticks` 的标题改为
  `Text(LocalizedStringKey(...), bundle: Language.resources)`。

### 书签栏与设置

- `37ae188`：书签栏可放到侧边栏顶部。上游把右键菜单抽成 `BookmarkActions`；
  fork 接受删除旧的私有菜单函数，并把新的 `BookmarkActions` 全部改为本地化按钮
  （原有 `ui.*` 键）。
- `09d1420`/`d2be947`：溢出书签的 »、文件夹中键全部打开。新增
  `ui.more_bookmarks`、`ui.no_safari_extensions`、`ui.added`、`ui.in_app`，
  `openAll` 保持本地化标签。

### 扩展与证书

- `3d2bbd5`：`cantDo` 拆分出 `wasm(...)`。fork 保留 `localizedCantDo`，
  以 `asksToBlockRequests` 实现 `blocking`，并新增 `localizedWasm` 与资源
  `extension.cant_wasm`。
- `a8099c3`/`0c0e711`：From Safari apps 列表与签名复检。新增
  `announcement.safari_extension_changed`，Line 标题/说明走
  `settings.extensions.safariApps.title` 与 `extensions.safari_apps_detail`。
- `70e9c35`：无适配。
- `cc127bc`：Continue Anyway 记录证书哈希。保留 fork 的 `@MainActor` alert，
  采用 `excuse(host, trust)`。

### 其他小适配

- `b6d647a`：Paste and Match Style 菜单本地化（英文键，与 Settings › Shortcuts
  的命令标题一致）。
- `99bb38a` / `2b2a752` / `ab9ee07`：浮动视频逻辑无冲突。
- `4f3a003`、`9bd3214` 等无冲突。
- `0c0e711`/`e0f22c8`/`c56b140` 新增设置项与分组 `news`，全部补 en/zh 资源。

## 国际化

运行 `python3 Tests/check-localization.py` 与 `--base e11d739` 复核后：

- 新增 126 条 en/zh 资源（`Localizable.strings` 由 2610 条增至 2736 条），包括：
  - 7 个新设置项（`helm.shown`、`foot.shown`、`bookmarks.side`、`field.window`、
    `wheel.smooth`、`news.updates`、`news.iphone`）、`settings.group.news`、
    `settings.extensions.safariApps`、`settings.fold.loadingLine`、
    `settings.tabs.clickAddressOnly`、`settings.sidebar.foldButton/narrowIcons`；
  - 1.0.17/1.0.18 的 What's New 开关与发布说明；
  - 欢迎页 Sync/Handoff 开关、OptIn 全部文案、Safari apps 列表、菜单项与
    announcements；
  - `settings.icloud.more` 的英文变更与中文同步更新；标签重命名表单的说明
    `Without a name, the tab shows its page's title.`。
- 枚举器、嵌套设置说明与新增命令（Next Space、Previous Space、Open File…、
  Paste and Match Style、Open Image in Split View、Open Link in Private Tab）
  都有对应资源。
- `WhatsNew.swift` 的 1.0.18 fixed.3 把 `\u{2026}` 写成实际省略号，便于
  `check-localization.py` 比对。

## 验证

本机 macOS 27.2 / Xcode 27.2 / Swift 6.4.2。

- `swift build`：通过。
- `python3 Tests/check-localization.py`：通过（2736 条字符串、41 个复数键）。
- `plutil -lint`：en/zh `Localizable.strings` 均 OK。
- `swift test --filter LanguageTests`：19/19 通过。
- 新增套件定向运行：OptInTests、CertificateExceptionTests、SyncDefaultTests、
  SideBookmarksTests、ExtensionLimitsTests 通过；`ApplePasswordsRowTests` 的
  `testOverAPipeAProgramKilledAtLaunchIsRefusedQuietly` 在本机稳定失败：
  `HostPipe.exitGrace` 取 1.5 秒、而拒绝判定窗口是 1 秒，本机子进程启动 + EOF
  通知超过 1 秒，于是短暂显示「Connecting…」并以 `.gone` 文案收尾。上游实现与
  测试与 `upstream/main` 完全一致，本机差异属于时序环境问题，待 GitHub Actions
  （macos-26）复核。
- 完整 `python3 Tests/run-ci-tests.py`：运行中，结果见文末更新。

## 未完成 / 待复核

- GitHub Actions 全部通过与否（tests、beta-dmg）。
- 本机 `ApplePasswordsRowTests` 的启动时序失败在 CI 上的结果。
- 双语言切换、浅深色、双窗口、macOS 14、真实输入法和 VoiceOver 的人工复核。
- 横向标签栏色带与设置搜索的视觉检查（`Tests/group_band.py`、`Tests/settings_layout.py`
  等 probe 需要构建 app 与独立 profile）。
- 本轮 PR 尚未合并；`ChasLui/Search:main` 仍镜像上游 `main`。
