#!/bin/bash

# OpenClaw Gateway 修复脚本 - 简化测试版本
# 专门用于测试非交互式执行

set -eo pipefail

# 简化配置
readonly SCRIPT_VERSION="1.0"
readonly DEBUG="${DEBUG:-0}"
readonly AUTO_ACCEPT="${AUTO_ACCEPT:-0}"

# 简化日志函数
log() {
    local level="$1"
    shift
    echo "[$level] $*"
}

error_exit() {
    log "ERROR" "$1"
    exit "${2:-1}"
}

# 检查系统
check_systemd() {
    log "INFO" "检查系统架构..."
    if ! command -v systemctl &> /dev/null; then
        error_exit "当前系统不是systemd架构！"
    fi
    log "INFO" "systemd架构检查通过"
}

# 获取目标用户（简化版）
get_target_user() {
    local user_input="${TARGET_USER:-}"
    if [[ -n "$user_input" ]]; then
        log "INFO" "使用指定用户: $user_input"
    else
        user_input=$(whoami)
        log "INFO" "自动使用当前用户: $user_input"
    fi
    echo "$user_input"
}

# 简化的修复流程
perform_fix() {
    local target_user="$1"
    
    log "INFO" "开始修复用户环境..."
    
    # 创建XDG_RUNTIME_DIR
    local target_uid
    target_uid=$(id -u "$target_user")
    
    log "INFO" "创建运行时目录: /run/user/$target_uid"
    sudo mkdir -p "/run/user/$target_uid" 2>/dev/null || true
    sudo chown "$target_user:$target_user" "/run/user/$target_uid" 2>/dev/null || true
    
    # 开启linger
    log "INFO" "开启用户linger..."
    sudo loginctl enable-linger "$target_user" 2>/dev/null || log "WARN" "linger开启可能失败"
    
    # 重载系统
    log "INFO" "重载systemd..."
    sudo systemctl daemon-reload 2>/dev/null || log "WARN" "systemd重载可能失败"
    
    log "INFO" "修复流程完成"
}

# 显示完成信息
show_completion() {
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
    echo "========================================"
    echo "  Gateway 修复脚本 v${SCRIPT_VERSION} (简化版)"
    echo "========================================"
    echo
    
    [[ "${DEBUG}" == "1" ]] && log "DEBUG" "调试模式已启用"
    [[ "${DEBUG}" == "1" ]] && log "DEBUG" "AUTO_ACCEPT=${AUTO_ACCEPT}"
    
    check_systemd
    
    local target_user
    target_user=$(get_target_user)
    
    log "INFO" "开始修复..."
    perform_fix "$target_user"
    show_completion "$target_user"
}

# 检查执行方式
if [[ -n "${CURL_EXECUTION:-}" ]] || [[ "$(basename "$0")" == "bash" ]] || [[ ! -f "$0" ]]; then
    export CURL_EXECUTION=1
    case "${1:-}" in
        "-h"|"--help")
            echo "Gateway 修复脚本 v${SCRIPT_VERSION} (简化版)"
            echo "用法: curl | bash"
            exit 0
            ;;
    esac
    main "$@"
else
    echo "此脚本应通过 curl 执行"
    exit 1
fi