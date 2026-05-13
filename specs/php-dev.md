# PHP 开发规范

## 命名规范

| 类型 | 规范 | 示例 |
|------|------|------|
| 类/接口/Trait | 大驼峰 PascalCase | `UserService` |
| 普通函数 | 小写 + 下划线 | `get_client_ip` |
| 方法 | 小驼峰 camelCase | `getUserName` |
| 常量 | 大写 + 下划线 | `APP_DEBUG` |
| 数据表/字段 | 小写 + 下划线 | `user_account`, `created_time` |

## 分层架构（MVC + Service）

- **Controller**：只做参数验证、调用 Service、返回响应；**禁止写任何业务逻辑，禁止直接操作 Model**
- **Service**：业务逻辑核心，负责业务编排、事务控制、缓存管理、调用外部 SDK
- **Model**：只做数据访问、字段校验、模型关联；禁止写业务逻辑，禁止直接响应请求

## 统一响应

- HTTP 状态码**固定为 200**，业务状态通过 `code` 字段区分
- 使用 `ApiResponse::success($data)` / `ApiResponse::error(400, '错误信息')` 统一响应

## 异常规范

| 异常类 | 使用场景 | 前端展示 | 是否告警 |
|--------|---------|---------|---------|
| `ValidationException` | 参数验证失败、格式错误 | message 直接返回 | 否 |
| `BusinessException` | 业务预期错误（余额不足、状态冲突等） | message 直接返回 | 可选 |
| `SystemException` | 系统/未知错误（DB 异常、Redis 失败等） | 统一返回"系统异常" | 建议开启 |

- **抛异常时必须携带 previous**，不得丢失原始堆栈：`throw new BusinessException('失败', $e)`

## Cache Key 规范

- Key 必须具备明确业务语义，代表一类完整数据单元
- 层级分隔符统一使用英文冒号 `:`，格式：`业务:模块:类型:{动态参数}:版本`
- **禁止**在业务代码中手写硬编码 Key，必须封装到统一的 `CacheKey` 类中
```php
class CacheKey {
    public static function userProfile(int $userId): string {
        return "user:profile:detail:{$userId}:v1";
    }
}
// ✅ Cache::get(CacheKey::userProfile($userId));
// ❌ Cache::get("user:profile:detail:$userId");
```

## 配置读取

- **禁止在业务代码中直接读取 `.env`**，必须通过 `config()` 函数读取配置文件
