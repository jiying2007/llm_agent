# 快速入门指南

## 概述

本指南帮助你快速上手 global-dev-kit（gdk），了解其核心概念和基本使用方法。

## 前置条件

- Bash 4.0+
- Git
- 基本的命令行操作知识

## 安装

### 1. 克隆仓库

```bash
git clone <repository-url>
cd global-dev-kit
```

### 2. 验证安装

```bash
bash scripts/devkit.sh validate --strict
```

### 3. 运行测试

```bash
bash tests/run_all.sh
```

## 核心概念

### 1. Agent（代理）
具有特定角色和职责的AI代理，负责执行特定类型的开发任务。

**示例**：
- `requirements-analyst`：需求分析
- `driver-engineer`：驱动开发
- `test-validation-engineer`：测试验证

### 2. Skill（技能）
可复用的开发能力单元，包含具体的开发流程和最佳实践。

**示例**：
- `requirements-triage`：需求分类
- `systematic-debugging`：系统化调试
- `verification-before-completion`：完成前验证

### 3. Profile（配置）
针对特定开发场景的技能和Agent组合配置。

**示例**：
- `core`：通用研发核心配置
- `embedded-fullstack`：嵌入式全栈配置
- `release-hardening`：发布前强化配置

### 4. Workflow（工作流）
标准化的开发流程，定义了从需求到交付的完整路径。

**标准流程**：
```
propose -> apply -> verify -> review -> archive
```

## 基本使用

### 1. 创建变更

```bash
bash scripts/workflow.sh propose --change my-change --title "我的变更"
```

### 2. 实施变更

```bash
# 编辑代码和文档
bash scripts/workflow.sh apply --change my-change
```

### 3. 验证变更

```bash
bash scripts/workflow.sh verify --change my-change
```

### 4. 审查变更

```bash
bash scripts/workflow.sh review --change my-change --result pass --blockers 0 --majors 0 --minors 0
```

### 5. 归档变更

```bash
bash scripts/workflow.sh archive --change my-change
```

## 使用模板

### 1. 查看可用模板

```bash
ls templates/artifacts/
ls templates/workflows/
```

### 2. 使用模板创建文档

```bash
cp templates/artifacts/prd-template.md docs/changes/my-change/prd.md
# 编辑模板内容
```

## 质量检查

### 1. 运行质量门禁检查

```bash
bash scripts/quality-gate-check.sh check-all
```

### 2. 运行特定检查

```bash
# 检查产物完整性
bash scripts/quality-gate-check.sh check-artifacts

# 检查一致性
bash scripts/quality-gate-check.sh check-consistency

# 检查验证证据
bash scripts/quality-gate-check.sh check-evidence

# 检查Profile配置
bash scripts/quality-gate-check.sh check-profiles
```

## 目录结构

```
global-dev-kit/
├── agents/                    # Agent定义
├── skills/                    # 技能定义
├── optional-skills/           # 可选技能
├── scripts/                   # 脚本工具
├── tests/                     # 测试套件
├── docs/                      # 文档体系
│   ├── changes/               # 变更追溯
│   ├── specs/                 # 规格说明
│   ├── explorations/          # 探索记录
│   └── runbooks/              # 操作手册
├── templates/                 # 模板文件
│   ├── artifacts/             # 产物模板
│   └── workflows/             # 工作流模板
├── CONTEXT.md                 # 领域语言
├── manifest.yaml              # 配置清单
└── README.md                  # 项目说明
```

## 常见任务

### 1. 开发新功能

```bash
# 1. 创建变更
bash scripts/workflow.sh propose --change feature-xxx --title "新增XXX功能"

# 2. 使用模板
cp templates/artifacts/prd-template.md docs/changes/feature-xxx/prd.md

# 3. 实施变更
# 编辑代码...

# 4. 验证变更
bash scripts/workflow.sh verify --change feature-xxx

# 5. 审查变更
bash scripts/workflow.sh review --change feature-xxx --result pass --blockers 0 --majors 0 --minors 0

# 6. 归档变更
bash scripts/workflow.sh archive --change feature-xxx
```

### 2. 修复缺陷

```bash
# 1. 创建变更
bash scripts/workflow.sh propose --change bugfix-xxx --title "修复XXX缺陷"

# 2. 实施修复
# 编辑代码...

# 3. 验证修复
bash scripts/workflow.sh verify --change bugfix-xxx

# 4. 审查修复
bash scripts/workflow.sh review --change bugfix-xxx --result pass --blockers 0 --majors 0 --minors 0

# 5. 归档修复
bash scripts/workflow.sh archive --change bugfix-xxx
```

### 3. 重构代码

```bash
# 1. 创建变更
bash scripts/workflow.sh propose --change refactor-xxx --title "重构XXX模块"

# 2. 使用模板
cp templates/artifacts/design-spec-template.md docs/changes/refactor-xxx/design.md

# 3. 实施重构
# 编辑代码...

# 4. 验证重构
bash scripts/workflow.sh verify --change refactor-xxx

# 5. 审查重构
bash scripts/workflow.sh review --change refactor-xxx --result pass --blockers 0 --majors 0 --minors 0

# 6. 归档重构
bash scripts/workflow.sh archive --change refactor-xxx
```

## 最佳实践

### 1. 变更管理
- 每个变更一个目录
- 保持文档完整性
- 及时更新状态

### 2. 文档管理
- 使用标准模板
- 保持文档质量
- 及时更新文档

### 3. 质量保证
- 运行质量检查
- 修复发现的问题
- 保持代码质量

## 下一步

- 阅读 [使用指南](usage.md) 了解更多功能
- 查看 [命令参考](commands.md) 了解所有命令
- 阅读 [工作流指南](workflows.md) 了解工作流详情
- 查看 [操作手册](runbooks/) 了解具体场景

## 获取帮助

- 查看文档：`docs/` 目录
- 运行帮助：`bash scripts/workflow.sh --help`
- 运行测试：`bash tests/run_all.sh`