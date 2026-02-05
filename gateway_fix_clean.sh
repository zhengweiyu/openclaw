#!/bin/bash

# OpenClaw Gateway 修复脚本 - 静默版本
# 版本: 1.0
# 使用方法: curl -fsSL https://raw.githubusercontent.com/zhengweiyu/openclaw/main/gateway_fix.sh | bash

set -eo pipefail

# 简化配置
readonly SCRIPT_VERSION="1.0"
readonly DEBUG="${DEBUG:-0}"
readonly AUTO_ACCEPT="${AUTO_ACCEPT:-1}"

# 静默日志函数（只输出重要信息）
log() {
    [[ "${DEBUG}" == "1" ]] || return
    echo "[$1] $2"
}

error_exit() {
    echo "[ERROR] $1"
    exit "${2:-1}"
}

# 显示横幅
show_banner() {
    echo "========================================"
    echo "  Gateway 修复脚本 v${SCRIPT_VERSION}"
    echo "========================================"
    echo "🔧 修复 systemd 用户服务问题"
    echo "⚡ 解决问题:"
    echo "• 用户级systemd总线不通"
    echo "• XDG_RUNTIME_DIR缺失"
    echo "• daemon-reload失败"
    echo "• 用户服务持久化"
    echo
}

# 检查系统
check_systemd() {
    if ! command -v systemctl &> /dev/null; then
        error_exit "当前系统不是systemd架构！"
    fi
    log "INFO" "systemd架构检查通过"
}

# 获取目标用户名（静默版）
get_target_user() {
    local user_input="$TARGET_USER"
    local current_user
    
    # 静默获取当前用户
    current_user=$(whoami 2>/dev/null | tr -d '\n\r' | tr -d ' \t')
    
    if [[ -n "$user_input" ]]; then
        log "INFO" "使用指定用户: $user_input"
    else
        user_input="$current_user"
        log "INFO" "自动使用当前用户: $user_input"
    fi
    
    # 清理用户名
    user_input=$(echo "$user_input" | tr -d ' \t\n\r')
    
    if ! id -u "$user_input" &> /dev/null; then
        error_exit "用户名 $user_input 不存在！"
    fi
    
    echo "$user_input"
}

# 开启用户linger（静默版）
enable_linger() {
    local target_user="$1"
    
    echo "🔧 开启用户linger持久化..."
    
    if [[ $EUID -ne 0 ]]; then
        echo "🔑 正在提权到root..."
        # 完全静默执行
        if sudo loginctl enable-linger "$target_user" >/dev/null 2>&1; then
            echo "✅ linger已开启"
            sudo systemctl daemon-reload >/dev/null 2>&1
            echo "✅ 系统级systemd已重载"
        else
            error_exit "root操作失败，请手动执行 loginctl enable-linger $target_user"
        fi
    else
        loginctl enable-linger "$target_user" >/dev/null 2>&1
        systemctl daemon-reload >/dev/null 2>&1
        echo "✅ linger已开启，systemd已重载"
    fi
}

# 验证用户环境（静默版）
verify_user_environment() {
    local target_user="$1"
    local target_uid
    target_uid=$(id -u "$target_user")
    
    echo "🔍 验证用户环境..."
    
    # 静默创建运行时目录
    sudo mkdir -p "/run/user/$target_uid" 2>/dev/null || true
    sudo chown -R "$target_user:$target_user" "/run/user/$target_uid" 2>/dev/null || true
    echo "✅ XDG_RUNTIME_DIR已创建: /run/user/$target_uid"
    
    # 静默测试用户级systemd
    if sudo -iu "$target_user" systemctl --user status >/dev/null 2>&1; then
        echo "✅ 用户级systemd总线连通成功！"
    else
        error_exit "用户级systemd总线仍不通，请检查系统配置！"
    fi
    
    # 静默执行daemon-reload
    sudo -iu "$target_user" systemctl --user daemon-reload >/dev/null 2>&1
    echo "✅ daemon-reload执行成功！"
}

# 显示最终结果（静默版）
show_completion_guide() {
    local target_user="$1"
    echo
    echo "========================================"
    echo "        🎉 Gateway 修复完成！"
    echo "========================================"
    echo
    echo "📋 修复的用户: $target_user"
    echo "🔧 修复内容: systemd用户服务环境"
    echo "✅ 修复状态: 完成"
    echo
    echo "🚀 建议操作:"
    echo "   - 重新连接服务器确保环境生效"
    echo "   - 手动重启Gateway: sudo -iu $target_user systemctl --user restart gateway"
    echo "   - 查看服务状态: sudo -iu $target_user systemctl --user status gateway"
    echo
}

# 主函数
main() {
    show_banner
    
    [[ "${DEBUG}" == "1" ]] && log "INFO" "调试模式已启用"
    
    check_systemd
    
    local target_user
    target_user=$(get_target_user)
    
    echo "⚠️  修复前说明:"
    echo "• 脚本会开启用户linger持久化"
    echo "• 需要root权限（会自动提权）"
    echo "• 确保当前用户有sudo权限"
    echo "• 修复后建议重新连接服务器"
    echo
    echo "🔄 开始修复..."
    
    enable_linger "$target_user"
    verify_user_environment "$target_user"
    show_completion_guide "$target_user"
}

# 检查执行方式
if [[ -n "${CURL_EXECUTION:-}" ]]; then
    case "${1:-}" in
        "-h"|"--help")
            echo "Gateway 修复脚本 v${SCRIPT_VERSION} (静默版)"
            echo "用法: curl | bash"
            exit 0
            ;;
    esac
    
    export CURL_EXECUTION=1
    main "$@"
else
    echo "此脚本应通过 curl 执行"
    exit 1
fi