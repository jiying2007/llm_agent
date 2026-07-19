# WeChat Metadata Intake

## Boundary

微信公众号研究与实践吸收分成两段：

1. `wechat-account-research` 在受限公共读取下生成 metadata-only `catalog.jsonl`，不保存正文。
2. `practice-intake --provider wechat` 将 catalog 归一为 `external-practice-candidate/v1`，仍保持 `review-required`。

任何阶段都不绕过登录、CAPTCHA、anti-spider、付费或安全验证，不使用代理池、身份/UA 轮换、Cookie 或自动验证码。

## Research Catalog

```bash
rtk bash ~/codex/scripts/wechat-archive.sh plan \
  --account '腾讯技术工程' \
  --date-from 2026-01-01 --date-to 2026-07-19 \
  --output-dir /tmp/wechat-research

rtk bash ~/codex/scripts/wechat-archive.sh collect \
  --plan-file /tmp/wechat-research/plan.json \
  --discovery-index /path/to/hermes/articles.json \
  --output-dir /tmp/wechat-research

rtk bash ~/codex/scripts/wechat-archive.sh check \
  --plan-file /tmp/wechat-research/plan.json \
  --output-dir /tmp/wechat-research
```

Catalog 每条至少包含 account/date/title/source URL/hash/verification/locator/body boundary；`body_persisted` 必须为 false。第三方 locator 保留 `untrusted-locator` 风险。

## Normalize into Practice Candidates

```bash
rtk scripts/practice-intake.sh collect \
  --provider wechat \
  --input /tmp/wechat-research/catalog.jsonl \
  --out /tmp/wechat-practice-candidates.jsonl \
  --evidence-out /tmp/wechat-practice-evidence.json

rtk scripts/practice-intake.sh check --kind candidate --input /tmp/wechat-practice-candidates.jsonl
```

WeChat candidate 使用 `copyright-restricted` 和 secondary-source 风险；不能因文章质量或账号身份自动生成 ADK decision。

## Absorption

独立 curator/owner 继续执行 duplicate、copyright、security、architecture 和 eval gate。批准后才创建 ADK change；优先增强现有 Agent/Skill/Workflow，不保留公众号专属平行资产。

详见 `docs/absorption-governance.md` 和 `docs/runbooks/external-practice-intake.md`。
