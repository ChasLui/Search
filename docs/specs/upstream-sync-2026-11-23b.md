# 2026-11-23 上游同步（第二轮，7 个提交）

PR #17 合并后（`chaslui-dev` 为 `b566a67`），上游 `main` 又从 `6f2b186`
前进到 `f9d7a74`。本次把这 7 个提交逐个 cherry-pick 到
`upstream-sync-2026-11-23b`，冲突按 fork 的架构与国际化实现解决。

- 上游基线：`6f2b186`（上一轮同步的上游目标）
- 上游目标：`f9d7a74`（`chrome.i18n.getMessage("") answers ""…`）
- fork 基线：`b566a67`（PR #17 合并后的 `chaslui-dev`）
- fork `main` 已与 `upstream/main` 同为 `f9d7a74`

## 提交

1. `9336a8e` Search › What's New…、自绘 About 窗口；iPhone beta 候补名单出现在
   About、Help 和空白标签页（IPhoneAsk）。
2. `42ca1b9` iPhone beta 提示只在真正要过 beta（或按 Not now）后隐藏。
3. `2b44d44` 活动文件夹里的帖子在标签页之间打开，不进入前台标签页的分组。
4. `20942bc` 扩展弹窗里 `target=_blank` 的链接在新标签页打开。
5. `3440888` Readwise Highlighter 的后台 worker 重新启动（`window` 只在脚本
   提到 `getBackgroundPage` 时给出）。
6. `c2c6d92` Set Up Like Arc 增加四项 Arc 习惯，并出现在欢迎页与 Arc 导入之后
   （共享 `LikeArc` 与撤销）。
7. `f9d7a74` `chrome.i18n.getMessage("")` 返回空串，uBlock Origin 的弹窗与
   仪表盘按钮恢复。

## 冲突与适配

### `9336a8e`（About、What's New、iPhone 候补）

- `App.swift` 的 Help 菜单：保留 fork 的 `language.text("ui.send_feedback")`，
  新增的 `Search for iPhone…` 用 `iphoneask.menu_title` 本地化。
- Search 菜单的两项改用 `language.text`：`About Search`（新增英文键资源）与
  `What's New…`（复用既有资源）。
- `About.swift`：What's New 按钮复用 `page.release-notes`；版本行改为
  `about.version` / `about.version_build`，视图观察 `Language.shared`。
- `IPhoneAsk.swift`：`pitch`、`short`、`action`、`not_now`、`card_title`、
  `menu_title` 全部走语言资源；About 卡片标题改为传本地化字符串（`Plate` 的
  非本地化标题按原文显示）。`OptInForm` 的按钮复用既有 `Join` 资源。

### `3440888`（Readwise worker）

- fork 把扫描的脚本内容变量命名为 `source`（上游为 `text`）并保留
  `scripts`/`folderPathLength`。合并时保留 fork 命名，在其后加入
  `namesWindow` 判定（跳过 `contentFile`），占位符替换按上游落地。

### `c2c6d92`（Set Up Like Arc）

- 接受上游的共享 `LikeArc`（设置、欢迎页、Arc 导入后的入口共用一份 Undo），
  删除 fork 原先的 `arcBefore`/`SettingsPanel.arcBefore`。
- 保留 fork 的本地化公告：`LikeArc.said(_:)` 内部用 `Language.shared` 处理
  `Already set up like Arc`、`announcement.turned_on` 与每个变更项；设置页直接
  调用 `browser.announce(LikeArc.said(changed))`。
- `ImportPanel` 保留 fork 的 `Said`/`.arc(...)` 结果文案，仅采纳上游的
  `arcLanded` 状态。
- 欢迎页与导入后的 Arc 入口文案走新资源 `welcome.arc.*`、`import.arc_offer`；
  `Set Up Like Arc` 按钮复用 `settings.arc.setup.title`。

## 国际化

`python3 Tests/check-localization.py` 与 `--base b566a67` 复核：

- `Localizable.strings` 由 2736 条增至 2753 条（17 条新增，en/zh 对齐），
  41 个复数键不变。新增：About 版本行、iPhone 候补（menu/card/pitch/short/
  action/not now）、欢迎页与导入的 Arc 入口、`Set Up Like Arc` 的四个新变更项
  （`tabs close after 12 hours` 等）。
- 更新 `settings.arc.setup.detail`/`more` 的英文与中文，描述新增的四项习惯。
- 交互文案（按钮、公告、菜单）均保留英文键或语义键；英文句子资源与源码逐字一致。

## 验证

本机 macOS 27.2 / Xcode 27.2 / Swift 6.4.2。

- `swift build`：通过。
- `python3 Tests/check-localization.py`：通过（2753 条、41 个复数键）。
- `plutil -lint`：en/zh 均 OK。
- 定向运行：`LanguageTests` 19/19、`IPhoneAskTests` 4/4、`OptInTests` 16/16、
  `LikeArcTests` 3/3、`SettingsIndexTests` 8/8 通过。
- 完整 `python3 Tests/run-ci-tests.py`：通过（exit 0）；本地化检查 2753 条、
  41 个复数键；主套件 1382 个用例、30 个跳过、0 失败；五个隔离套件逐进程运行
  全部通过。

## 未完成 / 待复核

- GitHub Actions 结果。
- 上游新增探针（`Tests/iphone_ask.py`、`Tests/live_folder_post_place.py`、
  `Tests/extension_popup_link.py`、`Tests/extension_i18n_empty.py`）未在本机执行。
- 双语言切换、浅深色、双窗口、macOS 14、真实输入法和 VoiceOver 的人工复核。
- 本轮 PR 尚未合并。
