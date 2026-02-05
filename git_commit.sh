#!/bin/bash

# Git 提交脚本 - OpenClaw LLM 提供商更换
# 版本: 1.0
# 描述: 将 OpenClaw 部署脚本中的 LLM 提供商从 Venice AI 更换为 MiniMax

set -euo pipefail

# ==================== 颜色定义 ====================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

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
    esac
}

# ==================== 配置 ====================
readonly COMMIT_TYPE="feat"
readonly COMMIT_SCOPE="deploy"
readonly COMMIT_MESSAGE="feat: 更换 LLM 提供商为 MiniMax

- 将部署脚本中的 Venice AI 替换为 MiniMax
- 更新初始化流程和配置说明
- 添加 MiniMax 官网地址和注册链接
- 完善文档中的 API 密钥配置指南
- 更新安全维护建议

影响文件:
- openclaw_secure_install.sh: 核心部署脚本
- README.md: 用户文档和配置指南"

readonly BRANCH_NAME="feature/minimax-provider"

# ==================== 函数定义 ====================

# 检查 Git 仓库状态
check_git_status() {
    log "INFO" "检查 Git 仓库状态..."
    
    if [[ ! -d ".git" ]]; then
        log "ERROR" "当前目录不是 Git 仓库"
        exit 1
    fi
    
    # 检查是否有未提交的更改
    if [[ -n $(git status --porcelain) ]]; then
        log "INFO" "发现未提交的更改"
        git status --short
    else
        log "WARN" "没有发现未提交的更改"
        exit 0
    fi
}

# 显示更改详情
show_changes() {
    log "INFO" "显示更改详情..."
    echo
    git diff --name-only
    echo
    
    log "INFO" "文件更改统计:"
    git diff --stat
    echo
    
    if confirm "是否查看详细更改？" "n"; then
        git diff
    fi
}

# 创建功能分支
create_branch() {
    local current_branch
    current_branch=$(git branch --show-current)
    
    if [[ "$current_branch" == "$BRANCH_NAME" ]]; then
        log "INFO" "已在目标分支: $BRANCH_NAME"
        return
    fi
    
    log "INFO" "创建功能分支: $BRANCH_NAME"
    if git checkout -b "$BRANCH_NAME"; then
        log "INFO" "分支创建成功"
    else
        log "WARN" "分支可能已存在，尝试切换..."
        git checkout "$BRANCH_NAME" || log "ERROR" "无法切换到分支 $BRANCH_NAME"
    fi
}

# 添加文件到暂存区
stage_files() {
    log "INFO" "添加文件到暂存区..."
    
    # 添加修改的文件
    local files_to_add=(
        "openclaw_secure_install.sh"
        "README.md"
        "git_commit.sh"
    )
    
    for file in "${files_to_add[@]}"; do
        if [[ -f "$file" ]]; then
            git add "$file"
            log "INFO" "已添加: $file"
        else
            log "WARN" "文件不存在: $file"
        fi
    done
    
    # 显示暂存状态
    log "INFO" "暂存区状态:"
    git status --short
}

# 确认提交
confirm_commit() {
    log "INFO" "提交信息预览:"
    echo
    echo -e "${YELLOW}$COMMIT_MESSAGE${NC}"
    echo
    
    if confirm "确认提交这些更改？" "y"; then
        return 0
    else
        log "WARN" "用户取消提交"
        exit 0
    fi
}

# 执行提交
perform_commit() {
    log "INFO" "执行 Git 提交..."
    
    if git commit -m "$COMMIT_MESSAGE"; then
        log "INFO" "提交成功！"
        echo
        git log --oneline -1
        echo
    else
        log "ERROR" "提交失败"
        exit 1
    fi
}

# 推送到远程仓库
push_to_remote() {
    log "INFO" "推送到远程仓库..."
    
    # 检查是否有远程仓库
    if ! git remote get-url origin &>/dev/null; then
        log "WARN" "没有配置远程仓库 origin"
        return
    fi
    
    if confirm "是否推送到远程仓库？" "n"; then
        if git push -u origin "$BRANCH_NAME"; then
            log "INFO" "推送成功！"
            echo
            log "INFO" "创建 Pull Request 命令:"
            echo "gh pr create --title '更换 LLM 提供商为 MiniMax' --body '$COMMIT_MESSAGE'"
            echo
        else
            log "ERROR" "推送失败"
            exit 1
        fi
    fi
}

# 清理工作
cleanup() {
    log "INFO" "清理临时文件..."
    
    # 清理任何临时文件
    find . -name "*.tmp" -type f -delete 2>/dev/null || true
    
    log "INFO" "清理完成"
}

# 显示后续步骤
show_next_steps() {
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}        提交完成！后续操作建议${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo -e "${BLUE}🚀 推送到远程仓库:${NC}"
    echo "git push -u origin $BRANCH_NAME"
    echo
    echo -e "${BLUE}📝 创建 Pull Request:${NC}"
    echo "gh pr create --title '更换 LLM 提供商为 MiniMax' --body '请查看详细的更改说明'"
    echo
    echo -e "${BLUE}🔀 切换回主分支:${NC}"
    echo "git checkout main"
    echo
    echo -e "${BLUE}🧹 清理功能分支（合并后）:${NC}"
    echo "git branch -d $BRANCH_NAME"
    echo "git push origin --delete $BRANCH_NAME"
    echo
    echo -e "${BLUE}📊 查看提交历史:${NC}"
    echo "git log --oneline -5"
    echo
}

# 确认对话框
confirm() {
    local message="$1"
    local default="${2:-n}"
    local response
    
    if [[ "$default" = "y" ]]; then
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

# ==================== 主函数 ====================
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}    OpenClaw Git 提交脚本 v1.0${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
    
    # 执行提交流程
    check_git_status
    show_changes
    
    if confirm "继续执行提交流程？" "y"; then
        create_branch
        stage_files
        confirm_commit
        perform_commit
        push_to_remote
        cleanup
        show_next_steps
    else
        log "INFO" "用户取消操作"
        exit 0
    fi
    
    echo
    log "INFO" "脚本执行完成！"
}

# ==================== 脚本入口点 ====================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # 处理命令行参数
    case "${1:-}" in
        "-h"|"--help")
            echo "OpenClaw Git 提交脚本 v1.0"
            echo
            echo "用法: $0 [选项]"
            echo
            echo "选项:"
            echo "  -h, --help      显示此帮助信息"
            echo "  --skip-push     跳过推送到远程仓库"
            echo "  --no-branch     不创建新分支"
            echo
            exit 0
            ;;
        "--skip-push")
            SKIP_PUSH=true
            ;;
        "--no-branch")
            NO_BRANCH=true
            ;;
    esac
    
    # 执行主函数
    main "$@"
fi