# llm_agent 与 global-dev-kit v2.0.0 不匹配分析

> 时间: 2026-05-05
> 结论: llm_agent 父仓库有 6 处需要同步更新

---

## 不匹配清单

### 1. [高] llm_agent/scripts/enhanced-gate-check.sh 仍存在

gdk 中已删除此文件（与 quality-gate-check.sh 完全重复），但 llm_agent/scripts/ 仍有独立副本。
影响: 两层脚本不一致，维护困惑。

修复: 删除 llm_agent/scripts/enhanced-gate-check.sh

### 2. [高] llm_agent/AGENTS.md 中 gdk 描述过时

第 66 行写 gdk 短板是"与外部生态桥接不足"，但 v2.0.0 已补齐:
- 意图路由（routing 表 + skill_match.sh）
- 模板体系（18 个模板全部填充）
- Profile 推荐指南
- 8 个运维命令接入 devkit.sh

修复: 更新 AGENTS.md 中 gdk 基线定位描述

### 3. [中] subrepos/phase-gate.env 仍标记 v1-frozen

```
note=v1-frozen-follow-up-tracking-enabled
```

gdk 已是 v2.0.0，门禁状态应更新。

修复: 更新 phase-gate.env note 字段

### 4. [中] scripts/README.md 未反映 gdk v2.0.0 新命令

README.md 只描述了旧的 check-gdk-harden-readiness 流程，未提及 gdk v2.0.0 的:
- 22 条 routing 覆盖
- 97 个测试
- 8 个运维命令
- ~/.codex 真实安装验证

修复: 在 README.md 中补充 gdk v2.0.0 状态摘要

### 5. [低] reports/ 中引用 v1.0.0 的报告未标注已过期

- reports/gdk-v1-freeze-signoff-2026-05-02.md
- reports/full-subrepo-analysis-2026-05-05.md

修复: 在报告顶部加注"已由 v2.0.0 替代"

### 6. [低] check-global-codex-health.sh 依赖 ~/.codex/control/scripts/doctor.sh

此脚本检查 codex 的 doctor.sh，但当前 ~/.codex 是 gdk 安装的（无 doctor.sh）。
影响: 此门禁脚本在当前环境下会失败。

修复: 标注此脚本适用于有 codex control 层的环境

---

## 修复优先级

| 优先级 | 项 | 耗时 |
|--------|------|------|
| P0 | 删除 llm_agent/scripts/enhanced-gate-check.sh | 1min |
| P0 | 更新 AGENTS.md gdk 描述 | 5min |
| P1 | 更新 phase-gate.env | 1min |
| P1 | 更新 scripts/README.md | 5min |
| P2 | 报告标注过期 | 2min |
| P2 | 标注 doctor.sh 依赖 | 2min |

总计约 15min。
