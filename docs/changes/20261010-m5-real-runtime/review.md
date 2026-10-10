# 本轮独立只读复审

- reviewer: `/root/m5_review`，只读；未修改源码，未调用模型或网络。
- target: 根仓 working-tree，模型默认值、exec 参数、证据字段、签名工具预算及相关 fixture。
- source_map_sha256: `f5d27bc231360e2f637967d5f469f042e32d771c7a7c56b2512263d4d738ae0c`；54 个 Python 文件已与本轮离线 wheel 逐字节核对。
- final_verdict: Spec PASS / Quality PASS；未发现新增 blocker/major。

1. 默认模型与 medium 参数：核 collector 与 rollover 单一默认来源，exec-only shim 和版本检查路径相容；requested effort 不写成 observed，raw-import 保持 unverified。独立相关 unittest 17/17 PASS。
2. 真实 Cosign 大小适配：256 MiB 有限预算容纳官方 v3.1.3，本体验证摘要、安全读取、冻结输入及离线验证保留。独立相关签名回归 4/4 PASS；不将模拟子进程测试当真实签名证明。
3. 两项 shell fixture 修正：默认模型 fixture/断言一致，所有输入拒绝负例保留；reference plan-only cache 使用 source root 外空临时目录，不改生产 overlap 拒绝。两脚本 bash -n PASS；行为复验由主代理定向及完整回归取证。

真实模型身份、promotion 签名、当前根仓 CI、field 与 owner 资格按 verification.md 分别判断。本轮源码审查通过不授予 M5 或 release 资格。
