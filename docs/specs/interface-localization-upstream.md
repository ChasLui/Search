# Search 界面国际化与上游同步规格

本规格供 fork 同步上游时使用：先判断上游是否已经提供等价能力，再保留或迁移这里的
行为、兼容性和验证。它记录的是约束和可复现的检查，不表示当前实现已经完成发布验收。
标签栏布局的独立约束见[横向标签栏性能规格](tab-bar-grouping-performance.md)。

2026 年 11 月 19 日的实现以 `8c22db7` 为起点，国际化代码提交为 `7947dbe`；
整合 `chaslui-dev` 的 `1fb5236` 后，验证的代码提交为 `8d4eea4`。具体测试结果、
环境和未完成项见[验收记录](../../Tests/I18N_VALIDATION.md)。后续同步应重新核对
实际提交和当前实现，而不是把这些历史提交或测试结果当作最新状态。

## 应保留的行为

- 界面语言保存在 `Store.settings` 的 `ui.language`，值为 `system`、`en` 或
  `zh-Hans`。默认跟随系统偏好，找不到支持的语言时回退英文。文字和复数规则由有效
  语言决定，地区沿用用户的 macOS 设置；网页翻译目标 `translate.target` 与之独立。
- 在设置中切换后，所有打开的 Search 窗口及菜单应立即更新。浏览器、标签和现有
  `WKWebView` 必须保持原实例；表单、输入焦点、滚动、分屏和设置页位置应保留，
  休眠标签不应因切换而唤醒。不要用随语言变化的 SwiftUI 根视图 `.id` 重建现场。
- 翻译 Search 自有文字，包括设置项的标题、简短说明和展开说明、错误和权限说明、
  菜单及 VoiceOver 标签。网页标题、用户命名、网址和扩展提供的文字按原值显示。
  系统文件选择器、权限弹窗的系统按钮和 WebKit 自带菜单遵循系统语言机制。
- 设置搜索以当前展示的译文为依据，同时保留英文名称、已有关键词和设置键。语言变化
  后按需重建索引；例如中文的「下载」和英文的 `Downloads` 都能找到相应设置。
- 地址栏命令开关默认关闭。中文界面开启后，中英文别名复用相同命令 ID、可用性判断
  和快捷键；只有完整别名触发命令，「设置路由器」仍是搜索。输入法有 marked text
  时，Return 和方向键交给输入法处理。
- `search://` 路由、偏好键、快捷键 ID、会话格式和 bench 协议保持兼容。默认标签
  标题在显示时本地化；用户名称和旧会话数据不因语言切换被改写。人可读的无障碍标签
  可翻译，自动化应使用稳定标识。

## 当前实现的接入点

| 位置 | 同步时应检查的责任 |
| --- | --- |
| [Language.swift](../../Sources/Search/Language.swift) | 共享语言状态、系统语言解析、有效语言变化时切换 bundle，以及 SwiftUI 的 `LanguageRoot` 和复数文本。 |
| [App.swift](../../Sources/Search/App.swift)、[Windows.swift](../../Sources/Search/Windows.swift) | 主 Scene、菜单命令和独立 `NSHostingView` 获得同一语言环境；新弹窗或悬浮视图也要检查。 |
| [WindowTitle.swift](../../Sources/Search/WindowTitle.swift)、[Tab.swift](../../Sources/Search/Tab.swift) | Search 自有标题按当前语言显示，网页和用户名称保持原样。 |
| [SettingsIndex.swift](../../Sources/Search/SettingsIndex.swift)、[Settings.swift](../../Sources/Search/Settings.swift) | 设置分组、标题、`detail`、`more`、搜索词及语言选择使用一致的资源。 |
| [AddressCommands.swift](../../Sources/Search/AddressCommands.swift)、[Omnibox.swift](../../Sources/Search/Omnibox.swift) | 中英文命令别名、完整匹配和输入法组字行为。 |
| [Browser.swift](../../Sources/Search/Browser.swift) | `announcement` 保留原有英文诊断／bench 文本；`displayedAnnouncement` 供界面随语言生成文字。 |
| [Resources](../../Sources/Search/Resources)、[Package.swift](../../Package.swift)、[build.sh](../../build.sh) | SwiftPM 与 app 使用同一份 `en.lproj`／`zh-Hans.lproj`；app 签名前放入资源，开发版名称与权限用途说明一起保留。 |

当前使用 Apple 原生 `.strings`、`.stringsdict` 和 `InfoPlist.strings`，不引入第三方
依赖。数量、日期、站点名等组成的句子应作为完整消息本地化，允许译文调整参数顺序；
不要将英文片段简单拼接后翻译。菜单或 AppKit 自有控件应在语言变化时刷新，按需创建
的菜单在展开时取得当前文字。

## 每次同步上游时

1. 在应用上游变更前记录 fork 当前提交，例如
   `pre_sync_fork="$(git rev-parse HEAD)"`，同时记录原上游基线和目标上游提交。
   对比三者的变更，重点检查上表中的接入点和上游新加的界面。
2. 应用并解决上游变更后，运行：

   ```sh
   python3 Tests/check-localization.py --base "$pre_sync_fork"
   ```

   `--base` 将指定提交与当前工作树比较。选择同步前的 fork 提交，可以比较其中已有的
   两套资源；如果指定提交没有资源文件，脚本会跳过相应的旧资源对比。列出的新增
   界面文字和英文变动需要人工复核；扫描是启发式的，不证明没有遗漏，也不会代替翻译。
3. 为新增内容添加稳定的语义键，并更新两种语言的完整句子、占位符及复数规则。英文
   原文变化时检查中文语义，即使键未变也不要只看双语键是否相同。逐项检查设置标题、
   简短说明和展开说明；「显示搜索建议」曾出现标题已翻译而下方说明遗漏的情况。
4. 审核用户可见文字和诊断／自动化数据的边界，尤其是默认标签标题、通知、菜单项、
   权限说明和扩展文字。新增窗口、独立 hosting view 或原生控件时检查语言环境是否
   到达，且切换语言不会替换 `Browser`、`Tab` 或 `WKWebView`。
5. 如上游引入新的国际化实现，先按本规格验证其语言切换、兼容性、资源和性能；等价
   时优先整合上游方案，避免长期维护两套机制。保留或迁移相关测试，记录取舍。

## 验证方法

使用隔离的构建与测试 profile，记录被测提交、macOS／Xcode 版本、架构、构建参数、
profile、场景和结果。`build.sh` 会写入构建目录中的 app；如果那里有正在使用的实例，
应使用独立构建目录，避免覆盖它。

先运行资源和针对性测试：

```sh
swift build
swift test --filter 'LanguageTests|SettingsIndexTests|AddressCommandTests'
python3 Tests/check-localization.py --base "$pre_sync_fork"
plutil -lint Sources/Search/Resources/{en,zh-Hans}.lproj/{InfoPlist.strings,Localizable.strings,Localizable.stringsdict}
python3 Tests/run-ci-tests.py
```

完整测试未通过时，应记录失败用例及断言，分别对目标基线和候选版本重跑，不因单测
重跑通过就抹掉完整运行的失败。WebKit 下载用例由完整脚本逐个隔离运行；使用
`CI=true` 延长等待复测时，单独记录原始超时和复测结果。

对隔离构建的 app 运行 `Tests/i18n_switch.py`，可用 `SEARCH_BENCH_APP` 指定 app。
脚本使用按 checkout 路径生成的 `i18n-switch-*` 测试 profile，会结束该 profile 的
probe 并清除其测试数据；运行前先确认该 profile 没有需要保留的数据。它在 20／200
标签、双窗口、分屏和休眠标签下比较切换前后的标签 ID、WebView 身份、状态及页面
表单／DOM 焦点／滚动。前后快照不能证明切换过程中新建或唤醒次数为零；该验收还需
事件或计数证据，并补做可见窗口、设置页位置和真实输入法检查。

运行 `SpeedBenchTests`、`Tests/address_at_rest.py` 和 `Tests/bookmark_redraws.py`，
保留现有断言：包括地址栏逐键耗时中位数比较，以及 20／200 标签时每次书签编辑的
侧栏行重建数为零。后两者使用各自的 checkout 专属 probe profile，并会清理该 profile；
先确认其数据和运行实例可清理。按[标签栏性能规格](tab-bar-grouping-performance.md)
复测受影响场景，避免国际化覆盖上游分组优化。

性能对照应在同机、同架构、相同 profile 和负载下使用 release `-Osize`，基线与候选
交错重复运行。记录首窗启动、逐键输入、语言切换到可见界面完成的 p50／p95，以及
可执行文件和 app 体积；先测基线波动，再判断可重复的稳态退化。历史结果不能作为
另一台机器或新提交的通过阈值。

最后检查开发版和 release app 内两套资源、权限用途说明、显示名和签名；在 macOS 14
及当前开发机用独立 profile 验证中英文、浅深色、双窗口、重启后语言选择、真实输入法、
VoiceOver 和旧会话恢复。尚未执行或未通过的场景必须明确记录。

## 本次复盘的未完成项

- 2026 年 11 月 19 日的资源中仍有 804 条使用英文原文作键；这些键并不稳定。迁移为
  语义键并复验前，不能宣称稳定键要求已经完成。
- 历史探针已比较切换前后状态，但没有证明切换过程中新建 WebView 和唤醒休眠标签均
  为零；设置页位置及部分可见界面仍需人工验收。
- 整合后的完整测试未通过；具体失败、单项重跑与性能数据见验收记录。真实输入法、
  VoiceOver、旧会话恢复、macOS 14，以及启动和切换至可见完成的 p50／p95 尚待验证。
