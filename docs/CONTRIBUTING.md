# 贡献指南

## 概述

欢迎贡献到 global-dev-kit！本指南帮助你了解如何为项目做出贡献。

## 贡献方式

### 1. 代码贡献
- 修复缺陷
- 添加新功能
- 改进性能
- 优化代码

### 2. 文档贡献
- 改进文档
- 添加示例
- 修复错误
- 翻译文档

### 3. 测试贡献
- 添加测试用例
- 改进测试覆盖
- 修复测试问题

### 4. 反馈贡献
- 报告问题
- 提出建议
- 分享经验

## 开发环境

### 1. 前置条件
- Bash 4.0+
- Git
- 文本编辑器

### 2. 克隆仓库
```bash
git clone <repository-url>
cd global-dev-kit
```

### 3. 验证环境
```bash
bash scripts/validate_assets.sh --strict
bash tests/run_all.sh
```

## 贡献流程

### 1. 创建分支
```bash
# 更新主分支
git checkout main
git pull origin main

# 创建功能分支
git checkout -b feature/my-feature

# 或创建修复分支
git checkout -b fix/my-fix
```

### 2. 开发代码
```bash
# 编辑代码
vim src/my-module.c

# 编辑文档
vim docs/my-documentation.md

# 运行测试
bash tests/run_all.sh
```

### 3. 提交变更
```bash
# 添加变更
git add .

# 提交变更
git commit -m "类型: 简短描述

详细描述（可选）

相关问题（可选）"
```

### 4. 推送分支
```bash
git push origin feature/my-feature
```

### 5. 创建PR
- 访问GitHub/GitLab
- 创建Pull Request
- 填写PR描述
- 等待审查

## 提交规范

### 1. 提交类型
- `feat`: 新功能
- `fix`: 修复缺陷
- `docs`: 文档更新
- `style`: 代码格式
- `refactor`: 代码重构
- `test`: 测试更新
- `chore`: 构建/工具更新

### 2. 提交格式
```
类型(范围): 简短描述

详细描述（可选）

相关问题（可选）
```

### 3. 提交示例
```bash
# 好的提交
git commit -m "feat(modbus): 添加 Modbus TCP 驱动

- 实现 Modbus TCP 协议栈
- 添加单元测试
- 更新文档

Closes #123"

# 不好的提交
git commit -m "更新代码"
git commit -m "修复问题"
git commit -m "my changes"
```

## 代码规范

### 1. 命名规范
```c
// 函数名：小驼峰
int calculate_sum(int a, int b);

// 变量名：小驼峰
int user_count;

// 常量名：大写下划线
#define MAX_BUFFER_SIZE 1024

// 结构体名：大驼峰
typedef struct {
    int width;
    int height;
} Rectangle;
```

### 2. 格式规范
```c
// 好的格式
if (condition) {
    do_something();
} else {
    do_something_else();
}

// 不好的格式
if(condition){do_something();}else{do_something_else();}
```

### 3. 注释规范
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

## 测试规范

### 1. 测试覆盖
- 新功能必须有测试
- 修复必须有回归测试
- 关键功能必须有测试

### 2. 测试命名
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
```bash
# 好的做法
bash tests/test_modbus_tcp.sh
bash tests/test_can_fd.sh

# 不好的做法
# 测试之间有依赖关系
```

## 文档规范

### 1. 文档结构
```markdown
# 标题
简短描述

## 概述
详细描述

## 使用
使用方法

## 示例
使用示例

## 参考
相关参考
```

### 2. 文档质量
- 清晰：易于理解
- 准确：信息正确
- 完整：覆盖所有内容
- 及时：保持更新

### 3. 文档格式
- 使用Markdown
- 使用清晰的标题
- 使用列表和表格
- 使用代码块

## 代码审查

### 1. 审查内容
- 代码质量
- 测试覆盖
- 文档更新
- 性能影响
- 安全考虑

### 2. 审查流程
1. 提交PR
2. 自动化检查
3. 人工审查
4. 修复问题
5. 合并PR

### 3. 审查标准
- 代码符合规范
- 测试通过
- 文档更新
- 无安全问题
- 性能可接受

## 问题报告

### 1. 报告内容
- 问题描述
- 重现步骤
- 预期行为
- 实际行为
- 环境信息

### 2. 报告格式
```markdown
## 问题描述
简短描述

## 重现步骤
1. 步骤1
2. 步骤2
3. 步骤3

## 预期行为
描述预期行为

## 实际行为
描述实际行为

## 环境信息
- 操作系统：
- Bash版本：
- Git版本：
```

### 3. 报告示例
```markdown
## 问题描述
验证脚本失败

## 重现步骤
1. 运行 `bash scripts/validate_assets.sh --strict`
2. 观察输出

## 预期行为
验证通过

## 实际行为
验证失败

## 环境信息
- 操作系统：Ubuntu 20.04
- Bash版本：5.0
- Git版本：2.25
```

## 功能请求

### 1. 请求内容
- 功能描述
- 使用场景
- 实现建议
- 优先级

### 2. 请求格式
```markdown
## 功能描述
简短描述

## 使用场景
描述使用场景

## 实现建议
描述实现建议

## 优先级
高/中/低
```

### 3. 请求示例
```markdown
## 功能描述
添加 Modbus TCP 支持

## 使用场景
需要与 Modbus 设备通信

## 实现建议
1. 实现 Modbus TCP 协议栈
2. 添加驱动接口
3. 添加单元测试

## 优先级
高
```

## 行为准则

### 1. 尊重他人
- 尊重不同观点
- 礼貌沟通
- 避免人身攻击

### 2. 专业行为
- 专注于技术问题
- 提供建设性反馈
- 接受合理建议

### 3. 包容性
- 欢迎不同背景
- 避免歧视性语言
- 创造友好环境

## 许可证

### 1. 贡献许可
- 贡献代码使用MIT许可证
- 贡献文档使用CC-BY许可证

### 2. 版权说明
- 贡献者保留版权
- 授予项目使用权限

### 3. 许可证文件
- 查看LICENSE文件
- 了解许可证详情

## 获取帮助

### 1. 文档资源
- [快速入门指南](quick-start.md)
- [使用指南](usage.md)
- [命令参考](commands.md)
- [故障排除指南](troubleshooting.md)

### 2. 社区支持
- 提交Issue
- 参与讨论
- 分享经验

### 3. 联系方式
- 邮件列表
- 社区论坛
- 社交媒体

## 感谢

感谢所有贡献者的付出！

你的贡献让项目变得更好。