# 2026-07-11 Coding Skill 观察仓库吸收落地报告

- 状态：method-only absorbed + runtime-disabled
- 输入证据：`reports/external-coding-skill-repos-assessment-2026-07-11.md`、`reports/oss-score-report-2026-07-11.md`、`reports/oss-discovery-candidates-2026-07-11.jsonl`
- 落地目标：`agent-dev-kit` 现有 skill/runbook 与 `llm_agent` adoption/lifecycle 账本
- 禁止边界：不安装 skill/plugin，不 clone 新 submodule，不执行第三方 CLI，不启用 hook/MCP/memory/runtime，不写 `~/.codex`

## 决策矩阵

| Source | Lane | Decision | Absorbed Mechanism | Target Asset | Forbidden Action | Verification |
|---|---|---|---|---|---|---|
| `mattpocock/skills` | requirements-and-domain-modeling | adapt | 将 `implement` / `domain-modeling` 类实践抽象为实现前领域建模预检：术语、实体、状态、接口、数据流、边界样例 | `agent-dev-kit/skills/adk-requirements-triage/SKILL.md` | 不恢复全量 submodule，不复制外部 skill 文本 | `rtk bash agent-dev-kit/scripts/devkit.sh validate --strict` |
| `mattpocock/skills` + `superpowers` | review-contract | adapt | 将 review 上下文、spec verdict、quality verdict、cannot-verify-from-diff 和 out-of-scope suggestions 固化为 review 基线 | `agent-dev-kit/skills/adk-code-review-loop/SKILL.md` | 不把 reviewer 意见当自动修复命令 | `rtk bash agent-dev-kit/scripts/devkit.sh validate --strict` |
| `addyosmani/agent-skills` | lifecycle-gate | archive-adapt | 复核后未发现需要复制的完整生命周期流程；保留“只吸收新增 eval/security/release gate”的规则 | `agent-dev-kit/docs/runbooks/skill-curation-delivery.md` | 不重复已有 ADK 生命周期流程 | `rtk scripts/check-doc-sync.sh .` |
| `affaan-m/ECC` | runtime-security-review | observe-only | 记录 hook/MCP/memory/install surface 高风险，进入安全评审 lane | `agent-dev-kit/docs/runbooks/skill-curation-delivery.md`; `agent-dev-kit/manifests/external_agent_pattern_contracts.json` | 不安装 ECC，不启用 hooks/MCP/memory | `rtk scripts/check-adoption-matrix-status.sh .` |
| `alirezarezvani/claude-skills` | catalog-discovery | observe-only | 大型 skill pool 只按域抽样和供应链审查 | `agent-dev-kit/docs/runbooks/skill-curation-delivery.md` | 不全量导入 skill pool | `rtk scripts/check-oss-intake-ledger.sh .` |
| `jeremylongshore/claude-code-plugins-plus-skills` | catalog-discovery | observe-only | marketplace/catalog 只作为候选线索 | `agent-dev-kit/docs/runbooks/skill-curation-delivery.md` | 不执行 CLI，不安装插件 | `rtk scripts/check-oss-intake-ledger.sh .` |
| awesome 系列索引仓 | catalog-discovery | archive-only | 只保留 discovery feed 和 license/owner 线索 | `subrepos/adoption-matrix.md` | 不作为 runtime 或默认依赖 | `rtk scripts/check-adoption-matrix-structured.sh .` |
| `ComposioHQ/composio` | runtime-security-review | reject-for-subrepo | hosted service、凭证和 open-world writes 仅在具体集成需求下单独安全评审 | adoption matrix | 不纳入普通子仓长期跟踪 | `rtk scripts/check-adoption-matrix-status.sh .` |
| `multica-ai/andrej-karpathy-skills` | archive-only | reject | 核心原则已由 AGENTS/ADK 覆盖，且 license 不清晰 | adoption matrix | 不恢复活跃仓 | `rtk scripts/check-adoption-matrix-status.sh .` |

## 本轮落地

- `adk-requirements-triage` 增加 Domain Model 预检：非纯配置/文案任务在实现前必须列出术语、实体、状态、接口、数据流和边界样例。
- `adk-code-review-loop` 增加 Review context 固定：缺 Requirement / Domain Model / Verification baseline 时，不得给 spec-compliance pass。
- `skill-curation-delivery` 增加观察仓库抽样吸收 lane，统一处理 P0/P1/P2 观察仓库和高风险 runtime 仓库。
- `subrepos/adoption-matrix.*` 与 `manifests/subrepo_lifecycle.json` 记录本轮 method-only 吸收证据。

## 不采纳项

- 不新增 `adk-security-supply-chain` core skill；当前 ADK 源树没有该 core skill，本轮复用已有 external pattern / reproducibility 合同和 runbook。
- 不把 `agent-skills`、`mattpocock/skills`、`ECC`、awesome 索引仓恢复为 active-reference subrepo。
- 不安装、执行或包装任何第三方 CLI / plugin / MCP。

## 后续

若要把某个观察仓升级为 active-reference，需要单独补：analysis、duplicate check、security review、deep assessment、onboarding plan、reviewed local clone，并获得 materialization approval。
