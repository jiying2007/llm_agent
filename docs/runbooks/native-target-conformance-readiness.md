# Native target conformance readiness

当前软件链分三层，必须分别记证据，不能互相继承：

1. **Source layout evidence**：ADK 7.2.0 的 `target-source-probe` 在隔离临时目录验证 export inventory、文件 digest 和文本入口可读性。该层固定 `native_runtime_evidence=false`。
2. **Managed trust software**：ADK 7.3.0 的 `native_conformance_trust_registry.json` 与 production loader 提供受管 verifier 注入。registry 默认没有 authority，因此不会自动启用任何 runtime target。
3. **Native campaign evidence**：必须在版本固定的真实 runtime 上独立完成 discovery/load/trigger，并生成 typed receipt、签名 bundle 与 owner-reviewed authority binding。只有该层完成后，才允许另开 target contract runtime promotion 变更。

Root 当前只消费前两层的软件能力，不创建 native receipt，不修改用户 live HOME，也不改变产品 release authority。

## 当前核验命令

```bash
rtk python -m pip install ./agent-dev-kit
rtk bash tests/test_adk_context_observability_consumer.sh
rtk bash tests/test_adk_native_trust_consumer.sh
rtk bash agent-dev-kit/scripts/devkit.sh target check --all --level static --summary-json
```

预期：所有 direct target 仍为 `static / not-certified / not-run`；managed trust registry 为 active 但 authorities 为空。

## 真实 campaign 的开始条件

开始真实 native campaign 前必须同时冻结：

- Root 与 ADK exact SHA、target contract digest、bundle digest；
- runtime binary digest 与 exact version pin；
- discovery/load/trigger 三个独立命令；
- authority ID、target scope、signature/provenance backend；
- 隐私约束：不保存 prompt、message、credential、raw tool payload；
- 预算和停止条件。

缺认证、缺 verifier binary、缺签名、identity/scope/digest 不匹配、任一 stage 失败时都保持 BLOCKED / static；不得退化为“source probe 已过所以 native 已验证”。

历史上 Claude 的隔离 discovery 曾因认证不可用而停止，这类结果应作为负证据保留；只有新的、版本绑定的完整 campaign 才能改变 native conformance 状态。
