# Root 活跃入口漂移与旧写入路径退役
日期：2026-11-18。范围：仅 Root 活跃脚本、操作文档和最小回归，不改 ADK/Codex gitlink，不改产品资格。

## 已复现的问题
- Root 不存在 `manifest.yaml`，旧 `scripts/version-manager.sh` 却以它为源并额外写 `.version-lock`；与 Gitlink 和忽略缓存 `adk.lock` 体系矛盾。
- 旧 `scripts/backup-rollback.sh` 面向任意目标恢复，会删除目标目录，文档示例指向 `~/.codex`，绕过 `~/codex` 的审批/计划/回滚链。
- 活跃部署说明仍调用上述路径；质量门禁手册把 `codex-home` 误称 `codex`，列入未声明的 runtime kind 和不存在的 health-adapter manifest。

## 验收
- 删除两条旧执行路径，活跃入口改为精确 ADK 源码消费与 `~/codex` 的审查链。
- 保留历史记录、Gitlink、资格状态和现有 CI 门禁；新增最小负例防回流。
- 在准确的 Root PR head 通过原合同/文档/集成检查，合并后核验 main 与签名回执；未通过则不得声明完成。
