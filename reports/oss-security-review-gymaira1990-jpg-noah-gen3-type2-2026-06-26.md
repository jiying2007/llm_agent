# OSS Security Review: gymaira1990-jpg/noah-gen3-type2

> Status: report-only, blocked for execution
> Date: 2026-06-26
> Source: `scratch/oss-intake/noah-gen3-type2`

## Review Boundary

- Cloned for local read-only review.
- Did not install dependencies.
- Did not execute upstream Python, shell, server, browser, MCP, or model commands.
- Did not copy upstream source code or prose into ADK runtime assets.

## Findings

| Severity | Finding | Evidence |
|---|---|---|
| High | Historical runtime contains suspected hardcoded model API keys. | `04-原铸诺亚-二代一型/源码/context_engine.py`, `04-原铸诺亚-二代一型/源码/core/engine.py` |
| High | Historical runtime contains default admin password strings. | `04-原铸诺亚-二代一型/源码/auth.py`, `04-原铸诺亚-二代一型/源码/server.yaml`, `04-原铸诺亚-二代一型/源码/web/templates/admin_login.html` |
| Medium | Install guides include user-level environment writes and system-level link examples. | `06-诺亚核心-模型管理与对话面板/接入指南.md` |
| Medium | MCP and model-management surfaces would require transport, auth, deny-path, and logging review before any live use. | `02-Mnemosyne-记忆宫殿/MCP桥接/README.md`, `06-诺亚核心-模型管理与对话面板/README.md` |
| Medium | README claims MIT, but no top-level license file was found in the local clone. | `README.md`; no `LICENSE*` found by file listing. |

## Security Decision

Decision: `REJECT` for code import, `ARCHIVE_ONLY` for conceptual reference.

Any future use must start with a clean-room implementation or fixture design, not with copying or executing upstream runtime code.
