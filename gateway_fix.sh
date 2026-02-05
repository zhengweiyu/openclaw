#!/bin/bash

# OpenClaw Gateway 修复脚本
# 版本: 1.0
# 使用方法: curl -fsSL https://raw.githubusercontent.com/zhengweiyu/openclaw/main/gateway_fix.sh | bash

set -euo pipefail

# ==================== 配置 ====================
readonly SCRIPT_VERSION="1.0"
readonly SCRIPT_URL="https://raw.githubusercontent.com/zhengweiyu/openclaw/main/gateway_fix.sh"

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# 全局配置
readonly DEBUG="${DEBUG:-0}"
readonly AUTO_ACCEPT="${AUTO_ACCEPT:-0}"
readonly TARGET_USER="${TARGET_USER:-}"

# 日志函数
log() {
    local level="$1"
    shift
    local message="$*"
    
    case "$level" in
        "INFO")
            echo -e "${GREEN}[INFO]${NC} $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" >&2
            ;;
        "DEBUG")
            [[ "${DEBUG}" == "1" ]] && echo -e "${CYAN}[DEBUG]${NC} $message"
            ;;
    esac
}

# 错误处理函数
error_exit() {
    log "ERROR" "$1"
    exit "${2:-1}"
}

# 确认对话框（非交互模式下跳过）
confirm() {
    local message="$1"
    local default="${2:-n}"
    
    if [[ "${AUTO_ACCEPT}" == "1" ]]; then
        log "INFO" "自动确认: $message"
        return 0
    fi
    
    local response
    if [[ "$default" == "y" ]]; then
        read -p "$message [Y/n]: " -r response
        response="${response:-y}"
    else
        read -p "$message [y/N]: " -r response
        response="${response:-n}"
    fi
    
    case "$response" in
        [Yy]|[Yy][Ee][Ss]) return 0 ;;
        *) return 1 ;;
    esac
}

# 等待用户按键（非交互模式下跳过）
wait_for_key() {
    if [[ "${AUTO_ACCEPT}" == "1" ]]; then
        log "INFO" "跳过用户交互，继续执行..."
        return
    fi
    
    log "INFO" "按任意键继续（Ctrl+C退出）..."
    read -n 1 -s -r
    echo
}

# 显示横幅
show_banner() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${PURPLE}  Gateway 修复脚本 v${SCRIPT_VERSION}${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
    echo -e "${CYAN}🔧 修复 systemd 用户服务问题${NC}"
    echo
    echo -e "${YELLOW}⚡ 解决问题:${NC}"
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
        # 自动模式下使用当前用户
        user_input=$(whoami)
        log "INFO" "自动模式，使用当前用户: $user_input"
    else
        read -p "请输入需要修复的目标用户名（默认: $(whoami)）: " -r user_input
        user_input="${user_input:-$(whoami)}"
    fi
    
    # 验证用户是否存在
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
        if ! sudo bash -c "
            loginctl enable-linger $target_user && \
            echo '✅ linger已开启' && \
            loginctl show-user $target_user | grep Linger && \
            systemctl daemon-reload && \
            echo '✅ 系统级systemd已重载'
        "; then
            error_exit "root操作失败，请手动执行 loginctl enable-linger $target_user"
        fi
    else
        # 已为root直接执行
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
    
    # 用sudo -iu切换（保证完整登录环境），执行验证逻辑
    sudo -iu "$target_user" bash -c "
        echo '当前用户：' && whoami
        
        echo -e '\n[验证XDG_RUNTIME_DIR环境变量]'
        if [[ -n \$XDG_RUNTIME_DIR ]]; then
            echo '✅ XDG_RUNTIME_DIR已存在：' \$XDG_RUNTIME_DIR
            ls -ld \$XDG_RUNTIME_DIR || echo '⚠️ 目录存在但无法访问'
        else
            echo '⚠️ XDG_RUNTIME_DIR缺失，手动创建修复...'
            mkdir -p /run/user/$target_uid
            chmod 700 /run/user/$target_uid
            chown -R $target_user:$target_user /run/user/$target_uid
            export XDG_RUNTIME_DIR=/run/user/$target_uid
            echo '✅ 已手动创建：' \$XDG_RUNTIME_DIR
        fi
        
        echo -e '\n[验证用户级systemd总线]'
        if systemctl --user status &> /dev/null; then
            echo '✅ 用户级systemd总线连通成功！'
            systemctl --user status | head -3
        else
            echo '[错误] 用户级systemd总线仍不通，请检查系统配置！'
            exit 1
        fi
        
        echo -e '\n[执行用户级daemon-reload]'
        systemctl --user daemon-reload
        echo '✅ daemon-reload执行成功！'
    "
}

# 显示最终结果
show_completion_guide() {
    local target_user="$1"
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}        🎉 Gateway 修复完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo -e "${CYAN}📋 验证结果:${NC}"
    echo "1. Linger状态验证："
    sudo loginctl show-user "$target_user" | grep Linger
    echo
    echo -e "${CYAN}🚀 建议操作:${NC}"
    echo "   - 退出当前终端，重新连接服务器（确保环境完全加载）"
    echo "   - 重新启动Gateway服务："
    echo "     sudo -iu $target_user systemctl --user restart gateway"
    echo "   - 查看Gateway日志："
    echo "     sudo -iu $target_user journalctl --user -u gateway -f"
    echo
    echo -e "${CYAN}🔧 常用命令:${NC}"
    echo "   查看用户服务状态：sudo -iu $target_user systemctl --user status"
    echo "   启用用户服务：sudo -iu $target_user systemctl --user enable gateway"
    echo "   禁用用户服务：sudo -iu $target_user systemctl --user disable gateway"
    echo
    echo -e "${GREEN}✨ Gateway 服务问题已修复！${NC}"
    echo
}

# 主修复函数
main() {
    # 显示横幅
    show_banner
    
    # 环境变量说明
    if [[ "${DEBUG}" == "1" ]]; then
        log "INFO" "调试模式已启用"
        log "INFO" "AUTO_ACCEPT=${AUTO_ACCEPT}"
        log "INFO" "TARGET_USER=${TARGET_USER}"
    fi
    
    # 检查系统
    check_systemd
    
    # 获取目标用户
    local target_user
    target_user=$(get_target_user)
    
    # 显示注意事项
    echo -e "${YELLOW}⚠️  修复前说明:${NC}"
    echo "• 脚本会开启用户linger持久化"
    echo "• 需要root权限（会自动提权）"
    echo "• 确保当前用户有sudo权限"
    echo "• 修复后建议重新连接服务器"
    echo
    
    wait_for_key
    
    # 执行修复步骤
    enable_linger "$target_user"
    verify_user_environment "$target_user"
    
    # 显示完成指南
    show_completion_guide "$target_user"
}

# ==================== 脚本入口点 ====================

# 检查是否通过curl执行
if [[ -n "${CURL_EXECUTION:-}" ]]; then
    # 处理命令行参数
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
    
    # 标记curl执行
    export CURL_EXECUTION=1
    
    # 执行主函数
    main "$@"
else
    log "ERROR" "此脚本应通过 curl 执行: curl -fsSL $SCRIPT_URL | bash"
    exit 1
fi