# Codex Skill 路由与交付门禁提交推送证据

- 日期：2026-07-24
- 源仓：`/home/leiwenjun/codex`
- 分支：`main`
- 状态：checked / committed / pushed / live-consistent
- 归档状态：Knowledge Hub candidate（未自动写入 Hub）
- 原子提交：`cd6243185ae51902dcbded76960d67ebe0ddbc88 feat(governance): 完善 Skill 路由、自动化与交付门禁`
- 远端终点：`origin/main=cd6243185ae51902dcbded76960d67ebe0ddbc88`

## Scope Summary

本次收口原 `~/codex` 的 40 项 dirty 状态，并在审计过程中补齐一个版本一致性缺口。最终提交共涉及 50 个文件，主要包括：

1. 新增月度 workflow mining 的 disabled、report-only 自动化合同。
2. 为 workflow 增加显式 route schema 和治理校验，要求 primary、supporting、fallback、mutually-exclusive 引用合法且边界清晰。
3. 新增 Skill routing eval 数据与“每个 case 仅一个 primary Skill”回归。
4. 新增 `embedded-audio-stream-triage`、`embedded-production-test-lifecycle`，并将 `embedded-core-dump-triage`、`embedded-log-triage` 从 `0.1.0` 迁移到 `0.2.0`。
5. 强化本地 Skill 命令必须经 `rtk`、脚本引用必须存在、source Skill 必须注册等门禁。
6. 更新 profile、Skill lifecycle、asset management 和 source-to-live 文档及 `manifests/lock.json`。

明确非目标：

- 未执行 merge、rebase、force push、tag、Release 或 PR。
- 未放宽权限、approval、MCP deny-path、模型或上下文配置。
- 未把本证据报告混入 `~/codex` 提交。

## Completion Claim Audit

| 声明 | Verifier 证据 | 结论 |
|---|---|---|
| dirty 已完整审计并形成原子提交 | `git show --stat HEAD` 为 50 文件；`git status --porcelain=v1 --branch` 清洁 | supported |
| source、build、governance、tests、smoke 均通过 | `scripts/check.sh --pre-apply` 与提交后的 `scripts/check.sh` 均返回 0 | supported |
| live 与 source 一致 | post-apply `check.sh`：`same=439 diff=0 missing=0`，drift 为 0 | supported |
| 远端安全快进完成 | push 前远端仍为 `43c6c83...`；普通 `main:main` push 后远端精确等于 `cd62431...` | supported |
| 没有未闭环 blocker | governance、Skill、MCP deny-path、bwrap、5 profile smoke 均无错误 | supported |

## Negative Path 与修复

审计发现 `src/codex-home/skills/registry.csv` 中：

- `embedded-core-dump-triage`
- `embedded-log-triage`

仍声明为 `0.1.0`，而 `manifests/skills.json` 已迁移到 `0.2.0`。该负路径会造成 registry 与 manifest 的版本漂移。

修复动作：

1. 将两个 registry 版本更新为 `0.2.0`。
2. 新增 `test_skill_registry_versions_match_manifest`，使同类漂移以后 fail closed。
3. 重新运行 57 项定向测试、Skill 门禁、governance doctor、pre-apply 全量门禁和提交后 post-apply 全量门禁。

原计划把自动化与其余治理变更拆成两个提交；暂存复核发现 `manifests/lock.json` 同时包含两组变更的最终哈希。为避免第一个提交产生 stale lock，中止该拆分并把本轮尚未推送的新提交修订为一个可独立验证的原子提交。没有改写更早历史。

## Verification Command Results

| Command | Exit Code | Result Summary | Evidence Path | Layer | Related Artifact |
|---|---:|---|---|---|---|
| `rtk python3 -m unittest tests.test_profile_documentation tests.test_check_skills tests.test_governance tests.test_agent_routing_eval` | 0 | 57 tests，全部通过 | 本报告 | Test | registry / Skill / routing governance |
| `rtk bash scripts/check-skills.sh` | 0 | skills=63，errors=0，warnings=0 | 本报告 | Skill | `manifests/skills.json` |
| `rtk bash scripts/doctor.sh --scope governance` | 0 | errors=0，warnings=0 | 本报告 | Workflow | governance contracts |
| `rtk git diff --check` | 0 | 无 whitespace error | 本报告 | Repository | source diff |
| `rtk bash scripts/check.sh --pre-apply` | 0 | 110 tests、5 profile smoke、plan/dry-run 全部通过 | 本报告 | Workflow | pre-apply gate |
| `rtk bash scripts/check.sh`（提交后） | 0 | 110 tests、5 profile smoke；`same=439 diff=0 missing=0`，drift=0 | 本报告 | Workflow | post-apply/live gate |
| `rtk git ls-remote origin refs/heads/main`（push 前） | 0 | 远端仍为审计基线 `43c6c83ce38cdc43bd24324a40a1487e4f9df66e` | 本报告 | Repository | concurrency preflight |
| `rtk git push origin main:main` | 0 | 普通 fast-forward push 成功 | 本报告 | Repository | `cd62431` |
| `rtk git ls-remote origin refs/heads/main`（push 后） | 0 | 远端精确等于 `cd6243185ae51902dcbded76960d67ebe0ddbc88` | 本报告 | Repository | remote verification |
| `rtk bash scripts/final-ready.sh` | 0 | final-ready pass；session coach 仅提示 THREAD_LONG | 本报告 | Workflow | final gate |

## Runtime、Prompt 与权限核验

- Runtime config：默认 profile 仍为 `token-lean`；post-apply doctor 对 repo/build/live 均为 0 errors、0 warnings。
- Prompt/routing regression：新增 routing fixture 覆盖 diagnostic CLI、远端日志、离线日志、通用 core、PCR02/SigmaStar core、音频流、生产测试 lifecycle 和协议审计，并验证每个 case 恰有一个 primary Skill。
- 权限与 transport：MCP deny-path tests 通过；没有修改 MCP server、permission profile、approval policy、模型或上下文上限。
- 自动化：`monthly-workflow-mining-report` 默认 disabled、report-only、manual approval，不产生自动外部写操作。

## Breaking Change、风险与回退

- Breaking change 判断：没有公共 CLI breaking change。两个本地 embedded Skill 的 `0.1.0 -> 0.2.0` 是受管资产版本迁移，manifest、registry、lock、route 和 live 已同步更新。
- 行为变化：generic core dump 继续由 `adk-offline-core-dump-triage` 主路由；PCR02/SigmaStar 专用 core 才路由到 `embedded-core-dump-triage`。离线/粘贴日志与设备远端日志也已显式互斥。
- 剩余风险：没有代码或交付 blocker。会话 coach 报告 `THREAD_LONG/CRITICAL`，因此本报告完成后应结束当前长线程。
- 回退：远端已快进，不改写历史；如需撤销，创建针对 `cd62431` 的可审查 `git revert` 提交，再重新执行完整 source-to-live 门禁。

## Final Gate Result

`pass`

源码、manifest、lock、测试、5 profile smoke、live consistency、本地 Git 状态和远端 SHA 均已有相互独立的证据。当前没有未解释的 skipped test、blocker、远端漂移或 source/live drift。
