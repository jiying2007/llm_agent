# WeChat Intake Full 门禁可移植性修复记录

## 结论

`check-all.sh --full` 的唯一失败并非 ledger 缺失或决策未闭环，而是 `check-wechat-intake-ledger.sh` 把被 `.gitignore` 排除的外部 `wechat-articles/` corpus 当作纯 Git checkout 的必备输入。修复后采用双模式契约：纯 checkout 校验 hash-bound snapshot；真实 corpus 存在时继续执行逐文件再生成对比。

这项修复不把 snapshot 声明成原始 corpus，也不降低 live-corpus 门禁。需要证明 corpus 可用时必须传 `--require-corpus`。

## 固定边界

- 基线 root commit：`383274fed93ad143cabb1dbd977e1b766eca5c04`
- 既有失败复现：纯 worktree 运行 `rtk scripts/check-wechat-intake-ledger.sh .`，稳定返回 `missing wechat-articles directory`。
- 受影响范围：根仓 WeChat intake ledger 门禁。
- 不受影响范围：`agent-dev-kit`、子模块指针、吸收决策、原始文章 corpus、远端状态。
- 回退锚点：基线 root commit；不得 reset 原工作树的 dirty 子模块或未跟踪目录。

## 假设矩阵

| 假设 | 验证 | 结果 |
|---|---|---|
| 提交内 ledger 或 decision overlay 缺失 | `git ls-files`、`wc -l`、SHA256 | 否；两者均已提交，ledger 313 行，decision 314 行（含表头） |
| Full runner 错误传参 | 读取 `scripts/check-all.sh` 调度逻辑 | 否；runner 只把 root 作为第一个参数传入 |
| checker 隐式依赖未提交 corpus | 读取 checker、`.gitignore` 并在纯 worktree 复现 | 是；checker 在任何结构校验前要求 `${ROOT}/wechat-articles` 存在 |
| 可以直接跳过 WeChat gate | 对照 ledger-first 治理规则 | 否；会丢失提交内 ledger 篡改、决策引用和外部代码 policy 检查 |

## 5-Why 根因链

1. Full 门禁为什么失败：checker 找不到 `wechat-articles/`。
2. 为什么纯 checkout 找不到：该目录被 `.gitignore` 明确排除，Git tree 不承载 corpus。
3. 为什么缺目录直接失败：旧 checker 只有 live-corpus 再生成这一种验证模式。
4. 为什么没有离线模式：提交内 ledger 没有独立的 count/hash snapshot 契约，checker 无法区分“corpus 不在 checkout”和“ledger 不可信”。
5. 为什么这会破坏 Full 可移植性：`check-all --full` 把环境性 live 输入要求混入了 clone/CI 必须可复现的仓内门禁。

根因是输入能力分层缺失，不是简单的路径错误。

## Repair Note

- failed_scope：纯 checkout 的 `check-wechat-intake-ledger.sh`。
- passing_scope_to_preserve：313 行结构化 ledger、decision overlay 引用、external-code report-only policy、真实 corpus 再生成与 stale 检查。
- minimal_rerun：targeted checker、正负 fixture、doc sync、root Full gate。
- repair_action：新增确定性 `reports/wechat-article-intake.manifest.json`；checker 先严格校验 ledger 结构、顺序 ID、安全路径、decision 引用、行数与 SHA256，再按 corpus 是否存在选择 snapshot/live 模式；generator 同步维护 manifest，并支持外部 `--articles-dir`。
- semantic_verification：snapshot tamper、manifest 缺失、`--require-corpus` 缺目录、live corpus 内容漂移、live corpus 数量漂移均必须失败。
- do_not_repeat：不得把“目录不存在”改成无条件 skip；不得把 snapshot 结果表述为 corpus 留存或 live 验证。

## 停止条件

- targeted fixtures 全绿；
- 纯 worktree checker 输出 `mode=committed-snapshot`；
- `--require-corpus` 在纯 worktree 仍 fail-closed；
- `scripts/check-all.sh --full` 全绿；
- diff 不触碰子模块、corpus、ADK 或未授权路径。

## 执行偏差：linked worktree 仓库判定

子模块初始化后，`check-file-modes.sh` 仍在 linked worktree 返回 `not a git repository`。源码使用 `[[ -d "${ROOT}/.git" ]]`，但 Git 的合法 linked worktree 以 `.git` 文件指向共享 metadata；因此该判断把标准隔离开发环境误判为非仓库。

补充修复只把仓库识别改为 `git -C <root> rev-parse --show-toplevel`，随后仍使用原有 index mode 与 working-tree execute bit 对比，不改变 `100644/100755` 策略和 `--fix` 语义。独立 fixture 在真实 linked worktree 中覆盖 pass、unexpected executable、missing executable 和两类 fix 后复验。

`check-adk-harden-readiness.sh` 原本直接调用 ADK 子模块内尚未修复的同名 checker，因此标准 submodule gitfile 仍会失败。根仓 harden 现改为用已修复的根 checker 检查 `agent-dev-kit` 路径；目标 Git index 仍由 `git -C agent-dev-kit` 读取，不改 ADK 文件、gitlink 或 file-mode 判定。

ADK 的 `tests/run_all.sh` 内部仍包含旧 `test_file_modes`，直接在 submodule 工作树执行会再次误判。harden 因此先完成真实 submodule 的 validate、模式、routing 和 evidence 检查，再把当前 ADK 精确 HEAD 以 `--no-hardlinks` 本地 clone 到临时目录，核对 cloned HEAD 完全一致后运行 52 项全套回归；退出时只删除该临时目录。这样不跳测试、不改子模块，同时给旧测试 harness 提供其当前要求的 standalone `.git` 目录。

ADK ecosystem tests 还会读取与 `agent-dev-kit` 同级的六个参考子模块。临时目录仅为这些已初始化路径建立只读 symlink，恢复原 workspace topology；测试仍读取当前 root worktree 的精确 sibling 内容，临时清理只移除链接本身。

## 修复验证

| 层级 | 命令 | 结果 |
|---|---|---|
| 静态 | `rtk shellcheck scripts/check-wechat-intake-ledger.sh scripts/generate-wechat-intake-ledger.sh scripts/check-file-modes.sh scripts/check-adk-harden-readiness.sh tests/test_wechat_intake_ledger.sh tests/test_file_modes_worktree.sh` | PASS |
| fixture | `rtk tests/test_wechat_intake_ledger.sh` | PASS；覆盖 snapshot/live 正例及 5 类负例 |
| fixture | `rtk tests/test_file_modes_worktree.sh` | PASS；覆盖 linked worktree 与两类 mode 漂移/fix |
| portable | `rtk scripts/check-wechat-intake-ledger.sh .` | PASS；`articles=313 mode=committed-snapshot` |
| fail-closed | `rtk scripts/check-wechat-intake-ledger.sh . --require-corpus` | 预期失败；纯 checkout 不冒充 live corpus |
| live | `rtk scripts/check-wechat-intake-ledger.sh . --articles-dir /home/leiwenjun/bin/llm_agent/wechat-articles --require-corpus` | PASS；`articles=313 mode=live-corpus` |
| ADK | `rtk scripts/check-adk-harden-readiness.sh .` | PASS；isolated exact HEAD `0d25f3d...`，ADK `52/52` |
| release | `rtk scripts/check-all.sh --full` | PASS；root `62/62` |
| diff | `rtk git diff --check` | PASS |

## 提交质量裁决

- Scope：一个目标——恢复根 Full 门禁在纯 checkout、linked worktree 和标准 submodule gitfile 环境下的可复现性；WeChat snapshot 与 file-mode/harden 均是同一失败链上的输入能力修复。
- Review：blocker=0，major=0；ShellCheck 的三条旧告警已按真实语义局部闭环。
- 配置漂移：无运行配置变更；新增 manifest 是确定性验证制品，不启用外部写操作。
- 兼容性：旧的 `[root]` 调用方式、live corpus 严格再生成、`--fix` 语义保持；新增参数均向后兼容。
- Owner / review responsibility：human owner 为 `leiwenjun`；Codex 受托实现并记录证据，后续 source remote publish 仍需独立授权。
- Release gate：root Full `62/62` 已通过；允许创建一个本地 source commit，不授权 source remote push。
