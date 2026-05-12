# 双仓库全面审计报告
## 审计日期: 2026-05-12
## 审计范围: llm_agent + agent-dev-kit

---

## 总览

| 仓库 | P0 | P1 | P2 | 合计 |
|------|----|----|----|----|
| llm_agent (文档-代码一致性) | 2 | 5 | 6 | 13 |
| agent-dev-kit (内部一致性) | 6 | 8 | 7 | 21 |
| 跨仓库冗余 | - | - | - | 8项 |
| **总计** | **8** | **13** | **13** | **42** |

---

## 一、llm_agent 文档-代码一致性 (13 项)

### P0 - 阻塞级 (2 项)

| ID | 问题 | 位置 | 影响 |
|----|------|------|------|
| P0-01 | phase-gate 默认值文档与实际不一致 | AGENTS.md L117 vs subrepos/phase-gate.env L6 | 文档说默认 no，实际是 yes，可能导致违规同步 |
| P0-02 | registry.csv 列数文档过时 (11列 vs 实际12列) | scripts/README.md L10, L387 | 新脚本按11列校验会截断 grade 列 |

### P1 - 重要 (5 项)

| ID | 问题 | 位置 |
|----|------|------|
| P1-01 | 根目录缺少 README.md | /home/aiot03/aiot/llm_agent/ |
| P1-02 | CHANGELOG.md 缺少显式版本号 | CHANGELOG.md |
| P1-03 | maintenance-guide 使用未说明的 rtk 命令 | docs/llm-agent-maintenance-guide.md |
| P1-04 | 意图路由表 skill 名称错误 (project-release-hardening → 实际是 adk-release-versioning) | AGENTS.md L34 |
| P1-05 | runbook 可发现性差 (docs/README.md 未列出子目录内容) | docs/README.md |

### P2 - 改进 (6 项)

| ID | 问题 | 位置 |
|----|------|------|
| P2-01 | 孤儿文件 vibeflow-article.md | 根目录 |
| P2-02 | subrepos/ 下 4 个归档文件未被引用 | subrepos/ |
| P2-03 | reports/README.md 未被引用 | reports/README.md |
| P2-04 | disabled 子仓处理不一致 (codex 已删目录, codex_doc_cn 保留空目录) | registry.csv |
| P2-05 | AGENTS.md 第6节遗漏 12+ 个 check-* 脚本 | AGENTS.md L175-194 |
| P2-06 | 版本号归属混用 (adk 版本 vs llm_agent 版本) | AGENTS.md L242 |

---

## 二、agent-dev-kit 内部一致性 (21 项)

### P0 - 必须立即修复 (6 项)

| ID | 问题 | 位置 | 影响 |
|----|------|------|------|
| P0-1 | manifest.yaml 仅定义 2/10 个 Profile (SSOT 失效) | manifest.yaml L307-377 | install --profile 找不到 8 个 profile |
| P0-2 | 全部 33 个 skill 条目有重复 quality_tier 键 | manifest.yaml L127-304 | YAML 解析行为不确定 |
| P0-3 | 2 个关键脚本不存在但被 40+ 处文档引用 | check-global-codex-health.sh, check-adk-harden-readiness.sh | 用户按文档操作直接失败 |
| P0-4 | NAVIGATION.md 3 个断裂 Runbook 链接 | docs/NAVIGATION.md L37,38,51 | 导航 404 |
| P0-5 | 版本锁定引用过时 (0.3.0/2.7.0 vs 当前 2.8.0) | 7 个文件 | 安装命令失败 |
| P0-6 | runbooks/README.md 引用 3 个不存在的文件名 | docs/runbooks/README.md L11,26,30 | 索引错误 |

### P1 - 近期修复 (8 项)

| ID | 问题 | 位置 |
|----|------|------|
| P1-1 | README.md Core Skills 数量过时 (28 vs 实际 33) | README.md L33 |
| P1-2 | CHANGELOG.md 缺少 v2.7.0 和 v2.8.0 条目 | CHANGELOG.md |
| P1-3 | AGENTS.md 统计数据过时 (Scripts 24→26, Profiles 10→2) | AGENTS.md L176-183 |
| P1-4 | NAVIGATION.md Runbook 数量过时 (26 vs 实际 28) | docs/NAVIGATION.md L3 |
| P1-5 | tool-cheatsheet.md 3 个断裂链接 | docs/reference/tool-cheatsheet.md |
| P1-6 | adk-data-fetch 子技能未注册到 manifest | optional-skills/adk-data-fetch/ |
| P1-7 | 5 个脚本未在 commands.md 中文档化 | scripts/ |
| P1-8 | 2026-05-08 审计报告中 24 个断裂脚本引用仍未修复 | docs/doc-code-consistency-audit-2026-05-08.md |

### P2 - 后续优化 (7 项)

| ID | 问题 | 位置 |
|----|------|------|
| P2-1 | gdk 残留引用均在归档/lint 上下文中 (OK) | .out-of-scope/ |
| P2-2 | 2 个 Skill 审计报告内容重叠 | docs/skill-audit-*.md |
| P2-3 | 12+ 个孤立文档未被 NAVIGATION.md 引用 | docs/ |
| P2-4 | 历史报告已归档 (OK) | reports/archive/ |
| P2-5 | 16 个模板文件未被任何文档引用 | templates/ |
| P2-6 | best-practices.md 与 best-practices-cookbook.md 有交叉 | docs/ |
| P2-7 | README.md 内容重复 (L252-313 vs L315-370) | README.md |

---

## 三、跨仓库冗余检测 (8 项)

### 3.1 同名脚本 (4 个，设计意图明确)

| 脚本 | 父仓库行数 | 子仓库行数 | 关系 |
|------|-----------|-----------|------|
| devkit.sh | 188 行 | 122 行 | 工作区级 vs 仓库级，命令子集不重叠 |
| version-manager.sh | 387 行 | 79 行 | 完整版 vs 精简版，子版有语法错误 |
| backup-rollback.sh | 317 行 | 163 行 | 完整版 vs 精简版，子版有语法错误 |
| health-check.sh | 419 行 | 267 行 | 完整版 vs 精简版，子版有重复变量定义 |

**结论**: 设计意图明确（完整版/精简版），保留两者。但子仓库 3 个脚本有语法错误需修复。

### 3.2 完全重复文档 (1 个)

| 文件 | 状态 | 建议 |
|------|------|------|
| docs/setup-gitlab-runner.md (父) = docs/runbooks/gitlab-runner-setup.md (子) | 内容完全相同 (213行) | 删除父版本，保留子版本为权威来源 |

### 3.3 内容重叠文档 (2 个)

| 文件 | 状态 | 建议 |
|------|------|------|
| docs/runbooks/production-deployment.md | 父版 412 行 vs 子版 29 行 | 父版精简为指向子版的引用 |
| AGENTS.md | 父版 246 行 vs 子版 216 行 | 父版简化 adk 相关内容 |

### 3.4 应清理文件 (8 个 .backup 文件)

```
agent-dev-kit/docs/troubleshooting.md.backup
agent-dev-kit/docs/CONTRIBUTING.md.backup
agent-dev-kit/docs/usage.md.backup
agent-dev-kit/docs/codex-agents-integration.md.backup
agent-dev-kit/docs/commands.md.backup
agent-dev-kit/docs/best-practices.md.backup
agent-dev-kit/README.md.backup
agent-dev-kit/manifest.yaml.backup
```

**建议**: 全部删除，历史版本应使用 Git 历史。

### 3.5 空目录/占位文件

| 路径 | 状态 | 建议 |
|------|------|------|
| agent-dev-kit/docs/changes/archive/.gitkeep | 仅占位 | 保留 |
| agent-dev-kit/docs/explorations/ | 仅 README | 保留 |
| agent-dev-kit/docs/specs/ | 仅 README | 保留 |
| codex_doc_cn/ | 空子仓 (.gitkeep + .git) | 确认是否移除 |

### 3.6 循环引用

**无循环引用**。依赖方向健康：llm_agent → agent-dev-kit (单向)。

---

## 四、修复优先级建议

### 立即处理 (P0)

1. **修复 manifest.yaml**: 补充 8 个缺失 Profile，修复重复 quality_tier 键
2. **处理缺失脚本**: 创建 check-global-codex-health.sh 和 check-adk-harden-readiness.sh，或更新文档引用
3. **修复断裂链接**: NAVIGATION.md 3 个 runbook 链接，runbooks/README.md 3 个文件名
4. **更新版本锁定引用**: 7 个文件中的 --lock-version 参数
5. **更新文档**: phase-gate 默认值说明、registry.csv 列数说明

### 近期处理 (P1)

1. 更新所有过时统计数字
2. 补充 CHANGELOG.md 缺失版本条目
3. 注册 adk-data-fetch 子技能到 manifest
4. 文档化 5 个未记录的脚本
5. 修复 2026-05-08 审计遗留的断裂引用

### 后续优化 (P2)

1. 删除 8 个 .backup 文件
2. 删除重复的 gitlab-runner 文档
3. 归档旧版审计报告
4. 补充 NAVIGATION.md 孤立文档引用
5. 修复子仓库 3 个脚本语法错误

---

## 五、审计统计

- 已检查引用路径: 19 个 (AGENTS.md) + 27 条 (registry.csv) + 60+ 个 (docs/)
- 子仓目录完整性: 27/27 全部存在
- 脚本路径完整性: AGENTS.md 引用的 19 个脚本全部存在
- 冗余程度: 中等（设计意图明确，非意外重复）

---

*审计完成时间: 2026-05-12 20:04*
*审计工具: codebase-audit skill + 3 parallel subagents*
