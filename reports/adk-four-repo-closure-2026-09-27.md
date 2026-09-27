# ADK、Codex 与 Knowledge Hub 四仓交付检查点

状态：`ADK-Python-3.8-branch-verified / Codex-live-verified / cross-repo-PR-review`。下文阶段检查点保留实施时的历史基线，文末列出本轮提交推送后的最新状态；源码验证、安装验收、Execution Policy 与跨仓发布分别判定。

## 目标与边界

- 目标：核对 `llm_agent → agent-dev-kit → ~/codex → ~/.codex` 的来源和安装链，并将有证据的结论交给 Knowledge Hub。
- 保留：根仓未跟踪参考目录、Knowledge Hub 已有脏改、Codex 认证/session/memory/`.system` 与当前 live profile。
- 停止条件：ADK 全量回归失败、Codex 来源或计划漂移、本机缺少合规 Python、live 计划触及受保护或未纳入计划的资产。
- 本轮不自动提交、推送、合并、提升 Hub active 或改写已有证据。

## 来源基线

| 层级 | 当前基线 | 本轮观察 |
| --- | --- | --- |
| `llm_agent` | `59967ae39f755fa00fcfffad850359a03e8ec4ad` | gitlink 固定 ADK `86e1306b287b1dbe593865b4fe8cfa667743c548`；参考目录未跟踪状态保留 |
| `agent-dev-kit` | `86e1306b287b1dbe593865b4fe8cfa667743c548`，`v7.8.0` | 本轮形成 `7.8.1` Python 3.8 原生兼容源码候选，含构建依赖、契约、CI 矩阵和测试；仍为未提交工作树，尚无新的 provider commit |
| `~/codex` | `62047a56e4b5ede2201c325a10ebd9cb46b9d558` | 与 `origin/main` 为 `0/0`；provider lock 固定 ADK `7.0.31`；本轮测试、CI、文档和派生 `manifests/lock.json` 有未提交修改 |
| `~/knowledge-hub` | `6aaeaf4477f403af6ffffd7b613d432a6255e185` | registry、索引和项目资料已有用户脏改；本轮候选通过事务追加，原有内容保留 |

## 阶段检查点

1. **ADK 源码**：保留原信任测试和退役目录检查修复，新增 Python 3.8 标准库、语法、构建依赖与发布契约兼容层；`pyproject.toml` 声明 `>=3.8`，CI/消费者矩阵加入 3.8，质量工具按解释器约束固定版本。候选版本为 `7.8.1`，不改写不可变的 `v7.8.0` tag。系统 Python 3.8.10 的 doctor、严格 Schema、目标/发布门禁、runtime bundle 与 30/30 路由评估通过；最终候选 doctor 再次确认版本 `7.8.1`、Python 3.8.10 及依赖。隔离 Docker Python 3.8.20、3.11.15、3.12.13 对同一源码快照 `172875f9b520068a671eac6349b0d32a2723e26a30f9e396249b91038dcac95f` 的完整门禁与依赖审计通过，各版本测试 `90/90`、路由 `30/30`；回执为 `agent-dev-kit/.cache/local-ci/full-parity-receipt.json`，状态 `pass`。这证明源码候选的受测功能兼容，尚未形成可供 Codex 锁定的 clean provider commit。
2. **Codex 来源**：只读审计比较现有 42 个启用 ADK Skill 与干净 ADK `7.8.0` 候选，`blocked_skills=0`，目录差异为 0；`v7.0.31..v7.8.0` 的 `skills/`、`agents/`、`execution_policy/` 源码差异也为 0。不得仅为版本变化改标既有来源。
3. **Codex 本机应用**：Python.org 3.11.16 源码 tarball 的 SHA256 `91bcdebfdde239a003ae93738a7fce0f9230fee5c4bc2b86f6e6e8c6f98aabe8` 与官方发布页一致；独立前缀及 venv 位于用户目录，主机实测 SSL、SQLite、venv 和 PyYAML 6.0.2 可用。正式计划保存在 `~/codex/.backups/member.Cuc2WAEg/`：第一份复制 78、覆盖 57、删除旧受管 80；第二份清理经审查的 24 个旧空目录并更新 managed state。两份计划均先 dry-run 再 apply，备份保留。`team-collab` live 的 doctor 为 0 错误/0 告警，最终 diff 为 0、drift 为 `changed=0/stale=0/unmanaged=0`、重复计划 `content_changes=0`。绑定第二份计划的 `check.sh --no-build --plan` 通过，包含 306 项源码测试和四个 profile 隔离 smoke。当前 live `adk-runtime-router` 指向 `2.1.0`。
4. **Codex 测试与来源收口**：已将两处隔离复制测试排除 `.backups`，把 10 个未跟踪、无文件、未被 manifest 引用的旧版本空目录移到本轮备份；smoke 结束后恢复运行前的主 build profile。完整回归所需的 `lark-oapi==1.7.1` 和 `websockets==13.1` 已安装到专用 venv；CI 与测试文档补齐后者的固定版本。`manifests/lock.json` 由本机 `team-collab` build 派生，保持未提交，不能当作默认 profile 的源码基线。
5. **Knowledge Hub**：预应用候选 `adk-four-repo-source-live-validation-20260927` 已通过 `knowledge-capture.sh` 事务登记到 `domains/codex/validation/`，状态为 `reviewing`、`promotion=none`、`manual_validation_pending=true`。写后 `knowledge-check --dry-run` 仍为原有 3 个音频资料治理错误，没有增加本轮候选错误；既有 registry/index 脏改保留，不据此提升 active。根仓 `check-doc-sync` 通过、`check-token-budget` 通过但有 warning；`check-agents-coverage` 因缺少 `digital-worker` 路径返回 2，与本轮四仓改动分列。
6. **根仓 L4 工作树门禁**：`validation_plan` 将版本、release/M5 与共享契约改动归为 L4。`tests/run_all.sh --fail-fast` 在第二项停下：直接运行缺少 ADK 导入路径；补上 `PYTHONPATH` 后明确显示候选 `7.8.1` 与 `adk.lock` 固定 `7.8.0` 不一致。`check-all.sh --quick --working-tree` 在系统 Python 3.8 环境为 33/52，通过 Python 3.11 venv 复核为 35/52；`check-adk-lock` 和 `check-codex-lock` 未通过，另有缺失子仓/资料、过期参考基线等独立工作区问题。未将根仓门禁标记为通过。

## 当前阻塞与下一步

- Python 3.8 验收范围已明确为 ADK 全部原生运行功能；`7.8.1` 源码候选的三版本完整门禁已通过。现有 `~/codex` provider lock 仍固定旧 ADK `7.0.31`，live Codex 工具仍使用独立 Python 3.11.16；不能把 ADK 源码兼容结论当作 Codex 当前运行资产已升级到 3.8。必须先有审查通过的 clean ADK commit 和 exact 来源/制品身份，才能更新 Codex lock 并重新执行 source-to-live。
- 本会话的 Execution Policy `apply`、`final` 事件均返回 `runtime_control.policy/v2 requires an attested goal intake`。没有为通过门禁补造 intake；这项本地任务策略 conformance 未完成，与已通过的成员安装验收分列。
- ADK 与 Codex 源码修改均未提交或推送；根仓 gitlink 仍固定已提交 ADK `86e1306`。Knowledge Hub 全局检查的既有 3 个音频资料错误也未关闭。
- 下一步最多三项：审查并按授权形成 ADK clean commit，再更新 Codex exact provider lock、根仓 gitlink 和 source-to-live；在具有真实 attested intake 的会话重跑 Execution Policy；保留 Hub reviewing 状态并独立处理既有全局错误。

## 提交推送更新（2026-09-27）

- ADK 上游在本轮执行中从 7.8.0 连续前进至 7.12.0。Python 3.8 原生兼容候选已迁移到 7.11.0 主线并形成独立提交 `42bde26abb353922135c5cc6c8b6b895646ca04d`，候选版本 7.11.1，推送至 `codex/native-python38-20260927`，草稿 PR 为 `jiying2007/agent-dev-kit#162`。最终干净提交的本地完整矩阵：Python 3.8.20、3.11.15、3.12.13 各 92/92 测试、30/30 路由评估及依赖审计通过；`--check-receipt` 匹配源码快照 `8a8b689651c98ec07770d92ca632023f2a89286dfc052d3ba2f36e1a79526d73`。验证期间上游主线又到 7.12.0，版本身份冲突，PR 尚不可合并。
- Codex 现有 7 个源码/测试/CI 改动已形成提交 `1bb693cb539cc199d42d74758b80db249ccbc244`，推送至 `codex/source-live-checks-20260927`，PR 为 `jiying2007/codex#41`。默认 profile 的 pre-apply 门禁通过 311 项测试、四 profile smoke 和安装 dry-run；现有 team-collab live doctor 为 0 错误/0 告警，同 profile diff=0、drift changed/stale/unmanaged=0。默认锁由正式 build 重新生成；未把临时 team-collab 锁当源码基线。
- Knowledge Hub 既有 50 个文件已形成提交 `fcdf9d427b3ae41873265c7406fcc0fc299d60f1`，检索兼容修复追加提交 `9d1a4354cad406ba4bfd04dc83d6cf5099812e51`，推送至 `codex/hub-archive-20260927`，PR 为 `jiying2007/knowledge-hub#133`。`knowledge-check --dry-run` 为 pass、0 错误、97 条 warning；检索基准通过，远端 quality 流水线成功，PR 已进入 review。所有候选仍保持原有 reviewing 状态。
- 根仓远端主线已前进，当前本地检出的 ADK 是尚未合并的兼容分支。本报告作为独立证据提交；根仓 `adk.lock` 与 gitlink 不锁定该未合并候选，待 ADK PR 合并并取得主线确切身份后更新。根仓原有缺失子仓、参考基线过期及其它工作树门禁失败仍单列，不视为通过。
