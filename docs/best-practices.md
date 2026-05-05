# 最佳实践指南

## 概述

本指南总结了使用 global-dev-kit 的最佳实践，帮助你更高效地使用 gdk 进行开发。

## 变更管理最佳实践

### 1. 变更粒度
**推荐**：每个变更专注于一个独立的问题或功能

```bash
# 好的做法
bash scripts/workflow.sh propose --change add-modbus-tcp --title "接入 Modbus TCP"
bash scripts/workflow.sh propose --change fix-can-timeout --title "修复 CAN 超时问题"

# 不好的做法
bash scripts/workflow.sh propose --change big-update --title "大更新"
```

### 2. 变更命名
**推荐**：使用 kebab-case，包含动词和对象

```bash
# 好的命名
add-modbus-tcp
fix-can-timeout
refactor-driver-module
update-api-documentation

# 不好的命名
update
fix
my-change
```

### 3. 变更描述
**推荐**：清晰描述变更的目标和范围

```markdown
# 好的描述
## 目标
接入 Modbus TCP 协议，实现设备通信

## 范围
- 新增 Modbus TCP 驱动
- 集成协议栈
- 添加单元测试

# 不好的描述
## 目标
更新代码
```

## 文档管理最佳实践

### 1. 使用模板
**推荐**：始终使用标准模板创建文档

```bash
# 使用模板
cp templates/artifacts/prd-template.md docs/changes/my-change/prd.md

# 编辑模板
vim docs/changes/my-change/prd.md
```

### 2. 保持文档同步
**推荐**：代码变更时同步更新文档

```bash
# 1. 修改代码
vim src/my-module.c

# 2. 更新文档
vim docs/changes/my-change/design.md

# 3. 提交变更
git add .
git commit -m "更新代码和文档"
```

### 3. 文档质量
**推荐**：确保文档清晰、准确、完整

```markdown
# 好的文档
## 接口设计
```c
/**
 * @brief 初始化 Modbus TCP 连接
 * @param ip 服务器IP地址
 * @param port 服务器端口
 * @return 0 成功，其他值失败
 */
int modbus_tcp_init(const char *ip, int port);
```

# 不好的文档
## 接口设计
初始化函数
```

## 代码质量最佳实践

### 1. 编码规范
**推荐**：遵循项目编码规范

```c
// 好的代码
int calculate_sum(int a, int b) {
    return a + b;
}

// 不好的代码
int calc(int a,int b){return a+b;}
```

### 2. 注释规范
**推荐**：添加清晰的注释

```c
// 好的注释
/**
 * @brief 计算两个数的和
 * @param a 第一个加数
 * @param b 第二个加数
 * @return 两数之和
 */
int calculate_sum(int a, int b) {
    return a + b;
}

// 不好的注释
// 计算和
int calculate_sum(int a, int b) {
    return a + b;
}
```

### 3. 错误处理
**推荐**：正确处理错误情况

```c
// 好的错误处理
int result = modbus_tcp_init(ip, port);
if (result != 0) {
    log_error("初始化失败: %d", result);
    return result;
}

// 不好的错误处理
modbus_tcp_init(ip, port);
```

## 测试最佳实践

### 1. 测试覆盖
**推荐**：确保关键功能有测试覆盖

```bash
# 运行测试
bash tests/run_all.sh

# 检查测试覆盖率
bash scripts/quality-gate-check.sh check-evidence
```

### 2. 测试命名
**推荐**：使用描述性的测试名称

```bash
# 好的测试名称
test_modbus_tcp_init_success
test_modbus_tcp_init_invalid_ip
test_modbus_tcp_init_connection_timeout

# 不好的测试名称
test1
test_function
test_case
```

### 3. 测试独立性
**推荐**：每个测试独立运行

```bash
# 好的做法
bash tests/test_modbus_tcp.sh
bash tests/test_can_fd.sh

# 不好的做法
# 测试之间有依赖关系
```

## 工作流最佳实践

### 1. 遵循工作流
**推荐**：严格按照工作流执行

```bash
# 正确的顺序
bash scripts/workflow.sh propose --change my-change --title "标题"
bash scripts/workflow.sh apply --change my-change
bash scripts/workflow.sh verify --change my-change
bash scripts/workflow.sh review --change my-change --result pass --blockers 0 --majors 0 --minors 0
bash scripts/workflow.sh archive --change my-change

# 不好的做法
# 跳过某些步骤
```

### 2. 状态管理
**推荐**：及时更新变更状态

```bash
# 检查状态
cat docs/changes/my-change/state.yaml

# 确保状态正确
stage: proposed  # 或 applied, verified, review-passed
owner: your-name
updated_at: 2026-05-05T00:00:00Z
```

### 3. 历史记录
**推荐**：保持历史记录完整

```bash
# 查看历史
cat docs/changes/my-change/history.log

# 确保每次状态变更都有记录
```

## 质量保证最佳实践

### 1. 定期检查
**推荐**：定期运行质量检查

```bash
# 每次修改后运行
bash scripts/quality-gate-check.sh check-all

# 提交前运行
bash tests/run_all.sh
```

### 2. 修复问题
**推荐**：及时修复发现的问题

```bash
# 发现问题后立即修复
bash scripts/quality-gate-check.sh check-all --verbose
# 修复问题...
bash scripts/quality-gate-check.sh check-all
```

### 3. 持续改进
**推荐**：持续改进代码和文档质量

```bash
# 定期审查
git log --oneline -10

# 改进代码
vim src/my-module.c

# 改进文档
vim docs/my-documentation.md
```

## 协作最佳实践

### 1. 版本控制
**推荐**：使用版本控制管理代码

```bash
# 创建分支
git checkout -b feature/my-feature

# 提交变更
git add .
git commit -m "描述变更"

# 合并分支
git checkout main
git merge feature/my-feature
```

### 2. 代码审查
**推荐**：进行代码审查

```bash
# 提交审查
git push origin feature/my-feature

# 创建PR
# 进行代码审查
# 合并PR
```

### 3. 沟通协作
**推荐**：保持良好沟通

```bash
# 记录决策
vim docs/changes/my-change/design.md

# 分享知识
vim docs/explorations/my-exploration/exploration.md
```

## 性能优化最佳实践

### 1. 代码优化
**推荐**：优化关键代码路径

```c
// 好的优化
for (int i = 0; i < n; i++) {
    // 高效代码
}

// 不好的代码
for (int i = 0; i < n; i++) {
    // 低效代码
}
```

### 2. 内存管理
**推荐**：正确管理内存

```c
// 好的内存管理
int *array = malloc(size * sizeof(int));
if (array == NULL) {
    return -1;
}
// 使用数组
free(array);

// 不好的内存管理
int *array = malloc(size * sizeof(int));
// 使用数组
// 忘记释放内存
```

### 3. 资源管理
**推荐**：正确管理系统资源

```c
// 好的资源管理
FILE *file = fopen("data.txt", "r");
if (file == NULL) {
    return -1;
}
// 读取文件
fclose(file);

// 不好的资源管理
FILE *file = fopen("data.txt", "r");
// 读取文件
// 忘记关闭文件
```

## 安全最佳实践

### 1. 输入验证
**推荐**：验证所有输入

```c
// 好的输入验证
if (input == NULL) {
    return -1;
}
if (strlen(input) > MAX_LENGTH) {
    return -1;
}

// 不好的输入验证
// 直接使用输入
```

### 2. 错误处理
**推荐**：正确处理错误

```c
// 好的错误处理
int result = function();
if (result != 0) {
    log_error("函数调用失败: %d", result);
    return result;
}

// 不好的错误处理
function();
```

### 3. 日志记录
**推荐**：记录关键操作

```c
// 好的日志记录
log_info("开始初始化");
int result = init();
if (result != 0) {
    log_error("初始化失败: %d", result);
    return result;
}
log_info("初始化成功");

// 不好的日志记录
// 没有日志记录
```

## 文档最佳实践

### 1. README文档
**推荐**：保持README文档更新

```markdown
# 项目名称
简短描述

## 安装
安装步骤

## 使用
使用方法

## 贡献
贡献指南
```

### 2. API文档
**推荐**：维护API文档

```markdown
# API文档
## 函数列表
### function_name
描述

**参数**：
- param1: 描述
- param2: 描述

**返回值**：
描述
```

### 3. 变更日志
**推荐**：维护变更日志

```markdown
# 变更日志
## [1.0.0] - 2026-05-05
### 新增
- 功能1
- 功能2

### 修复
- 问题1
- 问题2
```

## 工具使用最佳实践

### 1. 脚本使用
**推荐**：使用标准脚本

```bash
# 使用工作流脚本
bash scripts/workflow.sh propose --change my-change --title "标题"

# 使用质量检查脚本
bash scripts/quality-gate-check.sh check-all

# 使用验证脚本
bash scripts/validate_assets.sh --strict
```

### 2. 模板使用
**推荐**：使用标准模板

```bash
# 使用产物模板
cp templates/artifacts/prd-template.md docs/changes/my-change/prd.md

# 使用工作流模板
cp templates/workflows/standard-workflow-template.md docs/workflows/my-workflow.md
```

### 3. 测试使用
**推荐**：运行完整测试

```bash
# 运行所有测试
bash tests/run_all.sh

# 运行特定测试
bash tests/test_templates.sh
bash tests/test_integration.sh
```

## 持续改进

### 1. 定期审查
**推荐**：定期审查代码和文档

```bash
# 查看最近变更
git log --oneline -20

# 审查代码
git diff HEAD~10

# 审查文档
vim docs/
```

### 2. 收集反馈
**推荐**：收集用户反馈

```bash
# 记录反馈
vim docs/feedback.md

# 分析反馈
# 改进代码和文档
```

### 3. 学习改进
**推荐**：持续学习和改进

```bash
# 阅读文档
vim docs/

# 学习最佳实践
vim docs/best-practices.md

# 应用改进
# 修改代码和文档
```

## 总结

遵循这些最佳实践可以帮助你：

1. 提高代码质量
2. 减少错误
3. 提高开发效率
4. 改善协作
5. 保持项目健康

记住：最佳实践是指导原则，不是僵化的规则。根据实际情况灵活应用。