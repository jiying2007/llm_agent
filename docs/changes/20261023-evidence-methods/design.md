# 设计：在既有治理中吸收方法

本变更只使用现有 practice-intake candidate/decision 合同、adoption matrix、runbook、测试和 CI。外部原文不归档，只保留来源元数据、自主归纳和固定源码指针。已有上轮 12 项来源记录为检索依据；未经公布的日期、许可证保持未知。

## 数据与权限

- 既有 manual metadata collector 处理冻结来源清单，所有条目仍为 unverified-metadata/review-required。
- 为已审查官方文档在 manual URL allowlist 明确加入 docs.github.com 与 docs.langchain.com；仅允许 HTTPS metadata 输入，其他网络、执行、正文和写入限制保持既有合同。
- Owner decision 依据本轮真实用户指令，owner=leiwenjun；这不是后台自动批准，也不伪造真人技术复核或现场观察。
- 独立 AI 对来源映射、边界与当前实现进行实际审核；审核状态与 collector 输出分离。
- ADK 的 source-change/harness-source review 由独立角色生成并绑定实际文件摘要。

## 审查反馈：GitHub 文件级来源归属

METHODS-REVIEW-01 发现既有 manual collector 把 GitHub blob 文件 URL 的完整路径当作 repository.full_name。修复限定在 tools/codex_assets/practice_intake.py 的既有 _manual_repository：GitHub 的仓库身份从前两个非空路径段派生，并在仓库段处理 .git；文件 URL 本身、revision 与 candidate ID 的既有计算不变。保留非 GitHub 提供方的现有行为，特别是不把 GitLab 子组路径截断。通过公共 collect 入口验证 repo URL、固定 blob URL、缺少仓库段和两个不同文件路径的身份/ID边界；重新运行本轮 collector，核对十二个 candidate ID 与既有 decision 一致，不手改生成 ledger。

## 落地边界

方法增强落到 compiler/atomic_io/native_campaign、release_artifacts/archive_io/release_contract、impact/process_budget/gate_runner；外部平台生命周期与需要真实效果试验的方法保持观察或待测。统一说明写入 docs/runbooks/evidence-driven-optimization.md 并链接维护指南。方法吸收完成不代表真实任务收益已经测得。

回滚通过删除本轮元数据/说明和受保护代码回退；不删除历史证据、不改变已有资格。共享 policy 与版本由主 Agent 串行整合。
