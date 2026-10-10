# 设计边界

认证器是唯一认证 owner；collector 产生证据，rollover 负责事务写入，diagnostics 只读报告，不能用其中一个入口的预检查替代认证器的消费检查。

共享 runtime validator 对严格读取的单份证据核验 lock identity、manifest/task/grader 绑定、请求与观察模型、任务结果、固定 quality gates、时效及摘要。采集入口保留 lexical 路径，读取与摘要使用同一快照。

签名验证采用显式 pinned cosign/trusted-root，固定 canonical workflow identity/issuer；默认缺项 fail closed，不隐式联网，不从 PATH 接受未经固定的 verifier。认证器与 diagnostics/rollover 复用验证实现。

资格 CI 不接受整数作为成功证据。当前根仓集成需要显式受信签名的 CI 回执，绑定 repository/workflow/event/head/run/attempt/jobs；缺回执不晋级。历史独立 pilot 基线保持原样，不能被重新解释为当前根仓 CI。

晋级复制的是已验证快照，并在终态复核身份。测试用临时、隔离 fixture 和显式 fake verifier；fake verifier 不进入真实配置或受跟踪证据。

重新审查后补充：生产 ADK/root 源码检查拒绝 assume-unchanged 和 skip-worktree 标记，避免 Git clean/diff 隐藏 tracked 变更。manifest 和 canonical task 实际消费快照通过无 filter 的 Git blob 摘要绑定当前已核验 HEAD；任务解析与 dataset 摘要使用同一快照。自定义诊断任务入口保持原有边界。该检查不宣称整个工作树原子冻结，source_snapshot_atomic 仍为 false。

Hosted software-m5 checkout 获取完整历史，以验证 qualification record 中 rollover 前的 signed source baseline；现有的 exact action pins 和 main-push 签名身份保持不变。

源码身份边界同时拒绝源码目录或仓库顶层被忽略的 Python/shell/动态扩展输入，包含可在 Python 启动前加载的 sourceless sitecustomize.pyc。标准 __pycache__/*.pyc 保持缓存边界；本检查不替代 Python 环境隔离或密码学运行证明。

Collector 的 capability/help 和实际 eval 均使用同一个新鲜临时 PYTHONPYCACHEPREFIX，阻止读取既有工作树标准 cache，执行结束自动清理。保留用户原 cache，清除继承的 PYTHONPATH 后由 pinned devkit 显式设置 ADK/src；不使用只能禁止写入的 -B 代替读取隔离。

2026-10-10 执行边界：共用环境同时剔除 BASH_ENV、ENV 和全部 BASH_FUNC_*，保留正常认证、网络及解释器选择配置。执行前选择显式 runtime-binary 或当前 PATH Codex，解析目标并核 executable regular file、记录摘要。临时 PATH 入口以 shell 引用固定原绝对路径，实际 ADK 的 version/exec 均通过该入口；不复制原启动器，保留原路径和相对依赖。执行后检测链接目标变化与摘要变化，发布前再复核摘要。

collection.runtime_identity 为 selected-executable-pre-post-sha256 或 unverified-import；后者只表示当前文件摘要和导入报告，不能证明历史实际执行文件，生产共享消费契约一律拒绝。前后摘要不宣称原子执行、动态依赖闭包或密码学运行证明；合成测试的合法标记也不构成真实资格。
