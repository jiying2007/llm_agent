# 两仓 Skill 方法沉淀：设计

## 归属与机制

- `docs/absorption-governance.md` 保持吸收与生产采纳边界，定义长期规则的权限等级并引用七字段记录。
- `docs/llm-agent-maintenance-guide.md` 负责按问题导航；实际验证范围由现有 `tools.codex_assets.validation_plan` 和原门禁决定，不能仅按文件后缀降级。
- `docs/runbooks/evidence-driven-optimization.md` 是 Root 七字段的唯一说明入口；原 decision/change/evidence 承载具体事实，不新增登记表。
- `AGENTS.md` 只增加短导航，ADK 文档按 Root 当前 gitlink 读取。

## 维护与回滚

方法改变时同时复核问题证据、适用边界、资产 owner、验证和退出条件；普通小改不强制填写空模板。已知 CI、来源、签名和消费失败保持真实状态，不用文档同步抬升产品资格。

文档回滚使用受保护 revert；ADK 回退沿既有 promotion/release 规则，不能移动发布标签或手写历史 M5 证据。此文档变更基线为 `761e41b28b93b6b3fb5b8c451870afb0c45e0c5a`，ADK 规范基线为 `0a6bf985de5e2d3523cd4e82cb19d3b8575a4fdb`。
