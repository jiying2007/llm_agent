# Native target conformance readiness

当前软件链分三层，必须分别记证据，不能互相继承：

1. **Source layout evidence**：ADK 7.2.0 的 `target-source-probe` 在隔离临时目录验证 export inventory、文件 digest 和文本入口可读性。该层固定 `native_runtime_evidence=false`。
2. **Managed trust software**：ADK 7.3.0 的 `native_conformance_trust_registry.json` 与 production loader 提供受管 verifier 注入。registry 默认没有 authority，因此不会自动启用任何 runtime target。
3. **Native campaign software**：ADK 7.4.0 的 `native-campaign prepare/run/finalize` 已把版本探针、三阶段执行、typed receipt 候选和 future runtime contract 变成公开 CLI；失败/阻塞 campaign 不能 finalize。
4. **Native trust / promotion evidence**：只有真实 runtime discovery/load/trigger 全过，receipt 再经签名/provenance、managed registry 绑定和 production loader 验证后，才允许另开 target contract runtime promotion 变更。

Root 会消费前三层的软件能力，但 synthetic campaign 只验证 harness，不构成真实 native receipt、签名、registry authority、live HOME 修改或产品 release authority。

## 当前核验命令

```bash
rtk python -m pip install ./agent-dev-kit
rtk bash tests/test_adk_context_observability_consumer.sh
rtk bash tests/test_adk_native_trust_consumer.sh
rtk bash tests/test_adk_native_campaign_consumer.sh
rtk bash agent-dev-kit/scripts/devkit.sh target check --all --level static --summary-json
```

预期：所有 direct target 仍为 `static / not-certified / not-run`；managed trust registry 为 active 但 authorities 为空。

## 真实 campaign 的开始条件

开始真实 native campaign 前必须同时冻结：

- Root 与 ADK exact SHA、target contract digest、bundle digest；
- runtime binary digest 与 exact version pin；
- discovery/load/trigger 三个独立命令；
- authority ID、target scope、signature/provenance backend；
- 隐私约束：不保存 prompt、message、credential、raw tool payload；
- 预算和停止条件。

缺认证、缺 verifier binary、缺签名、identity/scope/digest 不匹配、任一 stage 失败时都保持 BLOCKED / static；不得退化为“source probe 已过所以 native 已验证”。

历史上 Claude 的隔离 discovery 曾因认证不可用而停止，这类结果应作为负证据保留；只有新的、版本绑定的完整 campaign 才能改变 native conformance 状态。


## ADK 7.4.0 campaign 操作边界

真实 campaign 不再手工拼 receipt。先按 `agent-dev-kit/docs/runbooks/native-campaign.md` 执行 `prepare`，冻结 exact target/source/runtime/bundle/authority/command identity；再执行 `run`；只有 `status=complete` 才执行 `finalize`。

`finalize` 仅输出 `ready-for-signature-and-registry` 候选，且拒绝覆盖 active target contract。后续仍必须独立完成 receipt 签名、managed registry exact binding、production loader 验证、owner review 与 target contract promotion。

Root 的 `test_adk_native_campaign_consumer.sh` 使用隔离 Python runtime fixture，只验证公开 CLI、fail-closed 与权限边界；其 PASS 不可写入 native certification、runtime qualification 或 product release evidence。


## Machine-readable readiness projection

Root now exposes one read-only projection for G21:

```bash
rtk python3 -m tools.control_plane.cli native-readiness --root . --summary-json
rtk python3 -m tools.control_plane.cli native-readiness --root . --require-native --summary-json
```

The default command validates the software chain and returns exit 0 even when terminal native evidence is still externally blocked. Read `terminal_status`, `software_ready`, `native_verified_targets`, and `blockers`. The `--require-native` form exits 2 until at least one direct target has a real version-pinned runtime conformance pass whose evidence path, trust policy, enabled registry authority, target scope, and runtime identity are coherent.

A green default projection means the status projection is valid; it does **not** mean native certification passed. This distinction is intentional so missing provider authentication or a real runtime campaign does not block unrelated software maintenance while still remaining a machine-visible terminal blocker.


## ADK 7.4.1 project discovery layout

真实 native campaign 必须让运行时从它实际支持的**项目级 discovery 位置**看到 Skill，而不是只把 `skills/` 放到任意临时目录：

- Claude Code：isolated project root 下的 `.claude/skills/<skill>/SKILL.md`
- OpenCode：isolated project root 下的 `.opencode/skills/<skill>/SKILL.md`

7.4.1 的 campaign runner 以 isolated project root 作为 runtime cwd，`ADK_TARGET_PROJECT_ROOT` 指向该项目根，`ADK_TARGET_ROOT` 指向对应 `.claude` / `.opencode` 配置根。这样 source/layout harness 与真实项目 discovery 语义一致。

`auth_mode=home` 只用于复用受控用户认证状态，不通过 `CLAUDE_CONFIG_DIR` 或 `OPENCODE_CONFIG_DIR` 把项目 Skill 路径替换成用户全局配置根。真实 campaign 仍需设计唯一 canary/命中证据，防止用户全局 Skill 造成假阳性。

## ADK 7.6 semantic evidence hard-cut

ADK 7.6.0 closes the exit-code-only native campaign gap. A discovery/load/trigger command returning zero is no longer sufficient evidence. Every real campaign must provide a separate pre-registered assertions JSON for the three native stages. The plan binds only assertion digests; execution evaluates the selected stdout/stderr/combined stream in memory and retains only assertion identity/result digests plus pass/fail status.

Root accepts only the active v2 certification surfaces:

- `schemas/native-target-campaign-plan-v2.schema.json`;
- `schemas/native-target-campaign-evidence-v2.schema.json`;
- `schemas/native-target-conformance-receipt-v2.schema.json`.

The v1 campaign/receipt certification path is retired with no compatibility fallback. `exit_code=0` plus a missing semantic canary must fail the campaign and cannot be finalized. Raw assertions and native command output remain non-retained.

This hard-cut still does not create native certification by itself. G21 terminal completion requires a real authenticated, version-pinned runtime campaign whose semantic assertions describe actual discovery/load/trigger success, followed by signed provenance, exact managed-trust binding, production-loader verification, and owner-reviewed target promotion.

