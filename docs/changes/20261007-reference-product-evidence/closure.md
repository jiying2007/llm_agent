# 源码阶段交付与剩余证据

2026-10-08 更新。源码优化、8.0.5 发布和 Root 主分支交付已完成；当前 M5 产品资格仍然阻断。本文件将已完成阶段与未完成验收分别记录，避免早期清单被当作当前状态。

## 已完成阶段

- ADK PR181 已合并，发布版本为 8.0.5，provider commit 为 `ef5384305421700ca01e89b3df3b3f7878a70265`。Root 的 lock、接口清单、子仓引用与发布证据已消费该身份。
- Root PR190 已合并，main commit 为 `4fd1e42795ca1707cad571d49705b44f8c9c38fc`。2026-10-08 本次回读确认 PR 为 MERGED，main CI `37719692451` 为 completed/success，并绑定同一提交。
- 前轮最终冻结 Root full 为 74/74；最终串行 quick 为 51/52，唯一失败为历史 M5 资格与当前候选不匹配。以上为前轮终态证据，本次文档修改不冒充重新执行完整回归。
- 前轮独立复审覆盖 27 个交付路径，Spec/Quality PASS；本次文档补齐不纳入该历史复审范围。
- Provider 前轮归档明确返回 ARCHIVED，修正执行顺序后同内容重试返回 ALREADY_ARCHIVED、write_performed=false。候选为 reviewing，未做 owner 批准或 active 提升。首次归档在 apply gate 失败后仍被调用的执行顺序错误保留，不追溯改写为 PASS。

## 本次只读复核

固定 cosign 3.1.3、可信根与以下身份重新验证当前仓库中的 promotion-evidence.json / promotion-attestation.json，返回 `Verified OK`：

- identity：`https://github.com/jiying2007/agent-dev-kit/.github/workflows/ci.yml@refs/heads/main`
- issuer：`https://token.actions.githubusercontent.com`

当前 M5 只读诊断确认候选为 8.0.5，promotion claims 通过；运行证据版本不匹配、qualification 未绑定当前候选、历史声明不构成当前资格。诊断自身仍保守报告 promotion_signature 需要 fresh verifier readback；本次独立验签结果未被写成诊断可消费的资格回执，不能把整体诊断升级为 PASS。model_invocations=0、write_performed=false、release_authorized=false。

独立 Codex 源清单的 ADK 来源为 8.0.2、exact commit `4c8ff2c2bfa37667f17e5c9613d3298848182daa`。比较该提交与 8.0.5 provider commit，在 skills、agents、workflows、profiles、templates、manifests 范围只有 `manifests/software_m5_eval_contract.json` 变化，没有上述运行资产正文变化。`doctor --scope live` 实际返回 errors=0、warnings=0，profile=team-collab；它不证明 live 已升级为 8.0.5，也不验证真实模型效果。独立源仓已有用户修改，保持原样。

## 未完成验收与后续顺序

使用 Root 声明支持的 Python 3.11 执行 `terminal-closure --require-terminal` 和 `effect-readiness --require-evidence`，两者均按预期返回 2：software_ready=true，terminal_ready=false / effect_evidence_ready=false。总计 22 个 backlog 条目中 20 个完成，剩余 G21/G22，没有意外未完成软件条目。G22 当前有效测量覆盖 0/86（13 agent、65 skill、8 profile），没有 owner decision。该汇总与 M5 是独立验收线。

首次误用系统 Python 3.8 执行这两个入口，触发 Path.is_relative_to 不存在的异常；Root pyproject.toml 明确 requires-python >=3.11。切换已安装的 3.11 环境后返回正常阻断投影，没有为不支持的解释器改写生产代码。

1. 将固定身份的 fresh 验签结果接入当前候选资格流程，回执必须绑定证据、attestation、verifier、可信根与候选身份；不得用非空 bundle 或历史 PASS 代替。
2. 当前候选需要新的真实运行实测证据；现有授权是先落地评测工具、暂不调用模型，所以本轮不能执行该实测，也不能用离线 fixture 替代。
3. 基于当前候选实测、签名及已有 field 证据审查新的 qualification/declaration，保留历史记录，缺项继续阻断。

G21 后续入口是经过认证、固定 runtime 版本的 direct-target discovery/load/trigger campaign，再完成 typed receipt 签名、managed registry 绑定及 production loader 验证，跟踪于 agent-dev-kit#153。G22 后续入口是冻结真实干预与模型 revision 的预注册包，先签名再按 budget/checkpoint 执行 campaign，随后接收真实 managed receipts、重算测量并完成逐资产 owner review，跟踪于 llm_agent#154。小规模试点不能被声明为 86 项资产整体资格完成。

本次未执行 source-to-live。未来有运行资产内容变化时，仍必须走 build、doctor、plan、apply dry-run、apply、check，并保留本机有效配置。参考目录仍隔离，内容身份复审不等于内容批准；参考复审有效期至 2026-10-14。

## 可回读入口

- [ADK PR181](https://github.com/jiying2007/agent-dev-kit/pull/181)
- [ADK 8.0.5 Release](https://github.com/jiying2007/agent-dev-kit/releases/tag/v8.0.5)
- [Root PR190](https://github.com/jiying2007/llm_agent/pull/190)
- [Root main CI](https://github.com/jiying2007/llm_agent/actions/runs/37719692451)
