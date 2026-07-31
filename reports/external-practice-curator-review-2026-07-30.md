# 2026-07-30 外部实践新一轮 Curator Review

## 结论

本轮完成了多来源 live intake、官方来源 ledger 复核、GitHub 定向发现和三项高信号 candidate 归一化。结果不是“发现越多越好”：118 个 cycle candidate 中，69 个来自已治理 official manifest、19 个来自既有 WeChat metadata catalog，真正新增的 30 个 GitHub live candidate 多数是新建/低证据 harness 仓。经 duplicate、架构、license、安全和维护成本审查后：

- `epc-c6f947d482aa8aa0c78f`（MCP 2026-07-28 final refresh）：唯一达到 `ENHANCE-ready / pending-owner-decision` 的增量，目标是增强既有 MCP compatibility staging，不新增 runtime。
- `epc-5a312f5a4fb1b05957d4`（StrongDM Attractor）：`OBSERVE`；存在可借鉴的 loop/steering/abort/output-bound 方法，但与 ADK 平台中立控制面定位及既有 runner/harness contracts 高度重叠。
- `epc-46da08e2db5a59e486ec`（Harness Evals）：建议 `REJECT-as-dependency / OBSERVE-vocabulary-only`；五维评测框架与 ADK eval、trace、repository process/cost/safety contracts 重复，当前没有安装依赖的净收益。

以上都是 curator 建议，不是 owner decision。根据仓内合同，没有独立人类对具体 candidate 签署 decision 前，不创建 ADK implementation change、不写 adoption matrix、不启用 runtime、不发布。

## 搜索问题与策略

决策问题：哪些 2026-07-30 仍然新鲜、可验证、平台中立且相对 ADK 现有资产有净增益的外部实践，值得进入下一轮 owner decision？

来源层：

1. 统一 provider cycle：GitHub/GitLab/Gitee live repository metadata。
2. 已治理官方来源：OpenAI、Anthropic freshness manifest。
3. 已治理二级来源：WeChat metadata-only catalog，不读取/保存正文。
4. 定向 primary source：上游 GitHub repository、release/tag、license、官方产品文档。
5. 本地 duplicate evidence：adoption matrix、ADK manifests、change artifacts、tests。

主要查询：

- `agent coding workflow skill harness`
- `AI Agent Skill Workflow`
- agent coding harness/evaluation、MCP 2026-07-28 final、ACP/A2A、coding loop spec、agent eval framework

排除：

- archived/disabled、license 不明且无额外证据、纯 prompt 集合、个人 dotfiles、平台营销包装；
- 与已吸收 capability 重复却没有测试/性能/安全净增益；
- 需要 clone/install/执行外部代码才能判断的候选；
- 以 star、来源权威或“官方”代替工程判断的候选。

## Cycle Evidence

| Provider | Status | Ledger candidates | Interpretation |
|---|---|---:|---|
| GitHub | complete | 30 | live metadata 成功；需逐项 review |
| GitLab | complete | 0 | 查询成功但未命中，不等于生态无候选 |
| Gitee | degraded-empty | 0 | 按合同保留退化，不能声明 source clean |
| OpenAI official | complete | 64 | 来自既有 freshness manifest，主要是已有治理来源 |
| Anthropic official | complete | 5 | 来自既有 freshness manifest |
| WeChat | complete | 19 | 原始 20，跨源去重 1；metadata-only |

总体：`degraded`，ledger=118，deduplicated=1。所有 candidate 保持：

- `review_status=review-required`
- `body_persisted=false`
- `auto_actions=[]`
- 未 clone、未执行外部代码、未注册子仓、未修改 live runtime

GitHub license 分布：

- MIT：18
- Apache-2.0：1
- NOASSERTION：2
- unknown：9

11/30 GitHub candidate 带 `license-review-required`。license 合法只是必要条件，不代表架构价值。

## 定向候选审查

### C1 MCP 2026-07-28 Final Compatibility Refresh

- candidate：`epc-c6f947d482aa8aa0c78f`
- source：`https://github.com/modelcontextprotocol/modelcontextprotocol`
- candidate revision：`41d9e938e9a9edf23a69429be180cad172e00f4e`
- final release tag：`2026-07-28`
- final tag commit：`5f5440bb26a62e2cf3440b92da5a667efa03b267`
- release：2026-07-28T16:47:49Z，`prerelease=false`
- license：repository 为混合过渡；新 code/spec contributions Apache-2.0，未完成 relicensing 的旧贡献 MIT，非 specification 文档为 CC-BY-4.0。按文件/用途复核，不能简单写成单一许可证。

#### 可借鉴优点

- 把现有 `2026-07-28-rc` staging 刷新为 final released evidence。
- 用 final tag/commit 替代“公告将发布”的未来事实。
- 复核 RC→final breaking diff、auth hardening、schema/extension/task lifecycle 和 deprecation。
- 继续复用现有 active/candidate/activation/rollback contract，不新增第二套 validator。

#### 不可迁移/拒绝边界

- 不自动把 active protocol 从 `2025-11-25` 切到 `2026-07-28`。
- 不启用 Tasks、Apps、extensions、remote server、network discovery 或 OAuth flow。
- 没有 version-pinned client/server smoke、schema fixture、auth review 和 rollback smoke 时，不声称 compatibility。
- 不从混合许可证仓复制规范正文或 SDK code。

#### Duplicate 与架构

ADK 已有：

- `external_agent_pattern_contracts.json:mcp-2026-07-28-rc`
- `skill_mcp_dependencies.json:protocol_compatibility_policy`
- positive/negative fixtures，阻断 RC 误当 final、runtime enable 和 weak auth
- `20260724-mcp-2026-compat-staging` change artifact，明确要求 final 后独立复核

因此资产形态只能是 `ENHANCE`，不能新增 Skill/Workflow/manifest。

#### Curator recommendation

`ENHANCE-ready / pending-owner-decision`：

- source ID 从 RC provenance 演进到 final provenance；
- candidate `protocol_version=2026-07-28`、`release_status=released`；
- `final_spec_retrieved=true` 只表示 source 已取回，不表示 compatibility；
- `compatibility_test` 仍为 not-run，`runtime_enabled=false`、`final_compatibility_claim=false`；
- 保留 active `2025-11-25` 和现有 rollback。

进入 proposal 前仍需独立 owner decision，理由必须接受“只刷新 final staging，不激活 runtime”的边界。

### C2 StrongDM Attractor Coding Agent Loop NLSpec

- candidate：`epc-5a312f5a4fb1b05957d4`
- source：`https://github.com/strongdm/attractor`
- revision：`fb57a55ed97372a27ac90102f436947e29f48426`
- license：Apache-2.0
- metadata：约 1253 stars / 196 forks，15 commits，无 release；最后 source push 2026-03-17。

#### 可借鉴优点

- 把 tool round、steering/follow-up、abort、loop detection、output truncation 和 execution environment 分成显式 loop contract。
- 定义可编程事件流与 definition-of-done，不只包装黑盒 CLI。
- 环境变量过滤、timeout 和 tool result 截断有明确安全/性能意义。

#### 不可迁移/拒绝边界

- Attractor 是 coding runtime NLSpec；ADK 的存在意义不是实现 LLM/tool runtime。
- provider-aligned tool/prompt profiles可能把平台专属假设带入 core。
- “把完整 NLSpec 交给 coding agent 实现”不满足 ADK 的独立需求/设计/测试和版权最小化要求。
- 无 release/version discipline；star 不能替代维护和兼容证据。

#### Duplicate 与架构

- ADK 已有 `adk_runner_contracts` 的 `turn/steer`、runtime API boundary、tool/permission contracts。
- 已有 harness-loop、retry/timeout/cancel、sandbox、artifact lineage、context compaction 和 completion evidence。
- 当前缺口更偏真实 runtime/field evidence，不是另造 coding loop。

#### Curator recommendation

`OBSERVE`。只有未来出现明确 ADK runner API 缺口并通过 owner decision 时，才允许把“bounded tool rounds、abort/steering event、output truncation evidence”合并到既有 runner/harness contract；不安装、不实现 Attractor、不复制 NLSpec。

### C3 Harness Evals

- candidate：`epc-46da08e2db5a59e486ec`
- source：`https://github.com/harness/harness-evals`
- revision：`7828ffa93c597c9e66a866a122c62a21e94376e0`
- license：Apache-2.0
- metadata：约 14 stars / 7 forks / 22 open issues，2026-07-28 有更新。

#### 可借鉴优点

- correctness、groundedness、safety、trajectory、performance 五维语言易于沟通。
- typed `EvalCase`/`Score`、threshold、CI/JUnit、OTEL/Langfuse adapter 体现工程化方向。

#### 不可迁移/拒绝边界

- 安装 Python eval framework 会增加依赖、provider adapter 和长期升级成本。
- LLM-as-judge、生产 trace adapter 和 prompt-injection metric 需要数据/隐私/成本单独审查。
- 低 adoption 与较多 open issues 不适合作为 ADK 发布门禁依赖。

#### Duplicate 与架构

ADK 已有：

- deterministic routing/effect suites、positive/negative/adversarial cases；
- trace-eval bundle、prompt/model/dataset version 与 regression link；
- repository evaluation 的 functionality、安全、process validity、token/cost/latency/cost-per-success；
- OpenTelemetry adapter 与 sensitive content default-off。

五维 taxonomy 没有足够净增益来支持新依赖或平行 workflow。

#### Curator recommendation

`REJECT-as-dependency / OBSERVE-vocabulary-only`。不新增 Skill/Workflow/script；如 owner 认为 trajectory 分类能改善报告可读性，只允许在现有 eval suite 的 documentation/manifest vocabulary 中 `MERGE`，并先证明不会形成双重 taxonomy。

## 其他搜索结果

### ACP/A2A

- A2A 1.0 已于 2026-07-14 进入 watch-only contract；本轮没有跨 Agent transport 新需求，维持 observe。
- Agent Client Protocol 已有 stable wire protocol v1 watch。GitHub Copilot CLI ACP server 是真实 target adoption 信号，但没有改变 ADK “无具体集成目标不启用 transport”的架构结论。

### GitHub live 30

多数候选为 2026-07 新建的个人 harness、dotfiles、skills 或 workflow 包。即使 MIT，也普遍缺少：

- release/tag 与兼容策略；
- security policy、威胁模型、权限/凭证边界；
- 稳定测试/CI、真实效果和维护周期；
- 相对现有 ADK capability 的净增益。

其中 `harness/harness-skills` 虽为 Apache-2.0，但主要是特定 Harness 平台技能集合；没有理由复制成 ADK core。全部维持 `review-required`，不批量写 decision。

### Official 与 WeChat

- OpenAI/Anthropic candidate 是已治理 official manifest 的再投影，不重复创建资产。
- WeChat 只保留 metadata 与负证据；版权受限、secondary source、未读取正文，不能直接形成实现结论。

## Owner Decision Request

当前只有 C1 值得进入独立 decision。建议 decision 形态：

```json
{
  "schema_version": "external-practice-decision/v1",
  "candidate_id": "epc-c6f947d482aa8aa0c78f",
  "decision": "ENHANCE",
  "owner": "<independent-human-owner>",
  "reviewed_at": "2026-07-30",
  "rationale": "<至少二十字；明确仅刷新 final compatibility staging，不激活 runtime>",
  "target": "agent-dev-kit/manifests/skill_mcp_dependencies.json",
  "evidence_refs": [
    "reports/external-practice-curator-review-2026-07-30.md",
    "reports/external-practice-targeted-evidence-2026-07-30.json"
  ]
}
```

若 owner 不接受 license/compatibility/pilot 边界，应选择 `OBSERVE`，不是弱化 Gate。

## Gate Result

- source：pass/degraded 分离；MCP exact tag 证据已补，Gitee 保持 degraded-empty。
- duplicate：pass；三个 candidate 均完成现有资产检索。
- license/security：MCP mixed license 需逐文件审查；Attractor/Harness Evals 为 Apache-2.0，但不授权复制/执行。
- architecture：pass；不新增 Agent/Skill/Workflow，优先 ENHANCE/OBSERVE/REJECT。
- decision：`blocked-pending-independent-owner`。
- implement/pilot/publish：`not-run`，且在 decision 前禁止。
