# M5 runtime ADK 依赖修复验证

verified_at: 2026-10-12
scope: root runtime workflow；未修改ADK源、模型默认值或live配置
source_base: af92f63dc91b668dd716e763ffe1f9683de7280a
independent_review: PASS（/root/m5_review；whole-diff，Spec/Quality均PASS，B/M/m=0）

真实workflow38260430071/attempt1 completed/failure。measure分配给唯一runner21，guard、准确main检出、Python、Cosign和固定task/trust准备success；collect因ADK eval帮助bootstrap缺jsonschema而失败，Sign/Export skipped。源码能力检查在真正模型command构造/执行之前退出，模型上游请求0；runner准确注销confirmed，GitHub registry回读0。没有signedruntime，本记录不替代签名或field/owner资格。

真实无模型对照：private namespace内不挂Codex auth，使用原job安装的Python3.11.12及其LD库路径；固定ADK eval帮助原exit1且ModuleNotFoundError jsonschema。执行同一Python安装root与准确ADK项目依赖后，帮助exit0，--max-new-results和--approve-unknown-cost均存在。使用ADK_PYTHON_BIN绑定该解释器。network仅依赖获取，上游模型请求0，未再dispatch。摘要 /tmp/m5-runtime-dependency-probe-result-20261012.json。

安装后追加同一authfalse namespace的完整源码核验：用该Python调用生产producer.clean_source(root, af92...)和smoke._validate_source_identity(root)，exit0、pinned-source-clean、stderr为空。root/ADK构建产生的ignored metadata未导致源码拒绝，未修改受管执行源；无网络/模型请求。

机械验证：tests/test_workflow_action_compatibility.sh PASS；scripts/check-doc-sync.sh PASS；git diff --check PASS。validation_plan为L2，未更改release关键源码或sharedcontract，实际依赖安装/help对照为定向行为验证。独立whole-diff Spec/Quality均PASS，B/M/m=0；审查者独立无auth/no-network/no-model完整源身份与clean_source核验PASS，相关provenance模块22/22 PASS（ResourceWarning为错误）。本准备验证不代表SCM、CI或真实runtime通过。

历史 af92 root签名CI仍是真实历史基线；本源码变化后必须取得新main完整signedrootCI和新的准确runtime provenance，禁止重标旧证据。单任务gpt-6.1-sol/medium、总计最多1个上游模型请求、tools关闭、server-model header、usage、签名与exactsource门槛全部保留。humanfield/owner缺证据，M5整体blocked。

Codify：修复模式为使用固定子模块项目的声明依赖及明确解释器，不推广临时runner设施为live资产；next_task_friction_reduced为消除真实ADK CLI bootstrap失败，证据为beforeexit1→afterexit0。promotion_candidate=false，原因是尚未取得真实signedruntime或人类资格review。源码回退通过独立PR反向变更，不改原用户dirty；本次临时runner注销已确认。
