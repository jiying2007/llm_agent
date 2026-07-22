# mattpocock/skills 参考子仓重新激活分析（2026-07-22）

## 结论

- 决策建议：`ADOPT`，目标为 `reference-repository`。
- 物化方式：`llm_agent/mattpocock-skills` Git submodule，registry 状态为 `enabled=yes/status=active`，lifecycle 状态为 `active-reference`。
- 跟踪级别：`P1 / fetch / main / adopt-first / A`，月度复核；允许进入现有子仓同步、差异扫描和周期报告，不自动执行或吸收上游资产。
- 本决策取代 2026-06-25 移除、2026-07-11 不恢复 submodule 和 2026-07-19 sampled watch 的旧运行状态；旧证据继续保留为 provenance，不删除历史决策。

## 不可变证据

- canonical URL：`https://github.com/mattpocock/skills`
- candidate：`epc-43e82b2e69e37e419c3f`
- reviewed HEAD：`ed37663cc5fbef691ddfecd080dff42f7e7e350d`
- previous reviewed HEAD：`9603c1cc8118d08bc1b3bf34cf714f62178dea3b`
- HEAD 日期：`2026-07-21T11:28:51+01:00`
- license：MIT
- GitHub metadata（retrieved 2026-07-22）：181661 stars、15508 forks、未归档、default branch=`main`
- tree：167 个 tracked entries，无 nested submodule；`AGENTS.md -> CLAUDE.md` 是唯一 symlink。
- 从 `9603c1c` 到 `ed37663`：1 个 non-merge commit，`skills/engineering/to-tickets/SKILL.md` 删除 2 行。

## 长期跟踪价值

1. 该仓是已多次产生可验证 ADK 增强的高信号来源，已贡献小技能组合、需求拷问、领域建模、双轴 review、cross-harness invocation、typed work-item permission、Hotspot/YAGNI scope 和 prototype provenance 等方法。
2. 直接 submodule 提供可复现的 commit snapshot、精确 diff 和本地结构化分析，避免只靠 forge metadata 或人工抽样遗漏契约变化。
3. 上游同时覆盖 Claude Code、Codex 和 Agent Skills 标准，适合作为跨 harness 语义及调用边界的长期参考；它不替代 `superpowers` 的流程主干，也不替代 `OpenSpec` 的 spec 工件体系。
4. 本地 reference 只提供研究输入；任何 Agent、Skill、Workflow、manifest 或 runtime 变化仍必须另走 candidate、独立 decision、吸收治理、验证和 source-to-live 链路。

## 运行边界

- 禁止运行 `npx skills add`、Claude plugin installer、`scripts/link-skills.sh`、上游 hooks 和第三方 runtime。
- 禁止把 submodule 直接加入 Codex/Claude skill 搜索路径。
- 禁止自动复制、自动启用或自动发布上游内容。
- 同步只允许 Git metadata/object fetch；新 commit 必须先形成 diff/review evidence，再决定 `ADOPT/ENHANCE/OBSERVE/REJECT`。
- submodule `.gitmodules` URL 与 materialized `origin` 必须保持批准的 canonical HTTPS URL，不能保留 `/tmp` 或本机路径。

## 验收

- candidate v1、独立 ADOPT decision、重复性审查和安全审查均可验证。
- registry 原位从 disabled 切换为唯一 active 行，lifecycle 原位从 watch 切换为唯一 active-reference 条目。
- `.gitmodules` 与 gitlink 指向 reviewed HEAD，target path 为 `mattpocock-skills`。
- registration、authorized-subrepos、practice-intake、doc/adoption sync 和 quick gate 通过。
