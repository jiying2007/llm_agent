# 微信公众号研究流水线与优化评估验证记录

## 1. 验证结论

本轮交付通过源码、运行态、负例和三仓治理四层验证：

1. `~/codex` 已新增版本化 `wechat-account-research` Skill、确定性 CLI、workflow route、recipe、eval suite 和 7 个单元测试，并完成 `~/codex -> ~/.codex` 的受管发布链路。
2. 真实前向试跑在微信 CAPTCHA 处按设计返回 `partial-access-gated`，没有重试绕过，也没有持久化文章正文、Cookie、session 或临时签名 URL。
3. `llm_agent` 已增加“采集归档”和“吸收决策”的分层入口；20 篇文章逐篇评估为 `MERGE=4`、`REFERENCE_ONLY=16`，跨文章净新增 `ADOPT=1`。
4. `agent-dev-kit` 没有代码或资产变更。其现有 Hook、Harness、Context/Token、Memory、Skill/Workflow、Multi-Agent 和 evaluation 合同已覆盖文章中的平台中立实践；完整回归证明保留现状没有破坏基线。
5. 脱敏评估已通过 Hub 原生 capture 登记为 `reviewing/project-archive` 候选；没有提升 active、关闭 owner gate 或写入 memory。

## 2. 交付物与责任边界

| 层 | 交付物 | 验证重点 |
|---|---|---|
| Codex source | `src/codex-home/vendor/skills/wechat-account-research/0.1.0/` | 版本、触发、证据合同、渐进披露 |
| Codex runtime tool | `tools/codex_assets/wechat_archive.py`、`scripts/wechat-archive.sh` | `plan -> collect -> report -> check`、非仓库 cwd、失败状态 |
| Codex manifests | skill、workflow、recipe、eval suite | primary/supporting/fallback 路由、profile 和治理一致性 |
| Codex live | `~/.codex/vendor/skills/wechat-account-research/0.1.0/` | source-to-live diff/drift 和可发现性 |
| llm_agent | 根 `AGENTS.md`、维护指南、评估与本验证记录 | 意图路由、吸收边界、长期证据 |
| agent-dev-kit | 无变更 | strict validation、runtime boundary、官方资料治理、完整回归 |

采集器只生成 metadata-only、`review-required` 证据。它不自动把文章观点提升为 Codex/ADK 规则，也不把文章正文写入 Knowledge Hub、memory 或 ADK。

## 3. Codex 源码与运行态证据

### 3.1 定向测试

| 验证 | 结果 |
|---|---|
| `tests.test_governance tests.test_skill_catalog tests.test_wechat_archive` | 51 tests passed |
| `tests.test_profile_documentation` | 5 tests passed |
| `scripts/check-skills.sh` | `skills=63 errors=0 warnings=0` |
| 新增 WeChat 测试 | 7 tests，覆盖预算上限、账号别名、Hermes 索引去重、hash/正文禁存、report/check、access gate、浏览器 wait timeout |
| 非 Codex cwd skill search | `wechat-account-research` 得分 788，命中 batch route；`browser-reader` 为 fallback，archive/absorption 为 supporting |

### 3.2 完整 `scripts/check.sh`

最终完整门禁退出码为 0：

- governance、repo/build/live doctor：`errors=0 warnings=0`；
- Python tests：`95/95`；
- 新 WeChat fixture：1 个 eligible、1 个 account mismatch，archive check `errors=[]`；
- skill catalog：63 个 skill，无 error/warning；
- `minimal`、`solo-dev`、`token-lean`、`team-collab`、`superpowers-compat` 五个 profile 的 build/install/diff/drift smoke 全部通过；
- 最终 live：`same=439 diff=0 missing=0`，`changed=0 stale=0 unmanaged=0`。

### 3.3 source-to-live 审计

首次 apply 前的受管计划为：`copy=5 keep=434 overwrite=1 delete=0 mkdir=274`。逐项审计确认变更仅为五个新增 Skill 文件和受管状态文件，没有无关 overwrite/delete。dry-run 与实际 apply 使用同一计划，实际 apply 完成。

后续完整检查重新构建后，校验计划为 `copy=0 keep=440 overwrite=0 delete=0`，说明 source、build 与 live 已一致。默认 profile 仍是 `token-lean`；新 Skill 以 deferred 方式登记，但版本化实体已进入 live，可通过受信 inventory 延迟发现。

## 4. 真实前向负例

前向试跑使用 2 个目标账号、4 个受限查询、1 个 seed URL、`max_candidates=1`，并接入 Hermes `articles.json` 只读索引和临时 `agent-browser`：

| 阶段 | 结果 |
|---|---|
| `plan` | 查询预算和 candidate 上限生效 |
| `collect` | 微信页面返回 CAPTCHA；命令按合同以退出码 3、`partial-access-gated` 结束 |
| retry | access gate 后重试预算为 0；未使用代理、UA/身份轮换或 CAPTCHA 绕过 |
| evidence | 只记录 `access-gated` 负证据，`accepted=0` |
| `report` | 生成零 eligible 的覆盖报告，保留失败状态 |
| `check` | `errors=[]`；确认 `body_persisted=false`，无临时签名 URL、Cookie 或 session |

这证明工具在当前网络条件下不能宣称“可持续抓取微信正文”，但证明了安全停止、可审计负状态和 metadata-only 边界。此前 Hermes 的成功读取证据仍是本轮 20 篇文章评估的数据来源。

## 5. llm_agent 与 ADK 验证

### 5.1 llm_agent

| 命令 | 结果 |
|---|---|
| `scripts/check-doc-sync.sh .` | pass |
| `scripts/check-agents-coverage.sh .` | pass；7 个 active 子仓全部有 local/overlay 规则覆盖 |
| `scripts/check-all.sh --quick` | `56/56`，exit 0 |
| `scripts/check-all.sh --full` | `62/62`，exit 0 |

full 门禁包含并通过：ADK harden readiness、ADK performance ops、evidence bundle、token budget、WeChat intake ledger、workspace entrypoints 以及所有 quick 项。`check-wechat-intake-ledger` 单项通过，说明新增评估记录没有破坏既有公众号文章账本治理。

### 5.2 agent-dev-kit

| 命令 | 结果 |
|---|---|
| `scripts/devkit.sh validate --strict` | pass |
| `scripts/devkit.sh runtime-boundary` | pass |
| `scripts/devkit.sh official-docs-governance --summary-json` | pass；69 sources、9 eval suites、5 hook events、failures=0 |
| `tests/run_all.sh` | `52/52`，exit 0 |

ADK 工作树没有本任务产生的变更。公众号搜索/浏览属于 Codex 运行时研究能力；将其反向导入平台中立 ADK core 会违反运行时边界，并与现有 research intake / external practice absorption 职责重叠。

## 6. 失败、修正与剩余限制

| 观察 | 处理 | 最终证据 |
|---|---|---|
| 初始 `openai.yaml` 的 `short_description` 过短 | 按生成器约束调整描述后重新生成 | staging skill 的通用 quick validator 通过 |
| Codex repo 要求 Skill frontmatter 含 `version/last_updated`，通用 skill-creator validator 不接受额外键 | 保留 Codex SSOT 的必需字段，使用仓库专属 `check-skills.sh` 作为最终门禁 | 63 skills、0 error、0 warning；这是 validator contract 差异，不隐藏为通用 validator 通过 |
| `agent-browser wait` 即使 `allow_failure=True` 仍抛出 timeout | 修正容错路径并增加回归测试 | 7 个 WeChat 单测通过；前向试跑进入真正的 CAPTCHA gate |
| 新 deferred skill 使 README 的 `team-collab` 计数仍为 60 | 修正为实际值 61 | profile 文档 5/5、完整 Codex 95/95 通过 |
| 微信真实页面触发 CAPTCHA | 将其保留为终止型负证据，不规避 | collect exit 3；report/check 可正常完成 |
| Codex `archive-note` 的旧 project registry 不认识 Hub 已登记的 `llm-agent`；fallback 还写出绝对路径 sidecar 和未登记 body | 精确删除本次新增的 3 个未跟踪文件，未修改既有 Hub 资产；改用 Hub 原生 `knowledge-capture` | 回滚后 Hub 恢复 0 error/0 warning；未把不合规归档留在长期层 |

剩余限制：搜狗结果是排序检索而非账号全量导出；近期文章可能有索引延迟；没有登录态时微信可能阻断正文读取；所有候选仍需人工复核。因此本交付声明的是“可控、可复跑、可审计的研究归档工作流”，不是“无条件完整抓取能力”。

## 7. Knowledge Hub 候选

使用 Hub 原生 `knowledge-capture.sh` 先 dry-run、后 apply，最终生成：

- item id：`llm-agent-wechat-account-research-assessment-20260716`；
- path：`projects/llm-agent/archive/research/2026-07-16-wechat-account-research-optimization-assessment.md`；
- status/kind：`reviewing` / `project-archive`；
- `active_promotion=false`、`manual_validation_pending=true`、`promotion=none`；
- transaction：1 份候选正文、1 条 registry item、1 条 lifecycle event、5 个派生索引，共 8 个受控写入。

验证结果：`knowledge-check --dry-run --json --diagnostics` 为 0 error/0 warning，`knowledge-link-audit --strict` 通过，精确 ID 搜索以 975 分返回 registry-backed 候选，`git diff --check` 通过。该候选只保存本评估摘要与决策证据，不包含文章正文、Cookie、session、临时 URL 或 memory 写入。

## 8. Dirty 状态与回退

- `~/codex` 在本任务前已有大量用户 dirty 变更；本任务没有回退、重排或清理它们。
- `llm_agent` 既有 Hermes、Hermes data 和其他子仓状态均保留；本任务只追加路由、维护说明和评估证据。
- 未执行 commit、push、merge 或 rebase。
- 回退边界仅包括新 WeChat Skill、CLI/wrapper、测试、四类 manifest 条目、README profile 计数和 `llm_agent` 的对应路由/报告；不得用破坏性命令清理整个工作树。
