# Software M5 全面落地计划

Software M5 采用 `llm-agent-software-m5-policy/v3`，目标是 **Production-qualified**。初次 M5 证明产品当前版本已经具备可发布的软件质量与真实使用证据；长期现场观察继续作为运营治理，不再阻塞首次 M5。

## 当前认证基线

- ADK：`251edf2b6654cf8719ad1d8a1b7c81ffd64ffe1c`
- ADK tree：`6fc560322a64c9660e75cc568fded98927954283`
- 当前版本：`5.0.0-rc.2`
- 独立真实软件仓：`digital-worker@4a94231d26df1aeaeba336e6a4e2327db5a3bd44`
- 独立 pilot：`software-m5-v5-independent-pilot-20260912`
- measured runtime：Codex runtime smoke
- compatibility evidence：Claude Code owner attestation
- qualification record：`reports/runtime-evidence/software-m5-production-qualification-2026-09-12.json`

## 必须通过的硬门禁

`software-m5.sh certify` 会 fail closed 校验：

- 当前 ADK lock 与 signed promotion evidence 完全一致；
- promotion evidence 为 release eligible 且声明 Sigstore bundle provenance；
- 至少一个 measured runtime smoke PASS 且全部 quality gates 为 true；
- 至少一个 governed independent real-software repository；
- 至少一个 human operator；
- 至少一个真实 independent `pilot_started` field event；
- field event append-only hash chain 与所有 evidence SHA256 完整；
- qualification record 中 required CI runs 均为 success；
- scorecard 声明与认证器计算结果完全一致。

## M5 后运营增强

下列事项继续进入 backlog/issue，但不会把已经成立的 M5 降回 M4：

- 30 天现场观察；
- 第二位真人 operator 与独立 reviewer；
- Codex/Claude 全量 comparative campaign；
- repository runtime campaign；
- 历史 4.0.0 official artifact continuity 恢复；
- 更多 native target runtime smoke；
- 5.1.0 release train。

若这些 follow-up 发现真实产品缺陷，应按缺陷严重性重新打开 blocker；不能因为它们尚未执行就把当前 production-qualified 产品永久卡在 M3/M4。

## 验证命令

```bash
rtk scripts/software-m5.sh status --summary-json
rtk scripts/check-software-m5-readiness.sh . --summary-json
rtk scripts/software-m5.sh certify --summary-json
rtk python3 -m tools.control_plane.status_projection --root . --summary-json
```

CI 的 source-contract profile 会通过 `test_status_projection.sh` 直接执行 Software M5 certify；涉及 policy、scorecard 或 ADK identity 的变更仍会触发 REQUIRED `integration-deep`，并继续执行 Cosign/Rekor v2 验证。
