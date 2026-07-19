# mattpocock/skills 更新吸收与落地报告（2026-07-19）

## 结论

- 状态：`ENHANCE absorbed + sampled-watch retained + runtime-disabled`。
- 来源：`https://github.com/mattpocock/skills`。
- 不可变快照：`9603c1cc8118d08bc1b3bf34cf714f62178dea3b`；对比基线为 `v1.1.0` peeled commit `d574778f94cf620fcc8ce741584093bc650a61d3`。
- 获取日期：`2026-07-19`；许可证：MIT。
- 变化规模：基线到快照共 39 个 commit（25 个 non-merge）、85 个文件、约 `+714/-105`。
- Owner decision：吸收可验证的方法与边界，不复制上游 Skill 文本，不安装第三方 plugin/CLI，不恢复 submodule，不引入运行时依赖。

上游 `main` 的 package version 仍为 `1.1.0`，Claude plugin manifest 则为 `1.2.0`。因此本轮把快照视为“可审查更新”，不把未发布的 `main` 宣称为稳定 release。

## 差异决策

| Lane | Decision | 吸收内容 | ADK 落点 | 明确边界 |
|---|---|---|---|---|
| cross-harness invocation | enhance | 将 implicit/explicit-only 调用意图变为 manifest SSOT，并按 target 确定性映射 | `manifest.json`、`manifests/manifest.schema.json`、`manifests/target-contracts/*.json`、`src/agent_dev_kit/targets.py` | 无证据不把现有 Skill 改为 explicit-only；target 不支持时 fail closed |
| work-item intent | enhance | 将 decision/research/prototype/implementation 的问题、证据、实现权限、退出门和 handoff 固化为 task package v2 | `manifests/structured_output_contracts.json`、`src/agent_dev_kit/intent_boundary.py`、既有 planning/task/parallel Skills | v1 硬退役；research/prototype 不获得实现权限；不保留兼容 reader |
| architecture scope | enhance | 用历史 Hotspot、first-order dependency 和 expansion reason 限定扫描范围 | `agent-dev-kit/agents/architecture-planner/AGENTS.md` | broad scan 必须给出扩域理由；不把“全面扫描”设为默认 |
| prototype provenance | enhance | 原型必须记录来源、输入、artifact hash、到期日、保留/清理决策 | `manifests/structured_output_contracts.json`、`templates/artifacts/prototype-evidence-template.md` | prototype 不是 production implementation，不允许凭原型自动晋级 |
| in-progress skills | observe | `batch-grill-me`、`to-questionnaire`、`setup-ts-deep-modules` 继续 sampled watch | `manifests/subrepo_lifecycle.json` | 未晋级稳定目录，不创建同名 ADK Skill |
| packaging/runtime | reject | 上游安装、plugin、submodule、代码复制 | adoption matrix | 不执行第三方脚本，不启用 hook/MCP/open-world writes，不建立供应链依赖 |

## 复用与去重

- 不新增 Agent、Skill 或 Workflow：invocation 属于 manifest/target contract，工作项边界由既有 `adk-task-breakdown`、`adk-planning-execution-loop`、`adk-parallel-agent-governance` 消费，架构范围由既有 `architecture-planner` 消费。
- 新增的只有平台中立 typed core、schema、模板与机械测试；长说明已归档到 `agent-dev-kit/docs/changes/archive/20260719-intent-boundary-governance-v2/`。
- Codex metadata 采用官方当前 nested `interface` 形状；implicit 为缺省省略，明确禁止 legacy 顶层字段和冗余 `allow_implicit_invocation: true`。

## 功能、性能与安全影响

- 功能：工作项从“名称暗示意图”升级为 schema 可判定权限；direct target 对不支持的 invocation mode 拒绝导出。
- 性能：新增校验均为本地 manifest/task 线性扫描，不增加网络、模型调用或常驻进程；Skill 仍受 140 行 token 门禁约束。
- 安全：不执行或复制上游代码；不引入依赖、凭证、hook、MCP 或外部写操作；prototype artifact 以 SHA-256、expiry 与 retention rule 约束。
- 可扩展性：新增 target 只需声明支持的 invocation modes 与 metadata mapping；新增 work-item kind 必须同时扩 schema、typed validator、cross-field negative test。
- 可维护性：manifest 是唯一 invocation SSOT，task package 只保留 v2，target adapter 和定向测试阻止兼容残留回流。

## 验证证据

已通过：

- `rtk python3 tools/check_manifest_sync.py`
- `rtk bash scripts/devkit.sh validate --strict`
- `rtk bash scripts/check-official-docs-governance.sh --summary-json`
- `rtk bash tests/test_intent_boundary_governance.sh`
- `rtk bash tests/test_target_contracts.sh`
- `rtk bash tests/test_skill_sop_quality.sh`
- `rtk bash tests/test_templates.sh`
- `rtk bash tests/test_token_budget.sh`
- `rtk bash scripts/devkit.sh release check --summary-json`
- `rtk bash tests/test_software_m5_ready.sh`

最终闭环证据：

- ADK quick `18/18`、full `55/55`、security `731 files / 0 warning`，七项性能预算与 memory gate 全通过。
- release source commit `66a8c19` 两次构建的 611-file artifact 字节一致，SHA256 为 `7c0ddf0c0d0e2174abcb682e0df1e6b5d10fdcb8695bdaaa2dccc37a5daf3907`。
- RC4→RC5 使用 release-only `target-contract-hard-cut` 迁移，candidate rollback 与 RC4 62-asset fallback restore 均通过。
- Codex source commit `684f7f8`；最终 source-to-live copy/overwrite/delete 全零，101 tests、五 profile 与 63/63 nested live metadata 通过。
- root quick `53/53`、full `58/58`，包括 exact-HEAD ADK harden、performance ops、evidence bundle、token budget 与 workspace entrypoints。
- review blocker=0、major=0、minor=0，change artifact 已进入受管 archive。

边界不变：以上仅证明本地 RC5 release candidate 与 Codex 声明式运行资产闭环；不声明 Software M5 certification、远端 CI/attestation、发布或 native direct-target runtime/field 认证。

## 生命周期

- 保持 `watch/manual/automation_eligible=false`，不恢复全量本地参考仓。
- 下一轮只抽样检查稳定 release 或新增 contract；纯文案、重复模式和未晋级 in-progress 变化不触发 ADK 改动。
- 若未来需要启用上游 plugin/runtime，必须另立 change，重新完成供应链、安全、许可、target compatibility 与 rollback 审查。

## Root Closure Negative Results

- 首轮 `check-adk-harden-readiness` 拒绝 sampled-watch 行：observe+done 缺少 Agent/Skill/Workflow 三层 intake package 和 dated package report。已补充 `reports/observe-secondary-intake-packages-2026-07-19.md`，未以虚假“已采纳”绕过门禁。
- 首轮 `test_product_maturity_contracts` 拒绝扩展 working-candidate status 枚举。保持稳定 `source-committed-local-rehearsed`，Codex live apply 事实只写入独立 `source_to_live`/`live_refresh_status` 字段，避免复用状态字段承载两种语义。
- 首轮 root quick 的 reference-removal pass fixture 检出 adoption decision hash 已随矩阵更新而过期。按当前受审查矩阵重算并更新 SHA256，不关闭 artifact freshness 检查。
