# 独立表达历史审核完成范围：设计

## 决策

1. 保留当前源码审核字段为 false；另以 historical_review_verified 表达原作用范围已经满足。
2. 完整三份历史包真实复验成功后清空重复历史待办，并从 current required scope 排除已完成历史项。
3. 缺失/篡改/原版校验失败继续 scan error；其他 G21/G22/LTA/M5 条件保持。

## 影响入口

- `tools/control_plane/qualification_followup.py`
- `tests/test_qualification_followup.py`
- `docs/runbooks/qualification-followup.md`

## 迁移与回滚

保持现有公共入口和权限边界；实现与回归一起审查、一起回退。已有历史证据不重写。源码与普通本地/公开 CI 验证不生成 native、field、effect 或产品资格。

## 验证与审核边界

复用现有定向测试与受保护 CI；独立 Spec/Quality 审核仍需真实独立执行。本轮不新增 Codex/Work 或代理委派，不把实现者自检登记为独立审核。
