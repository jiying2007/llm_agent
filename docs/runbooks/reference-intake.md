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

可配置 `--max-archive-bytes`、`--max-archive-members`、`--max-text-bytes`、`--timeout-seconds`。archive 生成、安全解包、Git tree 清单读取和 blob 字节对账共享一个快照阶段时限；文本分析使用独立阶段时限。所有来源验证命令也有独立有限超时，不能把该参数理解为从 CLI 启动到报告落盘的单一总时限。

archive 输出、解包后的文件总字节、Git tree 清单输出和 blob 对账读取各自受 archive 字节预算约束；archive 成员和原始 tree 叶子条目分别受成员预算约束。单条 tree 元数据最多 64 KiB，缺口路径每种状态最多展示 20 个。超过字节、成员或时间预算会失败，不会发布本轮完整分析结论。

analysis/result 使用 v2。`status=pass` 表示分析命令正常完成；`analysis_status=static-partial` 表示存在原始来源覆盖缺口、未读取的文件或无效 Skill frontmatter。读取下述两层覆盖、`by_suffix`、`invalid_skill_frontmatter` 和 `evidence_truncated` 后再解释结果。不得把没有分析的文件当作没有相关机制。

### 原始 tree 与 archive 覆盖

`git archive` 会遵循来源的 `export-ignore` 和 `export-subst`：前者可遗漏受控文件，后者可替换其内容。因此 archive 文件清单不代表固定提交的完整原始内容。

分析通过同一批准 commit 的有界 `git ls-tree -r -z --full-tree` 清单核对普通文件、符号链接和 gitlink，再流式计算解包文件的 Git blob 对象 ID，与 tree 中的 SHA-1 或 SHA-256 OID 比较。清单保留原始路径，tab/newline 不作为记录分隔符。过程不执行上游代码，不读取 dirty 工作树内容来替代固定提交，也不物化或跟随 gitlink/符号链接。

`source.snapshot_coverage` 的 `scope=git-tree-leaf-entries`，`identity_check=git-blob-object-id`；`total_entries` 是原始 tree 叶子条目数，等于 `by_status` 各计数之和：

| `by_status` 状态 | 含义 |
|---|---|
| `matched-blob` | 普通文件的解包字节匹配源 blob OID；是否能进行文本分析仍取决于文本覆盖。 |
| `archive-omitted` | 原始 tree 的普通文件未出现在快照中；`export-ignore` 是可能原因。 |
| `archive-transformed` | 解包字节不匹配源 blob OID；`export-subst` 是可能原因。 |
| `skipped-symlink` | 原始 tree 含符号链接；不跟随、不分析目标。 |
| `skipped-gitlink` | 原始 tree 含子模块 gitlink；不递归读取或初始化子模块。 |

`gap_path_examples` 提供各缺口状态的有界示例，`gap_examples_truncated` 明确示例是否截断。`source.skipped_archive_links` 继续表示解包时跳过的链接成员数，与 tree 清单的计数域不同，不要将二者相加。

顶层 `coverage.scope=extracted-archive-files`，其 `total_files` 继续表示解包得到的普通文件数。被转换的文件保留结构记录，但其 `read_status=archive-transformed`，不进入内容、Prompt 或 guardrail 分析；Skill 的 `frontmatter_status=not-read`，`sha256` 和 `lines` 为 null，不把转换后的字节当作源文件证据。

只有原始来源覆盖 `complete`、解包文件均已分析且没有无效 Skill frontmatter 或跳过链接时，才报告 `static-complete`。真实空 tree 可以完整覆盖；非空 tree 被全部 export-ignore 后的空 archive 必须为 `static-partial`。更新流水线将这类结果计入 `analysis_coverage.partial`，不会把命令成功解释成来源已全面分析。

既有 v2 报告不被批量改写。缺少 `source.snapshot_coverage` 的历史结果没有本次 tree/blob 对账证据，需要重新执行分析后才能形成新的覆盖结论。

### 人工审查边界

结构数量不是采纳分数。decision-candidate 始终 review-required、auto_apply=false；语义、重复、架构、许可证、安全与效果审查仍必须独立完成。运行时认证、发布资格和产品现场资格均不由分析报告继承。

人工审查先解释全部覆盖缺口，再决定是否需要单独复核固定提交的原始 blob。intake 不会因为有缺口而自动修改来源属性、执行参考脚本、采纳资产或写入 ADK；候选仍需独立 review-required 流程。

## 回归

```bash
rtk bash tests/test_intake_hardening.sh
rtk bash tests/test_reference_source_integrity.sh
rtk bash tests/test_reference_pins.sh
rtk bash tests/run_all.sh --fail-fast
```

测试使用本地合成 Git 仓和隔离目录，不调用模型、不读用户凭证、不写真实 live HOME。
