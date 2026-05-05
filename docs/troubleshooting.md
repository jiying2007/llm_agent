# 故障排除指南

## 概述

本指南帮助你诊断和解决使用 global-dev-kit 时遇到的常见问题。

## 常见问题

### 1. 安装问题

#### 问题：验证失败
```
[FAIL] validation failed
```

**可能原因**：
- 文件格式错误
- 缺少必需文件
- 配置不正确

**解决方案**：
```bash
# 1. 运行详细验证
bash scripts/validate_assets.sh --strict

# 2. 检查格式
bash scripts/check_format.sh

# 3. 查看错误详情
bash scripts/quality-gate-check.sh check-all --verbose
```

#### 问题：测试失败
```
Some tests failed
```

**可能原因**：
- 环境问题
- 依赖缺失
- 代码错误

**解决方案**：
```bash
# 1. 运行单个测试定位问题
bash tests/test_validate.sh

# 2. 检查测试环境
bash --version
git --version

# 3. 查看测试输出
bash tests/run_all.sh 2>&1 | grep -A 5 "FAIL"
```

### 2. 工作流问题

#### 问题：无法创建变更
```
[FAIL] change already exists
```

**可能原因**：
- 变更目录已存在
- 变更ID重复

**解决方案**：
```bash
# 1. 检查变更目录
ls docs/changes/

# 2. 使用不同的变更ID
bash scripts/workflow.sh propose --change new-change-id --title "新变更"

# 3. 或删除现有变更（谨慎操作）
rm -rf docs/changes/old-change-id
```

#### 问题：阶段顺序错误
```
[FAIL] apply requires stage 'proposed', current: applied
```

**可能原因**：
- 尝试在错误的阶段执行操作
- 状态文件损坏

**解决方案**：
```bash
# 1. 检查当前阶段
cat docs/changes/my-change/state.yaml

# 2. 按正确顺序执行
bash scripts/workflow.sh propose --change my-change --title "标题"
bash scripts/workflow.sh apply --change my-change
bash scripts/workflow.sh verify --change my-change
bash scripts/workflow.sh review --change my-change --result pass --blockers 0 --majors 0 --minors 0
bash scripts/workflow.sh archive --change my-change
```

#### 问题：验证失败
```
[FAIL] verify failed
```

**可能原因**：
- 缺少必需文件
- 文件格式错误
- 验证脚本失败

**解决方案**：
```bash
# 1. 检查验证报告
cat docs/changes/my-change/verify-report.md

# 2. 运行验证脚本
bash scripts/validate_assets.sh --strict
bash scripts/check_format.sh
bash scripts/check_change_governance.sh docs/changes/my-change

# 3. 修复问题后重新验证
bash scripts/workflow.sh verify --change my-change
```

#### 问题：审查失败
```
[FAIL] review needs-fix
```

**可能原因**：
- 存在blocker或major问题
- 评审报告状态不正确

**解决方案**：
```bash
# 1. 检查评审报告
cat docs/changes/my-change/review-report.md

# 2. 修复发现的问题

# 3. 重新审查
bash scripts/workflow.sh review --change my-change --result pass --blockers 0 --majors 0 --minors 0
```

### 3. 模板问题

#### 问题：模板文件缺失
```
[ERROR] 缺失模板: templates/artifacts/xxx-template.md
```

**可能原因**：
- 模板文件被删除
- 模板文件未创建

**解决方案**：
```bash
# 1. 检查模板目录
ls templates/artifacts/
ls templates/workflows/

# 2. 重新创建模板
# 参考现有模板创建新模板

# 3. 运行质量检查
bash scripts/quality-gate-check.sh check-artifacts
```

#### 问题：模板格式错误
```
[ERROR] 模板缺少artifact标签
```

**可能原因**：
- 模板格式不正确
- 缺少必需字段

**解决方案**：
```bash
# 1. 检查模板内容
cat templates/artifacts/xxx-template.md

# 2. 确保包含必需字段
# - [artifact:XXX]
# - status: READY
# - owner: xxx

# 3. 运行质量检查
bash scripts/quality-gate-check.sh check-artifacts --verbose
```

### 4. Profile问题

#### 问题：Profile继承错误
```
[ERROR] Profile xxx 继承的 yyy 不存在
```

**可能原因**：
- Profile名称错误
- 继承关系配置错误

**解决方案**：
```bash
# 1. 检查manifest.yaml
cat manifest.yaml | grep -A 10 "profiles:"

# 2. 修复继承关系
# 确保继承的Profile存在

# 3. 运行Profile检查
bash scripts/quality-gate-check.sh check-profiles
```

#### 问题：Profile引用的Agent/Skill不存在
```
[ERROR] Agent xxx 不存在
```

**可能原因**：
- Agent/Skill名称错误
- Agent/Skill目录缺失

**解决方案**：
```bash
# 1. 检查Agent目录
ls agents/

# 2. 检查Skill目录
ls skills/

# 3. 修复manifest.yaml中的引用
```

### 5. 质量检查问题

#### 问题：质量门禁检查失败
```
[ERROR] 质量门禁检查失败
```

**可能原因**：
- 产物不完整
- 一致性问题
- 验证证据缺失

**解决方案**：
```bash
# 1. 运行详细检查
bash scripts/quality-gate-check.sh check-all --verbose

# 2. 根据错误信息修复问题

# 3. 重新运行检查
bash scripts/quality-gate-check.sh check-all
```

## 诊断工具

### 1. 验证工具
```bash
# 完整验证
bash scripts/validate_assets.sh --strict

# 快速验证
bash scripts/validate_assets.sh --quick

# 格式检查
bash scripts/check_format.sh
```

### 2. 质量检查工具
```bash
# 所有检查
bash scripts/quality-gate-check.sh check-all

# 产物检查
bash scripts/quality-gate-check.sh check-artifacts

# 一致性检查
bash scripts/quality-gate-check.sh check-consistency

# 验证证据检查
bash scripts/quality-gate-check.sh check-evidence

# Profile检查
bash scripts/quality-gate-check.sh check-profiles
```

### 3. 测试工具
```bash
# 运行所有测试
bash tests/run_all.sh

# 运行单个测试
bash tests/test_validate.sh
bash tests/test_templates.sh
bash tests/test_integration.sh
```

### 4. 工作流工具
```bash
# 查看变更状态
cat docs/changes/my-change/state.yaml

# 查看历史记录
cat docs/changes/my-change/history.log

# 查看验证报告
cat docs/changes/my-change/verify-report.md

# 查看评审报告
cat docs/changes/my-change/review-report.md
```

## 日志和调试

### 1. 启用详细输出
```bash
# 使用--verbose参数
bash scripts/quality-gate-check.sh check-all --verbose

# 使用--strict参数
bash scripts/validate_assets.sh --strict
```

### 2. 查看错误日志
```bash
# 查看测试输出
bash tests/run_all.sh 2>&1 | tee test-output.log

# 查看验证输出
bash scripts/validate_assets.sh --strict 2>&1 | tee validate-output.log
```

### 3. 调试脚本
```bash
# 启用bash调试
bash -x scripts/workflow.sh propose --change test --title "测试"

# 查看脚本执行过程
set -x
bash scripts/workflow.sh propose --change test --title "测试"
set +x
```

## 恢复操作

### 1. 恢复变更
```bash
# 从备份恢复
cp -r backup/changes/my-change docs/changes/

# 从git恢复
git checkout HEAD -- docs/changes/my-change
```

### 2. 重置变更状态
```bash
# 手动编辑状态文件
cat > docs/changes/my-change/state.yaml << EOF
stage: proposed
owner: $(whoami)
updated_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
```

### 3. 强制归档
```bash
# 使用--force参数
bash scripts/workflow.sh archive --change my-change --force
```

## 预防措施

### 1. 定期备份
```bash
# 备份变更目录
tar -czf backup-$(date +%Y%m%d).tar.gz docs/changes/

# 备份配置
cp manifest.yaml manifest.yaml.backup
```

### 2. 版本控制
```bash
# 定期提交
git add .
git commit -m "保存工作进度"

# 创建分支
git checkout -b feature/my-feature
```

### 3. 测试验证
```bash
# 修改前运行测试
bash tests/run_all.sh

# 修改后运行测试
bash tests/run_all.sh
```

## 获取帮助

### 1. 查看文档
- [快速入门指南](quick-start.md)
- [使用指南](usage.md)
- [命令参考](commands.md)
- [工作流指南](workflows.md)

### 2. 运行帮助
```bash
# 工作流帮助
bash scripts/workflow.sh --help

# 质量检查帮助
bash scripts/quality-gate-check.sh --help
```

### 3. 检查配置
```bash
# 查看manifest.yaml
cat manifest.yaml

# 查看CONTEXT.md
cat CONTEXT.md
```

## 联系支持

如果以上方法都无法解决问题，请：

1. 收集错误信息
2. 记录重现步骤
3. 提供环境信息
4. 提交问题报告