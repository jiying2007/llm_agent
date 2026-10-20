# Intake 原始来源覆盖：提交检查点

- [x] 固定并核对 Root 基线 `f42395a37dced7e59867d0c46891ecd84c218585`。
- [x] 保留安全 archive，增加有界 Git tree / blob 对账及显式来源覆盖状态。
- [x] 转换文件从内容分析和源 Skill 哈希证据中排除；保留解包文件总数语义及人工采纳边界。
- [x] 增加真实本地 Git 行为回归：部分/全部 export-ignore、export-subst、空 tree、SHA-1/SHA-256、tab/newline 文件名、symlink/gitlink、成员和字节预算、有界示例、下游 partial 汇总及损坏 PAX 负例。
- [x] `rtk bash tests/test_intake_hardening.sh`：47/47 通过；最后一次定向执行为 3.023 秒。
- [x] `rtk bash tests/test_reference_source_integrity.sh`：12/12 Python 回归及 shell 端到端通过，覆盖固定来源分析、cache-only pipeline 和结构化失败证据。
- [x] 同步 reference intake runbook 和维护指南中的 F6 段落；测试临时目录已清理，无真实来源或 live 资产写入。
- [ ] 完整 L3 本地回归、PR 当前 head CI 和合并后 fresh-main：由实际检查结果提供，不预填 PASS。

## 本地证据边界

上述定向测试通过真实官方 rtk OSS 1.0.1，在隔离环境 Python 3.12.14 / PyYAML 6.0.3 上执行，使用临时合成 Git 仓库，不调用模型或付费服务。SHA-256 用例已执行，未跳过。测试结果证明本次静态覆盖和软件边界，不是实际 Agent 效果、Owner 审查、运行现场或发布资格。

定向 Ruff 检查与固定 HEAD 比对没有新增规则计数，消除两条旧 import 顺序告警；两个文件仍有 17 条原有告警，因此不声明 Ruff 全绿。保留原有 `timezone.utc`，不按 Python 3.11 lint 建议引入不兼容 Python 3.8 的 `datetime.UTC`。Python 3.8 grammar 检查通过，仅是语法检查，不替代该版本运行时测试。

Provider 的 `~/codex` 入口在本环境缺失，记录为 unavailable，由主会话统一处理执行策略与最终门禁；本地回归不替代这些要求。
