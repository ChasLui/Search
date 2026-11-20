# 本地 CDN：上游同步与实验规格

## 当前决定

本次 Swift 原生本地 CDN 候选**未通过性能验收，不发布、不回流上游**。经用户确认，
产品源码、资源、设置和专用测试已撤回；当前源码不包含此功能。原型曾测得收益，
但最终候选的两轮后台可见测量存在明显波动，且第一轮三个场景超过回退门槛，
详见[测量结果](#最终候选的测量结果)。功能验证通过不等于性能验收通过。

本文约束 fork 的后续同步和重新评估，不改变 `AGENTS.md` 中的 upstream mirror 与
逐个移植流程，也不阻止同步无关的上游改动。

## Agent 操作步骤

1. **同步或回提 WebKit 资源加载改动时**，先核对上游、fork 与当前工作树的实际差异。
   逐项记录相关改动是移植、已存在还是暂缓，并保留本规格及其 `AGENTS.md` 入口。
   上游若引入类似资源替换，单独评估其行为与收益；不得因上游已有实现、原型结果或
   本机残留候选而自动恢复或回提本次候选。
2. **重新尝试 bundled CDN 时**，先在隔离实例验证下文的行为矩阵，并完成两轮性能
   验收。测试候选可以放在隔离环境；在兼容性和性能均通过之前，保持产品源码的
   不发布状态。任一关键行为不能可靠实现、性能不达标或结果接近噪声时，记录证据
   并停止产品化。若验收口径改变，明确记录变更、原因和适用范围，不能混用不同口径。
3. 重新实现并验证通过后，记录源码版本、macOS 和 WebKit 版本、目标系统范围、
   资源校验值、行为矩阵、原始性能数据及最终结论；再按项目流程决定是否移植或回提。
   对每个上游改动的处理结果都应可复查。

本次候选的主要接入位置包括 [Tab.swift](../../Sources/Search/Tab.swift) 的
`Web.configuration`、[Browser.swift](../../Sources/Search/Browser.swift) 的弹出窗口
创建、[SidePanel.swift](../../Sources/Search/SidePanel.swift) 的网站侧栏 delegate，
以及 [Shield.swift](../../Sources/Search/Shield.swift) 的内容规则。后续改动前重新
核对实际调用关系；这些位置不是当前已存在本地 CDN 实现的证据。

## 重新评估时的行为契约

本次尝试采用 Swift、`WKContentRuleList` 和 `WKURLSchemeHandler`，不创建或加载
WebExtension。功能默认关闭，无痕页面不启用；普通页面的配置创建时预注册 handler，
使已有标签可在下次导航启用。关闭、初始化失败或规则不可用时不开始重定向，
handler 也不向网页提供资源，未重定向的请求维持 WebKit 原有网络路径。

仅当以下行为能在目标系统上可靠复现时，才考虑继续：

| 场景 | 必须验证的行为 |
| --- | --- |
| 标签、分屏、弹出标签、网站侧栏 | 顶层页面和跨域 iframe 均按预期处理。 |
| 隐私和开关 | 默认关闭；无痕标签不注册 handler 且不替换；设置变化后的下次导航行为正确。 |
| 站点豁免 | 豁免覆盖顶层页面及其跨域 iframe，不影响其他未豁免标签。 |
| 来源重载 | 只绕过当前标签的一次导航；完成、失败、取消或被新导航取代后恢复，其他标签不受影响。 |
| CSP／SRI／CORS | 保留 WebKit 语义，测试 classic script 和 module。 |
| Shield、扩展、代理 | 广告拦截和已安装扩展的真实规则继续生效；使用拒绝代理验证未命中、关闭、无痕和豁免请求的网络路径。 |
| 失败和资源 | 资源、规则或私有接口初始化失败时显示不可用，不开始替换；已发生重定向后的失败不保证自动回源，应允许关闭该站点优化后重新加载。 |

弹出标签重建 content controller，网站侧栏有独立 delegate。需覆盖限定 CDN 的 CSP、
正确及错误 SRI 与跨域 CORS；错误 SRI 与禁止该来源的 CSP 必须阻止执行。

不只检查规则数量：本次 uBlock Origin Lite 启动初期即使关闭候选功能也曾不稳定。
应等待实际请求连续被拦截后，再比较开启和关闭状态。站点卡片和来源重载还应覆盖
真实窗口操作；本次离屏浅色／深色绘制不证明交互通过，锁屏时未观察到 `⌘.` 停止
动作，不能把它当作桌面快捷键验证。

### WebKit 和资源边界

- WebKit 私有 `_activeContentRuleListActionPatterns` setter 会替换整张规则表。
  根据 [WebKit 的实现](https://github.com/WebKit/WebKit/blob/16a6fb9bd55d5f69410609b6654e149bc0f07f0f/Source/WebKit/UIProcess/API/Cocoa/WKWebpagePreferences.mm#L224-L245)，
  先读取并合并，只增删本功能条目，设置后回读；读取、设置或验证失败时不启用替换。
  不得覆盖 Shield 或扩展已有规则。仅改变顶层 `WKWebpagePreferences` 不足以保证
  iframe 豁免或来源重载，须验证实际网络路径。
- 此候选只匹配下表中的两个**完整 HTTPS 脚本 URL**，handler 只返回固定资源表中的
  内容，不接受任意文件路径。资源需核对 MIME、CORS、字节和完整许可证，SwiftPM
  与签名开发 app 打包同一份目录；不添加后台下载或遥测。
- 显式设置 `url-filter-is-case-sensitive: true`。WebKit 默认不区分大小写，
  可能错误替换不同路径；修改规则时更新编译列表标识。
- 测试过的候选将系统范围限制为 macOS 27.2.1 起的 27.2.x；其他主、次版本
  不能因版本号更大而自动放行。每个目标主、次版本应实测，最多从验证通过的最低
  补丁版本起开放该次版本范围。本次性能未通过，因此任何系统范围都未获发布验收。
- 如果将来实现变更了资源、匹配规则、接入时机、系统范围或相关 WebKit 行为，
  重新验证受影响的行为矩阵；新候选仍需完整性能验收。

本次固定资源为 jQuery 3.7.1，87,533 字节，SHA-256：
`fc9a93dd241f6b045cbff0481cf4e1901becd0e12fb45166a8f17f95823f0b1a`。
实现思路参考 [local-cdn](https://github.com/james-fray/local-cdn)，实验采用原生
Swift 路径，而非该项目的扩展实现。

## 性能验收方法

开始测量前，固定至少三个实际加载候选 URL 的公开免登录页面，以及一个不命中的
对照页面；重新确认页面、脚本 URL 和脚本执行情况仍然有效。本次冻结的样本为：

- jQuery Gantt：`https://uzbeki.github.io/jquery-gantt-chart/`；脚本为
  `https://cdn.jsdelivr.net/npm/jquery@3.7.1/dist/jquery.min.js`。
- Bootstrap Table：`https://bootstrap-table.com/docs/getting-started/introduction/`；
  脚本同上。
- jQuery Tutor：`https://javascript-tutor.net/jquery/jqry_tutor.html`；脚本为
  `https://code.jquery.com/jquery-3.7.1.min.js`。
- 对照：`https://example.com/`，未命中。

1. 使用隔离 WebKit store，分别交错测量每个页面的冷、热缓存，每轮各 20 对，
   保留原始数据并完成使用不同随机种子的独立复测。冷访问使用独立 store，热访问
   在相同标签和 store 中进行。这里的冷、热指 WebKit 缓存，不代表 DNS 或 TLS 冷启动。
2. 使用受控服务端日志验证基线请求是否发出，并验证候选确实由 handler 提供资源。
   真实页面跨域资源计时不可用时明确记录；不要把受控测试当作真实页面性能结果。
   记录窗口可见性、焦点、遮挡、系统及脚本／二进制版本。若用户要求不抢焦点，
   不主动激活应用；后台可见口径与前台口径分开，不能相互替代。
3. 同一个真实命中页面的冷缓存 `load` 中位数，须较基线降低至少 **10% 且 50 ms**，
   并在独立复测中再次达到；其他每个页面和缓存场景均不得同时恶化超过 **5% 和
   50 ms**。两轮均须完整；结果不稳定或接近噪声时不实施。
4. 本次用配对 bootstrap 95% 收益区间辅助评估噪声，并要求同一获益页面两轮区间
   下界均大于零；这是一项本次评估采用的统计判据，并非原始计划明文规定的阈值。
   保留正负结果、失败或排除样本及原因，不得挑选通过的轮次。

重新实现后，还须运行 `swift build`、相关 Swift 测试、`python3 Tests/run-ci-tests.py`、
本地化和 diff 检查，并验证 SwiftPM 与签名开发 app 均能加载相同资源。使用隔离
profile：在进程首次访问 `Store.world` 之前设置 `SEARCH_PROBE`；不要使用会清理
profile 的 `fresh.sh` 形式，也不要操作用户的现有会话。

## 最终候选的测量结果

基线为 Search `d431762bf285bd6aa2a944c094d4b4681ee07b34`，系统为 macOS 27.2.1
（26B131）、WebKit `22625.2.8.11.9`。用户将原先的前台可见条件调整为后台可见、
不抢系统焦点；其他门槛不变。测量副本隐藏启动，创建窗口后切换 `.prohibited`，
窗口鼠标穿透且置于普通窗口下方，再用 `unhideWithoutActivation` 在空闲屏幕区域
显示；测量期间监测窗口、页面可见性及焦点。这与普通 Search 窗口的激活策略不同，
结果只适用于记录的后台可见条件，不能推断普通前台性能。

两轮各四页、每页冷热各 20 对，每轮 160 个不同冷缓存 store，合计 320 个。
第一轮两次无效尝试（HTTPS 错误和窗口区域被占）均整对排除并重测；第二轮无失败
尝试。下表为 `load` 中位数，单位 ms：

| 页面 | 缓存 | 第一轮基线 → 候选 | 独立复测基线 → 候选 |
| --- | --- | ---: | ---: |
| jQuery Gantt | 冷 | 1632.5 → 1267.5 | 1602.5 → 1054.5 |
| jQuery Gantt | 热 | 89 → 95 | 87.5 → 86.5 |
| Bootstrap Table | 冷 | 1909.5 → 2025 | 1819.5 → 1653.5 |
| Bootstrap Table | 热 | 193.5 → 215 | 184 → 179 |
| jQuery Tutor | 冷 | 2787 → 3013.5 | 2390 → 2506.5 |
| jQuery Tutor | 热 | 376 → 370.5 | 348 → 307 |
| example.com | 冷 | 734.5 → 949.5 | 657 → 692.5 |
| example.com | 热 | 171 → 173 | 162 → 156 |

Gantt 冷缓存中位数两轮降低 22.4%、34.2%；配对 bootstrap 95% 收益区间分别为
`[-47.5, 1001] ms` 和 `[290.5, 744] ms`，第一轮跨零。第一轮 Bootstrap Table、
jQuery Tutor、example.com 的冷缓存中位数分别增加 115.5 ms／6.05%、
226.5 ms／8.13%、215 ms／29.27%，均超过回退门槛。这些回退的区间也跨零，
不能断言观测差异由候选代码造成；按照约定，波动与不确定性已使验收失败。

先前前台原型的 Gantt 冷缓存两轮分别改善 35.9%、41.5%，但它不是最终候选。
早期前台最终候选测量未完成，后台 v7 测量曾意外获得焦点，原因未确定；这些数据
均未混入上述两轮。不能仅凭 `open -g` 保证不会获得焦点。

## 功能证据与本机记录

在上述系统上，隔离原型和签名候选验证了普通标签、分屏、弹出标签、网站侧栏、
跨域 iframe、无痕、Shield、代理故障、豁免、来源重载及 CSP／SRI／CORS 的受控
行为；签名候选还检查了 classic script 和 module。五个入口使用独立测试 store，
普通入口的顶层和 iframe 执行本地脚本，无痕与未匹配 URL 走拒绝代理。

真实 uBlock Origin Lite `2026.1116.1650` 在规则连续稳定后，关闭与开启候选各
10 个新标签均保持广告拦截，开启组均执行本地脚本；已有标签开启前后也保持拦截。
签名候选还验证了已保存站点豁免、当前标签来源重载，以及 `window.stop()`、连接
失败和新导航取代后的恢复。这些是实验版本的功能证据，不代表当前源码包含该功能，
也不代替真实窗口交互与性能验收。

完整候选快照、功能日志、冻结清单、两轮原始数据、完整性审计和汇总保留在本次
工作树的 `.build/local-cdn-candidate-preserved-a9bc3ee78b37/`、
`.build/local-cdn-foreground-spike/`、`.build/local-cdn-plan-probe/` 与
`.build/local-cdn-product-bench/`。`.build/` 被 Git 忽略，不随仓库或上游同步迁移；
本文表格和结论不依赖临时路径。需要原始记录时，先确认这些本机文件仍存在：

- 功能记录位于 `.build/local-cdn-foreground-spike/`：
  `product-surfaces-cold-f1ea6404ad6a-result.json` 覆盖五个入口，
  `product-semantics-denied-v2-cdn-policy-1f49c88703e6-result.json` 覆盖
  CSP、SRI、CORS、classic 和 module。
- 同一目录的 `product-extension-stable-v2-final-result.json` 与
  `product-extension-existing-tab-v2-final-result.json` 记录真实扩展共存；
  `product-exemption-final-cdn-exempt-c6ee8ce4d1c1-result.json` 和
  `product-origin-jsstop-final-cdn-jsstop-8c1384bf0197-result.json` 分别记录
  站点豁免和来源重载恢复。
- `background-run-1-v12.jsonl` SHA-256：
  `71c852e7aa3df8f209048e2d8518aa0c75a6df2ac19d9cbcbedec7983fff3441`
- `background-run-2-v12.jsonl` SHA-256：
  `464677f4b28bb549412b3983ba7e26b0c325f7838c1a34a3b75cde80985b4b5c`
- 相同目录的 `background-run-{1,2}-v12-audit.json` 与
  `background-acceptance-v12.json` 分别记录完整性审计和未通过的验收结论。

撤回时，本机先前的 `build/Search.app` 仍含历史候选；不能仅凭文件名认定它由当前
源码构建，使用或发布前应重新确认来源和内容。候选撤回后，完整 CI 主套件 1053 项
中 19 项跳过、零失败，另 43 个隔离用例通过。候选和未修改基线此前均曾在同一处
favicon `NSCache` 断言失败；已确认 `Store.world` 首次访问后固定，测试类稍后设置
`SEARCH_PROBE` 无法改变它，因此 CI 入口将 `FaviconMemoryTests` 单独进程执行。
这一隔离修复不证明该断言失败的底层原因。

一次早期 XCTest 忘记设置 `SEARCH_PROBE`，读取了真实 Search 会话目录后崩溃；按
文件修改时间检查未见会话或偏好更改，但这不是完整取证。后续测试必须在启动进程前
设置隔离 profile，保护用户数据。
