# github/spec-kit 参考仓长期跟踪分析

## 结论

批准 `github/spec-kit` 进入受治理参考仓 onboarding，定位为 `P1 / observe-first / active-reference`。只跟踪 release 和实质机制差异，不把它设为 P0 流程 SSOT，不安装 `specify-cli`，不启用外部 runtime、workflow、extension、preset、bundle 或 catalog。

## Source Snapshot

- canonical URL：`https://github.com/github/spec-kit`
- candidate：`epc-2ab9c988520526e1e0e0`
- stable tag：`v0.13.4`
- reviewed commit：`ee883a1d4ecee9afe06a81f1bd38a0b745a8d059`
- reviewed tree：`b27f6e7260f477ee70d7ad1854a63b04689e98b4`
- default branch：`main`
- license：MIT；`LICENSE` SHA-256 `2510b446bc1f0cf9702453075d20cd88631e20e5642658edb7325d9c1eb534f7`
- `pyproject.toml` SHA-256：`efa2bb85325a12d72bc3456024d958ed7e9e93b49153ef37f5df9b3345eae1d5`
- upstream `AGENTS.md` SHA-256：`e3d9be4b1c0749e2eb9a351c8397f955abff583d87466bede4d909045b983bed`
- intake transport：metadata-only；source snapshot 只读审查，未执行第三方代码。

## 长期价值

1. **Agent integration 生命周期**：独立 integration package、单一 registry、Skills/Markdown/TOML/YAML target adapter、managed manifest、install/use/switch/upgrade/status/uninstall。
2. **安全变更与回退**：managed-file hash、本地修改保护、stale file 清理、安装失败回退和 bundle 引用计数。
3. **可组合分发治理**：project/user/built-in catalog priority、discovery-only 与 install-allowed、extension/preset/bundle 版本和冲突解析。
4. **Workflow fail-closed**：gate、fan-in/fan-out、if/switch/loop、malformed YAML、redirect 和 catalog 输入验证。
5. **Spec 演化**：`clarify`、`analyze`、`converge`、spec-of-specs 和 brownfield evolving-specs。
6. **Codex target 变化**：Codex 当前使用 `.agents/skills/speckit-*/SKILL.md` 与 `$speckit-*`，适合作为 target-local adapter watch，不进入 ADK core 常量。

## 跟踪策略

- 每周只检查 release/tag/security metadata。
- 每月运行语义 diff，忽略 stars、纯文档、单纯新增 Agent 和社区 catalog 上架噪声。
- 每 90 天复核一次保留、降级或退役。
- 以下变化触发深度分析：
  - Codex Skills 路径、调用语法或 `AGENTS.md` integration 边界变化；
  - major/minor breaking release；
  - integration install/upgrade/remove/rollback 语义变化；
  - workflow resolver/schema/gate/fan-in/fan-out 变化；
  - catalog redirect、digest、auth 或供应链安全变化；
  - brownfield、converge、spec-of-specs 出现实质新机制。

## 不吸收边界

- 不复制 constitution/specify/plan/tasks/implement 的完整命令和模板。
- 不用 Spec Kit 替代 OpenSpec、superpowers、vibeflow 或 ADK spec-chain。
- 不安装 CLI、Python 依赖、hooks 或 Git extension。
- 不执行 community workflow、extension、preset 或 bundle。
- 不把 agent-specific 路径写入 ADK core；只允许审查后的 target-local adapter。
- 不以 stars、release 数、生成代码量或社区规模作为质量证据。
- 不自动把 upstream change 转为 ADK change；必须另走 candidate、独立 decision、架构/安全/验证和 pilot。

## 建议 Registry 投影

```text
repo=spec-kit
group=workflow-core
priority=P1
sync_mode=fetch
branch=main
enabled=yes
status=active
owner=llm-agent-governance-owner
intake_policy=observe-first
grade=A
```

`active` 仅代表受治理长期跟踪，不代表 runtime 或安装启用。

## Evidence

| Command | Exit Code | Result |
|---|---:|---|
| `rtk scripts/practice-intake.sh collect --provider github --query 'repo:github/spec-kit' --allow-network ...` | 0 | trusted metadata candidate 1 条 |
| `rtk git clone --depth 1 --branch v0.13.4 https://github.com/github/spec-kit <tmp>/source` | 0 | 固定稳定 tag 快照 |
| `rtk git rev-parse HEAD` | 0 | `ee883a1d4ecee9afe06a81f1bd38a0b745a8d059` |
| `rtk git remote get-url origin` | 0 | canonical URL 一致 |
| `rtk git status --porcelain=v1` | 0 | source clean |
| `rtk sha256sum LICENSE pyproject.toml AGENTS.md` | 0 | 三项 digest 已记录 |

## 回退与退役

- onboarding apply 前必须保存生成的 plan 和 hash-bound evidence。
- 回退使用 `plan-reference-repository-removal.sh`，不得手工删除 gitlink、`.gitmodules` 或 registry 行。
- 连续两个季度没有 ADK 独有增量，或 80% 以上差异只是 target/catalog 数量变化时，降级为 metadata-only/disabled。
- 出现 license 变化、仓库 archived、canonical remote 变化、供应链事件或越权 runtime 执行时，立即停止同步并进入 removal review。
