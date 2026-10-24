# 实施与验证

- [x] 检索 impact/gate_runner/process_budget 消费者和生产 cache 使用；verify：调用点清单。
- [x] 添加真实 Git 中文、空格、引号、换行路径与 Git 失败回归；verify：impact 定向测试。
- [x] 替换独立 subprocess 管理为既有 bounded runner；verify：超时后代哨兵不写入、输出预算、正常退出和依赖阻塞。
- [x] 经主 Agent 确认后禁用 9 个输入不完整生产缓存；verify：同 HEAD index 变动无法命中旧 PASS，纯 fixture cache 正常命中/失效。
- [x] 修复 ROOT-REVIEW-01 显式空 --base 绕过校验；verify：真实 CLI 红测、15 项边界绿测及 Ruff/mypy/diff 检查，见 evidence/implementation-verification.json 的 review_01；等待独立复核。
- [ ] 运行 validation-plan 与必要定向/完整门禁，记录环境不可用项；verify：实际输出与退出码。
- [ ] 独立 Spec/Quality 审核；verify：源文件和证据摘要绑定。
- [ ] 受保护 PR、精确 SHA CI、合并后检查和 ADK 新发布固定；verify：远端最终读回。
