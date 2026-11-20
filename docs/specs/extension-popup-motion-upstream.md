# 扩展 popup 回抖与上游同步规格

## 范围与当前状态

本文记录侧栏布局中，由扩展按钮打开的 action popup 的尺寸回抖及本次修复。
它使用 `ExtensionPopup` 托管的 `NSPopover` 和扩展页面 `WKWebView`；扩展的
side panel、网页 popup 以及 `windows.create({type: "popup"})` 是不同路径。
WebKit 扩展入口需要 macOS 15.4 或更新；macOS 14 仍需保持项目的构建兼容性。

2026-11-20 的修复和测试位于提交 `6da10bd` 之上的工作区，编写本文时尚未提交。
下文的自动化结果针对该工作区和记录的环境；不代表其他提交或 macOS 版本已验收。
同步上游或调整弹窗定位、尺寸与动画时，应按行为比较实现，不机械叠加两套修复。

## 问题复盘

popup 首次加载时，页面在隐藏的 25×25 pt WebView 中测量。页面本来能完整放入
最终 popup，但这个临时视口可能出现滚动条；若把其宽高直接计入首次结果，popup
显示后滚动条消失，下一轮测量又会缩小尺寸。固定 500×300 pt 页面的离屏复现中，
原生 popover 的 frame 先由 386×266 pt 增至 543×343 pt，再回缩到 526×326 pt。
这些数字包含 popover 的外框，不是页面内容尺寸，也不是屏幕录制的动画帧。

另一个固定页面将 510×310 pt 内容放在 500×300 pt 的根元素中。滚动条会在
调整尺寸后出现或消失，使 WebView 在 500×300 和 515×315 pt 间反复切换。
仅在显示前复测一次不足以解决这一循环：弹出两秒后的宽度跟踪也必须使用相同的
滚动条判断。body 的边距可能引起类似溢出；反过来，body 自己裁剪或滚动的内容
不能一律当作外层窗口的溢出，否则 popup 会被错误放大。

排查时，原有尺寸测试和多窗口 anchor 测试均通过，但它们没有打开真实 popover
并跟踪尺寸变化。新增的离屏测试在首次修复前捕获了回缩；初版修复后又捕获了
尺寸循环。将固定页面的滚动条临时隐藏后，首次回缩不再出现。测试观察的是
AppKit window／view 的 frame，不能据此断言屏幕上的 Core Animation 逐帧位置
或实际视觉效果。

## 应保留的行为

- 扩展 popup 继续从对应浏览器窗口的按钮或现有 fallback anchor 打开。侧栏、顶部
  标签栏、固定和未固定扩展以及多窗口均不能失去既有定位和关闭行为。
- 首次显示前，使用临时 WebView 视口测量页面，按首次结果调整仍隐藏的 WebView，
  再测一次；这样由临时滚动条造成的尺寸误差不会在页面显示后才被修正。当前
  popover 本身已按缓存尺寸或默认尺寸打开，不能把隐藏 WebView 误记为整个
  popover 隐藏。复测失败，或五秒兜底先于复测完成时，使用首次有效结果显示。
- 测量应保留页面真正需要的滚动条，避免滚动条在尺寸变化时消失又出现。需区分
  根元素／body 的可滚动溢出、body 边距、被裁剪的内容和 body 内部滚动区域；
  不应把内部滚动区域的滚动条再次加到 popup 外层。页面通过样式隐藏滚动条时，
  不能继续加上之前缓存的滚动条宽高。测量时临时修改的页面样式应恢复，页面
  主动设置的滚动行为不能被永久改变。
- 遵循现有内容尺寸边界：宽度 25–800 pt，高度 25–600 pt。页面显示后，前 8 次
  尺寸跟踪触发允许宽高变化，测量失败也计入次数；之后高度只增不减，页面明确
  指定的宽度仍可收缩或增长。计时器间隔为 0.25 秒，两秒只是无延迟时的近似值。
  静态页面不应因滚动条测量在两个尺寸间反复切换。
- 切换或关闭 popup 后，旧 WebView／popover 的异步尺寸回调不能更新当前 popup。
  首次测量请求失败时，不能因合并或去重请求而吞掉已有的后续测量机会。
- 保持 `Motion.instant` 和现有淡入设置的语义，不以关闭全部动画代替尺寸修复。

当前职责分布在 [ExtensionPopup.swift](../../Sources/Search/ExtensionPopup.swift)：
`preferred` 负责计算尺寸，`firstMeasure` 在显示前复测，`grow` 负责后续跟随。
按钮和窗口 anchor 由 [Extensions.swift](../../Sources/Search/Extensions.swift)
提供。上述位置供同步时追踪；上游等价实现可采用不同结构。

## 同步或回提前

1. 记录 fork 基线、目标上游提交和工作区状态，包含未跟踪测试及 fixture；逐项
   比较首次测量、后续尺寸跟踪、滚动条、anchor 和异步回调的行为。
2. 上游已覆盖某项时，保留等价实现并迁移仍有价值的测试；仅部分覆盖时补齐缺项。
   特别检查两秒后的显式宽度跟踪，避免重新引入滚动条尺寸循环。
3. 重新运行下列针对性测试，并执行适用的真实窗口矩阵。记录被测版本、macOS、
   Xcode、构建方式、profile、扩展及版本、外观和每项结果；区分自动化结果与
   实机视觉验收，不用最终 frame 代替动画过程。

## 验证方法

从仓库根目录，在独立测试 profile 中执行：

```sh
SEARCH_PROBE=popup-motion-check SEARCH_FEED=file:///dev/null/no-appcast \
  swift build
SEARCH_PROBE=popup-motion-check SEARCH_FEED=file:///dev/null/no-appcast \
  swift test --filter ExtensionPopup
SEARCH_PROBE=popup-motion-check SEARCH_FEED=file:///dev/null/no-appcast \
  swift test --skip-build --filter 'ReduceAnimationsTests|PopupGestureRelayTests'
```

[ExtensionPopupMotionTests.swift](../../Tests/SearchTests/ExtensionPopupMotionTests.swift)
使用非持久化扩展 controller、真实扩展页面、屏幕外窗口和侧栏位置的测试 anchor。
它在亮色和暗色外观下采样 popup 尺寸，覆盖首次回缩、静态溢出、内容变化、
快速切换和显式滚动条。静态溢出采样延长到显示后 2.8 秒，但测试没有直接断言
计时器已进入后续跟踪分支，也没有断言溢出时初始尺寸恰为 515×315 pt。其 fixture 位于
[Tests/Fixtures/ExtensionPopup](../../Tests/Fixtures/ExtensionPopup)。
[ExtensionPopupSizingTests.swift](../../Tests/SearchTests/ExtensionPopupSizingTests.swift)
另覆盖正文边距、内部滚动、裁剪溢出、显式滚动条、视口变化后隐藏滚动条和
最大尺寸。

需要进一步验证真实窗口时，使用独立测试 profile 和测试扩展，在侧栏及顶部布局、
亮色及暗色外观、普通动画及减少动态效果下分别打开 popup。覆盖固定／未固定按钮、
靠近屏幕边缘的位置、首次／再次打开、动态加载和内容缩小。记录 anchor 与 popup
的屏幕位置及尺寸，采集打开过程的可见帧；确认静态内容无意外反向跳动，页面
主动改变宽度时仍能跟随，高度按上述阶段性规则处理。另测多窗口和快速切换。
离屏 frame 采样、单次截图或最终尺寸不能替代这些观察。

当前仓库的 `build.sh` 会删除并重建部分构建产物；部分现有 live probe 会清理
测试目录或终止测试进程。执行前先检查实际脚本和目标，遵守当前环境的删除与
进程操作边界；不要复用用户正在使用的浏览器 profile。

## 2026-11-20 的验证记录与未决项

- 环境：Apple Silicon、macOS 27.2.1（26B131）、Xcode 27.2、Swift 6.4.2。
  测试启动时设置了 `SEARCH_PROBE`，并将 `SEARCH_FEED` 指向本地无效文件路径。
  测试类会覆盖 `SEARCH_PROBE` 为带进程 ID 的名称；`Store.world` 使用进程首次
  访问时的环境，因此不能仅凭命令行参数推断每套测试实际采用的 profile 名称。
- `swift build` 通过；`ExtensionPopup` 筛选的 14 项测试通过，动画设置与事件
  转发筛选的 8 项测试通过。弹窗动画测试此前还在亮暗外观下重复运行通过；
  新增的内部滚动区检查在修复前失败、修复后通过。视口变大后隐藏滚动条的测试
  在修复前得到 515×315 pt，修复后得到预期的 500×300 pt。
- 从 Swift 字符串提取尺寸计算和尺寸跟踪 JavaScript 后，`oxlint` 检查通过；
  组合跟踪脚本包含原有 `reach` 条件表达式，检查时豁免了
  `no-unused-expressions`。测试构建曾报告未修改的 `ReaderGuessTests.swift`
  actor isolation 警告。
- 尚未运行完整 CI，也未在实际桌面浏览器窗口录屏或手动验收；macOS 14 的构建
  兼容性、其他支持扩展的 macOS 版本及真实扩展的可见动画仍待验证。离屏测试
  未测量屏幕位置回跳，也未证明快速切换时所有异步回调都能按预期到达。首次
  测量失败后的重试机会、复测失败和五秒兜底先于复测完成时的回退，均未做
  故障注入验证。
- 显式宽度跟踪复用 `preferred` 时，会临时修改并恢复根元素的 style，可能触发
  页面注册的 `MutationObserver`；此前部分宽度跟踪场景不需要这些修改。尚未
  验证它对真实扩展的影响。
- 独立复核指出现有 `webViewDidClose` 与 `didFinish` 未检查回调来源：旧页面
  的回调迟到时，可能关闭新 popup，或提前触发新页面的尺寸跟踪。这些快速切换
  时序尚未实机复现，本次未修改。后续应以可控时序验证后单独处理，不能把尺寸
  回调的身份检查视为已覆盖它们。
