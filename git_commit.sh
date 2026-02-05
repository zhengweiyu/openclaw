#!/bin/bash

# OpenClaw Git 提交脚本
# 版本: 2.0
# 描述: 统一的 Git 提交工具，支持完整和快速两种模式

set -euo pipefail

# ==================== 颜色定义 ====================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# 全局配置
readonly COMMIT_TYPE="${COMMIT_TYPE:-feat}"
readonly COMMIT_SCOPE="${COMMIT_SCOPE:-deploy}"
readonly AUTO_PUSH="${AUTO_PUSH:-0}"
readonly CREATE_BRANCH="${CREATE_BRANCH:-1}"

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
            [[ "${DEBUG:-0}" == "1" ]] && echo -e "${CYAN}[DEBUG]${NC} $message"
            ;;
    esac
}

# 错误处理函数
error_exit() {
    log "ERROR" "$1"
    exit "${2:-1}"
}

# 确认对话框
confirm() {
    local message="$1"
    local default="${2:-n}"
    local response
    
    if [[ "${AUTO_ACCEPT:-0}" == "1" ]]; then
        log "INFO" "自动确认: $message"
        return 0
    fi
    
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

# 显示横幅
show_banner() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}    OpenClaw Git 提交脚本 v2.0${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
    echo -e "${CYAN}🚀 模式选择:${NC}"
    echo "• 完整模式: 交互式提交，创建分支，推送到远程"
    echo "• 快速模式: 直接提交当前更改"
    echo
}

# 检查 Git 仓库状态
check_git_status() {
    log "INFO" "检查 Git 仓库状态..."
    
    if [[ ! -d ".git" ]]; then
        error_exit "当前目录不是 Git 仓库"
    fi
    
    # 检查是否有未提交的更改
    if [[ -n $(git status --porcelain) ]]; then
        log "INFO" "发现未提交的更改"
        git status --short
        return 0
    else
        log "WARN" "没有发现未提交的更改"
        return 1
    fi
}

# 显示更改详情
show_changes() {
    log "INFO" "显示更改详情..."
    echo
    echo -e "${YELLOW}修改的文件:${NC}"
    git diff --name-only
    echo
    
    echo -e "${YELLOW}文件更改统计:${NC}"
    git diff --stat
    echo
    
    if confirm "是否查看详细更改？" "n"; then
        git diff
    fi
}

# 生成提交信息
generate_commit_message() {
    local mode="$1"
    
    if [[ "$mode" == "quick" ]]; then
        echo "feat: 快速提交当前更改

- 快速提交未暂存的文件
- 包含所有修改和新增的文件
- 自动生成提交信息

文件列表:
$(git status --porcelain | sed 's/^/- /')"
    else
        cat << 'EOF'
feat: 更新 OpenClaw 部署和文档

- 优化安装脚本和配置
- 更新用户文档和使用指南
- 完善安全特性和最佳实践
- 添加多LLM提供商支持

影响文件:
- 安装脚本: online_install.sh
- 文档: README.md
- 工具: git_commit.sh
EOF
    fi
}

# 创建功能分支（完整模式）
create_branch() {
    local branch_name="$1"
    local current_branch
    current_branch=$(git branch --show-current)
    
    if [[ "$current_branch" == "$branch_name" ]]; then
        log "INFO" "已在目标分支: $branch_name"
        return
    fi
    
    log "INFO" "创建功能分支: $branch_name"
    if git checkout -b "$branch_name"; then
        log "INFO" "分支创建成功"
    else
        log "WARN" "分支可能已存在，尝试切换..."
        git checkout "$branch_name" || log "ERROR" "无法切换到分支 $branch_name"
    fi
}

# 添加文件到暂存区
stage_files() {
    log "INFO" "添加文件到暂存区..."
    
    # 自动检测修改的文件
    local modified_files
    modified_files=$(git status --porcelain | awk '{print $2}')
    
    if [[ -n "$modified_files" ]]; then
        echo "$modified_files" | xargs git add
        log "INFO" "已添加所有修改的文件"
    else
        log "WARN" "没有文件需要添加"
    fi
    
    # 显示暂存状态
    echo
    log "INFO" "暂存区状态:"
    git status --short
}

# 确认提交
confirm_commit() {
    local commit_message="$1"
    log "INFO" "提交信息预览:"
    echo
    echo -e "${YELLOW}$commit_message${NC}"
    echo
    
    if confirm "确认提交这些更改？" "y"; then
        return 0
    else
        log "WARN" "用户取消提交"
        return 1
    fi
}

# 执行提交
perform_commit() {
    local commit_message="$1"
    log "INFO" "执行 Git 提交..."
    
    if git commit -m "$commit_message"; then
        log "INFO" "提交成功！"
        echo
        git log --oneline -1
        echo
        return 0
    else
        log "ERROR" "提交失败"
        return 1
    fi
}

# 推送到远程仓库
push_to_remote() {
    local branch_name="$1"
    
    # 检查是否有远程仓库
    if ! git remote get-url origin &>/dev/null; then
        log "WARN" "没有配置远程仓库 origin"
        return
    fi
    
    log "INFO" "推送到远程仓库..."
    
    if confirm "是否推送到远程仓库？" "${AUTO_PUSH}"; then
        if git push -u origin "$branch_name"; then
            log "INFO" "推送成功！"
            echo
            log "INFO" "创建 Pull Request 命令:"
            echo "gh pr create --title 'OpenClaw 更新' --body '请查看详细的更改说明'"
            echo
        else
            log "ERROR" "推送失败"
            return 1
        fi
    else
        log "INFO" "跳过推送"
    fi
}

# 完整提交流程
full_commit_workflow() {
    local commit_message
    commit_message=$(generate_commit_message "full")
    local branch_name="feature/update-$(date +%Y%m%d-%H%M%S)"
    
    if [[ "${CREATE_BRANCH}" == "1" ]]; then
        create_branch "$branch_name"
    fi
    
    stage_files
    confirm_commit "$commit_message" || return 1
    perform_commit "$commit_message" || return 1
    push_to_remote "${branch_name}"
    
    show_next_steps "${branch_name}"
}

# 快速提交流程
quick_commit_workflow() {
    local commit_message
    commit_message=$(generate_commit_message "quick")
    
    # 直接在当前分支提交
    stage_files
    perform_commit "$commit_message" || return 1
    
    # 询问是否推送
    if [[ "${AUTO_PUSH}" == "1" ]] || confirm "是否推送到远程仓库？" "n"; then
        local current_branch
        current_branch=$(git branch --show-current)
        git push origin "$current_branch" && log "INFO" "推送成功！"
    fi
    
    echo
    echo -e "${GREEN}✅ 快速提交完成！${NC}"
}

# 显示后续步骤
show_next_steps() {
    local branch_name="$1"
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}        完整提交完成！后续操作${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo -e "${BLUE}🚀 推送到远程仓库:${NC}"
    echo "git push -u origin $branch_name"
    echo
    echo -e "${BLUE}📝 创建 Pull Request:${NC}"
    echo "gh pr create --title 'OpenClaw 更新' --body '请查看详细的更改说明'"
    echo
    echo -e "${BLUE}🔀 切换回主分支:${NC}"
    echo "git checkout main"
    echo
    echo -e "${BLUE}🧹 清理功能分支（合并后）:${NC}"
    echo "git branch -d $branch_name"
    echo "git push origin --delete $branch_name"
    echo
    echo -e "${BLUE}📊 查看提交历史:${NC}"
    echo "git log --oneline -5"
    echo
}

# 清理工作
cleanup() {
    log "INFO" "清理临时文件..."
    
    # 清理任何临时文件
    find . -name "*.tmp" -type f -delete 2>/dev/null || true
    find . -name "*.log" -type f -delete 2>/dev/null || true
    
    log "INFO" "清理完成"
}

# 显示使用帮助
show_help() {
    cat << EOF
OpenClaw Git 提交脚本 v2.0

用法: $0 [选项] [模式]

模式:
  full           完整模式 (默认) - 创建分支，交互式提交
  quick          快速模式 - 直接提交当前更改

选项:
  -h, --help     显示此帮助信息
  --auto-push    自动推送到远程仓库
  --no-branch    不创建新分支 (完整模式)
  --auto-accept  自动确认所有提示
  --debug        启用调试模式

环境变量:
  AUTO_PUSH=1    自动推送
  CREATE_BRANCH=0 跳过分支创建
  AUTO_ACCEPT=1  自动确认
  DEBUG=1        启用调试

示例:
  $0                    # 完整模式
  $0 quick              # 快速模式
  $0 --auto-push quick  # 快速模式 + 自动推送
  AUTO_ACCEPT=1 $0 quick # 无交互快速提交

文件添加规则:
  - 自动检测修改的文件
  - 支持手动指定文件: $0 --files file1 file2
EOF
}

# 解析命令行参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --auto-push)
                export AUTO_PUSH=1
                ;;
            --no-branch)
                export CREATE_BRANCH=0
                ;;
            --auto-accept)
                export AUTO_ACCEPT=1
                ;;
            --debug)
                export DEBUG=1
                ;;
            full)
                MODE="full"
                ;;
            quick)
                MODE="quick"
                ;;
            *)
                log "ERROR" "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

# ==================== 主函数 ====================
main() {
    # 默认模式
    local MODE="${MODE:-full}"
    
    # 解析参数
    parse_arguments "$@"
    
    # 显示横幅
    show_banner
    
    # 检查Git状态
    if ! check_git_status; then
        exit 0
    fi
    
    # 显示更改详情
    if [[ "${AUTO_ACCEPT:-0}" != "1" ]]; then
        show_changes
    fi
    
    # 确认继续
    if ! confirm "继续执行提交流程？" "y"; then
        log "INFO" "用户取消操作"
        exit 0
    fi
    
    # 执行相应的工作流
    case "$MODE" in
        "full")
            full_commit_workflow
            ;;
        "quick")
            quick_commit_workflow
            ;;
        *)
            error_exit "未知模式: $MODE"
            ;;
    esac
    
    # 清理
    cleanup
    
    echo
    log "INFO" "脚本执行完成！"
}

# ==================== 脚本入口点 ====================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi