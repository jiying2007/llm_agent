# VibeFlow 深度分析与吸收报告

**生成时间**: 2026-05-12
**源仓库**: https://github.com/ttttstc/vibeflow
**目标仓库**: agent-dev-kit (adk)

---

## 1. VibeFlow 概述

### 1.1 定位
VibeFlow 是一个 **repo-local control plane for AI software delivery**，不是另一个 agent runtime。

核心理念：
> "VibeFlow 不替智能体思考，也不试图再造一个执行内核。它做的事情更直接：把一次 AI 驱动的软件改动组织成一条能真正走完的交付流程。"

### 1.2 8 阶段生命周期

```
Spark → Design → Tasks → Build → Review → Test → Ship → Reflect
```

- **Spark**: 需求澄清与价值验证
- **Design**: 技术方案设计与三维评审
- **Tasks**: 合同化任务拆解
- **Build**: TDD 驱动开发
- **Review**: 多视角代码审查
- **Test**: 系统测试与 QA
- **Ship**: 发布与部署
- **Reflect**: 复盘与知识沉淀

### 1.3 核心设计原则

1. **只把 100% 可机械化的东西写成脚本**
2. **只把必须稳定复现的东西固化成状态机**
3. **只把经常忘、忘了就出事的东西做成 gate**
4. **其他尽量留给 agent runtime + skill 提示词 + 项目产物**

---

## 2. 可吸收的高价值模式

### 2.1 P0 立即吸收

#### 模式 1: 8 阶段生命周期框架

**来源**: ARCHITECTURE.md, VIBEFLOW-DESIGN.md

**价值**: 
- 比 adk 当前的"分析→吸收→压实→验证"更完整
- 增加了 Spark（需求澄清）和 Reflect（复盘）两个关键阶段
- 每个阶段有明确的输入/输出/门禁

**adk 落地建议**:
```yaml
# 在 AGENTS.md 中增加生命周期定义
lifecycle:
  - spark: 需求澄清与价值验证
  - design: 技术方案设计
  - tasks: 任务拆解与合同化
  - build: TDD 驱动开发
  - review: 多视角审查
  - test: 系统测试
  - ship: 发布部署
  - reflect: 复盘沉淀
```

#### 模式 2: 状态机与恢复点

**来源**: .vibeflow/state.json, ARCHITECTURE.md

**价值**:
- 工作流状态持久化到文件
- 支持中断恢复和跨会话交接
- 状态转换有明确的前置条件

**adk 落地建议**:
```json
// .adk/state.json
{
  "phase": "build",
  "feature": "login-module",
  "artifacts": {
    "design": "docs/changes/login/design.md",
    "tasks": "docs/changes/login/tasks.md"
  },
  "gates_passed": ["spark", "design"],
  "created_at": "2026-05-12T10:00:00Z"
}
```

#### 模式 3: Gate 机制设计原则

**来源**: vision.md

**价值**:
- Gate 只拦截"经常忘、忘了就出事"的事情
- 不接管执行，只防错
- 明确的 gate 选择标准（4 个问题）

**adk 落地建议**:
```markdown
## Gate 选择标准

新增 gate 前，必须回答：
1. 这件事是不是 100% 可机械化？
2. 这件事是不是必须稳定复现？
3. 这件事是不是经常忘，而且忘了会出事？
4. 这件事能不能更自然地由 agent runtime、skill 提示词或项目产物来承担？

前三个问题都答"是"，才做 gate。
```

### 2.2 P1 中期吸收

#### 模式 4: 合同化 Tasks

**来源**: skills/vibeflow-tasks/

**价值**:
- 每个 task 有明确的输入/输出/验收标准
- 任务边界清晰，可独立验证
- 支持任务状态追踪

#### 模式 5: 三维评审机制

**来源**: skills/vibeflow-plan-value-review/, vibeflow-plan-eng-review/, vibeflow-plan-design-review/

**价值**:
- 价值评审：这个功能值得做吗？
- 工程评审：技术方案可行吗？
- 设计评审：用户体验合理吗？

#### 模式 6: TDD 集成

**来源**: skills/vibeflow-tdd/

**价值**:
- 测试先行，红-绿-重构
- 测试作为验收证据
- 自动化测试门禁

#### 模式 7: Rules 目录结构

**来源**: rules/00-global.md, rules/coding/

**价值**:
- 规则分层：全局规则 → 语言规则 → 项目规则
- 规则可版本化、可 review
- 避免 CLAUDE.md 的全局污染问题

### 2.3 P2 长期吸收

#### 模式 8: Router 模式

**来源**: skills/vibeflow-router/

**价值**:
- 自动检测当前阶段
- 智能路由到对应 skill
- 减少用户手动选择

#### 模式 9: 复盘机制

**来源**: skills/vibeflow-reflect/

**价值**:
- 每次交付后自动复盘
- 沉淀经验教训
- 持续改进流程

---

## 3. 与 adk 现有模式的对比

| 维度 | adk 现状 | VibeFlow | 差距分析 |
|------|----------|----------|----------|
| 生命周期 | 4 阶段（分析→吸收→压实→验证） | 8 阶段（Spark→Reflect） | adk 缺少需求澄清和复盘阶段 |
| 状态管理 | 无持久化状态 | .vibeflow/state.json | adk 无法中断恢复 |
| Gate 机制 | check-all.sh 门禁 | 精细化 gate 选择 | adk gate 过于粗粒度 |
| 任务管理 | 无合同化 tasks | tasks.md + feature-list.json | adk 任务边界模糊 |
| 评审机制 | 单一 review | 三维评审（价值/工程/设计） | adk 评审视角单一 |
| TDD 集成 | 可选 | 强制 TDD 流程 | adk TDD 不是默认 |
| 规则管理 | AGENTS.md 单文件 | rules/ 分层目录 | adk 规则难以维护 |
| 复盘机制 | 无 | reflect skill | adk 无法沉淀经验 |

---

## 4. 吸收执行计划

### 4.1 Phase 1: 立即执行（本周）

1. ✅ 在 registry.csv 中注册 vibeflow
2. ✅ 在 AGENTS.md 中添加 vibeflow 条目
3. ⬜ 更新 adoption-matrix.md，记录 vibeflow 优点
4. ⬜ 在 adk 中创建 lifecycle 定义（8 阶段）
5. ⬜ 在 adk 中创建 state.json 规范

### 4.2 Phase 2: 中期落地（2 周内）

1. ⬜ 创建 adk/tasks.md 模板
2. ⬜ 创建 adk/gates/ 目录和 gate 选择标准
3. ⬜ 创建 adk/rules/ 分层规则目录
4. ⬜ 集成三维评审机制

### 4.3 Phase 3: 长期演进（1 个月内）

1. ⬜ 实现 router 自动阶段检测
2. ⬜ 实现 reflect 复盘机制
3. ⬜ 完整 TDD 流程集成

---

## 5. 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| VibeFlow 仅支持 Claude Code/Codex/OpenCode | 平台依赖 | 抽象通用接口，不绑定特定平台 |
| 8 阶段可能过于复杂 | 执行成本高 | 支持快速模式（跳过非必要阶段）|
| 状态机增加维护负担 | 长期成本 | 只在复杂 feature 中启用 |
| Rules 分层增加学习成本 | 上手难度 | 提供默认规则模板 |

---

## 6. 结论

VibeFlow 是一个高质量的 AI 交付编排框架，其核心价值在于：

1. **明确的生命周期定义**（8 阶段）
2. **状态持久化与恢复能力**
3. **精细化的 gate 机制**
4. **合同化的任务管理**
5. **多维度评审体系**

建议 adk 优先吸收 P0 模式（生命周期、状态机、gate 机制），中期吸收 P1 模式（tasks、评审、TDD），长期吸收 P2 模式（router、reflect）。

---

*报告生成于 2026-05-12*
