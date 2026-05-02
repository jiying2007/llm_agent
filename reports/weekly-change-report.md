# 子仓增量变更周报

- 生成日期：2026-05-02
- 扫描窗口：最近 7 天
- 规则：仅保留 AGENTS/SKILL/README/workflow/scripts 相关变更
- 阶段：harden-gdk
- 强制模式：0

## codex-cookbook

- 分组：knowledge
- 优先级：P1
- 状态：active
- owner：gdk-team
- intake_policy：observe-first
- 上次复审：2026-05-02
- 关注说明：Codex Cookbook 实战模板
- 变更文件：
  - skills/README.md
  - skills/junshi-fazheng/SKILL.md
  - skills/junshi-wenchen/SKILL.md
  - skills/junshi/SKILL.md
- 建议动作：进入 adoption-matrix 评估（adopt / observe / reject）

## global-dev-kit

- 分组：gdk-core
- 优先级：P0
- 状态：active
- owner：gdk-team
- intake_policy：adopt-first
- 上次复审：2026-05-02
- 关注说明：主落地仓库
- 变更文件：
  - .github/workflows/ci.yml
  - .github/workflows/release.yml
  - AGENTS.md
  - README.md
  - docs/changes/README.md
  - docs/runbooks/README.md
  - optional-skills/artifact-gated-lite/SKILL.md
  - optional-skills/cross-team-handoff/SKILL.md
  - optional-skills/incident-rca-report/SKILL.md
  - optional-skills/test-flakiness-triage/SKILL.md
  - scripts/catalog_assets.sh
  - scripts/check_format.sh
  - scripts/convert_assets.sh
  - scripts/devkit.sh
  - scripts/install_assets.sh
  - scripts/lib_manifest.sh
  - scripts/skill_match.sh
  - scripts/sync_codex_assets.sh
  - scripts/validate_assets.sh
  - scripts/workflow.sh
  - skills/adr-writer/SKILL.md
  - skills/bsp-porting-playbook/SKILL.md
  - skills/cmake-cross-build/SKILL.md
  - skills/commit-pr-quality-gate/SKILL.md
  - skills/component-api-stability/SKILL.md
  - skills/driver-bringup-checklist/SKILL.md
  - skills/fault-injection-recovery/SKILL.md
  - skills/integration-hil-sil/SKILL.md
  - skills/interface-contract-design/SKILL.md
  - skills/interrupt-dma-patterns/SKILL.md
  - skills/performance-profiling-embedded/SKILL.md
  - skills/protocol-stack-integration/SKILL.md
  - skills/register-map-design/SKILL.md
  - skills/release-versioning/SKILL.md
  - skills/requirements-triage/SKILL.md
  - skills/rtos-task-design/SKILL.md
  - skills/static-analysis-c-cpp/SKILL.md
  - skills/systematic-debugging/SKILL.md
  - skills/task-breakdown/SKILL.md
  - skills/toolchain-debug-openocd-gdb/SKILL.md
  - skills/unit-test-embedded/SKILL.md
  - skills/verification-before-completion/SKILL.md
- 建议动作：进入 adoption-matrix 评估（adopt / observe / reject）

## hermes-agent

- 分组：delivery
- 优先级：P1
- 状态：active
- owner：gdk-team
- intake_policy：observe-first
- 上次复审：2026-05-02
- 关注说明：大型 Agent 工程参考
- 变更文件：
  - AGENTS.md
  - README.md
  - scripts/build_model_catalog.py
  - scripts/install.sh
  - scripts/release.py
  - skills/mlops/inference/obliteratus/SKILL.md
  - ui-tui/README.md
- 建议动作：进入 adoption-matrix 评估（adopt / observe / reject）

## hermes-collaboration-skill

- 分组：agent-ecosystem
- 优先级：P1
- 状态：active
- owner：gdk-team
- intake_policy：observe-first
- 上次复审：2026-05-02
- 关注说明：团队协作能力参考
- 变更文件：
  - README.md
  - github/workflows/ci.yml
- 建议动作：进入 adoption-matrix 评估（adopt / observe / reject）

## hermes-team-skill

- 分组：agent-ecosystem
- 优先级：P2
- 状态：active
- owner：gdk-team
- intake_policy：observe-first
- 上次复审：2026-05-02
- 关注说明：轻量团队技能样例
- 变更文件：
  - README.md
  - SKILL.md
  - scripts/project_memory_manager.py
- 建议动作：进入 adoption-matrix 评估（adopt / observe / reject）

## mattpocock-skills

- 分组：agent-ecosystem
- 优先级：P1
- 状态：active
- owner：gdk-team
- intake_policy：adopt-first
- 上次复审：2026-05-02
- 关注说明：可组合技能体系
- 变更文件：
  - README.md
  - diagnose/SKILL.md
  - diagnose/scripts/hitl-loop.template.sh
  - scripts/link-skills.sh
  - scripts/list-skills.sh
  - skills/caveman/SKILL.md
  - skills/deprecated/README.md
  - skills/deprecated/design-an-interface/SKILL.md
  - skills/deprecated/qa/SKILL.md
  - skills/deprecated/request-refactor-plan/SKILL.md
  - skills/deprecated/triage-issue/SKILL.md
  - skills/deprecated/ubiquitous-language/SKILL.md
  - skills/design-an-interface/SKILL.md
  - skills/diagnose/SKILL.md
  - skills/diagnose/scripts/hitl-loop.template.sh
  - skills/domain-model/SKILL.md
  - skills/edit-article/SKILL.md
  - skills/engineering/README.md
  - skills/engineering/diagnose/SKILL.md
  - skills/engineering/diagnose/scripts/hitl-loop.template.sh
  - skills/engineering/domain-model/SKILL.md
  - skills/engineering/github-triage/SKILL.md
  - skills/engineering/grill-with-docs/SKILL.md
  - skills/engineering/improve-codebase-architecture/SKILL.md
  - skills/engineering/setup-matt-pocock-skills/SKILL.md
  - skills/engineering/tdd/SKILL.md
  - skills/engineering/to-issues/SKILL.md
  - skills/engineering/to-prd/SKILL.md
  - skills/engineering/triage/SKILL.md
  - skills/engineering/zoom-out/SKILL.md
  - skills/git-guardrails-claude-code/SKILL.md
  - skills/git-guardrails-claude-code/scripts/block-dangerous-git.sh
  - skills/github-triage/SKILL.md
  - skills/grill-me/SKILL.md
  - skills/improve-codebase-architecture/SKILL.md
  - skills/migrate-to-shoehorn/SKILL.md
  - skills/misc/README.md
  - skills/misc/git-guardrails-claude-code/SKILL.md
  - skills/misc/git-guardrails-claude-code/scripts/block-dangerous-git.sh
  - skills/misc/migrate-to-shoehorn/SKILL.md
  - skills/misc/scaffold-exercises/SKILL.md
  - skills/misc/setup-pre-commit/SKILL.md
  - skills/obsidian-vault/SKILL.md
  - skills/personal/README.md
  - skills/personal/edit-article/SKILL.md
  - skills/personal/obsidian-vault/SKILL.md
  - skills/productivity/README.md
  - skills/productivity/caveman/SKILL.md
  - skills/productivity/grill-me/SKILL.md
  - skills/productivity/write-a-skill/SKILL.md
  - skills/qa/SKILL.md
  - skills/request-refactor-plan/SKILL.md
  - skills/scaffold-exercises/SKILL.md
  - skills/setup-pre-commit/SKILL.md
  - skills/tdd/SKILL.md
  - skills/to-issues/SKILL.md
  - skills/to-prd/SKILL.md
  - skills/triage-issue/SKILL.md
  - skills/ubiquitous-language/SKILL.md
  - skills/write-a-skill/SKILL.md
  - skills/zoom-out/SKILL.md
- 建议动作：进入 adoption-matrix 评估（adopt / observe / reject）

