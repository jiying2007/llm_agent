# 最小终态设计

原结构不用重写：保留历史清单与固定 SHA，添加明确 retired-historical lifecycle；仅撤销 LTA-02 活跃资格承诺、readme/runbook 误导描述，以及消费链结果中可能混淆历史检查与当前 R2 资格的输出。

不改 Software M5 append-only ledger、现场事件或历史验证器的判断逻辑，不将旧 LTA-04 现场数据当成新 pilot，也不调整当前 Product M5 release_authorized=false。原本验证历史证据的测试继续保留，增补 active_runtime_qualification=false、LTA-02 不再等待未来 receipt 等断言。
