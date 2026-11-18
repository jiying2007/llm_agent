# 设计

将检查清单发现改为执行前的显式、可感知退出码的步骤。Smoke 必选文件缺失即返回错误，空清单一律报错；原来的 `while ... < <(discover_check_scripts)` 不能传递发现过程退出码，改为预检后从已确认清单执行。

这是根因修复而非新增门禁层。实际覆盖由 `tests/test_check_all_contract.sh` 和原 Root CI 验证。
