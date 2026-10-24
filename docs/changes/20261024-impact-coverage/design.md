# 设计

复用 `manifests/gates.json`、control-plane impact 与现有 CI profile。沿真实文件消费关系补输入清单，报告数量使用已有轻量预算检查。实现映射与测试分别由独立任务负责；shared manifest / CI / 锁由主 Agent 串行整合。

整合决定：将原 strict maintenance checker 注册为常驻 contract gate，保持全部 14 项原预算和禁用缓存，不带 integration-deep 标签；GitLab 只初始化该检查真实需要的 ADK 子模块。深度回归的文档与根报告路径按 `input-consumers.md` 逐消费者声明，普通新说明保留轻量路径。README 的既有退役运行时禁止词由常驻 active-contracts 一并校验，以保持原回归语义；不改 impact 算法。

恢复既有八文件整理 Git tree `d7f1319c90c70e989978c6b7e1984df2be59e66b` 的内容，不改变历史审核原件，不混入无关变更。回滚由受保护仓库 revert 新提交，不降低 required checks。

当前隔离环境缺少 `~/codex` Provider 与 Execution Policy，记录 not-run；该事实不被转换成 live PASS。历史 lessons 文件检索不存在，使用本轮已保存反例与来源作为确定输入。
