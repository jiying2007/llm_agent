# github/spec-kit 安全复核

## 结论

允许作为只读、固定 commit 的 active-reference 长期跟踪；禁止安装或执行。`spec-kit` 具备真实的网络、凭证、文件系统、Git 和 shell 执行能力，不能因 GitHub 官方组织、MIT 或高 stars 而降低 runtime 门禁。

## 审查范围

- stable snapshot：`v0.13.4`
- commit：`ee883a1d4ecee9afe06a81f1bd38a0b745a8d059`
- tree：`b27f6e7260f477ee70d7ad1854a63b04689e98b4`
- source origin：`https://github.com/github/spec-kit`
- 方法：读取 `AGENTS.md`、`LICENSE`、`pyproject.toml`、source tree、integration manifest、bundle installer、GitHub HTTP helper、workflow shell step，并扫描 subprocess/network/delete/write surface。
- 未执行 `specify-cli`、pytest、extension、preset、bundle、workflow 或上游脚本。

## 发现

| Surface | 证据 | 风险 | 本地控制 |
|---|---|---|---|
| 网络下载 | `urllib`、GitHub release asset、catalog、extension/preset/workflow 下载 | SSRF、redirect、恶意 artifact | reference-only；不运行；后续吸收需 host allowlist、size/digest 和 redirect 复核 |
| 凭证 | `GITHUB_TOKEN`、`GH_TOKEN`、auth config、Azure CLI token | token 泄露或跨 host 转发 | 不提供凭证；禁止运行；只保存脱敏 metadata |
| 文件写入/删除 | `write_text`、`unlink`、`rmtree`、managed-file install/remove | 覆盖用户配置或越界删除 | 不安装；不运行上游 CLI；只跟踪固定 Git submodule |
| Git 自动化 | bundled git extension、branch/commit/initialize scripts | 未授权 commit、branch 或 remote 写入 | 不启用 extension；本地治理仍禁止自动 commit/push |
| Shell workflow | `ShellStep` 明确使用 `subprocess.run(..., shell=True)` | catalog workflow 可执行任意本地命令 | runtime 默认禁用；第三方 workflow 必须逐项安全审查 |
| Community catalogs | bundle/extension/preset/workflow catalogs | 供应链、拼写抢注、版本漂移 | 不安装；community 条目只作发现线索 |
| 自升级 | `specify self upgrade` 与 installer subprocess | 未固定版本或安装器变化 | 不安装 CLI；参考仓固定 commit/tag |

## 正向控制信号

- MIT license 和公开 SECURITY.md。
- 默认 Python helper 拒绝一般 `shell=True`；ruff 启用 S602/S604/S605。
- GitHub token 只向已知 GitHub host 附加。
- 部分 HTTP/redirect、size、schema、path traversal 和 malformed input 有负向测试。
- integration manifest 保存 managed-file hash，修改文件默认保留。
- bundle install 失败有 best-effort rollback 和 shared-component 引用计数。

这些信号只降低研究风险，不足以授权 runtime。

## 准入边界

1. materialization 只允许 `local-submodule`，source 必须 clean、origin 精确匹配、HEAD 固定。
2. registry `active` 只允许 fetch/diff/analyze，不允许运行。
3. 不读取或转发本机 token，不执行 `specify init/self upgrade`。
4. 不启用 upstream hook、Git extension、workflow shell step或 community catalog。
5. 后续吸收必须 clean-room 重构，保留 source URL/commit/license/provenance。
6. 任何运行试点必须另建 change，显式列出 transport、工具、凭证、deny-path、日志脱敏和 rollback。

## 阻断条件

- canonical origin、license 或 security policy 漂移；
- source dirty、tag/commit 不匹配；
- onboarding plan hash 漂移；
- 需要凭证、外部写入或执行才能完成“跟踪”；
- registry/path identity 冲突；
- 根工作区不满足 apply workspace gate。
