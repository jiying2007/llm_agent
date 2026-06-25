# Harness / Loop Engineering 开源实践吸收候选

- 日期：2026-06-25
- 范围：面向 `agent-dev-kit` 的 harness engineering 与 loop engineering 方法吸收
- 模式：method-only / runtime-disabled
- 落地资产：`agent-dev-kit/manifests/harness_loop_engineering_contracts.json`
- 门禁：`agent-dev-kit/scripts/check-harness-loop-engineering-contracts.sh`、`scripts/check-harness-loop-engineering.sh`

## 结论

本轮不新增本地参考子仓，不引入外部运行时，也不默认安装 CLI、container、hook、MCP server 或后台 worker。可吸收部分落在三类 contract：

1. harness：把 repo task、eval suite、scorer、CI threshold、failure_replay 固化为可检查字段。
2. loop：把 state_schema、checkpoint_policy、resume_policy、retry_budget、stop_condition、human_gate 固化为 durable loop 证据。
3. observability：把 trace_id、tool_calls、handoff、guardrail_result、redaction_policy 固化为 trace evidence。

## P0 采纳源

| source_id | 仓库 | 吸收点 | 落地合同 | 边界 |
|---|---|---|---|---|
| google-adk-python | https://github.com/google/adk-python | workflow runtime、routing、fan-out/fan-in、loop、retry、state、human gate | durable-agent-loop-v1、workflow-state-contract-v1 | method-only、runtime-disabled |
| langgraph | https://github.com/langchain-ai/langgraph | state graph、checkpoint、resume、human-in-loop、durable execution | durable-agent-loop-v1、trace-observability-contract-v1 | method-only、runtime-disabled |
| swe-bench | https://github.com/SWE-bench/SWE-bench | repo task、pinned revision、patch artifact、reproducible grading | repo-task-evaluation-harness-v1 | 不默认跑 benchmark container |
| inspect-ai | https://github.com/UKGovernmentBEIS/inspect_ai | dataset / solver / scorer / task result 分解 | repo-task-evaluation-harness-v1、agent-eval-ci-gate-v1 | 不导入框架运行时 |
| promptfoo | https://github.com/promptfoo/promptfoo | declarative eval、assertions、CI threshold、red-team scope | agent-eval-ci-gate-v1、guardrail-handoff-contract-v1 | 不导入 CLI/provider 配置 |
| openai-agents-python | https://github.com/openai/openai-agents-python | guardrails、handoffs、sessions、tracing、human-in-loop | trace-observability-contract-v1、guardrail-handoff-contract-v1 | 不替换 ADK 运行时 |

## P1 方法源

| source_id | 仓库 | 可借鉴点 | 状态 |
|---|---|---|---|
| openhands | https://github.com/OpenHands/OpenHands | agent backend、workspace、sandbox boundary | adopt as method-only contract input |
| swe-agent | https://github.com/SWE-agent/SWE-agent | issue-to-patch loop、Agent-Computer Interface 术语 | adopt as method-only contract input |
| smolagents | https://github.com/huggingface/smolagents | code-action loop、sandbox warning | adopt as method-only contract input |
| deepeval | https://github.com/confident-ai/deepeval | pytest-like eval 组织、agentic metric 命名 | adopt as method-only contract input |
| phoenix | https://github.com/Arize-ai/phoenix | OpenTelemetry trace、dataset、experiment、evaluation observability | adopt as method-only contract input |
| lm-evaluation-harness | https://github.com/EleutherAI/lm-evaluation-harness | task registry、backend adapter、稳定结果 schema | adopt as method-only contract input |
| autogen | https://github.com/microsoft/autogen | 历史多 agent 分层架构与 benchmark 术语 | historical-reference-only |

## 已吸收合同

### repo-task-evaluation-harness-v1

必须声明 `task_id`、`source_repo`、`pinned_revision`、`environment_spec`、`runner_command`、`scorer`、`expected_artifacts`、`resource_budget`、`reproducibility_evidence`、`failure_replay`。

适用场景：外部 repo 任务评测、patch 质量验证、可复现 benchmark 候选。

### agent-eval-ci-gate-v1

必须声明 `eval_suite_id`、`positive_cases`、`negative_cases`、`judge_policy`、`non_llm_assertions`、`ci_mode`、`threshold`、`flaky_policy`、`red_team_scope`。

适用场景：routing、governance、prompt、skill 触发、guardrail 的回归验证。

### durable-agent-loop-v1

必须声明 `state_schema`、`transition_edges`、`checkpoint_policy`、`resume_policy`、`retry_budget`、`stop_condition`、`human_gate`、`failure_replay`。

适用场景：长任务恢复、调试闭环、Review -> Repair -> Validate、Agent Improvement Loop。

### coding-agent-loop-v1

必须声明 `workspace_boundary`、`sandbox_policy`、`action_format`、`observation_capture`、`patch_artifact`、`test_command`、`rollback_path`、`approval_boundary`。

适用场景：代码代理执行闭环、子代理任务包、外部代码执行 runtime 的准入前审查。

### trace-observability-contract-v1

必须声明 `trace_id`、`span_kind`、`agent_id`、`tool_calls`、`handoff`、`guardrail_result`、`session_id`、`redaction_policy`、`evidence_path`。

适用场景：trace eval、失败样本回放、交接审计、guardrail 命中证据。

### guardrail-handoff-contract-v1

必须声明 `guardrail_id`、`trigger_condition`、`decision`、`handoff_target`、`user_visible_effect`、`override_policy`、`audit_evidence`。

适用场景：安全门禁、人工审批、跨 agent handoff、拒绝或降级路径。

## 明确不吸收

- 不把任何外部仓库加入默认 runtime。
- 不默认执行 benchmark container。
- 不导入第三方 CLI、provider 配置、hook、daemon、browser automation 或 MCP server。
- 不把 LLM judge 输出当作唯一真源。
- 不把 hidden conversational state 当成 durable loop state。
- 不把 observability 降格为 console log。

## 后续使用方式

新增或升级 ADK harness / loop 能力时，先映射到 `harness_loop_engineering_contracts.json` 中的合同字段；如果字段不足，先扩展合同并补门禁，再实现具体 skill、workflow 或 script。

验证入口：

```bash
rtk bash agent-dev-kit/scripts/check-harness-loop-engineering-contracts.sh
rtk bash scripts/check-harness-loop-engineering.sh
```
