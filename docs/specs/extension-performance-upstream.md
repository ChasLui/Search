# 扩展性能与上游同步规格

从上游合并浏览器扩展改动，或向上游回提 fork 的优化时，用本规格判断哪些改动仍需迁移。
三个容易回退的位置分别在商店安装时、准备扩展脚本时，以及每次为页面配置注入脚本时。
它们需要不同的验收指标。

## 合并或回提前

1. 记录 fork 基线、目标上游提交和两者的共同祖先，用 `git status --short`
   补查未提交实现和未跟踪测试。2026-11-19 的记录来自 `eb6fb74` 之上的工作区；
   单看这个提交会漏掉本规格对应的改动。
2. 按下列三条路径对照双方实现和调用方。上游已经满足约束时，沿用上游实现并迁移仍有价值的测试；
   仅部分等价时，只补缺失的行为。文件改名后，按安装、更新或页面配置入口重新追踪。
3. 在合并说明里逐项记录采用哪方实现、依据哪条测试或测量，以及尚待验证的场景。
   对基线和候选都失败的用例，附两边的结果。单项复测和全量运行分别记录。

## 1. 商店下载、验签与安装

- 商店请求走浏览器配置的代理会话。非 2xx 保留状态码，空的 200 或 204 报空包。
  下载成功后，调用方在临时文件清理后仍能读取全部字节。现实现让 URLSession 下载到磁盘，
  再用 `.mappedIfSafe` 读取，由 Foundation 决定是否映射。[下载与验签][crx]
- 头部、子消息和 ZIP 可共享原始 `Data` 的存储，输入切片可以从非零索引开始。
  SHA-256 按顺序接收 `CRX3 SignedData` 和 NUL、4 字节小端长度、原始 signed header 及 ZIP。
  声明的 16 字节 ID 和 RSA 证明公钥派生的 ID 都须匹配请求的扩展；通过签名后才交付 ZIP。
  性能目标是消除整包数组与拼接签名消息的额外副本。当前解包仍会为 `ditto` 写一份 ZIP。
  保留 CRX3 的 protobuf 和 WebKit 使用的 manifest JSON。若上游引入 FlatBuffers 等中间格式，
  比较时把转码、写盘与读取的成本一并计入。
- 审核曾发现，protobuf 读取器会在字段中途结束时交出已读字段，也会在合法未知字段处提前停止。
  参与验签的消息须完整消费，未知但完整的字段按 wire type 跳过，未知 group 内的字段保持在该组内。
  验收要同时覆盖截断元数据被拒、有效签名包带有未知元数据仍能安装。[验签回归][verify-tests]
- 安装和自动更新共用主 actor 以外的验签、解包与 shim 准备路径，每次操作使用自己的 staging 目录。
  完成准备后才交给 WebKit 和权限确认流程；更新提交前复核当前安装状态，原子替换成功后才切换到新版本。
  失败、取消或拒绝授权时应保留已安装版本。[安装与更新][install]、[目录替换][files]

## 2. 生成扩展兼容脚本

`ExtensionShims.shim(for:)` 用一次目录遍历和每个 `.js` 文件的一次 UTF-8 读取，
同时收集脚本路径和提到的事件。此约束针对这两个清单的生成；
完整的 `prepare` 还会处理 HTML、编码和其他文件。[shim 生成][shim]

- 脚本路径标准化后排序。空文件和纯 Unicode 空白文件带空标记；
  读取失败或 UTF-8 解码失败的条目保留路径，按非空处理。
- `search-shim.js` 出现在脚本清单中，其事件不计入扩展。worker 已携带带结束标记的旧 shim 时，
  只从标记后的扩展源码提取事件。事件去重并排序，空白判定使用完整文件内容。[边界用例][shim-tests]
- 仅重构读取路径时，对同一输入比较生成脚本的 UTF-8 字节。若上游有意更新 shim 内容，
  单独审阅内容差异，比较事件和脚本清单，并运行真实页面探针。

## 3. 每页配置外部消息脚本

页面配置会调用 `ExtensionExternal.script`。在已加载的扩展上下文相同的期间，复用按
`externally_connectable` 生成的最终脚本文本，无可用规则时也缓存 `nil`。
加载、卸载或替换上下文会使缓存失效。特别检查同一 ID 换用新 manifest，
以及最后一条可用规则被移除的情况。[脚本生成][external]、[页面调用方][tab]、[生命周期测试][cache-tests]

复用的范围是脚本文本。每个页面仍按自己的 URL 匹配规则，只有被列出的页面才能获得对应的
`chrome.runtime`。用允许与未列出的两个来源检查暴露范围，以及回调、Promise 和发送方 origin。
WebKit 扩展入口保持 macOS 15.4 的可用性保护，浏览器保留 macOS 14 的构建兼容性。

## 验收入口

从仓库根目录运行。下载单测使用独立会话和本地 `URLProtocol` 替身，
覆盖 2 MiB 返回数据、HTTP 错误与空响应。[下载回归][download-tests]

```sh
swift test --filter 'Crx|Extension'
swift test --filter ProxyTests
Tests/run-extension-files-tests.sh
python3 Tests/run-ci-tests.py
```

在支持扩展的 macOS 上，用独立 checkout 的开发构建和测试 profile 做实机验收。
编码和外部消息探针会清理自己的测试数据。

```sh
SEARCH_DEV=1 SEARCH_SIGN_IDENTITY='' ./build.sh debug
python3 Tests/extension_encoding.py
python3 Tests/external_messaging.py
```

商店路径有改动时，使用新的专属 profile，例如
`SEARCH_PROBE=crx-sync-check ./fresh.sh again`，从商店安装 uBlock Origin Lite。
记录已加载扩展的 ID 和版本，退出这个实例，用相同命令重新打开并核对加载状态。
保留 `again` 参数才能复用已有的安装数据。

## 性能复测与历史证据

下表来自 2026-11-19 对优化前后工作区的微基准，环境为 Apple Silicon、macOS 27.2.1、
Swift 6.4.2，以 `swiftc -O` 构建。专项微基准使用了临时驱动。复测时在同一机器、编译设置和
输入下交替运行 fork 基线和候选，先校验输出，再比较中位数和波动。下表用于选负载和量级。

| 操作与采样范围 | 基线 → 优化后 |
| --- | --- |
| 有效签名包，48 MiB 载荷，10 轮独立进程 | 峰值 RSS 199.6 → 55.5 MiB，验签 76.9 → 44.2 ms |
| 120 个约 4 KiB 的 JS，11 轮，仅生成 shim | 进程 CPU 时间中位数 18.44 → 15.33 ms |
| 8 个模拟扩展，每个 12 条规则，连续读取脚本 500 次 | 约 148 ms → 缓存命中后低于 0.01 ms |

两版都以 `.mappedIfSafe` 读取同一包文件，再开始计时，到返回 ZIP 为止。
签名夹具生成放在计时外，返回后核对 ZIP 摘要。表中 RSS 为各进程峰值的中位数。
后两项均核对脚本字节，外部消息的紧循环只测字符串生成与读取。
如需判断页面加载收益，另用 [shim_cost.py][page-bench] 测多 frame 注入成本，并注明测量阶段。

审核修复后的专项运行包含 113 个 CRX／扩展用例（1 个跳过、0 个失败）、11 个代理用例和
5 项原子替换检查。真实商店包 uBlock Origin Lite `2026.1116.1650` 安装并重启加载成功。
此前编码探针 8/8 通过；外部消息探针一次出现回调超时等失败，同一构建复测 16/16 通过。
此前全量运行 1,084 个用例，18 个跳过、12 个失败，涉及侧栏交互和 WebKit 下载。
其中 11 个失败在未修改的基线复现，另 1 个侧栏双击用例在候选上单独复测通过。
审核修复后未再跑全量，也未在 macOS 14 上实测。后续合并应填写当次环境与结果。

[crx]: ../../Sources/Search/Crx.swift
[install]: ../../Sources/Search/Extensions.swift
[files]: ../../Sources/Search/ExtensionFiles.swift
[shim]: ../../Sources/Search/ExtensionShims.swift
[external]: ../../Sources/Search/ExtensionExternal.swift
[tab]: ../../Sources/Search/Tab.swift
[verify-tests]: ../../Tests/SearchTests/CrxVerificationTests.swift
[download-tests]: ../../Tests/SearchTests/CrxDownloadTests.swift
[shim-tests]: ../../Tests/SearchTests/ExtensionShimGenerationTests.swift
[cache-tests]: ../../Tests/SearchTests/ExtensionExternalCacheTests.swift
[page-bench]: ../../Tests/shim_cost.py
