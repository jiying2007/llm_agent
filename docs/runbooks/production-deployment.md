# 生产部署运行手册

## 概述

本手册指导如何将 agent-dev-kit 交接到 `~/codex`，再由 `~/codex` apply 到 `~/.codex` 生产运行目录。

## 前置条件

### 1. 环境要求
- Bash 4.0+
- Git 2.0+
- 足够的磁盘空间
- 网络访问权限

### 2. 权限要求
- 读写 `~/codex` 声明式资产仓库
- 由 `~/codex` 生成并写入 `~/.codex` 的权限
- 执行脚本权限
- 创建备份权限

### 3. 依赖检查
```bash
bash scripts/health-check.sh check-dependencies
```

## 部署流程

### 1. 准备阶段

#### 1.1 验证源代码
```bash
# 运行所有测试
bash tests/run_all.sh

# 运行质量检查
bash scripts/quality-gate-check.sh check-all

# 运行健康检查
bash scripts/health-check.sh check-all
```

#### 1.2 创建备份
```bash
# 备份当前运行目录；常规回滚优先使用 ~/codex apply plan
rtk bash ~/codex/scripts/backup.sh
```

#### 1.3 锁定版本
```bash
# 锁定版本
bash scripts/version-manager.sh lock --version 1.0.0
```

### 2. 部署阶段

#### 2.1 构建并应用 Codex 源资产
```bash
# agent-dev-kit 保持平台中立，不直接写入 ~/.codex，也不提供 Codex 专属 handoff 命令
bash scripts/devkit.sh validate --strict

# 在 ~/codex 中构建、预览并应用声明式 Codex Home 资产
rtk bash ~/codex/scripts/build.sh
rtk bash ~/codex/scripts/doctor.sh --scope all
rtk bash ~/codex/scripts/plan.sh --target ~/.codex --prune-stale --output ~/codex/build/apply-plan.json
rtk bash ~/codex/scripts/apply.sh --plan ~/codex/build/apply-plan.json --dry-run
rtk bash ~/codex/scripts/apply.sh --plan ~/codex/build/apply-plan.json
rtk bash ~/codex/scripts/check.sh
```

#### 2.2 验证交接与运行目录
```bash
# 验证 adk 资产
bash scripts/devkit.sh validate --strict

# 验证 ~/codex 构建、治理和 live 状态
cd ~/codex
rtk bash scripts/doctor.sh --scope all
```

#### 2.3 配置环境
```bash
# 检查配置
bash scripts/health-check.sh check-configuration

# 验证配置
cat manifest.yaml
```

### 3. 验证阶段

#### 3.1 运行测试
```bash
# 运行所有测试
bash tests/run_all.sh

# 运行集成测试
bash tests/test_integration.sh
```

#### 3.2 质量检查
```bash
# 运行质量门禁检查
bash scripts/quality-gate-check.sh check-all

# 运行健康检查
bash scripts/health-check.sh check-all
```

#### 3.3 功能验证
```bash
# 创建测试变更
bash scripts/workflow.sh propose --change test-deploy --title "测试部署"

# 验证工作流
bash scripts/workflow.sh apply --change test-deploy
bash scripts/workflow.sh verify --change test-deploy
bash scripts/workflow.sh review --change test-deploy --result pass --blockers 0 --majors 0 --minors 0
bash scripts/workflow.sh archive --change test-deploy
```

### 4. 收尾阶段

#### 4.1 生成文档
```bash
# 生成变更日志
bash scripts/version-manager.sh changelog --version 1.0.0

# 生成部署报告
echo "部署完成: $(date)" > deploy-report.txt
echo "版本: 1.0.0" >> deploy-report.txt
echo "状态: 成功" >> deploy-report.txt
```

#### 4.2 清理临时文件
```bash
# 清理测试数据
rm -rf docs/changes/test-deploy

# 清理临时文件
rm -rf /tmp/adk-*
```

#### 4.3 通知相关人员
```bash
# 发送部署通知
echo "agent-dev-kit 1.0.0 部署完成" | mail -s "部署通知" team@example.com
```

## 回滚流程

### 1. 识别问题
```bash
# 检查错误日志
tail -100 /var/log/adk.log

# 运行健康检查
bash scripts/health-check.sh check-all --verbose
```

### 2. 执行回滚
```bash
# 回滚到上一版本
bash scripts/backup-rollback.sh rollback --target ~/.codex --version pre-deploy

# 或使用版本管理器
bash scripts/version-manager.sh downgrade --target 0.9.0 --force
```

### 3. 验证回滚
```bash
# 验证回滚结果
bash scripts/health-check.sh check-all

# 运行测试
bash tests/run_all.sh
```

## 监控和维护

### 1. 定期检查
```bash
# 每日健康检查
bash scripts/health-check.sh check-all

# 每周质量检查
bash scripts/quality-gate-check.sh check-all
```

### 2. 备份管理
```bash
# 列出备份
bash scripts/backup-rollback.sh list

# 验证备份
bash scripts/backup-rollback.sh verify --version 1.0.0
```

### 3. 版本管理
```bash
# 查看当前版本
bash scripts/version-manager.sh current

# 比较版本
bash scripts/version-manager.sh compare --version 1.0.0 --target 1.1.0
```

## 故障处理

### 1. 交接或 apply 失败
```bash
# 检查错误日志
bash scripts/health-check.sh check-all --verbose

# 修复问题后重新验证 ADK，并在 ~/codex 侧重新 build / apply dry-run
bash scripts/devkit.sh validate --strict
rtk bash ~/codex/scripts/build.sh
rtk bash ~/codex/scripts/plan.sh --target ~/.codex --prune-stale --output ~/codex/build/apply-plan.json
rtk bash ~/codex/scripts/apply.sh --plan ~/codex/build/apply-plan.json --dry-run
```

### 2. 测试失败
```bash
# 运行单个测试
bash tests/test_validate.sh

# 查看测试输出
bash tests/run_all.sh 2>&1 | tee test-output.log

# 修复问题
# 重新测试
bash tests/run_all.sh
```

### 3. 质量问题
```bash
# 运行质量检查
bash scripts/quality-gate-check.sh check-all --verbose

# 修复问题
# 重新检查
bash scripts/quality-gate-check.sh check-all
```

## 性能优化

### 1. 磁盘空间
```bash
# 清理旧备份
find ~/.backups -name "*.tar.gz" -mtime +30 -delete

# 压缩文件
tar -czf backup.tar.gz docs/changes/
```

### 2. 网络优化
```bash
# 使用本地镜像
git config --local url."file:///path/to/mirror".insteadOf "https://github.com/"

# 压缩传输
git config --global core.compression 9
```

### 3. 并行处理
```bash
# 并行运行测试
bash tests/run_all.sh &

# 并行处理文件
find . -name "*.sh" -exec parallel bash {} \;
```

## 安全考虑

### 1. 权限管理
```bash
# 设置文件权限
chmod 755 scripts/*.sh
chmod 644 manifest.yaml
```

### 2. 备份安全
```bash
# 加密备份
gpg --encrypt --recipient user@example.com backup.tar.gz

# 安全存储
mv backup.tar.gz.gpg /secure/backup/
```

### 3. 日志管理
```bash
# 配置日志轮转
cat > /etc/logrotate.d/adk <<EOF
/var/log/adk.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
}
EOF
```

## 文档更新

### 1. 更新部署文档
```bash
# 更新部署手册
vim docs/runbooks/production-deployment.md

# 提交变更
git add docs/runbooks/production-deployment.md
git commit -m "docs: 更新部署手册"
```

### 2. 更新变更日志
```bash
# 生成变更日志
bash scripts/version-manager.sh changelog --version 1.0.0

# 提交变更
git add CHANGELOG-1.0.0.md
git commit -m "docs: 添加变更日志"
```

## 团队协作

### 1. 通知团队
```bash
# 发送通知
echo "部署完成，请验证" | mail -s "部署通知" team@example.com

# 更新状态
echo "部署状态: 成功" > /shared/status.txt
```

### 2. 知识分享
```bash
# 分享部署经验
vim docs/explorations/deployment-experience/exploration.md

# 提交分享
git add docs/explorations/
git commit -m "docs: 分享部署经验"
```

## 持续改进

### 1. 收集反馈
```bash
# 记录反馈
vim docs/feedback.md

# 分析反馈
grep -i "问题" docs/feedback.md
```

### 2. 改进流程
```bash
# 更新部署手册
vim docs/runbooks/production-deployment.md

# 提交改进
git add docs/runbooks/production-deployment.md
git commit -m "docs: 改进部署流程"
```

### 3. 自动化改进
```bash
# 创建自动化脚本
vim scripts/auto-deploy.sh

# 测试自动化
bash scripts/auto-deploy.sh --dry-run
```

## 附录

### 1. 常用命令
```bash
# 健康检查
bash scripts/health-check.sh check-all

# 质量检查
bash scripts/quality-gate-check.sh check-all

# 备份管理
bash scripts/backup-rollback.sh backup --target ~/.codex

# 版本管理
bash scripts/version-manager.sh current
```

### 2. 配置文件
```bash
# 主配置
manifest.yaml

# 领域语言
CONTEXT.md

# 版本锁定
.version-lock
```

### 3. 日志文件
```bash
# 部署日志
/var/log/adk.log

# 测试日志
test-output.log

# 错误日志
error.log
```

### 4. 相关文档
- [快速入门指南](../quick-start.md)
- [使用指南](../usage.md)
- [命令参考](../commands.md)
- [故障排除指南](../troubleshooting.md)
- [最佳实践](../best-practices.md)
