# 设计

本轮只复用 `docs/runbooks/goal-loop-token-efficiency.md`、`docs/runbooks/runtime-target-activation.md` 和已有控制面 CLI，不新增执行引擎、宿主拦截服务或模型开销。

SDD 由已固定的 ADK `feature-delivery` 与 Canonical Change Contract 承担，Root 只做消费导航。Host 如果尚未接入，事件预检仍是建议而不是真实请求跳过。旧 `codex.lock` 保留历史取证身份，Root 的 ADK 当前源仅取 Gitlink。
