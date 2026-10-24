# 设计

复用 `tools.control_plane.adk_promotion` 与已有 portability、Cosign 和 interface contract owners，不增加第二套升级、签名或发布逻辑。规划材料先提交，使原 promotion 的 clean-index / isolated-worktree 前置条件成立。ADK 正式 main SHA 与 tag、产物全部核对后才作为 candidate 输入，禁止拿未发布实现提交替代正式版本。

promotion 负责生成 gitlink、lock、interface 与派生 status；原始生产者 evidence / attestation 保持原字节。事务之外的交付记录只描述真实执行来源、时间、结果及限制，不把当前来源写回旧审查记录。Root 旧 F3 审核绑定 `a922a2884c4d38e2ecdc2f8dbc27b1fde69765b8`；接入造成的新 pin / current-status 身份由本 change 的独立审核负责。

ADK 静态 target 保持兼容；其 release validator 对没有独立可信宿主授权的 runtime-conformance 归档明确拒绝，不能将归档自带 registry 视作执行授权。此限制不授予或撤销正常本地 managed Native owner 的权限。

回滚使用旧正式 8.0.39 来源及已保留的原 promotion evidence，通过同一既有事务/PR路径；发布标签与历史证据不可重写。当前隔离环境没有 canonical `~/codex` Knowledge Provider 与 Execution Policy，相关 live 验收为 not-run，不据此判断用户真实主机故障。
