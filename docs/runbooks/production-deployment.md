# 生产部署与回退（Root / ADK）

本手册只描述当前有效的**源码消费**与**运行资产交付**。Root 本身不是 Agent runtime，不直接写 `~/.codex`，不得使用旧工作区版本锁、通用目录恢复或未审查的安装脚本替代 Gitlink / CI 验证。

## 1. 身份和职责

| 层 | 唯一事实源 | 允许动作 |
| --- | --- | --- |
| ADK 组件 | `agent-dev-kit/manifest.json`、已验证 commit/tag、不可变 Release 及摘要 | 构建、测试、发行纯 Agent/Skill 资产 |
| Root 消费 | Root 的 `agent-dev-kit` Gitlink、生成的 `reports/current-status.md` | 受保护 PR 更新 source pin 并运行跨仓验收 |
| Codex 声明式源 | `~/codex` 的自身 Manifest、构建与 apply/rollback 记录 | 独立审查后发布到 live |
| Codex live | `~/.codex` | 只接收 `~/codex` 经过批准的 apply，不从 Root 直接写 |
| 产品资格 | 当前源码身份对应的 runtime/field/owner 证据 | 单独认证，**不能**从组件发行或历史 M5 继承 |

Root 的 `adk.lock` 是忽略的可重建缓存，不是第二套版本权威。

## 2. 组件升级：先发行，后精确消费

1. 在 ADK 为**一个明确改动**提交有界需求、验证与回滚说明。需要修改公共 API、安装、版本或发布时，先检索消费者并在受保护 PR 完成完整回归。
2. 使用原 `agent-dev-kit/scripts/version-manager.sh` 将 Manifest 与受管版本字段一起前移；禁止只改 README 或手工改动已发布标签。
3. ADK 合并后以实际主线 CI、签名/摘要及不可变 Release 为准。若主线未发行、`latest` 倒退或 tag 与源码不符，停止 Root 晋级。
4. 在**干净、已审查的候选工作树**中复用 `scripts/promote-adk.sh --source-only --apply` 生成 Root 消费事务。事务仅包含 Gitlink 与生成状态投影；临时构建步骤不能进入最终 main。
5. Root PR 必须通过独立审查、不可变发行摘要与来源校验、接口合同、消费链和原有完整 CI；受保护合并后再核验 actual-main CI 和签名回执。

```bash
# 均在 llm_agent 受治理工作区、已准备好 rtk / Python 3.12 环境中执行
rtk python3 -m tools.control_plane.cli status --root . --summary-json
rtk bash scripts/check-adk-lock.sh . --pin-only
rtk bash scripts/check-current-status-consistency.sh .
# source-only --apply 仅限经批准的升级候选，不能在普通工作目录盲跑
```

来源与消费就绪不等于 `release_authorized=true`；状态以生成投影和产品资格证据独立判断。

## 3. Codex source-to-live

只有明确的 live 交付意图、环境可用和授权范围可核实，才进入 `~/codex`：

```bash
rtk bash ~/codex/scripts/build.sh
rtk bash ~/codex/scripts/doctor.sh --scope all
rtk bash ~/codex/scripts/plan.sh --target ~/.codex --prune-stale --output ~/codex/build/apply-plan.json
rtk bash ~/codex/scripts/apply.sh --plan ~/codex/build/apply-plan.json --dry-run
```

审查计划中所有新增、覆盖、删除和权限变化，取得 owner 的本次授权后，才由 `~/codex` 执行正式 apply 与 live health。以上命令是既有接口示例，实际参数以检出的 `~/codex` 版本和它的 `--help` 为准。Root 不替代这个过程，不以静态 smoke 代替宿主验证。

## 4. 故障处理与回退

- **ADK 发行失败**：暂停消费；保留失败日志和上个不可变版本，不重写或移动已发布标签。
- **Root 消费失败**：保持现有 pin；通过受保护修复 PR 重新生成、核验 Gitlink/状态投影，不手改生成区域。
- **live apply 失败或运行退化**：按 `~/codex` 的已审查 rollback/恢复能力和最新有效计划处理，再独立执行健康检查；不对 `~/.codex` 使用通用 `rm -rf` 或直接解包恢复。
- **资格验证失败**：状态保持 `HISTORICAL_NOT_AUTHORIZED` / `release_authorized=false`，直到新身份获得新鲜签名、runtime 和 field 证据。

## 5. 最小交付回执

记录精确 ADK commit、Release/tag/digest、Root merge commit、两仓 CI URL、是否实际执行 source-to-live、live 变更计划/审批与健康结果，以及未测/阻断项。历史的原始失败和最后一次 M5 基线不得清空、篡改或重新贴到当前源码身份。

参见 [Root 维护指南](../llm-agent-maintenance-guide.md)、[运行态激活](runtime-target-activation.md)、[资格边界](qualification-boundaries.md)。
