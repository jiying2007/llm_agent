# 受管修复交付提案

当前仅有本地实施授权，尚未执行 commit、push、PR 或 merge。根仓 AGENTS.md 明确“不自动 commit/push/merge/rebase”；本提案供用户审批下一阶段的实际 SCM 写入。

审批范围：将已验证的受管根仓修复集合放入独立交付分支，提交、推送并创建 PR，保留当前检出、已有 dirty 和独立子仓；不自动合并。建议提交摘要：`fix(m5): 加固真实资格证据与候选身份绑定`。

具体文件与逐文件 SHA256 在 `.cache/m5-field-binding-20261010/delivery-proposal.json`。该集合由 working-tree validation plan 的 managed_paths 生成，包含 M5 消费端/collector/observer/CI producer、相关测试、CI workflow 和对应 change 文档；排除 reference dirty 目录、ADK 子仓、live、历史 policy/scorecard/field/qualification、缓存、凭据和日志。审批后执行前必须重核每个摘要及 Git 基线，发生漂移则更新提案，不将未知 dirty 加入提交。

预期用途：让源码修复进入实际项目 CI 和人类 review。PR CI 不等于 main push 的受信签名 qualification receipt；合并需独立明确授权，随后仍须取得匹配最终主分支源码的真实回执。此交付也不替代真实模型身份及当前候选 field/owner 证据，不能直接关闭 M5 或授予 release。
