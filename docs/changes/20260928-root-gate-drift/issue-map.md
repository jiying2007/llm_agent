# 当前入口漂移问题地图

| ID | 级别 | 事实 | 本批动作 |
|---|---|---|---|
| D-01 | major | `docs/runbooks/quality-gate-checklist.md` 曾描述 YAML Manifest、旧 Skill 字段和已删除 profile-coherence 脚本 | 已改为当前 JSON Manifest、frontmatter 与 strict validator 合同 |
| D-02 | major | `scripts/README.md` 曾给出退役的根仓 tool/skill evidence wrapper | 已指向 ADK 实际脚本，定向门禁通过 |
| D-03 | major | ADK 并行试点 task package 的 `must_not_touch` 曾写 `manifest.yaml` | 已改为受保护的现行 `manifest.json`，试点回归通过 |
| D-04 | minor | ADK 当前参考采纳文档曾指向 optional 的规划 Skill 旧路径 | 已改为现行 core Skill 路径 |
| D-05 | blocker | `~/codex` provider lock 仍指向 ADK 7.0.31；现有 Codex 草稿仅覆盖单个 Skill，且沿用旧 provider lock | ADK 7.12.4 main 的签名推广与正式 Release 已验证，根仓 exact gitlink 和证据已导入；仍需按 source-to-live 重新导入、构建、doctor、plan、dry-run、apply 与 check，不复用旧草稿 |
| D-06 | major | full gate 的 harden/performance wrapper 曾调用已删除的 ADK `validate-assets.sh`、`test_product_maturity_v4.sh`，并要求六个按需参考仓在根目录物化 | 已迁到当前入口；新 ADK clean commit 的 harden 96/96、performance ops 和根仓 full gate 同快照复验通过 |
| D-07 | major | workspace entrypoints 曾要求旧 Hermes 候选错误、旧 Runtime Control 脚本和旧 runtime target 摘要字段 | 已按当前 registry/Execution Policy 修正；只读入口回归通过，过期 baseline 仍单列阻断 |
| D-08 | major | full gate evidence bundle 返回 `needs-fix` | 已证实仅 `reference_dirty_triage` 过期导致，按用户决定保持阻断，不降级为 pass |
| D-09 | observation | 首轮 full gate 运行期间修改了测试夹具，同运行 fingerprint 因而失败 | 后续稳定快照 full gate 的 fingerprint 通过；首轮失败不归因于产品内容 |
| D-10 | major | 旧 ADK quick 矩阵逐例启动 CLI，约 54 秒，导致 Python 3.11 quick 总耗时超过 120 秒预算 | ADK 本地 clean commit 已采用单进程完整矩阵 + 一次 CLI smoke；根仓 exact pin 的 full gate performance ops 通过 |

历史归档/分析中对旧路径的描述保留 provenance，不做全局替换。`/tmp` cosign 已完成官方二进制校验，当前 7.12.4 main promotion 签名通过；用户选择保留过期的参考基线、M5 真实证据和 clean source-to-live 仍按独立门禁处理。
