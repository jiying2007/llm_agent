# 本阶段验证记录

2026-10-08。本阶段只新增方案、内容身份清单和交付记录，不修改生产行为或真实资格。验证由主 Agent 执行，未声称新增独立子代理或 human owner 审查。

| 命令／检查 | 实际结果 | 验收层级 |
|---|---|---|
| Python 3.11 unittest discover：test_effect_planning.py | 3 tests，OK，1.503s | 离线准备、不覆盖输出、严格 JSON 负例 |
| Python 3.11 环境下 test_effect_preregistration_builder.sh | PASS，exit 0 | 内容派生引用、复验、拒绝覆盖／漂移／标签假干预；synthetic fixture |
| Python 3.11 环境下 test_native_target_readiness.sh | PASS，exit 0 | 软件就绪与真实 native 证据分离；不执行认证 campaign |
| 从 /tmp 读取当前 Manifest 并逐项重算清单 | PASS，86 项 content_ref 全部精确一致、无重复 | 实际 source 身份；不计入 measured |
| 方案权限及未确定输入核对 | 全部权限 false，actual_model_calls=0、approved_cost_usd=0、immutable_model_revision=null | 当前授权边界 |
| git diff --check | exit 0 | 文档差异格式 |
| scripts/check-doc-sync.sh . | PASS，exit 0 | 文档与治理同步 |
| validation_plan --root . --summary-json | L1，documentation/evidence-only | 必需门禁为 diff/doc-sync；无需重跑 source full |

初次终态投影误用了系统 Python 3.8，因 Root requires-python >=3.11 而异常；使用 3.11 后 terminal-closure --require-terminal / effect-readiness --require-evidence 均返回预期 exit 2，software_ready=true、terminal/effect=false。该负结果保留在上一阶段 closure，没有将环境错误归因生产逻辑，也没有兼容性改写。

边界核对：未调用真实模型、未执行 G21/G22 认证 campaign、未 dispatch signing workflow、未覆盖用户 dirty 或 live、未填写 owner approval。8.0.2/8.0.5 资产正文无干预差异，计划明确要求先选择真实干预，不生成假 frozen package。当前待审查的是方案，M5 与全局 terminal 的缺项继续保留。

文档回滚可通过后续普通 revert 撤销本阶段提交；不涉及 runtime 回滚或删除历史 evidence。本记录不替代 CI 的 exact-head 回读，SCM 终态在实际交付后登记。

提交前门禁首次拒绝：goal 尚 active 且缺少 scm-readback；未继续提交。原计划错误地把提交后回读列为提交前 complete 的条件，形成循环。显式 replan 终止该错误计划，保留原用量与失败，改为先验收 source/离线验证的本地 local-ready，再执行已授权 SCM。当前 local-ready goal 为 task-e851ce5cf781d03ca2c78994；累计前缀、阶段分配与转场保留余量相加不超过9000万。此 replan 不改变真实资格或模型权限，不用旧 SCM 代替新方案交付。
