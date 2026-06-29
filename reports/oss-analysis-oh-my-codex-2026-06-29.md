# OSS Analysis: oh-my-codex

- 日期：2026-06-29
- 本地路径：`oh-my-codex`
- 来源：`https://github.com/Yeachan-Heo/oh-my-codex.git`
- 本地 HEAD：`d96b698c5f2fabc85c890f7b8fcdc6e02f253ec7`
- 分支：`main`
- 决策：observe / active-reference / git submodule reference

## 价值判断

`oh-my-codex` 是 Codex CLI 工作流运行层，不是单纯的 skill 清单。可借鉴点包括：

- goal / ultragoal 类持久目标与 checkpoint 表达；
- worktree 启动隔离和 dirty worktree 提醒；
- `doctor` + `exec` smoke 的运行态验证思路；
- plugin bundle SSOT、native agent 验证、release evidence 协议；
- session state scope、HUD、team/runtime 的漂移修复经验。

## 本地适配方式

仅 method-only 观察。优先把可复用做法转成 ADK 或 `~/codex` 的声明式门禁、报告和 dry-run 检查，不引入 OMX CLI 运行时。

## 风险

- 运行时依赖 Node、tmux、Codex CLI 认证和全局安装；
- `--madmax` 等绕过审批/沙箱路径不适合作默认工作流；
- plugin/hook/MCP 状态面可能与本机 `~/codex -> ~/.codex` 声明式链路重叠。

## 证据

- `oh-my-codex/README.md`
- `oh-my-codex/package.json`
- `oh-my-codex/RELEASE_PROTOCOL.md`
- `oh-my-codex/plugins/oh-my-codex/.codex-plugin/plugin.json`
