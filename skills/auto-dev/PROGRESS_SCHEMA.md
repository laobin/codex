> 日期：2026-05-22

# progress.json 全量字段规范

本文档是各编排技能（`auto-dev` / `auto-dev-fast` / `auto-dev-standard` / `auto-dev-full` / `auto-dev-batch`）共享的 `progress.json` 单一权威定义。各技能描述只引用本文档，不重复写字段。

## 文件位置

- 单需求模式：`AI_DOC/features/<功能名>/progress.json`
- 批处理模式：`AI_DOC/batch/<批次名>/batch-progress.json`（结构见 §4）

## 1. 基础字段（所有模式通用）

```json
{
  "feature_name": "<功能名>",
  "mode": "fast | standard | full",
  "created_at": "<ISO时间>",
  "updated_at": "<ISO时间>",
  "current_stage": "routing | context-scan | plan-blueprint | plan-write | plan-review | test-design | code-implement | code-review | test-run | done",
  "last_success_stage": null,
  "scope": null,
  "plan_review_round": 0,
  "code_review_round": 0,
  "test_fix_round": 0,
  "current_status": "running | pending_fix | manual_required | completed | upgraded | blocked",
  "upgraded_from": null,
  "restart_from": null,
  "recommended_next_action": "continue-current-flow",
  "reason": "",
  "needs_user_decision": false,
  "blocking_issues": [],
  "stage_history": []
}
```

| 字段 | 说明 |
|---|---|
| `feature_name` | 功能名（kebab-case） |
| `mode` | 当前流程线 |
| `current_stage` | 当前状态或正在处理的阶段；初始 `routing`，进入具体技能后写阶段名 |
| `last_success_stage` | 最后一个已完成阶段 |
| `scope` | 当前确认的需求范围（一句话） |
| `plan_review_round` | 方案类问题回退轮次 |
| `code_review_round` | 代码评审发现实现问题的轮次 |
| `test_fix_round` | 测试阶段发现实现问题后的修复轮次 |
| `current_status` | 见下方枚举 |
| `upgraded_from` | 发生升级时记录原流程线 |
| `restart_from` | 升级或续跑时建议重新开始的阶段 |
| `recommended_next_action` | 下一步建议动作（见下方枚举） |
| `reason` | 建议动作的原因 |
| `needs_user_decision` | 是否需要用户决策 |
| `blocking_issues` | 未解决问题列表 |
| `stage_history` | 阶段记录数组 |

### current_status 枚举

| 值 | 含义 |
|---|---|
| `running` | 流程正在推进 |
| `pending_fix` | 等待修复后再继续 |
| `manual_required` | 自动流程无法收敛，需人工介入 |
| `completed` | 流程完成 |
| `upgraded` | 已升级到更高流程线，控制权交接中 |
| `blocked` | 当前被阻塞，等待外部条件 |

### recommended_next_action 枚举

| 值 | 含义 |
|---|---|
| `continue-current-flow` | 在当前流程继续 |
| `auto-dev-standard` | 升级到 standard |
| `auto-dev-full` | 升级到 full |
| `plan-blueprint` | 回到 PRD 整体设计（产物切分/契约问题） |
| `plan-write` | 回到方案撰写 |
| `code-implement` | 回到实现 |
| `test-run-lite` | 进入测试执行 |
| `bug-fix` | 走缺陷修复路径 |
| `fix-blocker` | 修阻塞项 |
| `merge-check` | 合并检查 |
| `manual-review` | 转人工评审 |
| `test-request-mail` | 生成提测邮件 |
| `none` | 流程已结束 |

### stage_history 元素结构

```json
{
  "stage": "<阶段名>",
  "status": "started | success | blocked | failed | skipped",
  "time": "<ISO时间>",
  "note": "<简短说明，长任务/续跑时记录 handoff：当前目标、已改文件、未决问题、建议下一步>"
}
```

### 状态更新时机

- 阶段开始
- 阶段完成
- 出现阻塞、失败或升级
- 问题修复后
- 流程完成

## 2. PRD 扩展字段（mode=full 且 is_prd=true 时）

```json
{
  "is_prd": true,
  "current_scope": "feature_root | deliverable",
  "current_deliverable": "01-xxx",
  "blueprint_review_round": 0,
  "deliverables_total": 6,
  "deliverables": [
    {
      "id": "01",
      "name": "<产物名>",
      "depends_on": [],
      "type": "contract | business | tool",
      "status": "pending | running | blocked | completed | failed",
      "scope_dir": "AI_DOC/features/<功能名>/deliverables/01-xxx/",
      "plan_review_round": 0,
      "code_review_round": 0,
      "test_fix_round": 0,
      "blocking_reason": null,
      "started_at": null,
      "completed_at": null
    }
  ]
}
```

### deliverables[].status 转移规则

| 当前 | 触发条件 | 目标 |
|---|---|---|
| `pending` | 依赖产物全部 `completed`，进入本产物 `plan-write` | `running` |
| `running` | 本产物 `code-review` 通过且测试不需要 / `test-run-lite` 通过 | `completed` |
| `running` | 阻塞条件出现（缺信息、环境不可用、外部依赖等） | `blocked`（写 `blocking_reason`） |
| `running` | 本流程 P0/P1 自动修复轮次用尽 | `failed` |
| `blocked` | 阻塞解除 | `running` |
| 任意 | blueprint 修订导致产物边界变更或被移除 | 由 `auto-dev-full` 重置为 `pending` 或标记 `failed` |

### current_scope 切换规则

| 触发 | 切换 |
|---|---|
| 进入产物 plan-write | `feature_root → deliverable`（更新 `current_deliverable`） |
| 当前产物 `completed` 且仍有下一个 ready 产物 | `deliverable(n) → deliverable(m)` |
| 所有产物 `completed`，进入集成验收 | `deliverable → feature_root` |
| 产物边界/契约问题需修 blueprint | `deliverable → feature_root`（并把受影响 deliverable 标 `pending`） |

### 回退规则

| 问题来源 | 处理 | 受影响字段 |
|---|---|---|
| 当前产物方案问题 | 留在当前 scope，回 `plan-write` | `deliverables[n].plan_review_round +1` |
| 当前产物实现问题 | 留在当前 scope，回 `code-implement` | `deliverables[n].code_review_round +1` |
| 产物边界/契约问题 | 切回 feature_root，回 `plan-blueprint` | 相关 deliverable 标 `pending`，`blueprint_review_round +1` |
| 集成验收失败 | feature_root scope 下定位失败产物，重新进入该产物循环 | 对应 `deliverables[n].status` 回到 `running` |

## 3. fast/standard 阶段约定

- fast 常用阶段：`code-implement` / `code-review` / `test-run` / `done`，`plan_review_round` 通常保持 0
- standard 常用阶段：`context-scan` / `plan-write` / `plan-review` / `test-design` / `code-implement` / `code-review` / `test-run` / `done`
- 跳过某阶段时在 `stage_history` 简短记录原因

## 4. 批处理扩展（batch-progress.json）

```json
{
  "batch_name": "<批次名>",
  "mode": "batch",
  "created_at": "<ISO时间>",
  "updated_at": "<ISO时间>",
  "current_status": "running | completed | blocked",
  "base_branch": "<开始分支>",
  "base_commit": "<开始commit>",
  "batch_branch": "feature/batch-<批次名>",
  "recommended_next_action": "continue-current-flow",
  "reason": "",
  "needs_user_decision": false,
  "items": [
    {
      "id": "R1",
      "feature_name": "<功能名>",
      "mode": "fast | standard | full",
      "status": "pending | running | completed | blocked | failed",
      "verification_level": "V0 | V1 | V2 | V3",
      "failure_type": null,
      "recommended_next_action": "continue-current-flow",
      "reason": null,
      "needs_user_decision": false,
      "branch": "feature/<功能名>",
      "changed_files": [],
      "feature_doc_dir": "AI_DOC/features/<功能名>/",
      "blocking_reason": null,
      "decision_notes": [],
      "verification_result": null,
      "merge_status": "not_merged | merged_to_batch | left_on_feature_branch"
    }
  ]
}
```

### verification_level 枚举

| 等级 | 含义 |
|---|---|
| `V1` | 可自动跑测试、接口或脚本验证 |
| `V2` | 可通过编译、静态检查或局部命令验证 |
| `V3` | 只能给人工验收路径 |
| `V0` | 关键风险不可验证 |

### failure_type 枚举

| 类型 | 含义 |
|---|---|
| `requirement_unclear` | 需求无法安全判断 |
| `verification_failed` | 验证执行后失败 |
| `verification_unavailable` | 环境或条件导致关键验证不可执行 |
| `ci_or_build_failed` | 构建、测试或检查命令失败 |
| `scope_expanded` | 正确做法明显超出授权范围 |
| `conflict_or_dirty_worktree` | 分支、合并或工作区状态阻塞 |
| `implementation_risk` | 实现存在事故风险，不建议继续自动推进 |

## 5. 一致性约束

- `progress.json` 始终落在 feature 根，不在产物层重复创建。
- PRD 模式下产物层进度通过 `deliverables[].status` 表达，不在产物子目录另开 progress 文件。
- 字段缺省值：未启动的阶段轮次保持 0；未发生的事件字段保持 `null`。
- 时间字段统一使用 ISO 8601（如 `2026-05-22T10:30:00+08:00`）。
- 任何编排技能要新增字段，先更新本文档再使用。
