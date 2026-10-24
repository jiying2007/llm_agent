# Root F3 与八文件恢复的独立只读审核

## 结论与范围

**Spec PASS / Quality PASS，无新增实质性缺陷。** 此结论限定于本次冻结的 F3 真实输入覆盖、常驻严格预算门禁、README 原有禁止词约束和八文件恢复内容。reviewer `/root/release_governance_audit` 未实现 Root 本范围；此前只实现了另一个仓库的 ADK F2。审核中没有修改 Root 源码、fixture、配置、版本或远端。

原始观测与可归档的精确来源、执行时间、命令、stdout/stderr SHA-256 保存在 `review-summary.json` 和逐项执行 JSON。该原始审核记录不充当受保护提交、合并、正式发布或运行资格授权；后续提交须绑定同一源码内容并保留独立的完整回归证据。

审核时间：**2026-10-24 15:58:34.001821–16:03:31.810813 UTC**。

## 八文件恢复：独立核验 8/8 一致

从冻结恢复清单读取 old/new blob，先与当前 HEAD `64c5192f2d6aaacf65143223f03190564032facc` 的原 blob 对照，再直接按 Git 对象编码重算当前文件 blob。七项存在文件逐字节一致，一项删除文件确实不存在。随后从 HEAD 全部 tree entries 出发，仅应用这八项恢复，递归重算整棵 Git tree，精确得到：

`d7f1319c90c70e989978c6b7e1984df2be59e66b`

这验证的是**八文件恢复单独形成的 tree**。当前 F3 配置和 status projection 的新变化另行审核，不把整个当前工作树冒充成该历史 tree。

原历史 review/consolidation 证据的字节没有被改写；报告正文合并与对应矩阵、removal 摘要恢复均属于上述八项。`reports/current-status.md` 的额外变更经差异检查和原 status-projection consumer 核验，只更新 `projection_inputs_sha256`；历史验证字段和产品放行事实未变。

## 实际消费者与最小调度范围

- `maintenance-budget` 直接调用原 `scripts/check-maintainability-budgets.sh --strict --summary-json`，常驻 `contract`，禁用缓存，没有添加 `integration-deep` 标签。
- 14 项预算配置与 HEAD 完全一致，没有修改阈值、排除项或原检查器。独立实际运行返回 pass，报告数 **320 / warning limit 320**，warnings 为空。
- 已有 gate 的业务参数、依赖、错误处理和权限声明保持不变；仅 `root-regression` 增加真实消费者输入。impact 算法和 GitHub workflow 保持原字节。
- GitLab 保留 `GIT_SUBMODULE_STRATEGY: none`，只在 contract 前初始化 ADK gitlink；继续调用同一个 gate runner，没有新增平行 CI 权威。
- README 普通说明不触发深度回归，但常驻 active-contracts 保留旧 shell 回归对 `hermes-agent` / `Hermes Agent` 的禁止词检查，且实际运行仍使用当前日期。
- README、无关 docs/architecture、docs/changes、docs/runbooks、普通报告和无关 optimization 说明的深度调度仍为 NOT_REQUIRED；普通报告仍由严格预算检查负责。

## 独立执行结果

| 执行 | UTC 开始 | 耗时 | 实际结果 |
| --- | --- | --- | --- |
| 全部 gate 边界回归 | 15:58:34.001821 | 11.397 秒 | **24/24 PASS**；含真实输入破坏、两路预算、路径编码、rename、cache 和进程超时 |
| 自建恢复/调度/rename/delete 反例 | 15:59:47.218499 | 0.415 秒 | **PASS**；七文件+一删除精确匹配，恢复 tree 精确匹配 |
| 原严格维护预算 | 16:00:05.002425 | 0.716 秒 | **PASS**；14 项、320 报告、0 warning |
| 当前日期 active-contracts | 16:00:05.000676 | 0.066 秒 | **PASS** |
| 既有 CI-DAG 回归 | 16:00:05.012994 | 0.117 秒 | **PASS** |
| Ruff 0.16.6，改动 validator + 边界测试 | 16:00:34.708597 | 0.032 秒 | **PASS** |
| Mypy 2.3.1，改动 validator | 16:00:34.708669 | 0.866 秒 | **PASS**；严格配置，1 个 source file |
| GitLab 实际 YAML 解析与最小 checkout 检查 | 16:00:34.726862 | 0.064 秒 | **PASS** |
| 原 status-projection consumer | 16:03:29.889166 | 0.064 秒 | **PASS** |
| `git diff --check` | 16:00:05.027669 | 0.016 秒 | **PASS** |

自建反例独立复制真实 removal pass fixture 和它绑定的源材料，先取得退出 0 基线，再把 adoption evidence 重命名到普通说明目录，以及单独删除原文件。两种破坏都使原 consumer 退出 **2**，错误为 `artifact is missing or unhashed`，对应 changed paths 都要求 deep；新说明路径单独变化不要求 deep。反例只写隔离临时目录，没有修改源仓。

所有执行的源文件指纹在执行前后稳定，且与最终报告指纹一致。原始输出通过常见 GitHub token、private key、Bearer secret pattern 检查，匹配 0。

## 源码绑定

完整来源清单和恢复路径 SHA-256 在 `review-summary.json`。canonical source-set SHA-256：

`bbe66c3efc2fe1226e6f0c31e7848b1179a2928997863d0a9bcc9077296a5b77`

| 文件 | SHA-256 |
| --- | --- |
| `manifests/gates.json` | `6b946680d8cd9329b1bce74a3e3e4565634daa25203b9cde2c8af3c507d9a8be` |
| `tools/control_plane/active_contracts.py` | `4cc0a123b5588f4b13c1ca697903e2fa436b0a1deceb76ad5e474f986340f8fc` |
| `tests/test_gate_boundaries.py` | `4be7ffefc6ec608f1fe7d6564c4e5e1ed74aad165f0b2aa3e695505fc96b6eb4` |
| `.gitlab-ci.yml` | `88029613e9d856d9633cafd4995db2f95f470065c69f52d4948ae0182a6db3ee` |
| `tests/test_ci_incremental_gate_dag.sh` | `c7737a1b585d52bba90a6b7c5106d6e84fca47563fe7f9d3215dcec59d69b3bb` |
| `tests/test_gate_runner.sh` | `c9b9975467c6c966b7fdbcba852fe81fd0c308f0355213857e85f17448a8bd41` |

## 集成边界

本 reviewer 没有重复执行主线程正在运行的完整 Root suite；不得把定向审核 PASS 当作完整回归 PASS。当前新 validation plan 是 L4，早期恢复阶段的 L2 plan 已不足以覆盖当前集成范围；因主线程全套测试当时正生成临时 fixture，交付前应在其清理完成后重新冻结 plan。隔离环境没有 canonical `~/codex` Provider 与 Execution Policy owner，这些运行态步骤据实 not-run，没有转换为产品资格。
