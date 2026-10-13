# ADK 8.0.6 根仓导入与当前资格真实性修复

## 目标与边界

使用 canonical `jiying2007/agent-dev-kit` 的 exact source `97cf0167e837c2095d9ec6a9431f5aa8c20a812b`，版本 `8.0.6`、tree `30002831cd3e39e6f5025fd43be5307981589fe6`，真实已验签 promotion run `38333027685/1` 和 immutable `v8.0.6` 发布。根仓基线为 `5cc46b132d1fe08efe35a1e2f4fa4d3b865aadae`。

task-package v2：kind=implementation；permission=用户明确授权的隔离 root 修改、验证、独立审查及 SCM；exit=实际原子导入、fresh root 验证、独立 whole-diff review 和新 main 完整签名 CI；handoff=唯一真实模型取证及分别验收 field/owner；retention=原 dirty、旧候选和负结果保留。

primary 为 adk-planning-execution-loop，support 为 code-review-loop、commit-pr-quality-gate、verification-before-completion。最多两次归因后的技术重试，来源漂移或设计变化先 replan，未知外部写先对账。模型取证仍限 gpt-6.1-sol/medium 单任务、总计一次上游请求，无自动重试。

## 阶段与验收

1. 已完成生产 dry-run 与独立准备审查；实际六路径 apply 已完成，四项 postverification 及 fixed Cosign 真实离线验签通过。原始 apply receipt 保留 `applied-not-verified`，后续证据另记，不重标它。
2. 消费者测试根据 pinned production loader 的日期与精确 stale 错误验证过期拒绝。其他故障不能成为 passing stale case；新鲜 source-layout PASS 仍不是 native certification。
3. 修复独立审查发现：当前 source 与历史 qualification 不匹配时，current maturity/readiness/field 显示未验证，certified/terminal=false。历史 scorecard、日期、runtime、field、owner 原记录不改。身份匹配时的投影只表示声明一致性，真实 qualification 仍走独立认证。
4. 按 backlog-review.md 真实复审 22 个软件路径/状态边界后续期有限 14 天；G21/G22 保持 blocked，不把路径存在或确定性测试升级为真实领域资格。
5. 按 validation_plan 的 L4 源码检查执行 ADK 多版本完整 parity、root full regression、quick working-tree gate；clean commit 才能形成 release-clean 证据。最终 fresh whole-diff 审查覆盖全部修复和文档，再提交已有授权的 SCM，独立核新 main 完整 signed CI。

## 负结果、回滚与未闭环项

首次 root full 30/31，test_gate_runner 因 backlog review 到期真实拒绝。原始 receipt 保留；不是 ADK 来源过期，也未调用模型。临时 postverify helper 初次因隔离 PATH 未含 rtk 启动失败，在加入既有 rtk 路径后通过，无生产修改或假验证器。

修复后的第二轮 root full 67/68，在 stale-reference 正负例因显式 PATH 选中系统 ripgrep 11.0.2（没有 PCRE2）而失败；未将 scanner error 解释为 PASS。当前宿主已有 ripgrep 15.2.0/+pcre2，修正验证工具选择并先运行同一 stale-reference suite，通过后再执行最终全回归。原失败回执保留，生产扫描器和拒绝规则不放宽。ADK 三版本 Docker full parity 已实际完成，每版本98/98、routing30/30及依赖 audit通过。

根仓事务失败由生产 apply 回滚；后续源码可通过正常 revert 还原该根仓提交，保留所有 historical 记录。不得清理原主仓或旧候选。组件发布、根仓集成、真实模型、native/effect、field/owner 是独立验收线。当前没有当前版本的 human field/owner 资格证据，不能用全部授权代替它们。live、认证配置和 memories 不在本次修改范围。
