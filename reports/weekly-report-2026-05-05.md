# 周报: 2026-05-05

> 自动生成于 2026-05-05 22:25:18

## 1. 本周 Git 提交摘要（最近 7 天）

本周共 **14** 次提交。

```
f1abf08 feat(scripts): 合并 codex pilot 检查脚本
5f05fed docs: 关联 repo-onboarding 技能到接入 Runbook
0f1a45c fix(workspace): 修复碎片化流程闭环问题
d691a22 feat(workspace): 新仓库接入闭环脚本和 Runbook
c0c9a99 refactor(llm_agent): 工作区全面优化 — 去冗余、补治理、加基建
ec36d57 sync(llm_agent): 同步 global-dev-kit v2.0.0 变更
a3ba8a9 feat(llm_agent): 添加全局文档、脚本和模板
6d95df3 feat(llm_agent): 更新global-dev-kit子模块到完全体release状态
7755a74 docs: 补齐 llm_agent 使用指南与维护指南，纳入 Trellis 子项目
47ffa61 feat(governance): implement production-grade gdk landing with six-scenario pilot coverage
3a64dec refactor(governance): transition wave10 observe items to adopt status
bd05cae feat(governance): finalize gdk v1 freeze and implement automated absorption gates
465ee2d feat(governance): implement subrepo tracking and automated reporting system
ccea7fd Init
```

## 2. 子仓同步状态

- 总仓库数: 25
- 启用 (enabled=yes): 23
- 禁用: 2

| 仓库 | 分组 | 优先级 | 同步模式 | 启用 | 状态 | 本地目录 |
|---|---|---|---|---|---|---|
| AUBB-Server | delivery | P2 | fetch | yes | active | ok |
| Migrationed_skills | skill-pool | P1 | fetch | yes | active | ok |
| OpenSpec | workflow-core | P0 | fetch | yes | active | ok |
| agency-agents-zh | agent-ecosystem | P1 | fetch | yes | active | ok |
| agent-skills | agent-ecosystem | P1 | fetch | yes | active | ok |
| ai-coding-guide | knowledge | P1 | fetch | yes | active | ok |
| arthas | delivery | P2 | fetch | yes | active | ok |
| artifact-gated-agents | workflow-core | P0 | fetch | yes | active | ok |
| auto-research | knowledge | P2 | fetch | yes | active | ok |
| autonomous-vehicle-dev | delivery | P1 | fetch | yes | active | ok |
| codex-cookbook | knowledge | P1 | fetch | yes | active | ok |
| codex-skill-spec | skill-pool | P1 | fetch | yes | active | ok |
| dotfiles | config | P2 | fetch | yes | active | ok |
| global-dev-kit | gdk-core | P0 | pull | yes | active | ok |
| hermes-agent | delivery | P1 | fetch | yes | active | ok |
| hermes-collaboration-skill | agent-ecosystem | P1 | fetch | yes | active | ok |
| hermes-team-skill | agent-ecosystem | P2 | fetch | yes | active | ok |
| mattpocock-skills | agent-ecosystem | P1 | fetch | yes | active | ok |
| prompts | knowledge | P2 | fetch | yes | active | ok |
| skills | agent-ecosystem | P1 | fetch | yes | active | ok |
| superpowers | workflow-core | P0 | fetch | yes | active | ok |
| superpowers-zh | workflow-core | P0 | fetch | yes | active | ok |
| vscode-codex-settings | config | P1 | fetch | yes | active | ok |


## 3. Adoption-Matrix 变更

- 总条目数: 45
- 本周相关提交: 5
- 决策分布: adopt=23 / observe=0
0 / reject=2
- 验收状态: done=24 / pending=0
0 / blocked=1

本周相关提交记录:
```
0f1a45c fix(workspace): 修复碎片化流程闭环问题
47ffa61 feat(governance): implement production-grade gdk landing with six-scenario pilot coverage
3a64dec refactor(governance): transition wave10 observe items to adopt status
bd05cae feat(governance): finalize gdk v1 freeze and implement automated absorption gates
465ee2d feat(governance): implement subrepo tracking and automated reporting system
```

## 4. 质量门禁状态

**综合状态: FAIL**

### health-check.sh
FAIL: 健康检查未通过
```
[0;31m[ERROR][0m 未知命令: .
健康检查脚本

Usage:
  ./scripts/health-check.sh <command> [options]

Commands:
  check-all              执行所有健康检查
  check-structure        检查目录结构
  check-dependencies     检查依赖
  check-configuration    检查配置
  check-tests            检查测试
  check-quality          检查质量

Options:
  --verbose              详细输出
  --fix                  自动修复问题
  -h, --help             显示帮助

Examples:
  ./scripts/health-check.sh check-all
  ./scripts/health-check.sh check-structure --verbose
  ./scripts/health-check.sh check-tests --fix
```

### check-adoption-matrix-status.sh
PASS: adoption-matrix 状态合规

### check-agents-coverage.sh
FAIL: AGENTS 覆盖不足
```
repo                         local    root    
---------------------------- -------- --------
agency-agents-zh             YES      YES     
agent-skills                 YES      YES     
ai-coding-guide              YES      YES     
arthas                       YES      YES     
artifact-gated-agents        YES      YES     
AUBB-Server                  YES      YES     
autonomous-vehicle-dev       YES      YES     
auto-research                YES      YES     
codex-cookbook               YES      NO      
codex_doc_cn                 YES      YES     
codex-skill-spec             YES      YES     
dotfiles                     YES      YES     
global-dev-kit               YES      YES     
hermes-agent                 YES      YES     
hermes-collaboration-skill   YES      YES     
hermes-team-skill            YES      YES     
mattpocock-skills            YES      YES     
Migrationed_skills           YES      YES     
OpenSpec                     YES      YES     
prompts                      YES      YES     
skills                       YES      YES     
superpowers                  YES      YES     
superpowers-zh               YES      YES     
Trellis                      YES      YES     
vscode-codex-settings        YES      YES     

[SUMMARY] local_missing=0 root_missing=1
```


---

*本报告由 scripts/generate-weekly-report.sh 自动生成*
