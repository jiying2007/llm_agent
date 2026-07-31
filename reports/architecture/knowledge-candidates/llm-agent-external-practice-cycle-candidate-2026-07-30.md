# Knowledge Hub Candidate: 2026-07-30 外部实践搜索与吸收决策

- source: `reports/external-practice-curator-review-2026-07-30.md`
- captured_at: 2026-07-30
- last_verified: 2026-07-30
- topic: llm-agent-external-practice-cycle-2026-07-30
- candidate_kind: decision
- intended_domain: projects/llm-agent
- status: reviewing
- owner_review_required: true
- review_after: 2026-08-29

## Summary

新一轮 report-only cycle 生成 118 个统一候选；GitHub=30、OpenAI official=64、Anthropic official=5、WeChat ledger=19，GitLab 查询成功但 0，Gitee 为 `degraded-empty`。另从 primary source 定向归一 3 个候选。

唯一达到 `ENHANCE-ready` 的增量是 MCP 2026-07-28 final compatibility refresh；它只能增强既有 RC staging，不能激活 runtime。StrongDM Attractor 保持 observe，Harness Evals 拒绝作为依赖、只观察 vocabulary。当前没有独立 owner decision，因此 implement/pilot/publish 均为 not-run。

## Durable Decisions

1. provider cycle 的 degraded 状态必须保留；Gitee 空结果不能解释为 source clean。
2. official manifest 的再投影不是新能力，不能重复创建 Agent/Skill/Workflow。
3. 新 GitHub harness 仓即使 MIT，也必须有 release、security、test、maintenance 和 duplicate 净增益证据。
4. MCP final tag `2026-07-28` 已发布，tag commit 为 `5f5440bb26a62e2cf3440b92da5a667efa03b267`；现有 RC staging 应在 owner 决策后选择 `ENHANCE`。
5. final source retrieved 不等于 compatibility：active 仍为 `2025-11-25`，runtime/Tasks/Apps/extensions 保持 disabled，smoke/auth/rollback 未运行。
6. Curator、collector 不能自批；没有独立人类 decision 不创建 ADK implementation change。

## Verification

- `rtk scripts/practice-intake.sh cycle ... --allow-network`：exit 0，status=degraded，candidates=118，deduplicated=1。
- `rtk scripts/practice-intake.sh check --kind candidate --input reports/external-practice-candidates-2026-07-30.jsonl`：118 records pass。
- `rtk scripts/practice-intake.sh check --kind candidate --input reports/external-practice-targeted-candidates-2026-07-30.jsonl`：3 records pass。
- `rtk scripts/practice-intake.sh check --kind evidence --input reports/external-practice-targeted-evidence-2026-07-30.json`：pass。
- `rtk scripts/check-practice-intake.sh .`：provider/security/idempotence/terminal contracts pass。

## Sanitization

- 不保存 token、raw API response、WeChat 正文、网页正文、登录态、浏览器状态或外部代码。
- 只保存 canonical URL、revision/tag、license status、metadata 摘要、duplicate/architecture 决策和命令证据。
- 未 clone、安装、执行、注册、commit、push、publish 或 live apply 外部候选。

## Residual Risk

- MCP repository 使用混合 licensing transition；任何复制都需要逐文件/license 审查，本候选只建议 metadata/contract enhancement。
- cycle 查询覆盖面受固定 query、provider API 和 metadata-only 策略限制；不是互联网穷尽证明。
- MCP candidate、Attractor、Harness Evals 均未得到独立 owner decision。

## Gate Result

`reviewing / decision-blocked`。Knowledge Hub dry-run transaction 为
`kh-20260730T154525Z-be912ef5`，`read_only=true`、`write_applied=false`。本候选不授权
active promotion、ADK implementation、runtime enablement 或 adoption matrix 更新。
