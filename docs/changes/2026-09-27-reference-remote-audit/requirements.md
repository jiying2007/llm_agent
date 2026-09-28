# 参考仓远端漂移只读审计

## 目标与边界

从 `manifests/reference_pins.json` 与 `subrepos/registry.csv` 读取已批准来源，默认离线；显式 `--allow-network` 后只用 `git ls-remote` 观察远端分支 HEAD，并区分 `same`、`different`、`unavailable`。不得 fetch、pull、clone、checkout、运行第三方代码、改 pin 或推断 ADK/runtime 已采用。

## 风险与停止条件

- URL 必须为已批准 pin 的无凭据 HTTPS，远端 host 限 GitHub、GitLab、Gitee；所有进程用参数数组和超时，禁止 shell 拼接。
- 仅 SHA 不证明祖先关系；`different` 不可表述成可安全快进。空结果、认证失败或超时必须标 `unavailable`。
- 当前用户工作区的参考目录有既有 dirty，工具不得访问或修改这些目录。
- 网络调用需要显式 `--allow-network`；省略时报告 `not-run-network-disabled`，不把旧 tracking ref 当成实时远端。

## 验收

离线无远端调用；联网相同/变化/空结果/失败均有确定性输出和退出码；输出绑定 pin/registry SHA256；测试不触网、仓库状态不漂移；与既有 `reference_pins` 可信校验复用，不建立第二份 pin。
