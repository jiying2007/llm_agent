# Active consumer migration

PR #139 第一轮 GitHub CI（36074864177）中 contract、doc-sync、Sigstore、ADK/Codex identity 通过；root-regression 在 test_reference_source_integrity 失败。原因是 fixture 仍复制单一 intake 模块并使用 Root checkout/v1 report。

追查发现实际 update_pipeline 也依赖 Root checkout 与旧动态评分。现迁移到批准 pin/cache-only source resolver，schema v2；不再自动 pull、执行 diff/grade hooks 或根据技能数量选择来源。显式 --repository 可重复指定批准 ID，--cache-root 与 materialize 一致。缺缓存时分析返回 BLOCKED；report-only 可返回观察完成 PASS，但分析计数为零且来源明确 not-materialized。

旧 --skip-sync/--skip-analyze 参数退出；不提供静默别名。调用方式：

```bash
rtk scripts/pipeline-subrepo-update.sh --report-only --summary-json
rtk scripts/pipeline-subrepo-update.sh --repository OpenSpec --cache-root /absolute/external/cache --summary-json
```

旧 worktree classification 和 dirty pull 拒绝仍独立测试；取证测试改用外部 cache，并保留 dirty 内容隔离、option-like ref/traversal 拒绝、真实 provenance failure 与 JSON/exit 一致性。无测试通过恢复 Root fallback。

局部新增五项 pipeline 回归，总计36 tests / OK；GitHub 继续运行31项基础测试及迁移后的完整 source integrity shell。完整回归结果以本 PR 最新 head 的 CI 为准。没有声明 native/effect/field 资格。
