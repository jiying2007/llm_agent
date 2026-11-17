# 整合后的当前验证

2026-11-17，本轮只整理新 intake 材料，保持保护基线 e288e406 的全部既有报告及预算。原失败、旧审核和旧验证保存在 evidence/original-intake 与 evidence/ci-contract-before.json；当前结果另存 local-validation.json。

| 当前实际检查 | 结果 |
|---|---|
| candidate / decision / evidence checker | 全部 exit 0；7 / 7 / 1 条 |
| strict maintainability budgets | exit 0；14 budgets 全通过，warnings=[]、failures=[] |
| root-report-count | 320，warning_limit=320、hard_limit=400；历史 baseline=284 |
| maintenance budget 直接回归 | exit 0 |
| doc sync | exit 0 |
| explicit-base validation planner | L1，documentation/evidence-only |
| candidate / decision semantic comparison | 7个稳定ID、1 ENHANCE/6 OBSERVE，仅 evidence_refs 改路径 |
| 原始8文件 | 与 a522b0d5 对应 Git 原对象逐字节相同 |
| 当前证据引用 / input / ledger digest | 全部实际存在且摘要匹配 |
| 相对 e288e406 的 reports diff | 空；未触碰既有320份报告 |

代码、registry、预算、Gitlink、runtime 和资格不变。源记录与治理证据的 scoped 审查不授予产品权限；本地 full/native/model/M5 未执行，符合该 L1 范围。宿主 Provider / Execution Policy 缺失继续为 UNAVAILABLE/NEEDS_REVIEW。

最终 diff check、独立 delta 审查以及新准确 PR head 的 required CI 均需后续实际核验；本文件不提前声称 merge 或后续 ADK 发行完成。
