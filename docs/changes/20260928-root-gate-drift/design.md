# 设计

根仓 shell 检查读取 `agent-dev-kit/manifest.json`，技能条目由 `jq` 枚举；运行路由先核关键 profile、Skill、路由矩阵和 runbook，再调用 ADK strict validator。参考仓排除集与当前 registry 中已启用的本地参考目录保持一致。M5 不再接受被移除的 `--allow-not-ready` 参数。

根仓 `codex` gitlink 是 `manifests/gitlinks.json` 声明的 `frozen-evidence-dependency`，须与 `codex.lock` 保持一致；独立 `~/codex` 才是 source-to-live 的声明式运行资产仓。working-tree quick gate 对未初始化的冻结证据子仓只执行 `--pin-only`，release-clean 保留完整子仓对象和 blob 验证。运行目标检查继续阻止根仓 `codex/` 成为 runtime source 或 live root。

此批只修复可证实的调用契约漂移；签名工具、参考仓过期基线、M5 证据身份和 owner 决策留在各自门禁处理。
