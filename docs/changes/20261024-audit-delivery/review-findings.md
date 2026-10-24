# Root ADK 8.0.40 接入独立审查

审核人：`ai/root/adk_code_audit`

实际审核完成时间：`2026-10-24T17:29:26Z`

最后证据绑定时间：`2026-10-24T17:28:21.976213+00:00`

## 结论与范围

**Spec：PASS；Quality：PASS；未发现本轮范围内的阻塞缺陷。** 新鲜 Root 全量回归单独记录为 **79/79 PASS**。受保护候选 PR CI 与合并后实际 main CI 仍是后续独立门禁；本报告没有提前认定它们通过，也不授予产品或现场运行资格。

审查对象是 Root 从规划提交 `33878cc1dac2faa28a32f4899afa7e0397fe1d0f` 到真实远端源码提交 `4de6364d18d65d3ae43364dc4625a0c2c4be3bb6` 的六路径推广；候选 tree 为 `e1b213fe444c5d5cdeeac1381b3a05f6a56762f9`。主线基线为 `9c5dd7840548a36dd78969e5fd7dbd208cf78a21`。原 requirements、design、tasks 在推广前后逐字节一致。完整原始 patch 为 `six-path-promotion.patch`，26331 字节，SHA-256 `474a166f9f082fc2474bb514b5c807a34d680f975ee2f9901d39d8df331b37f8`。

审核人没有编写 Root 本轮推广实现或规划，但编写过 ADK F1。因此本结论仅覆盖 Root 接入事务及其证据消费，不冒充 ADK F1 的独立语义复审。上游 ADK 发布实测原件来自 `ai/root/release_governance_audit`。

## Spec 核对

- 差异精确为 `agent-dev-kit`、`adk.lock`、`manifests/adk_interface.lock.json`、`reports/current-status.md` 与两份原始 promotion 文件。五个文件的 Git blob、原始字节 SHA-256 和 gitlink 身份均记录于 `source-binding.json`；源码与索引保持 clean。
- 独立 GitHub GET 确认实际 ADK main 为 `80ba8954c7d9f6225a2c5a4a2f0d805e8eb157c4`，tree `cda8f8223beb236bebb08df17908168a883fad90`、manifest blob `6cfa5195870bfec04ca5f298661c8fa531d649c8`、版本 8.0.40。main CI `40114372768` 的九项 job 均成功，全部绑定同一 SHA。
- annotated tag `v8.0.40` 对象 `360645efabf9ca1778c540812478437abc3ee7cf` 指向同一 commit；正式 Release `422869029` 为 immutable、非 draft、非 prerelease，发布运行 `40114884700` 成功。原始 GET 响应保存在 `github-observations.json`。
- 原 main CI artifact ZIP 的 API digest 与本地原始 ZIP 一致。ZIP 内 evidence、attestation 与 Root 当前文件、Git commit blob、原提取输入逐字节相同；ZIP release contract 与官方下载一致。正式三资产的实际大小、SHA-256 均对应 API，且三份官方下载与精确 main 的既有干净重建逐字节相同。归档 SHA-256 为 `b5e6220337bc34d326bfaa781a23cf144e1689be8c65d997cda3caac539f9196`，也等于已签 evidence 内的归档摘要。
- manifest 的原始文件 SHA 与规范化 manifest SHA 分别记录，使用现有 canonical owner 校核，未混淆两类摘要。上游 8.0.39 → 8.0.40 → 回滚 8.0.39 演练原件为 PASS，39 项资产恢复；其文件 SHA `d1b2ba155519329ab958851466b92dcedd50bdb272e6535edceb1f6f1824a830` 与内部 report 摘要分别保存。
- canonical dry-run 先于 apply；二者原回执内容摘要有效，绑定冻结规划 HEAD/tree、候选身份与最终字节。apply 精确暂存六路径；原始 `applied-not-verified`、`requires_fresh_cross_repo_verification=true`、`release_authorized=false` 保持不变。之后的验证成果单独记录。

## Quality 核对与实际检查

本次只有来源身份和签名证据替换；interface 的 surfaces、deprecated surfaces、maturity contract 未改变。current-status 除五行当前来源投影外逐字节一致。既有产品、Native、G22、LTA、field 与 Product M5 限制未被 source/test PASS 提升，预算阈值、保护规则、签名 issuer/identity 与 CI 门禁未修改。

审读现有 canonical promotion owner 后，定向运行原事务测试，实际覆盖重复键、非有限值、超大 JSON、符号链接拒绝、精确六路径暂存及失败回滚。原测试没有修改。测试中 Git 的嵌套仓库提示保留在 stderr，exit 0；未把它作为源缺陷或删除原输出。

| 实际独立检查 | 唯一记录 label | 结果 |
|---|---|---|
| validation plan（六路径、L4） | root8040-review-validation-plan-4de | PASS |
| 完整锁文件 / gitlink / worktree 校验 | root8040-review-pin-4de | PASS |
| require-worktree interface | root8040-review-interface-4de | PASS |
| current-status 一致性 | root8040-review-status-4de | PASS |
| 原 promotion 事务和回滚测试 | root8040-review-promotion-transaction-4de | PASS |
| 实际消费方 Sigstore 验证 | root8040-review-signature-4de | PASS，stderr 为 Verified OK |

Cosign 可执行文件 SHA-256 为 `4629c757b7618056f8ddd7e2625ae9fdd94c0372a65049520bc7d9df9efc7f71`，mode 0755。真实调用使用既有固定证书 identity `https://github.com/jiying2007/agent-dev-kit/.github/workflows/ci.yml@refs/heads/main` 与 issuer `https://token.actions.githubusercontent.com`。该检查为本审核人实际重验；不以 JSON 声明或签名形状代替验签，也不声称 Git commit/tag 本身有 GPG 签名。

## 独立全量门禁

全新隔离 clone 对齐 Root `4de6364…` 与 ADK `80ba8954…`，由 UID/GID 65534 执行原 `bash tests/run_all.sh --fail-fast --timing-json …`，在真实 /proc 环境下运行。Python 3.12.14、PyYAML 6.0.3、jsonschema 4.26.0。未修改生产、测试、断言或超时；已知固定 /tmp 输出由 nobody 所有，本轮未移动或删除它们。

执行区间：`2026-10-24T17:20:21.095768+00:00` 至 `2026-10-24T17:25:16.996707+00:00`，记录器耗时 295.901 秒，suite 内计时 295599 ms。原套件 **79 pass / 0 fail，exit 0**，前后源码快照一致。唯一 label 为 `root8040-independent-full-4de6364d-172005`；记录、stdout、stderr 原件及逐测试 timing 的路径、长度、摘要均保存在 binding 中。timing 原字节副本 `fresh-full-timing.json` 的 SHA-256 为 `560c6ca4eeb1123b622b31bab70d3a7581c34e06c5c1e95174e70fbbfa77fae8`。

## 限制与后续条件

本轮未重跑已冻结的 ADK 全量或扩大 ADK 语义审核。既有上游 12 份发布执行原件及其 stdout/stderr 摘要已核对，明确保留其独立执行者。Root validation plan 的实际记录时间晚于并行 full 启动、早于专项检查，原时间戳未倒填。

隔离环境没有 canonical Knowledge Provider 与 Execution Policy，相关 host live 门禁为 not-run；这不说明用户真实主机故障。本审核没有执行真实 Native runtime、付费模型调用或现场资格验收。受保护候选 PR CI 和合并后实际 main CI 必须由交付负责人按最终真实 SHA 另行完成；本报告不替代这些门禁。
