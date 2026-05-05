# 变更追溯目录说明

## 目录结构

```
docs/changes/
├── README.md                    # 本说明文件
├── archive/                     # 归档目录
│   └── YYYYMMDD-<change-id>/   # 按日期归档的变更
├── <change-id>/                 # 活跃变更目录
│   ├── proposal.md             # 变更提案
│   ├── implementation-report.md # 实施报告
│   ├── test-report.md          # 测试报告
│   ├── review-report.md        # 评审报告
│   ├── verify-report.md        # 验证报告
│   ├── state.yaml              # 变更状态
│   └── negative-results.md     # 负面结果记录
└── index.md                    # 变更索引
```

## 目录用途

### 1. 变更追溯
- 记录每个变更的完整生命周期
- 支持变更历史查询
- 提供变更影响分析

### 2. 质量保证
- 记录验证证据
- 支持质量审查
- 提供质量报告

### 3. 知识积累
- 积累变更经验
- 记录最佳实践
- 支持知识传承

## 使用规范

### 1. 变更目录命名
- 使用kebab-case格式
- 包含变更ID
- 例如：`modbus-tcp-integration`

### 2. 文件命名规范
- 使用小写字母和连字符
- 包含文件类型后缀
- 例如：`proposal.md`、`test-report.md`

### 3. 状态管理
- 使用state.yaml记录变更状态
- 状态包括：proposed、applied、verified、review-passed、archived
- 状态变更需要记录时间戳

## 变更流程

### 1. 提出变更
```bash
./scripts/workflow.sh propose --change <change-id> --title "变更标题"
```

### 2. 实施变更
```bash
./scripts/workflow.sh apply --change <change-id>
```

### 3. 验证变更
```bash
./scripts/workflow.sh verify --change <change-id>
```

### 4. 审查变更
```bash
./scripts/workflow.sh review --change <change-id> --result pass --blockers 0 --majors 0 --minors 0
```

### 5. 归档变更
```bash
./scripts/workflow.sh archive --change <change-id>
```

## 文件模板

### 1. 变更提案（proposal.md）
```markdown
# 变更提案：<变更标题>

## 变更目标
[描述变更目标]

## 变更范围
[描述变更范围]

## 变更方案
[描述变更方案]

## 风险与依赖
[识别风险和依赖]

## 时间计划
[描述时间计划]
```

### 2. 实施报告（implementation-report.md）
```markdown
# 实施报告：<变更标题>

## 实施概述
[描述实施概述]

## 实施步骤
[描述实施步骤]

## 实施结果
[描述实施结果]

## 问题与解决
[描述遇到的问题和解决方案]
```

### 3. 测试报告（test-report.md）
```markdown
# 测试报告：<变更标题>

## 测试概述
[描述测试概述]

## 测试用例
[描述测试用例]

## 测试结果
[描述测试结果]

## 问题与建议
[描述发现的问题和改进建议]
```

### 4. 评审报告（review-report.md）
```markdown
# 评审报告：<变更标题>

## 评审概述
[描述评审概述]

## 评审结果
[描述评审结果]

## 问题与建议
[描述发现的问题和改进建议]

## 评审结论
[描述评审结论]
```

### 5. 验证报告（verify-report.md）
```markdown
# 验证报告：<变更标题>

## 验证概述
[描述验证概述]

## 验证步骤
[描述验证步骤]

## 验证结果
[描述验证结果]

## 验证结论
[描述验证结论]
```

## 状态管理

### 1. 状态定义
- `proposed`：变更已提出
- `applied`：变更已实施
- `verified`：变更已验证
- `review-passed`：变更已审查通过
- `archived`：变更已归档

### 2. 状态转换
```
proposed -> applied -> verified -> review-passed -> archived
```

### 3. 状态记录
```yaml
stage: proposed
timestamp: 2026-05-05T01:00:00Z
owner: requirements-analyst
notes: 变更已提出，等待实施
```

## 索引管理

### 1. 索引内容
- 变更ID
- 变更标题
- 变更状态
- 变更时间
- 变更负责人

### 2. 索引更新
- 每次状态变更时更新索引
- 定期清理归档变更
- 维护变更历史

### 3. 索引查询
- 按状态查询
- 按时间查询
- 按负责人查询

## 归档管理

### 1. 归档条件
- 变更已完成
- 所有问题已解决
- 文档已完善

### 2. 归档流程
1. 整理变更文档
2. 验证文档完整性
3. 移动到归档目录
4. 更新变更索引

### 3. 归档查询
- 按日期查询
- 按变更ID查询
- 按变更类型查询

## 最佳实践

### 1. 变更管理
- 每个变更一个目录
- 保持文档完整性
- 及时更新状态

### 2. 文档管理
- 使用标准模板
- 保持文档质量
- 及时更新文档

### 3. 索引管理
- 及时更新索引
- 保持索引准确性
- 定期清理索引

## 工具支持

### 1. 工作流脚本
- `scripts/workflow.sh`：标准工作流脚本
- 支持所有变更操作
- 自动化状态管理

### 2. 检查脚本
- `scripts/check-gdk-harden-readiness.sh`：质量检查脚本
- 支持变更质量验证
- 自动化质量检查

### 3. 报告脚本
- `scripts/generate-adoption-matrix-summary.sh`：报告生成脚本
- 支持变更报告生成
- 自动化报告生成

## 常见问题

### 1. 如何创建新变更？
```bash
./scripts/workflow.sh propose --change <change-id> --title "变更标题"
```

### 2. 如何查看变更状态？
```bash
cat docs/changes/<change-id>/state.yaml
```

### 3. 如何归档变更？
```bash
./scripts/workflow.sh archive --change <change-id>
```

### 4. 如何查询变更历史？
```bash
cat docs/changes/index.md
```

## 附录

### 1. 术语表
- 变更ID：变更的唯一标识
- 变更状态：变更的当前状态
- 变更文档：变更的相关文档

### 2. 参考文档
- 标准工作流模板
- 紧急工作流模板
- 产物模板

### 3. 相关脚本
- `scripts/workflow.sh`
- `scripts/check-gdk-harden-readiness.sh`
- `scripts/generate-adoption-matrix-summary.sh`