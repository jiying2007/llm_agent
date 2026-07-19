# External Practice Intake Runbook

## Purpose

统一收集 GitHub、GitLab、Gitee、OpenAI/Codex 官方、Anthropic/Claude 官方、微信公众号和人工证据，只生成 `review-required` candidate、queue 与 cycle evidence。该流程不做批准、clone、执行、注册、吸收或发布。

## Contracts

- Source policy：`manifests/external_practice_sources.json`
- Cycle plan：`manifests/external_practice_cycle.json`
- Candidate schema：`schemas/external-practice-candidate.schema.json`
- Decision schema：`schemas/external-practice-decision.schema.json`
- Cycle schemas：`schemas/external-practice-cycle-*.schema.json`
- CLI：`scripts/practice-intake.sh`

## Provider Collect

Forge fixture/offline contract：

```bash
rtk scripts/practice-intake.sh collect \
  --provider gitee --query 'AI Agent Skill Workflow' \
  --fixture fixtures/external-practice/providers/gitee.json \
  --as-of 2026-07-19 \
  --out /tmp/gitee-candidates.jsonl \
  --evidence-out /tmp/gitee-evidence.json
```

Forge live metadata（需要显式网络授权）：

```bash
rtk scripts/practice-intake.sh collect \
  --provider github --query 'agent coding workflow skill harness' \
  --allow-network \
  --out reports/github-practice-candidates.jsonl \
  --evidence-out reports/github-practice-evidence.json
```

GitLab、Gitee 仅替换 `--provider`；token 只从 policy 指定 env 读取，不写 evidence。Gitee 空列表返回成功但 evidence 为 `degraded-empty`，queue 增加 provider-health 项。

官方来源：

```bash
rtk scripts/practice-intake.sh collect \
  --provider openai-official \
  --input agent-dev-kit/manifests/official_docs_freshness_gates.json \
  --out /tmp/openai-candidates.jsonl \
  --evidence-out /tmp/openai-evidence.json

rtk scripts/practice-intake.sh collect \
  --provider anthropic-official \
  --input agent-dev-kit/manifests/official_docs_freshness_gates.json \
  --out /tmp/anthropic-candidates.jsonl \
  --evidence-out /tmp/anthropic-evidence.json
```

微信公众号与人工输入：

```bash
rtk scripts/practice-intake.sh collect \
  --provider wechat \
  --input reports/wechat-account-research-2026-07-16/catalog.jsonl \
  --out /tmp/wechat-candidates.jsonl \
  --evidence-out /tmp/wechat-evidence.json

rtk scripts/practice-intake.sh collect \
  --provider manual \
  --url https://gitee.com/example/agent-pattern \
  --out /tmp/manual-candidates.jsonl \
  --evidence-out /tmp/manual-evidence.json
```

## Cycle

```bash
rtk scripts/practice-intake.sh cycle \
  --plan manifests/external_practice_cycle.json \
  --out-ledger reports/external-practice-candidates.jsonl \
  --out-queue reports/external-practice-review-queue.json \
  --out-evidence reports/external-practice-cycle-evidence.json \
  --out-md reports/external-practice-cycle.md
```

不带 `--allow-network` 时 live forge job 记录 `not-run-network-disabled`，本地 official/WeChat job 继续执行；cycle 结论是 degraded，不得写成 complete。计划中的 `allow_degraded` 只控制退出码，不改变证据状态。

## Validate and Recommend

```bash
rtk scripts/practice-intake.sh check --kind policy --input manifests/external_practice_sources.json
rtk scripts/practice-intake.sh check --kind plan --input manifests/external_practice_cycle.json
rtk scripts/practice-intake.sh check --kind candidate --input reports/external-practice-candidates.jsonl
rtk scripts/practice-intake.sh check --kind evidence --input reports/external-practice-cycle-evidence.json

rtk scripts/practice-intake.sh recommend \
  --ledger reports/external-practice-candidates.jsonl \
  --out-json reports/external-practice-recommendations.json \
  --out-md reports/external-practice-recommendations.md
```

recommend 只给 `agent|skill|workflow|script|manifest|runbook|observe` 形态提示，不生成资产或批准。

## Independent Decision

Decision JSONL 示例：

```json
{"schema_version":"external-practice-decision/v1","candidate_id":"epc-...","decision":"ENHANCE","owner":"governance-owner","reviewed_at":"2026-07-19","rationale":"至少二十字的独立复核理由和不可迁移边界。","target":"agent-dev-kit/workflows/existing","evidence_refs":["reports/curator-review.md"]}
```

```bash
rtk scripts/practice-intake.sh check --kind decision --input reports/external-practice-decisions.jsonl
```

Collector、`external-practice-curator` 或 automation 不能作为批准 owner。Decision 与 candidate 分离，不能将 `review_status` 改成 approved。

## Failure Matrix

| 现象 | 状态/动作 |
|---|---|
| Gitee 空列表 | `degraded-empty`，继续人工复核 source health |
| 网络未授权 | `not-run-network-disabled`，不是错误也不是 complete |
| HTTP/redirect/未知 host | fail closed，非零 |
| token、正文、auto action | fail closed，禁止写输出 |
| source 过期/license unknown | candidate risk flag，进入 review |
| response >4 MiB/job >100/cycle >500 | fail closed |
| 旧 OSS candidate/score schema | 直接拒绝，不迁移、不兼容 |

## Verification

```bash
rtk scripts/check-practice-intake.sh .
rtk tests/test_external_practice_intake.sh
rtk tests/test_reference_repository_registration.sh
```
