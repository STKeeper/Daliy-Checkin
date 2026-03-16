# 每日自动签到脚本

V2EX + 2Libra 每日自动签到，使用 Cookie 认证，通过 cron 定时执行，签到结果自动推送到 Telegram。

## 文件说明

| 文件 | 说明 |
|------|------|
| `daily-checkin.sh` | 签到主脚本 |
| `checkin-cookies.conf` | Cookie 配置文件（⚠️ 含敏感信息，勿泄露） |
| `checkin.log` | 运行日志（自动生成） |

## 支持的网站

### V2EX（https://www.v2ex.com）

- **签到方式**：访问 `/mission/daily` 页面 → 提取 `once` 令牌 → 请求 `/mission/daily/redeem?once=xxx` 完成签到
- **`once` 参数**：V2EX 的一次性防重放令牌（类似 CSRF token），每次访问签到页面会生成一个随机数字，签到时必须携带，用过即作废
- **认证方式**：Cookie（需要 `A2` + `A2O` 等多个字段）
- **注意**：如果账号开启了两步验证（2FA），需要在浏览器手动通过 2FA 后抓取完整 Cookie。2FA 的 Cookie（`A2O`）大约 **两周** 过期一次

### 2Libra（https://2libra.com）

- **签到方式**：携带 Cookie 访问首页即算签到（每日登录一次）
- **认证方式**：Cookie（主要依赖 `access_token`）
- **注意**：`access_token` 为 JWT 格式，有过期时间，失效后需重新登录获取

## Cookie 获取方法

### V2EX

1. 浏览器登录 https://www.v2ex.com
2. 如果开启了 2FA，完成两步验证
3. 访问 https://www.v2ex.com/mission/daily 确认能看到签到页面
4. `F12` → **Network** 面板 → 刷新页面
5. 点击第一个请求，在 **Request Headers** 中找到 `Cookie` 那一行
6. 复制**完整的 Cookie 字符串**

### 2Libra

1. 浏览器登录 https://2libra.com
2. `F12` → **Network** 面板 → 刷新页面
3. 点击任意请求，在 **Request Headers** 中找到 `Cookie` 那一行
4. 复制完整的 Cookie 字符串

## 配置

将获取的 Cookie 填入 `checkin-cookies.conf`：

```bash
V2EX_COOKIE='A2="..."; A2O="..."; PB3_SESSION="..."; V2EX_LANG=zhcn; ...'
LIBRA_COOKIE='access_token=eyJ...; refresh_token=...; ...'
```

## 使用

### 手动运行

```bash
bash /root/clawd/scripts/daily-checkin.sh
```

### 定时任务（已配置）

```cron
30 8 * * * /root/clawd/scripts/daily-checkin.sh >> /root/clawd/scripts/checkin.log 2>&1
```

每天 **08:30 UTC**（都柏林时间 08:30/09:30）自动执行。

## 签到流程

```
┌─────────────────────────────────────┐
│           daily-checkin.sh          │
├─────────────────────────────────────┤
│                                     │
│  1. 读取 checkin-cookies.conf       │
│                                     │
│  2. V2EX 签到                       │
│     ├─ 带 Cookie 访问 /mission/daily│
│     ├─ 检查是否已签到               │
│     ├─ 提取 once 令牌               │
│     └─ 请求 /mission/daily/redeem   │
│                                     │
│  3. 2Libra 签到                     │
│     └─ 带 Cookie 访问首页           │
│                                     │
│  4. 写入结果到                      │
│     memory/checkin-result.md        │
│                                     │
│  5. OpenClaw Heartbeat 检测到文件   │
│     → 推送结果到 Telegram           │
│     → 删除文件                      │
│                                     │
└─────────────────────────────────────┘
```

## 结果推送

脚本执行后会将结果写入 `/root/clawd/memory/checkin-result.md`，OpenClaw 的 Heartbeat 机制会自动检测该文件并将内容推送到 Telegram，然后删除文件。

- ✅ 签到成功：推送成功信息
- ❌ 签到失败：推送失败信息 + Cookie 过期提醒

## Cookie 过期处理

| 网站 | 过期周期 | 处理方式 |
|------|----------|----------|
| V2EX | ~2 周（2FA Cookie） | 浏览器重新过 2FA，抓完整 Cookie 更新 |
| 2Libra | 取决于 JWT 过期时间 | 浏览器重新登录，抓 Cookie 更新 |

签到失败时脚本会在推送消息中提醒更新 Cookie。

## 日志

运行日志保存在 `scripts/checkin.log`，包含每次签到的详细信息：

```
[2026-03-16 09:59:05] 每日签到开始 🚀
[2026-03-16 09:59:05] ========== V2EX 签到开始 ==========
[2026-03-16 09:59:05] [V2EX] 访问签到页面...
[2026-03-16 09:59:05] [V2EX] ✅ 今天已经签到过了
[2026-03-16 09:59:05] ========== 2Libra 签到开始 ==========
[2026-03-16 09:59:07] [2Libra] ✅ 签到成功（HTTP 200）
```

## 创建日期

2026-03-16
