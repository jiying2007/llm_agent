# 独立委派来源决策

日期：2026-11-17。

Reviewer / decision owner：`delegated-source-reviewer:/root/root_source_review`。
这是本会话真实的独立 AI 审查代理身份，不是人类签署或平台认证身份。候选收集与实现由父协调负责；本代理只为当前来源吸收范围形成独立决策。用户明确实施与既有受保护交付授权由 `source-review.md` 记录，本记录不扩权。

## 决策

| 固定来源 | 决策 | 作用范围 |
|---|---|---|
| Tencent/LoopForge `e89cda9804643d3631e77652d1bca47a079adb69` | ENHANCE | 增强已有 ADK task evidence 的按需确定性诊断；不引入其运行架构 |
| github/gh-aw `bd0cded89253b8bcf1daf2dbb7a2cc623de26d69` | OBSERVE | 效果/回执语义比较 |
| langchain-ai/langgraph `02f2c2e6c992ffccce9e9129781fdd04f015c6fa` | OBSERVE | pending writes / resume 身份边界比较 |
| OpenHands/software-agent-sdk `06f643ca471eea73c662a76fef2e0b836a33c826` | OBSERVE | 事件历史与恢复反例比较 |
| openai/symphony `be10a1b79df723d6d7612b5651c8522704dafb2e` | OBSERVE | 当前资格、迟到重试身份比较 |
| OrchestratorInc/agent-orchestrator `dbd2efc638146aacf6756282ef49af6aa191a956` | OBSERVE | PR-head / feedback 归属与重复发送窗口比较 |
| deepseek-ai/dsh-superagent-prototype `8c32a9dc5d72c033816c6a8110b37f40cf94fba4` | OBSERVE | 官方原型文档的实现与资格边界 |

机器可读结果为 `decisions.jsonl`，与七条 candidate 一一对应。候选仍保持原 `review-required`、unverified-metadata 与风险标记；独立决策不倒写自动收集结果。`intake-evidence.json` 的 `decision_generated=false` 仅描述当次自动收集没有生成决策，不能因本次独立审查而改写该历史事实。

## 已独立核对的依据

- 已读本目录 source metadata、candidate ledger、intake evidence 和 source review；核对固定来源身份、声明边界与用户授权记录。
- 已读 ADK v11.3.15 / Root 固定基线的实现和相关测试：`task_evidence.py:_events/_acceptance/_import`、`trace_summary.py:TraceRunFacts`、`run_evidence.py`、`repository_evaluation.py:_validate_result`、`task_trials.py:_compare`、`execution_policy/reducer.py:reduce_events`、`goal_loop_event_context.py:build_plan`，以及现有 AAR、恢复、权限、知识晋级和 Workflow IR 合同。
- LoopForge 固定 snapshot 的 `internal/domain/workflow.go`、`internal/domain/run_eval.go`、`internal/httpapi/run_eval.go` 及相关 facts / apply / prompt 接口提供比较依据；本轮又读取原 LICENSE，确认其 MIT 声明与保留的第三方条款。未复制其源码、Prompt 或运行资产。
- 3412 blob 的全快照一致性来自协调者已保存的取证；本代理没有重新逐字审计全部源文件或执行上游软件。其余六来源保留观察，不声称本代理完成了新的全源码、许可或原生运行认证。

## C1 接受条件

仅在现有 ADK task evidence / eval 路径增加 opt-in、确定性、有界、data-only 的诊断，保持原 evidence identity、schema、结果与资格边界：

1. 缺 usage、cost、阶段时间显示 UNKNOWN / not-available，不默认零。
2. 完整失败、重试、工具调用与费用仍留在原分母；后一次成功不消除前次失败。
3. 工具次数本身不证明浪费；必须区分新输入/新证据或标需要复核。
4. 不用总墙钟减并行节点时间推算等待；没有阶段原证就不生成该推断。
5. 诊断不授予 Goal 完成、产品资格、写入权限或 release；不自动改 prompt/Skill/Gate/retry 上限。
6. 不新增 schema、调度器、Goal/控制面SSOT、定时巡检、日费硬限额、默认模型调用或第三方依赖。

已有过程指标与 AAR 是继续使用的权威，不新建 LoopForge 式评分晋级体系。若本次新增对外诊断能力，按现有 SemVer 新功能规则选 minor；仅修复既有行为才使用 patch。版本统一由父协调处理。

## C2 与既有 reducer 修复

实际宿主的恢复、权限撤销、租约、Session、Outbox 和重复副作用 conformance 仍以真实选定宿主、授权、原始 trace/receipt 和原生负例为前提。本轮不预建 adapter，不运行宿主、设备或模型，也不从离线 fixture 声称 native 资格。

在现有 `execution_policy` 中，**独立复现的 replay 正确性缺口可作为有界源码修复纳入本次**，条件是保留其具体 RED、最小确定性反例、修复后的验证和独立源代码审查，不新增运行权威或降低原事件身份/权限/收敛要求。本 intake 决策只接受这类范围，不证明缺口已经修复，也不替代后续 Spec / Quality verdict。

## 保留与交付边界

其余六来源均不采代码、Prompt、依赖、host或高权限预设；当前 unknown license保持未知，未来如拟复制或引依赖再核对。candidate 中的 agent/workflow heuristic recommendation不等于 ADOPT，也不触发参考子仓登记。

新实现仍须真实定向/完整源码验证、独立审查、受保护 main CI 和不可变发行。Root随后单独source-only晋级，保持历史M5、runtime/设备/field未认证语义。没有原生模型对照，不能宣称Token、成本或成功率已经改善。

本记录只新增当前 owner decision 与理由，不修改已有证据、候选可信度、schema或policy。复审仅在真实宿主接入、证据格式变化、具体缺口或授权范围变化时触发，不创建定时任务。

## 实际验证

2026-11-17通过指定真实RTK proxy、既有CPython3.12.14环境实际执行：

- `scripts/practice-intake.sh check --kind candidate --input reports/loopforge-adoption-2026-11-17/candidates.jsonl`：退出0，PASS，7条。
- `scripts/practice-intake.sh check --kind decision --input reports/loopforge-adoption-2026-11-17/decisions.jsonl`：退出0，PASS，7条。
- 独立只读核对candidate/decision ID集合一一对应、1条ENHANCE/6条OBSERVE、全部evidence_refs实际存在；candidate ledger及source metadata原字节SHA256均与既有intake-evidence声明相同。

上述仅证明本次intake记录和绑定有效；未执行产品测试、外部程序、模型或原生宿主验证。
