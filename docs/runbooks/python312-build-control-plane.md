# Root Python 3.12 单版本管理环境

Root / `llm-agent-control-plane` 和精确绑定的 ADK 管理工具统一在 **CPython 3.12.x** 运行；不是服务端 Agent / Skill runtime 的 Python 要求。包元数据明确 `>=3.12,<3.13`，避免误声明未验证的解释器支持。旧 3.11 虚拟环境不可复用，应在受审查的源码快照上重新创建。

本地开发和复验（以 `rtk` 保持现有仓库入口约定，不自动安装或联网）：

```bash
rtk python3.12 -m venv .venv
rtk .venv/bin/python -m pip install -e '.[quality]'
rtk .venv/bin/python -m tools.control_plane.cli --help
```

ADK 仍保持独立的受审查源码、版本和签名来源；Root 迁移先于 ADK 停止 3.11 支持。GitHub Actions 已按 Job 隔离，使用固定 `actions/setup-python` 选择 Python 3.12，并以现有锁定依赖安装。不强制每个短暂 Actions Job 再创建一个重复的 venv。所有 PR/主线 required check 名称保持不变，不能用「兼容切换」绕过 Ruleset。

历史运行与签名证据上的 Python 3.11 字符串是当时的真实事实，保持不可变，不得进行全库机械替换。迁移后的新 CI 只会在 Python 3.12 上验证 Root；不从旧 CI 记录推导新版本适配成功。

回滚：先恢复旧 Root 源码、`pyproject.toml`、workflow 与旧已签名 ADK 10.0.5，单独重建旧运行环境；禁止拿当前 Python 3.12 的检查回执声称 Python 3.11 已受支持。
