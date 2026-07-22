# mattpocock/skills 参考子仓安全复核（2026-07-22）

## 结论

- 参考子仓物化：`PASS WITH BOUNDARIES`。
- 上游执行、安装、hook、plugin 和 skill 激活：`DENY`。
- reviewed HEAD：`ed37663cc5fbef691ddfecd080dff42f7e7e350d`。
- metadata candidate 未报告阻断 risk flag；本地复核确认 MIT、未归档、无 nested submodule、无凭证模式命中。

## 静态检查

- 167 个 tracked entries，最大文件约 49 KiB，无大体积二进制证据。
- 唯一 symlink 为 `AGENTS.md -> CLAUDE.md`，目标在仓内。
- executable 文件共 3 个：
  - `scripts/link-skills.sh`
  - `scripts/list-skills.sh`
  - `skills/misc/git-guardrails-claude-code/scripts/block-dangerous-git.sh`
- `package.json` 为 private package，仅声明 Changesets dev dependencies；本次未运行 `npm install`、`npx` 或 package scripts。
- `.github/workflows/release.yml` 使用 `npx changeset`，只作为上游发布实现参考，本地不执行。
- 未发现 `.gitmodules`；不会递归引入供应链。
- 常见 GitHub token、AWS key、OpenAI key 和 private-key header 模式扫描无命中。

## 风险面

1. `scripts/link-skills.sh` 会写 `~/.claude/skills`、`~/.agents/skills`，并对冲突目标执行 `rm -rf`；严禁在 llm_agent intake/sync/analysis 中运行。
2. README 和 docs 包含 `npx skills add/update`、Claude plugin 安装命令；这些是未授权外部安装面，不得由自动化触发。
3. `setup-pre-commit`、git guardrail 和 diagnosing-bugs 等 skill 包含 hook、shell、git 或外部工具操作建议；内容只能作为不可信研究输入。
4. skill 文本可能诱导 Agent 修改 issue tracker、仓库、用户 HOME 或执行命令；吸收前必须重新做 semantic、安全、版权和 runtime effect review。
5. Git fetch 会更新对象和 submodule HEAD 候选，但不得自动 checkout 新 HEAD、安装依赖、运行测试或写 live runtime。

## 强制控制

- lifecycle `automation_eligible=false`。
- runtime boundaries 固定为 `do-not-install-external-skills`、`do-not-execute-external-hooks-or-runtime`、`review-before-adk-absorption`。
- submodule 只使用 canonical HTTPS origin，不继承本地临时 clone remote。
- 后续同步采用 fetch/diff/report，不自动执行上游文件。
- 任何 ADK/Codex 变更均需独立 change artifact 和验证证据。
