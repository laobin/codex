---
name: auto-dev-standard
description: 标准业务开发流程。适用于日常功能迭代、单模块改动、有数据写入但风险可控的中等复杂度需求。由 auto-dev 主入口在 mode=standard 时进入，也可直接触发。
---

# 标准开发流程

## 目标

这个技能用于完成风险可控的日常业务开发。

- 先理解需求目标、边界和成功标准
- 判断是否需要方案、评审、测试设计或测试执行证据
- 完成小范围、可维护、可验证的代码改动
- 发现高风险时及时升级到 full

standard 是日常默认流程，不要求机械跑完所有阶段。已有文档只是辅助理解；缺文档不等于必须补文档。

## 工作重点

开始任何阶段前，先用一两句话确认本次改动范围与边界，写入 `progress.json.scope`，作为后续阶段选择和验证的硬约束。

参考路径：

```text
context-scan
plan-write
plan-review
test-design-lite
code-implement
code-review
test-run-lite
```

这是可选阶段清单，不是固定闭环。按当前需求风险选择必要动作：

- 需求目标、影响面或现有实现不清时，读取 `context-scan`。
- 解决方案、边界、数据状态或副作用处理不清时，读取 `plan-write`。
- 方案涉及数据写入、权限、副作用或较大影响面时，读取 `plan-review`。
- 验收标准或关键测试场景不清时，读取 `test-design-lite`。
- 实现代码时读取 `code-implement`；缺陷场景按需参考 `bug-fix`。
- 改动完成后，按风险读取 `code-review` 和 `test-run-lite`。

如果需求和方案已经足够清楚，可以跳过不必要的文档阶段，但最终要能说明实现依据和验证证据。

## 风险处理

出现以下情况时，升级到 `full`：

- 状态机、幂等、防重或一致性要求明显。
- 涉及缓存、MQ、定时任务、外部系统或下游副作用。
- 改动范围明显超出单模块或初始判断。
- P0/P1 问题在 standard 轮次内无法收敛。

回退时先判断问题类型：

- 需求或方案问题：回到 `plan-write`，或在问题明确时直接修方案。
- 实现问题：回到 `code-implement`；测试发现的缺陷优先参考 `bug-fix`。
- 环境不可验证：记录缺失证据，不声称通过。

standard 每类主要问题通常只给 1 轮自动修复机会。超过后，风险明确且 full 能处理时升级；否则转人工。

升级前完成 `progress.json` 更新（`current_status="upgraded"`、`upgraded_from="standard"`、`mode="full"`、`recommended_next_action="auto-dev-full"`），并在 `stage_history[].note` 写明建议起点和原代码状态。由主 agent 接力调用 `auto-dev-full`；full 流程先审计已有证据再决定从哪个必要动作接上。

## progress.json

按 `auto-dev` 主入口规范维护状态。

常用阶段：

- `context-scan`
- `plan-write`
- `plan-review`
- `test-design`
- `code-implement`
- `code-review`
- `test-run`
- `done`

跳过某阶段时，在 `stage_history` 里简短记录原因，例如“需求和实现边界已由现有代码确认，跳过方案文档”。

## 输出

最后说明：

- 本次采用的关键阶段和跳过原因。
- 改动范围和实现要点。
- 评审或测试结论。
- 未验证项、剩余风险和建议下一步。
