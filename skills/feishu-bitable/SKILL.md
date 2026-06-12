---
name: feishu-bitable
description: 用 lark-cli 操作飞书多维表格/智能表格（Bitable）——解析 wiki 链接、建/改字段、批量增删记录、配置分组/排序/筛选视图。当用户要读写飞书表格、把数据写入飞书表格、配置飞书表格视图时触发。
version: 1.0.0
---

# 操作飞书智能表格（Bitable / 多维表格）

封装用 `lark-cli` 读写飞书多维表格的标准流程与全部已知坑。**所有命令在 PowerShell 下执行。**

## 0. 前置（每次会话第一步，必做）

```powershell
$env:LARK_CLI_NO_PROXY='1'                 # 必须！否则 HTTPS_PROXY 会让所有请求报 "lookup http: no such host"
$cli = "D:\nvm4w\nodejs\lark-cli.ps1"       # lark-cli 入口
```

**凭证（已存于用户级环境变量，无需用户提供）**：
- `FEISHU_PROFILE` = App ID（`cli_` 开头）
- `FEISHU_CLI_APP_SEC` = App Secret（32 位）
- `FEISHU_BASE_TOKEN` / `FEISHU_TABLE_ID` = 旧「后端组待办」表的默认 token（仅作参照，新表用自己的）

读取方式：`[Environment]::GetEnvironmentVariable('FEISHU_PROFILE','User')`（当前进程可能未继承，用 User 作用域取最稳）。

**身份**：写操作一律加 `--as user`（用户身份=张德斌，管理员，有 record/field/view 全部 scope）。
- ⚠️ **bot/tenant 身份不能写记录**（91403 / 99991672）。tenant_access_token 只能读字段。

## 1. 由 wiki/分享链接拿到表的 base_token

用户给的链接形如 `https://xxx.feishu.cn/wiki/<NODE_TOKEN>?table=<TABLE_ID>&view=<VIEW_ID>`。
其中 `table=tbl...` 就是 table_id；但 base 的 app_token 要由 wiki 节点解析：

```powershell
$body = @{ app_id=[Environment]::GetEnvironmentVariable('FEISHU_PROFILE','User'); app_secret=[Environment]::GetEnvironmentVariable('FEISHU_CLI_APP_SEC','User') } | ConvertTo-Json
$tok = (Invoke-RestMethod -Uri 'https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal' -Method Post -ContentType 'application/json; charset=utf-8' -Body $body).tenant_access_token
$node = Invoke-RestMethod -Uri 'https://open.feishu.cn/open-apis/wiki/v2/spaces/get_node?token=<NODE_TOKEN>&obj_type=wiki' -Headers @{Authorization="Bearer $tok"}
$node.data.node.obj_token   # ← 这就是 base 的 app_token，下面所有 --base-token 用它
```
（普通 `base/...` 链接的 token 本身就是 app_token，无需解析。）

## 2. PowerShell 调用规约（踩坑总结）

- **stderr 会混进输出** → 把 stdout 重定向到文件再读：
  ```powershell
  & $cli base +record-list --base-token $app --table-id $tbl --as user --format json 1>$tmp 2>$null
  $j = Get-Content $tmp -Raw -Encoding UTF8 | ConvertFrom-Json
  ```
  直接 `| Out-String | ConvertFrom-Json` 偶尔会因首部混入提示符报 "Unexpected character"。
- **不要把函数参数命名为 `$args`**（PowerShell 保留变量，会导致命令拼装失效）。
- **中文/emoji 可安全透传** 给 lark-cli（实测 `🟢🟡🔴`、中文选项名都能正确匹配）。
- **构造复杂 --json**：用 `[ordered]@{...} | ConvertTo-Json -Depth 6 -Compress`，对 `{fields,rows}` 这种嵌套结构有效。
- **新写法先 `--dry-run`** 看请求体，再正式执行。
- **jq 表达式里的对象 key 不能是裸中文**（加引号或用 ASCII key）。访问中文列建议在 PowerShell 侧用 `[array]::IndexOf($cols,'列名')` 定位。

## 3. 字段（field）

```powershell
# 列字段：.data.fields[] = {id, name, type, multiple, options}
& $cli base +field-list --base-token $app --table-id $tbl --as user 1>$tmp 2>$null

# 建字段（无需 --yes）
& $cli base +field-create --base-token $app --table-id $tbl --as user --json '{"name":"接口","type":"text"}'
# 单选/多选：type=select + 顶层 multiple + options
& $cli base +field-create --base-token $app --table-id $tbl --as user --json '{"name":"优先级","type":"select","multiple":false,"options":[{"name":"P0"},{"name":"P1"}]}'

# 改字段/重命名（高危，需 --yes，且 json 必须带 type）
& $cli base +field-update --base-token $app --table-id $tbl --as user --field-id fldXXX --json '{"name":"编号","type":"text"}' --yes
```

**type 合法值**：`text / number / select / datetime / created_at / updated_at / user / group_chat / created_by / updated_by / link / formula / lookup / auto_number / attachment / location / checkbox`。
- 单选与多选都是 `select`，靠顶层 `multiple` 区分。
- 主字段（首列）不可删、必须 text 类。

## 4. 记录（record）

```powershell
# 批量建记录：用 {fields:[列名...], rows:[[值...], ...]}  —— 不是 {records:[...]}！
$payload = [ordered]@{
  fields = @('编号','模块','优先级')
  rows   = @( @('PAY-001','支付','P0'), @('USR-001','用户','P1') )
}
$json = $payload | ConvertTo-Json -Depth 6 -Compress
& $cli base +record-batch-create --base-token $app --table-id $tbl --as user --json $json
```
- 单选列的值 = 选项名字符串；多选列的值 = 名字数组 `["A","B"]`；不存在的选项会被拒/忽略。
- ⚠️ **响应里 `created` 常显示 0（不回显），不代表失败**。一律用 `record-list` 复核真实条数。

```powershell
# 列记录：必须加 --format json，否则输出 markdown
& $cli base +record-list --base-token $app --table-id $tbl --as user --format json 1>$tmp 2>$null
# 也可加 --view-id 看某视图过滤后的结果
```

**record-list 返回结构（重要，易错）**：
- `.data.fields` —— 列名数组（**行值按此顺序**）
- `.data.data` —— 行数组，**每行是值的数组**（不是对象！）；按 `.data.fields` 顺序对应
- `.data.record_id_list` —— 记录 ID 数组（取总数/删除用）
- `.data.field_id_list` / `.data.has_more` / `.data.total`
- ⚠️ **没有 `.data.records`**。单选单元格值是数组 `["选项"]`，文本是字符串。

```powershell
# 删记录（高危，需 --yes）
& $cli base +record-delete --base-token $app --table-id $tbl --as user --json '{"record_id_list":["rec1","rec2"]}' --yes
# 清空全表 = 先 record-list 取 record_id_list，再 delete
```

## 5. 视图（view）—— 分组/排序/筛选

```powershell
# 列视图：视图在 .data.views[] = {id, name, type}（不是 items！）
& $cli base +view-list --base-token $app --table-id $tbl --as user 1>$tmp 2>$null

# 建视图（建后响应不一定回显 id，重新 view-list 取最新 id）
& $cli base +view-create --base-token $app --table-id $tbl --as user --json '{"name":"按模块","type":"grid"}'
# 重命名
& $cli base +view-rename --base-token $app --table-id $tbl --view-id vewXXX --as user --name '①按模块·评审'

# 分组（field 用字段 ID）
& $cli base +view-set-group  --base-token $app --table-id $tbl --view-id vewXXX --as user --json '{"group_config":[{"field":"fldMod","desc":false}]}'
# 排序
& $cli base +view-set-sort   --base-token $app --table-id $tbl --view-id vewXXX --as user --json '{"sort_config":[{"field":"fldPri","desc":false}]}'
# 筛选 —— 注意：用 "logic"（不是 conjunction）；每个条件是数组 [字段, 操作符, 值]，不是对象！
& $cli base +view-set-filter --base-token $app --table-id $tbl --view-id vewXXX --as user --json '{"logic":"and","conditions":[["fldPri","is","P0"]]}'
```
- 单选列排序为升序时按选项定义顺序排（如 P0,P1,P2 → P0 在前）。
- 筛选操作符：`is` / `==` / `contains` 等。`view-get-filter` 返回 `{"filter":{"conditions":[],"logic":"and"}}` 可作格式参照。

## 6. 标准作业流程（新建一张对齐/任务表）

1. 关代理、读凭证；若是 wiki 链接先解析 `obj_token`。
2. `field-list` 看现状 → `field-update` 把主字段改成有意义的名（带 type、--yes）。
3. `field-create` 逐个建列（select 列带 options）。
4. `record-batch-create` 用 `{fields,rows}` 灌数据 → `record-list --format json` 复核条数。
5. 配视图：重命名默认视图并设分组/排序；`view-create` 增加「按端/按现状/P0清单」等视角，逐个 set-group/sort/filter。
6. 抽检 2~3 行确认 select/中文/emoji 正确，向用户汇报链接与视图清单。

## 关键坑速查表

| 现象 | 原因 / 解法 |
|------|------------|
| 所有请求 `lookup http: no such host` | 没设 `$env:LARK_CLI_NO_PROXY='1'` |
| 写记录 91403 / 99991672 | 用了 bot/tenant；改 `--as user` |
| batch-create 返回 ok 但 created=0 | 正常，不回显；用 record-list 复核 |
| record-list 解析 `.data.records` 为空 | 路径错，应是 `.data.data`（行=数组）|
| record-list 输出是表格不是 JSON | 缺 `--format json` |
| set-filter 报 "conditions[0] type array" | conditions 用对象了；应是数组 `[field,op,val]`，且键名 `logic` 非 conjunction |
| field-update "Invalid discriminator" | json 缺 `type` 字段 |
| field-create 报 `unknown flag --yes` | field-create 不要 --yes；field-update/delete/view 写操作才要 |
| ConvertFrom-Json "Unexpected character" | stderr 混入；改 `1>$file 2>$null` 再 `Get-Content -Raw -Encoding UTF8` |
| 命令拼装失效、打印顶层 help | 函数参数误用了保留变量 `$args` |

## 版本历史
- v1.0.0（2026-06-01）：初版，沉淀「海外中转站业务梳理」表的建表/灌数据/配视图全流程经验。
