# 窗口拖拽与系统平铺的上游同步规格

同步或回提上游，以及修改窗口、标题栏、标签拖动或系统窗口管理时，先比较上游实现与
本规格，再决定保留、迁移还是替换当前方案。下面的行为是验收目标；文末的历史结果
只对当时的提交和环境有效，不代表当前版本已通过全部实机验收。

## 问题与取舍

Search 将标签放在隐藏标题栏附近。窗口一直设为不可移动时，macOS 的「窗口 →
移动与调整大小」可能变灰，系统平铺快捷键也可能失效：见上游
[issue #286](https://github.com/driceroland/Search/issues/286)。但窗口一直可移动时，
真实鼠标拖动顶部标签可能带走整个窗口。上游
[PR #668](https://github.com/driceroland/Search/pull/668) 记录了原因：WindowServer
对标题栏拖动的判断早于应用收到 mouse-down；只在本地 mouse-down 监控中禁用移动
可能太晚。直接向视图投递事件也无法证明真实 WindowServer 路径正常。

上游 [PR #371](https://github.com/driceroland/Search/pull/371) 曾在处理 Control
快捷键时暂时放开窗口，但系统快捷键可由用户重映射。本机曾配置 `⌥⌘←/→`，仅
处理 Control 会漏掉它。[fork PR #6](https://github.com/ChasLui/Search/pull/6)
补充了 Command、Option、Control 修饰键的处理和未激活窗口的首次按下。回流时应
以行为和真实环境验证为准，不必机械保留某一套实现。

## 应保留的行为

- 在侧栏和顶部标签两种布局中，用户能从空白标题栏或指定拖拽区域移动窗口；未激活
  窗口也应能从首次按下开始拖动。窗口拖动交由系统处理，以支持系统吸附和平铺。
- 顶部标签拖动应移动标签而不带走窗口；侧栏标签拖动、标签关闭按钮、导航按钮、
  红黄绿窗口按钮、网页按钮和网页文字选择应保留原有交互。
- 系统「移动与调整大小」及实际配置的窗口快捷键应能移动或调整窗口；鼠标位于
  拖拽区域内外都要检查。快捷键应继续交给 AppKit，不能影响其他窗口的状态。
- 空标签区域的双击与普通标题栏双击各自保持现有语义：前者可新建标签，后者遵循
  macOS 的标题栏双击设置。一次双击不能被应用和 AppKit 重复执行。
- 多窗口、重叠拖拽区域、窗口视图移除和拖拽结束后，保护状态应按各窗口当前悬停
  情况恢复。任何实现都不能让一个窗口的状态改变另一窗口的标签拖动行为。

## 当前实现的接入点

| 位置 | 同步时应检查的责任 |
| --- | --- |
| [App.swift](../../Sources/Search/App.swift) | `dress` 关闭 `isMovableByWindowBackground`，避免选择网页内容时误拖窗口；初始 `isMovable = true`。 |
| [Stage.swift](../../Sources/Search/Stage.swift) | `DragStrip` 的命中区域、首次按下、悬停计数、快捷键放行、系统拖动交接及双击处理。 |
| [TabBar.swift](../../Sources/Search/TabBar.swift)、[Side.swift](../../Sources/Search/Side.swift) | 顶部和侧栏各自的拖拽空白区与标签、按钮的命中区域。 |
| [Fold.swift](../../Sources/Search/Fold.swift) | 适用布局下页面顶部的拖拽窄条；当前 `Fold.top` 为 8 pt。 |
| [WindowDragTests.swift](../../Tests/SearchTests/WindowDragTests.swift) | AppKit 状态恢复、首次按下、原始事件交接和浏览器快捷键处理链。 |
| [SidebarPressTests.swift](../../Tests/SearchTests/SidebarPressTests.swift)、[ShortcutTests.swift](../../Tests/SearchTests/ShortcutTests.swift) | 标签拖动和输入时方向键行为的回归检查。 |

当前 `DragStrip` 用 `reserved`、`trailing`、`below` 为标签和控件让出命中区域；
使用 `.mouseEnteredAndExited`、`.mouseMoved`、`.activeAlways`、`.inVisibleRect`
跟踪悬停，并按窗口计数，视图移离窗口时释放计数。同步 `2c37a80`（#1257）后，
是否锁住窗口由 `DragStrip.holdsWindow(at:in:)` 按指针位置判断：指针位于标题带内
的标签、按钮等实际控件上时，窗口不可移动，保护顶部标签拖动；空白 strip、红黄
绿窗口按钮和标题栏以下的区域保持可移动，让系统「移动与调整大小」、平铺和窗口
管理器可用（idea 744）。不要把命中测试的保留范围误当成独立的悬停计数。

拖拽达到 3 pt 门槛时，当前实现临时允许移动，并把原始 mouse-down 事件传给
`window.performDrag(with:)`；返回后按悬停计数恢复状态。处理带 Command、Option
或 Control 的 `.keyDown` 时，当前实现也临时允许事件所属窗口移动，在主队列下一轮
按实际悬停状态恢复，并把事件继续交给 AppKit。没有这三种修饰键的自定义窗口
快捷键不在当前处理范围内；第三方窗口管理器需要分别验证。

## 同步或回提前

1. 记录同步前 fork 提交、上游基线和目标提交；逐项对比上表及窗口快捷键的事件
   处理链，确认上游是否已有等价修复，避免叠加两套互相干扰的保护。
2. 检查拖拽区域与标签／按钮的命中范围，窗口初始移动状态、悬停计数的增减和视图
   生命周期，以及 `performDrag` 前后与快捷键处理期间的状态恢复。
3. 对保留或替代方案运行下列针对性测试，并完成适用的实机矩阵。上游方案只有在
   覆盖相同用户行为后才能替代 fork 实现；不等价的项目记录差异和未验收项。
4. 记录被测 commit、macOS／Xcode 版本、架构、构建方式、profile、快捷键绑定，
   每个场景的事件来源和结果。区分真实物理输入、系统菜单、系统级事件、AppKit
   合成事件和直接调用视图；不能用一种证据替代未覆盖的路径。

## 验证方法

先运行构建和针对性测试：

```sh
swift build
swift test --filter WindowDragTests
swift test --filter SidebarPressTests/testPressThenDragStillReordersWithoutEditing
swift test --filter SidebarPressTests/testStripPillPressThenDragStillReorders
swift test --filter ShortcutTests/testReboundArrowsYieldWhileTyping
python3 Tests/run-ci-tests.py
```

`SidebarPressTests` 涉及共享 AppKit 状态，上面两个用例分别使用独立进程；完整测试
按仓库脚本的进程隔离方式运行。失败时记录原始结果并单项复跑，不用单项通过覆盖
完整运行的失败。`WindowDragTests` 的 `DragWindow` 覆写了 `performDrag`，只能
证明调用时可移动、传入的事件和之后的状态，不能证明真实窗口移动或系统吸附。

在安全的隔离 profile 中构建和启动开发包。先确认构建目录、目标 profile 及其中的
运行实例属于本次测试；`fresh.sh` 不带 `again` 会清除所选 profile：

```sh
SEARCH_DEV=1 SEARCH_SIGN_IDENTITY='' ./build.sh debug
SEARCH_PROBE=window-drag-check ./fresh.sh again
```

采用独立测试窗口，读取系统当前实际配置的窗口快捷键；不要假定所有机器都使用
同一组 Fn／Control 绑定。在有权限的真实桌面完成下表，并比较操作前后的窗口位置、
尺寸与菜单可用性：

| 场景 | 要观察的结果 |
| --- | --- |
| 侧栏和顶部标签布局；激活及未激活窗口 | 从空白区、灯区可拖动位置拖动；适用布局再测页面顶部窄条。首次按下即可移动。 |
| 顶部和侧栏标签、网页内容 | 拖动标签时窗口不跟随；关闭／导航按钮、网页按钮和文字选择仍正常。 |
| 指针位于拖拽区域内及外 | 分别触发实际绑定的窗口快捷键；使用系统菜单时记录指针位置和菜单可用性。窗口位置或尺寸应发生预期变化。 |
| 两个窗口与重叠区域 | 一个窗口的悬停、快捷键或关闭不破坏另一个窗口；离开重叠区后状态正确恢复。 |
| 标题栏和空标签区双击 | 分别遵循系统设置和新建标签语义，不发生双重执行。 |

如环境不允许物理输入、某版本 macOS 或第三方窗口管理器实测，应明确记为未验收。
`bench hit` 和合成事件可协助定位命中及 AppKit 状态，不能代替真实鼠标经过
WindowServer 的拖拽，也不能证明系统吸附正常。

## 2026-11-21 上游同步记录

同步 `dbb8345` 的 103 个提交时，上游 `2c37a80`（#1257）已经用更精确的
`aim`/`hold` 取代了 fork 的“进入 strip 即锁窗口”：现在只有指针位于标题带内
的标签/按钮上才锁住窗口。该实现覆盖了 fork PR #6 的目标行为，因此采用上游
实现，保留 fork 的 `_ = Strip.shortcuts` 与 Command/Option/Control 快捷键放行
监控。`WindowDragTests` 原先在窗口左下角进入 strip 并断言锁窗，现改为在标题带
内的点进入，并使用 `fullSizeContentView` 窗口；4 项通过。真实物理鼠标、系统
平铺和第三方窗口管理器仍未在本次同步中实测，见
`docs/specs/upstream-sync-2026-11-21.md` 的未验收项。

## 2026-11-19 修复记录与边界

以下是 [fork PR #6](https://github.com/ChasLui/Search/pull/6) 的历史证据，修复
提交为 `ee3e7f74e6a6b2cbe7ff9c182eaeddc1d96802e0`，合并提交为
`3ac260c3069d466aab64bba82cdeabf96c1cca07`：

- `WindowDragTests` 的 4 项通过；顶部和侧栏标签拖动、输入时方向键相关用例逐项
  独立运行通过。同进程运行曾出现侧栏用例失败，不能将独立复跑等同于同进程通过。
- macOS 27.2.1、Apple Silicon、Xcode 27.2 上，ad-hoc 开发包构建、签名和启动
  通过。系统菜单的「移动与调整大小 → 左侧」实际移动了窗口；定向合成 `⌥⌘←`
  使窗口由 1180×780 变为屏幕左半边 900×1130，当时鼠标在拖拽区域外。悬停时的
  状态与 `ContentView` 处理链由 AppKit 合成测试覆盖。
- 上述修复提交的 GitHub macOS CI `tests` 与 `beta-dmg` 均成功。最后一次快捷键
  调整前，本地完整测试有 7 项失败：1 项 favicon 缓存检查单独复跑通过，6 项 WebKit
  下载生命周期用例超时；代表性的下载暂停用例在 `CI=true` 的 60 秒等待上限下仍
  超时。最后一次调整后未重新运行本地完整套件，远端通过不能抹去这段本地结果。
- 当时未验收真实物理鼠标拖拽、物理 Fn 快捷键、macOS 14 和已安装的 release
  客户端；不带上述三种修饰键的自定义快捷键及第三方窗口管理器也未充分验收。
