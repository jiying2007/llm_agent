# 研究消费链收口：审查检查点

## 实施结果

本变更建立在 Root #140 的7.0.32精确晋级与独立main CI36082767634全绿基线上。ADK #146实现重复试验比较，已合并到70fac05125907e4930ee73f3928799e11bac55de；main CI36084512715、签名晋级证据和immutable v7.1.0已实际产生。

Root使用现有adk_promotion生成六文件事务，验证真实signature、ZIP digest、release tar digest与tag commit一致。不手工重写签名JSON，不升级产品资格。源码提交8356c67bfeb8b0d46ef933498e115ec0f95ef125已删除所有准备workflow和传输文件。

## 已执行验证

准备阶段真实运行：tests/test_intake_active_docs.sh通过；tests/test_effect_trial_consumer.sh通过，覆盖四个实际子进程CLI出口：improved、alias-inconclusive、missing-trial-invalid、regressed。输入来自明确标记的合成fixture，不代表真实模型效果。

文档清理保留历史内容并单独归档，活动入口使用JSON-only manifest、exact reference cache及新pipeline参数。新增回归检查实际--help与文档一致。

正式CI仅补充在初始化pinned ADK之后安装该源码包及声明依赖，保持现有签名验证、完整Root回归、跨仓链路和current-or-historical资格检查不变。最终PR与合并后main仍必须独立执行；本文件不提前将其记为通过。

## 负结果与权限

第一次准备运行36084923113的源码、验签、scope检查、文档与CLI测试均成功，但推送被GitHub拒绝：runner token没有workflows权限，不能修改现有ci.yml。处理是将现有CI变更从runner事务中排除，通过已授权GitHub连接器单独提交；没有扩大token权限、降低保护或跳过测试。

## 剩余范围

重复试验基础设施交付不等于真实技能收益证明。真实no-ADK/current/candidate效果、native discover/load、现场事件与LTA-04仍需各自证据；其缺失不阻塞软件修复，但不得填为measured或release-authorized。

回滚应整体撤销本消费链变更及其六文件pin事务，恢复此前验证的7.0.32，不混用版本、接口和attestation。
