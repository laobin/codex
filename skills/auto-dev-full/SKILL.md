---
name: auto-dev-full
description: 高风险完整开发流程。适用于核心业务链路、状态机、幂等/防重、缓存/MQ/下游副作用、跨系统改动；以及 PRD 史诗级（多产物、多模块）需求。由 auto-dev 主入口在 mode=full 时进入，也可直接触发。
---

# 完整开发流程

## 目标

这个技能用于处理高风险需求，在理解业务规则、状态边界、副作用和验证标准后再实现。

- 核心链路是否会被影响
- 数据、状态和副作用是否一致
- 幂等、防重、并发和历史兼容是否可靠
- 验证证据是否足以支撑上线判断

full 表示风险更高、证据要求更高，不表示机械补齐所有文档。

## 适用场景

- 支付、退款、订单、权限等核心链路。
- 状态机、流程流转、幂等、防重。
- 缓存、MQ、定时任务、回调、下游副作用。
- 跨系统、跨服务或回滚困难的改动。
- 数据修复、迁移或兼容性要求较高的改动。
- **PRD 史诗级需求**：跨多个模块/领域/外部源，能识别出 ≥ 2 个独立可交付产物。

## 路径分流

进入本流程后，先判断是单产物路径还是 PRD 路径。

### 全新进入

无前置阶段直接进入 full 时，按下表判断：

| 判断 | 路径 |
|---|---|
| 单功能 / 单模块 / 单接口、能在单个 worktree 一周内闭环 | 单产物路径（feature 根 scope） |
| 跨多个模块/领域、能识别出 ≥ 2 个独立可交付产物 | PRD 路径（先 blueprint 拆产物，再逐产物循环） |

歧义时默认走 PRD 路径，由 blueprint 阶段再确认是否退回单产物路径。

### 升级接入

从 fast / standard 升级进入 full 时，**默认走单产物路径**，不强制 PRD：

- 已有 fast / standard 改动通常是单模块单职责，没必要事后拆产物。
- 升级要做的是补齐高风险所需的方案、评审、测试设计与证据，而不是重新切分。
- 续跑起点由 `progress.json.restart_from` 决定，先审计已有证据再决定补哪一步。

仅在升级过程中发现需求实际跨多产物（明显遗漏了其他模块的改动）时，才把升级路径切到 PRD：保留已有改动作为某一产物的"已完成实现"，重新跑 plan-blueprint 把整体范围补齐。

## 工作 scope

本流程涉及两层 scope：

- **feature 根**：`AI_DOC/features/<功能名>/`
- **产物层**（仅 PRD 路径）：`AI_DOC/features/<功能名>/deliverables/<n>-产物/`

每个阶段开始前显式确认当前 scope，并把 scope 路径作为参数传给下游技能。

## 单产物路径

在 feature 根 scope 下执行：

```text
context-scan
plan-write
plan-review
test-design-lite
code-implement
code-review
test-run-lite
```

这是高风险需求的常用路径。已有等价信息时可以复用；缺少理解、方案或验证证据时，读取对应单一技能补齐。

- `context-scan` 重点确认业务规则、状态边界、副作用、影响面和可复用模式。
- `plan-write` 重点写清解决方案、数据状态、异常路径、兼容性和回滚思路。
- `plan-review` 重点评审事故风险，不评文档漂亮程度。
- `test-design-lite` 重点覆盖主流程、关键异常、边界、状态一致性、幂等、防重、副作用和历史兼容。
- `code-implement` 只实现已理解且已确认的范围。
- `code-review` 和 `test-run-lite` 重点证明关键风险被控制。

## PRD 路径

PRD 路径在两层 scope 之间切换：

```text
[feature 根 scope] —— 设计阶段
  context-scan（可选前置，复杂背景时启用）
  plan-blueprint            → blueprint.md + deliverables/<n>-产物/README.md
  plan-review(target=blueprint) → blueprint-review.md

[产物层 scope] —— 逐产物循环（按依赖顺序）
  对每个产物 deliverables/<n>-产物/：
    plan-write              → 1-plan.md
    plan-review             → 2-plan-review.md
    test-design-lite        → 4-test-design-lite.md
    code-implement          → 改代码
    code-review             → 3-code-review.md
    test-run-lite           → 5-test-run-lite.md

[feature 根 scope] —— 集成验收阶段
  test-design-lite          → 4-test-design-lite.md（消费 blueprint.md 的"集成验收"章节）
  test-run-lite             → 5-test-run-lite.md（端到端用例验证）
```

PRD 路径关键规则：

- **blueprint 通过前不进入任何产物**：blueprint 评审不通过时，回到 plan-blueprint 修订，不允许在产物层私自打补丁。
- **依赖顺序硬约束**：产物按 blueprint 中声明的依赖顺序推进；契约型产物必须全部完成并通过评审，才能启动消费它们的下游产物。
- **可并行产物**：无相互依赖的产物可以并行推进（不同 worktree 或不同会话），但不绕过依赖。
- **全局约束消费**：每个产物的 plan-write 必须在方案开头声明消费的 blueprint 全局约束；不消费 = 评审 P0。
- **契约破坏式修改禁止**：契约型产物一旦被下游消费，只允许小幅扩展，不允许破坏式修改；需要破坏式修改时回到 plan-blueprint 重新评估。
- **产物级 code-review 通过后**才能进入下一个依赖该产物的产物。

### 集成验收阶段

所有产物的 `code-review` 和（如需要的）`test-run-lite` 都通过后，切回 feature 根 scope，执行集成验收：

1. **生成集成测试设计**：在 feature 根调用 `test-design-lite`，输入是 `blueprint.md` 的"集成验收"章节（产物 PRD 总目标对应的端到端用例），输出 `AI_DOC/features/<功能名>/4-test-design-lite.md`。
2. **执行集成测试**：在 feature 根调用 `test-run-lite`，输出 `AI_DOC/features/<功能名>/5-test-run-lite.md`。
3. **失败处理**：集成验收发现某个产物有问题时，按下表回退：

| 失败类型 | 处理 |
|---|---|
| 单一产物实现 bug | 切回该产物 scope，回 `code-implement` |
| 产物间契约或边界问题 | 切回 feature 根，回 `plan-blueprint` 修订 blueprint 与受影响产物 README |
| blueprint 集成用例本身设计错误 | 修订 `blueprint.md` 后重新生成集成测试设计 |

集成验收通过 = PRD 路径完成。

## 验证要求

full 流程不能只用"接口返回成功"作为通过依据。

涉及写入、状态、异步或外部副作用时，应尽量验证：

- 最终数据库状态。
- 状态流转是否合法。
- 重复请求、并发或重试结果。
- 缓存、MQ、任务、回调或下游系统结果。
- 历史数据和兼容场景。
- 日志和排障入口。

PRD 路径额外要求：

- 每个产物在产物层完成验证（产物级测试通过）。
- 所有产物完成后在 feature 根做集成验收（见上节），证明 blueprint 中声明的端到端用例可跑通。

环境无法验证关键风险时，记录阻塞点、缺失证据和建议验证路径，不把结论写成通过。

## 风险处理

回退时先判断问题类型与所在 scope：

- **方案问题（产物层 1-plan.md）**：在当前产物层回到 plan-write。
- **方案问题（blueprint 层面）**：回到 feature 根，重新跑 plan-blueprint。
- **实现问题**：在当前产物层回到 code-implement；测试发现的缺陷优先参考 `bug-fix`。
- **验证问题**：补证据；无法补证据时记录为未验证风险。
- **产物切分错误 / 契约缺失**：必须回 plan-blueprint，不允许在产物层补丁。

full 每类主要问题最多自动修复 2 轮。仍无法收敛时，转人工并说明失败路径、已查证据和需要用户决策的问题。

## 进度记录

`progress.json` 完整字段定义见 `skills/auto-dev/PROGRESS_SCHEMA.md`。本流程在 PRD 路径下重点维护以下字段：

- `is_prd`、`current_scope`、`current_deliverable`、`deliverables[]`、`blueprint_review_round`

### scope 切换时机

| 阶段进入 | 切换 |
|---|---|
| `plan-blueprint` / `plan-review(blueprint)` | `current_scope = feature_root` |
| 进入某产物的 `plan-write` | `current_scope = deliverable`、写入 `current_deliverable = <产物id>` |
| 当前产物完成（`completed`）且有下一 ready 产物 | 更新 `current_deliverable` 为下一个 |
| 所有产物完成，进入集成验收 | `current_scope = feature_root`、清空 `current_deliverable` |
| 集成验收回退到某产物 | `current_scope = deliverable`、`current_deliverable` 指向失败产物 |

每次切换都同时更新 `current_stage` 和 `stage_history`。

### deliverables[].status 转移

完整规则见 `PROGRESS_SCHEMA.md §2`。核心转移：

- `pending → running`：依赖产物全部 `completed`，进入本产物 `plan-write` 时。
- `running → completed`：本产物 `code-review` 通过且无需测试 / `test-run-lite` 通过。
- `running → blocked`：阻塞条件出现（写 `blocking_reason`）。
- `running → failed`：本产物 P0/P1 自动修复轮次用尽。
- `任意 → pending`：blueprint 修订导致本产物边界变更，由编排层重置。

### 回退与轮次计数

| 问题 | 受影响字段 |
|---|---|
| 当前产物方案问题 | `deliverables[n].plan_review_round +1`（每产物独立计数） |
| 当前产物实现问题 | `deliverables[n].code_review_round +1` |
| blueprint 层面问题 | `blueprint_review_round +1`，相关 deliverable 标 `pending` |
| 集成验收失败回到某产物 | 该 deliverable.status 回到 `running`，`test_fix_round +1` |

跳过某阶段时在 `stage_history[].note` 写明原因和替代证据。

## 输出

最后说明：

- 路径选择：单产物 / PRD。
- PRD 路径下：总产物数、契约型产物数、可并行产物数、依赖顺序。
- 本次控制的核心风险。
- 关键实现和影响面。
- 评审结论和测试证据。
- 集成验收结论（仅 PRD 路径）。
- 未验证项、剩余风险和是否建议人工复核。
