#!/bin/bash

# OpenClaw 安全安装脚本
# 版本: 2.1
# 使用方法: curl -fsSL https://raw.githubusercontent.com/zhengweiyu/openclaw/main/openclaw_secure_install.sh | bash

set -euo pipefail

# ==================== 配置 ====================
readonly SCRIPT_VERSION="2.1"
readonly SCRIPT_URL="https://raw.githubusercontent.com/zhengweiyu/openclaw/main/openclaw_secure_install.sh"

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
    
    # 尝试写入日志文件（如果可能）
    local log_file="/tmp/openclaw_install_$(date +%s).log"
    echo "[$timestamp] [$level] $message" >> "$log_file" 2>/dev/null || true
}

# 错误处理函数
error_exit() {
    log "ERROR" "$1"
    log "ERROR" "安装失败，请查看文档: https://openclaw.ai/docs"
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
    echo -e "${PURPLE}  OpenClaw 安全安装 v${SCRIPT_VERSION}${NC}"
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

# 安装系统依赖
install_dependencies() {
    local os="$1"
    log "INFO" "安装系统依赖..."
    
    case "$os" in
        "macos")
            install_homebrew
            brew update
            brew install curl wget git
            ;;
        "ubuntu")
            log "INFO" "更新系统包..."
            sudo apt update && sudo apt upgrade -y
            
            log "INFO" "安装基础工具..."
            sudo apt install -y curl wget git ufw unattended-upgrades
            
            # 配置自动安全更新
            echo 'unattended-upgrades unattended-upgrades/enable_auto_updates boolean true' | sudo debconf-set-selections
            sudo dpkg-reconfigure -f noninteractive unattended-upgrades
            ;;
    esac
    
    log "INFO" "系统依赖安装完成"
}

# 安装Homebrew（macOS）
install_homebrew() {
    if command_exists brew; then
        log "INFO" "Homebrew已安装"
        return
    fi
    
    log "INFO" "正在安装Homebrew..."
    if ! /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        error_exit "Homebrew安装失败"
    fi
    
    # 添加到PATH
    if [[ -d "/opt/homebrew/bin" ]]; then
        export PATH="/opt/homebrew/bin:$PATH"
        echo 'export PATH="/opt/homebrew/bin:$PATH"' >> "$HOME/.zshrc"
    fi
    
    log "INFO" "Homebrew安装完成"
}

# 配置Tailscale和防火墙
configure_network_security() {
    local os="$1"
    
    if [[ "${SKIP_TAILSCALE}" == "1" ]]; then
        log "INFO" "跳过Tailscale配置（SKIP_TAILSCALE=1）"
        return
    fi
    
    log "INFO" "配置网络安全..."
    
    # 安装Tailscale
    if ! command_exists tailscale; then
        log "INFO" "正在安装Tailscale..."
        if ! curl -fsSL https://tailscale.com/install.sh | sh; then
            log "WARN" "Tailscale安装失败，请手动安装"
        fi
        
        if command_exists tailscale; then
            log "INFO" "Tailscale安装成功，请手动完成授权："
            echo "sudo tailscale up"
            echo "复制URL到浏览器完成授权"
            
            if ! confirm "是否已完成Tailscale授权？" "n"; then
                log "WARN" "跳过Tailscale配置，可稍后手动完成"
            fi
        fi
    else
        log "INFO" "Tailscale已安装"
    fi
    
    # 配置防火墙
    configure_firewall "$os"
}

# 配置防火墙
configure_firewall() {
    local os="$1"
    log "INFO" "配置防火墙规则..."
    
    case "$os" in
        "macos")
            log "INFO" "macOS防火墙配置（请确保系统防火墙已启用）"
            ;;
        "ubuntu")
            # 重置防火墙规则
            sudo ufw --force reset
            
            # 设置默认策略
            sudo ufw default deny incoming
            sudo ufw default allow outgoing
            
            # 允许Tailscale网络访问SSH（如果Tailscale已安装）
            if command_exists tailscale && ip link show tailscale0 &> /dev/null; then
                sudo ufw allow in on tailscale0 to any port 22
            fi
            
            # 启用防火墙
            sudo ufw --force enable
            sudo ufw --force status
            ;;
    esac
    
    log "INFO" "防火墙配置完成"
}

# 安装Node.js
install_nodejs() {
    log "INFO" "安装Node.js 24..."
    
    # 安装nvm
    if ! command_exists nvm; then
        log "INFO" "安装nvm..."
        if ! curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash; then
            error_exit "nvm安装失败"
        fi
        
        # 加载nvm环境
        export NVM_DIR="${XDG_CONFIG_HOME:-$HOME/.nvm}"
        if [[ -s "$NVM_DIR/nvm.sh" ]]; then
            # shellcheck source=/dev/null
            source "$NVM_DIR/nvm.sh"
        fi
    fi
    
    # 安装Node.js
    if command_exists nvm; then
        nvm install 24 || error_exit "Node.js安装失败"
        nvm use 24
        nvm alias default 24
        
        local node_version
        node_version=$(node --version)
        log "INFO" "Node.js安装成功: $node_version"
    else
        error_exit "nvm安装失败"
    fi
}

# 安装OpenClaw
install_openclaw() {
    log "INFO" "安装OpenClaw..."
    
    if command_exists openclaw; then
        log "INFO" "OpenClaw已安装"
        return
    fi
    
    # 尝试从npm安装
    if npm install -g @openclaw/cli 2>/dev/null; then
        log "INFO" "从npm安装OpenClaw成功"
    elif curl -fsSL https://openclaw.ai/install.sh | bash; then
        log "INFO" "从官方脚本安装OpenClaw成功"
    else
        error_exit "OpenClaw安装失败"
    fi
    
    # 验证安装
    if ! command_exists openclaw; then
        local npm_global_path="$HOME/.npm-global/bin"
        if [[ -d "$npm_global_path" ]]; then
            export PATH="$npm_global_path:$PATH"
            echo "export PATH=\"$npm_global_path:\$PATH\"" >> "$HOME/.bashrc" "$HOME/.zshrc" 2>/dev/null || true
        fi
    fi
    
    if command_exists openclaw; then
        local version
        version=$(openclaw --version 2>/dev/null || echo "unknown")
        log "INFO" "OpenClaw安装成功: $version"
    else
        error_exit "OpenClaw验证失败"
    fi
}

# 初始化OpenClaw
initialize_openclaw() {
    log "INFO" "初始化OpenClaw..."
    
    # 显示LLM提供商选择信息
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
    
    if [[ "${AUTO_ACCEPT}" == "1" ]]; then
        log "INFO" "跳过交互式初始化"
        log "INFO" "请稍后手动执行: openclaw onboard"
        return
    fi
    
    if confirm "是否现在配置LLM提供商？" "y"; then
        if openclaw onboard; then
            log "INFO" "OpenClaw初始化完成"
        else
            log "WARN" "初始化失败，可稍后手动执行: openclaw onboard"
        fi
    else
        log "INFO" "跳过初始化，可稍后执行: openclaw onboard"
    fi
}

# 安装插件和配置安全
install_plugins_security() {
    log "INFO" "安装插件和安全配置..."
    
    # 安装Matrix插件
    if command_exists openclaw; then
        log "INFO" "安装Matrix插件..."
        if openclaw plugins install @openclaw/matrix 2>/dev/null; then
            log "INFO" "Matrix插件安装成功"
        else
            log "WARN" "Matrix插件安装失败，可稍后手动安装"
        fi
        
        # 安装安全技能
        log "INFO" "安装安全防护技能..."
        
        # 尝试安装各种安全技能
        for skill in "skillguard" "prompt-guard"; do
            if npx clawhub install "$skill" 2>/dev/null; then
                log "INFO" "安全技能 $skill 安装成功"
            else
                log "WARN" "安全技能 $skill 安装失败"
            fi
        done
        
        # ACIP认知免疫
        if openclaw skill install https://github.com/Dicklesworthstone/acip/tree/main 2>/dev/null; then
            log "INFO" "ACIP认知免疫安装成功"
        else
            log "WARN" "ACIP认知免疫安装失败"
        fi
    fi
    
    # 设置文件权限
    if [[ -d "$HOME/.openclaw" ]]; then
        chmod 700 "$HOME/.openclaw"
        find "$HOME/.openclaw" -name "*.json" -type f -exec chmod 600 {} \; 2>/dev/null || true
        find "$HOME/.openclaw" -name "*.key" -type f -exec chmod 600 {} \; 2>/dev/null || true
        log "INFO" "文件权限设置完成"
    fi
    
    # 禁用mDNS
    local shell_config
    if [[ -f "$HOME/.zshrc" ]]; then
        shell_config="$HOME/.zshrc"
    else
        shell_config="$HOME/.bashrc"
    fi
    
    if ! grep -q "OPENCLAW_DISABLE_BONJOUR" "$shell_config" 2>/dev/null; then
        echo 'export OPENCLAW_DISABLE_BONJOUR=1' >> "$shell_config"
    fi
    
    export OPENCLAW_DISABLE_BONJOUR=1
    log "INFO" "安全配置完成"
}

# 创建系统服务
create_service() {
    local os="$1"
    log "INFO" "创建系统服务..."
    
    local openclaw_path
    openclaw_path=$(which openclaw)
    local log_dir="$HOME/.openclaw/logs"
    
    mkdir -p "$log_dir"
    
    case "$os" in
        "macos")
            local plist_file="$HOME/Library/LaunchAgents/com.openclaw.ai.plist"
            
            cat > "$plist_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.openclaw.ai</string>
  <key>ProgramArguments</key>
  <array>
    <string>$openclaw_path</string>
    <string>start</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <dict>
    <key>SuccessfulExit</key>
    <false/>
  </dict>
  <key>StandardOutPath</key>
  <string>$log_dir/stdout.log</string>
  <key>StandardErrorPath</key>
  <string>$log_dir/stderr.log</string>
  <key>WorkingDirectory</key>
  <string>$HOME</string>
</dict>
</plist>
EOF
            
            launchctl load "$plist_file" 2>/dev/null || log "WARN" "服务加载失败"
            launchctl start com.openclaw.ai 2>/dev/null || log "WARN" "服务启动失败"
            ;;
            
        "ubuntu")
            local service_file="/etc/systemd/system/openclaw.service"
            
            sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=OpenClaw AI Assistant (Secure Deployment)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$HOME
ExecStart=$openclaw_path start
Restart=on-failure
RestartSec=10
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=$HOME/.openclaw
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
            
            sudo systemctl daemon-reload 2>/dev/null || log "WARN" "服务重载失败"
            sudo systemctl enable openclaw 2>/dev/null || log "WARN" "服务启用失败"
            sudo systemctl start openclaw 2>/dev/null || log "WARN" "服务启动失败"
            ;;
    esac
    
    log "INFO" "系统服务配置完成"
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
    
    wait_for_key
    
    # 执行安装步骤
    install_dependencies "$os"
    configure_network_security "$os"
    install_nodejs
    install_openclaw
    initialize_openclaw
    install_plugins_security
    create_service "$os"
    
    # 显示完成指南
    show_completion_guide "$os"
}

# ==================== 脚本入口点 ====================
# 检查是否通过curl执行
if [[ -n "${CURL_EXECUTION:-}" ]] || [[ "$(basename "$0")" == "bash" ]]; then
    # 处理命令行参数
    case "${1:-}" in
        "-h"|"--help")
            echo "OpenClaw 安全安装脚本 v${SCRIPT_VERSION}"
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