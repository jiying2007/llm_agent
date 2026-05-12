# llm_agent + agent-dev-kit 生产就绪度审计报告

> 审计时间: 2026-05-09
> 审计方式: 真实执行 + 逐层验证（12 层深度检查）
> 审计范围: llm_agent 工作区 + agent-dev-kit (adk) 核心仓库

---

## 结论总览

| 维度 | 评级 | 说明 |
|------|------|------|
| 架构设计 | ✅ 良好 | 目录分离清晰，职责边界明确 |
| 资产质量 | ⚠️ 部分问题 | Skills 质量高，但 manifest 声明与实际不一致 |
| 脚本工程 | ⚠️ 部分问题 | 语法全通过，但 devkit.sh 有阻断级 bug |
| 功能完整性 | ❌ 不达标 | 核心入口 devkit.sh 无法运行 |
| 意图路由 | ✅ 良好 | routing 表覆盖完整 |
| 文档准确性 | ⚠️ 部分问题 | 版本号不一致，缺少 CONTEXT.md |
| 测试覆盖 | ⚠️ 部分问题 | 测试存在但运行失败 |
| 实际可用性 | ❌ 不达标 | 核心功能无法使用 |

**综合评分: 6.2/10 — 未达到生产发布状态**

---

## 阻断级问题（必须修复）

### 阻断-1: devkit.sh SCRIPT_DIR 未定义

- **现象**: `bash scripts/devkit.sh validate --strict` 报错 `SCRIPT_DIR: unbound variable`
- **根因**: devkit.sh 使用 `$SCRIPT_DIR` 变量但从未定义
- **影响**: 所有子命令（install/validate/convert/catalog/match 等）全部不可用
- **修复**: 在脚本开头添加 `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`

### 阻断-2: manifest.yaml 声明 20 个不存在的 skills

- **现象**: manifest.yaml 声明 53 个 skills，实际只有 33 个存在
- **缺失列表**:
  - requirements-analyst, architecture-planner, driver-engineer, component-engineer
  - application-engineer, build-release-engineer, test-validation-engineer
  - performance-reliability-engineer, security-compliance-reviewer, code-review-governor
  - adk-artifact-gated-lite, adk-cross-team-handoff, adk-data-fetch
  - adk-email-imap-fetch, adk-fetch-url-content, adk-incident-rca-report
  - adk-planning-execution-loop, adk-security-supply-chain
  - adk-skill-composition-governance, adk-test-flakiness-triage
- **影响**: validate 命令会失败，install 会跳过缺失的 skills
- **修复**: 删除 manifest.yaml 中不存在的 skills 声明，或创建缺失的 skills

### 阻断-3: 缺少 CONTEXT.md 文件

- **现象**: health-check.sh 和 quality-gate-check.sh 都报告缺失 CONTEXT.md
- **影响**: 健康检查和质量门禁检查失败
- **修复**: 创建 CONTEXT.md 文件，定义领域语言和核心概念

---

## 高优问题（强烈建议修复）

### 高优-1: 版本号严重不一致

- **现象**: manifest.yaml 显示 version: 2.7.0，但文档中引用了 0.3.0、1.0.0、1.1.0、2.0.0 等多个版本
- **影响**: 用户困惑，无法确定当前真实版本
- **修复**: 统一版本号，建议以 manifest.yaml 为准

### 高优-2: 脚本命名风格不一致

- **现象**: scripts/ 目录混用 kebab-case 和 snake_case
  - kebab-case: auto-ops.sh, backup-rollback.sh, health-check.sh
  - snake_case: catalog_assets.sh, check_change_governance.sh, convert_assets.sh
- **影响**: 代码风格不统一，维护成本增加
- **修复**: 统一为 kebab-case（与 skills 目录一致）

### 高优-3: log_* 函数重复定义

- **现象**: log_info/log_warning/log_success/log_error 在 8 个脚本中重复定义
- **影响**: 维护成本高，修改需要同步多个文件
- **修复**: 提取为公共库 lib_logging.sh

### 高优-4: 测试套件运行失败

- **现象**: `bash tests/run_all.sh` 报告 FAIL: missing heading '## Prerequisites' in adk-artifact-gating/SKILL.md
- **影响**: 无法验证代码质量
- **修复**: 修复 adk-artifact-gating/SKILL.md 添加 Prerequisites 章节

---

## 中等问题

### 中等-1: 隐式外部依赖未声明

- **现象**: rg (ripgrep) 在 6 个脚本中使用但未检查安装
- **涉及脚本**: check_change_governance.sh, check_format.sh, evidence_index.sh, openspec_bridge.sh, workflow.sh, health-check.sh
- **修复**: 在 health-check.sh 中添加 ripgrep 依赖检查

### 中等-2: 破坏性操作未完全保护

- **现象**: 11 处 rm -rf，1 处 sed -i 修改 manifest.yaml
- **修复**: 添加 --force 门控，sed -i 前创建备份

### 中等-3: Skills 触发词质量参差不齐

- **现象**: 3 个 skills 的 triggers 偏描述性（adk-requirements-triage, adk-protocol-stack-integration, adk-context-engineering）
- **修复**: 改为可匹配的关键词短语

---

## 正常工作的部分

1. **Skills 质量高**: 33 个 core skills 中 77% 拥有完整 5 段标准结构，平均 126 行，无空壳文件
2. **Scripts 语法全通过**: 24/24 脚本通过 bash -n 语法检查
3. **错误处理规范**: 24/24 脚本使用 set -euo pipefail
4. **无交互式 read**: 所有 read 都是管道读取，适合 CI 环境
5. **目录结构清晰**: agents/skills/scripts/tests/docs 分离明确
6. **已实际部署**: 22 个 adk skills 已安装到 ~/.codex
7. **llm_agent 工作区健康**: 30 个脚本，26 个子仓治理完整

---

## 综合评分

| 维度 | 满分 | 得分 | 说明 |
|------|------|------|------|
| 架构设计 | 10 | 8 | 目录分离清晰，依赖方向明确 |
| 资产质量 | 10 | 7 | Skills 质量高，但 manifest 不一致 |
| 脚本工程 | 10 | 6 | 语法全通过，但有阻断级 bug |
| 功能完整性 | 10 | 3 | 核心入口无法使用 |
| 意图路由 | 10 | 8 | routing 表覆盖完整 |
| 文档准确性 | 10 | 5 | 版本号不一致，缺少 CONTEXT.md |
| 测试覆盖 | 10 | 6 | 测试存在但运行失败 |
| 实际可用性 | 10 | 3 | 核心功能无法使用 |
| **总计** | **80** | **46** | **57.5% — 未达标** |

---

## 修复路线图

### 阶段 A: 阻断修复（预计 2 小时）

1. **修复 devkit.sh**
   - 添加 SCRIPT_DIR 和 ROOT_DIR 定义
   - 验证所有子命令可执行

2. **清理 manifest.yaml**
   - 删除 20 个不存在的 skills 声明
   - 或创建缺失的 skills（工作量大，不推荐）

3. **创建 CONTEXT.md**
   - 定义领域语言和核心概念
   - 满足 health-check.sh 和 quality-gate-check.sh 的要求

### 阶段 B: 高优修复（预计 4 小时）

1. **统一版本号**
   - 以 manifest.yaml 的 2.7.0 为准
   - 更新所有文档中的版本引用

2. **统一脚本命名**
   - 将 snake_case 脚本重命名为 kebab-case
   - 更新所有引用

3. **提取公共库**
   - 创建 lib_logging.sh
   - 修改所有脚本 source 公共库

4. **修复测试套件**
   - 修复 adk-artifact-gating/SKILL.md
   - 确保所有测试通过

### 阶段 C: 生产验证（预计 2 小时）

1. **运行完整测试套件**
   - `bash tests/run_all.sh` 必须 100% 通过

2. **运行健康检查**
   - `bash scripts/health-check.sh check-all` 必须通过

3. **运行质量门禁**
   - `bash scripts/quality-gate-check.sh check-all` 必须通过

4. **实际安装验证**
   - `bash scripts/devkit.sh install --tool codex --profile core --target /tmp/test-install`
   - 验证产物完整性

---

## 审计证据

- Scripts 层审计报告: `/home/aiot03/aiot/llm_agent/agent-dev-kit/scripts/SCRIPTS_AUDIT_REPORT.md`
- Skills 层审计报告: `/home/aiot03/aiot/llm_agent/agent-dev-kit/docs/skills-audit-report.md`
- 本报告: `/home/aiot03/aiot/llm_agent/reports/production-readiness-audit-2026-05-09.md`

---

## 结论

**llm_agent + agent-dev-kit 当前未达到生产发布状态。**

主要阻断:
1. 核心入口 devkit.sh 无法运行（SCRIPT_DIR 未定义）
2. manifest.yaml 声明 20 个不存在的 skills
3. 缺少必需的 CONTEXT.md 文件

建议: 先完成阶段 A 阻断修复，再进行阶段 B 高优修复，最后执行阶段 C 生产验证。预计总修复时间 8 小时。
