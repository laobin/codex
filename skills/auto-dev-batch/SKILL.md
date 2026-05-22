---
name: auto-dev-batch
description: 批量无人值守自动开发流程。适用于用户一次给出多个需求，并明确希望 Codex 批量、全自动或无人值守推进的场景；负责拆分需求、排序、分流、记录阻塞项和批处理结果。
---

# 批量无人值守开发流程

## 目标

这个技能用于在用户明确授权批量或无人值守执行时，拆分需求、判断风险、逐项推进能安全处理的任务，并记录完成项、阻塞项和失败项。

- 每个需求目标是否清楚
- 需求之间是否互相影响
- 每个需求适合 fast、standard 还是 full
- 哪些需求可以自动推进
- 哪些需求需要 blocked 等用户决策

批处理不是把所有需求硬跑完。能安全做的继续做，不能安全决定的记录清楚后跳过当前需求。

## 工作边界

开始前先确认用户已经授权批量或无人值守代码修改。没有授权时，只能整理计划和说明需要确认的边界。

遇到破坏性操作、生产数据、密钥、真实外部支付、不可逆副作用，停止批处理并说明原因。

单个需求出现业务规则缺失、权限口径不清、金额 / 状态含义不明、外部系统行为无法判断时，不中断整个批次；按全局 unattended 规则记录 blocked，然后继续下一个需求。

## 工作重点

### 1. 拆分和排序

先把用户输入拆成相对独立的需求，并生成：

```text
AI_DOC/batch/<批次名>/batch-plan.md
```

文件可以包含：

- 需求列表和简短目标。
- 每个需求的初步流程线：fast / standard / full。
- 验证等级初判。
- 执行顺序和排序理由。
- 可能冲突的模块、文件、表、配置或接口。
- 无人值守授权边界。

初步分流不是最终结论。单个需求执行时，根据代码、项目文档和真实风险校正。

### 2. 分支和工作区

涉及提交、分支或 commit 信息时，先读取 `~/.claude/specs/git.md`。

批处理应记录开始分支、工作区状态和基线 commit。条件允许时，每个需求使用独立分支或 worktree；条件不允许时，也要避免在同一个脏工作区连续混做多个需求。

每个需求结束时记录：

- 当前分支和起止 commit。
- 变更文件。
- 是否已合入批次分支。
- blocked / failed 时是否留下未完成改动。

默认不 push。

### 3. 单需求执行

每个需求先确认目标和风险，再选择：

| 情况 | 执行技能 |
|------|----------|
| 范围清楚、低风险、小改动 | `auto-dev-fast` |
| 日常业务功能、风险可控 | `auto-dev-standard` |
| 状态、一致性、副作用、跨系统、高风险 | `auto-dev-full` |

缺陷修复、报错处理或回归问题仍按影响面分流；进入单需求后按需参考 `bug-fix`。

执行子流程时传入 `unattended=true`，具体阻塞处理遵守全局 `AGENTS.md` 的共用规则。

### 3.1 单需求升级处理

子流程把单需求 `progress.json` 标为 `current_status="upgraded"` 时，按下列规则接管，不等待用户：

- 读取子需求 `progress.json` 的 `mode`、`restart_from`、`recommended_next_action` 和 `stage_history` 末尾 note。
- 把 `items[].mode` 更新为目标流程线，保持 `items[].status="running"`，不计 failure；同一 `feature_name` 和分支沿用，不开新功能目录。
- 调用对应目标流程（`auto-dev-standard` / `auto-dev-full`），传入 `unattended=true`；目标流程先审计已有证据，再从 `restart_from` 接上，避免重跑已通过阶段。

`items[].recommended_next_action` 的可选值除原有项外，还包括 `auto-dev-standard`、`auto-dev-full`，用于覆盖升级接管场景。

### 4. 无人值守决策

遇到信息缺口时，先查代码、项目文档、`AI_DOC/global`、已有 feature 文档、配置、测试和历史实现。

能从现有实现推断时，选择项目已有模式中改动最小、兼容性最好、验证路径最清楚的方案。

不能安全决定时，不强行实现。记录：

- 缺什么信息。
- 已查过哪些证据。
- 为什么不能自动判断。
- 需要用户回答什么。

### 5. 异常恢复

执行异常先判断类型，不盲目重试。

可以有限恢复：

- 本地服务未启动：按项目文档或 runbook 尝试启动。
- 命令超时或卡住：检查日志、进程和资源后最多重试一次。
- 端口占用：若是本批次启动的进程，可以停止后重试；否则改端口或记录阻塞。
- 依赖服务不可用：先查本地配置和项目启动说明。
- 构建失败：区分环境问题、依赖问题、测试失败和代码错误。

不要停止非本项目进程，不改生产配置，不清空数据库，不执行破坏性数据操作。

恢复动作和结果写入 `batch-progress.json`，必要时写入 `batch-result.md`。

### 6. 验证等级

| 等级 | 含义 |
|------|------|
| `V1` | 可自动跑测试、接口或脚本验证 |
| `V2` | 可通过编译、静态检查或局部命令验证 |
| `V3` | 只能给人工验收路径 |
| `V0` | 关键风险不可验证 |

缺少详细证据时，不把结果写成自动验证通过。

### 7. 失败类型

| 类型 | 含义 |
|------|------|
| `requirement_unclear` | 需求无法安全判断 |
| `verification_failed` | 验证执行后失败 |
| `verification_unavailable` | 环境或条件导致关键验证不可执行 |
| `ci_or_build_failed` | 构建、测试或检查命令失败 |
| `scope_expanded` | 正确做法明显超出授权范围 |
| `conflict_or_dirty_worktree` | 分支、合并或工作区状态阻塞 |
| `implementation_risk` | 实现存在事故风险，不建议继续自动推进 |

### 8. 状态记录

维护：`AI_DOC/batch/<批次名>/batch-progress.json`

**完整字段定义、`verification_level`、`failure_type`、`recommended_next_action` 等枚举见 `skills/auto-dev/PROGRESS_SCHEMA.md §4`**。本流程在该 schema 基础上：

- 批次层维护 `batch_name`、`base_branch`、`base_commit`、`batch_branch`、`current_status`、`recommended_next_action`、`reason`、`needs_user_decision`。
- `items[]` 每条对应一个子需求，按 schema §4 字段填写。
- 每完成、阻塞或失败一个需求，立即更新对应 `items[n]`。
- 子需求 `items[n].mode` 升级时（升级接管场景），更新 `mode` 字段但不重新计入 failure。

## 输出

批处理目录：

```text
AI_DOC/batch/<批次名>/
  batch-plan.md
  batch-progress.json
  batch-result.md
```

每个需求仍按需写入：

```text
AI_DOC/features/<功能名>/
```

`batch-result.md` 可以包含：

- 总体结论：完成、阻塞、失败、未执行数量。
- 每个需求状态、验证等级、失败类型、分支、文档目录、变更文件和验证结论。
- 自动决策记录：问题、查证依据、最终选择、为什么。
- 阻塞需求：阻塞点、无法自动决定的原因、需要用户回答的问题。
- 分支与合并状态。
- 风险和建议人工检查点。

## 完成后建议

只提示用户从 `batch-result.md` 开始检查；不要自动 push。需要继续时，由用户选择修复阻塞项、补测、提交或进入下一批。
