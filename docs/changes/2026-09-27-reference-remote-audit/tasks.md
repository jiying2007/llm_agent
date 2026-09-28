# 本地任务

- [x] 盘点 pin、registry、已有 sync/status、dirty 参考目录和上游更新。
- [x] 实现默认离线/显式联网的远端审计；真实联网只读观测为 6 different、2 same、0 unavailable。
- [x] 补同 SHA、变化、空结果、进程失败、输入拒绝和审计期间 pin 漂移测试；Python 3.8 最新定向 6/6 通过。联网命令从仓库外 cwd 运行，禁用凭据 helper 与本地 Git 配置读取；真实 OpenSpec 单仓调用返回 `review-required`。
- [x] 在项目参考仓 runbook 增加操作入口与证据边界。
- [x] 根仓隔离 worktree 全量回归 64/64；此后仅增加来源漂移拒绝逻辑和相应定向测试，最新 6/6 通过。`check-doc-sync` 通过。`check-all --quick --working-tree` 为 37/52，15 项失败来自未物化参考仓/Codex 路径及既有产品资格门禁，不能声称整仓 release-ready。
- [x] 工作树自审发现受允主机可能经 HTTP 重定向跳出 allowlist，以及 registry/pin 上级目录 symlink 边界；已禁用 Git HTTP 重定向并拒绝 linked 上级目录，Python 3.8 定向 7/7 通过。修复后 OpenSpec 单仓真实只读联网返回 `review-required`、`different=1`，未改 pin 或 checkout。
- [x] 当前隔离 worktree 重跑根仓 full 首次在 `test_adk_agent_value_trust_consumer` 导入失败；核实子仓源码存在，根因是 root runner 未设置 ADK 源码 `PYTHONPATH`，现已在 runner 中绑定受管子仓和根仓源码路径。
- [x] 根仓 `pyproject.toml` 要求 Python ≥3.11；系统 Python 3.8 的后续标准库/API 失败属于解释器不符合根仓约束。runner 已加版本前置检查；现有 Python 3.11.16 环境完整根仓回归 64/64 通过。ADK Python 3.8 验证仍独立。
- [x] 同环境 `check-all.sh --quick --working-tree` 为 38/52，14 项失败涉及隔离 worktree 未物化参考仓、Codex 锁/运行态、promotion 所需 cosign、旧台账证据路径及其它现有工作区资格门禁；不把测试 64/64 推导为根仓 release-ready。
- [x] 验证计划要求的固定 ADK 子仓 quick 回归，在 Python 3.11.16、ADK 子仓 cwd 和显式 `PYTHONPATH` 下 49/49 通过；其 clean commit 身份与主 ADK 未提交工作树的 93/94 是不同快照。
- [ ] 与 ADK 本地吸收批次一起做最终语义审查；本阶段不提交、推送或改 pin。
