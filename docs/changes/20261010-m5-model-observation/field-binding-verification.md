# 当前候选 field 绑定验证

本轮关闭 field 消费端的候选身份缺口，真实 M5 资格仍 blocked。此前诊断中的 field PASS 仅代表历史最低策略通过；现在不能把它计入当前 8.0.5 的 field 就绪度。

根仓 HEAD 为 `30c7110eca5326a0bf6520733b9760293f930902`；ADK exact pinned 8.0.5 / `ef5384305421700ca01e89b3df3b3f7878a70265`，tracked clean。修改限定根仓 field facade、diagnostics、相关测试及本 change；历史 policy/scorecard/ledger/field/qualification 没有 diff。

实现要求 ledger candidate_version 精确匹配，并从事件摘要保护的独立 pilot-start 证据核对 canonical ADK commit、pilot、human operator、独立真实软件仓库及路径。reference-pin 候选与 pinned repository 身份必须在同一份证据中成立，不能跨文件拼接。managed-gitlink 路径也经过候选身份检查。只改 ledger 的版本标签仍无法通过。

五组定向测试 68/68 PASS，启用 ResourceWarning 为 error；完整合成 rollover 行为测试 PASS，覆盖正向事务、认证消费与拒绝/回滚行为。合成数据仅在复制的临时 Git fixture 中生成，带 selftest_only 标记；它只证明源码行为，不是实际 field、模型、签名 CI 或 owner 资格。

最终离线 wheel 校验 55 个 Python 文件逐字节一致，5 个 CLI 在非仓库目录 --help PASS；未安装或发布。wheel SHA256 `c2e72327f13398ada7fad35bd682caf95c3e31724a7bd6aad33bf80e915f42fc`，source-map SHA256 `38ac187f04bcdd38f3a1fe72836fbde743ba3bf089002bab30199ef6d5a0f1e7`。Ruff E9/F、git diff --check、doc sync PASS。

根仓完整回归 74/74 PASS，ADK quick 56/56 PASS，分别有 `.cache/m5-field-binding-20261010/root-tests.json` 与 `adk-tests.json` 新鲜回执。最终聚合结果以 `.cache/m5-field-binding-20261010/aggregate.json` 为准；M5 资格门禁必须保留真实失败。规则覆盖 PASS，token budget 无失败，保留 3 项既有软预算警告。

实体 Cosign 3.1.3 与 pinned trusted-root 新鲜离线验签通过；只证明当前 ADK promotion evidence 的签名。诊断回执 `.cache/m5-field-binding-20261010/diagnostics.json`：blocking_gates=[runtime, field, qualification, historical_declaration]、software_m5_certified=false、release_authorized=false。field 的实际拒绝原因是历史 ledger candidate version 不匹配。后续动作现在按实际阻断项生成，已通过的签名不再重复要求验签。

本轮没有追加模型调用，上轮 completed=true / observed_models=[] 的两次失败回执仍不能生成有效 runtime evidence。既有 gpt-6.1-sol / medium 请求配置不能代替真实观察模型。没有提交、推送、PR、合并、外部 CI 或 live 修改。

当前项目 Context 已通过 Knowledge Provider 查询；没有推断主体或写 Hub 内部目录，本轮没有宣称已归档。独立审查与本地测试不替代人类 owner review。

下一步：获得受管 SCM 交付授权后推进实际项目 CI/review；最终 main push 的受信回执仍必须绑定合并后的源码。模型身份与完整任务/usage、当前候选 human field/owner、当前 qualification/scorecard 继续独立收集验收，不能靠修改历史标签关闭。

## 完成前核验

| Command | Exit Code | Result | Evidence Path | Layer |
| --- | --- | --- | --- | --- |
| python3 -W error::ResourceWarning -m unittest 五组定向模块 | 0 | 68/68 PASS | 当前线程工具回执 | Source/test |
| bash tests/test_software_m5_rollover.sh | 0 | 合成事务及拒绝/回滚 PASS | 当前线程工具回执 | Source/test |
| bash tests/run_all.sh --fail-fast --timing-json ... | 0 | 74/74 PASS | .cache/m5-field-binding-20261010/root-tests.json | Source/test |
| bash agent-dev-kit/tests/run_all.sh --quick --timing-json ... | 0 | 56/56 PASS | .cache/m5-field-binding-20261010/adk-tests.json | ADK test |
| software_m5_diagnostics --verify-promotion 加固定 verifier/root pins | 2 | 签名 PASS，四项资格缺项 blocked | .cache/m5-field-binding-20261010/diagnostics.json | Crypto/qualification |
| 离线 pip wheel + 文件一致性/非仓 CLI 验证 | 0 | 55 Python / 5 CLI PASS | .cache/m5-field-binding-20261010/wheel/build-receipt.json | Build |

Tool/Skill Plan: primary=adk-planning-execution-loop，supporting=adk-code-review-loop、adk-verification-before-completion；只读独立复审、本地 CLI 和固定 Cosign，无新增模型/connector/GUI。Runtime/Trace/UI/lifecycle audit 不适用：本轮没有更改模型、prompt、tool permission、live 配置或异步生命周期。字段身份校验属于共享消费契约加固，沿用 canonical ADK repository，不引入 fallback。

Replayable Evidence: 固定 production 源码 SHA 见 field-binding-review.md，输入绑定 ADK lock/真实 promotion 与原始 hash-bound field；执行环境 Python 3.11 venv、支持 PCRE2 的 rg、隔离 TMPDIR 和固定 Cosign/trusted-root。定向测试可离线复跑；真实 field/owner 不能由测试回放生成。证据没有 raw credential/body/log 内容。

Breaking Change: 旧候选 field 在新候选消费中将被拒绝，迁移必须收集当前候选真实 field 并经既有流程晋级。Rollback: HEAD 基线和当前逐文件摘要见交付提案，回退仅针对受管补丁并保留用户 dirty；恢复旧消费行为前须审查其资格风险。

Codify Decision: reusable_pattern=候选与仓库身份在同一份 hash-bound 证据中验证；promotion_candidate=false；next_task_friction_reduced=true；reduced_by=诊断后续动作过滤已通过签名并明确当前 field 缺项；reduction_evidence=实际 next_actions 四项与历史 field 拒绝测试；do_not_promote_reason=本轮是项目源码加固且缺实际 field/owner；owner_review=missing；rollback_path=受管源码补丁；verification_evidence=本报告、独立复审及机器回执。

Completion Guard: 本地 field 缺陷 verified；整体 qualification needs-fix，open_items=4；认证/release 不允许。当前实际线程最终 Execution Policy 回执位于 `.cache/m5-field-binding-20261010/final-policy.json`，local conformance 不替代项目验收。SCM 提案需要明确授权，尚无 SCM 写入。
