# 真实资格缺项处理

当前 M5 policy/v3 的硬门槛为至少一个measured runtime、一个独立真实仓、一位真人及pilot_started事件；minimum_calendar_days=0。30天观察与第二操作者属于运营建议，不添加为首次M5硬门槛。旧资格版本为5.0.0-rc.2，当前候选8.0.5，历史记录保持原样。

已定位 rollover 将模型固定为gpt-5.5，而collector允许显式--model并验证请求/观察模型一致。本修复增加--expected-model，默认仍gpt-5.5；选择当前模型时必须显式提供，外层与nested结果仍精确一致，身份、时效、quality gate及内容摘要继续校验。它不确认模型revision或产生真实测量，不能代替G22不可变模型要求。

rollover JSON读取复用Root intake的有界regular严格读取，拒绝链接、FIFO、重复键及非有限数。新增测试均为临时synthetic输入，不生成真实runtime/field/owner证据，不更新policy、scorecard、qualification。

诊断中的promotion_signature默认blocked是保守默认；需要接入固定身份的实际验签结果，不能删除该门禁。G21的两个direct target当前均static、trust未启用、native evidence为空；G22真实测量与owner决策缺项独立处理，仍待运行授权和可信输入。

failed_scope：当前模型被历史硬编码拒绝及JSON入口边界；preserved_passing_scope：旧模型默认、候选identity、quality/时效/hash和历史记录；minimal_rerun：新模型/JSON负例及现有rollover回归；rollback_anchor：普通源码revert；修复未宣称任何产品资格成立。

后续补齐了公开finalize入口：保留runtime输入的lexical路径，避免先resolve后丢失链接拒绝条件。17项M5定向测试通过，其中包括旧模型默认、显式模型选择、错误/嵌套模型拒绝、strict JSON、链接/FIFO以及公开入口拒绝。

diagnostics新增显式--verify-promotion，要求cosign实体文件、trusted-root及两者SHA256 pin；固定canonical生产workflow certificate identity/issuer，实际执行verify-blob并核对前后输入摘要。默认诊断仍不启动外部进程。2026-10-09已用已有cosign3.1.3与trusted root实际通过8.0.5签名，promotion_signature PASS；整体仍blocked（runtime、qualification、historical_declaration），model_invocations=0，历史未改。

现有仓库measured smoke属于5.0.0-rc.2，已知临时raw报告属于旧manifest；G22索引entry_count=0，G21两个target为static、trust未启用、无native回执。旧实测、安装检查与synthetic target-check不重标为当前真实资格。

负结果保留：首轮full在stale-references处遇到系统rg无PCRE2；第二轮保留整个宿主PATH后native-campaign fixture失败（error空），同环境定向复验也失败。精简PATH下该fixture定向PASS，不能据此宣称已确定宿主PATH失败的精确根因。后续验证使用精简PATH与单独的既有PCRE2 rg入口，不修改生产native执行器或降低语义断言。

验签首试因verifier入口为symlink而被拒绝；改用实体文件后发现二进制超过JSON读取预算，改用同一regular检查的流式SHA256核验，再实际验签通过。没有放宽签名、摘要或链接门禁。
