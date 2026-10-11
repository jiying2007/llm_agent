# 真实 runtime 采集与资格交接

本入口尚未发布或执行。默认只提供可审查源码；没有模型调用、没有新 M5 资格。

## 前置条件

1. 维护者审查并发布 `software-m5-runtime.yml` 和对应生产/消费源码到 canonical main；本任务不自动 commit/push/merge。
2. 提供专用 `m5-runtime` self-hosted Linux x64 runner 和 `software-m5-runtime` environment，维护者配置实际访问控制、必要的人类审批与 runner 隔离。声明 environment 名称不证明其保护规则已生效。
3. runner 预置真实 Codex 登录能力和经审定的实体二进制；设置 environment 的 `M5_RUNTIME_BINARY`、`M5_RUNTIME_BINARY_SHA256`。不从 requested model、Git、usage 历史或聊天身份推断操作者或模型。
4. 提供经审定的 `M5_COSIGN_SHA256`、`M5_TRUSTED_ROOT_SHA256`、`M5_TRUSTED_ROOT_BASE64`。GitHub OIDC 只允许该专用 job；任何签名缺项必须拒绝。

发布前验证必须包含 producer 正常流程，而不仅是权限拒绝和 workflow 结构检查。从源码根运行 `PYTHONPATH=tests:. python3 -m unittest test_m5_execution_provenance`；其中真实 Git fixture 必须通过 clean 正例、dirty/隐藏 index 负例和离线 collect/envelope 流程。该测试的 inference/签名均为合成边界，不能作为实际 dispatch、模型或签名成功证据。

当前源码检查还必须覆盖 fsmonitor、继承 Git 环境、同 stat 脚本篡改和父/子仓 filter 副作用负例。不要只检查 HEAD/tree 或 native status：受管 `src/scripts/tools` 执行源码须匹配实际 HEAD blob。父仓检查跳过子仓 dirty 递归后，ADK 必须通过独立、禁 filter 的源码验收；gitlink HEAD 改变仍拒绝。失败时保留 blocked，不重新启用 filters、fsmonitor 或 unsigned fallback 来放行。

## 有界操作

仅在准确 main HEAD 上显式 dispatch，选中 `approve_network_and_cost=true`。源码入口固定采集 GPT-6.1-Sol medium、当前 ADK 固定任务集首个任务、一个请求；无自动重试。拒绝工具调用、非完成响应或缺真实上游模型 header。未观测到模型身份时终止，不补填 requested/config/payload model，不改默认模型绕门禁。

生产者在调用模型前核查 source HEAD/clean、隐藏 index、实体 binary pin 和全新独立输出。正式 workflow 先核 Cosign pin 和公开 trust，再采集、签名、独立离线验签，仅上传 `software-m5-runtime-signed`。原始报告和 unsigned 候选不导出为正式资格。失败时保留 run 身份；未知结果先对账，不盲目重放。

CLI（从仓库外也可通过安装包运行）只有 `collect` 和 `envelope`，没有接受任意历史报告生成 signable payload 的命令。缺 `--allow-network --approve-unknown-cost` 的 collect 会在模型调用前拒绝。普通 runtime-smoke collector 仍可生成 unsigned candidate，其 CLI 明确返回 `qualification_eligible=false`。

## 回读与最终资格

下载 signed artifact 后，用 explicit pinned Cosign/trust 消费；它必须绑定该报告全部测量内容、collector/producer/observer 源码和 source baseline。root CI 回执、runtime 回执和 qualification source_baseline 必须相同。若主分支在此后有源码变化，应先建立匹配的新证据，不能重标旧回执。

field 需要真实当前候选事件、受管独立仓 exact commit 与人类操作者证据。managed gitlink 路径还必须有实际 160000 Gitlink、匹配的独立 clean checkout/origin、无隐藏 index 标志，并在同一份 hash-bound pilot JSON 中绑定候选/仓库/commit/操作者。GROS/A123X 的使用记录或 reviewing 档不是 field 事实；其路由与契约治理未完成前不自动启动正式 pilot。

最后才运行 rollover 完整事务，完成 qualification/scorecard/current-status 的当前证据验收。历史 5.0.0-rc.2 不改日期、不重标身份；真实模型、field、owner、签名和最终声明分别核验。M5 之外的 owner/产品资格仍按各自策略验收。

## 回退

本轮源码保留在隔离 worktree，原 main、子仓与 live 未改。签名消费升级是有意的收紧：旧 unsigned runtime 继续可作候选，但不能再被接受为正式 runtime qualification。禁止以恢复 unsigned fallback 作为发布回退；运行失败时维持 blocked 并保留已生成证据。
