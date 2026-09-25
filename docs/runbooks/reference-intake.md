# Cache-only reference intake

## 安装与来源

在隔离 Python 3.11+ 环境执行 `rtk python -m pip install .`。Root package 0.2.0 声明 PyYAML，不能依赖其他工作区偶然安装的包。

```bash
rtk llm-ctl reference-pins --root . --summary-json
rtk llm-ctl reference-pins --root . --plan OpenSpec --summary-json
rtk llm-ctl reference-pins --root . --materialize OpenSpec --summary-json
rtk llm-ctl analyze OpenSpec --root . --all --summary-json
```

网络操作只发生在显式 materialize；analyze 不自动 clone。来源由 manifests/reference_pins.json 决定，HEAD 仅表示该批准 pin，不允许任意移动分支。使用自定义 `--cache-root` 时，plan/materialize/analyze 必须使用同一外部 cache 路径。

分析 ADK managed dependency 需要已初始化的 exact gitlink：

```bash
rtk llm-ctl analyze agent-dev-kit --root . --source-kind managed-dependency --all --summary-json
```

旧 scripts/analyze-repo.sh 保持为薄包装，参数直达同一实现。Root 中创建参考仓或软链接不会成为 fallback。Codex frozen evidence gitlink 不是 active managed source。

## 预算与结果

可配置 `--max-archive-bytes`、`--max-archive-members`、`--max-text-bytes`、`--timeout-seconds`。时间预算按子进程/分析阶段执行，不代表从 CLI 启动到报告落盘的单一总时限。所有来源验证命令也有独立有限超时。

analysis/result 使用 v2。`status=pass` 表示分析命令正常完成；`analysis_status=static-partial` 表示存在明确的未覆盖文件或跳过链接。读取 coverage/by_status、by_suffix、invalid_skill_frontmatter 和 evidence_truncated 后再解释结果。不得把没有分析的文件当作没有相关机制。

结构数量不是采纳分数。decision-candidate 始终 review-required、auto_apply=false；语义、重复、架构、许可证、安全与效果审查仍必须独立完成。运行时认证、发布资格和产品现场资格均不由分析报告继承。

## 回归

```bash
rtk bash tests/test_intake_hardening.sh
rtk bash tests/test_reference_pins.sh
rtk bash tests/run_all.sh --fail-fast
```

测试使用本地合成 Git 仓和隔离目录，不调用模型、不读用户凭证、不写真实 live HOME。
