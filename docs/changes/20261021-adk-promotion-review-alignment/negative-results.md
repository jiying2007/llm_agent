# 原始限制与恢复

## 本地解释器入口

恢复后的隔离 venv 保留依赖，但 `python` 与 `python3.12` 指向缺失的 `python3`，直接运行实际失败。2026-10-21T10:32:33–10:32:34Z 通过 Python 官方 `venv --upgrade` 恢复同一隔离环境的标准入口，exit 0；随后实际确认 Python 3.12.14、PyYAML 6.0.3、jsonschema 4.26.0。仓库源码与 HOME 配置未因此改变。

## 本地 Docker parity

`run-local-ci-parity.sh --python all --mode full` 于 10:33:04Z 实际 exit 2，原文为 `[FAIL] docker is required for local CI parity`。本轮没有生成 supported-full Docker receipt；远端三版本 CI 的结果单独记录。

## 首次构建包字节不同

首次本地 tar 为 2,239,547 bytes、SHA-256 `caeaaea2863850dc8ec66dfd7d285ff75dbddeebe4fd7956f31cdc2916e42a40`，与正式包不同。逐成员比对定位到本轮移除旧重复审查副本后留下的两个自有空目录：`evidence/harness-quality` 和 `evidence/harness-spec`，均位于 ADK `docs/changes/20261021-harness-utc-date/` 下，且不在 Git index / HEAD。

全部 1,664 个 regular file 内容相同，2,080 个共同成员的 metadata 相同，release manifest 原始字节相同。差异来自归档包含的两个目录 header。仅对这两个已确认的空目录执行 `rmdir`，保留首次制品与诊断证据；重新构建后 tar、checksum 和 release manifest 与正式原件逐字节一致。所有受管内容及 index 指纹保持不变。

## Canonical Hub 不可用

真实 `/root/codex` 目录缺失。apply policy preflight 于 10:36:44Z 返回 exit 2，明确 `policy_invoked=false`；10:40:40Z 对真实 Knowledge Provider 路径的调用返回 exit 127 / No such file。没有把源码子模块替换成 live Hub，也没有声称 Provider 或 Execution Policy 通过。当前发布结论保存在受保护 Git 交付与本轮审计记录中，Provider 归档仍受该环境限制。

上述时间均为 2026-10-21 UTC。后续 Root 原始门禁结果按实际退出记录在最终 PR 和审计原件中，保留环境限制与真实资格缺口。
