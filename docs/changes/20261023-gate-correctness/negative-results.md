# 反例与验证边界

## 修复前

实际运行新增行为测试：12 项，4.409 秒，16 个失败子例与 1 个缺失属性错误。复现 Git 路径引号/空白损坏、rename 离开受管目录漏掉旧路径、非 UTF-8 未 fail closed、暂存区变化后缓存旧 PASS、timeout 子进程晚写哨兵，以及 stdout/stderr 超预算仍返回 PASS。异常属性错误对应本次明确新增的有界诊断接口，不单独计为原审查缺陷。

## 实现后

首轮实现边界测试 14/14、现有 bounded I/O/intake 测试 47/47 通过。Ruff、3 个修改源码的 mypy 和 diff --check 通过。原始输出与修改文件摘要见 evidence/implementation-verification.json；这些历史运行与下方复核修复后的运行分开记录。

首次真实 production contract 图因整合项失败：改动 gates.json 后，reports/current-status.md 的当前投影摘要自然失配，status-projection FAIL 并阻断 2 个依赖项，其余 12 项通过。主 Agent 用唯一生成入口同步当前投影后，最终 test_gate_runner_contract.sh 返回 0：14 项边界测试、完整 contract 图、回执摘要和能力阻塞断言全部通过。原始失败与最终成功日志均保留；历史认证和 release_authorized=false 未改变。

首次额外 mypy 检查指出 gate_runner 既有 JSON 根对象类型不收敛和 cache bool 返回问题；经主 Agent 确认补充最小类型检查，非对象配置明确 ValueError，非对象缓存作为 miss，并增加正负行为控制。未改资格、CI 保护或依赖图。

## 独立审查修复 ROOT-REVIEW-01

独立审查发现 impact.main 使用 if args.base，使显式空 --base 绕过既有非空校验。通过真实 tools.control_plane.cli impact 入口新增回归，修复前 1 项测试在 0.231 秒内失败：CLI 退出 0，输出 required=false、reason=not-required；同一测试中的省略 --base、仅传 --changed-file 正向控制通过。

将条件最小修改为 args.base is not None 后，显式空值进入 Git 参数校验并非零退出，不产生成功回执；省略参数的模式继续正常工作。全部 15 项边界测试在 5.248 秒内通过，定向 Ruff、3 个源码文件的 mypy 及 diff --check 通过。红绿输出分别见 evidence/review-01-red.log、evidence/review-01-boundary-green.log；质量检查见 evidence/review-01-quality.log。

本轮未重复整个 production contract 脚本，保留首轮通过的历史记录，并在实现回执明确阶段；主 Agent 负责最终整合回归。首轮独立审核证据 evidence/independent-review-initial.json 保持原样，ROOT-REVIEW-01 的实现修复等待独立复核，不提前宣称审核通过。
