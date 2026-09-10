
## 关于 rtk 命令

`rtk` 是工作区统一命令入口工具。位于 `llm_agent` 受治理工作区时，所有 shell 命令必须通过 `rtk` 执行；不要在本工作区文档、门禁或会话中使用裸 `bash`、`git`、`rg`、`sed`、`awk`、`python` 等命令作为执行入口。

**rtk 与 bash 的对应关系：**
- `rtk scripts/xxx.sh` 等价于 `bash scripts/xxx.sh`
- `rtk bash -lc "..."` 等价于 `bash -lc "..."`

**安装 rtk：**
```bash
# 本工作区默认要求 rtk；缺失时先安装或修复 rtk，再执行维护命令。
```

# llm_agent 持续维护与生产验证指南

## 1. 定位

`llm_agent` 是 adk 的上游治理工作区，负责四件事：

1. 管理参考子仓清单与同步策略。
2. 从参考子仓提炼可采纳实践，并记录采纳/观察/拒绝原因。
3. 推动 `agent-dev-kit` 落地、验证，并导出可交接资产。
4. 将 adk 资产交给 `~/codex` 作为声明式 Codex Home 源，再由 `~/codex` build/apply 到 `~/.codex`，最后把真实运行结果回灌。

不推荐在 `llm_agent` 中直接改 `~/.codex` 运行资产。生产运行资产应先由 `agent-dev-kit` 导出，经 `~/codex` 注册到 `src/codex-home/` 与 `manifests/`，再由 `~/codex/scripts/build.sh` 和 `~/codex/scripts/apply.sh` 注入 `~/.codex`。报告需记录 adk 版本、profile、optional skill、`~/codex` build/apply 证据和 `~/.codex` 健康检查结果。

运行态 target registry 位于 `manifests/runtime_targets.json`，健康检查 adapter contract 位于 `manifests/runtime_health_adapters.json`。当前默认 target 是 `codex-home`；`check-runtime-targets.sh` 会验证它与 `adk.lock`、`subrepos/registry.csv`、adapter contract 和 runtime 检查脚本一致。新增 `claude-code`、`hermes-agent`、`opencode` 等运行态时，先按 `docs/runbooks/runtime-target-activation.md` 补 source/live chain、只读 health adapter、写入策略和候选阻断证据，再允许成为 active target。

参考子仓 dirty 只允许通过 `subrepos/dirty-baseline.tsv` 和 `reports/reference-dirty-triage-YYYY-MM-DD.*` 解释，不允许在治理提交中静默清理或混入参考仓文件。baseline 必须区分 `mode/content/type/untracked/staged` 并声明 `commit-snapshot-only`；`generate-reference-dirty-triage.sh` 只读采集分类与 status sample，`check-reference-dirty-triage.sh` 默认选择 latest valid schema v2 报告，并按当天日期重新判断 baseline 是否过期。深度分析必须通过 `analyze-repo.sh` 的安全 `git archive` 快照读取，报告只写根仓 `reports/repo-analysis/<repo>/<commit>/`，并固定生成 `analysis.json`、`decision-candidate.json`、`task-pack.json`。静态分析完成只表示 `static-complete`；决策必须保持 `review-required`，不能直接写入 ADK。

一键更新使用 `scripts/pipeline-subrepo-update.sh`。pipeline 按 registry 与动态评分共同选择近期 S/A 参考源，记录 `grade_drift`，跨仓模式只聚合 commit-snapshot 证据。任一 sync/diff/grade/analyze 阶段失败都返回非零并写结构化失败报告；仓库不提供自动吸收写入口。

## 2. 目录职责

| 路径 | 职责 | 维护要求 |
|---|---|---|
| `AGENTS.md` | 工作区入口、意图路由、硬边界和高频验证入口 | 只在路由、硬边界或高频入口变化时同步更新；不得承载完整子仓清单 |
| `subrepos/registry.csv` | 参考子仓单一清单 | 新增/禁用子仓必须更新 |
| `subrepos/adoption-matrix.md` | 候选采纳矩阵 | 每个候选必须有决策、状态、目标层和证据 |
| `subrepos/adoption-matrix.jsonl` | 候选矩阵结构化导出 | 由 Markdown 矩阵机械生成，供脚本低 token 读取 |
| `subrepos/phase-gate.env` | 是否允许追踪上游更新 | 默认先压实 adk，再开门同步 |
| `subrepos/dirty-baseline.tsv` | observe 子仓预期 dirty 状态 | 区分已知参考仓噪音与本轮风险 dirty |
| `adk.lock` | adk 版本和子模块指针锁 | adk 升级或子模块指针变化时同步更新 |
| `manifests/` | external-practice source/cycle、reference repository lifecycle、runtime target/adapter 声明 | 修改后必须运行对应 contract 检查 |
| `fixtures/external-practice/` | 多来源 candidate/decision/cycle 和 repository handoff 正负样例 | 修改后必须运行 practice intake 测试 |
| `tests/` | 根仓定向回归测试 | 新增脚本或 fixture 后补相应测试入口 |
| `scripts/` | 治理、同步、门禁脚本 | 新脚本必须写入 `scripts/README.md` |
| `reports/` | pilot、安装、周报、wave 记录 | 生产结论必须有报告证据 |
| `agent-dev-kit/` | adk 源资产与测试 | 所有候选能力先在这里压实并导出 |
| `~/codex` | 本机 Codex CLI 声明式资产仓库 | 吸收 adk 资产，执行 build/doctor/apply，再影响 `~/.codex` |

## 3. 维护流程

### 3.0 AGENTS 瘦身边界

根 `AGENTS.md` 是 AI 进入本仓时的低 token 入口，不是治理资料库。维护时遵循以下分流：

- 子仓是否纳入治理、owner、状态、复审日期：写入 `subrepos/registry.csv`。
- 候选实践的采纳/观察/拒绝、目标层和证据：写入 `subrepos/adoption-matrix.md`。
- 可复现维护流程、门禁解释、source-to-live 证据链：写入本指南或对应 runbook。
- 一次性试跑、复核、周报、证据包：写入 `reports/`。
- 根 `AGENTS.md` 只保留意图路由、命令硬约束、吸收边界、常用验证入口和文档分流。

`scripts/check-doc-sync.sh` 与 `scripts/check-agents-coverage.sh` 会强制根 `AGENTS.md` 不超过 180 行，并要求它指向 `subrepos/registry.csv`、`subrepos/adoption-matrix.md`、`docs/llm-agent-maintenance-guide.md` 和 `docs/absorption-governance.md`。新增参考仓时不要在根 `AGENTS.md` 追加仓库条目，除非新增了新的顶层路由或硬边界。

### 3.1 日常健康检查

```bash
rtk scripts/check-doc-sync.sh .
rtk scripts/check-agents-coverage.sh .
rtk scripts/check-adk-target-evidence.sh .
rtk scripts/check-adk-lock.sh .
rtk scripts/check-phase-gate.sh .
rtk scripts/check-subrepo-state.sh .
rtk scripts/check-runtime-routing.sh .
rtk scripts/check-practice-intake.sh .
rtk scripts/check-reference-repository-registration.sh .
rtk scripts/check-reference-repository-removal.sh .
rtk scripts/check-upstream-intake-readiness.sh .
rtk scripts/check-stale-references.sh .
rtk scripts/check-token-budget.sh . --summary-json
rtk scripts/check-file-modes.sh .
rtk scripts/check-runtime-health.sh . --profile minimal
```

适用场景：只确认当前状态是否健康，不同步参考仓，不部署。

跨会话优化先按 [历史与知识复用](runbooks/history-knowledge-reuse.md) 核对覆盖和现有能力；向团队交付按 [试点验收](runbooks/team-pilot-acceptance.md) 记录真实上手、失败恢复和任务收益。

### 3.2 adk 压实检查

```bash
rtk scripts/check-adk-harden-readiness.sh .
```

适用场景：修改了 adk 文档、profile、skill、agent、workflow 或 root scripts 后，需要确认基础门禁。

### 3.3 生产级放行检查

```bash
rtk scripts/check-adk-harden-readiness.sh . --require-pilot
```

适用场景：准备声明 adk 可进入 `~/codex` 生产分发链路，或准备由 `~/codex` 重新 apply 到 `~/.codex`。

该门禁会检查：

- adk strict validation
- optional skills 回归
- 外部仓库引用隔离
- skill metadata
- skill routing conflicts
- docs sync
- adoption matrix 状态
- observe backlog / delivery adopt 深度
- runtime routing
- upstream intake readiness
- adk full regression suite
- runtime pilot evidence
- runtime pilot coverage
- `~/codex` build/apply 证据与 global `~/.codex` health

### 3.3.1 治理产品化复核规则

每次复核 ADK 原生运行 footprint、upstream intake 或 `~/codex -> ~/.codex` live 状态时，必须产出可审查报告，不只更新 `subrepos/phase-gate.env`。报告默认写入 `reports/`，至少包含：

- Summary：本轮目标、非目标和结论。
- Baseline：父仓状态、`agent-dev-kit` 状态、`known_dirty/unexpected_dirty/stale_baseline`、phase gate 原状态。
- Evidence Index：关键命令、退出码、摘要和所属层级。
- Decisions：是否更新 `last_live_refresh`、`next_review_by`、`allow_upstream_sync`，以及原因。
- Residual Risk：真实设备、HIL、OTA 回滚、现场包、reference dirty 等未闭环项。

推荐先用 report-only 入口生成复核报告：

```bash
rtk scripts/governance-review.sh . --out reports/governance-review-YYYY-MM-DD.md
```

该入口只编排现有检查并生成建议，不会同步参考子仓、不会修改 phase gate、不会 apply 到 `~/.codex`。

`last_live_refresh` 只有在 `~/codex` source-to-live 链路完成并有证据时才能更新。最小证据链为：

```bash
rtk bash ~/codex/scripts/build.sh
rtk bash ~/codex/scripts/doctor.sh --scope all
rtk bash ~/codex/scripts/plan.sh --target ~/.codex --prune-stale --output ~/codex/build/apply-plan.json
rtk bash ~/codex/scripts/apply.sh --plan ~/codex/build/apply-plan.json --dry-run
rtk bash ~/codex/scripts/apply.sh --plan ~/codex/build/apply-plan.json
rtk bash ~/codex/scripts/check-routing-precedence.sh
rtk bash ~/codex/scripts/check.sh
rtk scripts/check-runtime-health.sh . --profile minimal
```

若 dry-run 显示会 `copy`、`overwrite` 或 `delete` live 资产，必须在报告中解释变更来源和风险；没有明确审查结论时，不更新 `last_live_refresh`，也不把 live 状态声明为已刷新。

参考子仓 dirty 只按 `check-subrepo-state.sh . --summary-json` 的分类处理：`known_dirty` 不阻断治理复核，`unexpected_dirty>0` 或 `stale_baseline>0` 必须先形成单独修复项，不能混入 ADK 或 phase gate 改动。

### 3.4 参考子仓同步

多来源候选发现与批准前治理见 `docs/runbooks/external-practice-intake.md`；批准后的参考仓登记与退出见 `docs/runbooks/reference-repository-lifecycle.md`。`sync-subrepos` / `diff-scan` 只处理已登记子仓，不承担发现、决策或吸收。

同步前先跑：

```bash
rtk scripts/check-adk-harden-readiness.sh . --require-pilot
```

同步和扫描：

```bash
rtk scripts/sync-subrepos.sh . fetch
rtk scripts/diff-scan.sh . 7 reports/weekly-change-report.md
```

若门禁未开，脚本会阻止同步。不要用 `--force` 常态绕过，除非只是一次性紧急扫描并会在报告里说明原因。

### 3.5 候选吸收

候选吸收先走统一 `external-practice-candidate/v1 -> owner decision -> ADK change`。不使用跨来源分数，不把 star 或官方身份当作批准；只有独立 decision 和可审查证据齐全后，才更新 `subrepos/adoption-matrix.md` 或进入 reference repository lifecycle。

### 3.5.1 微信公众号账号研究归档

指定公众号、日期窗口和主题范围的批量研究统一路由到 `~/codex` 的 `wechat-account-research`。该入口用于生成可审查研究证据，不属于 ADK 自动吸收入口：

```bash
rtk bash ~/codex/scripts/wechat-archive.sh plan \
  --account '腾讯技术工程' \
  --account '阿里云开发者|阿里开发者' \
  --date-from 2026-01-16 \
  --date-to 2026-07-16 \
  --output-dir /tmp/wechat-research

rtk bash ~/codex/scripts/wechat-archive.sh collect \
  --plan-file /tmp/wechat-research/plan.json \
  --discovery-index /path/to/hermes/articles.json \
  --output-dir /tmp/wechat-research

rtk bash ~/codex/scripts/wechat-archive.sh report \
  --plan-file /tmp/wechat-research/plan.json \
  --output-dir /tmp/wechat-research

rtk bash ~/codex/scripts/wechat-archive.sh check \
  --plan-file /tmp/wechat-research/plan.json \
  --output-dir /tmp/wechat-research
```

约束：

- Hermes `articles.json` 只作为 discovery 输入，不回写；没有索引时才使用受限 `agent-browser` 公共读取。
- CAPTCHA、登录、anti-spider、付费或安全验证页是终止状态，不使用代理池、UA/身份轮换、Cookie 或自动验证绕过。
- 正文只在内存中用于账号/日期核验、主题信号和 SHA-256；证据包不得保存正文、raw HTML、浏览器状态或临时签名 URL。
- `catalog.jsonl` 默认 `review-required`。只有再经过 `external-practice-absorption` 的语义、重复、架构、安全和验证复核，才能形成 ADK/Codex 改动。
- 搜狗返回排序结果页而非账号完整导出，最终报告必须披露索引延迟和非穷尽边界。

统一控制面固定为 `scripts/practice-intake.sh`。GitHub/GitLab/Gitee live metadata 只有显式 `--allow-network` 才执行；官方与微信 provider 只读本地受治理 manifest/catalog；所有自动阶段止于 `review-required`：

```bash
rtk scripts/practice-intake.sh cycle \
  --plan manifests/external_practice_cycle.json \
  --out-ledger reports/external-practice-candidates.jsonl \
  --out-queue reports/external-practice-review-queue.json \
  --out-evidence reports/external-practice-cycle-evidence.json \
  --out-md reports/external-practice-cycle.md
rtk scripts/practice-intake.sh check --kind candidate --input reports/external-practice-candidates.jsonl
rtk scripts/practice-intake.sh check --kind decision --input reports/external-practice-decisions.jsonl
rtk scripts/onboard-reference-repository.sh . \
  --candidates reports/external-practice-candidates.jsonl \
  --decisions reports/external-practice-decisions.jsonl \
  --candidate-id <epc-id> \
  --analysis <analysis> --duplicate-check <duplicate-review> --security-review <security-review>
rtk scripts/plan-reference-repository-removal.sh . --repo codex \
  --evidence-dependency-scan reports/subrepo-removal-plan-codex-2026-06-16.md \
  --rollback-plan reports/subrepo-removal-plan-codex-2026-06-16.md
rtk tests/test_external_practice_intake.sh
rtk tests/test_reference_repository_registration.sh
rtk tests/test_reference_repository_removal.sh
```

1. 在 `subrepos/adoption-matrix.md` 增加候选行。
2. 给出 `adopt/observe/reject`。
3. 对 `adopt + done`，必须有本地证据路径。
4. 对 delivery 类 adopt，必须覆盖 Agent/Skill/Workflow 至少一层。
5. 对安全、脚本、第三方资产，先走 `adk-security-supply-chain`。
6. 最终执行：

```bash
rtk scripts/check-adoption-matrix-status.sh .
rtk scripts/export-adoption-matrix-jsonl.sh .
rtk scripts/check-adoption-matrix-structured.sh .
rtk scripts/check-upstream-intake-readiness.sh .
rtk scripts/check-adk-harden-readiness.sh . --require-pilot
```

## 4. adk 变更分级

| 变更类型 | 最小验证 | 说明 |
|---|---|---|
| 文档说明 | `rtk scripts/check-doc-sync.sh .` | 若涉及 adk docs，还应跑 adk 相关测试 |
| runbook / workflow 文档 | `rtk agent-dev-kit/tests/run_all.sh` | 防止 catalog、格式、引用漂移 |
| Agent/Skill 内容 | `rtk agent-dev-kit/tests/run_all.sh` | 会覆盖 frontmatter、内容质量、触发矩阵 |
| profile / manifest | `rtk agent-dev-kit/tests/test_profile_coherence.sh` + `rtk agent-dev-kit/tests/run_all.sh` | 防止继承重复与未知引用 |
| install / convert 脚本 | `rtk agent-dev-kit/tests/run_all.sh` | 必须覆盖安装、转换、dry-run |
| external-practice manifest/schema | `rtk scripts/check-practice-intake.sh .` + `rtk tests/test_external_practice_intake.sh` | 防止 provider、candidate/decision/cycle、网络和正文边界漂移 |
| external-practice fixture | `rtk tests/test_external_practice_intake.sh` | 七个 provider、Gitee degraded、幂等、redaction、预算和旧 schema 负例必须一致 |
| Reference repository registration | `rtk scripts/check-reference-repository-registration.sh .` + `rtk tests/test_reference_repository_registration.sh` | 只接受 v1 candidate + 独立 `ADOPT` decision；默认 dry-run，不吸收 ADK |
| Reference repository removal | `rtk scripts/check-reference-repository-removal.sh .` + `rtk tests/test_reference_repository_removal.sh` | 只生成/校验带 artifact hash 的 removal plan，禁止自动删除 |
| root 门禁脚本 | `rtk scripts/check-adk-harden-readiness.sh . --require-pilot` | 影响生产放行链路 |
| `~/codex -> ~/.codex` 部署 | `rtk scripts/check-adk-harden-readiness.sh . --require-pilot` + `~/codex` apply plan / dry-run / health 证据 | 必须保留 backup |

## 5. 生产部署流程

生产部署不从 `agent-dev-kit` 直接写入 `~/.codex`。adk 负责校验平台中立资产；`~/codex` 负责注册源资产、构建产物、生成 apply plan，并最终注入 `~/.codex`。当前 `agent-dev-kit` core 不再提供平台专属 `codex-handoff` 命令；Codex 运行态应用以 `~/codex` source-to-live 链路为准。

```bash
rtk bash agent-dev-kit/scripts/devkit.sh validate --strict
rtk bash ~/codex/scripts/build.sh
rtk bash ~/codex/scripts/doctor.sh --scope all
rtk bash ~/codex/scripts/plan.sh --target ~/.codex --prune-stale --output ~/codex/build/apply-plan.json
rtk bash ~/codex/scripts/apply.sh --plan ~/codex/build/apply-plan.json --dry-run
rtk bash ~/codex/scripts/apply.sh --plan ~/codex/build/apply-plan.json
rtk bash ~/codex/scripts/check-routing-precedence.sh
rtk bash ~/codex/scripts/check.sh
rtk scripts/check-runtime-health.sh . --profile minimal
rtk scripts/check-adk-harden-readiness.sh . --require-pilot
```

生产安装纪律：

- 不把 `agent-dev-kit` 导出物直接作为 `~/.codex` 来源。
- `~/codex` 侧必须维护源资产与 manifest，并运行 build / doctor / apply dry-run。
- 真正写入 `~/.codex` 时由 `~/codex/scripts/apply.sh` 负责备份、覆盖策略和回滚计划。
- 使用 adk `manifest.yaml` 版本和 `~/codex` apply plan 双重记录，防止误装不匹配版本。
- 安装后必须跑 `check-runtime-health.sh`；Codex adapter 为 `check-global-codex-health.sh`。

## 6. 回滚流程

先从安装报告确认备份路径，例如：

```text
$HOME/.codex/.adk-backups/YYYYMMDDTHHMMSSZ
```

回滚原则：

1. 不直接删除 `~/.codex`。
2. 先确认备份中存在 `agents/` 与 `skills/`。
3. 回滚后执行健康检查。
4. 在 `reports/` 新增回滚记录。

建议由用户明确授权后再执行回滚，因为会覆盖生产运行目录。

## 7. `~/.codex/AGENTS.md` 与 adk 的关系

`~/codex` 是 Codex Home 的声明式资产仓库，`~/.codex/AGENTS.md` 是运行时总策略层，adk 是 Agent/Skill/Profile 资产供应层。三者不要互相替代。

推荐职责边界：

| 层级 | 放什么 | 不放什么 |
|---|---|---|
| `llm_agent/agent-dev-kit` | adk 源资产、测试、profile、runbook、导出物 | 生产运行时的临时状态 |
| `~/codex/src/codex-home` + `~/codex/manifests` | 经治理的 Codex Home 源资产与声明式关系 | 未登记来源、未审查第三方资产 |
| `~/.codex/AGENTS.md` | 全局行为规则、命令硬约束、沟通风格、流程升级/降级、技能路由总原则 | 大量具体 Agent/Skill 正文、参考仓细节、一次性试跑报告 |
| `~/.codex/agents/` | `~/codex` apply 后的运行 Agent | 手工复制的第三方 Agent |
| `~/.codex/skills/` | `~/codex` apply 后的运行 Skill + 系统保留 skill | 未审查第三方技能 |
| `llm_agent/reports` | 安装、pilot、回归、上游吸收证据 | 密钥或私人业务数据 |

`~/.codex/AGENTS.md` 建议保留这些与 adk 配合的规则：

```md
## agent-dev-kit 配合规则

- `agent-dev-kit` 是嵌入式系统开发 Agent/Skill/Profile 的生产资产来源。
- 不手工把参考仓资产或 adk 导出物直接复制进 `~/.codex/agents` 或 `~/.codex/skills`。
- adk 资产更新必须先在 `llm_agent/agent-dev-kit` 通过回归，再交给 `~/codex` 注册、build、doctor 和 apply。
- 任务开始前如需判定技能、fallback 或跳过条件，优先使用 `adk-runtime-router`。
- 测试策略、代码审查、并行 agent、worktree 和分支收尾分别优先使用 `adk-test-strategy`、`adk-code-review-loop`、`adk-parallel-agent-governance`、`adk-worktree-governance`、`adk-branch-closeout`。
- 外部参考仓只作 intake/provenance，不进入 ADK runtime fallback；运行 footprint 以 `manifests/runtime_targets.json` 的 required/forbidden 声明为准。
- 长任务优先使用 `adk-planning-execution-loop`。
- 多技能冲突时以 `adk-runtime-router` 先做 primary/supporting/fallback 裁决；需要组合治理时再叠加 `adk-skill-composition-governance`。
- 第三方技能、脚本或参考资产进入全局环境前必须使用 `adk-security-supply-chain`。
- 完成前必须使用 `adk-verification-before-completion` 核对证据。
- 涉及 `~/.codex` 生产可用性结论时，必须同时附 `~/codex` build/apply 证据、`check-runtime-health.sh . --profile minimal` 和 `check-runtime-live-footprint.sh . --summary-json` 证据。
```

当前不建议让 adk 覆盖 `~/.codex/AGENTS.md`，也不建议绕过 `~/codex` 直接写入 `~/.codex`。原因：

- `AGENTS.md` 包含个人环境硬约束，如 `rtk` 命令前缀、沟通偏好、文档目录、并行策略。
- `~/codex` 负责 Codex Home 源资产、manifest、build、apply 和 drift 管理。
- adk 的职责是提供经过门禁压实的上游资产，不是替换个人全局策略或运行目录管理器。
- 若要把 adk 的策略沉淀进 `~/.codex/AGENTS.md`，应先进入 `~/codex` 源资产，再采用“追加小节 + 人工审阅 + 健康检查”的方式。

## 8. 常见问题

### 8.1 是否可以跳过 pilot？

开发中可以临时不加 `--require-pilot`，但不能据此声明生产可用。生产结论必须使用：

```bash
rtk scripts/check-adk-harden-readiness.sh . --require-pilot
```

### 8.1.1 如何生成提交或发布证据包？

使用统一 evidence bundle：

```bash
rtk scripts/evidence-bundle.sh . --out reports/evidence-bundle.md
rtk scripts/evidence-bundle.sh . --format json
```

证据包会汇总 `adk.lock`、runtime target registry、phase gate、subrepo state、reference dirty triage、runtime pilot、runtime health、runtime live required/forbidden footprint 和 pilot readiness。它不替代完整回归，但适合提交说明、PR 描述和发布记录附证。

runtime live 实装态单独使用：

```bash
rtk scripts/check-runtime-targets.sh .
rtk scripts/check-runtime-live-footprint.sh . --summary-json
rtk scripts/check-runtime-live-footprint.sh . --strict
```

长会话或上下文压力较高时，先运行：

```bash
rtk bash ~/codex/scripts/runtime-control.sh snapshot
rtk bash ~/codex/scripts/runtime-control.sh watch
```

### 8.2 是否可以直接更新参考子仓？

可以同步，但必须先确认 phase gate。默认策略是先压实 adk，再追踪更新。

### 8.3 为什么 observe 已清零还要跑 observe 检查？

因为脚本会确认 backlog cleared，防止后续新增 observe 后没有三层证据。

### 8.4 adk 能否替代所有参考仓？

当前 adk 是生产分发层和压实层，不是参考仓全文镜像。参考仓继续作为上游灵感和候选池；只有经过采纳矩阵、adk 实现、门禁和 pilot 的能力才进入生产。

## 9. 维护记录模板

```md
### YYYY-MM-DD（主题）
- 变更范围：
- 触发原因：
- 更新条目：
- 验证命令：
- 验证结果：
- 后续事项：
```
