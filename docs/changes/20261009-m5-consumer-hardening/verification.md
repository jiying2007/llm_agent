# M5 消费边界加固验收

## 资格边界

本次只修复根仓源码与工作流。合成测试中的 pinned fake verifier 仅用于事务测试，不是密码学证明，不改变历史 qualification、policy、scorecard 或产品状态。真实 M5 仍要求当前 ADK 的有效 promotion、实际 Codex 测量、真实 field baseline 和可信 root CI 回执。

## 消费契约

- `m5_runtime_contract.validate(..., source_root=...)` 是生产调用：身份、时效、摘要、固定四项 gates、非零任务及逐任务观测模型先校验，再核当前干净 ADK checkout、manifest、canonical `software_m5_eval_tasks.jsonl` 的摘要和标签。无 `source_root` 的调用只供结构单元测试，不能形成认证结果。
- 认证与 rollover 必须传入 reviewed `--cosign-binary`、`--cosign-sha256`、`--trusted-root`、`--trusted-root-sha256`；参数不得从证据或 PATH 推导。verifier、trust root、bundle 与 payload 均冻结后离线验证；签名身份固定 canonical main-push CI workflow 和 GitHub OIDC issuer。
- `--root-integration-run-id` 不再证明成功。rollover 还要求 `--root-ci-receipt`：`llm-agent-signed-ci-receipt/v1` envelope 保存原始 payload/bundle 的 base64，由 root main-push CI 产生。payload 的 repository/workflow/ref/event/head/run/attempt 和四项 required jobs 均必须匹配。
- CI producer 仅在 canonical main push 且 contract、doc-sync、integration、integration-summary 全部 success 时签名上传；integration skipped 不产生成功回执。新增 workflow 需提交并在 GitHub 实际执行后才有真实 artifact，本次不触发、推送或发布。
- hosted CERTIFIED consumer 独立安装 pinned-version cosign 并初始化 ADK；owner 显式配置 repository variables `M5_COSIGN_SHA256`、`M5_TRUSTED_ROOT_SHA256`、`M5_TRUSTED_ROOT_BASE64`。后者是 reviewed 公共 trust root，不含 credential；其摘要必须与 reviewed pin 相符。缺配置阻断，不能由 installer 或证据反向生成可信 pin。
- qualification record 内嵌签名 root receipt；独立认证重新验签，并核 ADK promotion run/digest、源码 baseline 与允许的五个 qualification 输出。新增未跟踪源码不得绕过 baseline 检查；既有 reference/runtime 输出 exclusions 与 Python bytecode cache 单列。
- 自定义任务集仍可用于采集诊断，生产 M5 仅接受 pinned ADK canonical 任务集。独立认证必须有当前干净 ADK checkout；未初始化、dirty 或不匹配时阻断。
- diagnostics 默认只读，仅校验 claims。显式 opt-in 签名验证复用冻结/离线 helper；该诊断不授予认证或 release authorization。

## 操作入口

```bash
rtk python3 -m tools.codex_assets.software_m5_rollover \
  --root . --runtime-evidence /reviewed/runtime.json \
  --root-integration-run-id 123 --root-ci-receipt /reviewed/root-ci-receipt.json \
  --cosign-binary /reviewed/cosign --cosign-sha256 REVIEWED_BINARY_SHA256 \
  --trusted-root /reviewed/trusted-root.json --trusted-root-sha256 REVIEWED_ROOT_SHA256 \
  --expected-model REVIEWED_MODEL --apply --summary-json
rtk bash scripts/software-m5.sh \
  --cosign-binary /reviewed/cosign --cosign-sha256 REVIEWED_BINARY_SHA256 \
  --trusted-root /reviewed/trusted-root.json --trusted-root-sha256 REVIEWED_ROOT_SHA256 \
  certify --summary-json
```

示例路径、run ID 与摘要占位符需要替换为已核验输入。rollover 要求 clean source，认证结果重新计算；真实签名、任务测量或 CI 缺项继续 blocked。

## 验证记录

以下为首轮加固的历史验收；后续重审发现已单列，不能将该历史 PASS 视为最新源码结论。

| 验证 | 本轮结果 |
| --- | --- |
| 根仓完整回归 | 74/74 PASS；最终回执 `/tmp/llm-agent-m5-hardening-tests-closed-20261009.json` |
| M5 对抗单元测试 | 14/14 PASS，覆盖原五类绕过及新 CI/trust/snapshot 契约 |
| 模型绑定 / diagnostics / runtime 命令 | 7/7、10/10、4/4 PASS |
| 隔离 rollover 集成 | PASS；合法晋级、直接认证拒绝新增源码、后段失败完整回滚、无签名/时间/dirty 负例 |
| 独立审查 | whole-diff 与最终增量 Spec PASS / Quality PASS，无未关闭 blocker/major |
| 静态检查 | `git diff --check` 与修改 Python 的 Ruff F/E9 PASS |
| 新 CLI 非仓库 cwd | 两个新增 CLI 的 `/tmp` cwd `--help` PASS |
| 根仓离线构建 | 隔离 source snapshot 离线 wheel 构建 PASS；8 个生产模块字节匹配，两个新 CLI 从 wheel 的非仓库 cwd `--help` PASS |
| ADK quick | 56/56 PASS；回执 `/tmp/llm-agent-m5-hardening-adk-tests-20261009.json` |
| 聚合门禁 | 50/52，整体 FAIL；workspace fingerprint stability PASS；回执 `/tmp/llm-agent-m5-hardening-checks-20261009.json` |
| 当前线程 Execution Policy | final PASS；thread `01a11fea-4d33-7643-a96a-b4176110e08a`，真实 repo/build/checkpoint/evidence 已绑定；仅 Runtime conformance |

历史中间回执保留了失败和修复过程，不能与最终统一回执混为同一轮成功。未安装真实 cosign、未取得本次真实 CI 或模型调用证据；合成测试不替代它们。运行资产未修改，因此不执行 source-to-live apply。

## 保留的外部资格阻塞

1. `check-adk-promotion-evidence.sh`：当前环境没有真实 cosign。测试 verifier 不进入该门禁，也不形成签名证明。
2. `check-software-m5-readiness.sh`：历史 policy 候选 `5.0.0-rc.2` 与当前 promotion 的候选身份不匹配，机器认证和历史 scorecard 声明拒绝通过。未重写任何历史资格或伪造当前运行证据。

两项均为本次修复前已经存在的环境/资格阻塞。聚合 FAIL 不等于产品就绪；源码修复、软件回归、独立审查已完成，真实产品资格仍 blocked。实际运行新 CI workflow 和归档候选审批不在本次外部写授权范围；本次不 commit/push/触发 CI。

## 构建身份

- build source snapshot: `e0a40385de42a02acad2fc404150389a2706ffa726d00deb9f693028803806df`
- wheel: `/tmp/llm-agent-m5-hardening-wheel-20261009/llm_agent_control_plane-0.6.0-py3-none-any.whl`
- wheel SHA256: `342631529006613576727cc51155ae25ca0e7c0b68b01325dd5ac89beb68d6ae`
- 命令采用 `pip wheel --no-deps --no-build-isolation --no-index`；没有安装、发布或修改 live runtime。后续只补齐验收文档，不改变已构建的生产模块。
- final gate 首次因缺 build artifact 拒绝；补真实离线构建后于 `2026-10-09T11:08:42Z` PASS。不将测试回执伪登记为 build。

## 重新审查与修复验收

- 用户请求：重新审查；继续推进落地闭环。
- 两项 P1：工作树任务内容没有绑定 pinned blob；hosted 浅克隆缺少 signed source baseline。已补实际 Git 正负例并修复。
- 同一源码身份缺陷补全：ignored startup sourceless bytecode 和有效 header 的标准 cache 均实际复现。前者拒绝，后者以新鲜 PYTHONPYCACHEPREFIX 隔离 capability/help 和 eval；继承 PYTHONPATH 清除，用户 cache 保留。
- 新鲜定向：hardening 19/19、runtime command 5/5、workflow compatibility、consumer-chain、reference-pins、Ruff F/E9、diff check 通过；文档同步、AGENTS coverage 通过。
- Fresh independent whole-diff：Spec PASS / Quality PASS；本轮已复现源码缺陷全部关闭。
- 整批首跑 consumer-chain 的旧全工作区 cp fixture 触发 ENOSPC；该失败保留，改用 owned-only snapshot 并保留原篡改负例后通过。没有清理用户参考仓、缓存或现场文件。
- 最新离线 build source（package-files-v1）：`fcf418d60c0879b7185a5527d3614ba283950cb3f659f46d04a145ce77219ec8`。
- 最新 wheel：`/tmp/llm-agent-m5-rereview-wheel-20261009/llm_agent_control_plane-0.6.0-py3-none-any.whl`。
- 最新 wheel SHA256：`1b2a30616688fa32c2df0ac0317bec2ae568b3f1b5d6520cf655a4a54bbdc5c2`；8 个生产模块逐一字节匹配，两个 CLI 在非仓库 cwd 通过 help 检查。
- 本次新 goal：`task-dfebedcb7e1b6b54d88856d8`；绑定真实用户重审/修复请求。Runtime final 在交付前独立执行，结论以当前线程本机回执为准；不推导产品资格。

| 最新验证 | 结果与证据 |
| --- | --- |
| Frozen root regression | 74/74 PASS；`/tmp/llm-agent-m5-rereview-tests-closed-20261009.json`；SHA256 `45a71023f6d823f3a00cd6ad9d1184be733e4132c861ef5f5a2748d55aca89b2` |
| ADK quick | 56/56 PASS；`/tmp/llm-agent-m5-rereview-adk-tests-20261009.json`；SHA256 `66e490a8c36f5b76b0274c70208e25d873fc68b18b1c600920af3ec3a8e78d4d` |
| Aggregate checks | 50/52，整体 FAIL；`/tmp/llm-agent-m5-rereview-checks-20261009.json`；workspace fingerprint stability PASS |
| 回归源码快照 | managed-diff-v2 `e2a88c6367aaf9412417a2469ea8e4d536a18a33835a259e3fb48d5b9d76120d`；回归前后相同，后续仅更新 change 文档 |

聚合剩余失败仍为缺真实 cosign，以及历史 candidate 5.0.0-rc.2 与当前 promotion 不匹配导致 M5/scorecard 拒绝通过。没有新增聚合失败，没有重写历史资格。ADK tracked worktree 干净，根仓未暂存、未提交、未推送，原有 reference/runtime untracked 目录保留。

## 2026-10-10 最新执行边界修复验收

本节为当前最新源码结论；以上 PASS 均是历史快照。两项重审 P1（Bash 启动环境继承、实际执行文件与摘要误绑）已修复，并完成 fresh 独立 Spec PASS / Quality PASS。

| 当前验证 | 结果与回执 |
| --- | --- |
| 根仓完整回归 | 74/74 PASS，402422 ms；`/tmp/llm-agent-m5-execution-tests-20261010.json`；SHA256 `77af8a715988a85b2db79bb2d2819d985d10ee70c2a7611686768d1711c3d95a` |
| ADK quick | 56/56 PASS；`/tmp/llm-agent-m5-execution-adk-tests-20261010.json`；SHA256 `207f216197afeef064804074b23cd68079e7ef5ea7c21e760ae7f38015d54b78` |
| 定向命令 / 加固 | 9/9、19/19 PASS；真实 startup marker 未执行，正常 help/eval 输出成功；所选启动器覆盖另一个 PATH Codex、带空格路径正常、不可执行文件前置拒绝、自修改文件阻止发布；导入或缺身份标记即使重算摘要仍拒绝 |
| 真实 pinned ADK 调用链 | PASS；collector/evaluator 无 mock，假 Codex 无网络、无模型调用；实际文件与摘要一致，不可执行 B 不进入评估；`/tmp/llm-agent-m5-execution-probe-20261010.json`；SHA256 `d86a715204997002edb9bded89e925348569bdd46e028b439f60fd022de0bab6` |
| 聚合门禁 | 50/52，整体 FAIL；两项既有资格阻塞；fingerprint stability PASS；`/tmp/llm-agent-m5-execution-checks-20261010.json`；SHA256 `6fa0c4c9f5d561a363860dce0bf45def029cafbc63440edfdea84f559914b02a` |
| 静态 / 文档 | Ruff F/E9、diff check、文档同步、AGENTS coverage PASS；Token 门禁 3 项既有软警告、0 失败 |
| 独立复审 | `/root/m5_review` fresh whole-diff Spec PASS / Quality PASS；未发现授权修复范围内新的 blocker/major；8 个生产模块 AST 与 diff check 通过 |
| 离线构建 | PASS；54 个 Python 源文件与 wheel 逐字节相同，4 个 CLI 在非仓库 cwd help 成功；无网络、未安装/发布/live apply |

回归前后 managed-diff-v2 快照均为 `6952392cb3eb6e2ae86d4fb12c72f3d7d37f62178d464ceda0a4c6d64df9c692`，之后仅更新本 change 文档，生产源码和测试未再变更。

最新 wheel：`/tmp/llm-agent-m5-execution-wheel-20261010/llm_agent_control_plane-0.6.0-py3-none-any.whl`；SHA256 `7b41668f3caa9f1bc8a6529ab0bc860927062d57b91e040d4511b65ea12d20cf`。54 文件摘要映射（排序路径及各文件 SHA256 的 canonical JSON）为 `8c42d9513be4256e7739cb2afe6fc86901e1ca5ee921e36af15a4aa09919968a`。构建回执 SHA256 `7c919028db8ca9738a06e8d48639e24b4d1c7ba60dd725c52c5ad2fdf1dbfce6`，已绑定当前真实线程 build artifact。

首次隔离调用链探针的假响应字段不符合真实 ADK schema，实际执行返回失败；改为 primary_skill/safe_to_execute/reason 后复验通过，生产源码未因此改变。Git filter 复现此前被安全检查拒绝，本次未重试，未列为已确认或已关闭缺陷。

旧报告导入明确为 unverified-import，只供诊断；当前 M5 消费需要 selected-executable-pre-post-sha256。摘要前后检查不证明原子执行、动态依赖闭包或密码学运行证明。完整确定性回归和假运行器不能替代真实模型、field、owner 或发布资格。

最新资格状态复核：candidate_version=5.0.0-rc.2，promotion evidence source.version does not match current candidate；software_m5_certified=false、eligibility/certification=blocked。缺真实 cosign 和历史 scorecard 漂移继续保留，未修改历史 policy/qualification/scorecard。

当前 Runtime goal 为 `task-c3d899451781e5fab0d09ac0`，thread `01a11fea-4d33-7643-a96a-b4176110e08a`；final gate 在交付前独立执行，结论以该线程本机回执为准，只代表 Runtime conformance。Provider 只生成 reviewing dry-run 候选计划，不将其称为已归档。根仓无暂存/提交/推送，ADK tracked worktree 干净，既有参考目录保留。
