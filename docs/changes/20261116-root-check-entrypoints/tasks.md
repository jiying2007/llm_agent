# 实施与证据

- [x] T1 冻结实际基线，补确定性的 wrapper/真实 parser 回归并保留 RED。
- [x] T2 修改 source-pin 薄包装、单处负例拼写和两个 Python 选择器；最小同步版本说明。
- [x] T3 运行相同定向验证、真实 scanner 与 supported/unsupported parser 控制，保留 GREEN。
- [x] T4 运行一次 Root quick，对比原 45/52，记录仍真实失败的环境/资格项；本次 PATH 额外 127 原样保留，两个受影响入口各做一次授权定向复核。
- [x] T5 检查 diff、确认 source-only 两路径及 ADK 不变，交还独立审查；不 commit/push。

原始实施回执保存在 `/workspace/scratch/2d4d08f07657/root-checks-implementation/`；本目录记录可复验命令、结果摘要和边界。活动 `~/codex` 未提供，Knowledge Provider 与其 Execution Policy 为 unavailable，不伪造 runtime 或最终资格通过。

## 独立审查 Major：R1 cwd 模块遮蔽

- [x] T6 在既有 source-pin 测试中加入真实 caller-owned `tools` 包，保留 valid/invalid 调用的 RED，覆盖相对 root/evidence 语义。
- [x] T7 为当前支持的 Python 显式启用安全模块搜索起点；仅做 R1 定向 GREEN、语法/diff 和范围核对，再交独立审查。

本轮基线为首轮冻结提交 `ffc4b2ffc008a53bee536bd154564920ad1564ee`。新原始回执进入 `/workspace/scratch/2d4d08f07657/root-checks-review-fix/`；不改写首轮 quick 45/52、旧证据或 Parent 管理的 evidence 文件。
