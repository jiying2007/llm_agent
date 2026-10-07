# 2026-10-07 证据读取与交付入口迭代

目标：内部审查与外部一手资料核验后，对可复现证据边界问题实施修复。保持用户参考目录、Codex 本地有效修改与真实模型禁用，不更改历史 M5/owner/有效期资格。

ADK 从已核验 8.0.2 开始，source candidate 8.0.3。目标契约、晋级证据和发布归档的 JSON 统一拒绝重复键/非有限值/超限输入。真实 target 入口保留原始叶节点路径，native 回执 hash 与解析来自同一次有界 descriptor 读取，晋级公开输出沿用排序字节与 0644，使用共享原子写入。

llm_agent 的跨仓证据包 `plan_receipt` 原使用普通 JSON，重复 content_changes 采用末值，非对象导致 AttributeError；修复为现有 intake_io 有界严格读取，原始字节同时生成 hash/bytes/字段。明确拒绝非对象与错误 nested receipt 类型，输出复用事务 writer，拒绝输出链接。仍是 provenance-only / release_authorized=false，不提升产品资格。测试只使用隔离临时目录，不访问实际 Hub 内部目录。

Design-change/replan：审查发现该工具默认直接读取 ~/knowledge-hub Git 状态，与当前 Provider-only 跨仓边界冲突。接口前移 schema_version=2 / projection=adk-cross-repo-release-bundle-v2，repository 列表仅 llm-agent/ADK/Codex；删除 --hub-root 和 --hub-candidate，调用者迁移为 --knowledge-candidate <本地脱敏候选>，字段迁移 hub_candidate→knowledge_candidate。新增 knowledge_boundary 固定 provider_persisted=false / archive_claim=not-established / provider_readback_required=true；不提供历史别名或私有路径 fallback。候选 hash 不代表归档，持久化另走 Provider Adapter 并核 actual readback。旧消费者回滚须整体回滚 CLI+projection+fixture，禁止把旧Hub直读作为运行回退。

外部依据：https://docs.python.org/3/library/json.html 对不可信 JSON 的 CPU/内存风险、重复键及非有限数值说明；POSIX open 规范对 FIFO/NONBLOCK 的说明。MCP 官方安全指南纳入搜索，但没有引入新 MCP transport、功能或权限。

审查与验证：ADK 14 项定向通过；初次独立复审发现两个 Major，修复后 working-tree source spec/quality PASS，最终 staged source snapshot cf7fff2ba40cdf2546b7ffe6047e61bebb553b5b536d98461f60945ff7d7362a / index663b92bc9a12cd16a1f6a2bdf2d7c26896136abde9b49ae47c5c3a77cabd2fd2。完整三 Python 矩阵运行中；根仓定向 9 项及迁移后隔离跨仓 bundle 行为通过。Provider接口前移已有fresh独立PASS，随后保留0600兼容性改动需整批复审。后续以实际终态更新，不使用旧 receipt/签名声明本轮通过。

权限兼容：原bundle NamedTemporaryFile默认私有0600；共享intake writer原默认0644。writer新增keyword-only mode并验证，所有旧调用保持0644默认，bundle显式0600。权限在临时文件发布前设置；测试验证bundle私有、共享默认、非法mode不产生输出。共享工具的其它行为不修改。

验证环境负结果：一次Root full使用重新列举的系统PATH，丢失既有PCRE2 ripgrep，于stale-reference尾段返回scanner exit2；不计整轮PASS。恢复原PATH并仅前置已验证Python3.11/cosign，再单独复跑stale-reference及完整Root suite；无需修改源码或放宽检查。
恢复后的Root最终full实际74/74通过，stale-reference包含在整轮通过结果中；receipt /tmp/llm-803-final-root-full-pcre2-20261007.json SHA1d8e7b807ee75fcafbe3f2fefbc946844c70c3e52d72e02fc8243c9753520573。quick按full后串行执行，尚待实际终态；完整源码测试不等于workspace/domain/M5通过。
首次quick不作为最终证据：只读沙箱阻止Sigstore TUF/Python编译缓存，且更新本报告时改变进行中快照，导致额外runtime/同snapshot检查失败。冻结报告/index后以具备必要缓存权限的相同只读检查重跑；不修改managed源码、live资产、历史M5或参考baseline。
冻结quick实际49/52，snapshot stability PASS，actual验签与global Codex/runtime健康PASS；receipt /tmp/llm-803-frozen-final-quick-20261007.json SHA1c1da7f66c619645bd7fab7ed886fa3b9cac5aee11a645503e640ec18a598521，workspace fingerprint613aee16257951b7a5b83832965f8205b89dc24b5a68ec7bbb36e33749606528。三个失败check为reference-dirty-triage、subrepo-state（两者同属既有过期reference baseline，含可观察的缺失observe项），software-m5-readiness（历史source/current source mismatch）。本轮未修改其脚本、registry或baseline，不刷新owner/date/资格。与上轮50/52区别据实际终态报告，不复制旧计数。

负结果：根 full 首次未采用既有 Python3.11 环境而被环境门禁阻断；用 /tmp/llm_agent_py311_venv/bin 重新执行后，消费版本门禁因 current candidate8.0.3 与已发布 lock8.0.2 不一致而正确阻断。须正式新签名源形成后再更新消费契约。根初次复审发现新 writer 可移动目录（Major）及新 parent 不再创建（Minor），已在调用入口拒绝 existing 非regular/链接并安全创建新 parent；目录/FIFO inode和内容保持测试、新 parent 和输入重叠保护测试通过。

实际ADK交付：PR179已合并main3df8f7b821d1194fbe0cc44e013416857d6b64a5，tree00587cbcbe3fa51f6af7f2542cadaebed315ca6e，manifest blob4b5a641cfbff43dcdc59000140fb81fe26499002。main CI37580322786九job成功；发行37580751586成功，v8.0.3 immutable且非draft/prerelease，annotated tagb68385b0e60f5cf31af979c440f96d5c8d6c213e指向同main。实际archive86f1f591d9c8f528d2586cd47417edcfb2aa3ffb118e51893c3d53588d1e1ede同时匹配API digest、签名evidence和contract；contract10713ed331e887c8ceba7247aeebe1297eb03e24e71d5513ce69b0d3043dfa56与Main artifact逐字节相同。固定cosign3.1.3和已审核trusted-root验签Verified OK。

ADK最终staged三Python各98/98 full、30/30routing及wheel/lint/types/strict/dependency audit全部通过，exact source/index check-receipt通过；receipt84c5de4f0b474df6345cb44a175b6b961e784a6df9f8918ad07b6d86f629489a。根source锁/interface/SDK及实际promotion evidence8af7a3c5a5cd353126a87a39cbf4a8b62a3ac99855988fb6d28c9a19bd39f224 / attestation70fcedb595d7a8488afaf0c4162507e4073fa42878676b57158daedbf0fa50b7一致，portable consumer verifier PASS。生成current-status仍为historical / release_authorized=false；初次未暂存gitlink时投影/接口检查失败，不计PASS，统一index后通过。

阶段验收：ADK源码/正式发行已完成；Root源码74/74及整批staged复审通过，workspace/product资格保留上述阻塞。Root SCM需exact head远端检查终态后合并，实际回执单独读回，不在源码报告预填未来commit/merge。Skill/Agent及运行policy正文无本轮改动，独立Codex不导入/build/apply，live仍保留已声明的8.0.2来源身份，不冒称8.0.3运行升级。retry_budget=2，验证共享工作树串行；每阶段核验当前 source 与 test receipt。归档成员总量/整包解压资源控制、各解释器数字预算、实际模型收益是候选，不声明已关闭。
