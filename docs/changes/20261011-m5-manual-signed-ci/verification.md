# M5 受信手动完整 CI 验证

verified_at: 2026-10-11
software_m5_certified: false
release_authorized: false

六组定向Python3.11 unittest，ResourceWarningerror：93/93，exit0；workflow action compatibility exit0。测试覆盖manual签名force真值、缺失/错误类型、错误事件/分支、skipped integration提前拒绝且不调用verifier；producer仍要求全success、main/canonicalworkflow/run绑定。原push成功与全部runtime/field硬化回归保留。

独立只读增量复审：Spec PASS、Quality PASS，无blocker/major；独立test_m5_consumer_hardening 23/23 PASS，Python3.11与ResourceWarningerror。未独立重跑全部93项；签名边界mock不替真实回执。

真实负结果：main CI38147680682成功，但integration-deep与software-m5-ci-receipt均SKIPPED，所以没有该基线签名rootCI。新入口尚未在真实GitHub上运行，不把本地签名mock当真实Cosign或CI。此处保留故障原因与后续独立审查/远端结果的分别验收。

变更仅ci.yml、rootCI producer/consumer、对应测试和本变更文档；model、native调用、field/owner权限无变化。普通CI成功与M5真实资格分别报告。后续实际root签名CI成功也不能替代runtime/humanfield/owner。

回退只撤销本增量；保持原push严格门禁，不允许unsigned、skip或手动force缺项fallback。原main用户dirty和live不改。
