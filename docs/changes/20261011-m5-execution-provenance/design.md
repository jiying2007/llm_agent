# 签名执行回执契约

状态：实现基线。普通本地采集是 unsigned candidate，不能直接成为 M5 runtime qualification。

## 来源与责任

唯一生产者是 canonical `jiying2007/llm_agent` 的 `software-m5-runtime.yml`，仅接受 main 的显式 workflow_dispatch。专用 runner 与受保护 environment 由维护者提供，模型二进制必须有预先审定 SHA256；运行成本和联网必须显式允许。任务固定为当前 ADK 的首个任务，默认 GPT-6.1-Sol medium；真实上游模型 header、完成响应和 usage 必须存在。生产者直接调用采集器，不提供导入任意报告后签名的操作。

签名 payload 使用 `llm-agent-runtime-execution-receipt/v1`，字段精确限定（unknown fields 拒绝）：schema、repository、workflow、ref、event、head_sha、run_id、run_attempt、evidence_payload_sha256。最后一项覆盖报告去除 execution_receipt/evidence_sha256 后的全部内容，包括 ADK、任务、执行器、collector/observer 源码摘要、模型观测与测量结果。envelope 字段精确限定为 schema、payload_base64、bundle_base64。

消费端先验证类型、范围、报告绑定，再以显式 pinned Cosign/trusted-root 验证准确 workflow identity 和 GitHub issuer。qualification 还要求 runtime 回执的 head 与 root CI/source_baseline 一致。源码摘要必须匹配当前消费源码。缺回执、错误身份、未知字段、重摘要后篡改、签名失败全部拒绝；不回退到旧 unsigned 证据。

## 生命周期与副作用

prepared → collecting → measured → signed → verified；任何拒绝进入 blocked，禁止发布资格。producer 输出必须是全新、不含 symlink 的独立路径；model 调用只能在 context/binary/source/output 预检之后发生。未完成测量不能签名，签名失败不能导出资格证据。一个 dispatch 一个有界任务，无自动重试；外部签名与模型执行未知结果须按 run/response 身份对账，不自动重放。受控 workflow 只作为可审查的采集入口，本轮不部署、不触发、不设置凭据或环境。

## 兼容性与 field

unsigned collector 保留采集用途，但显式声明 qualification_eligible=false。测试签名只能存在于隔离 synthetic fixtures；生产没有测试开关。managed-gitlink 不能凭 registry 路径获得资格：registry URL、真实 HEAD Gitlink mode/commit、独立 checkout 的 HEAD、pilot JSON 仓库与 commit 必须一致，且同一份 hash-bound JSON 同时绑定候选 ADK/操作者/pilot。reference-pin 保持其既有规则。

## 验收

正常：使用真实临时 root/ADK Git 仓库，贯通 collect → payload → envelope → production consumer；仅 inference 与密码学边界使用明确合成依赖，clean-source、task/blob/source hash 与报告校验使用实际代码。边界：当前源码/CI baseline 匹配且输出独立。异常：无签名、伪造观测、错误 workflow/HEAD、错误 Gitlink/仓库/commit、无 --allow-network，均拒绝。所有模拟仅验证代码行为，不构成真实 M5。

Git 查询以返回码判定执行失败。身份查询默认还要求非空输出；只有 clean-source 的 status 查询显式允许成功空输出。空状态表示 clean，非空表示 dirty；Git 错误、错误 HEAD、assume-unchanged 和 skip-worktree 始终拒绝。此区分不改变签名、模型权限或资格契约。

## Git 源码完整性边界

producer、collector、rollover、qualification 和 managed-pilot 的身份查询共用 `source_git`。每次调用清除继承的全部 `GIT_*`，关闭 system/global 配置、fsmonitor、hooks、外部 attributes 和 replace objects。status/diff 在读取工作树前关闭仓库配置中的 clean/smudge/process filter 及其 required 标记，禁止这些查询执行外部过滤程序；危险或无法解析的 filter 名称直接拒绝。

producer 还核实 Git 实际根与请求 root 一致。Root/ADK 的 `src/scripts/tools` 下受管 Python、shell 和动态模块必须为 regular tracked file，实际字节以 `hash-object --no-filters` 对比 HEAD blob；stat 缓存、filters 或仅 HEAD/tree 字符串匹配不能替代字节核验。资格消费端同时核对 signed CI baseline diff；未重标候选或降低既有签名契约。该检查不能提供并发恶意进程下的原子源码快照，报告继续保留 `source_snapshot_atomic=false`。

父仓 status/diff 使用 `--ignore-submodules=dirty`，避免 Git 的递归检查执行子仓本地独有 filter；gitlink HEAD 改变仍可见。producer 随后直接运行 ADK 身份与 byte 校验，不能以忽略子仓 dirty 代替子仓验收。真实回归先证明父仓 native status 会执行已注册子仓的同尺寸脚本 clean filter，再证明隔离的父/子查询与 producer 拒绝路径不执行它。
