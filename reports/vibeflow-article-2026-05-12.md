# 用了两个月 Superpowers + gstack 之后，我自己造了一个 VibeFlow

**作者**: 低卧扑食
**发布时间**: 2026-05-11 00:15
**原文链接**: https://mp.weixin.qq.com/s/ppB5ElgXwOKCfxGQd7hI-Q

---

## 文章摘要

本文作者分享了使用 Superpowers + gstack 两个月后，自己创建 VibeFlow 的经历和思考。

### 核心观点

1. **AI 编程的关注点正在转变** - 从"模型生成能力"转向"工程系统能力"
2. **很多失败不是模型不会，是开始得太早** - 缺乏系统化的流程约束
3. **VibeFlow 是 SDD + Harness 的交付编排层** - 把 AI 编码从"聊天里临场发挥"变成"按流程推进"

### 主要问题

作者使用 Superpowers + gstack 后发现：
- 两个插件各自能力很强，但对人的要求并不低
- 需要先理解 SDD、Harness、TDD、code review 等工程概念
- 每一步都要自己手动衔接 skill
- **没有一根线把它们串起来**

### VibeFlow 解决方案

VibeFlow 的核心理念：
> "先想清楚，再有节奏地做完。"

关键设计：
- **Office Hours** - 需求澄清阶段
- **DeepResearch** - 深度调研阶段  
- **三维评审** - 从三个视角审查
- **状态机** - 自动推进流程
- **合同化 tasks** - 明确的任务边界

### 实际效果

- 第一次跑会觉得比手动慢（Office Hours 要回答 6 个问题，DeepResearch 要等 10 分钟）
- 但跑完一次后，你手上多了 brief、design、tasks、feature-list、verification 的完整资产链
- 第二次进项目的 agent 能直接接班
- **第三次开始，再去看裸跑的 Vibe Coding，会觉得那是在抽卡**

### 核心结论

> "框架不在多，在闭环。"

VibeFlow 把传统软件工程里的两件常识重新捡回来：
1. **先想清楚**
2. **再有节奏地做完**

用的是 agent 能稳定执行的结构化形式：
- skill
- 状态机
- 合同化的 tasks
- 机器可读的 wiki

而不是工程师脑子里的隐性知识。

### 项目地址

https://github.com/ttttstc/vibeflow

---

*本文来自微信公众号「低卧扑食」*
