#!/bin/bash

# OpenClaw Gateway 修复脚本 - 工作版本
# 版本: 1.0
# 使用方法: curl -fsSL https://raw.githubusercontent.com/zhengweiyu/openclaw/main/gateway_fix.sh | bash

set -eo pipefail

# ==================== 配置 ====================
readonly SCRIPT_VERSION="1.0"
readonly SCRIPT_URL="https://raw.githubusercontent.com/zhengweiyu/openclaw/main/gateway_fix.sh"

# 简化颜色定义（避免终端兼容问题）
readonly RED=''
readonly GREEN=''
readonly YELLOW=''
readonly BLUE=''
readonly PURPLE=''
readonly CYAN=''
readonly NC=''

# 全局配置
readonly DEBUG="${DEBUG:-0}"
readonly AUTO_ACCEPT="${AUTO_ACCEPT:-0}"
readonly TARGET_USER="${TARGET_USER:-}"

# 日志函数
log() {
    local level="$1"
    shift
    local message="$*"
    echo "[$level] $message"
}

# 错误处理函数
error_exit() {
    log "ERROR" "$1"
    exit "${2:-1}"
}

# 确认对话框（非交互模式下跳过）
confirm() {
    local message="$1"
    [[ "${AUTO_ACCEPT}" == "1" ]] && return 0
    
    local response
    read -p "$message [y/N]: " -r response
    case "$response" in
        [Yy]|[Yy][Ee][Ss]) return 0 ;;
        *) return 1 ;;
    esac
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

# 检查系统是否为systemd
check_systemd() {
    log "INFO" "检查系统架构..."
    
    if ! command -v systemctl &> /dev/null; then
        error_exit "当前系统不是systemd架构，该脚本不适用！"
    fi
    
    log "INFO" "systemd架构检查通过"
}

# 获取目标用户名
get_target_user() {
    local user_input="$TARGET_USER"
    
    if [[ -n "$user_input" ]]; then
        log "INFO" "使用指定用户: $user_input"
    elif [[ "${AUTO_ACCEPT}" == "1" ]]; then
        user_input=$(whoami)
        log "INFO" "自动模式，使用当前用户: $user_input"
    else
        read -p "请输入需要修复的目标用户名（默认: $(whoami)）: " -r user_input
        user_input="${user_input:-$(whoami)}"
    fi
    
    if ! id -u "$user_input" &> /dev/null; then
        error_exit "用户名 $user_input 不存在！"
    fi
    
    echo "$user_input"
}

# 开启用户linger持久化
enable_linger() {
    local target_user="$1"
    
    log "INFO" "开启用户linger持久化..."
    
    if [[ $EUID -ne 0 ]]; then
        log "INFO" "正在提权到root..."
        if sudo loginctl enable-linger "$target_user"; then
            log "INFO" "linger已开启"
            sudo loginctl show-user "$target_user" | grep Linger
            sudo systemctl daemon-reload
            log "INFO" "系统级systemd已重载"
        else
            error_exit "root操作失败，请手动执行 loginctl enable-linger $target_user"
        fi
    else
        loginctl enable-linger "$target_user"
        log "INFO" "linger已开启"
        loginctl show-user "$target_user" | grep Linger
        systemctl daemon-reload
        log "INFO" "系统级systemd已重载"
    fi
}

# 验证用户环境
verify_user_environment() {
    local target_user="$1"
    local target_uid
    target_uid=$(id -u "$target_user")
    
    log "INFO" "验证用户环境..."
    
    # 简化的验证逻辑
    log "INFO" "创建XDG_RUNTIME_DIR..."
    sudo mkdir -p "/run/user/$target_uid"
    sudo chmod 700 "/run/user/$target_uid"
    sudo chown -R "$target_user:$target_user" "/run/user/$target_uid"
    log "INFO" "XDG_RUNTIME_DIR已创建: /run/user/$target_uid"
    
    # 测试用户级systemd
    if sudo -iu "$target_user" systemctl --user status &> /dev/null; then
        log "INFO" "用户级systemd总线连通成功！"
    else
        log "ERROR" "用户级systemd总线仍不通，请检查系统配置！"
        return 1
    fi
    
    # 执行用户级daemon-reload
    sudo -iu "$target_user" systemctl --user daemon-reload
    log "INFO" "daemon-reload执行成功！"
}

# 显示最终结果
show_completion_guide() {
    local target_user="$1"
    echo
    echo "========================================"
    echo "        🎉 Gateway 修复完成！"
    echo "========================================"
    echo
    echo "📋 验证结果:"
    echo "1. Linger状态验证："
    sudo loginctl show-user "$target_user" | grep Linger
    echo
    echo "🚀 建议操作:"
    echo "   - 退出当前终端，重新连接服务器"
    echo "   - 重新启动Gateway服务："
    echo "     sudo -iu $target_user systemctl --user restart gateway"
    echo "   - 查看Gateway日志："
    echo "     sudo -iu $target_user journalctl --user -u gateway -f"
    echo
    echo "✨ Gateway 服务问题已修复！"
    echo
    
    # 尝试自动重启 Gateway 服务
    echo "🔄 正在尝试自动重启 Gateway 服务..."
    if sudo -iu "$target_user" command -v openclaw &> /dev/null; then
        if sudo -iu "$target_user" openclaw gateway restart 2>/dev/null; then
            echo "✅ Gateway 服务已成功重启！"
            
            # 等待几秒让服务启动
            sleep 3
            
            # 显示服务状态
            echo "📊 Gateway 服务状态："
            if sudo -iu "$target_user" systemctl --user is-active --quiet gateway; then
                echo "   ✅ Gateway 服务正在运行"
                # 显示端口信息
                echo "📡 Gateway 端口信息："
                sudo -iu "$target_user" openclaw gateway status 2>/dev/null || echo "   ℹ️  无法获取详细状态，但服务已启动"
            else
                echo "   ⚠️  Gateway 服务可能需要更多时间启动"
            fi
        else
            echo "⚠️  自动重启失败，请手动执行："
            echo "   sudo -iu $target_user openclaw gateway restart"
        fi
    else
        echo "ℹ️  OpenClaw 命令未找到，跳过自动重启"
        echo "   请确保 OpenClaw 已正确安装"
    fi
    
    echo
}

# 主修复函数
main() {
    show_banner
    
    if [[ "${DEBUG}" == "1" ]]; then
        log "INFO" "调试模式已启用"
        log "INFO" "AUTO_ACCEPT=${AUTO_ACCEPT}"
        log "INFO" "TARGET_USER=${TARGET_USER}"
    fi
    
    check_systemd
    
    local target_user
    target_user=$(get_target_user)
    
    echo "⚠️  修复前说明:"
    echo "• 脚本会开启用户linger持久化"
    echo "• 需要root权限（会自动提权）"
    echo "• 确保当前用户有sudo权限"
    echo "• 修复后建议重新连接服务器"
    echo
    
    if [[ "${AUTO_ACCEPT}" != "1" ]]; then
        confirm "继续执行修复？"
    fi
    
    enable_linger "$target_user"
    verify_user_environment "$target_user"
    show_completion_guide "$target_user"
}

# ==================== 脚本入口点 ====================
# 检查是否通过curl执行
if [[ -n "${CURL_EXECUTION:-}" ]] || [[ "$(basename "$0")" == "bash" ]]; then
    case "${1:-}" in
        "-h"|"--help")
            echo "OpenClaw Gateway 修复脚本 v${SCRIPT_VERSION}"
            echo
            echo "用法: curl -fsSL $SCRIPT_URL | bash [选项]"
            echo
            echo "环境变量:"
            echo "  DEBUG=1              启用调试模式"
            echo "  AUTO_ACCEPT=1        自动确认所有提示"
            echo "  TARGET_USER=<name>   指定目标用户名"
            echo
            echo "示例:"
            echo "  curl -fsSL $SCRIPT_URL | bash"
            echo "  DEBUG=1 curl -fsSL $SCRIPT_URL | bash"
            echo "  TARGET_USER=ubuntu curl -fsSL $SCRIPT_URL | bash"
            echo "  AUTO_ACCEPT=1 TARGET_USER=app curl -fsSL $SCRIPT_URL | bash"
            echo
            exit 0
            ;;
    esac
    
    export CURL_EXECUTION=1
    main "$@"
else
    error_exit "此脚本应通过 curl 执行: curl -fsSL $SCRIPT_URL | bash"
fi