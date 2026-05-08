# llm_agent 持续维护与生产验证指南

## 1. 定位

`llm_agent` 是 adk 的上游治理工作区，负责三件事：

1. 管理参考子仓清单与同步策略。
2. 从参考子仓提炼可采纳实践，并记录采纳/观察/拒绝原因。
3. 推动 `agent-dev-kit` 落地、验证、部署到 `~/.codex`，再把真实运行结果回灌。

不推荐在 `llm_agent` 中直接改 `~/.codex` 运行资产。生产运行资产应由 `agent-dev-kit/scripts/devkit.sh install` 生成，并由报告记录版本、profile、optional skill、备份路径和健康检查结果。

## 2. 目录职责

| 路径 | 职责 | 维护要求 |
|---|---|---|
| `AGENTS.md` | 工作区全局规则、参考子仓总览、维护记录 | 规则或流程变化时同步更新 |
| `subrepos/registry.csv` | 参考子仓单一清单 | 新增/禁用子仓必须更新 |
| `subrepos/adoption-matrix.md` | 候选采纳矩阵 | 每个候选必须有决策、状态、目标层和证据 |
| `subrepos/phase-gate.env` | 是否允许追踪上游更新 | 默认先压实 adk，再开门同步 |
| `scripts/` | 治理、同步、门禁脚本 | 新脚本必须写入 `scripts/README.md` |
| `reports/` | pilot、安装、周报、wave 记录 | 生产结论必须有报告证据 |
| `agent-dev-kit/` | adk 源资产与测试 | 所有生产能力最终在这里压实 |

## 3. 维护流程

### 3.1 日常健康检查

```bash
rtk scripts/check-doc-sync.sh .
rtk scripts/check-runtime-routing.sh .
rtk scripts/check-upstream-intake-readiness.sh .
rtk scripts/check-global-codex-health.sh ~/.codex minimal
```

适用场景：只确认当前状态是否健康，不同步参考仓，不部署。

### 3.2 adk 压实检查

```bash
rtk scripts/check-adk-harden-readiness.sh .
```

适用场景：修改了 adk 文档、profile、skill、agent、workflow 或 root scripts 后，需要确认基础门禁。

### 3.3 生产级放行检查

```bash
rtk scripts/check-adk-harden-readiness.sh . --require-pilot
```

适用场景：准备声明 adk 可用于 `~/.codex` 生产运行，或准备重新部署到 `~/.codex`。

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
- codex pilot evidence
- codex pilot coverage
- global `~/.codex` health

### 3.4 参考子仓同步

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

1. 在 `subrepos/adoption-matrix.md` 增加候选行。
2. 给出 `adopt/observe/reject`。
3. 对 `adopt + done`，必须有本地证据路径。
4. 对 delivery 类 adopt，必须覆盖 Agent/Skill/Workflow 至少一层。
5. 对安全、脚本、第三方资产，先走 `security-supply-chain`。
6. 最终执行：

```bash
rtk scripts/check-adoption-matrix-status.sh .
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
| root 门禁脚本 | `rtk scripts/check-adk-harden-readiness.sh . --require-pilot` | 影响生产放行链路 |
| `~/.codex` 部署 | `rtk scripts/check-adk-harden-readiness.sh . --require-pilot` + install report | 必须保留 backup |

## 5. 生产部署流程

生产部署只从 `agent-dev-kit` 执行，不手工复制单个 Agent/Skill。

```bash
rtk bash -lc "cd agent-dev-kit && bash scripts/devkit.sh validate --strict"
rtk bash -lc "cd agent-dev-kit && bash scripts/devkit.sh install --tool codex --target ~/.codex --mode copy --profile personal-core --extra-profile release-hardening --with-optional-skill planning-execution-loop --with-optional-skill skill-composition-governance --with-optional-skill security-supply-chain --with-optional-skill cross-team-handoff --with-optional-skill artifact-gated-lite --backup --install-report ../reports/adk-install-report-$(date +%F).md --lock-version 0.3.0"
rtk scripts/check-global-codex-health.sh ~/.codex minimal
rtk scripts/check-adk-harden-readiness.sh . --require-pilot
```

生产安装纪律：

- 使用 `copy`，避免 adk 工作区未提交改动影响 `~/.codex`。
- 使用 `--backup`，生成回滚点。
- 使用 `--install-report`，记录 profile、optional skill、数量与 backup。
- 使用 `--lock-version`，防止误装不匹配版本。
- 安装后必须跑 `check-global-codex-health.sh`。

## 6. 回滚流程

先从安装报告确认备份路径，例如：

```text
/home/aiot03/.codex/.adk-backups/20260502T104514Z
```

回滚原则：

1. 不直接删除 `~/.codex`。
2. 先确认备份中存在 `agents/` 与 `skills/`。
3. 回滚后执行健康检查。
4. 在 `reports/` 新增回滚记录。

建议由用户明确授权后再执行回滚，因为会覆盖生产运行目录。

## 7. `~/.codex/AGENTS.md` 与 adk 的关系

`~/.codex/AGENTS.md` 是运行时总策略层，adk 是 Agent/Skill/Profile 资产供应层。二者不要互相替代。

推荐职责边界：

| 层级 | 放什么 | 不放什么 |
|---|---|---|
| `~/.codex/AGENTS.md` | 全局行为规则、命令硬约束、沟通风格、流程升级/降级、技能路由总原则 | 大量具体 Agent/Skill 正文、参考仓细节、一次性试跑报告 |
| `~/.codex/agents/` | adk 安装后的角色 Agent | 手工复制的第三方 Agent |
| `~/.codex/skills/` | adk 安装后的稳定技能 + 个人已治理技能 | 未审查第三方技能 |
| `llm_agent/agent-dev-kit` | 源资产、测试、profile、runbook | 生产运行时的临时状态 |
| `llm_agent/reports` | 安装、pilot、回归、上游吸收证据 | 密钥或私人业务数据 |

`~/.codex/AGENTS.md` 建议保留这些与 adk 配合的规则：

```md
## agent-dev-kit 配合规则

- `agent-dev-kit` 是嵌入式系统开发 Agent/Skill/Profile 的生产资产来源。
- 不手工把参考仓资产直接复制进 `~/.codex/agents` 或 `~/.codex/skills`。
- adk 资产更新必须先在 `llm_agent/agent-dev-kit` 通过回归，再用 `scripts/devkit.sh install` 安装。
- 长任务优先使用 `planning-execution-loop`。
- 多技能冲突时以 `skill-composition-governance` 判定 primary/supporting/fallback。
- 第三方技能、脚本或参考资产进入全局环境前必须使用 `security-supply-chain`。
- 完成前必须使用 `verification-before-completion` 核对证据。
- 涉及 `~/.codex` 生产可用性结论时，必须附 `check-global-codex-health.sh ~/.codex minimal` 证据。
```

当前不建议让 adk 覆盖 `~/.codex/AGENTS.md`。原因：

- `AGENTS.md` 包含个人环境硬约束，如 `rtk` 命令前缀、沟通偏好、文档目录、并行策略。
- adk 安装器的职责是分发 `agents/` 与 `skills/`，不是替换个人全局策略。
- 若要把 adk 的策略沉淀进 `~/.codex/AGENTS.md`，应采用“追加小节 + 人工审阅 + 健康检查”的方式。

## 8. 常见问题

### 8.1 是否可以跳过 pilot？

开发中可以临时不加 `--require-pilot`，但不能据此声明生产可用。生产结论必须使用：

```bash
rtk scripts/check-adk-harden-readiness.sh . --require-pilot
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
