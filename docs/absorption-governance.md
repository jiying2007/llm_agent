# 子仓吸收治理规则（SSOT）

> 生效日期: 2026-05-12
> 触发原因: 长期增量更新导致臃肿、歧义、偏离、重复、冗余

---

## 核心原则

### 禁止：完全增量更新

**❌ 不允许的做法：**
- 简单追加新文件而不检查现有内容
- 直接合并上游变更而不评估影响
- "有新内容就加" 的无脑模式
- 跳过重复检查直接吸收
- 忽略与现有架构的冲突

**✓ 必须的做法：**
- 全盘评估吸收内容与现有资产的关系
- 检查重复、冲突、冗余
- 评估对整体架构的影响
- 考虑是否需要重构而非简单追加
- 每次吸收都必须有"为什么不用现有方案"的论证

### 临时参考素材

临时文章、网页摘录、手工导出的参考目录不等同于受治理子仓。它们只可作为背景输入：

- 不直接写入 `subrepos/adoption-matrix.md`，除非先提升为正式参考源。
- 不作为长期 knowledge 的唯一依据。
- 不保留来源专名到 core skill；应抽象成可复用规则、门禁或模板。
- 后续移除临时素材后，正式资产仍必须能独立通过验证。

### `wechat-articles/` 吸收专用规则

`wechat-articles/` 是文章归档池，吸收前必须先生成文章级账本：

```bash
rtk scripts/generate-wechat-intake-ledger.sh
rtk scripts/check-wechat-intake-ledger.sh .
```

固定产物：

- `reports/wechat-article-intake.jsonl`：每篇文章的唯一 intake 状态源。
- `reports/wechat-absorb-next-batch.md`：下一批 P0/P1 候选。
- `reports/wechat-absorb-batch.template.md`：每批吸收决策报告模板。
- `docs/runbooks/wechat-article-absorption.md`：文章吸收 runbook。

约束：

- 每篇文章必须先进入 ledger，再进入批次报告，不允许绕过账本直接改 adk 资产。
- 外部 GitHub / 源码 / 安装命令默认 `report-only-until-security-review`，不得自动新增子仓或执行安装。
- 已有等价能力时默认增强现有 skill/workflow/script，不新增平行资产。
- 纯资讯、重复教程、过期模型动态默认 `REFERENCE_ONLY` 或 `REJECT`。
- 每批吸收后至少运行 `rtk scripts/check-wechat-intake-ledger.sh .` 与 `rtk scripts/check-all.sh --quick`。

---

## 吸收前检查清单（必须全部通过）

### 1. 重复检查 (MUST)

```bash
# 检查是否有功能重复的现有资产
grep -r "功能描述关键词" agent-dev-kit/skills/ agent-dev-kit/optional-skills/
grep -r "功能描述关键词" agent-dev-kit/docs/

# 检查是否有名称相似的文件
find agent-dev-kit -name "*相似名称*"
```

**判定标准：**
- 如果已有功能相同/相似的 skill → 拒绝吸收，改为增强现有 skill
- 如果已有名称相似的文件 → 必须说明为什么不复用现有文件

### 2. 冲突检查 (MUST)

```bash
# 检查是否与现有流程冲突
grep -r "工作流步骤" agent-dev-kit/docs/workflows/
grep -r "触发词" agent-dev-kit/manifest.yaml

# 检查是否与现有规范冲突
diff 新内容 现有内容
```

**判定标准：**
- 如果与现有流程冲突 → 必须先解决冲突再吸收
- 如果触发词重复 → 必须重新设计触发词

### 3. 冗余检查 (MUST)

```bash
# 检查是否有可以合并的内容
grep -r "类似功能描述" agent-dev-kit/

# 检查是否有过时内容需要清理
find agent-dev-kit -name "*.backup" -o -name "*old*"
```

**判定标准：**
- 如果有可以合并的内容 → 必须合并后再吸收
- 如果有过时内容 → 必须先清理再吸收

### 4. 架构影响评估 (MUST)

**必须回答的问题：**
1. 这个内容是否符合 adk 的领域边界？（嵌入式系统，非前端/后端）
2. 这个内容是否与现有架构一致？
3. 这个内容是否需要修改现有目录结构？
4. 这个内容是否需要修改 manifest.yaml？
5. 这个内容是否需要更新 NAVIGATION.md？

**判定标准：**
- 如果不符合领域边界 → 拒绝吸收
- 如果需要修改架构 → 必须先出架构变更方案

### 5. 质量门禁 (MUST)

**必须满足：**
- 有完整的 SKILL.md/AGENTS.md 定义
- 有触发词和非触发词说明
- 有输入/输出/约束说明
- 有验证步骤
- 有示例或模板

**判定标准：**
- 如果质量不达标 → 必须先补充完善再吸收

---

## 吸收决策矩阵

| 情况 | 决策 | 理由 |
|------|------|------|
| 功能完全重复 | REJECT | 已有相同功能 |
| 功能部分重叠 | MERGE | 合并到现有资产 |
| 功能相似但实现不同 | EVALUATE | 评估哪个更好，保留最优 |
| 全新功能 | ADOPT | 但必须通过全部检查 |
| 质量不达标 | ENHANCE | 先完善再吸收 |
| 不符合领域边界 | REJECT | 超出 adk 范围 |

---

## 吸收流程（8 步闭环）

### Step 1: 深度分析 (MUST)

```bash
# 1.1 分析候选内容
bash scripts/analyze-repo.sh <repo_name>

# 1.2 生成分析报告
# 必须包含：功能定位、与现有资产关系、潜在冲突、质量评估
```

### Step 2: 全盘比对 (MUST)

```bash
# 2.1 检查重复
grep -r "关键词" agent-dev-kit/

# 2.2 检查冲突
grep -r "触发词" agent-dev-kit/manifest.yaml

# 2.3 检查冗余
find agent-dev-kit -name "*.md" | xargs grep -l "类似功能"
```

### Step 3: 决策论证 (MUST)

**必须输出：**
```markdown
## 吸收决策论证

### 候选内容
- 来源: <repo_name>
- 功能: <功能描述>

### 现有资产比对
- 相似资产: <list>
- 差异点: <list>
- 冲突点: <list>

### 决策
- 决策: ADOPT / MERGE / REJECT / ENHANCE
- 理由: <详细理由>

### 如果 ADOPT/MERGE
- 需要修改的文件: <list>
- 需要更新的文档: <list>
- 需要的测试: <list>
```

### Step 4: 架构评估 (MUST)

**必须回答：**
1. 是否需要修改目录结构？
2. 是否需要修改 manifest.yaml？
3. 是否需要更新 NAVIGATION.md？
4. 是否需要修改其他文档？

### Step 5: 质量补充 (IF NEEDED)

**如果质量不达标：**
1. 补充 SKILL.md/AGENTS.md 定义
2. 补充触发词说明
3. 补充输入/输出/约束
4. 补充验证步骤
5. 补充示例或模板

### Step 6: 执行吸收 (AFTER APPROVAL)

```bash
# 6.1 备份当前状态
bash scripts/backup-rollback.sh backup

# 6.2 执行吸收
bash scripts/auto-absorb.sh <repo_name> --apply

# 6.3 更新 adoption-matrix.md
# 记录决策、理由、证据
```

临时参考素材不执行 6.3；只有正式参考仓、明确采纳项或 delivery/observe 矩阵项才更新 `adoption-matrix.md`。

### Step 7: 验证 (MUST)

```bash
# 7.1 运行全量测试
bash agent-dev-kit/tests/run_all.sh

# 7.2 检查文档同步
bash scripts/check-doc-sync.sh .

# 7.3 检查 manifest 一致性
bash scripts/check-skill-metadata.sh .

# 7.4 检查路由冲突
bash scripts/check-skill-routing-conflicts.sh .
```

### Step 8: 记录 (MUST)

**必须更新：**
1. adoption-matrix.md - 记录决策和证据
2. CHANGELOG.md - 记录变更
3. NAVIGATION.md - 如果有新文档
4. 相关 runbook - 如果有流程变更

---

## 禁止的吸收模式

### ❌ 模式 1: 无脑追加

```bash
# 禁止：直接复制文件
cp source/file agent-dev-kit/skills/new-skill/

# 必须：先检查重复
grep -r "功能" agent-dev-kit/skills/
# 决定是新建还是增强现有
```

### ❌ 模式 2: 增量合并

```bash
# 禁止：直接 git merge
git merge upstream/main

# 必须：逐文件评估
git diff upstream/main
# 每个文件单独决策
```

### ❌ 模式 3: 跳过检查

```bash
# 禁止：跳过测试直接提交
git add -A && git commit

# 必须：先验证
bash agent-dev-kit/tests/run_all.sh
bash scripts/check-doc-sync.sh .
git add -A && git commit
```

### ❌ 模式 4: 忽略冲突

```bash
# 禁止：有冲突就接受
git merge --no-edit

# 必须：解决冲突后再合并
git merge
# 手动解决每个冲突
# 验证解决后的代码
```

---

## 吸收后审计

### 每次吸收后必须检查

```bash
# 1. 检查重复
bash scripts/check-skill-routing-conflicts.sh .

# 2. 检查冗余
bash scripts/check-doc-sync.sh .

# 3. 检查一致性
bash scripts/check-skill-metadata.sh .

# 4. 检查质量
bash agent-dev-kit/tests/run_all.sh
```

### 定期全盘审计

```bash
# 每月运行一次全面审计
bash scripts/check-all.sh --verbose
```

---

## 质量指标

### 吸收质量评分

| 指标 | 权重 | 达标标准 |
|------|------|----------|
| 无重复 | 30% | 0 个功能重复 |
| 无冲突 | 25% | 0 个触发词/流程冲突 |
| 无冗余 | 20% | 0 个可合并内容 |
| 架构一致 | 15% | 符合现有目录结构 |
| 质量达标 | 10% | 有完整文档和测试 |

### 吸收效果评估

**好的吸收：**
- 增强了现有能力，而非增加新负担
- 减少了重复，而非增加重复
- 简化了架构，而非复杂化
- 提高了质量，而非降低

**坏的吸收：**
- 增加了重复内容
- 引入了冲突
- 复杂了架构
- 降低了质量

---

## 附录：吸收决策模板

```markdown
# 吸收决策报告

## 候选内容
- 来源仓库: <repo_name>
- 候选内容: <content_name>
- 功能描述: <description>

## 全盘比对

### 重复检查
- [ ] 检查现有 skills/ 目录
- [ ] 检查现有 optional-skills/ 目录
- [ ] 检查现有 docs/ 目录
- 结果: <无重复 / 有重复: xxx>

### 冲突检查
- [ ] 检查触发词冲突
- [ ] 检查流程冲突
- [ ] 检查规范冲突
- 结果: <无冲突 / 有冲突: xxx>

### 冗余检查
- [ ] 检查可合并内容
- [ ] 检查过时内容
- 结果: <无冗余 / 有冗余: xxx>

### 架构影响评估
- [ ] 是否符合领域边界
- [ ] 是否与现有架构一致
- [ ] 是否需要修改目录结构
- [ ] 是否需要修改 manifest.yaml
- 结果: <无影响 / 需要修改: xxx>

### 质量评估
- [ ] 有完整 SKILL.md/AGENTS.md
- [ ] 有触发词说明
- [ ] 有输入/输出/约束
- [ ] 有验证步骤
- [ ] 有示例或模板
- 结果: <达标 / 不达标: xxx>

## 决策
- 决策: ADOPT / MERGE / REJECT / ENHANCE
- 理由: <详细理由>

## 执行计划
- [ ] 需要修改的文件: <list>
- [ ] 需要更新的文档: <list>
- [ ] 需要的测试: <list>
- [ ] 验证步骤: <list>

## 证据
- 分析报告: <path>
- 测试结果: <path>
- 审核记录: <path>
```

---

## 附录：常见错误和纠正

### 错误 1: "上游有新内容，我们应该吸收"

**纠正：** 上游有新内容不等于我们应该吸收。必须先问：
1. 我们是否已有相同/相似功能？
2. 这个内容是否符合我们的领域边界？
3. 这个内容的质量是否达标？
4. 吸收后是否会增加重复/冲突/冗余？

### 错误 2: "这个功能很有用，应该加上"

**纠正：** "有用" 不等于 "应该加上"。必须先问：
1. 我们是否已有类似功能？
2. 这个功能是否在我们的范围内？
3. 这个功能是否会导致架构复杂化？
4. 这个功能是否会导致维护负担增加？

### 错误 3: "先加上，以后再优化"

**纠正：** 这是导致臃肿的根本原因。必须：
1. 现在就评估影响
2. 现在就检查重复/冲突/冗余
3. 现在就决定是新建还是增强现有
4. 现在就确保质量达标

### 错误 4: "这是一个小改动，不需要全盘评估"

**纠正：** 小改动也可能导致大问题。必须：
1. 检查是否与现有内容冲突
2. 检查是否引入重复
3. 检查是否需要更新其他文档
4. 验证改动后的效果

---

*本规则基于 2026-05-12 双仓库审计的经验教训制定*
*审计发现 42 个问题，其中大部分源于无序的增量更新*
