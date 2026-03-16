#!/bin/bash
# ============================================================
# 每日自动签到脚本 - V2EX + 2Libra
# 使用 Cookie 方式认证
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/checkin-cookies.conf"
LOG_FILE="$SCRIPT_DIR/checkin.log"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "$msg"
    echo "$msg" >> "$LOG_FILE"
}

# 检查配置文件
if [[ ! -f "$CONFIG_FILE" ]]; then
    cat > "$CONFIG_FILE" << 'EOF'
# ============================================================
# 签到 Cookie 配置文件
# ============================================================

# V2EX Cookie
# 获取方式: 浏览器登录 v2ex.com → F12 → Application → Cookies
# 复制整个 Cookie 字符串（包含 A2 等字段）
V2EX_COOKIE=""

# 2Libra Cookie
# 获取方式: 浏览器登录 2libra.com → F12 → Network → 任意请求的 Request Headers → Cookie
LIBRA_COOKIE=""
EOF
    echo -e "${YELLOW}配置文件已创建: $CONFIG_FILE${NC}"
    echo -e "${YELLOW}请填写 Cookie 后重新运行脚本${NC}"
    exit 1
fi

source "$CONFIG_FILE"

# ============================================================
# V2EX 签到
# ============================================================
v2ex_checkin() {
    log "========== V2EX 签到开始 =========="

    if [[ -z "${V2EX_COOKIE:-}" ]]; then
        log "${RED}[V2EX] ❌ Cookie 未配置${NC}"
        return 1
    fi

    local UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

    # 1. 访问签到页面，获取 once 参数
    log "[V2EX] 访问签到页面..."
    local mission_page
    mission_page=$(curl -s -L \
        -H "Cookie: $V2EX_COOKIE" \
        -H "User-Agent: $UA" \
        -H "Referer: https://www.v2ex.com/" \
        "https://www.v2ex.com/mission/daily" 2>&1)

    # 检查是否需要登录
    if echo "$mission_page" | grep -q "需要先登录"; then
        log "[V2EX] ❌ Cookie 已失效，需要重新获取"
        return 1
    fi

    # 检查是否已经签到
    if echo "$mission_page" | grep -q "每日登录奖励已领取"; then
        log "[V2EX] ✅ 今天已经签到过了"
        return 0
    fi

    # 提取 once 参数
    local once
    once=$(echo "$mission_page" | grep -oP '/mission/daily/redeem\?once=\K\d+' | head -1)

    if [[ -z "$once" ]]; then
        log "[V2EX] ❌ 无法获取 once 参数，可能页面结构变化"
        return 1
    fi

    log "[V2EX] 获取到 once=$once，正在签到..."

    # 2. 执行签到
    local result
    result=$(curl -s -L \
        -H "Cookie: $V2EX_COOKIE" \
        -H "User-Agent: $UA" \
        -H "Referer: https://www.v2ex.com/mission/daily" \
        "https://www.v2ex.com/mission/daily/redeem?once=$once" 2>&1)

    if echo "$result" | grep -q "每日登录奖励已领取"; then
        log "[V2EX] ✅ 签到成功！"
        # 尝试提取连续登录天数
        local days
        days=$(echo "$result" | grep -oP '已连续登录 \K\d+' | head -1)
        if [[ -n "$days" ]]; then
            log "[V2EX] 📅 已连续登录 ${days} 天"
        fi
        return 0
    else
        log "[V2EX] ⚠️ 签到结果不确定，请手动检查"
        return 1
    fi
}

# ============================================================
# 2Libra 签到
# ============================================================
libra_checkin() {
    log "========== 2Libra 签到开始 =========="

    if [[ -z "${LIBRA_COOKIE:-}" ]]; then
        log "${RED}[2Libra] ❌ Cookie 未配置${NC}"
        return 1
    fi

    local UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

    # 访问首页即可完成签到
    log "[2Libra] 访问首页进行签到..."
    local response_code
    response_code=$(curl -s -o /dev/null -w "%{http_code}" -L \
        -H "Cookie: $LIBRA_COOKIE" \
        -H "User-Agent: $UA" \
        -H "Referer: https://2libra.com/" \
        "https://2libra.com/" 2>&1)

    if [[ "$response_code" == "200" ]]; then
        log "[2Libra] ✅ 签到成功（HTTP $response_code）"
        return 0
    elif [[ "$response_code" == "401" || "$response_code" == "403" ]]; then
        log "[2Libra] ❌ Cookie 已失效（HTTP $response_code），需要重新获取"
        return 1
    else
        log "[2Libra] ⚠️ 访问返回 HTTP $response_code"
        return 1
    fi
}

# ============================================================
# 主流程
# ============================================================
main() {
    log "======================================"
    log "每日签到开始 🚀"
    log "======================================"

    local v2ex_ok=0
    local libra_ok=0

    v2ex_checkin && v2ex_ok=1 || true
    echo ""
    libra_checkin && libra_ok=1 || true

    echo ""
    log "======================================"
    log "签到结果汇总:"
    [[ $v2ex_ok -eq 1 ]] && log "  V2EX:   ✅ 成功" || log "  V2EX:   ❌ 失败"
    [[ $libra_ok -eq 1 ]] && log "  2Libra: ✅ 成功" || log "  2Libra: ❌ 失败"
    log "======================================"

    # 写入结果供 OpenClaw heartbeat 推送
    local summary=""
    summary+="📋 每日签到结果\n"
    [[ $v2ex_ok -eq 1 ]] && summary+="V2EX: ✅\n" || summary+="V2EX: ❌ 失败\n"
    [[ $libra_ok -eq 1 ]] && summary+="2Libra: ✅" || summary+="2Libra: ❌ 失败"

    # cookie 过期提醒
    if [[ $v2ex_ok -eq 0 ]]; then
        summary+="\n\n⚠️ V2EX 签到失败，可能是 2FA cookie 过期了，请重新在浏览器过一次 2FA 后把完整 cookie 发给我更新。"
    fi
    if [[ $libra_ok -eq 0 ]]; then
        summary+="\n\n⚠️ 2Libra 签到失败，可能是 cookie 过期了，请重新登录后把 cookie 发给我更新。"
    fi

    echo -e "$summary" > /root/clawd/memory/checkin-result.md
}

main "$@"
