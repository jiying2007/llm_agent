# Active Reference Repo 深度吸收建议

## 范围

- 日期：2026-07-06
- 范围：active 参考仓 `OpenSpec`、`oh-my-codex`、`planning-with-files`、`superpowers`、`vibeflow`、`scale-engine`
- 排除：`agent-dev-kit` 是应用/落地仓，不作为参考来源仓评估
- 读取状态：
  - `oh-my-codex`、`planning-with-files`、`scale-engine` 已快进到 upstream 最新
  - `OpenSpec`、`superpowers` 因 dirty + behind 只读 `origin/main` 差异
  - `vibeflow` 已在 upstream 最新，但本地仍 dirty

## 推荐吸收项

| Priority | Source | Candidate | Decision | Target |
|---|---|---|---|---|
| P0 | OpenSpec | canonical resolution parity：同一实体的 `status`、`validate`、`view`、`archive` 必须共用 resolver，并用 parity tests 防止命令各自分叉 | adapt | `agent-dev-kit` verification / script governance |
| P0 | vibeflow | overview freshness：`PROJECT.md`、`ARCHITECTURE.md`、`CURRENT-STATE.md` 三件套 + source hash + generated block hash + stale reasons | adapt | `adk-repo-drift-remediation` / context state contracts |
| P1 | planning-with-files | plan completeness guard：无 phase heading 不得报 0/0 complete；mixed status 格式逐字段取 max；gate 只在 explicit opt-in + in_progress + ledger advanced 时阻断 | adapt | `adk-planning-execution-loop` / context handoff |
| P1 | planning-with-files | plan attestation write-readback：plan hash 写入后必须 read-back verify；并发/legacy 模式给出 slug-mode 提示 | adapt | continuity attestation template / planning loop |
| P1 | vibeflow | browser verification evidence：UI 变更必须有真实浏览器计划、截图、console、network、a11y 与安全边界 | adapt, optional | frontend/UI verification gate |
| P2 | scale-engine | external skill ecosystem policy：第三方 skill 默认 review-required，记录 license、source revision、runtime boundary、required artifacts 和 domain routing | adapt | skill reproducibility / supply-chain contracts |

## 不建议立即吸收

| Source | Item | Reason |
|---|---|---|
| superpowers | v6.1 Codex portal packaging / hook stripping | 已在 Superpowers v6 报告中覆盖大部分 Codex packaging 和 hook 边界；剩余更像上游包发布细节，不应进 ADK core |
| OpenSpec | stores/worksets 大重构 | 价值高但体量过大，且本地 OpenSpec dirty + behind；应先单独做 OpenSpec-focused intake |
| oh-my-codex | HUD superseded status、Ralplan consensus review、autopilot handoff runtime | 多数已被 `adk-parallel-agent-governance`、`adk-code-review-loop`、tool-call policy 覆盖；剩余偏上游 runtime 内部状态机 |
| scale-engine | external setup installer / GBrain / Feishu / UI skill pack | 依赖和外部服务边界重，当前只适合吸收治理字段，不适合启用 runtime |

## 证据摘要

- OpenSpec `origin/main` 的 `fix-validate-view-resolution-parity` 设计明确指出根因是命令各自实现 resolution/validation 逻辑，修复策略是收敛到 canonical helper，并用 parity tests 固定。
- Vibeflow `vibeflow-wiki` 把长期项目上下文压成 3 个正式 overview 文件，并用 `.vibeflow/wiki-status.json` 记录 hash、stale 和 generated blocks，适合迁移为 ADK 文档新鲜度/漂移门禁。
- `planning-with-files/scripts/check-complete.sh` 对 Stop gate 处理了 opt-in、in_progress、block cap、ledger progress 和 false 0/0；`attest-plan.sh` 对 attestation 写入做了 read-back verification。
- Vibeflow browser testing skill 把 UI 验证拆成真实交互、console、network、screenshot、a11y 和安全边界，适合只吸收证据字段，不吸收外部 MCP runtime。
- Scale Engine 的 third-party skill policy 强调 review-required、license/source revision、not vendored、runtime boundaries，与 ADK supply-chain 能力一致但可补 domain routing 和 required artifacts。

## 建议 Codex Goal

```text
Goal: 将 active 参考仓 2026-07-06 深度筛选出的高价值实践，以最小漂移方式压实到 agent-dev-kit，并保持 agent-dev-kit 作为应用/落地仓而非参考源。

Scope:
- P0: 吸收 OpenSpec canonical resolution parity，形成 ADK 命令/脚本共享 resolver 与 parity test 门禁。
- P0: 吸收 Vibeflow overview freshness，形成项目长期上下文三件套与 stale/hash 证据合同。
- P1: 吸收 planning-with-files 的 plan completeness guard 与 attestation read-back verification，补强 planning execution / context handoff。
- P1: 仅以 evidence gate 方式吸收 Vibeflow browser verification，不启用外部 MCP/runtime。
- P2: 将 Scale Engine 第三方 skill domain policy 补入 skill supply-chain / reproducibility contracts。

Non-goals:
- 不把 agent-dev-kit 当参考仓同步或分析来源。
- 不启用或 vendor 任何外部 skill、hook、MCP、browser runtime、GBrain、Feishu/Lark、Scale runtime。
- 不处理 OpenSpec stores/worksets 大重构，除非另开 OpenSpec-focused intake。
- 不重置、stash 或覆盖 dirty 参考仓本地改动。

Success criteria:
- 每个采纳项都有 adoption-matrix 记录、source evidence、target asset 和验证命令。
- 新增或修改的 ADK 资产都有对应正/负 fixture、脚本检查或 quick test。
- `agent-dev-kit` 保持平台中立；外部 runtime 均为 method-only/report-only。
- `sync-subrepos.sh` 默认继续排除 `adk-core` landing repo。

Verification:
- rtk scripts/check-adoption-matrix-status.sh .
- rtk scripts/check-adoption-matrix-structured.sh .
- rtk scripts/check-doc-sync.sh .
- rtk scripts/check-skill-metadata.sh .
- rtk agent-dev-kit/scripts/devkit.sh validate --quick
- rtk bash agent-dev-kit/tests/run_all.sh --quick --max-failure-lines 20
- rtk scripts/check-token-budget.sh . --summary-json
- rtk git diff --check
- rtk git -C agent-dev-kit diff --check

Review artifacts:
- reports/reference-repo-deep-absorption-recommendations-2026-07-06.md
- reports/reference-repo-absorption-implementation-2026-07-06.md
- subrepos/adoption-matrix.md
- subrepos/adoption-matrix.jsonl

Blockers:
- OpenSpec/superpowers dirty + behind requires user decision before local worktree sync.
- Any proposed runtime integration, network installer, external service, browser automation beyond evidence schema requires explicit approval and separate security review.
```
