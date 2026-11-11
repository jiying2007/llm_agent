# Goal 长任务与执行成本只读观察

本工具复用 ADK 原有 current-state 与 Execution Policy，不建立另一套 Goal、任务队列、自动化、批准、运行时或预算权威。工程平台 Issue #293 继续保留完整历史，跨轮次恢复优先读取小型 ADK current-state 当前状态和需要的准确证据链接，而不是把整个历史 Issue 注入模型上下文。

## 最小状态读取

使用已授权执行器产生的 adk.current-state/v1 JSON，需包含 goal_ref、milestone、evidence_refs、blockers、1～3 个 next_actions 和 history_refs。先用固定 ADK 的 goal state-check 检验，再运行：

    python3 -m tools.control_plane.goal_efficiency --current-state STATE.json

输出仅有 goal、当前里程碑、阻塞、最多三个下一步、原文件 SHA-256 与证据数量。独立执行器必须验证输入来源；本工具的输出固定声明 OBSERVED_NOT_CERTIFIED 和 goal_completion_verified=false。

## GitHub Actions 实际 Job 用时

从 GitHub REST API 正式获取某次工作流的完整 jobs JSON（/actions/runs/<ID>/attempts/<N>/jobs?per_page=100，必须包含 total_count、jobs，以及 job id、run_id、run_attempt、head_sha、started_at、completed_at）。运行：

    python3 -m tools.control_plane.goal_efficiency \
      --current-state STATE.json --jobs JOBS.json \
      --run-id 41406503099 --attempt 1 \
      --head-sha 127799079a0ad7cab4e579f7a0388943e7a56b12

必须明确绑定同一次 run、attempt 和精确 source SHA；截断分页、重复 ID、错误来源、异常时间立即失败。job_seconds_sum 为所有已完成 Job 历时合计，observed_wall_seconds 是可观察的首末 Job 区间，两者都不是 GitHub 实际计费或模型成本。部分执行中标记 PARTIAL，不能声称 CI 已成功。

## Goal / Loop 实际 Token 效率

本仓库模型调用预算已改为 **无每日费用硬上限、无每日 Token/调用次数硬停止**。对 Goal/Loop 的效果应从同一组真实任务的 Tokens/新验收、重复上下文、nonclosing_calls、恢复耗时和完成率衡量，不以每日花费下降代替效率提升。

当可信执行器已有请求级用量时，可按 `docs/runbooks/model-call-budget.md` 调用 `python3 -m tools.codex_assets.model_call_budget --state /path/to/ledger.json report`；其中 `goals` 汇总仅为带来源的诊断，不授予 Goal 完成资格。无真实输入/输出 usage 时 `input_tokens_per_progress=null`，相同证据哈希不可重复算新进展。默认最多返回 10 个 token 消耗最高的 Goal 统计项，避免报告本身再进入长上下文循环。

## Token 与验收

只有原始 ADK runtime_control.state/v1 包含已观察的 usage.observed_at，才可追加 --runtime-state RUNTIME.json 读取 input/output/cached/reasoning/total tokens。没有真实观察一律 UNKNOWN，不当成零。即使有记录也仅为 REPORTED_UNVERIFIED，不能伪称 Provider 验签、计费凭证或跨执行器消重。禁止 bytes/4 替代真实 usage；不能因绿色 CI 自动认定 Goal 达成。

后续应选至少十个真实任务冻结 A/B 基线，比较 Token/已验收里程碑、GitHub Job-分钟、CI 返工次数、人工干预与真实 Goal 完成率；没有外部受信接受收据则目标结果 UNKNOWN。涉及生产、用户凭据和外部效果恢复，仍严格依原系统的独立门禁。

安全与成本：工具离线只读，输入上限 256KiB，拒绝符号链接、特殊文件、重复 JSON 字段及来源漂移；只显示摘要/引用数和必要的安全枚举，不记录原文 Prompt、密钥或完整运行日志。失败返回非零。完整原始审计证据留在 GitHub/ADK 权威入口，不随投影复制。

相关来源：agent-dev-kit/src/agent_dev_kit/planning_state.py、agent-dev-kit/src/agent_dev_kit/execution_policy、GitHub engineering-platform/issues/293。
