# 反例与验证边界

## METHODS-REVIEW-01：GitHub 文件来源归属

独立 reviewer 发现 EXT-05/06/07/08 的完整 GitHub blob URL 被当作 repository.full_name。完整来源 URL 和固定 revision 本身正确，错误发生在既有 manual collector 的仓库身份派生。

在现有 tests/test_external_practice_intake.sh 中补充一个通过 scripts/practice-intake.sh collect 运行的八条 metadata 事务，覆盖仓库 URL、两个相同仓库和 revision 的不同文件、仓库段 .git 的文件 URL、缺少仓库段、GitLab nested subgroup 仓库/文件路径及 Gitee 正向控制。测试同时检查固定 candidate ID、完整 canonical_url、revision 和 review-required 边界。

修复前实际测试 exit 1：collector 生成八条 candidate，但行为断言发现 example/agent/blob/<revision>/first.md 不等于 example/agent。红测见 evidence/methods-review-01-red.log。修复限定在 _manual_repository 的 github.com 分支；非 GitHub 沿用既有完整路径逻辑。

修复后完整 external-practice intake 脚本和 reference repository registration 回归均 exit 0；shell 语法与 diff --check 通过。未新增 module 或修改 gate。日志和准确命令见 evidence/methods-review-01-implementation.json 及其引用文件。

## 本轮 ledger 重新生成

通过既有 canonical collector 重新生成 candidates.jsonl 与 collection.json。与修复前冻结快照逐字段比较，只有以下四项 repository.full_name 改变：

| 来源 | 正确仓库身份 |
| --- | --- |
| EXT-05 | addyosmani/agent-skills |
| EXT-06 | mattpocock/skills |
| EXT-07 | cursor/plugins |
| EXT-08 | cursor/plugins |

十二个 candidate ID、完整 canonical_url、revision 及其余候选字段全部保持；十二条既有 decision 和原始 source metadata 文件字节未改变。collection 仅更新 ledger_sha256 和实际 duration_ms，其 input_sha256 与 ledger_sha256 均匹配当前文件。policy、candidate、decision、evidence 四项 canonical check 全部 exit 0。

原始 reviewer 文件 review-findings.md 未修改，最终独立复核由 external_methods 完成。所有 candidate 继续 unverified-metadata/review-required，body_persisted=false、auto_actions=[]；结构和行为验证不证明外部内容、许可证、真实任务收益或产品资格。

当前共享工作树 validation plan 为 L4，包含已存在的 status projection 发布敏感面；最终整合门禁与组件发布由主 Agent 统一执行。本实现者仅声明上述实际定向检查通过。
