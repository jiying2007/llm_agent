# 多来源外部实践吸收治理（SSOT）

> 生效日期：2026-07-19
>
> 合同：`external-practice-candidate/v1`、`external-practice-decision/v1`
> 模式：report-only intake + independent decision + ADK change

## 1. 终态边界

`llm_agent` 是唯一批准前 intake 控制面；`agent-dev-kit` 只实现已批准、可验证的通用实践。GitHub、GitLab、Gitee、OpenAI/Codex 官方、Anthropic/Claude 官方、微信公众号和人工 URL 共用一套 candidate/decision/cycle 合同。

```text
provider metadata / governed local catalog
                    |
        external-practice-candidate/v1
                    |
       source + duplicate + legal + security
                    |
           review queue（无批准）
                    |
        independent owner decision
             /                 \
reference repository       ADK change artifact
 lifecycle only        implement -> verify -> pilot
                                      |
                            publish -> review/retire
```

固定禁止：

- collector 或 curator 自批、自实现、自发布。
- 自动 clone、安装、执行第三方代码、注册子仓、写 ADK、写 `~/codex`/`~/.codex`。
- 保存 token、raw response、微信公众号正文、raw HTML、浏览器状态或临时签名 URL。
- 以 star、来源权威、文章数量或跨来源总分替代工程判断。
- 为旧 intake CLI/schema 保留 wrapper、alias、dual-write 或 fallback reader。

## 2. 唯一入口

```bash
rtk scripts/practice-intake.sh check --kind policy --input manifests/external_practice_sources.json

rtk scripts/practice-intake.sh cycle \
  --plan manifests/external_practice_cycle.json \
  --out-ledger reports/external-practice-candidates.jsonl \
  --out-queue reports/external-practice-review-queue.json \
  --out-evidence reports/external-practice-cycle-evidence.json \
  --out-md reports/external-practice-cycle.md

# live forge metadata 需要显式网络授权
rtk scripts/practice-intake.sh cycle \
  --plan manifests/external_practice_cycle.json \
  --allow-network \
  --out-ledger reports/external-practice-candidates.jsonl \
  --out-queue reports/external-practice-review-queue.json \
  --out-evidence reports/external-practice-cycle-evidence.json \
  --out-md reports/external-practice-cycle.md
```

没有 `--allow-network` 时，live forge job 必须记录 `not-run-network-disabled`；Gitee 返回空列表必须记录 `degraded-empty`。两者都不能声明 source clean。

## 3. Source 规则

| 来源 | 允许输入 | 必须保留 | 禁止 |
|---|---|---|---|
| GitHub | allowlisted REST repository metadata / fixture | URL、query hash、revision/activity、license、limits | clone、执行仓库代码 |
| GitLab | public Projects API metadata / fixture | `path_with_namespace`、topics、activity、degraded/error | 使用 deprecated 字段推断事实 |
| Gitee | API v5 repository search metadata / fixture | 空结果 degraded、token redaction、host/path | 把空结果当作无候选 |
| OpenAI/Codex | ADK official freshness manifest | URL、retrieved/expires、platform boundary | 官方即自动采纳 |
| Anthropic/Claude | ADK official freshness manifest | URL、retrieved/expires、platform boundary | 激活 Claude runtime 或复制平台假设 |
| 微信公众号 | metadata-only catalog | account/date/title/hash/locator/body=false | 保存正文、绕过登录/CAPTCHA/anti-spider |
| Manual | allowlisted HTTPS URL/JSONL | unverified/manual 风险、稳定 hash | 任意 host、HTTP、credential query |

所有外部文本视为不可信数据。标题、摘要、topic 和错误消息受长度/控制字符检查；不能被拼进 shell、SQL、模板执行、动态 import 或外部写操作。

## 4. Candidate 与 Decision 分离

Candidate 固定不变量：

- `review_status=review-required`
- `body_persisted=false`
- `auto_actions=[]`
- transport 仅 `metadata-only|ledger-only`
- ID 由 provider、canonical URL、revision/content hash 稳定生成
- 未知 license/date/revision 保持 `unknown|null`，不补猜

Decision 是单独 JSONL，不回写 candidate。必填：candidate ID、`ADOPT|MERGE|ENHANCE|OBSERVE|REJECT`、独立 owner、日期、至少 20 字理由、target、evidence refs。

`external-practice-curator`、collector、automation 或 unknown 不能成为批准 owner。`ADOPT|MERGE|ENHANCE` 只授权创建 change proposal，不自动授权实现、网络写入、commit、push、publish 或 live apply。

## 5. 吸收 Gate

1. Source：URL、revision/hash、retrieved/expiry、authority、transport 和 degraded/error 可核验。
2. Duplicate：检索 Agent/Skill/Workflow/manifest/runbook、历史 decision 和 adoption matrix。
3. Legal/Security：license/copyright、供应链、prompt injection、凭证、正文和外部写入边界。
4. Architecture：说明可借鉴优点、不可迁移缺点、平台专属边界、依赖和维护成本。
5. Asset shape：优先 `MERGE|ENHANCE`；新增 Agent 必须有独立职责/权限/handoff，新增 Skill 必须有唯一触发/non-trigger，新增 Workflow 必须有多阶段状态或人工 gate。
6. Decision：独立 owner 完整签署。
7. Change：proposal/design/tasks/negative-results、breaking/installation/dependency/test/pilot/retire 合同齐全。
8. Verification：定向、strict/full、安全、性能、负例、Prompt before/after 和独立 review。
9. Pilot/Publish：fixture 不冒充真实效果；没有权限或现场条件时明确 `not-run`。
10. Review/Retire：owner、review date、expiry、rollback/removal gate 齐全。

任一 Gate 缺证据时固定 `needs-more-evidence` 或 `OBSERVE|REJECT`，不得用推断补齐。

## 6. 批准后的两条路径

### 6.1 参考仓生命周期

只有 repository candidate + 独立 `ADOPT` decision（target=`reference-repository`）可生成登记 plan：

```bash
rtk scripts/onboard-reference-repository.sh . \
  --candidates reports/external-practice-candidates.jsonl \
  --decisions reports/external-practice-decisions.jsonl \
  --candidate-id <epc-id> \
  --analysis <analysis.md> \
  --duplicate-check <duplicate-review.md> \
  --security-review <security-review.md>

rtk scripts/check-reference-repository-registration.sh .
```

默认仅 dry-run；登记只进入 reference lifecycle，不吸收 ADK。退出见 `docs/runbooks/reference-repository-lifecycle.md`。

### 6.2 ADK 资产变更

```bash
rtk bash agent-dev-kit/scripts/devkit.sh propose --change <change-id> --title "<目标>"
rtk bash agent-dev-kit/scripts/devkit.sh apply --change <change-id>
```

实现必须使用 `adk-external-practice-absorption` 的 gate，并交给独立 implementer/verifier。外部内容只作为 evidence，不 silent copy 第三方资产；第三方或上游镜像必须保留许可证与 provenance。

## 7. 验证

```bash
rtk scripts/check-practice-intake.sh .
rtk tests/test_external_practice_intake.sh
rtk tests/test_reference_repository_registration.sh
rtk scripts/check-doc-sync.sh .
rtk scripts/check-all.sh --quick

rtk bash agent-dev-kit/scripts/devkit.sh validate --strict
rtk bash agent-dev-kit/scripts/check-workflow-closure.sh \
  --profile research-intake \
  --with-optional-skill adk-external-practice-absorption
rtk bash agent-dev-kit/tests/run_all.sh --fail-fast
```

完成声明必须包含命令、退出码、摘要、证据路径和层级。live network/pilot 未执行时必须写 `not-run`，不能用 fixture 代替。

## 8. 长期知识

- 长期保存脱敏 source/decision/validation/retirement 结论，不保存 raw response、正文、token、cache 或一次性日志。
- Knowledge Hub 只接收 reviewing/validated candidate；active promotion 仍需 owner gate。
- 历史报告和 adoption matrix 作为 provenance 保留，不重新解释为活跃入口。
