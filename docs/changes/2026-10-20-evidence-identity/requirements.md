# LTA 原始证据字节身份：需求

## 目标与边界

修复固定源码审查发现的 HEAD/index/worktree 原始字节身份缺口。Git 换行与 clean 过滤不能将变化的工作树证据重新规范化成被接受的 HEAD 对象。

不改变现场数据、Owner 决策、证据链、独立观察周期或产品资格；回归中的临时 Git 仓库仅是软件 fixture。

## 验收

1. HEAD、index 与未经过滤的工作树文件字节身份一致才通过。
2. core.autocrlf 与显式 clean filter 均不能隐藏原始字节变化。
3. 恢复原始字节后继续通过；已有 staged、assume-unchanged、skip-worktree、路径与资源预算负例保持有效。
4. 完整仓库回归和受保护 PR 的当前 head 检查通过后才合并。
