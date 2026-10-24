# 方法吸收独立审核

Reviewer：`ai/root/external_methods`。方法吸收实现者：`ai/root`。

本 reviewer 参与了前序来源研究，但没有编写本轮 intake、decision、runbook 或 adoption matrix；本审核独立检查的是**方法吸收的实现、适用边界与价值表述**，不将自己前序研究宣称为另一份独立上游来源鉴证。

## 当前范围与状态

已实际阅读 requirements/design、12 项 sources、source metadata、candidate ledger、collection evidence、decision ledger、Owner decision、runbook，以及 source policy 的 diff。也阅读了本轮 release、output boundary 和 Root gate 责任模块的相关实现/差异，release 修复另有完整的独立 Spec/Quality 审核。

**Spec：pass。Quality：pass。METHODS-REVIEW-01 已独立复核关闭；未发现本次方法吸收范围内未关闭的 blocker 或 major。**

来源、权限、成本、收益表述、最终 adoption matrix 与真实 collector 重生语义均已核对。最终源文件与实际执行证据由同目录 `review-evidence.json` 绑定；这是方法吸收的源码/文档审核，不是完整集成交付或产品资格放行。

## 已发现的问题

### METHODS-REVIEW-01：GitHub 文件 URL 被误记为仓库名（minor，fixed）

初始审核发现：四条原始源码来源 EXT-05/06/07/08 的 `canonical_url` 与固定 revision 正确，但 candidate 的 `repository.full_name` 被记录成 `owner/repo/blob/<sha>/<path>`。旧 `_manual_repository` 把整个 URL path 用作仓库名，没有区分文件 URL 与仓库身份。

实现者已在原 collector owner 中把 github.com 的仓库归属限定为 owner/repository，处理仓库段的 .git 后缀与缺少仓库段，并通过 canonical collector 重生 ledger。canonical URL、revision、candidate ID 计算没有改动；GitLab/Gitee 的原逻辑保持，未宣称同时修复所有 forge 文件 URL 的归属。

独立复核使用真实 12 项 source metadata 再次调用公共 `scripts/practice-intake.sh collect`，输出写入临时目录。生成 candidate 与冻结 ledger **逐字节相等**；collection 除实际 duration_ms 外逐字段相同。把四项 full_name 恢复为旧值后，整个 ledger 的 SHA-256 恢复为首次独立观察到的 `82033b320cd6ce3211f9499422e96c3952476b219fad29e98cbef8afb83cf35d`，证实其余所有 candidate 字段保持不变。source metadata 与 decisions 的原始文件摘要也未改变。

额外公共入口探针覆盖 9 种 URL 形式，包括 uppercase host、blob/tree/commit、仓库段 .git、owner-only、空仓库段、GitLab subgroup 和 Gitee；同仓库同 revision 的不同文件仍产生不同 candidate ID。伪装 GitHub host 与 HTTP 输入均拒绝，并且没有留下输出文件。修复未扩大 trust、权限或自动执行范围。

## 来源到实际采用范围

| 来源 | 已检查的本地采用 | 必须保留的效果边界 |
| --- | --- | --- |
| EXT-01 / EXT-03 / EXT-05：结果评估、Agent eval 与 Skill eval | runbook 分开 routing、命令完成、产物正确、真实任务效果；当前三组缺陷用确定性失败样例和回归关闭。 | 本轮没有新的模型试验、grader 校准或真实 task outcome 样本。静态路由与本地测试不得替代 G22、Native、LTA 或 Product M5。 |
| EXT-04：harness 消融 | runbook 规定单因素比较、固定任务与预算、保留完整失败分母。 | ENHANCE 表示采纳试验方法；本轮没有测得删除 harness 组件后的质量/成本收益，也未普遍删去既有保护。 |
| EXT-06：接口与完整责任 | 现有 compiler/atomic_io、release_artifacts/archive_io/release_contract、impact/process_budget/gate_runner 继续承担其责任，没有复制外部 runner 或 Skill Pack。 | 模块数、行数、wrapper 数不作为架构收益量化；公共入口及异常行为的回归才支持此次缺陷修复。 |
| EXT-07：基准正确性 | runbook 要求实际工作、产物、原始时长、冷/热条件、完整分母；Root process budget 限制输出和执行资源。 | 资源安全修复不是已测性能优化。测试墙钟、runner-seconds、RSS、tracemalloc 不混用，未知 token/cost 仍未知。 |
| EXT-08：幂等与状态恢复 | runbook 要求先读回当前状态；当前文件输出实现增加发布前检查、准备和失败补偿，release 发布使用同一已验证快照。 | 未证明所有进程崩溃/远端响应丢失切点均 exactly-once。当前异常补偿不能被写成跨多文件和远端系统的原子事务保证。 |
| EXT-09：信任边界 | 非可信日志/模型文本/回执仍为数据；release、provenance 和产品资格保留各自 authority。 | 未引入已弃用 Agent Builder，也未通过外部文章新增逐工具人工确认流程或覆盖用户已授权操作。 |
| EXT-10：checkpoint | decision 保持 OBSERVE；runbook 解释 replay 可能再次执行外部副作用。 | 没有增加 LangGraph 依赖，也没有声称持久化模式或崩溃恢复已实测。 |
| EXT-11：不可变发布 | canonical release contract 对 tar/checksum/contract 三资产作一致性检查，dry-run 和捕获后替换已独立验证。 | 本地 mock 不证明真实远端 tag、构建主体或 asset attestation。实际发布与精确读回仍需独立 delivery evidence。 |
| EXT-02：平台退役 | 来源与 runbook 记录静态检索范围；decision 保持 OBSERVE，不新增已退役平台依赖。 | 指定执行面未发现活跃调用，只支持选型约束；不凭文档引用制造迁移缺陷，未提供部署配置仍在检索范围外。 |
| EXT-12：workflow lockfiles | sources 保留官方 how-to、Enterprise Cloud、public preview、write access 与零新增费用限制；decision 为 OBSERVE，维持 full SHA pin。 | 不无条件要求试点或升级付费计划；只有已有资格且无需新增费用才可重新评估兼容性。 |

## 已实际执行的合同检查

独立运行完整 `tests/test_external_practice_intake.sh`，包括作者新增的 8 项公共 collector metadata 用例，exit 0。审核者另行编写的 `evidence/independent-review-probes.py` 4 个测试方法全部通过（0.699 s），覆盖真实重放、精确变更范围、上述 URL 控制及 source/decision/matrix 关联。

使用仓库现有 `scripts/practice-intake.sh check` 分别检查 policy、candidate、decision、evidence，4 个命令均 exit 0。另用只读检查核对：12 个 sources、12 个 metadata、12 个 candidate 与 12 个 decision 一一对应；candidate ID 唯一；collection 的 input SHA-256 与 ledger SHA-256 均匹配实际文件；所有 candidate 均保持 `review-required`、`unverified-metadata`、`body_persisted=false`、`auto_actions=[]`。9 项 ENHANCE 与 3 项 OBSERVE 与 source 边界相符。

首次结构检查未发现 METHODS-REVIEW-01，说明合同通过不等于字段语义正确；独立语义审核指出问题后，公共行为回归和真实 ledger 重生验证共同支持本次关闭。

source policy diff 仅把 `docs.github.com` 和 `docs.langchain.com` 加入既有 manual metadata 的 HTTPS 主机允许清单并更新时间。没有放松网络显式授权、metadata-only、禁止自动 decision 或禁止外部执行等既有规则。

## 最终 matrix 与价值边界

已阅读 implementation-map 的 12 项映射及 10 项缺陷/owner 对应，并对照实际实现责任与已有独立审核。矩阵的 12 个 EXT ID 与来源、decision 一一对应；9 项 adopt 对应 ENHANCE，3 项 observe 对应 OBSERVE，目标均为 llm_agent 的方法/runbook，所列证据路径均存在。现有 structured、status、real-assets 检查均 exit 0，Markdown 与 canonical JSONL 机械导出一致。

implementation-map 与矩阵末尾明确说明：本轮 done 只代表方法采纳或观察决定、实际落点与操作说明落实，不表示真实模型效果、现场或产品资格通过。矩阵的高/中/低是方案判断，不能替代实测效果或成本。真实收益、组件发布、精确 CI 和 Root promotion 继续由各自证据证明，本文不推断完成。

最新 tasks 保留独立审核与远端资格项在实现冻结时的 pending 状态，并说明后续以单独 review/CI/交付记录为准；这与本审核通过不存在资格升级冲突。runbook 的复审日期仍只是建议，不是已创建的定时任务。

## 审核限制

- reviewer 参与了原始来源研究；此次独立性针对吸收实现和边界复核，不声称又完成一份独立上游来源鉴证。
- 本轮没有调用收费模型、下载或执行上游 Skill Pack、进行许可证许可判定、运行真实 Native/G22/LTA/Product M5 试验。
- 真实 collector 重放没有网络访问；schema/metadata/matrix 检查不能验证上游事实、所有生产动态配置或第三方身份。
- 本审核不替代后续完整集成回归、精确提交 CI、组件发布、Root 接入或已存在的真实运行异常处理。
