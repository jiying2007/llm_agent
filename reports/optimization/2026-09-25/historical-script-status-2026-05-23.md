# 历史脚本手册状态摘录

归档日期：2026-09-25。下文逐字保留自脚本手册的2026-05-23段落，仅描述历史，不是当前版本、运行环境或资格声明。当前信息读取生成投影，不从本档继承。

### adk 当前状态（2026-05-23）

- 版本锁: `agent-dev-kit.version=2.9.0`
- Pilot readiness: 10/10 ready，planned=0，`device_needs_fix=0`，`device_simulated_pass=1`
- Runtime footprint: ADK required Skill 必须存在，外部兼容 Skill/vendor 路径必须不存在
- Codex 交接: `agent-dev-kit -> ~/codex -> ~/.codex` 只通过 handoff/build/plan/apply 链路进入运行目录
- Runtime boundary: 禁止 adk 绕过 `~/codex` 直接写入 `~/.codex`
- Production-field: 已有模拟设备状态机闭环；真实 production-ready 仍需实机烧录/readback、boot log、HIL/产测、OTA 回滚和现场包证据
- 证据刷新: 当前机器保留 build、doctor、plan、apply dry-run 与 global health 证据；当前状态索引见 `reports/current-status.md`
  `reports/current-status.md` 是最新门禁和证据包引用索引，不是 live refresh 已完成、真实 apply 已执行或 rollback 可用的证明。
