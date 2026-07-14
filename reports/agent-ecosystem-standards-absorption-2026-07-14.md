# Agent 生态标准与优秀实践吸收报告（2026-07-14）

## 结论

本轮筛选出 7 个高质量一手来源，形成 5 项 method-only 采纳和 2 项 watch-only 决策。落地范围限定为 `agent-dev-kit` 的平台中立治理契约、fixtures 与静态门禁：不复制外部实现，不安装依赖，不启用 MCP/ACP/A2A/OTel/GitHub runtime，也不把协议或 registry 元数据误当作运行时安全证明。

最值得立即吸收的四条实践是：

1. Skill 使用可移植的目录与 `SKILL.md` 最小格式，同时保留渐进披露。
2. Agent 安全评审使用 OWASP ASI01-ASI10 做覆盖 taxonomy，并要求每项落到本地 control 与 evidence。
3. 自动化写操作采用“read-only reasoning agent -> schema/policy validation -> separate least-privilege executor”。
4. MCP 依赖必须记录 namespace、version、digest、review、freshness 与 trust decision；registry listing 只用于发现，不等于认证。

## 范围与方法

- 检索优先级：官方规范 / 官方仓库 / 官方安全项目；不以 stars、博客转载或 marketplace 排名作为信任证据。
- 复核日期：2026-07-14。
- 吸收原则：先查既有 SSOT，再做最小增量；外部内容只提取可复用 claim，不复制代码或长段文档。
- 验收方式：跨 manifest checker、正向 clean-room bundle、单故障负向 fixtures、strict/full regression。
- 明确排除：外部 package install、submodule、connector、网络写操作、runtime compatibility claim。

## 来源质量与决策

| 优先级 | 一手来源 | 关键事实与可借鉴点 | 许可证 / 漂移 | 决策 | ADK 落点 |
|---|---|---|---|---|---|
| P0 | [Agent Skills specification](https://agentskills.io/specification) / [reference repo](https://github.com/agentskills/agentskills) | Skill 目录至少含 `SKILL.md`；`name`、`description` 必需；metadata、instructions、resources 分级加载 | code Apache-2.0；docs CC-BY-4.0；规范会演进 | adopt-method-only | `skill_reproducibility_contracts.json` |
| P0 | [OWASP Top 10 for Agentic Applications 2026](https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/) | ASI01-ASI10 提供目标劫持、工具误用、身份权限、供应链、代码执行、记忆污染、Agent 通信、级联失败、人机信任和 rogue agent 的完整 taxonomy | CC-BY-SA-4.0；年度 taxonomy | adopt-method-only | `adk_runtime_policy_gates.json` |
| P1 | [GitHub Agentic Workflows safe outputs](https://github.github.com/gh-aw/reference/safe-outputs/) | reasoning job 保持只读；模型只产生结构化动作请求；独立 permission-controlled job 校验并执行；支持操作上限和 staged mode | MIT；0.x/快速变化，30 天复核 | adopt-method-only | `automation_worktree_contracts.json` |
| P1 | [MCP Registry](https://github.com/modelcontextprotocol/registry) | 发布时验证 namespace ownership，可作为 publisher provenance；仍需 version/digest/runtime review | 当前 Apache-2.0，历史 license/版本需逐项复核；30 天复核 | adopt-method-only | `skill_mcp_dependencies.json` |
| P1 | [OpenTelemetry GenAI semantic conventions](https://github.com/open-telemetry/semantic-conventions-genai) | 提供 Agent、tool、workflow、eval/MCP 的 telemetry vocabulary；当前 schema URL 为 `gen-ai/1.42.0` | Apache-2.0；实验性、快速演进 | adapt-method-only | `trace_eval_contracts.json` optional adapter |
| P2 | [Agent Client Protocol](https://github.com/agentclientprotocol/agent-client-protocol) | editor/IDE 与 coding agent 的协议；stable wire protocol v1，schema artifact 版本与 wire version 需区分 | Apache-2.0；远程支持仍演进 | observe-method-only | external ledger watch contract |
| P2 | [Agent2Agent Protocol 1.0](https://a2a-protocol.org/latest/specification/) | 面向独立 Agent 的发现、任务、消息与 artifact 互操作；与 MCP 职责互补 | Linux Foundation / Apache-2.0；v1.0.0 | observe-method-only | external ledger watch contract |

## 采纳、适配、观察与拒绝

| 决策 | 内容 | 理由 |
|---|---|---|
| adopt | Agent Skills portable minimum | ADK 已有 target renderer，只需补开放格式 provenance、字段约束和 conformance evidence，不应重做 compiler |
| adopt | OWASP ASI01-ASI10 crosswalk | 补齐安全覆盖语言，但必须明确“静态 taxonomy != runtime security certification” |
| adopt | safe-output executor separation | 可直接补强 automation 的 least privilege、验证、operation cap、kill switch、审计与回滚 |
| adopt | MCP provenance fields | 能把 registry discovery 与供应链 trust 分离，避免 auto-install 和 namespace 过度信任 |
| adapt | OTel GenAI adapter | 只保留版本 pin 与稳定字段映射；ADK 原生 evidence 不丢失，敏感 content capture 默认不可 opt-in |
| observe | ACP v1 | 目前没有 editor transport 交付目标；启用前需具体 client/agent、auth、compatibility fixtures 和 rollback |
| observe | A2A 1.0.0 | 目前没有跨 Agent 网络 transport 需求；启用将扩大身份、发现、消息和远程执行攻击面 |
| reject | 复制外部仓库实现或引入 submodule | 超出 method-only 吸收边界，增加供应链、更新和许可证成本 |
| reject | 新建 ecosystem mega-manifest | 会与既有领域 SSOT 形成第二 owner；采用“来源集中、契约归域、跨 manifest 校验” |
| reject | registry listing / protocol metadata 作为 trust 或 compatibility 证明 | provenance、compatibility、runtime security 是不同证据层，不能互相替代 |

## 已落地资产

- 来源与 watch 决策：`agent-dev-kit/manifests/external_agent_pattern_contracts.json`
- Portable Skill：`agent-dev-kit/manifests/skill_reproducibility_contracts.json`
- OWASP ASI crosswalk：`agent-dev-kit/manifests/adk_runtime_policy_gates.json`
- Safe output：`agent-dev-kit/manifests/automation_worktree_contracts.json`
- MCP provenance：`agent-dev-kit/manifests/skill_mcp_dependencies.json`
- OTel adapter：`agent-dev-kit/manifests/trace_eval_contracts.json`
- 跨域 checker：`agent-dev-kit/scripts/check-agent-ecosystem-standards.sh`
- 正负 fixtures：`agent-dev-kit/fixtures/agent-ecosystem-standards/`
- 回归测试：`agent-dev-kit/tests/test_agent_ecosystem_standards.sh`
- 变更证据：`agent-dev-kit/docs/changes/agent-ecosystem-standards-hardening/`

## 安全映射摘要

OWASP taxonomy 在 ADK 中不是一份复制文档，而是以下 control/evidence 路由：

| ASI | 本地主要落点 |
|---|---|
| ASI01 Agent Goal Hijack | untrusted data、instruction precedence、scope-change approval |
| ASI02 Tool Misuse and Exploitation | least-capability tools、schema/policy validation、rollback |
| ASI03 Identity and Privilege Abuse | credential isolation、permission profiles、approval audit |
| ASI04 Agentic Supply Chain Vulnerabilities | version/digest/license/provenance、method-only default |
| ASI05 Unexpected Code Execution | sandbox、command approval、hooks/runtime disabled by default |
| ASI06 Memory and Context Poisoning | memory default-off、source/raw fallback、redaction/review |
| ASI07 Insecure Inter-Agent Communication | sender/scope/output contract、schema/auth boundary、protocol watch-only |
| ASI08 Cascading Failures | retry budget、checkpoint、operation cap、kill switch |
| ASI09 Human-Agent Trust Exploitation | claim-to-evidence、independent verifier、structured write review |
| ASI10 Rogue Agents | least privilege、heartbeat/stop、scope-drift escalation |

## 负向证据

新增 fixtures 证明以下情况必须失败：

- portable skill 缺少 `description`；
- ASI01-ASI10 覆盖不完整；
- reasoning agent 获得直接写权限；
- MCP dependency 缺少 `artifact_digest`；
- OTel adapter 开启敏感 content capture；
- watch-only ACP/A2A 条目开启 runtime。

此外，重复修改 Skill compiler、新建平行 mega-manifest、直接启用 ACP/A2A runtime 三种方案均已在 change 的 `negative-results.md` 中记录为不采用。

## Freshness 与复审

- `gh-aw`、MCP Registry、OTel GenAI：`expires_at=2026-08-13`，快速变化，30 天复核。
- Agent Skills、ACP、A2A：`expires_at=2026-09-12`，60 天复核。
- OWASP Agentic Top 10：`expires_at=2026-10-12`，90 天复核。
- 到期只触发只读复核；不得自动升级 dependency、runtime 或 install scope。

## 验证状态

- 已通过：`rtk agent-dev-kit/scripts/check-agent-ecosystem-standards.sh --summary-json`，结果覆盖 283 项检查、7 个来源、10 个 ASI 分类、6 个负向 fixtures，`runtime_enabled=false`。
- 已通过：`rtk agent-dev-kit/tests/test_agent_ecosystem_standards.sh`。
- 已通过：`rtk agent-dev-kit/scripts/validate-assets.sh --strict`。
- 已通过：`rtk agent-dev-kit/tests/run_all.sh --quick --fail-fast`，18/18。
- 首轮 full regression 在 `test_no_external_repo_refs` 发现 change task 绑定本机参考仓名称；已改为通用 dirty-reference boundary，并保留负结果。
- 修复后已通过：`rtk agent-dev-kit/tests/run_all.sh --fail-fast --timing-json /tmp/agent-ecosystem-full-timing.json`，52/52，耗时 365989 ms。
- 已通过根仓 `check-doc-sync`、`check-agents-coverage`、`check-adoption-matrix-status`、`check-adk-target-evidence` 与 `check-token-budget --summary-json`。
- 已通过：`rtk scripts/check-adk-harden-readiness.sh . --skip-full-suite`；full suite 已由上一条独立执行，不重复运行。
- 实现阶段根仓 `rtk scripts/check-all.sh --quick` 首次为 54/56；唯一底层原因是 strict `agent-dev-kit` 子仓尚未提交，`check-subrepo-state` 及其上层 `check-current-status-consistency` 按设计失败。
- 获得明确提交/推送授权后，ADK 已提交为 `0d25f3d`；根仓以 `agent_dev_kit_release_commit=dd67b48` 保留 RC2 制品证据、以 `agent_dev_kit_commit=0d25f3d` 记录当前治理基线，并验证两者之间无 runtime 映射资产变化。最终根仓 quick 门禁为 56/56。
