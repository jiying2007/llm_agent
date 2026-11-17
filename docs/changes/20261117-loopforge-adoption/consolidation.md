# 本轮来源材料整合与维护预算修正

## 具体失败与选择

PR #347 首次 GitHub head 为 `a522b0d560e4652c162164b41191f517c83f1062`，与本地 `5858daa789ba4fb377d75769c2d26748775c5091` 的 tree 同为 `534ac56e00279b37aea16493d38ff5f15eb4e9a9`。
CI run `44106992674` / contract job `134121912911` 的 strict maintenance-budget 实际失败：
root-report-count=328、warning_limit=320、hard_limit=400；合同历史 baseline=284。
保护基线 `e288e406eb2262f354e36e69ce93b5fb46a70b49` 原有报告数为320，本轮增加8份触发阻断。

既有 `docs/changes/20261023-evidence-methods/review-consolidation-findings.md` 的同类先例允许把一次具体吸收变更材料整合到 change package。
本次仅整理自己新增的8份材料，没有移动、修改或删除既有320份报告，没有变更预算、扫描规则或排除项。

## 原始字节与位置

原 canonical 前缀为 `reports/loopforge-adoption-2026-11-17/`；新 canonical 前缀为 `docs/changes/20261117-loopforge-adoption/`。
原始8份字节全部保留在本包 `evidence/original-intake/`，同时可从上述固定 GitHub commit 原路径回读。
原始 local-validation、verification、owner-review 的时间、命令和结果只描述其当时快照，不能替代当前校验。

| 原文件 | 原 Git blob | 原 SHA-256 |
|---|---|---|
| candidates.jsonl | 254308407d25e27138752090e5a91e969668d7c2 | 660df8d9c07a304507adc1e9a0e761014c277a89a998a0747642a845d85195ce |
| decisions.jsonl | 22fafea118beae8ddcc345a9a6b869722ada0d27 | 2ee3eb9d6ade5ff914f769b215e0f7535f8c5970fa2e997597ebe6601c64b0cd |
| intake-evidence.json | 4124ae23d0bef55ace48c2f59bd433d920e48bdd | 393e61780c5b78565346ba66a06b6d9f73a87a834604b950dc2111a7a4348eac |
| local-validation.json | 2700dd0a25307657428b64629c1e9401666664c7 | 49762a4a1364190b492744fa380589aba249f0862fb80adbb8dfde5cbcbb6444 |
| owner-review.md | 0ba4eeef70ee2fc2f5896e6d93b68bfa14d09c16 | 0acfcf4961f89e698e36354d80037d25c3a868878dbf02848ff6dd9273dbf8bc |
| source-metadata.jsonl | ef4818ebfc15dc95d5fd7b671ec8cb1cccf7bfe8 | 28f4640b9623529eeb094c4bbb36d00ed38deeb775863bf2a3d0b67a8070f26f |
| source-review.md | c844c59b3f5f13bccefbbf045385c5b2b3a3a7d8 | 7e3662824e7ea8f8b6398e3ea2c211af3c135ef9832063260f62ac5594dd9254 |
| verification.md | b6865114f02f1c8d96fbba8183f90797195398c8 | 83fc70657854ab3cb624c901f78c2a8b533494eb1b8878339e6151d0743557c7 |

原 CI 完整日志见 `evidence/ci-contract-before.json` 的 raw_log；旧失败不是通过迁移被改写成 PASS。
首次原文日志打包触发 git diff --check 的真实 trailing-whitespace 拒绝（exit 2）。
现将完整原文用 JSON 字符串承载，解码字节必须与原日志相同；不删空格、不改全局 whitespace 规则。

## Canonical 重建与验收

source metadata 原字节保持；新位置通过既有 practice-intake collect 实际重生 candidate/evidence，
不手工改旧 input_ref、ledger digest 或时间。decision 只改 evidence_refs 位置，保留7个稳定 ID、
真实 delegated owner、1 ENHANCE/6 OBSERVE、日期、rationale 和限制。owner-review 原件继续保留，
后续当前路径校验与独立 delta 复审单独记录。自动 candidate 仍是 review-required，collector 不产生批准。

验收使用原 candidate/decision/evidence check、实际路径存在性、input/ledger 摘要、strict maintenance budget、
其直接回归、L1 doc-sync 和 diff check，以及新 head 的真实 required CI。
预期报告数回到320、warnings/failures为空；当前结果必须实际运行后记录，不能用预期代替通过。

## 边界与回退

不清理旧 active 报告：既有 retention planner 的本次只读结果为180候选、eligible_for_review=0、
scan_incomplete=true，故没有依据选择旧报告退役；planner没有执行移动。
不把研究材料放入 runtime-evidence，不改扩展名隐藏统计。

本变更仅为一次 source intake 的正确承载和引用重建。ADK行为、安全修复、发布及随后Root gitlink晋级
分别验证；provider/host缺失、真实模型效果、native/device/M5资格边界全部保留。
若当前材料整合有误，以受保护后继修订恢复正确路径；原Git对象及历史证据不可覆盖。
