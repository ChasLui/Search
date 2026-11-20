# Search 的 Paseo Playbooks

在 Playbooks 面板的当前 workspace 中选择并启动所需的 playbook：

- **项目变更**：填写请求；实现并验证后进行独立静态审查。发现阻塞问题时
  以 `needs_changes` 结束；已有修改重叠且无法可靠审查时以
  `review_incomplete` 结束。报告保留问题及验证空白。
- **独立审查**：填写审查范围和基线；两个只读步骤并行检查正确性和验证覆盖。
- **上游同步预检**：提供本仓库已有的上游引用或 commit SHA；默认比较
  `origin/main` 和 `origin/chaslui-dev`。可提供同步前镜像引用以精确界定
  同步范围；不更新引用或执行同步。

这些配置不指定 provider、model 或 agent mode：步骤继承 Playbook Manager
的 provider 和 model，未设置的 mode 由 provider 决定。
使用当前 workspace 可保留当前 worktree 的未提交内容；新建 workspace
可能从已提交版本读取配置，且涉及创建 worktree，应先确认授权。
非隔离 run 在同一 workspace 中不能并发。

项目默认关闭 Playbooks 的 worktree 隔离、workspace 和步骤 agent 的自动
归档；工具权限请求设为升级给用户。`readonly` 是事后检查，不是 sandbox；
权限升级也只能处理实际出现的权限请求。启动 run 不代表同意 git mutation、
删除、清数据、结束进程，或对外发消息、评论、上传和发布；这些操作仍须
逐项获得明确许可。步骤 agent 会保留，完成后可由用户按需处理。

测试和构建的副作用需逐项检查：部分 Swift 测试会清理 profile 或临时文件；
`fresh.sh`、`build.sh` 和 GUI probe 也可能删除产物、清理数据或终止进程。
报告应区分自动化检查、真实 GUI 验收与未验证项。
