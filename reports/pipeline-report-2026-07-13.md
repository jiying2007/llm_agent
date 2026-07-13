# 子仓更新流水线报告

- generated_at: 2026-07-13T06:46:07Z
- status: pass
- mode: active
- failure: -

## 阶段结果

| Stage | Status | Exit | Seconds |
|---|---|---:|---:|
| diff-scan | pass | 0 | 0.114 |
| quality-grade | pass | 0 | 0.249 |

## 分析结果

- eligible_repositories: [{"repository": "planning-with-files", "age_days": 7}, {"repository": "scale-engine", "age_days": 17}]
- `planning-with-files` @ `d71b3be47b62`: static evidence complete, decision review required
- `scale-engine` @ `ace49169c419`: static evidence complete, decision review required

## 跨仓模式

- repeated_skill_names: {}
- repeated_pattern_signals: {"explicit-guardrails": 2, "progressive-disclosure-assets": 2, "tests-or-evals": 2, "tool-backed-skills": 2}
- boundary: pattern frequency is discovery evidence, not an adoption decision
- grade_drift: [{"repository": "OpenSpec", "registry_grade": "S", "dynamic_grade": "A"}, {"repository": "oh-my-codex", "registry_grade": "A", "dynamic_grade": "B"}, {"repository": "superpowers", "registry_grade": "S", "dynamic_grade": "A"}, {"repository": "vibeflow", "registry_grade": "S", "dynamic_grade": "A"}, {"repository": "scale-engine", "registry_grade": "A", "dynamic_grade": "S"}]

## 关键输出摘要

### diff-scan

```text
[OK] report generated: ./reports/weekly-change-report.md
```

### quality-grade

```text
=== 子仓库质量分级 (2026-07-13) ===

[0;36m[A][0m OpenSpec                       score=65  days=83   commits=567   group=workflow-core      enabled=yes
[0m[B][0m oh-my-codex                    score=50  days=9    commits=3083  group=codex-runtime      enabled=yes
[0;36m[A][0m planning-with-files            score=55  days=7    commits=294   group=workflow-quality   enabled=yes
[0;36m[A][0m superpowers                    score=65  days=81   commits=438   group=workflow-core      enabled=yes
[0;36m[A][0m vibeflow                       score=65  days=91   commits=113   group=workflow-core      enabled=yes
[0;32m[S][0m scale-engine                   score=85  days=17   commits=325   group=workflow-core      enabled=yes

=== 分级完成 ===
报告: ./subrepos/repo-grading-report.md
用法: bash scripts/check-repo-quality.sh --report --auto-disable
```

## 下一门禁

任何 `decision-candidate.json` 都必须经过语义、重复、架构、许可证、安全和运行效果复核，才能更新 adoption matrix 或修改 agent-dev-kit。
