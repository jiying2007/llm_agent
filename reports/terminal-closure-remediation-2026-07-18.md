# 终态闭环优化执行记录（2026-07-18）

## 目标与边界

- goal_statement：修复本地可落地的终态审计缺陷，使门禁、实现、manifest、schema、文档和测试对同一合同给出一致且可复现的结论。
- scope_write：根仓性能包装门禁与本报告；`agent-dev-kit` 的 Harness、性能合同、安装合同、manifest schema、安全基线、测试和对应 change 工件。
- must_not_touch：现有参考子仓 dirty 内容、git history rewrite、远端分支、真实运行时凭证、付费 campaign、`~/codex` 和 `~/.codex` 用户运行资产；本地 commit/version/rehearsal 后续已获 owner 明确授权。
- 非目标：不伪造远程 CI、第二操作者、独立仓、30 天试点、真实 runtime 或 field evidence；不通过弱化预算、放宽 dirty policy 或篡改成熟度状态制造通过。

## 验收矩阵

| 阶段 | Done criteria | 验证 | 证据位置 |
|---|---|---|---|
| S1 计划与基线 | dirty 边界、失败根因、retry 和外部阻塞已记录 | change governance、git diff/status | 本报告与 ADK change 工件 |
| S2 Harness 真实性 | 否定权限文本不能 pass；未来/过期验证时间不能视为新鲜 | Harness 红灯/绿灯与完整定向测试 | Harness tests、review-findings |
| S3 性能门禁真实性 | 根包装器必须执行 strict timing budget；超预算 fixture 必须失败 | 性能包装器正负测试 | 根测试与 ADK performance checker |
| S4 契约一致性 | install 默认模式、实现、CLI、文档和 schema 一致；错误模式 fail-closed | schema/manifest/install/docs tests | ADK tests 与 change evidence |
| S5 安全维护基线 | Python/依赖支持窗口明确；本地与 CI 质量入口一致且可执行 | strict/security/release/quality checks | CI、pyproject、验证报告 |
| S6 集成回归 | ADK 定向、quick、full、受控本地 CI parity 和根仓适用门禁完成 | tests/run_all、local CI runner、check-all、final-ready | verification-evidence |
| S7 外部闭环 | runtime campaign、独立仓、第二操作者、30 天现场证据真实存在 | software-m5 certifier | 保持 blocker，不能由本轮本地代码替代 |

## Task State

- Current stage：S6 本地 commit/version/rehearsal 与根产品门禁完成；S7 外部认证闭环 blocked。
- Last completed checkpoint：ADK RC3 exact-commit 双构建、rc.2 → rc.3 rehearsal、ADK full 54/54、根 quick 56/56 与 full 62/62 全部通过。
- Current blocker：仅剩真实 runtime、远程 CI/attestation、独立操作者和长期现场证据；不影响本地 RC3 候选闭环，也不能被本地证据替代。
- Changed scope：owner 授权本地 commit/version/rehearsal；未授权 push、tag、publish 或 live apply。
- Retry budget：同一失败根因最多 2 次；第三次前必须 replan 或 split。
- Staleness threshold：45 分钟或完成一个阶段后更新一次。
- Heartbeat：每个阶段至少记录一条新测试或新证据。
- Stop condition：`pass`、`replan`、`split`、`blocked`、`abort`。

## Goal Closure

- completion_claim：本地 RC3 source/evidence、制品、回滚演练和根产品基线已实现并验证；不声明 remote-release-ready、M5 certified 或 terminal maturity。
- claimant：Codex。
- verifier：`adk-verification-before-completion` 与仓库机械门禁。
- required_evidence：至少一条改前红灯、对应绿灯、定向回归、ADK full、根仓集成结果、breaking/rollback 说明。
- open_items：push 与远程 Python 3.11/3.12 CI/attestation；真实双 runtime campaign；独立仓/第二操作者/30 天 field evidence；最终 3.1.0 promotion。
- decision：local-rc3-release-candidate-closed / external-certification-blocked。

## Repair Ledger

| Finding | Passing scope to preserve | Repair action | Minimal rerun | Rollback anchor |
|---|---|---|---|---|
| Harness 否定语义假通过 | secret redaction、report-only、bounded scan | 结构化权限声明优先；启发式证据拒绝否定语境 | Harness test | 当前 dirty Harness change diff |
| `last_verified_at` 只验语法 | owner 缺失降级行为 | 加未来拒绝和 freshness window | Harness test | readiness contract v1 |
| quick 性能外门禁假绿 | benchmark/full budget | 包装器调用 strict timing checker并增加超预算负例 | performance gate test | 当前 wrapper |
| install `symlink` 漂移 | copy transaction/rollback | 统一 default/supported mode 为 copy并强化 schema | product maturity tests | rc.2 install contract |
| Python/依赖基线过旧 | Python 3.12 CI与 safe_load | 发布下限提升到 3.11，固定 PyYAML/jsonschema，doctor 显式报告环境漂移 | product/security/release | rc.2 pyproject |
| 远端 CI 临时绕过缺少可审计替代证据 | fail-closed release/M5/field 边界 | pinned base、identity-labelled tool image、只读快照、非 root、离线 gates、独立联网 audit 的双版本 runner | local CI quick/full | 7 天 waiver |
| standalone 快照依赖 `.git`/父工作区 | Git checkout 严格模式 | security 增加 bounded fallback；file mode 接受只读 index inventory；外部参考 clone 默认可选并保留显式 strict | product/file-mode/ecosystem tests | Git/default strict paths |

## 实施与复审结果

### 已落地

1. Harness：结构化 MCP 权限边界、否定语境拒绝、future/stale blocker、gate 禁止历史 `as_of`、仓库级 owner 路径收紧。
2. 性能：根包装器接通 strict timing；quick 分层并保留 full/根包装覆盖；最终受控 quick 为 17 项且满足 120 秒预算。
3. 热路径：typed schema 后 `manifest_validate` p95 从 557.465ms 降至 99.853ms，缓存按原始 schema 内容失效且容量为 8。
4. 契约：manifest JSON/YAML、schema、installer、CLI、文档统一 copy-only；关键 nested object 采用 typed fail-closed schema与负向测试。
5. 安全维护：Python 3.11+、固定 PyYAML/jsonschema、CI 3.11/3.12、Ruff/pip-audit quality extra、doctor 结构化 support status。
6. 可维护性：根 `AGENTS.md` 从 270 行降至 86 行，R1-R8 与生命周期细节下沉且有语义保真测试；增加 OWNERS 和 90 天 freshness metadata。
7. 受控 CI parity：Python 3.11.15/3.12.13 各 full 54/54；gates 使用 `uid=65532(adk-ci)`、`--network none`、只读 root、无 capability/no-new-privileges；`pip-audit` 独立 bridge，两个版本均无已知漏洞。
8. 可追溯性：记录 source snapshot、Git index mode inventory、Dockerfile+entrypoint definition hash、base digest 与两个 immutable tool image ID；旧/替换 tag 会 fail closed。

### 独立复审

- 复审新增并修复 4 个 major：历史评估时钟绕过、嵌套 OWNERS 假阳性、R1.8 规则语义丢失、typed schema breaking 迁移说明缺失。
- 性能复验期间新增并修复 2 个实现问题：schema meta-validation 重复导致预算回归；suite mode 首轮变量名错误。
- CI waiver 复审新增并修复 4 个 major：gates 全程联网、容器默认 root、local tag 身份不可追溯、安全扫描越界 symlink 仍被跟随。
- 非 root 实跑另暴露 `whoami` UID 无名称映射；保留非 root，通过固定无登录 `adk-ci` 身份修复并完成双版本复验。
- 当前 blocker=0、major=0（本地 source/test 范围）。AI review 不替代 owner 对版本、业务语义和远程执行的最终签收。

### 根仓 full 归因

`rtk scripts/check-all.sh --full` 得到 55/62。初始 `goal-capability` 与 `performance-ops` 已修复并定向转绿；其余失败由同一未提交 candidate 链派生：strict ADK dirty、evidence bundle/current status、旧 release rehearsal digest、Software M5 declaration 和 workspace health。不能通过放宽 dirty policy或篡改旧证据修绿。

最终 `rtk scripts/check-all.sh --quick` 为 53/56；仅 `current-status-consistency`、`software-m5-readiness`、`subrepo-state` 失败，三者均指向上述未提交 candidate/旧 digest 边界。quick 按设计跳过的重型性能、harden、evidence 和 workspace aggregate 已分别取得定向证据或在初始 full 中完成归因。

2026-07-18 08:55Z 复跑保持 53/56：Software M5 明确报告 rehearsal candidate manifest digest 与当前 checkout 不匹配、scorecard 声明陈旧；subrepo gate 明确报告严格 `agent-dev-kit` 有 51 项未提交变更。该结果与本地 waiver 设计一致，不能在未 commit/version/rehearsal 的前提下消除。

## 外部执行边界

真实 Claude/Codex campaign、远程 GitHub Actions、artifact attestation、独立仓和 30 天现场周期涉及凭证、费用、外部人员或时间条件。本轮只确保命令、合同和 fail-closed certifier 可执行；没有真实证据时，`terminal_mature` 必须继续为 false。

本轮未写 Knowledge Hub candidate：仓库内 change/review/verification 工件已经形成可审查长期证据，Knowledge Hub 位于当前授权写入范围之外；不静默扩大写权限。

`final-ready` 返回 pass。其 session coach 同时将长线程和 `~/codex` 既有 40 项 dirty 资产标为高风险；这些状态不属于本次写入范围，因此没有执行 build/apply/清理，并在交付中继续明确未提交、未刷新 live runtime。

## 受控 CI waiver 冻结快照证据（版本前）

- ADK source snapshot：`f867ed55726e092747c5c4172ad91e1541ef89f31ba3e37b1286d0f303df962c`。
- file mode inventory：`a7c3a1d961dbeee3b17b00291c1f3103e9872e9e7743fe7bf3b8d94aef9ff6a2`。
- local CI definition：`663f5c72c4db79280a5d82bcb206f765748977d5fcf9817527569c5e3e30113b`。
- Python 3.11 tool image：`sha256:2f4ec1f0197b789009d2cae4f5288fcf213e2167adf1afa47665f641c2d4c451`。
- Python 3.12 tool image：`sha256:3fcedbe94b2caf8081d7b509eea6ec5279cc7bb5923622598327a36a713878c8`。
- 最终命令：`rtk scripts/run-local-ci-parity.sh --python all --mode full`，退出 0；Python 3.11/3.12 各 54/54，两个独立 dependency audit 均报告无已知漏洞。
- 为避免把哈希写回当时快照后再次改变被验证源码，该 snapshot hash 保存在父仓报告；随后按 owner 授权进入 RC3 version/commit/rehearsal，并由下节独立证据替代其“最终候选”地位。

## RC3 commit / version / rehearsal 闭环

- ADK 版本合同：`3.1.0-rc.3`；source commit `defe8a078b9693b6963e434f3131891ebbcf5d62`，evidence commit `a1b5e2fed679d8002b21567103c6366c57236915`。
- exact-commit source artifact：两次独立 build 字节一致，SHA256 `46afbb507f61fce8facffbfa36c23f59fe3f5498e3f1843ceaa53f2507d8fcd8`，576 source files，两个 sidecar 均通过。
- rc.2 → rc.3 rehearsal：previous/candidate 各安装 39 项，candidate rollback removed/restored=39，report SHA256 `1526ac3aaeb275c4c34da79419e2aed9588620c6487ee6b8805232de31096de9`。
- 历史 RC2 provenance 负证据：从 `dd67b48` 重建为 520 files，而 checksum 有效的历史最终 artifact 为 521 files；唯一额外文件是 Git 忽略的 `history.log`。RC3 release assembler 已排除 `*.log` 并增加归档负例，未改写 RC2 证据。
- ADK release tree full：54/54，335446ms；security 695 files，0 failure、0 warning。
- 根仓 quick：56/56；根仓 full：62/62。full 包含 harden readiness、真实性能预算、evidence bundle、Software M5、token、WeChat 与 workspace aggregate。
- mapped paths：`0d25f3d..defe8a0` 与 `defe8a0..a1b5e2f` 在 `agents/skills/optional-skills/workflows/templates` 下均无变化，因此 source-to-live 决策为 `not-required-mapped-no-change`，本轮未写 `~/codex` 或 `~/.codex`。
- 外部边界：未 push、tag、publish、执行远端 CI/attestation、真实双 runtime campaign 或 field certification；`software_m5_certified=false`、`terminal_mature=false`。
