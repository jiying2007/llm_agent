# llm_agent 工作区全量深度审计报告

> 审计时间: 2026-05-05
> 审计范围: 全部 25 个子仓 + scripts/ + docs/ + reports/ + subrepos/ + templates/ + AGENTS.md + README.md
> 结论: **治理框架优秀，但存在大量冗余和 1 个孤儿子仓，需要瘦身和补齐**

---

## 一、全局统计

| 维度 | 数量 |
|------|------|
| 子仓总数 | 25（on-disk）+ 1 disabled（codex） |
| llm_agent 级脚本 | 21 |
| llm_agent 级文档 | 10 |
| llm_agent 级报告 | 27 |
| llm_agent 级模板 | 11 |
| 根目录文件 | 4（AGENTS.md, README.md, .codex, .gitignore） |

---

## 二、子仓健康度

全部 25 个子仓均有 git 历史和 AGENTS.md。

| 子仓 | 文件数 | 最近提交 | registry 状态 |
|------|--------|---------|--------------|
| agency-agents-zh | 274 | star badge | active |
| agent-skills | 72 | merge PR | active |
| ai-coding-guide | 75 | star badge | active |
| arthas | 1661 | mcp task | active |
| artifact-gated-agents | 28 | hero section | active |
| AUBB-Server | 613 | dev->main | active |
| autonomous-vehicle-dev | 96800 | ACC仿真 | active |
| auto-research | 370 | init | active |
| codex-cookbook | 20 | skill orchestration | active |
| codex_doc_cn | 366 | header actions | disabled |
| codex-skill-spec | 15 | readme | active |
| dotfiles | 858 | chrome-devtools | active |
| **global-dev-kit** | **178** | **v2.0.0 最终版** | **active** |
| hermes-agent | 2556 | revert onboarding | active |
| hermes-collaboration-skill | 27 | CI workflow | active |
| hermes-team-skill | 6 | MIT License | active |
| mattpocock-skills | 58 | what-to-do | active |
| Migrationed_skills | 2112 | strip backup | active |
| OpenSpec | 658 | version packages | active |
| prompts | 33 | gitlab CLI | active |
| skills | 287 | merge PR | active |
| superpowers | 146 | codex plugin | active |
| superpowers-zh | 145 | star badge | active |
| **Trellis** | **1202** | merge PR | **未注册** |
| vscode-codex-settings | 4 | auth.json | active |

**问题**: Trellis（1202 文件）在磁盘上存在但未在 registry.csv 和 AGENTS.md 中注册，属于孤儿子仓。

---

## 三、核心发现

### 发现 1: 大量冗余（严重度: 高）

llm_agent 的 docs/ 和 templates/ 与 global-dev-kit 高度重复：

| llm_agent 文件 | gdk 对应文件 | 状态 |
|---------------|-------------|------|
| docs/quick-start.md | gdk/docs/quick-start.md | 完全重复 |
| docs/best-practices.md | gdk/docs/best-practices.md | 完全重复 |
| docs/troubleshooting.md | gdk/docs/troubleshooting.md | 完全重复 |
| docs/CONTRIBUTING.md | gdk/docs/CONTRIBUTING.md | 完全重复 |
| docs/skill-composition-guide.md | gdk/docs/skill-composition-guide.md | 完全重复 |
| docs/explorations/README.md | gdk/docs/explorations/README.md | 完全重复 |
| docs/specs/README.md | gdk/docs/specs/README.md | 完全重复 |
| docs/changes/README.md | gdk/docs/changes/README.md | 完全重复 |
| docs/runbooks/production-deployment.md | gdk/docs/runbooks/production-deployment.md | 完全重复 |
| templates/ (11 files) | gdk/templates/ (18 files) | 完全重复（子集） |

**8/10 文档 + 11/11 模板 = 19 个文件完全冗余。**

唯一有价值的 llm_agent 级文档: `docs/llm-agent-maintenance-guide.md`

### 发现 2: 文档引用不存在的脚本（严重度: 高）

多个 llm_agent 文档引用的脚本在 llm_agent/scripts/ 中不存在：

| 引用的脚本 | 在 llm_agent 中 | 实际位置 |
|-----------|----------------|---------|
| scripts/workflow.sh | 不存在 | global-dev-kit/scripts/ |
| scripts/validate_assets.sh | 不存在 | global-dev-kit/scripts/ |
| scripts/check_format.sh | 不存在 | global-dev-kit/scripts/ |
| scripts/quality-gate-check.sh | 不存在 | global-dev-kit/scripts/ |
| scripts/install_assets.sh | 不存在 | global-dev-kit/scripts/ |

这让新用户按文档操作会直接报错。

### 发现 3: 脚本健壮性不足（严重度: 中）

| 问题 | 影响范围 |
|------|---------|
| 缺少 set -e | 3/21 脚本（check-agents-coverage, diff-scan, sync-subrepos） |
| 缺少 usage 函数 | 17/21 脚本无 --help |
| 缺少 set -euo pipefail | check-agents-coverage.sh 只有 set -u |

### 发现 4: 报告堆积（严重度: 低）

27 个报告中：
- 高价值: 4 个（pilot-report, install-report, production-landing, p0-closeout）
- 中价值: 5 个（freeze-signoff, kickoff, analysis, sync, matrix-summary）
- 低价值/可归档: 18 个（wave1-wave8, intake-packages, p1-rollouts）

### 发现 5: 缺失基础设施（严重度: 中）

| 项目 | 状态 |
|------|------|
| 根 README.md | ✅ 存在，质量好 |
| 根 CONTRIBUTING.md | ❌ 缺失（只在 docs/ 中有重复副本） |
| 根 CHANGELOG.md | ❌ 缺失 |
| 根 LICENSE | ❌ 缺失 |
| CI/CD | ❌ 缺失 |
| Makefile | ❌ 缺失 |

### 发现 6: AGENTS.md 14 天计划过时（严重度: 低）

计划描述 D1-D14 分散执行，实际 2 天内压缩完成（2026-05-01/02 两日 10+ 轮迭代）。计划结构仍可作为模板，但时间线描述不准确。

---

## 四、架构评估

| 维度 | 评分 | 说明 |
|------|------|------|
| 治理框架 | 9/10 | registry + adoption-matrix + phase-gate 设计优秀 |
| 子仓覆盖 | 8/10 | Trellis 未注册，其余全覆盖 |
| 脚本工程 | 6/10 | 3/21 缺 set -e，17/21 无 usage |
| 文档架构 | 3/10 | 90% 内容与 gdk 重复，引用不存在的脚本 |
| 报告管理 | 5/10 | 高价值报告少，低价值报告堆积 |
| 模板管理 | 2/10 | 100% 与 gdk 重复，且是子集 |
| 可维护性 | 7/10 | AGENTS.md + maintenance-guide 质量高 |
| 可扩展性 | 8/10 | registry.csv 设计可扩展 |
| 基础设施 | 4/10 | 无 CI/CD、无 Makefile、无 LICENSE |
| **综合** | **58/100** | |

---

## 五、优化路线图

### 阶段 A: 瘦身去冗余（P0）

1. 删除 llm_agent/docs/ 中 8 个与 gdk 重复的文件
2. 删除 llm_agent/templates/ 全部 11 个文件（gdk 是超集）
3. 归档 18 个低价值报告到 reports/archive/

### 阶段 B: 治理补齐（P0）

4. 将 Trellis 加入 registry.csv 和 AGENTS.md
5. 修复 3 个脚本缺少 set -e 的问题
6. 在 llm_agent/docs/ 添加 README.md 说明文档职责

### 阶段 C: 基础设施（P1）

7. 添加根 CONTRIBUTING.md（从 gdk 复制并标注）
8. 添加根 CHANGELOG.md
9. 添加根 LICENSE（MIT）

### 阶段 D: AGENTS.md 更新（P1）

10. 更新 14 天计划为实际执行模式
11. 更新 gdk 基线定位为 v2.0.0 状态
