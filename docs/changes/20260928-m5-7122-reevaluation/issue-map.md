# 重评链路问题地图

| ID | 级别 | 事实 | 处理 |
|---|---|---|---|
| M5-01 | resolved-local | 旧根仓固定 ADK 7.12.2 checkout 的 eval CLI 缺预算参数与新报告身份 | ADK 7.12.4 main `35b5fb31810c654a295c25b89e04435d6a32f57c` 已通过原子 promotion 导入根仓 exact gitlink/lock，预算参数和新报告身份均存在 |
| M5-02 | blocker | 真实 7.12.4 measured Codex smoke 与 root fresh integration 缺失 | 当前 main Sigstore promotion 已验证，但 M5 保持 blocked；不得使用 synthetic fixture 晋级 |
| M5-03 | major | rollover 曾用证据 `generated_at` 日期作最终状态投影日期，可能按历史日期评估新鲜性 | 已改为当前 UTC 日期，拒绝过期 review window 和回填 qualification time；时间负例通过 |
| M5-04 | major | M5 certifier 对 measured runtime 主要检查自述版本与 quality gate，缺强来源认证 | rollover 已要求原签名推广门禁在写入前通过；collector 锁定 clean source/任务合同。runtime 报告仍非独立签名证据，保留 owner/CI 资格线，不声称 cryptographic runtime attestation |
| M5-05 | blocker | rollover 曾只读取根仓 HEAD，未拒绝根仓 dirty 文件，资格记录可能与实际源码树不一致 | 已要求写入前根仓工作树及子仓状态 clean；模拟正例先冻结临时 fixture commit，dirty 负例验证无写入 |
| M5-06 | major | collector 曾允许请求 `gpt-5.5` 却观测到另一个模型，只要逐例与总列表内部一致即可通过 | 当前 M5 单模型 smoke 要求实际观测列表严格等于请求模型，错配负例拒绝写证据 |

只修改根仓隔离工作树中的本地合同与测试；不触碰用户 dirty、历史 M5 材料或 live runtime。
