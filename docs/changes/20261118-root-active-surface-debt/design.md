# 最小改动设计

1. Root 版本权威只保留已跟踪的 ADK Gitlink；`adk.lock` 仍是按 source 生成的忽略缓存。组件版本同步仍属于 ADK 自身的 `version-manager.sh`。
2. 退役 Root 旧版本脚本和通用备份恢复脚本；原调用者扫描覆盖当前 `scripts/` 与活跃 `docs/runbooks/`、CI、维护指南，更新实际指向的 `AGENTS.md`、`scripts/README.md`、生产部署手册。
3. 文档保留 source promotion 与 live apply 的独立审批；Root 的回退使用受保护的 pin 修复 PR，live 由 `~/codex` 原生回滚。历史 `reports/`、`docs/changes/` 与 M5 原件不清理。
4. 只修正门禁手册的可核验事实与重复编号，不新增清理框架、影子版本、运行时写入或额外资格。
5. `tests/test_source_hygiene.sh` 直接拒绝两个退役文件重新出现；完整 CI 负责验证其他消费者。
