#!/bin/bash

# OpenClaw 在线一键安装脚本
# 版本: 2.0
# 使用方法: curl -fsSL https://raw.githubusercontent.com/zhengweiyu/openclaw/main/online_install.sh | bash

set -euo pipefail

# ==================== 配置 ====================
readonly SCRIPT_VERSION="2.0"
readonly SCRIPT_URL="https://raw.githubusercontent.com/zhengweiyu/openclaw/main/online_install.sh"

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
readonly SKIP_TAILSCALE="${SKIP_TAILSCALE:-0}"
readonly LLM_PROVIDER="${LLM_PROVIDER:-minimax}"
readonly INSTALL_DIR="${INSTALL_DIR:-$HOME/.openclaw}"

# 日志函数
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
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

# 检查命令是否存在
command_exists() {
    command -v "$1" &> /dev/null
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
    echo -e "${PURPLE}  OpenClaw 在线一键安装 v${SCRIPT_VERSION}${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
    echo -e "${CYAN}🚀 AI 助手 | 🔒 安全部署 | 🌐 跨平台支持${NC}"
    echo
    echo -e "${YELLOW}⚡ 支持的提供商: MiniMax | Claude | GPT${NC}"
    echo -e "${YELLOW}🔧 系统支持: macOS | Ubuntu 20.04+${NC}"
    echo
}

# 检测系统
detect_system() {
    local uname_s
    uname_s="$(uname -s)"
    local os="unknown"
    
    case "$uname_s" in
        "Darwin")
            os="macos"
            log "INFO" "检测到系统: macOS"
            ;;
        "Linux")
            if [[ -f "/etc/lsb-release" ]]; then
                local ubuntu_version
                ubuntu_version=$(grep "DISTRIB_RELEASE" /etc/lsb-release | cut -d'=' -f2)
                if [[ $(echo "$ubuntu_version" | cut -d'.' -f1) -lt 20 ]]; then
                    error_exit "不支持的Ubuntu版本：$ubuntu_version（需要20.04+）"
                fi
                os="ubuntu"
                log "INFO" "检测到系统: Ubuntu $ubuntu_version"
            else
                error_exit "不支持的Linux发行版（仅适配Ubuntu 20.04+）"
            fi
            ;;
        *)
            error_exit "不支持的系统：$uname_s（仅适配macOS和Ubuntu）"
            ;;
    esac
    
    echo "$os"
}

# 检查前置条件
check_prerequisites() {
    log "INFO" "检查前置条件..."
    
    # 检查网络连接
    log "INFO" "检查网络连接..."
    if ! curl -s --connect-timeout 5 https://api.minimax.chat &> /dev/null; then
        log "WARN" "网络连接异常，可能会影响安装过程"
    fi
    
    # 检查磁盘空间（至少需要2GB）
    local available_space
    available_space=$(df . | awk 'NR==2 {print $4}')
    local required_space=2097152  # 2GB in KB
    
    if [[ $available_space -lt $required_space ]]; then
        error_exit "磁盘空间不足，至少需要2GB可用空间"
    fi
    
    log "INFO" "前置条件检查通过"
}

# 显示LLM提供商信息
show_llm_provider_info() {
    echo
    log "INFO" "选择LLM提供商: ${LLM_PROVIDER}"
    case "${LLM_PROVIDER}" in
        "minimax")
            echo "📝 MiniMax 注册地址: https://api.minimax.chat/"
            echo "🔑 需要准备: Group ID 和 API Key"
            ;;
        "claude")
            echo "📝 Claude 注册地址: https://console.anthropic.com/"
            echo "🔑 需要准备: API Key"
            ;;
        "gpt")
            echo "📝 OpenAI 注册地址: https://platform.openai.com/"
            echo "🔑 需要准备: API Key"
            ;;
    esac
    echo
}

# 主安装函数
main() {
    # 显示横幅
    show_banner
    
    # 环境变量说明
    if [[ "${DEBUG}" == "1" ]]; then
        log "INFO" "调试模式已启用"
        log "INFO" "AUTO_ACCEPT=${AUTO_ACCEPT}"
        log "INFO" "SKIP_TAILSCALE=${SKIP_TAILSCALE}"
        log "INFO" "LLM_PROVIDER=${LLM_PROVIDER}"
    fi
    
    # 检测系统
    local os
    os=$(detect_system)
    
    # 检查前置条件
    check_prerequisites
    
    # 显示注意事项
    echo -e "${YELLOW}⚠️  安装前准备:${NC}"
    echo "• 确保有稳定的网络连接"
    echo "• 准备LLM提供商的API密钥"
    echo "• 确保有管理员权限"
    echo
    
    # 显示LLM提供商信息
    show_llm_provider_info
    
    wait_for_key
    
    # 下载并执行本地安装脚本
    log "INFO" "下载本地安装脚本..."
    local install_script_url="https://raw.githubusercontent.com/zhengweiyu/openclaw/main/openclaw_secure_install.sh"
    
    if ! curl -fsSL "$install_script_url" | bash -s -- --online-mode --llm-provider "${LLM_PROVIDER}"; then
        error_exit "安装脚本下载或执行失败"
    fi
    
    # 显示完成指南
    show_completion_guide "$os"
}

# 显示完成指南
show_completion_guide() {
    local os="$1"
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}        🎉 OpenClaw 安装完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo -e "${CYAN}🚀 快速开始:${NC}"
    echo "1. 启动网关: openclaw gateway"
    echo "2. 访问控制台: http://localhost:18789"
    echo "3. 配置LLM提供商: openclaw onboard"
    echo
    echo -e "${CYAN}🔧 服务管理:${NC}"
    case "$os" in
        "macos")
            echo "启动: launchctl start com.openclaw.ai"
            echo "停止: launchctl stop com.openclaw.ai"
            echo "日志: tail -f ~/.openclaw/logs/stdout.log"
            ;;
        "ubuntu")
            echo "启动: sudo systemctl start openclaw"
            echo "停止: sudo systemctl stop openclaw"
            echo "日志: journalctl -u openclaw -f"
            ;;
    esac
    echo
    echo -e "${CYAN}📚 文档和支持:${NC}"
    echo "• 官方文档: https://openclaw.ai/docs"
    echo "• 社区支持: https://community.openclaw.ai"
    echo "• GitHub仓库: https://github.com/zhengweiyu/openclaw"
    echo
    echo -e "${GREEN}✨ 感谢使用 OpenClaw！${NC}"
    echo
}

# ==================== 脚本入口点 ====================
# 检查是否通过curl执行
if [[ "${BASH_SOURCE[0]}" != "${0}" ]] || [[ -n "${CURL_EXECUTION:-}" ]]; then
    # 处理命令行参数
    case "${1:-}" in
        "-h"|"--help")
            echo "OpenClaw 在线一键安装脚本 v${SCRIPT_VERSION}"
            echo
            echo "用法: curl -fsSL $SCRIPT_URL | bash [选项]"
            echo
            echo "环境变量:"
            echo "  DEBUG=1              启用调试模式"
            echo "  AUTO_ACCEPT=1        自动确认所有提示"
            echo "  SKIP_TAILSCALE=1     跳过Tailscale安装"
            echo "  LLM_PROVIDER=<name>  LLM提供商 (minimax/claude/gpt)"
            echo
            echo "示例:"
            echo "  curl -fsSL $SCRIPT_URL | bash"
            echo "  DEBUG=1 curl -fsSL $SCRIPT_URL | bash"
            echo "  AUTO_ACCEPT=1 curl -fsSL $SCRIPT_URL | bash"
            echo "  LLM_PROVIDER=claude curl -fsSL $SCRIPT_URL | bash"
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