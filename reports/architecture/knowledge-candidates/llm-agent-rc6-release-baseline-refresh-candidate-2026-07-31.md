# Knowledge Candidate：RC6 release baseline refresh

- status：review-required
- owner：leiwenjun
- scope：llm_agent / agent-dev-kit release validation
- source commit：`agent-dev-kit@9f82e1d9deffadc3967f446069375f5872363d46`
- evidence HEAD：`agent-dev-kit@cf082b602d68f3948ae1fcd6d00a522d116ddd0a`
- reusable conclusion：同一 prerelease 版本不能用于合法升级 rehearsal；RC5 后映射资产必须提升为 RC6，并以 exact-commit 双构建、checksum 和 RC5→RC6 rollback rehearsal 建立新 baseline。
- artifact SHA256：`4cd728126b7242150665315a22706811c12de4de9f136eaef17b0e3ecbe63b15`
- rehearsal：39 项原位升级，candidate rollback removed/restored=39，RC5 managed hashes 恢复。
- source-to-live：`required-pending-owner-authorization`；不得从 release evidence 自动推导 live apply 权限。
- exclusions：tag、remote release、remote CI/attestation、runtime campaign、field certification、memory write、active promotion。
