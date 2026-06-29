# OSS Absorption Plan: oh-my-codex

- 日期：2026-06-29
- 决策：method-only observe
- 不复制代码，不安装运行时，不启用 hooks/MCP。

## 可吸收方向

| 方向 | 目标资产 | 做法 |
|---|---|---|
| goal/checkpoint 证据 | ADK goal templates / context state contracts | 只吸收字段和验收表达，不引入 OMX 状态文件 |
| worktree 启动安全 | `adk-worktree-governance` | 借鉴 dirty worktree 警告、命名隔离和重复启动防护 |
| doctor + exec smoke | `~/codex` / ADK runtime gates | 强化“安装形态检查”和“真实模型调用 smoke”分离 |
| plugin bundle SSOT | plugin/skill 资产治理 | 借鉴 bundle check、native agent verify、release evidence |
| release protocol | release/versioning gate | release note 必须对齐 compare range 和发布证据 |

## 拒绝项

- 不安装 `oh-my-codex` 全局 npm 包。
- 不启用 OMX runtime、tmux 管理、HUD、MCP state server。
- 不迁移 prompt/persona 资产到 ADK core。

## 下一步

仅当后续出现对应需求时，按单点议题生成 ADK 候选，例如 `doctor smoke split` 或 `release evidence range check`。
