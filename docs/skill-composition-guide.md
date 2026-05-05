# 技能组合指南

## 概述

本指南介绍如何组合使用global-dev-kit中的技能，借鉴mattpocock-skills的可组合技能范式，提高开发效率和质量。

## 技能组合原则

### 1. 小技能组合优于大流程
- 每个技能专注于单一职责
- 技能之间通过标准接口协作
- 组合使用可以覆盖复杂场景

### 2. 意图驱动的技能选择
- 根据开发意图选择技能
- 技能触发词明确
- 技能场景描述清晰

### 3. 渐进式技能组合
- 从简单技能开始
- 逐步添加相关技能
- 根据需要调整组合

## 技能分类

### 1. 需求分析类
- `requirements-triage`：需求分类与优先级排序
- `interface-contract-design`：接口契约设计
- `register-map-design`：寄存器映射设计

### 2. 架构设计类
- `adr-writer`：架构决策记录
- `component-api-stability`：组件API稳定性
- `protocol-stack-integration`：协议栈集成

### 3. 开发实现类
- `driver-bringup-checklist`：驱动开发检查清单
- `bsp-porting-playbook`：BSP移植手册
- `rtos-task-design`：RTOS任务设计
- `interrupt-dma-patterns`：中断与DMA模式

### 4. 构建测试类
- `cmake-cross-build`：CMake交叉编译
- `static-analysis-c-cpp`：C/C++静态分析
- `unit-test-embedded`：嵌入式单元测试
- `integration-hil-sil`：HIL/SIL集成测试

### 5. 质量保证类
- `systematic-debugging`：系统化调试
- `fault-injection-recovery`：故障注入与恢复
- `performance-profiling-embedded`：嵌入式性能分析
- `verification-before-completion`：完成前验证

### 6. 发布管理类
- `release-versioning`：版本发布管理
- `commit-pr-quality-gate`：提交与PR质量门禁

## 常见技能组合

### 1. 驱动开发组合
**场景**：开发新的硬件驱动

**技能组合**：
1. `requirements-triage`：分析驱动需求
2. `register-map-design`：设计寄存器映射
3. `interface-contract-design`：定义接口契约
4. `driver-bringup-checklist`：执行驱动开发检查
5. `static-analysis-c-cpp`：静态代码分析
6. `unit-test-embedded`：编写单元测试
7. `integration-hil-sil`：HIL/SIL集成测试
8. `verification-before-completion`：完成前验证

**使用流程**：
```bash
# 1. 需求分析
# 使用requirements-triage分析驱动需求

# 2. 寄存器设计
# 使用register-map-design设计寄存器映射

# 3. 接口设计
# 使用interface-contract-design定义接口契约

# 4. 驱动开发
# 使用driver-bringup-checklist执行驱动开发检查

# 5. 代码分析
# 使用static-analysis-c-cpp进行静态分析

# 6. 单元测试
# 使用unit-test-embedded编写单元测试

# 7. 集成测试
# 使用integration-hil-sil进行HIL/SIL集成测试

# 8. 验证完成
# 使用verification-before-completion进行完成前验证
```

### 2. BSP移植组合
**场景**：移植BSP到新平台

**技能组合**：
1. `requirements-triage`：分析移植需求
2. `bsp-porting-playbook`：执行BSP移植流程
3. `cmake-cross-build`：配置交叉编译
4. `static-analysis-c-cpp`：静态代码分析
5. `unit-test-embedded`：编写单元测试
6. `integration-hil-sil`：HIL/SIL集成测试
7. `verification-before-completion`：完成前验证

**使用流程**：
```bash
# 1. 需求分析
# 使用requirements-triage分析移植需求

# 2. BSP移植
# 使用bsp-porting-playbook执行BSP移植流程

# 3. 交叉编译
# 使用cmake-cross-build配置交叉编译

# 4. 代码分析
# 使用static-analysis-c-cpp进行静态分析

# 5. 单元测试
# 使用unit-test-embedded编写单元测试

# 6. 集成测试
# 使用integration-hil-sil进行HIL/SIL集成测试

# 7. 验证完成
# 使用verification-before-completion进行完成前验证
```

### 3. 协议栈集成组合
**场景**：集成新的通信协议栈

**技能组合**：
1. `requirements-triage`：分析协议需求
2. `protocol-stack-integration`：集成协议栈
3. `interface-contract-design`：定义接口契约
4. `static-analysis-c-cpp`：静态代码分析
5. `unit-test-embedded`：编写单元测试
6. `integration-hil-sil`：HIL/SIL集成测试
7. `verification-before-completion`：完成前验证

**使用流程**：
```bash
# 1. 需求分析
# 使用requirements-triage分析协议需求

# 2. 协议集成
# 使用protocol-stack-integration集成协议栈

# 3. 接口设计
# 使用interface-contract-design定义接口契约

# 4. 代码分析
# 使用static-analysis-c-cpp进行静态分析

# 5. 单元测试
# 使用unit-test-embedded编写单元测试

# 6. 集成测试
# 使用integration-hil-sil进行HIL/SIL集成测试

# 7. 验证完成
# 使用verification-before-completion进行完成前验证
```

### 4. 性能优化组合
**场景**：优化系统性能

**技能组合**：
1. `performance-profiling-embedded`：性能分析
2. `systematic-debugging`：系统化调试
3. `fault-injection-recovery`：故障注入与恢复
4. `static-analysis-c-cpp`：静态代码分析
5. `unit-test-embedded`：编写单元测试
6. `verification-before-completion`：完成前验证

**使用流程**：
```bash
# 1. 性能分析
# 使用performance-profiling-embedded进行性能分析

# 2. 问题定位
# 使用systematic-debugging进行系统化调试

# 3. 故障注入
# 使用fault-injection-recovery进行故障注入与恢复

# 4. 代码分析
# 使用static-analysis-c-cpp进行静态分析

# 5. 单元测试
# 使用unit-test-embedded编写单元测试

# 6. 验证完成
# 使用verification-before-completion进行完成前验证
```

### 5. 发布管理组合
**场景**：准备版本发布

**技能组合**：
1. `release-versioning`：版本发布管理
2. `commit-pr-quality-gate`：提交与PR质量门禁
3. `verification-before-completion`：完成前验证

**使用流程**：
```bash
# 1. 版本管理
# 使用release-versioning管理版本发布

# 2. 质量门禁
# 使用commit-pr-quality-gate执行质量门禁

# 3. 验证完成
# 使用verification-before-completion进行完成前验证
```

## 技能组合最佳实践

### 1. 技能选择
- 根据开发意图选择技能
- 优先使用核心技能
- 按需添加可选技能

### 2. 技能顺序
- 需求分析在前
- 实现在中
- 验证在后
- 质量保证贯穿始终

### 3. 技能协作
- 使用标准接口
- 保持数据一致性
- 记录协作日志

### 4. 技能优化
- 定期评估技能效果
- 优化技能组合
- 更新技能版本

## 技能触发词

### 1. 需求分析触发词
- "分析需求"
- "需求分类"
- "优先级排序"
- "接口设计"

### 2. 架构设计触发词
- "架构决策"
- "API设计"
- "协议集成"
- "组件设计"

### 3. 开发实现触发词
- "驱动开发"
- "BSP移植"
- "RTOS设计"
- "中断处理"

### 4. 构建测试触发词
- "交叉编译"
- "静态分析"
- "单元测试"
- "集成测试"

### 5. 质量保证触发词
- "调试"
- "性能分析"
- "故障注入"
- "验证"

### 6. 发布管理触发词
- "版本发布"
- "质量门禁"
- "提交检查"

## 技能组合示例

### 示例1：CAN FD驱动开发
```bash
# 需求分析
使用requirements-triage分析CAN FD驱动需求

# 寄存器设计
使用register-map-design设计CAN FD控制器寄存器映射

# 接口设计
使用interface-contract-design定义CAN FD驱动接口契约

# 驱动开发
使用driver-bringup-checklist执行CAN FD驱动开发检查

# 静态分析
使用static-analysis-c-cpp进行CAN FD驱动代码静态分析

# 单元测试
使用unit-test-embedded编写CAN FD驱动单元测试

# 集成测试
使用integration-hil-sil进行CAN FD驱动HIL/SIL集成测试

# 验证完成
使用verification-before-completion进行CAN FD驱动完成前验证
```

### 示例2：Modbus TCP协议集成
```bash
# 需求分析
使用requirements-triage分析Modbus TCP协议需求

# 协议集成
使用protocol-stack-integration集成Modbus TCP协议栈

# 接口设计
使用interface-contract-design定义Modbus TCP接口契约

# 静态分析
使用static-analysis-c-cpp进行Modbus TCP代码静态分析

# 单元测试
使用unit-test-embedded编写Modbus TCP单元测试

# 集成测试
使用integration-hil-sil进行Modbus TCP HIL/SIL集成测试

# 验证完成
使用verification-before-completion进行Modbus TCP完成前验证
```

### 示例3：系统性能优化
```bash
# 性能分析
使用performance-profiling-embedded进行系统性能分析

# 问题定位
使用systematic-debugging进行性能问题系统化调试

# 故障注入
使用fault-injection-recovery进行性能相关故障注入与恢复

# 静态分析
使用static-analysis-c-cpp进行性能优化代码静态分析

# 单元测试
使用unit-test-embedded编写性能优化单元测试

# 验证完成
使用verification-before-completion进行性能优化完成前验证
```

## 技能组合工具

### 1. 技能选择工具
- 技能推荐引擎
- 技能组合分析
- 技能依赖检查

### 2. 技能执行工具
- 技能执行脚本
- 技能状态跟踪
- 技能结果收集

### 3. 技能评估工具
- 技能效果评估
- 技能组合优化
- 技能版本管理

## 常见问题

### 1. 如何选择技能组合？
根据开发意图和场景需求，参考常见技能组合选择。

### 2. 如何优化技能组合？
定期评估技能效果，根据反馈优化技能组合。

### 3. 如何管理技能版本？
使用技能版本管理工具，定期更新技能版本。

### 4. 如何记录技能使用？
使用技能执行工具记录技能使用情况和结果。

## 附录

### 1. 技能清单
- 列出所有可用技能
- 技能描述和触发词
- 技能使用示例

### 2. 技能组合模板
- 常见技能组合模板
- 技能组合配置文件
- 技能组合执行脚本

### 3. 技能最佳实践
- 技能选择最佳实践
- 技能执行最佳实践
- 技能评估最佳实践