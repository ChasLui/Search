# 实现和验证

只在 `{{ worktree }}` 工作。先确认仓库根目录，记录开始时的 `git status`
和已有的 staged、unstaged、untracked 修改。阅读 `AGENTS.md`、相关实现及
调用方，再做与请求直接相关的最小改动；涉及专项行为时按项目规则阅读规格。

结构探索优先 codebase-memory（cbm），行为查询优先 jg，文本查询优先 tgrep；
不可用时使用其他可用工具。对不熟悉的功能，先比较 GitHub 上的公开实现再
动手；对外检索不发送用户私有信息。

按改动选择验证：Swift 变更考虑 `swift build` 和相关的
`swift test --filter`；界面文案变更考虑
`python3 Tests/check-localization.py`；其他文件使用适用的 linter。
执行前检查命令和测试实际涉及的目录、profile 与进程。部分测试会删除临时
文件、清理 profile 或终止 probe；需要此类操作时，先请求具体授权。
`SEARCH_PROBE` 不保证所有测试都使用该 profile。

界面变更注意亮、暗两种外观；WebKit、AppKit 或 profile 变更报告 macOS
版本和真实场景。离屏或合成测试不证明真实窗口和动画已验收。
不自动提交、推送、发布或运行公证。

将本次改动文件、关键行为、执行过的命令和结果、跳过的验证及原因写入步骤
声明的输出。逐项标明改动文件在 run 开始时是否已有修改；无法可靠区分已有
修改与本次改动时，明确说明审查基线不足。

若必须取得用户的信息或具体授权才能继续，以 `needs_input` 报告具体问题；
摘要还须包含开始时的工作区状态、已有改动和验证进度，供 manager 在重启时
传回。授权范围无法从用户答复中确定时，不得自行推断。
