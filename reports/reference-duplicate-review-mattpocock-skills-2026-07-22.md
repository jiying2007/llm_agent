# mattpocock/skills 重复性与边界复核（2026-07-22）

## 结论

`mattpocock-skills` 与现有 active reference 有能力重叠，但不存在身份、目标路径或治理职责重复，批准作为独立长期参考子仓。

## 对比

| 现有资产 | 主要职责 | 与 mattpocock/skills 的关系 | 处理 |
|---|---|---|---|
| `superpowers` | 自动化工程流程主干、设计/执行/review 闭环 | 部分覆盖需求、测试和 review，但控制权与组合模型不同 | 并存；不让 mattpocock 取代流程主干 |
| `OpenSpec` | spec 工件和变更生命周期 | 与 `to-spec/to-tickets` 有表面重叠 | 并存；OpenSpec 保持 spec SSOT，mattpocock 仅作为方法参考 |
| `planning-with-files` | 文件化长任务、恢复和上下文连续性 | 与 handoff/wayfinder 有局部重叠 | 并存；分别观察恢复合同与轻量任务导航 |
| `oh-my-codex` | Codex 运行层治理参考 | 与跨 harness skill 发现存在邻接 | 并存；禁止启用两者 runtime/plugin |
| ADK 原生 skills | 本地运行资产和治理 SSOT | 已吸收部分 mattpocock 方法 | 不建立运行时依赖；新增吸收继续独立审批 |

## 唯一性检查

- canonical repository identity 唯一：`mattpocock/skills`。
- registry 已有且仅有一个历史行，允许原位 reactivation，禁止追加重复行或新建别名。
- lifecycle 已有且仅有一个 `watch` 条目，允许原位切换为 `active-reference`。
- `.gitmodules` 尚无 `mattpocock-skills`，目标路径不存在。
- 新增 adoption matrix 记录表达的是“长期参考仓重新激活”，不改写既有 method-only 吸收和拒绝安装记录。

## 非目标

- 不恢复历史上被拒绝的全量安装或 plugin 启用。
- 不因成为 active reference 就把所有新增 skill 判定为高价值。
- 不合并进 `superpowers`、`OpenSpec` 或 ADK 源目录。
