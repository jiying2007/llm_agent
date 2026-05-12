# 子仓库质量分级报告

- 生成日期: 2026-05-08
- 评分模型: 活跃度(30) + 内容丰富度(25) + 使命相关性(25) + 可用性(20) + 独特性(+10) - 重叠度(-15)
- 执行脚本: `scripts/check-repo-quality.sh`

## 分级定义

| 等级 | 含义 | 分数区间 | 处理策略 |
|------|------|----------|----------|
| **S** | 核心跟踪 | ≥70 | 每次同步必分析，优先吸收改进 |
| **A** | 长期跟踪 | 55-69 | 定期同步，有重大变更时分析 |
| **B** | 按需参考 | 40-54 | 不主动同步，需要时查阅 |
| **C** | 待考察 | 20-39 | 30 天观察期，无改善则降级或放弃 |
| **D** | 建议放弃 | <20 | 标记 disabled，不再同步 |
| **X** | 特殊 | - | 运行时目标（如 codex），单独管理 |

## 升降级规则

1. **自动降级**: C 级仓库 30 天内无新提交 → 降为 D
2. **自动升级**: B/C 级仓库出现重大功能更新 → 人工评估升级
3. **人工干预**: 任何升降级均可由人工 override
4. **定期审查**: 每月运行 `check-repo-quality.sh` 生成新报告

### ⚠️ Disable 前置规则（强制）

> **任何仓库在 disable 之前，必须先完成全量分析，确认所有可吸收内容已吸纳完毕。**

执行流程：
1. **全量扫描**: 读取仓库全部 SKILL.md / AGENTS.md / scripts / workflows
2. **提取清单**: 列出所有可吸收的 skill / 模式 / 脚本 / 最佳实践
3. **吸纳落地**: 将有价值内容合并到 adk 或记录到 adoption-matrix
4. **吸纳确认**: 在分级报告中记录"已吸纳清单"
5. **执行禁用**: 仅在上述步骤完成后才标记 disabled

禁止操作：
- ❌ 未经分析直接 disable
- ❌ 分析后未吸纳就 disable
- ❌ 吸纳后未记录就 disable

## 当前分级结果

### S 级 — 核心跟踪（4 个）

| 仓库 | 分数 | 最后提交 | 总提交 | 分组 | 独特价值 |
|------|------|----------|--------|------|----------|
| OpenSpec | 85 | 2026-04-21 | 567 | workflow-core | Spec 工件体系，变更追溯 |
| agent-skills | 85 | 2026-04-27 | 149 | agent-ecosystem | 技能驱动开发流程，多平台适配 |
| superpowers | 75 | 2026-04-23 | 438 | workflow-core | 流程主干，插件同步工具链 |
| agency-agents-zh | 75 | 2026-04-19 | 113 | agent-ecosystem | 中文角色资产库 |

### A 级 — 长期跟踪（8 个）

| 仓库 | 分数 | 最后提交 | 总提交 | 分组 | 说明 |
|------|------|----------|--------|------|------|
| mattpocock-skills | 65 | 2026-04-30 | 63 | agent-ecosystem | XML 标签创新，可组合技能 |
| skills | 65 | 2026-04-22 | 128 | agent-ecosystem | skills CLI 生态 |
| superpowers-zh | 65 | 2026-04-19 | 43 | workflow-core | 中文流程增强 |
| arthas | 65 | 2026-04-22 | 2185 | delivery | 成熟开源工程规范 |
| hermes-agent | 55 | 2026-04-26 | 5974 | delivery | 大型 Agent 工程参考 |
| prompts | 55 | 2026-04-20 | 165 | knowledge | 提示词资产 |
| AUBB-Server | 55 | 2026-04-17 | 72 | delivery | 后端业务样本 |
| ai-coding-guide | 55 | 2026-04-19 | 34 | knowledge | 场景化实践指南 |

### B 级 — 按需参考（3 个）

| 仓库 | 分数 | 说明 |
|------|------|------|
| Trellis | 50 | 知识管理参考，低相关但极活跃 |
| dotfiles | 45 | 环境配置管理，按需查阅 |
| hermes-collaboration-skill | 40 | 团队协作，内容尚少 |

### C 级 — 待考察（1 个保留 + 6 个已禁用）

| 仓库 | 分数 | 状态 | 说明 |
|------|------|------|------|
| codex-cookbook | 38 | ✅ 保留 | 军师编排模型有价值，观察 |
| ~~Migrationed_skills~~ | 30 | ⚠️ 观察 | 501 skill 但模板化严重 |
| ~~auto-research~~ | 20 | ❌ 禁用 | GitHub 鉴权失败，仅 1 次提交 |

### ⛔ 已禁用仓库 — 全量分析后禁用（6 个）

> 以下仓库均在完成全量分析、确认可吸收内容已吸纳后才执行禁用。


### D 级 — 建议放弃（2 个，已禁用）

| 仓库 | 分数 | 原因 | 已吸纳清单 |
|------|------|------|-----------|
| codex-skill-spec | 10 | 停滞 116 天，被覆盖 | ① 最小闭环范式(4步) ② WHEN/THEN/SHALL 验收格式 → `references/acceptance-criteria-format.md` ③ 交互式生成模式 ④ SKILL.md 最小结构 ⑤ code-review-pro 审查分层结构 ⑥ config.toml 环境声明模式 |
| codex_doc_cn | 5 | 远程不可达 | ① AGENTS.md 发现链与覆盖机制 ② SKILL.md 渐进加载规范 ③ skill 目录标准结构 ④ 文档翻译规范体系 ⑤ 检查清单模式 ⑥ 分阶段改造规划模板 |

### C 级 — 已禁用（4 个，分析后禁用）

| 仓库 | 分数 | 原因 | 已吸纳清单 |
|------|------|------|-----------|
| artifact-gated-agents | 30 | OpenSpec 已覆盖 | ① BLOCKED/READY/Code 交付模板 → `templates/artifacts/` ② 5 条设计原则 → `references/design-principles.md` ③ [artifact:Tag] 标签规范 ④ Review/Security/Test 统一 verdict 模板 → `templates/artifacts/review-verdict-template.md` ⑤ 编码前置门禁 4 项检查 |
| hermes-team-skill | 25 | 被覆盖 | ① SKILL.md YAML frontmatter 元数据规范 ② AGENTS.md 维护约束模式(repo-intro:start/end) ③ "脚本+模板+手册"三件套交付范式 |
| vscode-codex-settings | 20 | 仅 3 次提交 | ① MCP 注释模式 ② "配置概要+校验命令"模式 ③ 渐进式上下文收集 4 步骤 → `references/context-collection-guide.md` ④ 充分性检查清单(4 项) ⑤ 成本控制机制(深挖≤3次) |
| autonomous-vehicle-dev | 30 | 领域专用 | ① 阶段进度可视化模板 ② 规则清单+禁止项清单模式 ③ C++→C 转换规则模板结构 |


## 本次操作

- **禁用 6 个仓库**（全部经过全量分析 + 吸纳完毕）:
  - codex_doc_cn, codex-skill-spec, hermes-team-skill, vscode-codex-settings, artifact-gated-agents, autonomous-vehicle-dev
- **吸纳落地 6 个文件**:
  - `templates/artifacts/blocked-template.md`
  - `templates/artifacts/code-delivery-template.md`
  - `templates/artifacts/review-verdict-template.md`
  - `references/design-principles.md`
  - `references/context-collection-guide.md`
  - `references/acceptance-criteria-format.md`
- **保留观察 1 个**: codex-cookbook (C 级，有军师编排价值)
- **registry.csv 增加 grade 字段**
- **后续**: 每月运行 `check-repo-quality.sh` 自动审查
