# Codex Goal: ADK Practice Source Governance Hard Cut

thread_role:
  作为 llm_agent / agent-dev-kit 架构治理执行者，先理解两个仓库职责，再执行硬切换式去耦合与通用化收口。

goal:
  将 agent-dev-kit 优化为 source-neutral、runtime-neutral、长期可维护可扩展的 Agent/Skill/Profile/Workflow 资产包；将 OpenAI、Codex、Claude、优秀 OSS 和官方实践统一降格为 llm_agent 管理的参考来源、证据来源或显式 runtime adapter/handoff，不允许来源名继续污染 ADK core active 命令、脚本、测试、runbook 和默认 profile。

scope:
  - 检查 llm_agent 与 agent-dev-kit 当前目标、manifest、docs、scripts、tests、adoption matrix 和 runtime routing。
  - 设计并落地四层边界：reference/practice sources、practice patterns、neutral ADK assets、runtime adapters/handoffs。
  - 硬替换 active OpenAI/Codex 命名入口为 generic 能力名；同步调用方、测试、文档和门禁。
  - 建立 allowlist boundary check，区分合法 provenance 与非法 core coupling。
  - 保留 Codex 作为 external_handoff_targets，不加入 direct tool_targets；保留 OpenAI/Codex 历史证据但迁入 provenance/reference 边界。
  - 更新采纳/吸收治理，使 Prompt Engineering、Context Engineering、Harness Engineering、Loop Engineering、skill、agent、workflow、profile 候选通过统一 practice pattern 决策进入 ADK。

non_goals:
  - 不同步参考子仓到最新代码，除非执行中发现验证必须依赖该动作并先说明原因。
  - 不直接修改 ~/.codex；Codex live 应用只能经 ~/codex source-to-live 链路。
  - 不保留旧 openai/codex active 命令兼容壳。
  - 不删除 adoption matrix、archive、reports 中的历史 provenance。
  - 不把 ADK 重新定位为 Codex 专用、OpenAI 专用或 Claude 专用资产包。

success_criteria:
  - ADK core active 命令、脚本、测试、runbook、profile 默认路径均使用 source-neutral 命名。
  - `openai|codex` 扫描结果全部可归类为 reference_sources、external_handoff_targets、source registry、reference docs、historical reports、adoption matrix 或参考子仓内容。
  - `manifest.yaml` 清楚表达：reference_sources 不启用 runtime；tool_targets 只含 direct export targets；Codex 只在 external_handoff_targets。
  - llm_agent 吸收流程能把官方实践和 OSS 实现归一为 practice pattern，再映射到 ADK assets，而不是按来源追加平行资产。
  - 所有变更有测试和门禁证据；提交前工作区 dirty 状态可解释，不覆盖用户或参考仓既有改动。

verification_commands:
  - rtk git status --short
  - rtk rg -n "OpenAI|openai|Codex|codex" agent-dev-kit scripts docs subrepos manifests AGENTS.md
  - rtk agent-dev-kit/scripts/check-runtime-boundary.sh
  - rtk bash agent-dev-kit/scripts/devkit.sh validate --strict
  - rtk agent-dev-kit/tests/run_all.sh
  - rtk scripts/check-adk-harden-readiness.sh .
  - rtk scripts/check-all.sh --quick
  - 若修改 ~/codex 资产，运行完整 ~/codex build/doctor/plan/apply/check source-to-live 链路。

review_artifacts:
  - 变更文件清单和关键 diff 摘要。
  - OpenAI/Codex residual allowlist 报告。
  - practice source governance 或 absorption decision 报告。
  - ADK runtime boundary 验证摘要。
  - root 与 ADK 测试结果摘要。
  - 如有提交，提供 commit hash；如有推送，提供远端分支状态。

blockers:
  - 发现旧命令被外部未迁移入口强依赖，且无法在本轮定位调用方。
  - boundary checker 无法区分历史 provenance 与 active coupling。
  - 关键验证脚本失败且根因超出本轮 scope。
  - 工作区存在用户改动与本目标冲突，继续会覆盖用户内容。

closeout_actions:
  - 先给 issue map，再实施修复。
  - 完成后报告 fixed、intentionally left、validation、residual risk。
  - 不满足 success_criteria 时不得标记 goal complete。
  - 若完成并需要继续同线程新 goal，提示先执行 /goal clear。
