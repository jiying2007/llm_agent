# Context Compression Preflight

## 目标
- 线程角色：asset-governance / implementation
- 目标强度：strong
- 本轮目标：全部落地 2026-07-23 成熟度审计中本地可实现的优化并闭环。
- 范围：根测试/聚合门禁/诊断、ADK Python 入口、成熟度状态语义、
  dirty 分类与本地交付证据。
- 非目标：凭证、第二 operator、独立仓 30 天试点、远端发布和 live apply。
- 成功标准：本地 blocker/major=0；外部 blocker 保持准确；两仓完整证据可重放。
- 验证命令：root/ADK targeted+full、Python 3.11/3.12 parity、final-ready。
- 可审查产物：ADK change、root tests/JSON summary、verify/review report。
- 阻塞条件：用户 dirty 无法安全分类；需要凭证/费用/外部人员/时间。
- 期望输出：本地闭环或逐项 blocked_external，不伪报 terminal maturity。

## 当前状态
- 仓库：/home/leiwenjun/bin/llm_agent
- 分支：main
- 关键文件：
- 已完成：全面审计、根因核验、ADK 56/56、双 Python quick parity。
- 未完成：实现、dirty 收敛、full 回归、复审。

### 工作区状态

```text
 m OpenSpec
 m agent-dev-kit
 M docs/software-m5-certification-plan.md
 M fixtures/reference-repository/removal/pass/removal-plan.json
 M manifests/external_practice_sources.json
 M manifests/product_maturity_scorecard.json
 M manifests/software_m5_policy.json
 M scripts/check-current-status-consistency.sh
 M subrepos/adoption-matrix.jsonl
 M subrepos/adoption-matrix.md
 m superpowers
 M tests/test_product_maturity_contracts.sh
 M tests/test_software_m5_certification.sh
 M tools/codex_assets/software_m5.py
 m vibeflow
?? .cache/
?? hermes/
?? hermes_data/
?? reports/external-practice-absorption-candidates-2026-07-23.jsonl
?? reports/external-practice-absorption-decisions-2026-07-23.jsonl
?? reports/external-practice-absorption-implementation-2026-07-23.md
?? reports/external-practice-candidates-2026-07-22.jsonl
?? reports/external-practice-candidates-spec-kit-2026-07-23.jsonl
?? reports/external-practice-cycle-2026-07-22.md
?? reports/external-practice-cycle-evidence-2026-07-22.json
?? reports/external-practice-decisions-spec-kit-2026-07-23.jsonl
?? reports/external-practice-evidence-spec-kit-2026-07-23.json
?? reports/external-practice-recommendations-2026-07-22.json
?? reports/external-practice-recommendations-2026-07-22.md
?? reports/external-practice-review-queue-2026-07-22.json
?? reports/external-practice-search-and-absorption-candidates-2026-07-22.md
?? reports/observe-secondary-intake-packages-2026-07-23.md
?? reports/reference-analysis-spec-kit-2026-07-23.md
?? reports/reference-duplicate-review-spec-kit-2026-07-23.md
?? reports/reference-repository-onboarding-spec-kit-2026-07-23.json
?? reports/reference-repository-onboarding-spec-kit-2026-07-23.md
?? reports/reference-security-review-spec-kit-2026-07-23.md
?? reports/spec-kit-reference-onboarding-implementation-2026-07-23.md
```

### 变更规模

```text
OpenSpec                                           |   0
 agent-dev-kit                                      |   0
 docs/software-m5-certification-plan.md             |  27 ++
 .../removal/pass/removal-plan.json                 |   2 +-
 manifests/external_practice_sources.json           |  42 +--
 manifests/product_maturity_scorecard.json          |   2 +-
 manifests/software_m5_policy.json                  | 120 +++++++-
 scripts/check-current-status-consistency.sh        |   1 +
 subrepos/adoption-matrix.jsonl                     |  11 +
 subrepos/adoption-matrix.md                        |  11 +
 superpowers                                        |   0
 tests/test_product_maturity_contracts.sh           |   1 +
 tests/test_software_m5_certification.sh            | 322 ++++++++++++++++++++-
 tools/codex_assets/software_m5.py                  | 189 +++++++++++-
 vibeflow                                           |   0
 15 files changed, 698 insertions(+), 30 deletions(-)
```

### 最近提交

```text
7b3ef85 feat(subrepos): 重激活mattpocock技能参考仓
71e00f8 feat(governance): 支持参考子仓安全重激活
18b2ab3 docs(status): 锁定RC5意图边界基线
a9775b1 feat(governance): 吸收skills意图边界实践
e7b92ef docs(status): 锁定RC4外部实践吸收基线
```

## Context Layout
### Stable Context
- 仓库硬规则：全部 shell 经 rtk；手工编辑用 apply_patch；不覆盖用户 dirty；
  无证据不声明完成。
- 长期决策：整体 M3/M5-ready-but-blocked；field evidence 不可模拟。
- 可复用工作流：ADK change lifecycle、root check-all、local CI parity。
- 可提升候选：根测试完整性与有界失败日志。

### Dynamic Context
- 当前目标：terminal-maturity-optimization-v2。
- 当前范围：见目标区。
- 当前工作区状态：见上方工作区状态和变更规模
- 最近验证：ADK full 56/56；root full 52/58；root tests 13/15。
- 下一条命令：实现 root runner 与 architecture fixture。

### Evidence Context
- 命令 / 退出码：见 ADK change `negative-results.md`。
- 工件路径：`agent-dev-kit/docs/changes/terminal-maturity-optimization-v2/`。
- 负结果或被排除路径：root fixture 漂移、expired baselines、unsupported host。
- 证据缺口：当前候选 full supported Python、clean/approved worktree、source-to-live。

### Excluded Context
- 不写入：secrets、auth、sessions、长日志、缓存、未审查 memory
- 需要脱敏后再归档：

## 关键决策（只保留可复用）
- 决策 1：先修测试/诊断合同，再处理共享状态。
- 决策 2：外部 M5 blocker 不由本地代码替代。

## 自动结晶（Crystallized Insights）
- Insight 1：
- 为什么重要：
- 是否应提升到 AGENTS / archive / memory：

## 操作队列
- steer：统一根测试 runner 和 fixture。
- queue：Python/status/state/full/review。
- scope-change：从只读审计切换为用户授权的本地实现闭环。

## 未决张力（Open Tensions）
- Tension 1：用户 dirty 需要保留，但 strict gate 要求可审查状态。
- 为什么还没闭环：必须先分类和固定证据，不能直接清理或续期。
- 下次恢复时先验证什么：三个 reference worktree 的 diff 类别与 baseline hash。

## 约束与风险
- 约束：不 commit/push/apply，除非用户进一步明确。
- 风险：共享 scorecard 与现有 M5 dirty 修改冲突；聚合脚本递归增加时延。

## 下一步（可执行）
- Step 1: root runner/fixture/diagnostics。
- Step 2: Python/effective-level/state closure。
- Step 3: full parity/review/final-ready。

## 可审查产物
- Markdown note：本文件和 ADK change。
- index.html / 预览 / 截图：
- CSV / 表格 / 数据产物：
- diff / 测试报告 / artifact report：verify-report/review-report。
- 归档或提升建议：稳定 commit 后写 Hub reviewing validation candidate。

## 验证命令
- `rtk bash scripts/check.sh`
- `rtk git diff --check`

## 恢复提示（Resume Prompt）
继续处理：terminal-maturity-optimization-v2 本地优化闭环。
从这些文件继续：本报告、ADK change tasks/negative-results。
先执行：读取 `tasks.md` 当前未完成的第一个 T 项。
