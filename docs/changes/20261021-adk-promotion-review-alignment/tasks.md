# 任务与交付记录边界

协调与 Root 修改：`ai/root`。独立 Spec：`ai/root/external_methods`；独立 Quality：`ai/root/native_evidence_audit`。`ai/root/qualification_audit` 负责验证计划准备、制品差异诊断与隔离发布演练，其提议自查不替代最终独立审核。

- [x] 冻结正式晋升、五处说明修订及真实资格边界。
- [x] 完成 ADK PR #218、精确主线 CI 与不可变 v8.0.37 Release。
- [x] 核对原始 promotion artifact、正式 tag 指向与真实 Sigstore 验签。
- [x] 诊断并保留空目录导致的首次本地构建差异；重新构建与正式 tar、checksum、release manifest 逐字节一致。
- [x] 使用正式 8.0.36 / 8.0.37 原件完成隔离升级和回滚演练。
- [x] 完成 Root canonical 六路径晋升与原始凭证验证，随后同步五处说明。
- [ ] 在最终待提交内容上生成 L4 计划并记录完整 Root 回归、aggregate 和 token-budget 的实际结果。
- [ ] 独立复核最终 diff，完成受保护 Root PR、clean-commit 检查与 fresh-main 资格报告核对。

这是提交前的事实检查点。最后两项需要本文件冻结后才能产生精确快照和远端结果，其实际完成状态由本次 Root PR 最终正文与最终审计记录承接；不在源文件中预填成功。
