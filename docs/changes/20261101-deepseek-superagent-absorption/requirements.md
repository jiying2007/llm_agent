# Requirements — DeepSeek Superagent 方法评估与可控吸收

## 目标

在不安装上游 Runtime、不增加新权限、不扰动在途工程平台 P0 的情况下，把外部有价值的低干扰自主协作方法转为可检查的候选方案，并为已有 llm_agent → ADK → 消费者链路提供可执行的验收标准。

## 范围

- 只读核验固定上游仓库快照，许可和安全风险，区分已实现代码与未来愿景。
- 对照现有 Root 的独立外部实践批准、ADK 的平台中立执行策略和工程平台的 Worker/Action/Recovery。
- 保留已有 Source、Task、Policy、Evidence、Review 和 Qualification 的 authority；只增强缺少的行为规则、测试案例或 presentation。
- 记录明确的 P0/P1/P2 改进建议、owner 与恢复点，不因“认可方向”自动扩大授权。

## 非目标

- 不注册上游 gitlink/submodule，不自动 clone/安装/运行上游依赖和代码。
- 不复制 DeepSeek Harness 的 preset、prompt、GitHub CLI 或 danger-full-access 工具链到生产。
- 不直接写 ADK、engineering-platform 的生产接口，不创建第二套跨仓代理 Runtime 或自动审批记录。
- 不使用 Codex/ChatGPT Work 额度；不通过新定时任务规避平台调度上限。

## 验收

1. 能从仓库固定 SHA 追踪所有关键特征和风险的证据源。
2. 明确哪些是现有能力、哪些是真实缺口、哪些只属于论文愿景。
3. 每项拟吸收功能指定目标 owner、代码/文档资产、正负例、可回滚边界，标记 awaiting independent owner decision。
4. 安全、权限及外部效果相关的建议不会降低现有 fail-closed 判据。
5. 绝不把未执行的 upstream test、CI、真实运行及 A/B 效果写成 PASS。

## 可信度与授权

本次为 independent assessment candidate。用户要求评估与吸收优化，不等于已有外部实践治理中具体 candidate 的独立签署事件；独立 owner decision 需另行写入 canonical decision record 并经既有 schema 校验。