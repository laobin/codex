---
name: backend-task-assign
description: 后端组工作任务指派流程。用于用户要求给后端同事分配任务、写入“后端组工作进展表”、指定负责人/项目/截止时间/交付物、生成任务记录链接，或把任务创建结果同步到“后端小分队”飞书群时使用；典型说法包括“给某人指派一个任务”“创建后端任务并同步群”“维护后端组工作进展表任务”。
---

# 后端组任务指派

## 固定资源

优先使用这些已验证参数，避免重复解析链接：

| 资源 | 值 |
| --- | --- |
| 工作进展表链接 | `https://jinzhouai.feishu.cn/wiki/KMDMwxxyDiVNTwknUAcc35GLnwg?table=tblE9KNnd4akHJu7&view=vewKEDvefq` |
| Base 名称 | `后端组工作进展表` |
| Base token | `Wvj1bFxNbahstPsefoWcF3ZDngz` |
| 表名 / 表 ID | `后端组待办` / `tblE9KNnd4akHJu7` |
| 常用视图 | `张德斌待办` / `vewKEDvefq` |
| 同步群 | `后端小分队` |
| 同步群 chat_id | `oc_05f11f2f6ec803691b8a6a49b125837d` |
| 群消息身份 | 默认 `--as bot` |

已验证常用人员（2026-06-03 从 `负责人` 字段 126 条记录中去重得到）：

| 姓名 | open_id |
| --- | --- |
| 蔡梓钿 | `ou_1732b45f4bbf7ad1aeb82b7709dd1a24` |
| 杜伟毅 | `ou_6ea6e3ddd88dea6a5ae55a3226f1106f` |
| 马斐彤 | `ou_09065e55daaa0908f749023bf463b603` |
| 谢金吐 | `ou_5c6bc4c9d8c7105dce0dc47b1515ff47` |
| 张德斌 | `ou_2a2cefc26e4d8fb9c8105198702b6b58` |
| 张溢键 | `ou_d4b8326a94acf26911015b9017a13e7c` |
| 钟琪锋 | `ou_b1180d7ba6cfd68d190ceb1f76da7f93` |

## 依赖 Skills

按需加载并遵守这些飞书 skill：

- `lark-base`：读取字段、检索重复任务、创建任务记录、生成记录分享链接。
- `lark-contact`：解析未收录人员的 open_id。
- `lark-im`：搜索群、发送群消息。发送消息前必须按 `lark-im` 要求确认收件群、消息内容和发送身份。

如果 `HTTPS_PROXY` 导致 `lookup http: no such host`，本次命令临时设置 `LARK_CLI_NO_PROXY=1` 后重试。

## 字段与默认值

写入 `tblE9KNnd4akHJu7` 时优先使用字段名：

| 字段 | 写入规则 |
| --- | --- |
| `任务名称` | 从用户任务目标整理成一句清晰标题。 |
| `所属项目` | 使用用户给出的项目原文；已验证 `海外聚宝盆` 是有效选项。 |
| `负责人` | user 字段，写 `[{ "id": "ou_xxx" }]`；不要猜 ID。 |
| `状态` | 默认 `未开始`，除非用户明确给出其他状态。 |
| `截止时间` | 写 `YYYY-MM-DD 00:00:00`；相对日期必须结合当前日期转成绝对日期。 |
| `开始开发日期` | 默认当前日期 `YYYY-MM-DD 00:00:00`。 |
| `交付物` | 多选；文档/整理/调研结论默认写 `["结论"]`，开发任务默认写 `["代码"]`，方案任务写 `["方案"]`。 |
| `优先级` | 明确短期截止或用户强调紧急时写 `重要紧急`，否则可不写或写 `重要不紧急`。 |
| `备注` | 写清任务背景、交付对象、交付范围、关键参数/代码/文档要求。 |
| `关联资料` | 放已有任务 record_id、文档链接或用户提供的资料链接。 |

不要写 `逾期天数`、`风险状态`、`AI进展摘要` 等公式或只读字段。

## 工作流

1. 解析任务要素：项目、负责人、任务标题、交付对象、截止时间、交付物、是否同步群。
2. 将所有相对日期转成绝对日期。当前日期来自系统上下文；例如 2026-06-03 时“4号之前”按 `2026-06-04` 处理。
3. 解析负责人 open_id：
   - 如果命中“已验证常用人员”，直接使用固定 open_id。
   - 否则先用 `lark-contact +search-user`。
   - 若联系人权限缺失，可用 `lark-base +record-search` 在 `负责人` 字段按姓名反查历史记录中的 `{id,name}`，仅在姓名唯一匹配时复用。
4. 创建前做一次轻量重复检查：用任务关键词在 `任务名称`、`备注`、`关联资料` 中 `+record-search`。发现近似已有任务时，根据用户意图选择更新已有任务或创建更具体的新任务，并在 `关联资料` 里记录关联。
5. 用 `lark-cli base +record-upsert` 创建记录。
6. 用 `lark-cli base +record-share-link-create` 生成记录链接。
7. 如果用户要求同步群：
   - 发送前向用户确认群、发送身份和消息正文。
   - 默认发送到 `后端小分队` 的 `oc_05f11f2f6ec803691b8a6a49b125837d`，身份 `--as bot`。
   - 消息中包含任务名、项目、负责人、交付对象、截止时间、简要要求和记录链接；能确定 open_id 时使用 `<at user_id="ou_xxx">姓名</at>`。
   - 使用包含 record_id 的 `--idempotency-key`，避免重复发送。

## 常用命令模板

创建记录：

```powershell
$env:LARK_CLI_NO_PROXY='1'
lark-cli base +record-upsert `
  --base-token Wvj1bFxNbahstPsefoWcF3ZDngz `
  --table-id tblE9KNnd4akHJu7 `
  --json '<FIELD_JSON>' `
  --as user
```

生成记录链接：

```powershell
$env:LARK_CLI_NO_PROXY='1'
lark-cli base +record-share-link-create `
  --base-token Wvj1bFxNbahstPsefoWcF3ZDngz `
  --table-id tblE9KNnd4akHJu7 `
  --record-ids <record_id> `
  --as user
```

发送群消息：

```powershell
$env:LARK_CLI_NO_PROXY='1'
lark-cli im +messages-send `
  --chat-id oc_05f11f2f6ec803691b8a6a49b125837d `
  --text '<MESSAGE_TEXT>' `
  --as bot `
  --idempotency-key 'backend-task-<record_id>'
```

## 输出要求

完成后简要返回：是否创建成功、record_id、记录链接、是否已同步群、消息 ID。若权限缺失，说明缺少的 scope、已完成的部分和下一步授权命令。
