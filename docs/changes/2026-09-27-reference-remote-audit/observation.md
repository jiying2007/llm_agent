# 已批准参考 pin 的远端观察

2026-09-27 使用本地只读入口 `reference_remote_audit --allow-network` 观察 8 个已批准参考仓。输入 pin manifest SHA256 为 `0b12798f00db011d0a5a3fa919ee667ac960b8294435653bfd8af651947bca1c`，registry SHA256 为 `9ebb5e25882ccaea7d4852954924883e1bf0c8588154dbf23fa5ec3331d3cc6f`。结果 `review-required`：6 个 `different`、2 个 `same`、0 个 `unavailable`；该工具只比较 SHA，不声明可快进或采纳价值。

| ID | Pin | 观察到的远端 HEAD | 关系 |
|---|---|---|---|
| OpenSpec | `3c7a05c5dc88b2397c478805890b55ed392b19e8` | `79b6aa9c98f1e36795b2bc4ef2a8f770c6d3a777` | different |
| digital-worker | `4a94231d26df1aeaeba336e6a4e2327db5a3bd44` | `6160b33862a3b077fe8d2a21ab1a15416491cf0b` | different；独立试点仓 |
| mattpocock-skills | `ed37663cc5fbef691ddfecd080dff42f7e7e350d` | `c55ee46073ed923f86ce59a5eb3b6d895095d1b7` | different |
| oh-my-codex | `f947e3a41c062c25fd107686862b68ee5d1b66a5` | `cdc24a71408ebd6bd0362f52170f0d7998f77007` | different |
| planning-with-files | `d71b3be47b62fe49d60fb2ede800e1907ebea3d9` | `51c1caa27f9fefe259e45a7cc92fa79ee8787cd7` | different |
| superpowers | `6efe32c9e2dd002d0c394e861e0529675d1ab32e` | `8ca22dba9a94f28898bbce59f2537ff4d87c747d` | different |
| scale-engine | `ace49169c4191db656989b738f31edb19a380a63` | 同 pin | same |
| vibeflow | `0df764eff5e7b034611540da8d9f8367dfae55b2` | 同 pin | same |

本次未触及本地 dirty 参考 checkout，也未修改 `reference_pins.json`、registry、adoption matrix 或 runtime。新官方开源候选和方法吸收判断另在 ADK 本地 change review 中审查；根仓 pin 提升须保持独立决策与 exact source 核验。
