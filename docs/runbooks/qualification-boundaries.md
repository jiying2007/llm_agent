# 当前源码与历史资格的严格边界

`llm_agent` 是不自行发布组件的研究/控制工作区；`agent-dev-kit` 是不可变组件 Release 的权威。两者的组件可发布性、当前产品资格、实际 runtime 和长期现场证据是不同事实。

## 优先读取哪一份权威

- **源码身份**：`adk.lock`、`manifests/adk_interface.lock.json` 与 gitlink 一致性。
- **当前消费资格**：`reports/current-status.md` 的 generated-current-source-projection，结合真实 `software-m5-certify` 校验；`release_authorized=false` 不得被 historical scorecard 代替。
- **历史产品 M5**：`manifests/product_maturity_scorecard.json` 及 `reports/current-status.md` 的 Last Verified Product Baseline，只适用于其固定源码和当时的证据。
- **组件发布**：ADK GitHub immutable Release、签名推广与精确制品 digest；不自动产生新的 field/product 资格。
- **长期资格**：`manifests/long_term_asset_qualification.json`。LTA-04 只接受实际独立现场日志、完整摘要和注册人类 owner 审核。

## 状态判定

1. 当前 ADK commit 与历史候选不相同时，即使 PR/CI/Release 成功，Root 仍为 `HISTORICAL_NOT_AUTHORIZED`。
2. Product M5 的历史 `pass` 在 LTA qualification layers 中显式标记 `historical-last-verified-product-m5-baseline`，不代表当前源码可用。
3. 真实 30 天窗口届满仅解除时间条件，不产生 `PASS`；即便当前观察事件数为零，也须由真实摘要、事件集合闭环与 owner 审核证明。
4. `--as-of` 时间旅行输出为 `simulated_pass`，`terminal_qualified=false`；不得作为真实 owner/field/release 记录。
5. 证据缺失、过期、模型 identity 为 alias 或只完成 deterministic fixture 时，要保留 blocked/not-measured/inconclusive；禁止补默认零值、复制历史 receipt 或静默提升资格。

## 稳定消费而非追随 HEAD

团队日常运行目标应绑定一个已批准的 ADK 版本、来源 commit/tree、已审核 profile 组合、目标 adapter 和回滚点；新主线先独立验证、重新测量与审核，随后才更新稳定消费基线。不要为方便快速更新而降低 exact-source 约束，也不要为单次未授权候选重复制造额外发布权威。

## 效果门禁与实际收益

现有 `docs/runbooks/effect-readiness.md` 是 G22 唯一效果证据入口：固定相同任务/模型 revision/控制条件，比较原生运行时基线、按需 ADK 与新候选。记录最终正确性、错误路由、人工返工、耗时和真实 token。软件准备好不等于效果验证成功；不为追求“终态”生成模型未执行的 trial/receipt 或 owner decision。


### LTA-04 end-of-window observation authority (2026-10-16)

Thirty elapsed calendar days and a correctly rehashed summary alone are not
terminal evidence. Record an actual, digest-bound `pilot_observed` field event
from the registered independent pilot within the final 24 hours of the
summary's `observed_through` and at or after the 30-day eligibility boundary.
The event must reference authentic operator-reviewed field observation material
(e.g. sanitized real pilot runtime/incident/health receipts), with a current
SHA-256 and proper hash-chain continuity. If the pilot stopped or no genuine
observation exists, keep LTA-04 **BLOCKED** with
`end-window-field-evidence-missing`; never manufacture a heartbeat, claim a
clean 30-day window from no telemetry, or re-label fixture data as field
operations. Existing owner review, full-window outcome counts, risk disposition
and protected PR ratchet remain mandatory and independent.


LTA-04 原始 event-log JSONL 与终态 summary 均拒绝任何层级重复 JSON key：
原生 JSON 解析器“后值覆盖前值”会使机器 digest 与人工文本审查出现
歧义；即使两个重复字段的值相同、哈希内容重新计算正确，也必须 FAIL。


### Longitudinal field evidence resource and operator boundaries

The LTA-04 `pilot_started` and terminal `pilot_observed` events must
identify a **human operator registered to the exact independent pilot**.
Neither an unaffiliated actor nor an undeclared automation account gains
qualification authority by rehashing event and summary JSON.

The certifier streams JSONL with hard byte/line/count budgets, bounds each
referenced field evidence file before hashing, and rejects non-standard
`NaN`/`Infinity` and overflowing floating-point JSON values. Oversized
or invalid evidence is `FAIL`, not an empty observation, synthetic PASS,
or a reason to bypass the 30-day and owner-review requirements.

### Durable terminal source identity

Real `longitudinal-operation` PASS accepts only the canonical
`reports/long-term-assets/longitudinal-operation-current.json` path from
the LTA-04 manifest. An alternate `--evidence` file is review-only: it
must stay BLOCKED in real mode, while explicit `--as-of` may validate the
candidate as simulated evidence without terminal authorization.

Before PASS, the certifier also requires its long-term asset manifest,
pilot ledger, append-only event log, canonical summary and every referenced
field evidence file to be tracked and unchanged relative to Git HEAD.
Modified, staged, ignored or untracked materials cannot silently acquire
terminal authority from locally recomputed hashes. Git identity is still
only source reproducibility: genuine field provenance, 30-day observations,
owner review, signed evidence as applicable and protected PR/fresh-main
qualification remain independent requirements.


### HEAD blob identity independent of Git status (2026-10-16)

Git `status --porcelain` is **not** sufficient to authorize terminal
field evidence: Git index flags such as `assume-unchanged` and
`skip-worktree` can suppress reporting of modified bytes. The certifier now
compares the exact regular-file blob and mode from **HEAD** to the index,
then hashes actual worktree bytes with `git hash-object` and compares those
raw bytes to the HEAD blob SHA. Staged-only differences, hidden worktree
differences, missing files, and paths with Git glob characters fail closed.
This is a source-integrity requirement, not proof that the field operator
really observed what a receipt claims.


### Event evidence references are bounded and exact

Each field-event `evidence` list is limited to 32 **distinct** regular
repository-local file paths. Its `evidence_sha256` object must contain
**exactly** those paths, without surplus or omitted digest keys. This stops
repeated hashing of the same large evidence file and prevents misleading
unreferenced digests from appearing in a valid event-chain record. The
per-file, JSONL/line and Git HEAD blob budgets remain independently enforced.
No synthetic event is added to the real LTA-04 ledger by these checks.


### Cross-event field evidence budget (2026-10-16)

The LTA-04 JSONL reader uses one SHA-256 verification per canonical evidence
file across the entire event chain; referencing the same authentic receipt
from several field events does **not** multiply full-file I/O. A single
certification pass allows at most 8192 distinct evidence files and 512 MiB
of cumulative unique evidence bytes, in addition to the 32 references/event
and 16 MiB/file budgets. Noncanonical aliases such as redundant `./` or
repeated separators are rejected even when they resolve to the same file.
Exceeding budgets yields a hard invalid-evidence result, never a silent
partial qualification or simulated success. Genuine field evidence and owner
review remain required irrespective of hash-cache behavior.


### Registered operator authority for the entire field event chain

The `pilot_started` and final `pilot_observed` are not the only records
subject to the operator registry. Every scoped field event contributing to
an LTA-04 terminal summary—including `fault_observed`,
`regression_observed`, `recovery_completed`, and maintenance observations—
must declare a registered **human** operator of the exact pilot.
An unknown actor fails even after the event chain and summary hashes have
been recomputed and reviewed. Registry ID equality verifies declared scope,
not human authentication or genuine operation; provenance/owner review and
real independent pilot evidence remain separate mandatory controls.


### Owner review must postdate the entire recorded event lineage

LTA-04 observation `occurred_at` and ingestion `recorded_at` are separate
facts. A late field event may have occurred within the 30-day window but been
entered later. Because the canonical summary binds the entire ledger's SHA,
event count and chain head, the registered human owner must issue the
review **on or after the latest `recorded_at` of all bound events**, as well
as after `observed_through` and the 30-day eligibility time. Rehashing a
late event cannot retroactively authorize an older owner review. The test
fixture verifies both early-review rejection and explicitly later simulated
approval without creating any real field record or owner decision.
