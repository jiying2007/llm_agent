# 设计与边界

本设计落实 Owner 于本轮给定的三个维护修复，不扩展准入或资格语义。

## R1：薄包装参数适配

包装脚本从自身位置确定实现目录，默认也以它作为被检查 root。仅消费首个非选项位置参数；其余参数原样交给现有 `adk_interface --source-pin`。将实现目录加入子进程 `PYTHONPATH`，使任意 cwd 下都能调用实际控制面，保持相对被检查路径和证据路径相对于调用者 cwd 的语义。使用 `exec` 保留 Python 退出码、stdout 和 stderr，不复制 pin 或签名校验逻辑。

## R2：合成数据与真实检测

仅将新测试中的 retired command 字面量拆分为与同文件其他 fixture 一致的字符串拼接。生成文件的实际字节保持不变；仍由真实 ripgrep 和 scanner 执行正负验证。不给 tests 加豁免，不改变扫描策略。

## R3：调用方对齐生产解析器

两个 active caller 将 `--python all` 改为 `--python 3.12`。harden 成功日志和脚本文档同步当前支持版本，保留 `--mode full`、`--check-receipt`、真实 receipt 判定及现有 fallback。回归从实际 plan 输出和 harden 调用位置取得参数，交给 pinned ADK 的真实 `--dry-run`，并用 unsupported selector 作拒绝控制；不调用 Docker。

## 验证与回滚

先运行新增调用边界回归及真实 scanner 取得 RED，再做最小生产修改并重复同一验证取得 GREEN。最后只运行一次 `check-all --quick --working-tree`，预期两个既有入口失败消失，其余五项环境/资格失败仍如实报告；不以 quick 全绿作为本轮验收前提。

回滚只撤销本维护提交对应文件，保留 source-only 升级和原始证据。共享上下文下不执行自动回滚或提交。
