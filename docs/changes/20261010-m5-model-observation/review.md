# 模型观测修复独立复审

本轮复用独立 review agent，对 observer、collector、共享 runtime consumer 和负例执行只读复审。审查没有模型调用、外部网络或代码写入。

最终增量结论为 Spec PASS、Quality PASS；独立定向 52/52 通过，并将 ResourceWarning 设为 error。观察器源码 SHA256 为 `8ad5a8c27af9a9cd4e8facaa55b0740bf9188ba03adbfd980137e396857cabf3`。

已关闭的发现：

- 总 deadline 与子进程/连接退出原本不完整；现采用 threaded server、有界 socket、主动取消、stdin select、有限标准流与子进程释放。包含无 EOF stdin、半发送请求取消、stdout 超预算负例。
- 工具 delta 与非有限浮点数缺少拒绝；现拒绝工具事件/输出、失败响应、重复字段和溢出浮点数。
- 新增失败诊断可跟随链接覆盖既有文件，已确认 major；现模型执行前预检路径，实际写入逐级 dir_fd NOFOLLOW、叶子 O_EXCL/NOFOLLOW、0600。负例证明拒绝发生在执行前，既有内容保持不变。
- 发送计数语义不准；现称 prepared_requests，真实 HTTP 状态与阶段另列。
- 直接调用参数可能改写 provider；现仅允许 pinned evaluator 的 read-only 参数形状，拒绝额外配置与输出逃逸。

初轮将纯函数构造 SSE response.headers 的正例判断为 TLS 来源绕过，后经核真撤销。生产路径仅从固定 TLS 上游读取 HTTP 或原始 SSE 服务端响应元数据；模型生成文本和 response.model 都不能建立模型身份。scope/header_sources 已明确区分 HTTP/SSE，解决原表述歧义。

上述 PASS 限本轮实现与定向质量。真实调用没有产生有效模型身份回执，当前候选 runtime、同基线受信 CI、field/owner 完整资格和产品放行都不能据此通过。
