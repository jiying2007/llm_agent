# 六项既有资格任务的自动复核

## 入口与输出

```bash
rtk python3 -m tools.control_plane.cli qualification-followup --root . --summary-json
```

这个只读入口收集既有 certifier/diagnostics 的实际输出；它不签发新的资格或审批，不调用模型和远程 runtime。输出到 stdout，调用者可在仓库外保留原始 JSON。

- `scan_status=complete` / 退出 0：六项客观复核均正常结束，允许它们仍然 blocked。
- `scan_status=error` / 退出 1：执行、预算、JSON/schema 或来源一致性有错误；同时保留其他检查结果。
- 每项 `command_exit` 是实际子命令退出码；纯文件清单检查为 null。`result` 保留对应有界原始结果，`remaining_evidence` 与 `next_actions` 指向下一步。
- `qualification_all_ready` 与扫描成功是不同事实；`release_authorized=false`、`may_fill_owner=false` 固定表示本报告没有授权。
- `generated_at` 使用真实 UTC。报告保留前后来源身份、输入摘要和一致性，必须核对实际来源再使用，不能仅凭 artifact 名称或 workflow 绿色下结论。

## 六项权威

| 任务 | 既有权威与正确下一步 |
| --- | --- |
| [ADK #153](https://github.com/jiying2007/agent-dev-kit/issues/153) | Root `native-readiness` 消费精确 ADK；真正认证需 authenticated discovery/load/trigger、签名、受管信任和生产 loader |
| [ADK #201](https://github.com/jiying2007/agent-dev-kit/issues/201) | 三个原始 change 的 Spec/Quality 与真实 Owner 逐项判断；清单和 AI 审查不是人类决策 |
| [ADK #205](https://github.com/jiying2007/agent-dev-kit/issues/205) | ADK `harness readiness --gate` 使用当天日期；七维日期只在实际复审后修改 |
| [Root #236](https://github.com/jiying2007/llm_agent/issues/236) | 条件性 Product M5 当前候选认证；诊断不启动产品部署或未知费用请求，默认离线签名待验证不等于组件签名无效 |
| [Root #154](https://github.com/jiying2007/llm_agent/issues/154) | `effect-readiness`，真实预注册实验、全部当前资产的测量和逐项 Owner 判断 |
| [Root #67](https://github.com/jiying2007/llm_agent/issues/67) | `longitudinal-operation`，真实完整窗口、末窗口观察、事件/风险总结和真实审核；日期届满不替代证据 |

## 持续执行

[qualification-followup workflow](https://github.com/jiying2007/llm_agent/actions/workflows/qualification-followup.yml) 在相关 PR、main push、每天北京时间 **09:23** 和手动 `workflow_dispatch` 运行。只授予 `contents: read`，使用固定 action SHA 与 10 分钟整体预算。每份 artifact 保留 30 天。

PR 执行校验候选代码；主线/定时结果绑定其实际 checkout 的 main 和 ADK gitlink。工作流摘要分别显示扫描状态与六项资格状态。任何错误都保留已生成报告，不通过 `continue-on-error` 把失败任务变成成功。

GitHub 的定时执行可能延迟或漏调度，公共仓长期无活动还可能停用 schedule；实际采集时间和当前 workflow 状态比计划时间更有权威。相关源码 push 与手动入口是补充触发，不能声称无间断的真实现场运行。

## 真实证据到达后的闭环

1. 将真实证据提交到各自既有 governed 入口，保留原始身份、字节摘要、可信来源和实际操作者；按需要独立验签。
2. 实际 Owner 只回答具体待审问题，不替 automation 生成的缺省答案背书。历史包、七维 Harness、G22 与 LTA-04 的审核彼此独立。
3. 执行对应 canonical gate 并通过受保护 PR；主线更新自动触发本复核器。
4. 核对 exact-source/fresh-main 的真实结果后，再按原 issue 的完成条件更新状态。聚合器不自动改期、填 Owner、关单、改信任注册或授权发布。

外部方法依据与本轮具体复核材料见 [研究判断](../changes/20261020-qualification-followup/external-methods.md) 和 [Owner 复核材料](../changes/20261020-qualification-followup/owner-review-packet.md)。
