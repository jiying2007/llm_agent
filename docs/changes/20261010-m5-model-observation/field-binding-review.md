# 当前候选 field 绑定独立复审

- Review Target: working-tree；本轮 field 绑定及 diagnostics/测试增量。
- Reviewer Independence: independent，`/root/m5_review`；未联网、调用模型或写文件。
- Requirement Baseline: field-binding-plan.md；认证 owner、release 权限及历史证据边界不变。
- Spec Verdict / Quality Verdict: PASS / PASS；本轮 blocker=0、major=0、minor=0。

ledger candidate_version 必须匹配 policy；hash-bound pilot-start 必须匹配 canonical ADK commit、pilot、human operator、独立真实软件仓库及路径。reference-pin 的候选与 pinned repository/path/commit 必须在同一份证据中匹配，不能跨文件拼接；managed-gitlink 同样经过候选及事件身份检查。

diagnostics next_actions 只列实际阻断项，已经通过的签名不再留下重复验签动作。合成 helper 只在本轮测试调用链的临时复制 fixture 中重建带 selftest_only 标记的 field 证据和 hash 链，未发现修改真实历史证据的路径。

独立 test_current_m5_diagnostics 13/13 PASS，ResourceWarning 为 error；git diff --check 与 rollover bash -n PASS。最终快照复审确认模块说明、底部注释和未使用 Sequence import 的清理没有包含运行逻辑修改，Spec/Quality 仍 PASS。最终生产文件 SHA256：software_m5_v3.py `851bb444086a64994d4caa6a4ecd65bc9ccc8c2d7b07721bfd038e666aa21bb2`；software_m5_diagnostics.py `69a4f9c3aab9ff9c2134775dcdddc505585d15ad00febd221d497da1940a149b`。

审查只证明本地契约和测试；真实模型、同基线 signed CI/qualification、当前候选 human field/owner 及历史声明继续分别验收。
