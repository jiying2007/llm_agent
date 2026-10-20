# 任务与实际验证

- [x] 核对当前精确主线、六项 issue、现有资格边界与本地 runtime 可用性。
- [x] 完成 17 项外部一手来源检索与已有能力去重，见 external-methods.md。
- [x] 实现只读六项复核入口及确定性正负测试，包含来源拒绝执行、真实进程预算、脱敏和状态一致性。
- [x] 整合有界低频工作流、摘要和可下载原始结果；相关变更触发，另每日 01:23 UTC 复核。
- [x] 完成三份历史变更 AI Spec/Quality 复核与 Harness 客观证据整理，见 owner-review-packet.md。
- [x] 执行当前来源下的定向、完整回归和真实六项诊断。
- [x] 复核已归档历史 M5 运行原件、下载摘要及真实 Cosign 签名，见 historical-runtime-recheck.md。
- [x] 将新边界测试接入既有 required contract job，并保持受保护 PR、fresh-main 验证和既有资格边界。

## 实际本地验证

2026-10-20，Root 基线 `1badead06b2083d8c41a1854dec5aff74c0d0b42`，锁定 ADK 8.0.34。运行使用真实 RTK、Python 3.12.14；完整回归在真实 POSIX 进程环境中移除 root 的 DAC 绕过能力，以实际验证文件权限负例。

| 检查 | 实际结果 |
| --- | --- |
| 新聚合器与工作流定向回归 | 36/36 PASS，exit 0 |
| Root 严格 mypy 配置范围 | 9 个生产模块 PASS，exit 0 |
| 新生产模块及两份 Python 测试 Ruff | PASS，exit 0 |
| Root 完整回归 | 79/79 PASS，exit 0，387844 ms |
| 锁定 ADK quick 回归 | 56/56 PASS，exit 0，102366 ms |
| `check-all --quick --working-tree` | 47/52 PASS，exit 1；五项既有环境/资格阻塞保留，workspace fingerprint stability PASS |
| 实际六项聚合 | scan complete，source consistent，五个原 checker 实际 exit 2，人工文件库存 exit null；资格和发布授权均 false |
| 历史 M5 原始签名复核 | 原始 ZIP 摘要匹配、已归档 JSON 逐字节相等、工作流/测量/源绑定核对成功，真实 Cosign `Verified OK` / exit 0 |

完整回归前后 16 个受管变更路径的快照均为 `11c1fb6642a2ddbed5b0f1291da4c5c011c5fb071965e6fc2d88b50a4e11b8c8`。测试自有的临时材料经前后文件库存与摘要确认后完整移出源码，源码状态和 ADK 子模块清洁度复原；这些合成文件没有进入真实资格证据。此段本地结果说明在回归结束后补写，最终提交以远端 PR/main 的独立完整验证为准。

五项综合阻塞仍来自实际缺失的全局 Codex 健康/目标策略、运行环境健康、既有 reference triage 和 Software M5 readiness；相关既有实现与当前 HEAD 原始字节一致。本次没有创建全局 Provider 替身、刷新未审查日期或改写真实资格状态。

## 交付后证据

受保护 PR、主线 CI、ADK 后续正式版本提升以及六项既有 issue 的事实更新，由各自原始 PR/run/issue 记录作为权威交付证据；只有实际完成的门禁和操作才记为成功。本变更包不预填未来 CI、现场、Owner 或模型活动的执行结论。
