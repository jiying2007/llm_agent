> **注意**: 此报告已被 global-dev-kit v2.0.0 替代，仅供参考。
# llm_agent 全量子仓库深度分析报告

> 生成时间: 2026-05-05 | 分析范围: 26个子仓库 + global-dev-kit
> 目标: 为基于 llm_agent 优化 global-dev-kit 提供全面的参考依据

---

## 一、总览: 26个子仓库质量排名

| 排名 | 仓库 | 质量评分 | 核心定位 | Agent | Skill | Workflow |
|------|------|---------|---------|-------|-------|----------|
| 1 | AUBB-Server | 9.5/10 | 后端业务样本 | 1 | 17 | 20+执行计划 |
| 2 | agent-skills | 9.3/10 | 全流程技能资产 | 3 | 21 | 7命令 |
| 3 | mattpocock-skills | 9.2/10 | 可组合工程技能 | 0 | 22 | 链式组合 |
| 4 | codex_doc_cn | 9.0/10 | Codex文档中文镜像 | 0 | 0 | 5校验脚本 |
| 5 | Trellis | 9.0/10 | AI编码治理框架 | 多平台 | 技能路由 | 3阶段状态机 |
| 6 | skills(天工) | 8.8/10 | 数据获取技能集 | 0 | 43 | 采集链 |
| 7 | arthas | 8.5/10 | Java诊断工具 | 1 | 3 | MCP集成 |
| 8 | dotfiles | 8.5/10 | 系统配置管理 | 4层AGENTS | 0 | Taskfile |
| 9 | ai-coding-guide | 8.5/10 | AI编程实践指南 | 0 | 0 | 场景工作流 |
| 10 | superpowers-zh | 8.3/10 | 中文化流程体系 | 0 | 20 | workflow-runner |
| 11 | codex-cookbook | 8.0/10 | Codex协作方法论 | 4军师 | 4 | 道法术器 |
| 12 | global-dev-kit | 8.0/10 | 全局开发工具包 | 10 | 22+7 | 状态机+证据 |
| 13 | superpowers | 8.0/10 | 工程流程体系 | 0 | 14 | 生命周期 |
| 14 | auto-research | 7.8/10 | 研究闭环 | 15 | 33 | 50+命令 |
| 15 | prompts | 7.5/10 | 提示词资产 | 0 | 10 | 0 |
| 16 | vscode-codex-settings | 7.5/10 | Codex配置 | 0 | 0 | 4阶段规范 |
| 17 | artifact-gated-agents | 7.5/10 | Artifact/Gate协议 | 12 | 0 | 9阶段闭环 |
| 18 | Migrationed_skills | 7.0/10 | 迁移型技能池 | 29 | ~79 | 混合 |
| 19 | OpenSpec | 7.0/10 | Spec驱动框架 | 0 | 0 | DAG引擎 |
| 20 | hermes-agent | (平台级) | Agent核心框架 | 平台 | 27+ | 多入口 |
| 21 | agency-agents-zh | 7.0/10 | 中文角色Agent | 211 | 0 | NEXUS战略 |
| 22 | codex-skill-spec | 7.0/10 | 轻量任务模板 | 0 | 4 | 最小闭环 |
| 23 | hermes-team-skill | 6.0/10 | Hermes升级包 | 0 | 1 | 0 |
| 24 | autonomous-vehicle-dev | 6.0/10 | 自动驾驶重构 | 0 | 0 | 0 |
| 25 | hermes-collaboration-skill | 5.0/10 | 团队协作技能 | 0 | 0 | 早期 |

---

## 二、核心发现: 6大可借鉴维度

### 维度1: Agent 角色设计

**最佳实践来源:**
- **AUBB-Server** (1个Agent + 17个Skill): 任务分流模型(只读/实现/并行) + 5级质量门禁
- **artifact-gated-agents** (12个角色): One Role One Decision + Read-Only Reviewers + 阻塞模板
- **agency-agents-zh** (211个角色): 中国市场深度本土化(小红书/抖音/微信/高考志愿)
- **auto-research** (15个角色): 研究闭环角色(文献/数据/写作/审稿)

**gdk 可借鉴:**
1. AUBB-Server 的任务分流判断模型 → gdk Agent 路由
2. artifact-gated-agents 的 BLOCKED 模板 → gdk 阻塞策略
3. agency-agents-zh 的本土化 Agent 格式 → gdk 中文 Agent 模板

---

### 维度2: Skill 工程化

**最佳实践来源:**
- **agent-skills** (21个): Anti-Rationalization 机制 + 三层编排(Skills/Personas/Commands) + 门控工作流
- **mattpocock-skills** (22个): 小技能可组合 + grill-me 烤问式对齐 + CONTEXT.md 领域语言
- **skills/天工** (43个): 原子化 fetch 技能 + 三步工作流(check→dry-run→fetch) + 健壮性模板
- **superpowers-zh** (20个): 中文化翻译 + 6个原创中国特色 skill

**gdk 可借鉴:**
1. agent-skills 的 Anti-Rationalization 表 → 每个 gdk skill 加"借口拦截"
2. mattpocock 的 grill-with-docs → gdk 需求对齐 skill
3. skills/天工 的 retry/backoff/validate 模板 → gdk 数据获取类 skill
4. agent-skills 的 Intent→Skill 映射表 → gdk skill 路由

---

### 维度3: Workflow 状态机

**最佳实践来源:**
- **Trellis** (3阶段+状态机): 面包屑机制 + hook注入 + 子代理派发 + 知识回写闭环
- **global-dev-kit** (propose→apply→verify→review): Evidence Index + 分级评审
- **artifact-gated-agents** (9阶段): 20个artifact标签 + 统一输出协议
- **OpenSpec** (DAG引擎): ArtifactGraph + 拓扑排序 + 循环依赖检测

**gdk 可借鉴:**
1. Trellis 的 "Specs injected, not remembered" → gdk 规范注入机制
2. Trellis 的面包屑状态机 → gdk 工作流状态追踪
3. OpenSpec 的 DAG 引擎 → gdk 工作流编排底层
4. artifact-gated-agents 的 artifact 标签体系 → gdk 变更工件标准化

---

### 维度4: 工程纪律与质量门禁

**最佳实践来源:**
- **AUBB-Server**: 五维度质量评分卡 + 执行计划六要素(目标/范围/风险/决策/验证/结果)
- **hermes-agent**: Hermetic Testing + 插件不侵入核心 + AGENTS.md 777行工程知识沉淀
- **codex_doc_cn**: 3级翻译质量评定(L1/L2/L3) + 5个自动化校验脚本
- **agent-skills**: 7个slash命令映射生命周期 + references/渐进式披露

**gdk 可借鉴:**
1. AUBB-Server 的执行计划模板 → gdk runbook 标准化
2. hermes-agent 的 hermetic testing → gdk 测试隔离
3. codex_doc_cn 的自动化校验脚本模式 → gdk 资产验证
4. agent-skills 的渐进式披露 → gdk skill 按需加载

---

### 维度5: 多工具适配

**最佳实践来源:**
- **agency-agents-zh**: 16种工具一键安装 + 格式自动转换
- **agent-skills**: 7+工具(Claude/Cursor/Gemini/Windsurf/OpenCode/Copilot/Kiro)
- **Trellis**: 10+平台(Claude/Cursor/Codex/OpenCode/Pi/Kilo/Windsurf...)
- **hermes-agent**: 27个平台适配器(含钉钉/企微/微信/飞书/QQ)

**gdk 可借鉴:**
1. agency-agents-zh 的 convert.sh 格式转换 → gdk 多工具分发
2. Trellis 的平台适配层设计 → gdk tool_targets 实现
3. hermes-agent 的 ADDING_A_PLATFORM.md → gdk 工具接入文档

---

### 维度6: 中文本土化

**最佳实践来源:**
- **agency-agents-zh**: 211个中文Agent(46个中国市场原创)
- **superpowers-zh**: 20个中文Skill(6个中国特色原创)
- **ai-coding-guide**: 9款工具中文实战指南 + 陷阱四段式
- **codex-cookbook**: 道法术器方法论 + 军师技能系统

**gdk 可借鉴:**
1. agency-agents-zh 的本土化Agent模板(小红书/抖音/微信) → gdk 中文场景
2. superpowers-zh 的中文触发词路由表 → gdk 中文 skill 路由
3. ai-coding-guide 的陷阱四段式 → gdk troubleshooting 文档
4. codex-cookbook 的误用边界设计 → gdk skill 反模式

---

## 三、gdk 当前短板与改进路线图

### P0: 立即改进

| 改进项 | 参考来源 | 具体动作 |
|--------|---------|---------|
| 版本撕裂修复 | - | manifest(1.0.0) vs README(0.3.0) 统一 |
| 配置冲突修复 | - | manifest default_mode(symlink) vs README(copy) 统一 |
| Anti-Rationalization | agent-skills | 每个skill加"借口拦截"表 |
| 阻塞模板标准化 | artifact-gated-agents | 采纳BLOCKED/READY模板 |
| skill路由表 | agent-skills + superpowers-zh | Intent→Skill映射 + 中文触发词 |

### P1: 中期改进

| 改进项 | 参考来源 | 具体动作 |
|--------|---------|---------|
| DAG工作流引擎 | OpenSpec | 提取ArtifactGraph为gdk工作流底层 |
| 面包屑状态机 | Trellis | workflow-state标签 + hook注入 |
| 知识回写闭环 | Trellis | Phase 3.3 spec update机制 |
| 执行计划模板 | AUBB-Server | 六要素(目标/范围/风险/决策/验证/结果) |
| 质量评分卡 | AUBB-Server | 五维度自评+下一步 |
| 健壮性模板 | skills/天工 | retry/backoff/validate/quarantine |
| 渐进式披露 | agent-skills | SKILL.md入口 + references/按需加载 |

### P2: 长期改进

| 改进项 | 参考来源 | 具体动作 |
|--------|---------|---------|
| 动态路由引擎 | - | runtime routing从静态文档升级为可执行 |
| Evidence Index结构化 | - | Markdown表格→JSON/YAML |
| 多工具适配层 | agency-agents-zh + Trellis | convert.sh + 平台适配器模式 |
| 中文场景Agent | agency-agents-zh | 本土化Agent模板库 |
| 数据获取skill | skills/天工 | 原子化fetch + 采集链模式 |
| 测试隔离 | hermes-agent | hermetic testing + conftest.py |
| AGENTS.md分治 | dotfiles | 四层分治(根级→子目录→模块级) |

---

## 四、资产复用优先级矩阵

### 直接复用 (可立即集成到 gdk)

| 资产 | 来源 | 复用方式 |
|------|------|---------|
| Anti-Rationalization表 | agent-skills | 嵌入每个gdk skill |
| BLOCKED/READY模板 | artifact-gated-agents | gdk工作流模板 |
| 烤问式对齐(grill) | mattpocock-skills | gdk需求分析skill |
| 陷阱四段式 | ai-coding-guide | gdk troubleshooting runbook |
| 执行计划六要素 | AUBB-Server | gdk runbook模板 |
| 质量评分卡 | AUBB-Server | gdk质量门禁 |
| config.toml注释模式 | vscode-codex-settings | gdk配置模板 |

### 概念借鉴 (需适配后集成)

| 概念 | 来源 | gdk适配方案 |
|------|------|------------|
| Specs injected, not remembered | Trellis | gdk规范注入机制 |
| 面包屑状态机 | Trellis | gdk工作流状态追踪 |
| DAG工件图 | OpenSpec | gdk工作流编排引擎 |
| Intent→Skill映射 | agent-skills | gdk skill路由 |
| 三层编排(Skills/Personas/Commands) | agent-skills | gdk角色/技能/命令分离 |
| 知识回写闭环 | Trellis | gdk持续改进机制 |
| 四层AGENTS.md分治 | dotfiles | gdk文档治理 |

### 领域特定 (选择性集成)

| 资产 | 来源 | 适用场景 |
|------|------|---------|
| 211个中文Agent | agency-agents-zh | gdk中文场景扩展 |
| 43个数据获取skill | skills/天工 | gdk数据采集场景 |
| 48个SEO/CRO skill | Migrationed_skills | gdk营销场景 |
| 4个军师skill | codex-cookbook | gdk协作编排 |
| 33个研究skill | auto-research | gdk学术研究场景 |

---

## 五、关键文件索引

每个子仓库的关键分析文件路径:

```
global-dev-kit:     /home/aiot03/aiot/llm_agent/global-dev-kit/AGENTS.md
                    /home/aiot03/aiot/llm_agent/global-dev-kit/manifest.yaml
superpowers:        /home/aiot03/aiot/llm_agent/superpowers/README.md
superpowers-zh:     /home/aiot03/aiot/llm_agent/superpowers-zh/README.md
agency-agents-zh:   /home/aiot03/aiot/llm_agent/agency-agents-zh/AGENT-LIST.md
agent-skills:       /home/aiot03/aiot/llm_agent/agent-skills/AGENTS.md
auto-research:      /home/aiot03/aiot/llm_agent/auto-research/AGENTS.md
artifact-gated:     /home/aiot03/aiot/llm_agent/artifact-gated-agents/AGENTS.md
OpenSpec:           /home/aiot03/aiot/llm_agent/OpenSpec/README.md
codex-skill-spec:   /home/aiot03/aiot/llm_agent/codex-skill-spec/AGENTS.md
hermes-agent:       /home/aiot03/aiot/llm_agent/hermes-agent/AGENTS.md
hermes-collab:      /home/aiot03/aiot/llm_agent/hermes-collaboration-skill/README.md
hermes-team:        /home/aiot03/aiot/llm_agent/hermes-team-skill/SKILL.md
arthas:             /home/aiot03/aiot/llm_agent/arthas/AGENTS.md
AUBB-Server:        /home/aiot03/aiot/llm_agent/AUBB-Server/AGENTS.md
autonomous-vehicle: /home/aiot03/aiot/llm_agent/autonomous-vehicle-dev/AGENTS.md
ai-coding-guide:    /home/aiot03/aiot/llm_agent/ai-coding-guide/README.md
codex_doc_cn:       /home/aiot03/aiot/llm_agent/codex_doc_cn/AGENTS.md
codex-cookbook:     /home/aiot03/aiot/llm_agent/codex-cookbook/codex-cookbook.md
mattpocock-skills:  /home/aiot03/aiot/llm_agent/mattpocock-skills/README.md
Migrationed:        /home/aiot03/aiot/llm_agent/Migrationed_skills/catalog/INDEX.md
skills(天工):       /home/aiot03/aiot/llm_agent/skills/AGENTS.md
prompts:            /home/aiot03/aiot/llm_agent/prompts/AGENTS.md
dotfiles:           /home/aiot03/aiot/llm_agent/dotfiles/docs/AGENTS.md
vscode-codex:       /home/aiot03/aiot/llm_agent/vscode-codex-settings/AGENTS.md
Trellis:            /home/aiot03/aiot/llm_agent/Trellis/.trellis/workflow.md
```

---

## 六、总结

llm_agent 工作区包含 26 个子仓库，覆盖了 AI 辅助开发的完整生态:

- **方法论层**: superpowers/superpowers-zh (工作方法论) + codex-cookbook (协作哲学)
- **角色层**: agency-agents-zh (211个角色) + artifact-gated-agents (12个角色协议)
- **技能层**: agent-skills (21个) + mattpocock-skills (22个) + skills/天工 (43个) + auto-research (33个)
- **流程层**: Trellis (治理框架) + OpenSpec (DAG引擎) + global-dev-kit (生产底座)
- **平台层**: hermes-agent (Agent框架) + ai-coding-guide (工具指南)
- **工程层**: AUBB-Server (业务样本) + arthas (诊断工具) + dotfiles (基础设施)

**gdk 优化的核心策略**: 从"自建一切"转向"精选吸收"——从上述 6 大维度中挑选最佳实践，通过 gdk 的 manifest.yaml + install_assets.sh + devkit.sh 体系进行工程化压实。
