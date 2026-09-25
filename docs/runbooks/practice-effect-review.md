# 实践效果复审与重复试验

本工作区负责批准候选与组织证据；ADK负责试验合同和比较，外部运行时负责真正执行。不得将source/test、native/runtime、field证据混用。

先冻结来源commit、具体机制、本地问题、现有对应资产、文件级许可证、安全审查、baseline/candidate bundle、固定任务/trial与控制条件，再记录审查决定。调用方填写的时间和环境引用不自动成为原生证明。

使用已经通过Root pin/接口验签的ADK：

```bash
rtk python -m pip install ./agent-dev-kit
rtk bash agent-dev-kit/scripts/devkit.sh eval compare-trials --input /absolute/evidence/campaign.json --output /absolute/evidence/comparison.json --summary-json
```

输入和结果合同见已pin ADK的 `docs/runbooks/effect-trials.md`、`schemas/effect-trials-v1.schema.json` 与 `schemas/effect-trial-comparison-v1.schema.json`。真实运行数据应满足opaque ref/隐私要求；不要把原始提示、用户内容或凭证提交到公共仓。

出口：improved/non-inferior返回0，regressed返回1，inconclusive/invalid返回2。样本不足、指标缺失、模型别名无法确认为固定revision时，不得写成已改善。统计通过仍需owner审查，不自动写adoption matrix、安装live资产或升级产品资格。

`tests/test_effect_trial_consumer.sh` 只使用固定ADK提供的合成fixture，检查真实CLI跨仓调用和四类退出语义。它不是模型效果实验，不能从该测试推导成功率或延迟收益。需要完整Root回归时先安装本仓和已pin ADK的声明依赖。

恢复执行先核验当前Root/ADK SHA、bundle和已完成run_id；读取已有receipt后再决定下一未完成trial。缺trial保持invalid，不改task ID、不删失败trial、不重复上传成功结果冒充独立样本。CI、签名晋级和产品资格分别收口。


## Profile / context source observability

在进入真实 no-ADK/current/candidate 效果试验前，先记录候选 profile 的 source surface；这不是 runtime 初始上下文或真实 token 计量：

```bash
rtk bash agent-dev-kit/scripts/devkit.sh profile-footprint --profile core --summary-json
rtk bash agent-dev-kit/scripts/devkit.sh profile-footprint --profile core --compare embedded-fullstack --summary-json
rtk bash agent-dev-kit/scripts/devkit.sh profile-footprint --profile core --ratchet --summary-json
```

重点读取 frontmatter、entry body、deferred support 三层字节。bytes/4 仅为启发式估算；真实 runtime token 必须来自 Run Evidence。profile source-growth ratchet 只防止资产面无审查增长，不是上下文窗口上限，也不构成质量评分。

Direct target 的静态可发现/可加载检查使用隔离 source probe：

```bash
rtk bash agent-dev-kit/scripts/devkit.sh target-source-probe --target claude-code --profile core --summary-json
rtk bash agent-dev-kit/scripts/devkit.sh target-source-probe --target opencode --profile core --summary-json
```

该 probe 不触碰用户 live HOME，不启动 native runtime；PASS 仍必须保持 `evidence_level=source-layout`、`native_runtime_evidence=false`、`certification=not-certified`。真实 discover/load/trigger 只能由独立 native runtime campaign 提升。
