---
name: auto-dev
description: 自动化开发统一入口。用于用户要求自动开发、auto-dev、全流程开发，或需要根据需求风险自动选择 fast、standard、full、batch 流程时触发。
---

# 自动化开发主入口

## 目标

这个技能用于理解需求目标、判断风险等级，并选择合适的自动化开发路径。

- 用户真正要解决什么问题
- 需求是否可以安全自动推进
- 应该走 fast、standard、full 还是 batch
- 是否需要先澄清、升级或阻塞
- `AI_DOC` 和 `progress.json` 应该记录什么证据

自动化开发不是机械跑完所有阶段。文档和状态文件用于辅助理解、续跑、评审和排障，不是为了补齐流程闭环。

## 工作重点

### 1. 先判断需求和风险

没有指定 mode 时，默认按 `auto` 处理，由主 agent 判断流程线。

| mode | 用途 |
|------|------|
| `fast` | 低风险小改动，小 bug、文案、展示字段、简单交互 |
| `standard` | 日常业务开发，单模块或单接口改动，风险可控 |
| `full` | 核心链路、状态机、幂等、防重、缓存、MQ、跨系统、副作用 |
| `batch` | 多个需求，或用户明确要求批量、全自动、无人值守 |

判断有歧义时，优先选择更稳妥的流程线。执行中发现真实风险高于初判时可以升级；不要为了省阶段而压低风险。

缺陷修复不是独立 mode。用户要求修 bug、报错处理或回归问题时，仍按影响面选择 fast / standard / full / batch，执行时按需参考 `bug-fix`。

### 2. 首次响应说明分流

在进行实质代码修改前，先简短说明：

```text
功能名：<功能名>
分支名：feature/<功能名>
文档目录：AI_DOC/features/<功能名>/
流程线：fast / standard / full / batch
选择理由：<1-2 句话>
```

选择 `batch` 时，说明批次名、批次目录、需求数量和选择理由。

如果用户已经明确要求自动执行，且需求和风险判断清楚，可以说明分流后继续推进。需求目标不清、业务规则冲突或没有可靠方案时，先暂停；无人值守时按全局规则记录 blocked。

### 3. 维护 progress.json

`progress.json` 用于记录状态、续跑、阻塞和建议动作。没有必要时不要让它主导实现方式；但进入自动化流程后，应保持状态可恢复。

文件路径：

```text
AI_DOC/features/<功能名>/progress.json
```

文件可以包含：

```json
{
  "feature_name": "<功能名>",
  "mode": "fast|standard|full",
  "created_at": "<ISO时间>",
  "updated_at": "<ISO时间>",
  "current_stage": "routing",
  "last_success_stage": null,
  "scope": null,
  "plan_review_round": 0,
  "code_review_round": 0,
  "test_fix_round": 0,
  "current_status": "running",
  "upgraded_from": null,
  "restart_from": null,
  "recommended_next_action": "continue-current-flow",
  "reason": "已完成分流，准备进入对应流程线",
  "needs_user_decision": false,
  "blocking_issues": [],
  "stage_history": []
}
```

`routing` 只表示主入口已完成分流，不是需要执行的阶段。

关键字段约定：

| 字段 | 说明 |
|------|------|
| `current_stage` | 当前状态或正在处理的阶段；初始为 `routing`，进入具体技能后再写阶段名 |
| `last_success_stage` | 最后一个已完成阶段 |
| `scope` | 当前确认的需求范围 |
| `current_status` | `running` / `pending_fix` / `manual_required` / `completed` / `upgraded` |
| `upgraded_from` | 发生升级时记录原流程线 |
| `restart_from` | 升级或续跑时建议重新开始的阶段 |
| `recommended_next_action` | 下一步建议动作 |
| `reason` | 建议动作的原因 |
| `needs_user_decision` | 是否需要用户决策 |
| `blocking_issues` | 未解决问题 |
| `stage_history` | 阶段记录 |

`stage_history[]` 至少记录阶段、状态、时间和简短说明。状态可用：`started` / `success` / `blocked` / `failed` / `skipped`。

长任务、批处理或上下文可能中断时，把轻量 handoff 写入 `stage_history[].note`：当前目标、已改文件、未决问题和建议下一步。

状态更新时机：

- 阶段开始。
- 阶段完成。
- 出现阻塞、失败或升级。
- 问题修复后。
- 流程完成。

### 4. 选择并执行对应流程

| 流程线 | 读取技能 |
|--------|----------|
| fast | `auto-dev-fast` |
| standard | `auto-dev-standard` |
| full | `auto-dev-full` |
| batch | `auto-dev-batch` |

把需求描述、功能名、文档目录、progress 路径和是否无人值守传给对应流程即可。具体阶段由对应流程按风险决定，不要求补齐所有文档。

### 5. 最小完成定义

自动化流程完成时至少满足：

- 需求目标已实现，或已明确记录无法实现的原因。
- 改动范围可解释，没有不必要的修改。
- 至少有一种验证证据，或明确记录不可验证原因。
- 没有未处理的 P0/P1 风险。
- `progress.json` 的最终状态、建议动作和原因可读。

### 6. 回退和升级

每次回退只处理一个主要问题，避免计数混乱。

| 问题来源 | 常见处理 |
|----------|----------|
| 方案问题 | 回到 `plan-write`，或在问题明确时直接修方案 |
| 实现问题 | 回到 `code-implement`，缺陷场景优先参考 `bug-fix` |
| 验证失败 | 先判断是方案问题、实现问题还是环境问题 |

计数器含义：

- `plan_review_round`：方案类问题回退轮次。
- `code_review_round`：代码评审发现实现问题的轮次。
- `test_fix_round`：测试阶段发现实现问题后的修复轮次。

升级原则：

- fast 发现数据写入、影响面扩大或方案问题时，升级到 standard。
- fast / standard 发现状态机、幂等、副作用、跨系统或高风险一致性问题时，升级到 full。
- full 超过可自动收敛范围时，转人工。

升级时记录升级原因、原流程线、新流程线、建议续跑阶段和原代码是否可复用。

控制权交接：当前 agent 完成 `progress.json` 更新（`current_status="upgraded"`、`mode`、`recommended_next_action`、`restart_from`、`stage_history[].note`）后立即停止原流程。同会话已加载目标流程技能时直接执行；否则向上层输出明确提示「已升级到 auto-dev-<目标流程>，请调用继续；建议起点 <restart_from>」。无人值守模式下由批处理调度器按 `recommended_next_action` 自动接力，不等待用户确认。

## 完成后建议

主入口只负责分流、状态和总控。最终结果由 fast / standard / full / batch 流程输出。
