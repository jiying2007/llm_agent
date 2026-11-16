# 验证记录

## RED → GREEN

在同一基线与新增回归下，先保留旧实现失败，再修改生产入口。

| 实际检查 | RED | GREEN |
| --- | --- | --- |
| source-pin 包装脚本 + 位置 root | 退出 2：argparse 收到多余位置参数 | 退出 0，与实际模块输出相同，source-only |
| source-pin 包装回归 | 非仓库 cwd 下无法导入实际模块 | 实际 Git fixture 通过：位置/flag-only root、空格/相对路径、任意 cwd、参数错误 2 与校验失败 1 的 stdout/stderr/状态保留 |
| stale-reference 现有回归 | 6 项通过，但真实仓扫描失败 | 6 项通过，真实仓扫描通过；生成负例仍被检出 |
| validation-plan 回归 | 22 项中两个真实解析器调用失败：选择器不被接受 | 22 项全部通过；plan 与 harden receipt 参数兼容，unsupported 选择器仍退出 2 |

可复验命令（源码根，按当前工具环境运行）：

```bash
rtk bash scripts/check-adk-source-pin.sh "$PWD" --summary-json
rtk bash tests/test_adk_source_pin.sh
rtk bash tests/test_stale_references.sh
rtk bash scripts/check-stale-references.sh "$PWD"
rtk bash tests/test_validation_plan.sh
rtk git diff --check
rtk bash -n scripts/check-adk-source-pin.sh scripts/check-adk-harden-readiness.sh tests/test_adk_source_pin.sh
```

## 一次 quick 与工具环境复核

只运行一次 `check-all --quick --working-tree`。原始回执为 **45/52、7 项失败**，没有改写为其他总数：本次修复的 source-pin 与 stale-reference 已通过；调用者遗漏将 `rtk` 所在目录加入 PATH，使 `check-harness-loop-engineering.sh` 和 `check-reference-source-integrity.sh` 的嵌套调用新增退出 127。补齐工具 PATH 后，Owner 授权这两个入口各做一次定向复核，均退出 0；后者实际运行 13 项完整性测试。

以下原有五项仍真实失败，未修改源码、证据或判据来消除它们：

- `check-global-codex-health.sh`：活动 `~/codex` doctor 缺失。
- `check-global-codex-target-policy.sh`：活动声明仓缺失。
- `check-runtime-health.sh`：同一活动 Codex doctor 缺失。
- `check-reference-dirty-triage.sh`：既有参考基线过期且复核记录缺失。
- `check-software-m5-readiness.sh`：历史 promotion/scorecard 与当前候选不匹配。

## 证据与限制

原始 command/exit/output 见 `/workspace/scratch/2d4d08f07657/root-checks-implementation/` 下 `red.json`、`green.json`、`quick-command.json`、`quick-result.json` 和 `path-rechecks.json`。实施回执绑定改动文件内容与基线；本记录不替代独立审查或 Root CI。

ADK 与 source-only 升级两路径没有新增变更。没有执行 Docker parity、真实 receipt 资格复核、完整 harden、live refresh、额外全量回归、commit 或 push。`--dry-run` 仅验证实际调用参数兼容；完整 Root 回归由本次 Root CI 执行。

## 独立审查 Major：当前目录可遮蔽实际 verifier

独立审查推翻了首轮“任意 cwd”结论的完整性：当调用者目录包含自定义 `tools/control_plane/adk_interface.py` 时，Python 默认先搜索 cwd，再搜索包装脚本设置的 `PYTHONPATH`。受控假 verifier 因此可对未知参数返回 0；真实 verifier 在干净目录返回 2。原始审查 probe 为 `/workspace/scratch/2d4d08f07657/root-checks-cwd-probe.json`，SHA-256 为 `7e5597e2cdf7e6409fd50aad04aef4d3a991f5e1dd468ba806d801d25c52babf`。

Owner 将修复限定为 R1：先补真实 shadow-tools 回归，再固定 Python 模块搜索起点，保持调用者 cwd 及相对 root/evidence 路径语义。生产改动仅在原 `exec python3` 中加入 `-P`，继续由实际 `adk_interface` 校验；不切换 cwd。

同一新增回归在旧包装脚本上退出 1，六种调用都实际执行了受控 shadow verifier；修复后该回归退出 0，逐项结果如下。比较基准是在已知源码根运行的真实模块，而不是同一 shadow cwd 中的模块。

| shadow cwd 调用 | RED 实际结果 | GREEN 实际结果 |
| --- | --- | --- |
| 有效绝对 root | 假 verifier 退出 0，输出不符 | 实际 source-pin 退出 0，完整输出匹配 |
| 相对 `--root ..` | 假 verifier 退出 0，输出不符 | 实际 source-pin 退出 0，完整输出匹配 |
| 默认 root / flag-only | 假 verifier 退出 0，输出不符 | 实际 source-pin 退出 0，完整输出匹配 |
| 未知参数 | 错误地退出 0 | 实际 argparse 退出 2，stdout/stderr 匹配 |
| 不存在的 root | 错误地退出 0 | 实际校验退出 1，stdout/stderr 匹配 |
| 相对 root 与相对证据文件 | 错误地退出 0 | 从调用者目录读取受控文件后，实际 schema 校验退出 1，完整输出匹配 |

相对证据控制使用无效 schema，在 attestation 调用前终止；它证明路径解析及拒绝状态，不声称真实发布证据有效。回归清除调用者 `PYTHONSAFEPATH`，避免环境预设掩盖旧缺陷。Bash 语法与 `git diff --check` 通过；仅重跑既有 source-pin 定向测试，没有 full/quick 或 R2/R3 回归重跑。

新原始记录保存在 `/workspace/scratch/2d4d08f07657/root-checks-review-fix/`，绑定基线 `ffc4b2ffc008a53bee536bd154564920ad1564ee`、同一 RED/GREEN 测试源码和修复后文件 hash。此修复限定为 cwd 默认模块搜索问题，不构成完整 Python 环境隔离或产品资格证明。R2/R3、ADK、pin/status、门禁、原始 quick 与 Parent 管理的旧 evidence 文件保持不变；后续仍由独立 reviewer 判定。
