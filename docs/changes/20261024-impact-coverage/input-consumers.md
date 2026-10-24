# 实际输入与增量调度

## 取证方法

从 `tests/run_all.sh` 的全部 `tests/test_*.sh` 入口追踪文件读取、复制到隔离夹具的源输入，以及被调用 Python 检查器的间接引用。区分真实仓库输入与测试自行生成的临时文件；后者不增加生产输入声明。

增量算法不需要改变。现有 `calculate_impact` 以直接命中的 gate 的 `impact_groups` 决定是否调度深度集成；依赖闭包继续只是下游信息。问题是消费者的输入声明缺失。

## 常驻的轻量检查

`contract` 增加调用既有 `scripts/check-maintainability-budgets.sh --strict --summary-json` 的 gate。保持原有 14 项预算、严格模式与禁用缓存，不增加 `integration-deep` 标签。

其输入覆盖 `scripts`、`tools`、`manifests`、`reports`、`agent-dev-kit/scripts`、`agent-dev-kit/src`。这些路径包含现有预算 scope、检查实现及配置；ADK 子模块须在执行该检查之前初始化。普通新增报告命中该 gate，无须因此运行完整深度集成。

## 深度回归的实际非代码输入

下表补充 `root-regression` 已有的 `tests`、`scripts`、`tools`、`manifests`。相关 gitlink、锁文件和当前状态报告已有直接的深度 gate 归属。

| 输入 | 现有消费者与失败条件 |
| --- | --- |
| `fixtures`、`schemas` | `test_external_practice_intake.sh` 读取现有 cycle plan、provider fixtures 与四份 schema；registration/removal 检查器验证正反夹具及摘要。 |
| `subrepos` | registration/removal 读取 registry、phase gate、adoption matrix、dirty baseline；只改 adoption matrix 即可使原 removal pass fixture 的哈希过期。 |
| `registry`、`.github/workflows`、`.github/CODEOWNERS` | `test_branch_gc_native_subtraction.sh`、`test_ci_incremental_gate_dag.sh`、`test_solo_recovery_drill_contract.sh` 及治理、M5、qualification-followup 回归消费登记表和 workflow；backlog 实现证据检查还要求 `CODEOWNERS` 存在。 |
| `pyproject.toml` | `test_typecheck_contract.sh` 检查严格类型配置及受检文件集；CI 回归也读取打包与质量工具声明。 |
| `docs/llm-agent-maintenance-guide.md` | `test_active_contracts.sh` 和 `test_asset_inventory_contract.py` / `check-asset-inventory.sh` 检查当前运行目标和资产数量口径。 |
| `docs/product-maturity-model.md`、`docs/software-m5-certification-plan.md` | backlog / scorecard 实现证据的存在性，以及 `test_long_term_asset_qualification.sh` 的当前来源与历史产品资格边界。 |
| `docs/runbooks/runtime-target-activation.md`、`docs/runbooks/knowledge-retention-handoff.md`、`docs/runbooks/practice-effect-review.md`、`docs/runbooks/native-target-conformance-readiness.md`、`docs/runbooks/effect-readiness.md`、`docs/runbooks/solo-maintainer-continuity.md`、`docs/runbooks/team-pilot-acceptance.md`、`docs/knowledge-candidates/llm-agent-adk-target-architecture.md` | active-contracts、LTA、knowledge handoff 消费运行目标、连续性、团队试点和候选 frontmatter；候选 handoff 还要求其 SOURCE_REFS 全部存在。精确声明这些路径，不扩大到整个 runbooks / knowledge-candidates 目录。 |
| `reports/README.md`、`reports/optimization/2026-09-25/historical-script-status-2026-05-23.md`、`reports/optimization/2026-09-25/llm_agent-adk-optimization-plan.md` | `test_intake_active_docs.sh` 校验历史脚本状态、归档元数据、归档文件长度及 SHA-256 / Git blob 摘要。其他新 optimization 说明只需严格报告预算。 |
| `reports/architecture` | `test_architecture_reports.sh` / `check-architecture-reports.sh` 校验章节、当前来源注册和 backlog 实现证据；knowledge handoff 也消费架构来源。 |
| `reports/field-evidence`、`reports/long-term-assets` | M5、LTA、consumer-chain 和 longitudinal 回归读取事件、恢复和治理证据。 |
| `reports/promotion`、`reports/runtime-evidence` | runtime-chain 消费固定版本的历史 promotion 证据；promotion、M5、knowledge handoff 和 runtime-target 检查消费当前及历史运行证据。 |
| `reports/external-practice-targeted-decisions-2026-07-30.jsonl` | backlog 的真实 implementation_evidence，架构检查要求其存在。 |
| `reports/oss-analysis-example-runtime-policy-gates-2026-06-16.md`、`reports/oss-duplicate-check-example-runtime-policy-gates-2026-06-16.md`、`reports/oss-security-review-example-runtime-policy-gates-2026-06-16.md` | `test_reference_repository_registration.sh` 直接读取的三份输入证据，现有 registration plan 绑定其摘要。 |
| `reports/subrepo-removal-plan-codex-2026-06-16.md` | `test_reference_repository_removal.sh` 的真实证据与回滚输入，现有 pass fixture 绑定其摘要。 |
| `reports/wechat-account-research-2026-07-16/catalog.jsonl` | source policy 的 provider input_path；practice intake 的 policy check 和 registration 回归实际读取。 |

`manifests/subrepo_lifecycle.json` 中其他历史报告引用在这些测试路径上仅作为字符串保留，并未读取报告内容或检查其存在性。backlog 的 `review_evidence` 也是声明元数据，当前执行路径没有读取该文件，故不为它增加 `docs/changes` 例外。不能仅根据出现过路径就把全部 `reports` 纳入深度集成。部分独立治理脚本另有历史报告消费者，但 `run_all.sh` 没有在真实 root 上调用这些脚本；本变更不声称扩大了它们的执行范围。

## 回归方式

`ImpactConsumerTests` 复用原检查器，在临时仓库复制真实输入：

1. 不改预算配置；必要时仅填充临时报告人口到现有 warning limit，再新增一个普通报告。原 strict checker 必须从退出 0 变为退出 1，并且该消费者在常驻 `contract` 内。
2. 复制原 removal pass fixture 及其 `required_artifacts`，先检查通过，再分别制造 adoption 摘要过期、pass fixture 非 dry-run、绑定文件重命名后缺失。原 checker 必须退出 2，实际路径必须调度深度回归。
3. 执行原 intake 和 typecheck shell 回归，先取得通过基线，再分别破坏 schema、cycle plan、严格类型配置，确认真实消费者失败且仍被调度。
4. 从 backlog 的 `source_report` / `implementation_evidence`、scorecard 的 dimension evidence、source policy 的 provider input_path、registration/removal pass fixture 的 required_artifacts 自动推导被消费路径，防止输入声明与真实引用继续漂移。测试不复制 gates.json 的新增输入清单。
5. README、无关 architecture / changes / runbooks / knowledge-candidates 说明和普通报告（含 optimization 目录下的新说明）仍不要求深度集成；原有异常 Git 文件名、重命名、无效编码及缺失 Git 基线回归继续保留。

红测记录见 `evidence/impact-consumers-red.json`。它记录共享配置修改前 8 个测试、21 个预期断言失败、0 个执行错误；所有破坏输入的用例均先通过原检查器基线。验证只证明源码和调度边界，不构成运行态或产品放行证据。

## README 轻量路径的一致性

进一步交叉核对发现，`test_active_contracts.sh` 还禁止 README 出现 `hermes-agent` / `Hermes Agent`，而常驻 `active-contracts` gate 只检查 interface 的 `deprecated_surfaces`，该清单并不包含这两个运行目标名。只在 README 追加这些名称，原 shell 回归失败，常驻 gate 仍退出 0，深度集成也未被要求。

新增第 9 个消费边界测试直接比较原 shell 与真实 gate.argv，在隔离副本分别重放两个名称；原实现的 2 个调度一致性断言均失败。证据见 `evidence/impact-readme-red.json`。最小修正是在已读取 README 的常驻 validator 中保留这两项既有禁止词检查；不需要让普通 README 修改触发深度集成，也不应以固定历史 `--as-of` 的 shell 测试替代当前日期的 freshness gate。

## 阶段交接

输入映射经独立只读任务 `/root/root_code_audit/input_map_check` 复核：没有新增实质性漏依赖或夹具伪失败；也核对了归档文件重新出现的反向依赖和旧 M5 历史引用。该复核没有运行全量测试，也不替代最终共享配置差异的独立审核。

交接时 `tests/test_gate_boundaries.py` 共 24 个测试，其 SHA-256 为 `2281afd61cce5cb7f64ddcf8d45712ca8b535f51236762eacddd63f1f011e62b`。`git diff --check` 退出 0。`impact.py` 保持原样。共享 gate / CI 配置与 README validator 由主线程整合，随后须在冻结的同一工作树运行全部 24 个边界测试；本阶段没有宣称绿测或产品放行。
