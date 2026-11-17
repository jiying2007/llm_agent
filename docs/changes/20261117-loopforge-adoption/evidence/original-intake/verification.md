# Intake 源码记录验证

基线为 `e288e406eb2262f354e36e69ce93b5fb46a70b49`，范围仅本目录的来源、candidate、独立 decision 与证据。未修改生产代码、registry、ADK/Codex gitlink 或资格。行为实现与源码晋级在后续独立提交进行。

## 实测

所有 shell 使用工作区 RTK proxy，工具 Python 为 CPython 3.12.14。命令 stdout 与 exit code 见 local-validation.json；candidate/decision 校验见 owner-review.md。

| 检查 | 实际结果 |
|---|---|
| validation_plan，explicit base=e288e406 | L1，human-facing documentation/evidence-only diff |
| git diff --check | exit 0 |
| check-doc-sync.sh | exit 0，PASS |
| check-agents-coverage.sh | exit 0，9 active、missing_path=0 |
| check-token-budget.sh --summary-json | exit 0，failures=0，既有 root AGENTS soft warning=1 |
| practice-intake candidate / decision | 各 exit 0，7 条有效且一一对应 |

根 AGENTS 的 3886 bytes 超过 3400 soft limit 是未修改基线的 warning，非本次增加；累计 6800 bytes 低于 12000 hard limit。global AGENTS not-found 保持事实，不伪造宿主路径。

## 交付与回退

当前仅完成来源范围决策和 L1 本地验证，后续受保护 PR/CI 与 merge 需实际通过后报告。没有程序行为变更，按现有 planner 不运行代码 full regression；后续 ADK 安全逻辑和 Root gitlink 晋级各自执行完整回归。

回退通过受保护 revert 撤销本目录记录，不改变上游来源、旧审查或任何发行物。没有导入第三方代码/Prompt、登记新 runtime、模型运行、安装或周期任务。知识 Provider 与宿主 Execution Policy 在本环境不可用，保留 UNAVAILABLE/NEEDS_REVIEW；不能从本次来源记录推出 native 或 M5 资格。
