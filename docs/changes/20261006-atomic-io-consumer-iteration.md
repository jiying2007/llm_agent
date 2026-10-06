# 文件IO安全迭代与8.0.1 SDK消费候选

本轮内部/tmp实证发现4项输入/输出风险：Root intake/hash及runtime config叶节点check/open替换窗口，ADK安装plan/receipt固定临时名跟随预置链接。Root descriptor身份/预算/脱敏修复PR185已合并ab40301；ADK随机独占temp/fd写入fsync关闭后原子发布修复PR177已合并46c35605a400f422414bfae85e809143e527c37c。

Root读取包47/47定向、74/74完整、ADKquick56/56，独立fresh spec/quality PASS。ADK三个Python full各98/98+30/30路由及audit，独立16路径复审PASS；首lint失败修复并保留负结果，发布main checkout复验same snapshot/index的full receipt仍PASS。默认不调用真实模型，收益未量化。

真实mainCI37425994529九jobs成功，tag/release37426558324成功。immutable v8.0.1 tag979f928fa272064c14aa4f62b10931b66cb23493指向46c35605；treee9955c89b7e425b50f5a94507caaed53e4c7b71e，manifestblob9e6e83d06b7c3cb1ec379ed8756bcd5c0347bfab。实际归档c8de31339c864c947f34abdb356c93f6a318ae440cb94045533fdb767f0377be与API/evidence/contract一致，固定main workflow/issuer+reviewed trusted-root验签Verified OK，不重标旧签名。

本Root候选用已有工具完成六路径atomic promotion；SDK精确detached main，lock/interface/current-status/actual evidence+attestation同事务stage。该候选须新鲜完整Root/串行quick与whole-staged独立复审。报告与证据写source外阶段receipt，避免验证后source漂移。现有参考基线过期及历史M5/current不一致保持NEEDS_REVIEW，release_authorized=false，不伪owner/date/qualification。

独立~/codex从相同签名来源导入42Skill/9Agent/4policy，实际正文不变；来源pin/分发metadata/strict validators单独验收；真实SCM与source-to-live另验。Root codex gitlink是frozen-evidence-dependency，保留历史pin。保护用户10参考目录、CodeX5dirty+journal/live config及team-collab；未手改live。新ADK文档POSIX0600，目录并发/同权限writer/断电恢复边界明确。

外部依据：[Python tempfile](https://docs.python.org/3/library/tempfile.html)、[Python原子替换](https://docs.python.org/3/library/os.html#os.replace)、[SLSA验证期望](https://slsa.dev/spec/v1.2/verifying-artifacts)、[Anthropic分层评测](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)。仅设计证据，不进入runtime或证明产品资格。回滚保留Rootab40301及原ADK2c5bd35/8.0.0；回退安全修复会恢复已证实风险。
