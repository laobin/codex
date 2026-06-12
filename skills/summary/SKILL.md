---
name: summary
description: 生成功能开发总结文档，优先使用 codex-cli MCP，结果写入 6-summary.md。当用户说"生成总结"、"写总结"时触发。
version: 2.1.0
---

# 开发总结生成

## 设计原则

- **主线程驱动**：主线程负责上下文准备和路径传递，由 codex-cli 完成实际总结撰写工作
- **codex 作为 AI 代理**：codex-cli 是独立的 AI 代理，自行读取所有产物文件、获取模型配置，直接写入总结，主线程只传路径
- **完全透明**：总结文档记录 codex 使用的工具和精确模型版本

## 执行步骤

### 第一步：确认上下文

1. 执行 `git rev-parse --show-toplevel 2>/dev/null || pwd` 获取项目根目录，记为 `<ROOT>`
2. 确认功能名称（未指定时从当前分支名去掉 `feature/` 前缀推断）

### 第二步：调用 codex-cli MCP 生成总结并直接写文件

调用 `mcp__codex-cli__codex`：
- `sandbox`: `"workspace-write"`
- `cwd`: `<ROOT>`
- `prompt`：

```
你是开发流程总结撰写者，请完成以下任务：
0. 执行 cat ~/.codex/config.toml | grep "^model" 获取当前模型版本，记为 <CODEX_MODEL>，写入总结文档
1. 读取以下产物文件（相对于当前工作目录，文件不存在则跳过，对应章节注明"本阶段未执行"）：
   - AI_DOC/features/<功能名>/1-plan.md
   - AI_DOC/features/<功能名>/2-plan-review.md
   - AI_DOC/features/<功能名>/3-code-review.md
   - AI_DOC/features/<功能名>/4-test-design-lite.md
   - AI_DOC/features/<功能名>/5-test-run-lite.md
2. 基于读取内容，生成开发总结
3. 将总结直接写入：AI_DOC/features/<功能名>/6-summary.md（覆盖写入）

【输出格式】
> 日期：YYYY-MM-DD
> 生成工具：codex-cli MCP（<CODEX_MODEL>）

# <功能名> 开发总结

## 1. 功能概述
一句话说清楚本次开发了什么，解决了什么问题。

## 2. 最终落地结果
实际实现了哪些内容，与原始需求对比是否有偏差。

## 3. 方案关键调整（如有）
方案在评审中做了哪些调整，调整原因。

## 4. 代码关键修复（如有）
代码评审中发现并修复了哪些问题。

## 5. 测试结论
关键测试场景的通过情况，是否有待确认项。

## 6. 已知限制
当前实现的已知限制或遗留问题。

（可选）## 7. 可复用经验
本次值得沉淀的模式或经验。

【撰写要求】
- 语言简洁，面向开发者阅读
- 每节控制在 3-5 条要点，不写流水账
- 只基于产物内容撰写，不自行推断
```

**若 codex 调用失败**：主线程自行生成总结并用 Write 写文件，报告标注 ⚠️ 降级及精确 model ID（claude-sonnet-4-6）。

### 第三步：向用户汇报

展示：
- 总结文档路径
- 生成工具和精确模型版本（从写入的文档读取）
- 2-3 句话说明本次开发的整体结论
- 是否有遗留问题

---

## 版本历史

- v2.1.0（2026-04-19）：codex 自行读取模型配置，主线程只传功能名和 ROOT，零文件读操作
- v2.0.0（2026-04-19）：改用 codex-cli MCP，主线程调用，codex 直接写文件，去掉子 agent
- v1.0.0：委托 summary-writer agent 执行
