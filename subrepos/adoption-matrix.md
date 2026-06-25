# 子仓借鉴评估矩阵（SSOT）

## 使用说明

1. 每个候选项对应一行，不跨行合并多个能力点。
2. `决策` 仅允许：`adopt`、`observe`、`reject`。
3. `验收状态` 仅允许：`done`、`pending`、`blocked`。
4. `证据` 必须包含可复现命令或报告路径。
5. `回灌目标` 默认填写 `agent-dev-kit`，如需试跑可追加 `codex`。

## 当前记录（全量治理）

| 日期 | 来源仓库 | 类别标签 | 候选能力 | 价值 | 适配成本 | 风险 | 决策 | 验收状态 | 回灌目标 | 证据 |
|---|---|---|---|---|---|---|---|---|---|---|
| 2026-05-02 | superpowers | workflow-core | 生命周期流程主干（brainstorm/plan/verify/review） | 高 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/docs/workflows.md |
| 2026-05-02 | superpowers-zh | workflow-core | 中文触发词与流程表达标准化 | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/AGENTS.md |
| 2026-05-02 | OpenSpec | workflow-core | 变更工件命名和状态流转硬约束 | 高 | 中 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/workflows.md |
| 2026-05-02 | agency-agents-zh | agent-ecosystem | 角色职责矩阵与术语体系（角色覆盖丰富，保留为术语与职责参考，不直接并入核心） | 中 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/lead-agent-convergence-delivery.md |
| 2026-05-02 | agent-skills | agent-ecosystem | 技能触发路由与生命周期映射（流程完备，保留方法论参考） | 中 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/docs/agent-skill-catalog.md |
| 2026-05-02 | skills | agent-ecosystem | skills CLI 目录约定与安装入口（安装机制已吸收为兼容性约束） | 中 | 低 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/feature-delivery.md |
| 2026-05-02 | mattpocock-skills | agent-ecosystem | 小技能组合范式与 deprecated 分层治理 | 中 | 中 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/skill-curation-delivery.md |
| 2026-05-02 | hermes-collaboration-skill | agent-ecosystem | 多人协作文档模板与 runbook 化结构（文档范式已吸收，以 runbook 方式落地） | 中 | 低 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/optional-skills/adk-cross-team-handoff/SKILL.md |
| 2026-05-02 | Migrationed_skills | skill-pool | 历史技能池候选筛选机制（资产池价值高，保留为按需提取来源） | 中 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/skill-curation-delivery.md |
| 2026-05-02 | hermes-agent | delivery | 大型 Agent 工程目录职责与发布脚本治理（已吸收为大仓交付触点模板与收口约束） | 中 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/large-platform-delivery.md |
| 2026-05-02 | AUBB-Server | delivery | 业务闭环中的验证证据写法（已吸收为命令级 Evidence Index 交付标准） | 中 | 中 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/evidence-index-delivery.md |
| 2026-05-02 | arthas | delivery | 贡献规范与发布质量门槛模板（已吸收为评审分级与发布门禁标准） | 中 | 中 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/release-hardening.md |
| 2026-05-02 | ai-coding-guide | knowledge | 场景化工作流导览与风险提示清单（方法论导览价值高，已纳入 adopt） | 中 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/bugfix-delivery.md |
| 2026-05-02 | prompts | knowledge | 提示词资产的轻量演进机制（保留参考，不进入强约束） | 低 | 低 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/prompt-evolution-delivery.md |
| 2026-05-02 | auto-research | knowledge | 负结果留痕与复盘机制（研究/工程双场景留痕机制可复用） | 中 | 低 | 低 | adopt | done | agent-dev-kit | reports/weekly-change-report.md |
| 2026-05-02 | dotfiles | config | 最小变更 + 基线校验策略（配置基线思想已吸收为治理约束） | 中 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/config-baseline-governance.md |
| 2026-05-02 | codex | runtime-target | control/scripts/catalog/doctor 真实运行闭环验证 | 高 | 中 | 中 | adopt | done | codex, agent-dev-kit | reports/codex-pilot-report.md |
| 2026-05-02 | codex-cookbook | knowledge | Codex 实战模板与 cookbook 任务样例（经验模板已吸收，不并入 core 流程强约束） | 中 | 低 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/lead-agent-convergence-delivery.md |
| 2026-05-08 | workspace | knowledge | 维护指南（日常健康检查、adk 压实检查、生产级放行检查） | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/workspace-maintenance-guide.md |
| 2026-05-08 | workspace | delivery | GitLab Runner 安装配置（Debian/RHEL/Docker 三种方式） | 中 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/gitlab-runner-setup.md |
| 2026-05-08 | workspace | knowledge | Pilot 试跑完整证据链（六类试跑场景 artifact 记录） | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/codex-pilot-evidence.md |
| 2026-05-08 | workspace | knowledge | 27 条候选能力完整评估矩阵（含决策、验收状态、证据） | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/reference-adoption-matrix.md |
| 2026-05-08 | workspace | knowledge | "道法术器"四层方法论框架（哲学→组织→战术→工具） | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/best-practices-cookbook.md |
| 2026-05-08 | workspace | knowledge | 9 款工具速查表（30 秒决策矩阵 + 能力对比表） | 中 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/reference/tool-cheatsheet.md |
| 2026-05-08 | workspace | delivery | 子仓治理脚本完整使用手册（24+ 脚本用法） | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/runbooks/workspace-maintenance-guide.md |
| 2026-05-08 | workspace | adk-core | 意图路由表 + 子仓清单 + 优先级门禁治理全景 | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/workspace-governance.md |
| 2026-05-08 | superpowers | workflow-core | 贡献规范（94% PR 拒绝率策略） | 中 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/reference/engineering-agents.md |
| 2026-05-08 | workspace | workflow-core | Artifact 门禁协议模式（统一标签+状态+交接） | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/skills/adk-artifact-gating/SKILL.md |
| 2026-05-08 | workspace | workflow-core | Pilot 试跑框架模式（场景+证据+门禁） | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/skills/adk-pilot-framework/SKILL.md |
| 2026-05-08 | workspace | workflow-core | 子仓接入工作流模式（扫描+分析+决策） | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/skills/adk-intake-workflow/SKILL.md |
| 2026-05-12 | vibeflow | workflow-core | 8 阶段生命周期框架（Spark→Design→Tasks→Build→Review→Test→Ship→Reflect） | 高 | 中 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/workflows/lifecycle.md |
| 2026-05-12 | vibeflow | workflow-core | 状态机与恢复点（.vibeflow/state.json 持久化） | 高 | 中 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/workflows/lifecycle.md#statejson-规范 |
| 2026-05-12 | vibeflow | workflow-core | Gate 机制设计原则（4 问选择标准） | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/AGENTS.md |
| 2026-05-12 | vibeflow | workflow-core | 合同化 Tasks（输入/输出/验收标准） | 高 | 中 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/templates/artifacts/tasks-template.md |
| 2026-05-12 | vibeflow | workflow-core | 三维评审机制（价值/工程/设计） | 高 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/templates/artifacts/review-template.md |
| 2026-05-12 | vibeflow | workflow-core | TDD 集成（红-绿-重构流程） | 中 | 中 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/workflows/lifecycle.md |
| 2026-05-12 | vibeflow | workflow-core | Rules 分层目录结构（避免全局污染） | 中 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/rules/README.md |
| 2026-05-12 | vibeflow | workflow-core | Router 自动阶段检测（不采纳独立 Router persona，改用内置路由） | 中 | 高 | 中 | reject | done | agent-dev-kit | agent-dev-kit/references/orchestration-patterns.md; agent-dev-kit/scripts/skill-match.sh |
| 2026-05-12 | vibeflow | workflow-core | 复盘机制（Reflect skill） | 中 | 中 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/templates/LESSONS.md |
| 2026-05-20 | Trellis | reference | 多平台模板与任务状态上下文脚本体系（优先保留为参考，不直接纳入核心流程） | 中 | 中 | 中 | reject | done | agent-dev-kit | agent-dev-kit/docs/runbooks/optional-pilot-boundary.md |
| 2026-05-20 | agent-browser | tooling | 浏览器自动化 CLI 的快照压缩与 ref 交互模式（先验证可迁移性，再决定是否核心采纳） | 中 | 中 | 中 | reject | done | agent-dev-kit | agent-dev-kit/docs/runbooks/optional-pilot-boundary.md |
| 2026-05-21 | workspace | adk-core | Codex Skills 岗位 SOP 模型（Skill/Agent/Sub-agent/MCP 分层、description discovery、worker contract、入口长度门禁） | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/skill-agent-runtime-model.md; agent-dev-kit/templates/planning/worker-contract.md; agent-dev-kit/tests/test_skill_sop_quality.sh |
| 2026-05-21 | workspace | adk-core | Agent 记忆与 AAR 自我进化治理（四层记忆、memory candidate、风险审批、过期复验、lint 门禁） | 高 | 中 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/skills/adk-after-action-review/SKILL.md; agent-dev-kit/templates/memory/memory-candidate.md; agent-dev-kit/scripts/check-memory-governance.sh |
| 2026-05-21 | workspace | adk-core | 保真省 Token 与上下文读取治理（分层摘要、原文回退、高风险原文、raw evidence、token budget 门禁） | 高 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/skills/adk-token-context-governance/SKILL.md; agent-dev-kit/templates/context/tool-output-summary.md; agent-dev-kit/scripts/check-token-budget.sh |
| 2026-05-22 | workspace | adk-core | 上下文预算模式治理（极速/均衡/精确/审计、task_type/risk_level/read_tier、CTX_PRESSURE 交接约束） | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/templates/context/context-budget-profile.md; agent-dev-kit/docs/runbooks/token-context-governance.md; agent-dev-kit/tests/test_token_context_governance.sh |
| 2026-05-22 | codex-agent-mem | memory-context | Codex 项目连续性记忆与 compact context pack（先观察，不默认引入 SQLite/MCP 依赖） | 中 | 中 | 中 | observe | done | agent-dev-kit | agent-dev-kit/agents/architecture-planner/AGENTS.md; agent-dev-kit/skills/adk-token-context-governance/SKILL.md; agent-dev-kit/docs/runbooks/token-context-governance.md; reports/observe-secondary-intake-packages-2026-05-22.md |
| 2026-05-22 | code-session-memory | memory-search | 跨工具会话索引与语义检索（先观察，不默认接入 embedding/向量库链路） | 中 | 中 | 中 | observe | done | agent-dev-kit | agent-dev-kit/agents/architecture-planner/AGENTS.md; agent-dev-kit/skills/adk-token-context-governance/SKILL.md; agent-dev-kit/docs/runbooks/token-context-governance.md; reports/observe-secondary-intake-packages-2026-05-22.md |
| 2026-05-25 | OpenAI Developers | adk-core | Codex Customization 与 reasoning model 指南（skill/plugin 分层、progressive disclosure、上下文压缩、tool description 下沉） | 高 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/docs/reference/openai-developers-reference.md; agent-dev-kit/manifests/official_docs_freshness_gates.json; agent-dev-kit/scripts/check-openai-developers-governance.sh |
| 2026-05-25 | OpenAI Developers | quality-gate | Agents tracing 与 agent evals（trace summary、routing/governance/completion eval suites、失败样本进入回归） | 高 | 中 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/manifests/eval_suites.json; agent-dev-kit/manifests/trace_eval_contracts.json; agent-dev-kit/tests/test_openai_developers_governance.sh |
| 2026-05-25 | OpenAI Developers | runtime-boundary | Apps SDK tool hint 审核规则迁移到 MCP/tool 安全契约（readOnly/destructive/openWorld、PII、dry-run、approval） | 高 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/manifests/skill_mcp_dependencies.json; agent-dev-kit/manifests/slash_command_runtime_audits.json; agent-dev-kit/docs/runbooks/openai-developers-governance.md |
| 2026-05-25 | OpenAI Developers | agent-ecosystem | Agents SDK 起点分类作为长期参考（agent definitions/state/sandbox/handoffs/guardrails/tools/observability），不重写现有 adk 生命周期 | 中 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/docs/reference/openai-developers-reference.md; agent-dev-kit/manifests/subagent_contracts.json |
| 2026-05-25 | OpenAI Developers | runtime-policy | Codex config/reference、requirements.toml 与 sandbox defaults 迁移为运行态策略门禁（配置边界、不可覆盖策略、full-access 禁止默认） | 高 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/manifests/adk_runtime_policy_gates.json; agent-dev-kit/scripts/check-openai-developers-governance.sh; agent-dev-kit/docs/runbooks/openai-developers-governance.md |
| 2026-05-25 | OpenAI Developers | runtime-hooks | Codex Hooks 事件契约迁移为 hook runtime audit（event 支持字段、matcher 生效性、trust、日志脱敏、并发风险） | 高 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/manifests/hooks_runtime_audits.json; agent-dev-kit/docs/reference/openai-developers-reference.md; agent-dev-kit/tests/test_openai_developers_governance.sh |
| 2026-05-25 | OpenAI Developers | runtime-mcp | Codex-as-MCP server 迁移为 runner/reply 合同（threadId、cwd、sandbox、approval-policy、profile、审批关联） | 中 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/manifests/adk_runner_contracts.json; agent-dev-kit/scripts/check-openai-developers-governance.sh |
| 2026-05-25 | OpenAI Developers | plugin-delivery | Codex plugin build 与 marketplace metadata 迁移为 P2 包装契约（plugin.json、skills 路径、source containment、安装/认证策略） | 中 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/manifests/plugin_marketplace_contracts.json; agent-dev-kit/docs/reference/openai-developers-reference.md |
| 2026-05-25 | OpenAI Developers | runtime-policy | Codex Rules 与危险设置迁移为 P0 门禁（prefix_rule inline tests、network proxy、Unix socket、live web search、prompt-injection 风险） | 高 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/manifests/adk_rules_contracts.json; agent-dev-kit/manifests/adk_runtime_policy_gates.json; agent-dev-kit/scripts/check-openai-developers-governance.sh |
| 2026-05-25 | OpenAI Developers | runtime-api | Codex App Server API 迁移为 read/write/destructive/open-world 分级合同（shellCommand/process/fs/config/plugin/MCP） | 高 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/manifests/adk_runtime_api_contracts.json; agent-dev-kit/docs/runbooks/openai-developers-governance.md |
| 2026-05-25 | OpenAI Developers | memory-context | Context Engineering session memory 迁移为上下文状态合同（latest goal、invalidated goals、per-issue summary、error isolation、raw fallback） | 高 | 低 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/manifests/context_state_contracts.json; agent-dev-kit/docs/runbooks/token-context-governance.md |
| 2026-05-25 | OpenAI Developers | docs-tooling | OpenAI Docs MCP quickstart 迁移为跨工具官方文档查询策略（Codex/VS Code/Cursor/Claude Code，MCP first，官方域名 fallback） | 中 | 低 | 低 | adopt | done | agent-dev-kit | agent-dev-kit/manifests/official_docs_mcp_tooling.json; agent-dev-kit/docs/reference/openai-developers-reference.md |
| 2026-05-25 | OpenAI Developers | api-runner | Responses API migration 作为 P2 watch，仅登记未来 API-backed runner 状态迁移要求，不立即重写 adk | 中 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/manifests/context_state_contracts.json; agent-dev-kit/docs/reference/openai-developers-reference.md |
| 2026-05-26 | OpenAI Developers | workflow-quality | Structured Outputs、Function Calling strict、Tool Search、Codex Automations/Worktrees 与 Agent Improvement Loop 迁移为 schema 产物、lazy-loading、report-only automation、worktree handoff 和 trace-feedback-eval-handoff 闭环 | 高 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/manifests/structured_output_contracts.json; agent-dev-kit/manifests/tool_search_contracts.json; agent-dev-kit/manifests/automation_worktree_contracts.json; agent-dev-kit/manifests/agent_improvement_loop_contracts.json; agent-dev-kit/scripts/check-openai-developers-governance.sh |
| 2026-05-26 | OpenAI Developers | pr-review-governance | Codex GitHub Action、Codex Code Review SDK 与 Skills API operational practices 迁移为 CI/PR review runner、untrusted PR secret 隔离、inline anchoring、skill version pin 和 deterministic tiny CLI 门禁 | 高 | 中 | 中 | adopt | done | agent-dev-kit | agent-dev-kit/manifests/pr_review_governance_contracts.json; agent-dev-kit/manifests/skill_reproducibility_contracts.json; agent-dev-kit/skills/adk-code-review-loop/SKILL.md; agent-dev-kit/scripts/check-openai-developers-governance.sh |
| 2026-05-27 | OpenAI Developers | context-token | Prompt Caching 与当前模型目录迁移为短期 freshness gate、静态前缀/动态尾部上下文布局和 cached-token 观测候选 | 高 | 低 | 中 | adopt | done | agent-dev-kit | reports/openai-developers-adoption-candidates-2026-05-27.md; agent-dev-kit/manifests/official_docs_freshness_gates.json |
| 2026-05-27 | OpenAI Developers | agent-orchestration | Agents SDK handoffs vs agents-as-tools 迁移为 ADK 子代理/worker 所有权术语候选 | 高 | 中 | 中 | adopt | done | agent-dev-kit | reports/openai-developers-adoption-candidates-2026-05-27.md; agent-dev-kit/docs/reference/openai-developers-reference.md |
| 2026-05-27 | OpenAI Developers | quality-gate | Graders 与 Optimize Prompts golden examples 迁移为 routing/prompt 变更前的正负样例 eval 候选 | 高 | 中 | 低 | adopt | done | agent-dev-kit | reports/openai-developers-adoption-candidates-2026-05-27.md; agent-dev-kit/manifests/eval_suites.json |
| 2026-05-27 | OpenAI Developers | workflow-quality | Codex iterative repair loop 迁移为 Review->Repair->Validate 闭环修复候选，完成声明必须绑定验证证据 | 高 | 中 | 低 | adopt | done | agent-dev-kit | reports/openai-developers-adoption-candidates-2026-05-27.md; agent-dev-kit/manifests/eval_suites.json |
| 2026-05-27 | OpenAI Developers | context-token | Prompt engineering roles/formatting 迁移为 developer/user/context/tool-output 指令层级和动态上下文边界合同 | 高 | 低 | 中 | adopt | done | agent-dev-kit | reports/openai-developers-adoption-candidates-2026-05-27-batch2.md; agent-dev-kit/manifests/context_state_contracts.json |
| 2026-05-27 | OpenAI Developers | workflow-quality | Model optimization workflow 与 eval-driven system design 迁移为 eval-baseline-first 优化闭环和升级阶梯 | 高 | 中 | 中 | adopt | done | agent-dev-kit | reports/openai-developers-adoption-candidates-2026-05-27-batch2.md; agent-dev-kit/manifests/agent_improvement_loop_contracts.json |
| 2026-05-27 | OpenAI Developers | quality-gate | Agentic governance test dataset 与 stored completion monitoring 迁移为 guardrail 正负样例和脱敏会话回归监控门禁 | 高 | 中 | 中 | adopt | done | agent-dev-kit | reports/openai-developers-adoption-candidates-2026-05-27-batch2.md; agent-dev-kit/manifests/eval_suites.json; agent-dev-kit/manifests/trace_eval_contracts.json |
| 2026-05-27 | OpenAI Developers | runtime-policy | Model selection guide 迁移为 KPI/SLO、成本、延迟、版本 pin、A/B 和 rollback 决策记录 | 高 | 中 | 中 | adopt | done | agent-dev-kit | reports/openai-developers-adoption-candidates-2026-05-27-batch2.md; agent-dev-kit/manifests/model_selection_decision_records.json |
| 2026-05-27 | OpenAI Developers | delivery | AI-native engineering team 文档交付建议迁移为文档 freshness、系统图和 release summary 交付证据候选 | 中 | 低 | 低 | adopt | done | agent-dev-kit | reports/openai-developers-adoption-candidates-2026-05-27-batch2.md; agent-dev-kit/docs/reference/openai-developers-reference.md |
| 2026-05-28 | OpenAI Developers | runtime-policy | Data controls /v1/responses 迁移为数据保留、ZDR、background mode、remote MCP、hosted container 与 owner approval 状态合同 | 高 | 中 | 中 | adopt | done | agent-dev-kit | reports/openai-developers-adoption-candidates-2026-05-28.md; agent-dev-kit/manifests/data_retention_state_contracts.json |
| 2026-05-28 | OpenAI Developers | api-runner | Responses statefulness 迁移为 previous_response_id、Conversation state、manual replay、encrypted reasoning、store=false 与 call_id 关联合同 | 高 | 中 | 中 | adopt | done | agent-dev-kit | reports/openai-developers-adoption-candidates-2026-05-28.md; agent-dev-kit/manifests/context_state_contracts.json; agent-dev-kit/manifests/data_retention_state_contracts.json |
| 2026-05-28 | OpenAI Developers | context-token | Prompt cache retention 迁移为 in_memory/24h/model_default 策略、模型支持 freshness、stable/dynamic 布局和 cache-miss 行为保持合同 | 高 | 低 | 中 | adopt | done | agent-dev-kit | reports/openai-developers-adoption-candidates-2026-05-28.md; agent-dev-kit/manifests/prompt_cache_policy_contracts.json; agent-dev-kit/manifests/model_selection_decision_records.json |
| 2026-06-15 | OpenAI Developers | runtime-policy | Codex config、permissions 与 memories 迁移为项目配置禁覆盖、permission profile、granular approval 和 memory runtime 门禁 | 高 | 中 | 中 | adopt | done | agent-dev-kit | reports/openai-developers-runtime-capability-candidates-2026-06-15.md; agent-dev-kit/manifests/adk_runtime_policy_gates.json; agent-dev-kit/scripts/check-openai-runtime-capabilities.sh |
| 2026-06-15 | OpenAI Developers | agent-orchestration | Codex subagents runtime 迁移为 max threads、max depth、job runtime fallback、nested subagent policy 与委托证据字段 | 高 | 中 | 中 | adopt | done | agent-dev-kit | reports/openai-developers-runtime-capability-candidates-2026-06-15.md; agent-dev-kit/manifests/subagent_contracts.json; agent-dev-kit/scripts/check-openai-runtime-capabilities.sh |
| 2026-06-24 | scale-engine | workflow-core | AI Agent 治理运行时参考（gates/evidence/context/queue 机制持续跟踪；hook/orchestrator 不自动启用） | 高 | 中 | 中 | observe | done | llm_agent, agent-dev-kit | agent-dev-kit/agents/security-compliance-reviewer/AGENTS.md; agent-dev-kit/skills/adk-intake-workflow/SKILL.md; agent-dev-kit/docs/runbooks/upstream-intake.md; reports/observe-secondary-intake-packages-2026-06-24.md; reports/oss-analysis-hongmaple-scale-engine-2026-06-24.md; reports/oss-absorption-plan-hongmaple-scale-engine-2026-06-24.md; reports/oss-deep-assessment-hongmaple-scale-engine-2026-06-25.md; reports/oss-security-review-hongmaple-scale-engine-2026-06-24.md |
| 2026-06-25 | scale-engine | workflow-quality | harness/loop readiness 证据模型迁移为 report-only 合同（DiagnosticLoop、AgentLoopReadiness、failure replay 字段；runtime 禁用） | 高 | 低 | 中 | adopt | done | llm_agent, agent-dev-kit | reports/oss-loop-readiness-hongmaple-scale-engine-2026-06-25.md; manifests/loop_readiness_contracts.json; scripts/check-loop-readiness.sh |
| 2026-06-25 | scale-engine | workflow-quality | progressive governance 与 resource lifecycle 迁移为 report-only 合同（风险分级、资源类型、Git policy、runtime 禁用） | 高 | 低 | 中 | adopt | done | llm_agent, agent-dev-kit | reports/oss-governance-contracts-hongmaple-scale-engine-2026-06-25.md; manifests/scale_engine_governance_contracts.json; scripts/check-scale-engine-governance.sh |
| 2026-06-25 | scale-engine | adk-core | tool/skill evidence plan、memory maintenance、verification command safety 与 code intelligence fallback 迁移为 ADK report-only 契约 | 高 | 中 | 中 | adopt | done | agent-dev-kit | reports/oss-adk-optimization-hongmaple-scale-engine-2026-06-25.md; agent-dev-kit/manifests/tool_skill_evidence_contracts.json; agent-dev-kit/scripts/check-tool-skill-evidence-contracts.sh; scripts/check-adk-tool-skill-evidence-contracts.sh; agent-dev-kit/skills/adk-runtime-router/SKILL.md; agent-dev-kit/skills/adk-verification-before-completion/SKILL.md; agent-dev-kit/skills/adk-memory-curator/SKILL.md; agent-dev-kit/skills/adk-token-context-governance/SKILL.md |
| 2026-06-15 | OpenAI Developers | agent-ecosystem | Codex glossary 迁移为 agent/skill/plugin/automation/worktree/MCP server/permission profile 术语漂移控制 | 中 | 低 | 低 | adopt | done | agent-dev-kit | reports/openai-developers-runtime-capability-candidates-2026-06-15.md; agent-dev-kit/manifests/codex_surface_terms.json; agent-dev-kit/scripts/check-openai-runtime-capabilities.sh |
| 2026-05-29 | karpathy-wiki | knowledge | LLM Wiki 三层知识编译模型迁移为 raw sources、maintained wiki、schema 与 ingest/query/lint 合同 | 高 | 中 | 中 | adopt | done | agent-dev-kit | reports/external-agent-pattern-adoption-candidates-2026-05-29.md; agent-dev-kit/manifests/external_agent_pattern_contracts.json |
| 2026-05-29 | compound-engineering | workflow-quality | Plan->Delegate->Assess->Codify 迁移为交付后 reusable pattern / do-not-promote / owner review / rollback 决策门禁 | 高 | 中 | 中 | adopt | done | agent-dev-kit | reports/external-agent-pattern-adoption-candidates-2026-05-29.md; agent-dev-kit/manifests/external_agent_pattern_contracts.json |
| 2026-05-29 | claude-mem | memory-context | 三层 memory search 迁移为 search index、timeline context、observation details 渐进披露合同 | 高 | 中 | 高 | adopt | done | agent-dev-kit | reports/external-agent-pattern-adoption-candidates-2026-05-29.md; agent-dev-kit/manifests/external_agent_pattern_contracts.json |
| 2026-05-29 | caveman | context-token | 低 token 输出 profile 迁移为显式触发、技术信息保真、安全例外和恢复条件合同 | 中 | 低 | 中 | adopt | done | agent-dev-kit | reports/external-agent-pattern-adoption-candidates-2026-05-29.md; agent-dev-kit/manifests/external_agent_pattern_contracts.json |
| 2026-05-29 | External Agent Patterns | security-supply-chain | 第三方 agent/plugin/memory/skill 候选迁移为 source、license、install surface、hooks、worker、MCP、retention、deny-path、rollback 审查合同 | 高 | 中 | 高 | adopt | done | agent-dev-kit | reports/external-agent-pattern-adoption-candidates-2026-05-29.md; agent-dev-kit/manifests/external_agent_pattern_contracts.json; agent-dev-kit/scripts/check-external-agent-patterns.sh |
| 2026-05-29 | karpathy-wiki | knowledge | LLM Wiki 三层模型实际落地为 knowledge compile runbook、note 模板和 `devkit.sh knowledge-compile` 门禁 | 高 | 中 | 中 | adopt | done | agent-dev-kit | reports/adk-capability-uplift-implementation-2026-05-29.md; agent-dev-kit/docs/runbooks/knowledge-compile-model.md; agent-dev-kit/templates/memory/knowledge-compile-note.md; agent-dev-kit/scripts/check-knowledge-compile-model.sh |
| 2026-05-29 | compound-engineering | workflow-quality | Codify after delivery 实际接入 AAR 与完成前验证，要求 reusable / do-not-promote / owner review / rollback 决策证据 | 高 | 中 | 中 | adopt | done | agent-dev-kit | reports/adk-capability-uplift-implementation-2026-05-29.md; agent-dev-kit/skills/adk-after-action-review/SKILL.md; agent-dev-kit/skills/adk-verification-before-completion/SKILL.md; agent-dev-kit/templates/governance/codify-decision.md |
| 2026-06-01 | compound-engineering + karpathy-skills | workflow-quality | 补强 Codify next-task friction、Knowledge freshness/duplicate concept lint 与 reuse-before-rebuild 新资产准入门禁 | 高 | 低 | 中 | adopt | done | agent-dev-kit | reports/external-agent-pattern-optimization-2026-06-01.md; agent-dev-kit/templates/governance/reuse-before-rebuild-decision.md; agent-dev-kit/scripts/check-reuse-before-rebuild.sh |
| 2026-05-29 | claude-mem | memory-context | 三层 memory search 实际落地为只读渐进披露 runbook、memory search result 模板和 context experience 门禁 | 高 | 中 | 高 | adopt | done | agent-dev-kit | reports/adk-capability-uplift-implementation-2026-05-29.md; agent-dev-kit/docs/runbooks/token-context-governance.md; agent-dev-kit/templates/context/memory-search-result.md; agent-dev-kit/scripts/check-context-experience-patterns.sh |
| 2026-05-29 | caveman | context-token | 低 token profile 实际落地为显式触发模板、安全例外、恢复条件和 token budget 资产计数门禁 | 中 | 低 | 中 | adopt | done | agent-dev-kit | reports/adk-capability-uplift-implementation-2026-05-29.md; agent-dev-kit/templates/context/low-token-profile.md; agent-dev-kit/scripts/check-token-budget.sh; agent-dev-kit/tests/test_token_context_governance.sh |
| 2026-05-29 | agent-dev-kit | adk-core | 外部模式从治理契约推进到可执行入口：`devkit.sh` 子命令、顶层 `check-all` wrapper、回归测试和 capability uplift test | 高 | 低 | 低 | adopt | done | agent-dev-kit, llm_agent | reports/adk-capability-uplift-implementation-2026-05-29.md; agent-dev-kit/scripts/devkit.sh; agent-dev-kit/tests/test_capability_uplift.sh; scripts/check-adk-codify-governance.sh; scripts/check-adk-knowledge-compile-model.sh; scripts/check-adk-context-experience-patterns.sh |

## 模板

| 日期 | 来源仓库 | 类别标签 | 候选能力 | 价值 | 适配成本 | 风险 | 决策 | 验收状态 | 回灌目标 | 证据 |
|---|---|---|---|---|---|---|---|---|---|---|


## agent-browser（浏览器自动化 CLI）

**来源**: https://github.com/vercel-labs/agent-browser
**版本**: v0.27.0
**语言**: Rust
**Stars**: 33k+
**评估日期**: 2026-05-15
**策略**: observe-first

### 优点

1. **Rust 原生高性能** — 浏览器操作延迟极低
2. **Accessibility-tree 快照** — 用 @eN ref 交互，200-400 tokens 即可描述页面
3. **CDP 直连** — 不依赖 Playwright/Puppeteer，更轻量
4. **CLI 原生** — 一行命令完成 open/snapshot/click/fill/screenshot
5. **Skills 系统** — 内置 core/slack/electron/dogfood 等技能
6. **Chrome for Testing** — 自动下载管理浏览器版本

### adk 借鉴点

1. 浏览器自动化 skill 设计模式
2. 快照压缩策略（Accessibility-tree vs raw HTML）
3. @eN ref 交互范式
4. CLI-first 的工具设计哲学

### 当前状态

- 已安装全局命令 `agent-browser`
- 已下载 Chrome 148.0.7778.167
- 测试通过：open/snapshot/screenshot/close
