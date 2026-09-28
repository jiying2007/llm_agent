# 当前检查结果与交接

## 已通过

- 2026-09-28：`rtk scripts/check-all.sh --quick --working-tree` 完整复测为 49/52；较本批开始的 38/52 多 11 项通过。
- `rtk bash tests/test_validation_plan.sh` 17 项、四个新增边界测试各 1 项通过。
- `rtk bash scripts/check-adoption-evidence-integrity.sh .` 检查 206 行、603 个路径通过；结构化矩阵同步、外部实践检查、参考仓移除计划、资产清单和文件模式检查通过。
- 参考来源完整性检查使用本机 Python 3.8 与带本地 PyYAML 的 Python 3.11 定向通过；这不代表根仓整体支持 Python 3.8。
- 更新 ADK pin 前：固定子仓 Python 3.8 quick 49/49；`/tmp` Python 3.11 venv 的根仓全套 69/69；官方 cosign v3.1.3 二进制与发布 checksum 一致，历史 c8 promotion 返回 `Verified OK`。旧 clean ADK 隔离 clone harden 全套 92/92；workspace entrypoints 现行合同检查通过。
- 当前 ADK 7.12.4 main `35b5fb31810c654a295c25b89e04435d6a32f57c` 在普通隔离 clone 全套 96/96、GitHub main Python 3.8/3.11/3.12 回归和 promotion-evidence job 通过。根仓原子事务已同步 exact gitlink、`adk.lock`、interface lock、状态页和新签名材料；原始 `check-adk-promotion-evidence` 返回 `Verified OK`。
- 当前 7.12.4 main + 新签名证据的 `check-all --full --working-tree` 同快照为 55/58，工作树指纹稳定；ADK harden、performance ops、原始 promotion 签名、root regression 和 workspace entrypoints 均通过。三项失败是参考仓 baseline、Software M5 readiness 与衍生的 evidence bundle。根仓 rollover 测试夹具在 `/tmp` 内模拟 promotion；该夹具不代替真实运行测量。
- full gate 首轮 50/58 含运行期间工作树变化，以及后续已修复的旧入口；performance wrapper 的旧 ADK pin quick 49/49 但 165727 ms 超现行 120000 ms 门槛。新 ADK 的 quick 性能预算现已在 full gate 中通过。
- 历史 7.12.2 签名材料保留 provenance。7.12.3 main CI 因固定日期 Agent Value 测试跨过 30 天窗口失败，自动 promotion 跳过；修复 PR #168 仅固定测试 `as_of`，生产 freshness 拒绝保留。当前 7.12.4 main CI run `36423553089` 和 Sigstore 签名通过，annotated tag `v7.12.4` 指向 exact main；GitHub Release tarball SHA256 `cc6f21f6fba7b1976f934c2c09f670ec13643450b28df78e7e2ddf5a8f90a4a1` 与 promotion evidence 一致。
- 当前 status projection 为 `source-current-evidence-historical`、`release_authorized=false`；ADK gitlink 与 lock SHA 一致，但上次验证基线不是当前源码的 fresh baseline。`status=pass` 只表示投影计算成功，不代表发布放行。

## 剩余阻断与已澄清边界

1. `check-reference-dirty-triage`：OpenSpec、superpowers、vibeflow 的 baseline 均于 2026-08-31 过期。2026-09-28 只读采样中三者 fingerprint 与分类均匹配旧基线，但状态仍是 `baseline-expired`；用户决定保持阻断，不自动延长。
2. `check-software-m5-readiness`：签名 promotion 已就绪，但 policy/scorecard 仍指向历史候选，且没有当前 SHA 的真实 measured Codex smoke 与 owner 资格证据；不能因源码签名而放行。
3. `check-evidence-bundle`：因参考仓 baseline 过期返回 `needs-fix`，属于第 1 项的派生阻断。

用户最初选择启动 7.12.2 重评；受保护 PR 版本门禁与 main CI 修复最终使当前可推广源码为 7.12.4。本地 collector 已为当前 ADK 预算接口做好 fail-closed 适配，签名证据已验证，但真实 Codex 测量与资格尚未齐备。准备证据见 `docs/changes/20260928-m5-7122-reevaluation/verification.md`，当前 M5 仍 blocked。

根仓 `codex` gitlink 不是待清理的无授权目录。`manifests/gitlinks.json` 明确声明它是必需的冻结证据依赖，`codex.lock` 与索引均绑定 `d12e782b46430d6bfc828f24a41f94f871a7a19a`，`--pin-only` 通过。隔离工作树的子仓未初始化；working-tree quick gate 只做 pin 核验，release-clean 仍需完整对象和 blob 验证。`~/codex` 作为独立运行资产仓，不由根仓 gitlink 充当 runtime source。

根仓完整 `tests/run_all.sh` 需要 Python 3.11 和 root/ADK 依赖；隔离 `/tmp` venv 已补齐，更新 ADK pin 前得到 69/69，7.12.3 pin 的 root regression 曾在 full gate 同快照通过。ADK PR https://github.com/jiying2007/agent-dev-kit/pull/167 与修复 PR https://github.com/jiying2007/agent-dev-kit/pull/168 均已合并；根仓本地候选现绑定 7.12.4 exact main 与签名证据，尚无根仓推送或 Codex live 应用。
