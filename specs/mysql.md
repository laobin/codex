# MySQL 数据库设计规范

## 命名规范

- 表名、字段名：**小写 + 下划线**，表名用复数，不使用保留字（`order`/`desc`/`key` 等）
- 标准写法：`user_account`、`created_time`

## 字段规范

- **禁止使用 NULL**：字符串默认 `''`，数字默认 `0`，时间默认 `CURRENT_TIMESTAMP`
- 金额：用 `decimal(10,2)`（元）或 `bigint`（分）；**禁止用 float/double**
- 时间：用 `DATETIME`，**不用 TIMESTAMP**（2038 问题）
- Boolean：用 `tinyint(1)`，如 `is_deleted tinyint(1) DEFAULT 0`
- 大字段（超 1KB）拆分到附表，如 `product_detail`

## 索引规范

- 每张表索引不超过 **5 个**
- 遵循**最左前缀原则**
- WHERE / ORDER BY / JOIN 字段必须建索引
- 低区分度字段（gender/status）不单独建索引，考虑联合索引 `(status, updated_time)`
- 字符串字段超 100 字符使用前缀索引：`index idx_name (name(20))`
- **禁止**在高并发系统使用外键约束，由应用层保证数据一致性

## SQL 规范

- **禁止 `SELECT *`**，明确写出所需字段
- 禁止 `%xxx` 前置百分号模糊查询（无法命中索引），全文搜索考虑 ES
- 大分页优化：用 `WHERE id > last_id LIMIT 20` 替代 `LIMIT 100000, 20`

## 表结构规范

- 超过 **2000 万行**考虑按时间或 UID hash 分表
- 日志/历史数据按月分表：`user_login_log_202501`
- 存储引擎强制使用 **InnoDB**

## 通用字段

| 字段 | 类型 | 说明 |
|------|------|------|
| id | bigint unsigned AUTO_INCREMENT | 主键 |
| created_time | datetime DEFAULT CURRENT_TIMESTAMP | 创建时间 |
| updated_time | datetime ON UPDATE CURRENT_TIMESTAMP | 更新时间 |
| is_deleted | tinyint(1) DEFAULT 0 | 软删除（可选） |
| version | int | 乐观锁（可选） |

## 建表示例

```sql
CREATE TABLE `user_account` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT COMMENT '主键',
  `uid` bigint unsigned NOT NULL DEFAULT 0 COMMENT '用户ID',
  `mobile` varchar(20) NOT NULL DEFAULT '' COMMENT '手机号',
  `balance` decimal(10,2) NOT NULL DEFAULT 0 COMMENT '余额(元)',
  `status` tinyint(1) NOT NULL DEFAULT 1 COMMENT '状态:1启用 0禁用',
  `created_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0 COMMENT '软删除标志',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_mobile` (`mobile`),
  KEY `idx_uid_status` (`uid`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户账户表';
```
