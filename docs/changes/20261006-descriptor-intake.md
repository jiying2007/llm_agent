# 消费端文件读取与实际descriptor绑定

基线Root main ebacd77、ADK8.0.0。审查/tmp实验确认：intake_io先检查symlinkchain/regular再Path.open时，leaf在实际open前换成链接会读到outside目标；runtime_security同类读取窗口。范围仅Root共享byte/hash输入及config审计，ADK安全writer另包，不调整URL、claims、权限、owner或SDK信任期望。

设计复用intake_io单一reader：保留parent symlinkchain preflight，lstat记录常规文件身份，NOFOLLOW/NONBLOCK打开，fstat核对type/device/inode，固定descriptor读取并确保关闭；字节预算在实际fd检查并限量读取。hash流式输入使用同一guard，不新增hash体积限制。read_bytes公开有界入口供TOML审计使用，runtime配置输入错误继续ValueError/脱敏诊断，不另立JSON解码器。

目录由调用方控制；此处不声称父目录并发rename、same-inode内容写入锁或完全原子快照。缺安全flag平台返回明确错误，不unsafe降级；Root既有Python3.11运行基线与supported环境不变。正常regular输入、strictJSON/JSONL及旧byte预算保持，CLI输出/URL期望不变。

确定性回归：普通byte/JSON与exact预算；真实os.open前leaf替换成symlink、FIFO或另一regular文件均拒绝且fd关闭，outside内容不变；digest复用guard且错误不泄漏原始OS内容；config替换拒绝且secret不输出。Source共享输入变化须完整Root回归、完整staged独立复审与freeze身份，不拿定向测试替代这些门禁。

外部依据：[Python官方tempfile安全IO](https://docs.python.org/3/library/tempfile.html)、[SLSA1.2验证期望](https://slsa.dev/spec/v1.2/verifying-artifacts)、[Anthropic工具设计](https://www.anthropic.com/engineering/writing-tools-for-agents)。只设计/测试参考，不引入runtime或真实模型评测。后续actualSCM/运行采用和Provider reviewing候选分别验证，referencebaseline/M5等真实缺项不伪刷新。

回滚保留ebacd77与原分支；回滚本reader会恢复已证明的leaf替换风险。最终完整测试/独立审查及hash写source外阶段证据，避免验证后source漂移。
