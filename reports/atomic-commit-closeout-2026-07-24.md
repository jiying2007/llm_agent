# Atomic Commit Closeout：2026-07-24

## Authorization and Scope

Human owner 明确授权：

- ADK 4 个、root 1 个本地原子 commit；
- 逐提交 staged-tree 验证；
- 不 push、不建 PR、不 merge、不 rebase；
- 不执行 `agent-dev-kit -> ~/codex -> ~/.codex` source-to-live；
- 不清理、不暂存、不提交既有参考治理、observe 子仓、研究目录和 cache dirty；
- 发现未知冲突立即停止。

实际执行未扩大上述权限。

## Local Commits

| Order | Repository | Commit | Subject |
|---:|---|---|---|
| 1 | agent-dev-kit | `40246e4` | `feat(security): 完善 MCP 与 Skill 维护门禁` |
| 2 | agent-dev-kit | `172f964` | `feat(eval): 增加真实仓库运行时证据门禁` |
| 3 | agent-dev-kit | `bb86bff` | `feat(field): 完善量产现场证据模板` |
| 4 | agent-dev-kit | `54a4d7f` | `fix(cli): 收紧 Python 与验证重试边界` |
| 5 | llm_agent | `8a4a3ee` | `feat(governance): 集成 M5 与聚合门禁证据` |

提交后 ADK 工作树和 index 均 clean；root index 为空，Root-1 路径均 clean。
root 仍保留用户原有参考治理、三个 known-dirty observe 子仓、研究目录、cache
和历史报告，不纳入上述提交。

## Per-Commit Gate Evidence

| Commit | Staged-tree Gate | Result |
|---|---|---|
| `40246e4` | ecosystem checker、negative fixtures、strict asset validation | pass；479 checks，runtime disabled |
| `172f964` | repository runtime contract/plan、quick regression | pass；quick 19/19，network deny，owner approval required |
| `bb86bff` | strict assets、quick regression | pass；quick 19/19 |
| `54a4d7f` | Python launcher、workflow、strict validation、quick regression | pass；quick 20/20 |
| `8a4a3ee` | root docs sync、独立 temporary staged-tree regression | pass；17/17 |

Root-1 首次 staged-tree regression 曾以 16/17 失败，准确发现 staged gitlink
`54a4d7f` 与 `adk.lock` 中旧 commit 不一致。只同步机械锁字段后重新构建
temporary staged tree，17/17 通过。该负结果没有被跳过或用 baseline 绕过。

## Clean-HEAD ADK Gates

| Command | Result |
|---|---|
| `tests/run_all.sh --timing-json /tmp/adk-clean-head-full-20260724.json` | 57/57 pass，371.049 秒 |
| `scripts/devkit.sh security check --summary-json` | pass，805 files，0 failure |
| `scripts/devkit.sh release check --summary-json` | pass，RC5，0 failure |
| `scripts/run-local-ci-parity.sh --python all --mode quick` | Python 3.11/3.12 各 20/20；dependency audit 均无已知漏洞 |

宿主机默认 Python 3.8.10 的直接结果仍只视为 development evidence；受支持
Python 证据来自受控 Docker parity。容器 source mount 只读、gate network
为 none、无 credentials、无 release authority。

## Post-Commit Root Full Gate

证据：
`reports/terminal-maturity-check-all-post-commit-2026-07-24.json`

- total：59
- pass：58
- fail：1
- elapsed：920 秒
- same-run reuse：6，`eligible=true`
- 唯一失败：`check-current-status-consistency.sh`

已通过的关键门禁包括：

- ADK harden readiness；
- ADK performance ops；
- root regression；
- evidence bundle；
- Software M5 readiness；
- strict subrepo state；
- workspace entrypoints；
- token、security、runtime health、pilot 与 reference governance gates。

提交后 `check-subrepo-state.sh` 为：

- clean=5；
- known-dirty=3；
- unexpected-dirty=0；
- strict ADK clean。

## Remaining Intentional Boundary

`reports/current-status.md` 是 2026-07-19 最近一次已完成 source-to-live 的产品
基线，仍锚定旧 ADK evidence commit。当前源码/gitlink/`adk.lock` 已前进到
`54a4d7f`，且 field-readiness Skill 属于 mapped asset；由于本轮授权明确排除
source-to-live，不能：

- 把旧 live evidence 改写成已应用；
- 把 `current-status.md` 机械更新为新 commit 后伪报运行态一致；
- 重写 release evidence 或 artifact digest；
- 通过 baseline、skip 或历史 cache 关闭该失败。

因此 58/59 是授权边界内的正确终态，不是源码回归。若未来单独授权
source-to-live，应按完整 build/doctor/plan/dry-run/apply/routing/check 链路产生
新证据，再刷新 `current-status.md` 和 release evidence。

## Quality-Gate Decisions

- Scope check：pass，五个 commit 各自聚焦，Root-1 只增加机械 `adk.lock`
  同步依赖。
- Review findings：local commit blocker=0、major=0、minor=0；
  release/live blocker=1（未授权 source-to-live）。
- Config drift：
  - MCP/Skill security 维持 optional、disabled-by-default；
  - repository runtime 保持 execution disabled、network deny、owner approval；
  - M5 policy 增加真实仓库/runtime/field blockers，阻止 fixture 假阳性；
  - same-run reuse 绑定同父进程、成功 producer、workspace fingerprint 和 TTL。
- Skill decision：field-readiness 增强为 `global-ready` 的既有 P0
  release-closure asset；领域启用仍受 profile/route 控制。
- Breaking change：无默认 CLI breaking change；旧 Python 默认只告警，
  `ADK_REQUIRE_SUPPORTED_PYTHON=1` 才 fail-fast。M5 收紧属于有意的错误放行
  防护。
- Core/optional：平台中立 contract/checker 进入 core；场景化 field/runtime
  adapter 保持 profile/optional 或 disabled-by-default。
- Human owner：当前用户负责本地 commit 授权；远端、source-to-live 和最终
  release 仍需新的显式授权。

## Final Decision

- Local atomic commit delivery：`pass`。
- Source implementation and clean-HEAD regression：`pass`。
- Remote delivery：`not-authorized`。
- Source-to-live/current-status consistency：`needs-fix-by-explicit-future-authorization`。
- Software M5 certification：仍为 `false`；真实 runtime/repository campaign、
  独立 repository/operator、30 天 field evidence 等现实门禁继续保留。

未执行 rollback。若后续需要回退，应先 revert root `8a4a3ee`，再按
`54a4d7f -> bb86bff -> 172f964 -> 40246e4` 逆序评估 ADK revert；不得 reset
或清理用户 dirty。
