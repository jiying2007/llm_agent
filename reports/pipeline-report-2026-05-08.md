# 子仓更新流水线报告

- 生成日期: 2026-05-08
- 执行模式: sync=skip, analyze=skip

## 1. 子仓同步 (跳过)

## 2. 差异扫描

变更仓库数: 0
0

```
[OK] report generated: /home/aiot03/aiot/llm_agent/reports/weekly-change-report.md
```

## 3. 质量分级

| 等级 | 数量 |
|------|------|
| S (核心) | 7 |
| A (长期) | 7 |
| B (按需) | 2 |
| C (观察) | 4 |
| D (放弃) | 4 |

```
=== 子仓库质量分级 (2026-05-08) ===

[0;36m[A][0m AUBB-Server                    score=55  days=21   commits=72    group=delivery           enabled=yes
[0;33m[C][0m Migrationed_skills             score=30  days=42   commits=3     group=skill-pool         enabled=yes
[0;32m[S][0m OpenSpec                       score=85  days=17   commits=567   group=workflow-core      enabled=yes
[0;32m[S][0m agency-agents-zh               score=75  days=19   commits=113   group=agent-ecosystem    enabled=yes
[0;32m[S][0m agent-skills                   score=85  days=11   commits=149   group=agent-ecosystem    enabled=yes
[0;36m[A][0m ai-coding-guide                score=55  days=19   commits=34    group=knowledge          enabled=yes
[0;36m[A][0m arthas                         score=65  days=16   commits=2185  group=delivery           enabled=yes
[0;33m[C][0m artifact-gated-agents          score=20  days=39   commits=3     group=workflow-core      enabled=no
[0;33m[C][0m auto-research                  score=30  days=31   commits=1     group=knowledge          enabled=yes
[0;33m[C][0m autonomous-vehicle-dev         score=20  days=16   commits=4     group=delivery           enabled=no
[0m[B][0m codex-cookbook                 score=48  days=13   commits=17    group=knowledge          enabled=yes
[0;31m[D][0m codex-skill-spec               score=0   days=116  commits=4     group=skill-pool         enabled=no
[0;31m[D][0m codex_doc_cn                   score=5   days=16   commits=64    group=knowledge          enabled=no
[0;36m[A][0m dotfiles                       score=55  days=19   commits=543   group=config             enabled=yes
[0;36m[A][0m hermes-agent                   score=65  days=12   commits=5974  group=delivery           enabled=yes
[0m[B][0m hermes-collaboration-skill     score=50  days=10   commits=2     group=agent-ecosystem    enabled=yes
[0;31m[D][0m hermes-team-skill              score=15  days=12   commits=4     group=agent-ecosystem    enabled=no
[0;32m[S][0m mattpocock-skills              score=75  days=8    commits=63    group=agent-ecosystem    enabled=yes
[0;36m[A][0m prompts                        score=65  days=18   commits=165   group=knowledge          enabled=yes
[0;32m[S][0m skills                         score=75  days=16   commits=128   group=agent-ecosystem    enabled=yes
[0;32m[S][0m superpowers                    score=85  days=15   commits=438   group=workflow-core      enabled=yes
[0;32m[S][0m superpowers-zh                 score=75  days=19   commits=43    group=workflow-core      enabled=yes
[0;31m[D][0m vscode-codex-settings          score=10  days=29   commits=3     group=config             enabled=no
[0;36m[A][0m Trellis                        score=60  days=6    commits=830   group=reference          enabled=yes

=== 分级完成 ===
报告: /home/aiot03/aiot/llm_agent/subrepos/repo-grading-report.md
用法: bash scripts/check-repo-quality.sh --report --auto-disable
```

## 4. 深度分析

本轮无需要深度分析的仓库

## 5. Adoption Matrix

当前条目数: 27

> 如有新分析报告，需人工评估后更新 adoption-matrix

## 6. 跨仓库模式检测

未发现跨仓库共同模式

无 Skill 名称冲突

## 7. 综合建议

### 待处理项


### 下次执行建议

- 检查 D 级仓库是否有新增内容需要吸纳
- 检查 C 级仓库 30 天观察期是否到期
- 更新 adoption-matrix 中 pending 状态的条目

---
*报告由 pipeline-subrepo-update.sh 自动生成*
