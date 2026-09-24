# 取证链路修复：提交检查点

本文件记录提交时证据，不是可手改的发布或资格状态。

- [x] 原方案字节级归档，Git blob 与源文件一致；SHA256 见 archive.json。
- [x] cache-only 来源解析和显式 managed source 实现。
- [x] 进程预算、归档预算、逐文件覆盖与安全 YAML 实现。
- [x] 删除结构化报告中的伪效用总分，保留结构计数和独立语义审查。
- [x] 添加 llm-ctl reference-pins / analyze 入口与运行说明。
- [x] 新增 31 项离线回归；局部源码环境执行通过。
- [ ] 仓库级 CI、所有 active consumer 回归及合并后的 fresh-main 结果：由本 PR / GitHub Actions 实际结果提供，不预填 PASS。
- [ ] 真实上游网络物化、Codex native 加载和配对效果实验：本提交不声称已执行。

## 已执行命令

`python -m unittest discover -s tests -p test_intake_hardening.py`

结果：31 tests，OK。该环境是定向重建的源码测试环境，不是完整 Root checkout；rtk 不可用，未声称验证其包装层。

资源回归：64 个约 256 KiB 文本，总计 16,778,432 bytes；tracemalloc Python allocation peak 约 1.36 MB（断言上限 8 MiB）。此指标不是 RSS、不是浏览器内存，也不是生产容量资格。

运行完整回归：`rtk bash tests/run_all.sh --fail-fast`。不因完整 CI 尚未执行而将局部结果升格。

后续工作保持原计划顺序：ADK repeated-trial/control-variable comparison → Root 实践级实验消费 → 技能/native/context 验证；不受现场数据缺失阻塞软件开发。
