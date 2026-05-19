# codex 实战试跑报告

- 试跑日期：2026-05-02
- 目标仓库：`~/.codex`
- 对应 adk 版本/分支：`agent-dev-kit`（本地当前工作分支）
- 执行人：Codex（自动化落地）

## 门禁证据状态

- pilot_high_risk_case_done: yes
- artifact_labels_complete: yes
- review_test_consistent: yes
- command_evidence_recorded: yes
- pilot_full_coverage_ready: yes
- pilot_feature_delivery_done: yes
- pilot_bugfix_delivery_done: yes
- pilot_refactor_hardening_done: yes
- pilot_release_hardening_done: yes
- pilot_team_handoff_done: yes
- pilot_upstream_intake_done: yes
- pilot_production_install_done: yes

## 本轮状态

1. `~/.codex` 作为全局运行目录纳入试跑目标（不再依赖当前仓库本地 `codex/`）。
2. 阶段门禁已开启：`subrepos/phase-gate.env` 中 `allow_upstream_sync=yes`。
3. 开门后正式执行了 `sync + diff` 增量评估（见 `weekly-change-report.md`）。
4. 已在 `agent-dev-kit` 落地 `artifact-gated-lite`：
   - profile：`artifact-gated-lite`
   - optional skill：`artifact-gated-lite`
   - runbook：`docs/runbooks/artifact-gated-delivery.md`
5. 关键验证已通过：
   - `rtk scripts/check-adk-harden-readiness.sh . --open-gate`
   - `rtk scripts/sync-subrepos.sh . fetch`
   - `rtk scripts/diff-scan.sh . 7 reports/weekly-change-report.md`
6. 本轮 `adoption-matrix` 已回填（adopt/observe/reject）。
7. 六类 codex pilot 已完成 adk 自举试跑：新功能、缺陷修复、重构、发布收口、团队交接、上游吸收。
8. 生产级 pilot coverage 字段已补齐；当前 `pilot_full_coverage_ready=yes`，表示六类场景均已有可复现命令证据与 artifact 记录。
9. 已完成一次真实 `~/.codex` 生产安装：
   - profile：`personal-core + release-hardening`
   - optional skills：`planning-execution-loop`、`skill-composition-governance`、`security-supply-chain`、`cross-team-handoff`、`artifact-gated-lite`
   - 安装报告：`reports/adk-install-report-2026-05-02.md`
   - 回滚备份：`/home/aiot03/.codex/.adk-backups/20260502T104514Z`

## 2026-05-19 当前机器运行态刷新

本节只刷新当前机器 `~/codex -> ~/.codex` 的只读 / dry-run 证据，不直接写入 `~/.codex`。

| Command | Exit Code | Result Summary | Evidence Path | Layer | Related Artifact |
|---|---:|---|---|---|---|
| `rtk bash scripts/build.sh --profile team-collab --build /tmp/adk-codex-build` | 0 | `team-collab` build 成功，managed=584 | `/tmp/adk-codex-build` | Codex Home | Runtime Refresh |
| `rtk bash scripts/doctor.sh --scope live --target /home/leiwenjun/.codex` | 0 | live doctor 通过，errors=0 warnings=0，PROFILE=team-collab | command output | Runtime | Runtime Refresh |
| `rtk bash scripts/plan.sh --build /tmp/adk-codex-build --target /home/leiwenjun/.codex --output /tmp/adk-apply-plan.json` | 0 | apply plan 生成成功，copy=0 keep=394 overwrite=0 mkdir=192 skip=0 | `/tmp/adk-apply-plan.json` | Runtime | Runtime Refresh |
| `rtk bash scripts/apply.sh --build /tmp/adk-codex-build --target /home/leiwenjun/.codex --profile team-collab --no-build --dry-run --plan-out /tmp/adk-apply-dry-run-plan.json` | 0 | apply dry-run 通过，未写入运行目录 | `/tmp/adk-apply-dry-run-plan.json` | Runtime | Runtime Refresh |
| `rtk bash scripts/evidence-bundle.sh . --format json` | 0 | 生成 llm_agent/adk 门禁摘要；当前 `agent-dev-kit` 正在修改，因此 subrepo_state 显示 1 个 unexpected_dirty | command output | Governance | Evidence Bundle |

结论：当前机器的 Codex Home 构建、运行态健康、apply plan 和 apply dry-run 均可复现；本轮未执行真实 apply，因此没有产生新的 `~/.codex` 备份。

## 试跑场景 A（已完成）

场景：`~/.codex` 高风险配置门禁校验（RTK/skills 链接一致性与配置渲染状态）

[artifact:ImplementationPlan]
status: READY
owner: Codex
scope:
- 使用 `~/.codex/control/scripts/doctor.sh` 对 `minimal` profile 执行门禁检查
- 识别 errors/warnings 并形成可追溯结论
inputs:
- ~/.codex/control/scripts/doctor.sh
- ~/.codex/control/catalog/*.csv
handoff_to:
- subrepos/adoption-matrix 决策回填

[artifact:ReviewReport]
status: PASS
owner: Codex
verdict: pass
findings:
- None
must_fix:
- None（当前不阻断）
can_follow_up:
- None

[artifact:TestReport]
status: PASS
owner: Codex
tests_run:
- `rtk bash ~/.codex/control/scripts/doctor.sh ~/.codex minimal` -> `errors=0 warnings=0`
known_issues:
- None

## 试跑场景 B（已完成）

场景：`~/.codex` 生产安装与回滚点校验

[artifact:ImplementationPlan]
status: READY
owner: Codex
scope:
- 使用 `copy` 模式安装 adk 到 `~/.codex`
- 安装前备份 `agents/skills`
- 生成安装报告并执行健康检查
inputs:
- agent-dev-kit/manifest.yaml
- agent-dev-kit/scripts/install_assets.sh
handoff_to:
- 后续六类 pilot 场景

[artifact:ReviewReport]
status: PASS
owner: Codex
verdict: pass
findings:
- None
must_fix:
- None
can_follow_up:
- 六类 pilot 已完成 adk 自举试跑；后续仍需补真实业务任务样例

[artifact:TestReport]
status: PASS
owner: Codex
tests_run:
- `rtk bash -lc 'cd agent-dev-kit && bash scripts/devkit.sh validate --strict'` -> `Validation passed. strict=1 quick=0`
- `rtk bash -lc 'cd agent-dev-kit && bash scripts/devkit.sh install --tool codex --target ~/.codex --mode copy --profile personal-core --extra-profile release-hardening --with-optional-skill planning-execution-loop --with-optional-skill skill-composition-governance --with-optional-skill security-supply-chain --with-optional-skill cross-team-handoff --with-optional-skill artifact-gated-lite --backup --install-report ../reports/adk-install-report-2026-05-02.md --lock-version 0.3.0'` -> `backup=/home/aiot03/.codex/.adk-backups/20260502T104514Z`
- `rtk scripts/check-global-codex-health.sh ~/.codex minimal` -> `errors=0 warnings=0`
- `rtk scripts/check-adk-harden-readiness.sh . --require-pilot` -> `global codex health ready`
known_issues:
- 生产安装和六类 adk 自举 pilot 已完成；真实业务任务样例仍需后续补充

## 试跑场景 C：新功能交付（已完成）

scenario_key: pilot_feature_delivery_done

场景：新增能力进入 `~/.codex` 后，能通过 Skill 路由触发“计划执行闭环”，支撑复杂功能开发前的计划审查和检查点推进。

[artifact:ImplementationPlan]
status: READY
owner: Codex
scope:
- 验证 `planning-execution-loop` 作为 optional skill 已具备可触发入口
- 用代表性功能交付输入触发 skill routing
- 记录命令级证据，作为新功能 delivery pilot
inputs:
- agent-dev-kit/optional-skills/planning-execution-loop/SKILL.md
- agent-dev-kit/scripts/skill_match.sh
handoff_to:
- 后续真实功能开发任务默认采用计划审查与检查点闭环

[artifact:ReviewReport]
status: PASS
owner: Codex
verdict: pass
findings:
- None
must_fix:
- None
can_follow_up:
- 在真实业务功能中继续补充 before/after prompt 回归样例

[artifact:TestReport]
status: PASS
owner: Codex
tests_run:
- `rtk bash -lc 'cd agent-dev-kit && bash scripts/devkit.sh match --skill planning-execution-loop --scope optional-skill --text "复杂任务需要计划审查和执行检查点时"'` -> `match=true skill=planning-execution-loop`
known_issues:
- None

## Evidence Index（命令级）
| Command | Exit Code | Result Summary | Evidence Path | Layer | Related Artifact |
|---|---:|---|---|---|---|
| `rtk bash -lc 'cd agent-dev-kit && bash scripts/devkit.sh match --skill planning-execution-loop --scope optional-skill --text "复杂任务需要计划审查和执行检查点时"'` | 0 | planning-execution-loop 正例触发成功 | reports/codex-pilot-report.md#试跑场景-c新功能交付已完成 | Skill | TestReport |

## 试跑场景 D：缺陷修复（已完成）

scenario_key: pilot_bugfix_delivery_done

场景：缺陷修复必须保留命令级 Evidence Index，避免“修了但无证据”的交付缺口。

[artifact:ImplementationPlan]
status: READY
owner: Codex
scope:
- 验证 `evidence_index.sh` 能写入命令、退出码、结果摘要、证据路径、层级与关联工件
- 将缺陷修复 pilot 映射到 evidence 能力回归
inputs:
- agent-dev-kit/scripts/evidence_index.sh
- agent-dev-kit/tests/test_evidence_index.sh
handoff_to:
- 后续 bugfix 任务的 TestReport / negative-results 证据沉淀

[artifact:ReviewReport]
status: PASS
owner: Codex
verdict: pass
findings:
- None
must_fix:
- None
can_follow_up:
- 在真实缺陷修复中补充失败复现与修复后对照命令

[artifact:TestReport]
status: PASS
owner: Codex
tests_run:
- `rtk bash -lc 'cd agent-dev-kit && bash tests/test_evidence_index.sh'` -> `[PASS] evidence index`
known_issues:
- None

## Evidence Index（命令级）
| Command | Exit Code | Result Summary | Evidence Path | Layer | Related Artifact |
|---|---:|---|---|---|---|
| `rtk bash -lc 'cd agent-dev-kit && bash tests/test_evidence_index.sh'` | 0 | Evidence Index 字段与追加逻辑回归通过 | reports/codex-pilot-report.md#试跑场景-d缺陷修复已完成 | Workflow | TestReport |

## 试跑场景 E：重构压实（已完成）

scenario_key: pilot_refactor_hardening_done

场景：重构或 profile 调整后必须保持资产结构、manifest、元数据与格式校验通过。

[artifact:ImplementationPlan]
status: READY
owner: Codex
scope:
- 执行 adk strict validation
- 证明本轮新增 Agent/Skill/Workflow 资产仍满足 manifest 与结构约束
inputs:
- agent-dev-kit/manifest.yaml
- agent-dev-kit/scripts/validate_assets.sh
handoff_to:
- 后续较大重构前后的资产一致性门禁

[artifact:ReviewReport]
status: PASS
owner: Codex
verdict: pass
findings:
- None
must_fix:
- None
can_follow_up:
- 增加更细粒度的 profile 组合快照测试

[artifact:TestReport]
status: PASS
owner: Codex
tests_run:
- `rtk bash -lc 'cd agent-dev-kit && bash scripts/devkit.sh validate --strict'` -> `Validation passed. strict=1 quick=0`
known_issues:
- None

## Evidence Index（命令级）
| Command | Exit Code | Result Summary | Evidence Path | Layer | Related Artifact |
|---|---:|---|---|---|---|
| `rtk bash -lc 'cd agent-dev-kit && bash scripts/devkit.sh validate --strict'` | 0 | strict validation 通过 | reports/codex-pilot-report.md#试跑场景-e重构压实已完成 | Agent | TestReport |

## 试跑场景 F：发布收口（已完成）

scenario_key: pilot_release_hardening_done

场景：发布前安装计划必须可 dry-run、可锁版本、可产出 install report，并覆盖 release-hardening profile。

[artifact:ImplementationPlan]
status: READY
owner: Codex
scope:
- 使用 release-hardening profile 执行 dry-run 安装
- 带入 `security-supply-chain` optional skill 与 `--lock-version 0.3.0`
- 验证安装计划不会直接写入生产目录
inputs:
- agent-dev-kit/scripts/install_assets.sh
- agent-dev-kit/manifest.yaml
handoff_to:
- 后续正式发布前的 dry-run 与回滚点审查

[artifact:ReviewReport]
status: PASS
owner: Codex
verdict: pass
findings:
- None
must_fix:
- None
can_follow_up:
- 后续可增加 release note 生成脚本

[artifact:TestReport]
status: PASS
owner: Codex
tests_run:
- `rtk bash -lc 'cd agent-dev-kit && bash scripts/devkit.sh install --tool codex --target /tmp/adk-release-pilot-codex --mode copy --profile release-hardening --with-optional-skill security-supply-chain --install-report /tmp/adk-release-pilot-install.md --lock-version 0.3.0 --dry-run'` -> `Install completed`
known_issues:
- None

## Evidence Index（命令级）
| Command | Exit Code | Result Summary | Evidence Path | Layer | Related Artifact |
|---|---:|---|---|---|---|
| `rtk bash -lc 'cd agent-dev-kit && bash scripts/devkit.sh install --tool codex --target /tmp/adk-release-pilot-codex --mode copy --profile release-hardening --with-optional-skill security-supply-chain --install-report /tmp/adk-release-pilot-install.md --lock-version 0.3.0 --dry-run'` | 0 | release-hardening dry-run 安装计划通过 | reports/codex-pilot-report.md#试跑场景-f发布收口已完成 | Workflow | TestReport |

## 试跑场景 G：团队交接（已完成）

scenario_key: pilot_team_handoff_done

场景：团队交接任务必须能触发 `cross-team-handoff`，确保 owner、验收条件、风险与回退路径进入交接清单。

[artifact:ImplementationPlan]
status: READY
owner: Codex
scope:
- 验证 `cross-team-handoff` 在已安装 optional skills 中具备可触发入口
- 用代表性交接输入触发 skill routing
inputs:
- agent-dev-kit/optional-skills/cross-team-handoff/SKILL.md
- agent-dev-kit/scripts/skill_match.sh
handoff_to:
- 后续团队协作任务的交接清单模板

[artifact:ReviewReport]
status: PASS
owner: Codex
verdict: pass
findings:
- None
must_fix:
- None
can_follow_up:
- 补充真实团队签收样例

[artifact:TestReport]
status: PASS
owner: Codex
tests_run:
- `rtk bash -lc 'cd agent-dev-kit && bash scripts/devkit.sh match --skill cross-team-handoff --scope optional-skill --text "模块即将交接给其他团队维护"'` -> `match=true skill=cross-team-handoff`
known_issues:
- None

## Evidence Index（命令级）
| Command | Exit Code | Result Summary | Evidence Path | Layer | Related Artifact |
|---|---:|---|---|---|---|
| `rtk bash -lc 'cd agent-dev-kit && bash scripts/devkit.sh match --skill cross-team-handoff --scope optional-skill --text "模块即将交接给其他团队维护"'` | 0 | cross-team-handoff 正例触发成功 | reports/codex-pilot-report.md#试跑场景-g团队交接已完成 | Skill | TestReport |

## 试跑场景 H：上游吸收（已完成）

scenario_key: pilot_upstream_intake_done

场景：参考子仓优秀实践进入 adopt 前，必须满足上游吸收准入，防止只采纳结论、不保留证据与边界。

[artifact:ImplementationPlan]
status: READY
owner: Codex
scope:
- 执行 upstream intake readiness 检查
- 确认 adopt 行具备生产准入所需证据
inputs:
- scripts/check-upstream-intake-readiness.sh
- subrepos/adoption-matrix.md
handoff_to:
- 后续参考子仓增量跟踪与 adopt/reject 决策

[artifact:ReviewReport]
status: PASS
owner: Codex
verdict: pass
findings:
- None
must_fix:
- None
can_follow_up:
- 跟踪参考子仓更新时继续补充新的 wave 报告

[artifact:TestReport]
status: PASS
owner: Codex
tests_run:
- `rtk scripts/check-upstream-intake-readiness.sh .` -> `[PASS] upstream intake readiness checks passed (23 adopt rows)`
known_issues:
- None

## Evidence Index（命令级）
| Command | Exit Code | Result Summary | Evidence Path | Layer | Related Artifact |
|---|---:|---|---|---|---|
| `rtk scripts/check-upstream-intake-readiness.sh .` | 0 | 23 条 adopt 行满足上游吸收准入 | reports/codex-pilot-report.md#试跑场景-h上游吸收已完成 | Workflow | TestReport |

## 下一步

1. 将六类 pilot 从“adk 自举试跑”继续推进到真实业务任务试跑。
2. 对真实业务试跑继续记录 artifact 标签、命令、退出码、review/test 一致性与 Evidence Index。
3. 若真实业务试跑发现触发噪音或流程过重，回灌 `runtime-routing.md` 与 profile 默认组合。
