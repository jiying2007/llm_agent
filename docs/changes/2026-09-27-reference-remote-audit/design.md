# 设计

- 实现位于 `tools.codex_assets.reference_remote_audit`，复用 `tools.control_plane.reference_pins.check` 的 exact pin、URL 和 Git 边界校验；读取同一 pin 原文并在联网前后复核 digest，不依赖物化计划或缓存根。用 registry 取得 active 分支并检查两套 SSOT 一致。
- 默认只输出离线身份清单。联网使用受限 Git 环境、固定主机允许表、禁止 HTTP 重定向、单仓超时和有限输出；registry/pin 本体及上级目录不得为 symlink。每个仓独立失败，最后给 `review-required`、`current` 或 `degraded`。不同 SHA 只表示远端变化，不计算 ahead/behind。
- JSON 包含 pin 与 registry digest、id/branch/pin/remote/relation、`mutation_performed=false`、`runtime_enablement=false`。不默认生成 report 文件；本地吸收候选继续通过项目现有 intake/owner decision 流程。
- 现有 `sync-subrepos.sh status/fetch/pull` 保持原语义；新入口补上无工作区写入的实时远端检查。
- 隔离 worktree 的根仓测试 runner 显式将受管 `agent-dev-kit/src` 与根仓加入 `PYTHONPATH`，并按根仓 `pyproject.toml` 前置要求 Python ≥3.11；这与 ADK 自身 Python 3.8 合同分开。测试脚本直接调用 `python3`，避免本机 `python` 落到 Python 2。
