# 取证链路修复：设计

reference_pins 继续独占批准来源解析，返回冻结 ReferenceSource。intake 只消费验证后的 source identity 或显式 managed gitlink；运行时 source/live 目录从现有 runtime_targets registry 读取。

process_budget 仅负责 shell-free 子进程生命周期和有界双管道 I/O，不是 Agent runtime。stdout 可写入受预算约束的临时归档，stderr 同时消费；超时或洪泛清理子进程组。

intake 对固定 commit 做 git archive。提取仅允许常规文件/目录，跳过链接、拒绝特殊文件和不安全路径。不执行参考仓 hooks/install。扫描逐文件读取，不保存所有文本；保留有限证据样本和完整计数，并显式标记截断。

YAML 解析拒绝 aliases、重复或非字符串键、危险类型和超出事件/嵌套/字节预算的输入。描述兼容 literal/folded/CRLF；内容哈希基于原始读取字节，不基于格式归一化后的 metadata。

报告 source 绑定 commit/tree/kind/origin。结构计数仅用于诊断。自动采纳和 live 写入仍禁止。准备全部报告后逐文件原子替换；这里不声称跨文件事务或对恶意并发目录置换的完整隔离。

## 回滚

回滚整个变更及其新代码/测试/声明依赖，保留研究归档；v2 报告继续作为历史证据保存，不能交给 v1 consumer 伪装兼容。禁止仅恢复旧 Root source fallback 绕过 exact-pin 验证。
