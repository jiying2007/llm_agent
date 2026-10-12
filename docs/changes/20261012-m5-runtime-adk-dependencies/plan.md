# M5 runtime 的固定 ADK 依赖准备修复

task-package: v2
kind: implementation
permission: 用户全部授权后的真实运行失败修复
scope: root runtime workflow 与本变更记录
owner: 授权执行代理，不声明人类资格owner
exit: 实际无模型依赖/help验证与独立审查；SCM及新鲜签名CI另阶段验收
handoff: 当前main的新鲜CI与单次剩余模型请求
retention: 脱敏总结reviewing，不存credential或原始模型输出

实际run38260430071的环境初始化、guard、checkout、Python、Cosign和任务trust准备success，但collect在ADK eval帮助探测时失败。复现确认根项目只安装PyYAML，ADK导入需要jsonschema而未安装；能力探测失败发生在模型命令构造/执行之前，实际上游请求0。runner21已准确注销，Sign/Export skipped，旧失败记录保留。

修复在固定子模块初始化后通过同一已安装Python同时安装root与准确ADK项目依赖，并实际运行ADK eval run help。collect导出该Python实体作为ADK_PYTHON_BIN，避免auto选择另一未安装依赖的解释器。模型仍gpt-6.1-sol/medium，单任务/最多一次上游请求，不自动重试；source/signature/header门槛不变。

验证：同一隔离namespace中的实际ADK依赖安装、相同Python与库路径的eval帮助/两个bounded-cost flags，无auth挂载/无模型；workflow兼容与源码diff检查，独立Spec/Quality review。root源码变化后必须取得新main完整signedrootCI，不能用af92历史CI重标。humanfield/owner继续缺证据，整体M5 blocked。
