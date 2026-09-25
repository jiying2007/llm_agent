# Campaign readiness projection design

The projection reads `adk.lock`, current status projection inputs and, when initialized, the pinned `agent-dev-kit` worktree. It does not write reports or mutate manifests.

Effect software readiness is file/identity based: repeated-trial schemas, implementation and runbook must exist in the exact locked ADK source. The projection intentionally does not ingest raw real-task evidence.

Native software readiness is similarly file/identity based, then reads the managed native trust registry and direct target contracts. Enabled authorities and runtime-certified targets are observations only; promotion still belongs to the target-contract/native-receipt authority.

Top-level `status=pass` means the projection was computed. `software_status` and `evidence_closure_status` carry readiness semantics. Product release authorization is copied from the existing status projection and is explicitly independent.

The only CI gate is `--gate software`. This avoids turning absent external model/runtime evidence into a source-development blocker while preventing silent regression of the software foundations needed to collect that evidence.
