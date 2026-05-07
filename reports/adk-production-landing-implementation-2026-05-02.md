# adk 生产级落地补齐实施记录

- 日期：2026-05-02
- 范围：`agent-dev-kit` 生产级运行入口、profile 分层、runtime routing、Evidence Index、pilot coverage、上游吸收门禁、生产安装治理
- 目标：把 adk 从“压实版资产包”推进为 `~/.codex` 的生产级统一分发层。

## 本轮落地

1. Runtime Routing
- 新增 `scripts/check-runtime-routing.sh`，校验生产 profile、optional skill 与 runbook 资产完整性。
- 新增 `runtime-routing` runbook，明确只读分析、行为变更、高风险变更、长任务、团队交接、上游吸收的入口判定。

2. 强计划与长任务闭环
- 新增 optional skill：`planning-execution-loop`。
- 新增 runbook：`planning-execution-loop.md`。
- 固化 `session-state / next-actions / risk-ledger / resume-prompt` 四类恢复工件。

3. 组合式技能治理
- 新增 optional skill：`skill-composition-governance`。
- 明确 primary/supporting/fallback/mutually-exclusive/deprecated 规则。

4. 团队交付与供应链治理
- 新增 optional skill：`security-supply-chain`。
- 新增 runbook：`team-delivery.md`、`security-supply-chain.md`、`upstream-intake.md`、`compatibility-matrix.md`。
- 新增 `team-core`、`research-intake` 等 profile，为团队协作与参考仓吸收提供独立安装边界。

5. Evidence Automation
- 新增 `agent-dev-kit/scripts/evidence_index.sh` 与 `devkit.sh evidence` 入口。
- 新增 `agent-dev-kit/tests/test_evidence_index.sh`。
- Evidence Index 支持追加命令、退出码、结果摘要、证据路径、层级与关联工件。

6. 生产安装治理
- `install_assets.sh` 新增 `--backup`、`--backup-dir`、`--install-report`、`--lock-version`。
- `test_install.sh` 覆盖备份、安装报告和版本锁定。
- 新增 `production-deployment.md`，固化生产安装、健康检查与回滚流程。

7. Pilot 与上游吸收门禁
- 新增并升级 `scripts/check-codex-pilot-coverage.sh`，校验六类 pilot 字段、场景章节、artifact 标签与命令级 Evidence Index。
- 新增 `scripts/check-upstream-intake-readiness.sh`，校验 `adopt + done` 行具备生产目标和本地证据。
- `check-adk-harden-readiness.sh` 默认接入 runtime routing 与 upstream intake；`--require-pilot` 时接入 pilot coverage 字段检查。

8. `~/.codex` 生产安装
- 已执行真实安装：`personal-core + release-hardening`。
- 已安装 optional skills：`planning-execution-loop`、`skill-composition-governance`、`security-supply-chain`、`cross-team-handoff`、`artifact-gated-lite`。
- 安装报告：`reports/adk-install-report-2026-05-02.md`。
- 回滚备份：`/home/aiot03/.codex/.adk-backups/20260502T104514Z`。

9. 六类 pilot 自举试跑
- 新功能交付：验证 `planning-execution-loop` 触发。
- 缺陷修复：验证 Evidence Index 命令级字段。
- 重构压实：验证 `devkit validate --strict`。
- 发布收口：验证 `release-hardening` dry-run 安装与版本锁。
- 团队交接：验证 `cross-team-handoff` 触发。
- 上游吸收：验证 `check-upstream-intake-readiness.sh`。

10. 去冗余与顺序压实
- 清理 `manifest.yaml` 中继承后重复声明的 profile 增量项，避免多轮补丁造成 profile 噪音。
- 新增 `agent-dev-kit/scripts/check_profile_coherence.sh` 与 `test_profile_coherence.sh`，校验 profile 继承重复、未知引用、默认 profile 漂移。
- 统一 workflow 模板与 `evidence_index.sh` 的 Evidence Index 字段，固定为 `Command/Exit Code/Result Summary/Evidence Path/Layer/Related Artifact`。
- 明确场景 Skill 列表按 `Primary -> Supporting` 排列，避免“多技能组合”被误读为多个主入口。

## 当前边界

- `pilot_full_coverage_ready=yes`：六类 pilot 已完成 adk 自举试跑，并由脚本校验 artifact 与命令级证据。
- 本轮完成的是生产级落地基础设施与 adk 自举试跑；真实业务任务样例仍需继续积累，不声明已完成所有团队场景的长期替代结论。
- `core` 继续保持精简，复杂能力通过 optional skill/profile 启用。

## 验证证据

- `rtk agent-dev-kit/tests/test_install.sh` -> PASS
- `rtk agent-dev-kit/tests/test_profile_coherence.sh` -> PASS
- `rtk agent-dev-kit/tests/test_evidence_index.sh` -> PASS
- `rtk agent-dev-kit/tests/test_change_governance.sh` -> PASS
- `rtk agent-dev-kit/tests/test_workflow.sh` -> PASS
- `rtk scripts/check-runtime-routing.sh .` -> PASS
- `rtk scripts/check-codex-pilot-coverage.sh .` -> PASS（full coverage ready）
- `rtk bash -lc 'cd agent-dev-kit && bash scripts/devkit.sh match --skill planning-execution-loop --scope optional-skill --text "复杂任务需要计划审查和执行检查点时"'` -> PASS
- `rtk bash -lc 'cd agent-dev-kit && bash tests/test_evidence_index.sh'` -> PASS
- `rtk bash -lc 'cd agent-dev-kit && bash scripts/devkit.sh validate --strict'` -> PASS
- `rtk bash -lc 'cd agent-dev-kit && bash scripts/devkit.sh install --tool codex --target /tmp/adk-release-pilot-codex --mode copy --profile release-hardening --with-optional-skill security-supply-chain --install-report /tmp/adk-release-pilot-install.md --lock-version 0.3.0 --dry-run'` -> PASS
- `rtk bash -lc 'cd agent-dev-kit && bash scripts/devkit.sh match --skill cross-team-handoff --scope optional-skill --text "模块即将交接给其他团队维护"'` -> PASS
- `rtk scripts/check-upstream-intake-readiness.sh .` -> PASS（23 adopt rows）
- `rtk scripts/check-doc-sync.sh .` -> PASS
- `rtk agent-dev-kit/tests/run_all.sh` -> PASS
- `rtk scripts/check-adk-harden-readiness.sh . --require-pilot` -> PASS
- `rtk bash -lc 'cd agent-dev-kit && bash scripts/devkit.sh install --tool codex --target ~/.codex --mode copy --profile personal-core --extra-profile release-hardening --with-optional-skill planning-execution-loop --with-optional-skill skill-composition-governance --with-optional-skill security-supply-chain --with-optional-skill cross-team-handoff --with-optional-skill artifact-gated-lite --backup --install-report ../reports/adk-install-report-2026-05-02.md --lock-version 0.3.0'` -> PASS
- `rtk scripts/check-global-codex-health.sh ~/.codex minimal` -> PASS

## 下一步

1. 按真实业务任务继续补充六类 pilot 样例，验证长期使用中的触发噪音和流程成本。
2. 将真实业务样例中的有效修正回灌到 `runtime-routing.md`、profile 与 optional skill。
3. 若安装后出现问题，回滚到 `/home/aiot03/.codex/.adk-backups/20260502T104514Z`。
