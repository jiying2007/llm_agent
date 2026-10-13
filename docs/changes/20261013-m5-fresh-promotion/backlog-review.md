# 2026-10-13 优化 backlog 有界复审

review_scope: 软件实现路径与真实资格边界；不是 22 项 terminal outcomes 重新认证。
source_snapshot: root base `5cc46b132d1fe08efe35a1e2f4fa4d3b865aadae`，candidate ADK `8.0.6 / 97cf0167e837c2095d9ec6a9431f5aa8c20a812b`。
review_window: 2026-10-13 至 2026-10-27；保持原 freshness 拒绝规则。

首次当前时钟 active_contracts 唯一 failure 为 review_after=2026-10-12 到期。以原截止日显式执行结构核验 PASS，只证明原窗口结构有效，不伪称今天 fresh PASS。实际逐项检查全部 implementation_evidence 路径，没有缺失。额外实际执行 architecture、current-status、product-maturity、status-projection 回归，通过；严格 native/effect 资格命令均按预期 exit2 拒绝。首轮 independent whole-diff 发现 current 资格误标，已修实现并完成定向回归，最终扩展审查与全回归另记。

| 条目 | 决策 | 本次证据与限制 |
| --- | --- | --- |
| G1 | 保留软件实现 | architecture/status 结构核验；不继承历史资格 |
| G2 | 保留软件实现 | practice/reference 既有实现路径；首轮 intake 测试 PASS，未重新操作 Provider |
| G3 | 保留软件实现 | 原子导入、真实验签及保留失败回执；完整 gate 待最终验证 |
| G4 | 保留软件实现 | exact ADK manifest/CLI；完整 ADK parity 待最终回执 |
| G5 | 保留软件实现 | quality/历史 benchmark 存在；未新增真实性能测量 |
| G6 | 保留软件实现 | registry/status 投影一致性核验 |
| G7 | 保留软件实现 | runtime registry/intake 实现路径；不启用新 runtime |
| G8 | 保留软件实现 | commands/devkit 实现路径；模板验证由 parity 覆盖 |
| G9 | 保留既有证据 | handoff/历史 Provider 与 owner 记录存在；本次未宣称新的 owner decision |
| G10 | 保留软件实现 | installation/release 实现存在，ADK 新发布实际验签；不宣称 live rollback 已做 |
| G11 | 更新复审窗口 | 本次 architecture/status checks，原到期拒绝保留 |
| G12 | 保留预算规则 | budget 实现与既有边界不放宽；最终 quick gate 再核 |
| G13 | 保留软件实现 | Docker 支持矩阵实际运行，结果由最终验证回执确认 |
| G14 | 修复后保留软件实现 | historical current 资格误标已修；实际字段未认证、strict certification 拒绝；不声称当前 runtime/field 已合格 |
| G15 | 保留既有证据 | CODEOWNERS/recovery/runbook 路径存在；未重新认证远端 owner 资格 |
| G16 | 更新来源复审证据 | ADK docs/changes/official-source-refresh-20261013/source-review.md 与 verify-report.md；PR184/main签名promotion/immutable8.0.6真实已核 |
| G17 | 保留软件实现 | matcher/IR 实现与协议存在；完整 parity 覆盖确定性回归 |
| G18 | 保留软件实现 | core/embedded manifest 及 profile contract；不做新 native 资格声明 |
| G19 | 保留软件实现 | workflow/execution policy 实现与完整 parity 证据分层 |
| G20 | 保留软件实现 | evidence graph/trace contracts；不存 raw session/日志/凭据 |
| G21 | 保持 blocked | 实际 native_verified=false，trust disabled、receipt0；strict require-native exit2 |
| G22 | 保持 blocked | 实际 measurement not-measured、coverage0/86、owner decision0；strict require-evidence exit2 |

已有 done 仅表示既有软件实现；该复审不为未执行的每条 verification 命令写 fresh PASS。源代码、确定性测试、真实模型、签名、field 与 owner 分别核验。续期依据是本次逐项源码/证据路径及真实边界审查，不更新任何历史资格日期。
