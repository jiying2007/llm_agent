# M5 执行来源修复验证记录

本轮修复三项审查问题：真实执行来源认证、managed Gitlink 实体身份绑定、执行前显式联网许可。源码基线为 `134d124ad2973f621f920f68eb14f4d0cbdbce65`，增量留在隔离工作树，未提交、推送、合并或更新 live。

## 最新源码完整性修复（2026-10-11）

以下为最新增量；后文85/55项结果与旧源码摘要仅属于此前 clean-source 空输出修复，不代表本次最终快照。

新鲜全面审查确认两项 Major：Git fsmonitor 能隐藏已修改的 ADK 执行脚本，完整 `_validate_source_identity()` 仍接受；继承 `GIT_DIR/GIT_WORK_TREE` 能将 producer 的 root clean-source 预检重定向到另一同 HEAD 干净仓库。后者未证明贯通签发链，不能扩大实证结论。

修复统一 `source_git`：清除继承 Git 环境，隔离 system/global 配置，禁用 fsmonitor、hooks、global attributes、replace objects；status/diff 停用本仓 clean/smudge/process filter 和 required 标志。producer 校验实际 root，Root/ADK 受管 executable 源实际字节与 HEAD blob 无过滤比较；qualification、rollover、managed field 复用相同 Git 边界。执行环境也清除 Git 重定向变量。

独立复审还提出父仓递归扫描子仓的 filter 漏项。真实注册子仓、同尺寸脚本修改可复现 native root status 执行 child filter；producer 和 rollover 改为父仓 `--ignore-submodules=dirty` 后直接隔离验收 ADK，qualification root diff 使用同边界。真实回归覆盖两实际入口拒绝且 marker 不执行；独立实验确认 ADK HEAD 改变仍显示 `M agent-dev-kit` 并拒绝。

最终主代理与独立 reviewer 各自六组 **90/90 PASS**（Python3.11，ResourceWarning 作为错误）；独立 whole-diff Spec PASS / Quality PASS，原两项 Major 及递归 child-filter 漏项关闭，无其他 confirmed blocker/major。实际 pinned ADK 8.0.5 executable 源字节检查 PASS，ADK quick **56/56 PASS**；root full **74/74 PASS**，exit0，机器证据 `/tmp/m5-source-git-root-tests-20261011.json`。最终 M5 shell 集成回归在修正后的源码与测试上通过。

冻结 aggregate **49/52**、exit1，`workspace-fingerprint-stability` PASS，机器证据 `/tmp/m5-source-git-final-quick-20261011.json`。三项失败与上轮相同：generic promotion check 的 PATH 无 Cosign、隔离工作树没有原主仓 reference dirty 实体、历史候选/scorecard 不满足当前身份资格。实体 pinned promotion 验签单独通过；未造 wrapper/reference 目录、删检查或重标历史。快检后只补记验证文档与计划，功能源码及测试与独立复审摘要一致；文档同步另行验证。

原主仓 HEAD/index/tracked diff 最终保护核验通过，未回写或清理用户 dirty。仓外 producer help、docs sync、AGENTS coverage、diff check PASS；token预算检查PASS且保留3条已有软阈值warning。最新实现本地 open_items=0；Provider reviewing 与 Runtime final 以实际回执独立收口。

保留负结果：递归 filter fixture 首次使用不同尺寸修改，native root status 没有执行 filter，未构成有效反例；同尺寸修改才证明执行，随后生产修复阻止执行。新增 rollover 源码预检令旧非 Git symlink fixture 提前拒绝，90项初跑89/90；只在 focused reader 单测隔离新增 preflight，严格路径拒绝断言保留，复跑90/90，生产无绕过开关。

关键源码摘要：source_git `732a5a6e92b516dc7bf96abef165504fcd9f4775313ad3e60d3f7e581bc86778`；collector `e1e3eda0e97176c4f5b8f58cf09a4952ac1318ed00269f424bf40b842a7a9870`；producer `49f7e09d127f9009e4ec5869b832c62f323a030aec5e7b57c5202b93f71a8be1`；rollover `bd7c3a4702f54ca002da0297dbd2a8f84c0e005011189819b61b98f64bb05933`；provenance tests `4f75823256d8a54f2962a2c8e6fc047139eb33c216b120d80b229de75d60e042`。

本次实体 Cosign 3.1.3 pinned binary/trusted-root 离线验证当前8.0.5 promotion PASS；diagnostics exit2：runtime、field、qualification、historical declaration 四项仍 blocked。零模型调用，未联网或运行新签名 workflow，未更新历史候选/scorecard。独立 AI 复审不替代人类 owner；source_snapshot_atomic=false 保持。

本次 reusable_pattern 为受管源码身份查询隔离 Git 配置并核对实际执行字节；promotion_candidate=false，不自动推广全局规则/live。原工作区保护、最终 Provider reviewing 与 Runtime 本地 final 由实际收口回执分别验收，不推导 M5 资格。

## 全面复审后的追加修复

再次全面审查发现一项 Major：producer 的 clean-source 检查复用了禁止空 stdout 的身份查询 helper，干净 checkout 的正常空 status 被误判为异常，使 collect 与 envelope 无法继续。该问题已使用真实 pinned ADK 复现；上一轮“无剩余 confirmed finding”仅是当时审查结果，不能覆盖此新发现。

最小修复为 `_run_git(..., allow_empty=False)`，仅 status 调用显式允许空 stdout；身份查询仍要求非空、Git 非零返回码仍拒绝。增加三个真实 root/ADK Git fixture 测试，覆盖 clean 正例、dirty/untracked/隐藏 index/错误 HEAD/Git 错误负例，以及 collect → payload → envelope → production consumer 的离线成功流程。成功流程仅替换 inference 与密码学边界，未 mock clean-source、源码/任务 blob 或消费者校验；unsigned 中间报告仍拒绝生产资格。

当前 Python 3.11 定向回归 85/85 PASS，开启 ResourceWarning 为错误。独立 whole-increment 复审 Spec PASS / Quality PASS，独立 55/55 PASS，并直接核验真实 pinned ADK clean-source PASS；该 Major 已关闭，无新增 confirmed Blocker/Major。最初独立复验使用系统 Python 3.8，属于不满足项目 >=3.11 的环境错误，随后支持解释器复验通过，不计为产品缺陷。

源码摘要：collector `6fbfdb9e98afd14000f23ef3b4759ae5154b013600c50cac9b65b0d7580df46c`；producer `856a78ec2c4044b7e1a8232851c80a6bc453a3f609dd68a2eb5924fbd651571a`；provenance tests `d6080e7f24b395a9746097b7811ae6f7f6961c6087a99bf89669235ccebf2e1b`。仓库外 producer help PASS。本轮 ADK quick 56/56 PASS。

首次完整 root 回归在新增“错误 Git 路径”负例失败：TMPDIR 位于原工作区内，Git 向上发现父仓库，存在的临时目录并非稳定的错误 Git 路径。负例改为不存在的 `missing-checkout` 后，在同一 PATH/TMPDIR 下 16/16、85/85 与独立 55/55 全部 PASS；生产源码未因此变化。完整 root 回归重跑 74/74 PASS、exit 0，机器结果保存于本次运行证据；aggregate 随后串行验证，不隐去首轮负结果。

最终 aggregate 49/52、exit 1，workspace-fingerprint-stability PASS。三项负结果为 generic promotion check 的 PATH 未提供 Cosign、隔离树未包含 OpenSpec/superpowers/vibeflow 的原始 reference dirty 实体，以及历史 5.0.0-rc.2 身份/scorecard 与当前候选不一致。显式 pinned Cosign 3.1.3 已实际离线验签当前 promotion PASS，不能将 PATH 缺项误报为该签名不可信，也不能以该验签替代 runtime/field。未删检查、造 reference 目录或重标历史；快检后仅更新本验证记录和计划，功能源码及测试未变化，文档同步另行复验。

真实签名 runtime、当前 human field、owner 与同基线 qualification 仍未取得。本修复未调用真实模型或联网，未发布新 workflow。真实 promotion 签名已有实体 Cosign 离线 PASS，不能推导 runtime 或 M5 资格。

## 复用与推广边界

- reusable_pattern: 按 Git 子命令的成功输出语义设置约束；身份查询与状态查询分别验收，不能用只测拒绝路径的测试证明正常入口可用。
- promotion_candidate: false；do_not_promote_reason: 本轮只修既有契约实现，未申请改变全局规则或 runtime 资产。
- next_task_friction_reduced: 对 clean-source 的误拒与临时目录父仓发现问题提供可复跑反例；reduced_by: 真实 Git fixture 与正常 producer 流程；reduction_evidence: 支持 Python/TMPDIR 的定向 85/85 与独立 55/55。
- owner_review: 未执行人类 owner 审定；独立源码 reviewer 为 AI，只支持代码审查结论。
- rollback_path: 在隔离 worktree 审查并回退本轮增量；不覆盖原 main dirty，不恢复 unsigned qualification fallback。
- verification_evidence: 本记录、当前测试源码及命令级本地回归；所有模型/密码学 fixture 明确为合成依赖。

## 本轮命令级证据

所有命令均经 rtk；Python 入口使用项目支持的 3.11。root/ADK 回归与定向复验采用同一 PATH/TMPDIR，aggregate 等全部临时 fixture 退出后串行执行。

| 命令 | exit | 结果与范围 |
| --- | --- | --- |
| `python3 -W error::ResourceWarning -m unittest test_m5_execution_provenance test_runtime_smoke_command test_m5_consumer_hardening test_m5_rollover_model_binding test_codex_model_observer test_current_m5_diagnostics`，`PYTHONPATH=tests:.` | 0 | 85/85，含真实 Git 和明确合成 inference/签名边界 |
| 独立 reviewer 四组定向 unittest，同一 Python/TMPDIR | 0 | 55/55，Spec/Quality PASS |
| 当前真实 pinned ADK 的 `clean_source(root, HEAD)` | 0 | 修复后实际 clean-source PASS |
| `bash agent-dev-kit/tests/run_all.sh --quick` | 0 | 56/56；ADK 源码未修改 |
| 首次 `bash tests/run_all.sh --fail-fast` | 1 | 错误 Git 路径负例受 TMPDIR 父仓发现影响；已修测试并重跑 |
| 最终 `bash tests/run_all.sh --fail-fast --timing-json <本轮运行证据>` | 0 | 74/74，全套回归覆盖最新测试修正；原报告 `/tmp/m5-producer-root-tests-20261011.json` |
| `bash scripts/check-all.sh --quick --working-tree --result-json <本轮运行证据>` | 1 | 49/52；fingerprint 稳定，保留三项环境/资格负结果；原报告 `/tmp/m5-producer-final-quick-20261011.json` |
| `software_m5_diagnostics --verify-promotion`，explicit pinned Cosign/trust | 2 | 真 promotion 验签 PASS；runtime/field/qualification/历史声明仍 blocked，零模型调用 |
| 仓库外 `python3 -m tools.codex_assets.m5_runtime_receipt_producer --help` | 0 | 源码模块入口可用，不证明实际 workflow |
| `git diff --check` / `bash scripts/check-doc-sync.sh .` / `bash scripts/check-agents-coverage.sh .` | 0 | 改动格式、文档与规则覆盖检查 PASS |

## 已验证的行为

- 生产 runtime 消费端要求受信 workflow 的签名执行回执。测量摘要覆盖完整报告；修改模型、usage、response ID、执行器或源码后，重算普通摘要不能恢复原签名绑定。
- runtime 与签名 root CI 使用相同 source baseline，并核对 collector、producer 与 observer 的源码摘要。unsigned collector 输出 `qualification_eligible=false`。
- managed field 路径要求实际 HEAD Gitlink、独立子仓 HEAD、registry origin 与同一 pilot JSON 的身份一致。拒绝 dirty 和隐藏 index 标志；真实临时 Git fixture 覆盖 assume-unchanged 与 skip-worktree。
- 普通 execute 与 producer collect 都在没有显式网络许可时提前拒绝，不启动模型调用。
- 新工作流只接受 canonical main 的手动执行，固定 GPT-6.1-Sol / medium、最多一个任务，先核 owner 配置与制品 pin，再采集、签名、离线验证并导出。工作流代码存在不表示现实 runner、environment 与 owner 保护已经配置。

## 追加修复前的验证结果

| 验证 | 当前结果 | 证据范围 |
| --- | --- | --- |
| 新 provenance 反例 | 13/13 PASS | 含真实本地 Git fixture；密码学成功路径使用显式测试 mock |
| runtime smoke 命令 | 11/11 PASS | 缺联网许可零执行；输出路径拒绝覆盖与链接 |
| 独立 whole-increment 复审 | Spec PASS / Quality PASS | 隐藏 index 绕过修复后关闭，无剩余 confirmed finding；独立定向 52/52 PASS |
| ADK quick | 56/56 PASS | ADK 未修改 |
| 根仓完整回归 | 74/74 PASS | 覆盖最新隐藏 index 补强、runtime 与 rollover、workflow 兼容性；exit 0 |
| 源码冻结后 quick aggregate | 49/52，exit 1 | workspace fingerprint 稳定；三项负结果为 PATH 未提供 Cosign、隔离树缺 reference dirty 实体、历史 M5 资格不匹配及声明过期 |
| 真实旧 CI 与 ADK promotion 签名离线复验 | PASS | 实体 Cosign 3.1.3 与固定 trusted root 独立验证；不推导新 runtime 资格 |
| 新工具仓库外 help | PASS | 在非仓库 cwd 通过源码模块入口运行 |
| 原工作区保护 | PASS | HEAD、index 和 tracked diff 摘要与本轮前一致 |

旧 CI 回执测量摘要为 `e9aa86d59653b5170b12ac442b5b5da85a06759695498eac987dcccc623b0023`；ADK promotion 签名 payload 摘要为 `d607402e2e0e5248e0f53a4a525748e218b24bebeed9ef01d1397a49a73fbd02`。原 main HEAD 为 `30c7110eca5326a0bf6520733b9760293f930902`；index 摘要为 `7985679f94c0c03abab4b0627902038101bfc57fd1c57e1236be0bd2d0aeb1ba`，tracked diff 摘要为 `b2771be0c96c41a52881673090dfe9a2490171804f11196fd06704b69a33bd3d`。

本轮 quick 的机器结果保留于运行证据，未删失败检查或伪造参考实体。真实离线验证使用显式固定 Cosign 路径，不因 generic check 的 PATH 缺项而误报签名失败。快检结束后仅更新本验证记录与计划，功能源码未再变化；文档同步与 diff 检查单独复验。

## 尚未具备的资格

本轮没有真实模型、外网调用或 field 采集，也没有运行新签名工作流。历史 `5.0.0-rc.2` 候选与当前 ADK `8.0.5` 身份不一致，scorecard 过期，不能重标为当前资格。当前 human field、owner 审定、受治理 runner 配置和同基线 signed runtime 仍缺真实证据，整体 M5 保持阻断。

隔离工作树不包含原工作区的 reference dirty 实体；对应检查缺失不能伪造目录补齐。本地 quick 的环境与资格负结果单独保留。确定性测试、合成 verifier、独立代码复审和旧 CI 真签名各自只支持其验证范围。

归档目标是 reviewing 验证记录，不代表 owner 批准、active 晋升或产品放行。回滚通过审查本轮增量实施，不恢复生产端接受 unsigned 报告的 fallback，不删除现有证据或用户 dirty。
# PR 发布后的 workflow 上下文修复（2026-10-11）

PR #194 首次提交 `674f148306b989d42150023d2681dfe8e73a4aee` 已推送。GitHub runtime workflow 的 push 记录 `38144377913` 在创建 job 前失败（jobs 为空、无可下载日志）；没有执行模型。核对 GitHub 官方 context availability 后确认 job 级 env 不允许 `runner`，原 `PYTHONPYCACHEPREFIX` 使用 `runner.temp` 不符合上下文层级。将同一按 run_id/run_attempt 隔离的缓存路径移入准备、采集和验签三个 Python run 步骤的 env；前置 mkdir、空 PYTHONPATH、字节码限制、权限与手动成本授权保持。GitHub 根 CI 与真实 runtime workflow 的验收分别报告。

追加回归检查 job env 无 runner 上下文、三个 Python 步骤缓存路径一致并绑定 run/attempt、目录在准备步骤创建。实际六组定向回归 `91/91`、exit 0；workflow action compatibility exit 0。本轮只改 workflow 上下文和对应回归，原完整测试支持源码快照需与本次增量分别核验，旧90/90不作为新91/91的替代。

首次提交前 Runtime gate 因目标未完成而拒绝，提交命令仍执行，属于执行顺序偏差。保留本地提交及失败记录；旧混合SCM目标已 abort，拆分准备目标，核验20文件提交内容、父main、原主仓保护后，真实commit/apply gate通过，再推送和创建PR。后续修复严格先完成准备目标、门禁允许后提交，不将事后补验描述为原提交前通过。无合并、无模型或field采集，M5资格仍blocked。

官方规则：https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#context-availability
