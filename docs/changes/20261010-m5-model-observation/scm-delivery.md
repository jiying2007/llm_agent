# M5 隔离交付与 CI 修复记录

日期：2026-10-10。交付分支：`codex/m5-evidence-binding-20261010`。

用户授权独立分支提交、推送和草稿 PR，未授权合并。首批冻结的 42 个受管文件已提交为 `6fb2ed0836933b2f261049a5818a2b1e6287ad1f`，并创建 [草稿 PR #193](https://github.com/jiying2007/llm_agent/pull/193)。原 main 检出、索引及 dirty 保留。

## 真实 CI 首轮失败与修复

[run 38030224677](https://github.com/jiying2007/llm_agent/actions/runs/38030224677) 的 contract 失败：根仓 checkout 使用 `submodules:false`，M5 rollover 读取 ADK canonical task 数据集时发生 FileNotFoundError；后续集成检查因此跳过。

contract 在 M5 tooling 前新增 `git submodule update --init --depth=1 agent-dev-kit`。检出身份仍由根仓 gitlink 决定，不使用远端最新分支；本地实际检出为 `ef5384305421700ca01e89b3df3b3f7878a70265`。工作流回归要求初始化发生在 rollover 前。

隔离 linked worktree 复验另外发现 fixture 兼容缺陷：`m5_snapshot_fixture.py` 已创建独立 `.git` 目录，旧 rollover 分支重复对该目录执行 `unlink()`。删除冗余 root metadata 重建，保留 child metadata 隔离、synthetic commit 和 lock 重绑定。

## 新鲜本地验证与独立复审

- `test_runtime_smoke_evidence.sh`：PASS。
- `test_software_m5_rollover.sh`：21 + 17 + 7 + 13 项 Python 测试 PASS；linked worktree 的成功、拒绝及事务回滚路径 PASS。
- `test_ci_incremental_gate_dag.sh`：PASS。
- `test_workflow_action_compatibility.sh`：PASS。
- 独立代理对 workflow、顺序回归及 fixture 修复完成两轮只读复审：Spec PASS、Quality PASS，无剩余 finding；独立 `bash -n` 与 `git diff --check` PASS。

上述为交付 worktree 的本地修复证据。修复后的 hosted CI 状态以 PR 最终 head 对应的 GitHub run 为准。

## 资格边界

真实 runtime 的受信模型身份、当前候选 field、人类 owner 资格以及匹配最终 main 的签名 CI/qualification 仍需独立验收。历史候选和过期 scorecard 未重标。fixture 使用模拟 verifier/runner，只验证消费与事务行为；PR CI、源码审查和本地 Execution Policy conformance 均不构成 M5 或产品放行。
