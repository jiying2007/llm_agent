# github/spec-kit 重复性复核

## 结论

`github/spec-kit` 与现有 workflow-core 高度重叠，但不存在 repository identity、目标路径或长期观察职责重复。批准独立登记为 `spec-kit`，前提是只跟踪其 integration/distribution/workflow-engine 增量，不重复吸收通用 SDD 模板。

## 已有覆盖

| 现有资产 | 已覆盖能力 | 与 Spec Kit 的关系 |
|---|---|---|
| `OpenSpec` | Spec 工件、change 状态、canonical resolution | 覆盖变更工件 SSOT，不覆盖多 Agent 安装生命周期 |
| `superpowers` | brainstorm、planning、verification、review | 覆盖开发流程主干，不覆盖 catalog/bundle/integration manifest |
| `vibeflow` | SDD + Harness 生命周期、恢复点、gate | 覆盖阶段编排，不覆盖跨 30+ target 的 managed-file 生命周期 |
| ADK spec-chain | requirements → design → tasks → verify | 覆盖本地工件和门禁，不需要复制 Spec Kit 模板 |
| ADK Skill/target contracts | Skill 安全、维护、target watch | 可消费 Spec Kit target 变化，但当前没有其 catalog/bundle 参考实现 |

## 独有观察面

1. integration registry 与 target-local subclass；
2. managed-file SHA-256、修改保护和卸载语义；
3. multi-install safe 判定；
4. catalog stack、discovery-only/install-allowed；
5. extension/preset/bundle 解析、冲突和引用计数；
6. workflow engine 的 malformed input、redirect 和 step fail-closed；
7. Codex/Copilot Skills 模式演化。

## 身份与路径冲突

- `subrepos/registry.csv` 当前没有 `spec-kit`。
- `.gitmodules` 当前没有 `spec-kit`。
- 根目标路径 `spec-kit/` 当前不存在。
- 历史微信条目中的 `REJECT` / `REFERENCE_ONLY` 是二级文章级决定，不是 v1 repository candidate + owner decision，不能视为同一受治理仓库记录。
- canonical repository `github/spec-kit` 与 `OpenSpec`、`superpowers`、`vibeflow` 的 full name 和 remote 均不同。

## 去重门禁

- 不复制上游命令和模板。
- adoption matrix 的能力描述必须限定为“长期观察增量”，不能写成“Spec 主流程已整体吸收”。
- 后续每个吸收项必须说明相对 OpenSpec、superpowers、vibeflow、ADK spec-chain 的独有差异。
- 仅新增 Agent、stars、文档润色和 community catalog 条目默认判为噪声。
