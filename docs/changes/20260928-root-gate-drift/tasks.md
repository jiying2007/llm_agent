# 执行与验证

- [x] 验证计划从 registry 读取受限的 active fetch 参考目录；`test_validation_plan.sh` 17 项通过。
- [x] 外部实践路径迁移；`check-practice-intake.sh .` 通过。
- [x] 更新三项 ADK JSON Manifest 检查；三项独立命令通过。
- [x] 移除 M5 废弃参数；脚本真实返回 promotion evidence 版本和 scorecard 状态不一致。
- [x] `check-doc-sync.sh .` 与 `git diff --check` 通过。
- [x] 采纳矩阵六处退役路径改为当前实证入口或移除冗余项，并同步 JSONL；206 行、603 路径检查通过。更新受矩阵 hash 绑定的移除计划正例夹具。
- [x] 独立 `digital-worker` 试点不纳入上游实践采纳矩阵；fetch 型参考仓不要求根目录物化，pull 型子仓仍需本地路径与授权 gitlink。新增正反例通过。
- [x] `health-check` 与资产清单读取 ADK JSON Manifest；参考来源检查在 Python 3.8 和 3.11 定向通过。
- [x] 按 `manifests/gitlinks.json` 保留冻结证据型 `codex` gitlink；working-tree quick gate 只核不可变 pin，独立 `~/codex` 仍是唯一运行资产源。
- [x] promotion evidence 静态身份与原始 Sigstore 验证在 Python 3.11 和隔离 cosign v3.1.3 下通过；修复负例脚本使用旧 `python` 导致的虚假通过。
- [x] 根仓全套回归：隔离 Python 3.11 依赖已补齐，7.12.4 main + 新签名证据的 full gate 为 55/58，工作树指纹稳定；三项独立阻断见 `verification.md`。

ADK PR #167/#168 已合并并形成 7.12.4 main 签名与 Release，根仓本地候选已提交但未推送；尚无 Codex source-to-live 或 M5 产品资格证据。
