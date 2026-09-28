# 剩余门禁的审查候选

以下为本地只读观察和待决事项，不是已批准的 baseline、产品采用或发布证据。

## 参考仓 dirty baseline

2026-09-28 从根仓参考仓只读采样：OpenSpec、superpowers、vibeflow 的工作树 fingerprint 与分类均匹配当前基线，`analysis_policy=commit-snapshot-only`；三行 `expires_on=2026-08-31`，因此门禁保持 `baseline-expired`。三仓 dirty 项数分别为 655、115、216。owner 需要确认这些现场状态仍可作为只读观察基线，并决定新的复审截止日；确认前不改 `subrepos/dirty-baseline.tsv`，也不把匹配旧指纹解释为重新批准。

本轮用户明确选择“保持过期阻断”；因此不续期、不修改 baseline，也不生成伪通过报告。以后若重新评估，需以当时现场重新取证。

## Software M5 候选身份

`manifests/software_m5_policy.json` 和 scorecard 仍声明候选 `5.0.0-rc.2`。ADK PR #167 与修复 PR #168 均已合并；当前 root exact pin 为 ADK 7.12.4 main `35b5fb31810c654a295c25b89e04435d6a32f57c`。该 SHA 的 main CI `36423553089`、Sigstore promotion、annotated `v7.12.4` tag 与 GitHub Release 已完成，根仓原子事务已导入并验证匹配的 promotion evidence。历史 7.12.2 签名仍保留 provenance，不能认证当前 SHA。M5 检查保持 fail-closed；不能只替换版本字符串或复用旧资格资料。

本轮用户最初选择“启动 7.12.2 重新评估”；受保护 PR 的版本前进门禁及 main CI 修复最终将可推广源码提升为 7.12.4。这启动本地评估准备与证据收集流程，不代表 M5 资格已迁移。重评实现与门禁见 `docs/changes/20260928-m5-7122-reevaluation/`。

已有 `software_m5_rollover` 的事务测试覆盖新版本合格证据的正例和回滚边界；当前根仓没有 7.12.4 的真实 measured Codex runtime-smoke 文件，只有历史 v5 文件。测试夹具不能代替真实运行证据，也不能直接调用 `--apply` 使 M5 通过。

## 签名校验环境

官方 cosign v3.1.3 已按发布 checksum 固定在 `/tmp` 隔离目录。当前 7.12.4 evidence 的 source/lock/interface 静态声明与原始 `check-adk-promotion-evidence` Sigstore 验证均通过，返回 `Verified OK`；这证明源码推广身份，不代替 Codex 运行测量或 M5 产品资格。

参考仓 baseline 和 M5 真实证据仍按独立门禁处理；发布与运行资产采用还要求 root fresh integration、clean commit 及各自 owner 证据。
