# LTA 原始证据字节身份：提交检查点

- [x] 固定并核对 Root 基线 f42395a37dced7e59867d0c46891ecd84c218585。
- [x] 原始字节计算使用 --no-filters。
- [x] 新增 autocrlf 与 clean-filter 行为回归，并通过 test_longitudinal_operation_certifier.sh。
- [ ] 完整回归、PR 当前 head CI 与合并后 fresh-main：由关联 GitHub Actions 的实际结果提供，不预填 PASS。

本地通过真实官方 rtk OSS 1.0.1 执行测试；Provider 位于 ~/codex 的入口在本环境缺失，记录为 unavailable。该情况与软件回归结果分开，不声明 Provider、Native、Owner 或现场资格。
