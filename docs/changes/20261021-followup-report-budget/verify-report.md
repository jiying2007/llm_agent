# 实际验证检查点

时间均为 2026-10-21 北京时间。冻结来源基线为 Root `cd60e38a2a8cda1cc643824004538448d850a783`，ADK 仍固定 `19a89bab07c42f4fe506bafe5b8c8e64e1e1baf3` / 8.0.37。

## 已完成

| 检查 | 实际结果 |
| --- | --- |
| 新大输入回归对原生产代码，21:22:26–21:22:27 | exit 1；实际最终 JSON 加换行 5,315,390 字节，大于 4,194,304；原 stderr SHA-256 `707fa6c3485e21ec33a5431936563875a6e40501920d124c5b8ac908f0dd3770` |
| 修复后六个字节边界回归，21:22:57–21:22:58 | 6/6 PASS，exit 0；涵盖大输入、中文与换行边界、二级压缩、来源无效早返、最小内部预算 |
| 既有 qualification-followup 完整定向入口，21:23:40–21:23:44 | 84/84 PASS，exit 0；原 stderr 15,381 字节，SHA-256 `b145e2665394c2b757245dbdef113ada5c4669bf7099783aacf4320d3fa0826f` |
| 当前工作树真实六项复核，21:23:55–21:23:56 | exit 0，`scan_status=complete`，前后各 142 项输入完整且相同，无 `report_truncated` 标记 |

真实工作树复核的 stdout 为 82,176 字节，SHA-256 `33bad56833d8e0e70c3bb766fae79e984db9400ad7fe3d71d8bfd2cf2d4a6fde`，输入身份为 `e6d584c3e03a0226284a2fa654bfb34139b0372f792bd65f373ded3571f7248c`。ADK #201/#205 为 ready，Native/G22/LTA 仍 blocked，M5 conditional，`release_authorized=false`。这是工作树诊断，并非最终 clean-commit 或 fresh-main 结果。

本轮确认的原始超限审计、red 回归与上述通过输出分别留在最终审计包中，不覆盖原失败。原始 stderr/stdout 摘要以执行收据为准，测试 fixture 不进入任何真实资格索引。

## 待冻结后执行

当前实际验证计划为 L3：Root 完整回归、ADK quick、工作树 aggregate。联合源码冻结后运行这些检查，并按真实环境记录失败；本机 `/root/codex`、原始参考 dirty 工作树缺失和历史 M5 资格不会由本修复补绿。独立 Spec/Quality、受保护 PR 和主线运行的最终状态由 PR 最终正文及最终审计记录承接。
