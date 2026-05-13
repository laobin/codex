# Git 规范

## 提交规范

格式：`<类型>[可选范围]: <简短描述>`

| 类型 | 说明 |
|------|------|
| feat | 新功能 |
| fix | 修复 Bug |
| docs | 文档修改 |
| style | 格式调整（不影响逻辑） |
| refactor | 重构 |
| perf | 性能优化 |
| test | 测试 |
| chore | 构建/依赖/脚本维护 |
| ci | CI/CD 配置修改 |
| revert | 回滚 |
| deps | 依赖升级 |
| config | 配置变更 |

## 分支管理

- `production`：线上正式环境（稳定分支），**禁止直接修改**
- `master`：预发布/测试分支，用于内部测试
- `feature/*`：功能开发分支，命名：`feature/模块-功能描述`
- `hotfix/*`：紧急修复分支，命名：`hotfix/问题描述`

**Feature 流程**：从 `production` 切出 → 开发完成 → MR 合并到 `master` 测试 → 测试通过后合并到 `production`

**Hotfix 流程**：从 `production` 切出 → 修复完成 → **同时合并到 `master` 和 `production`**（缺一不可）

## MR 要求

- 重要项目至少 1 人 Code Review
- 需注明：修改说明、影响范围、是否涉及 DB/缓存/队列/定时任务
- 代码评审使用 `/code-review`，评审标准见 `agents/code-reviewer.md`
