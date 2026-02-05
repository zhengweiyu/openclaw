#!/bin/bash

# 快速提交脚本 - 立即提交当前的 MiniMax 更改

set -e

# 提交信息
COMMIT_MESSAGE="feat: 更换 LLM 提供商为 MiniMax

- 将部署脚本中的 Venice AI 替换为 MiniMax
- 更新初始化流程和配置说明
- 添加 MiniMax 官网地址: https://api.minimax.chat/
- 完善 README.md 中的 API 密钥配置指南
- 更新安全维护建议和配置命令

影响文件:
- openclaw_secure_install.sh: 核心部署脚本
- README.md: 用户文档
- git_commit.sh: 提交脚本
- quick_commit.sh: 快速提交脚本"

echo "🚀 开始快速提交..."

# 显示当前状态
echo "📋 当前状态:"
git status --short

# 添加所有相关文件
echo
echo "📁 添加文件到暂存区..."
git add openclaw_secure_install.sh README.md git_commit.sh quick_commit.sh

# 显示暂存状态
echo
echo "📊 暂存区状态:"
git status --short

# 提交
echo
echo "💬 提交更改..."
git commit -m "$COMMIT_MESSAGE"

# 显示提交结果
echo
echo "✅ 提交成功！"
echo
echo "📝 最新提交:"
git log --oneline -1
echo

# 询问是否推送
read -p "📤 是否推送到远程仓库？(y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 推送到远程仓库..."
    git push
    echo "✅ 推送成功！"
else
    echo "⏸️  跳过推送"
fi

echo
echo "🎉 快速提交完成！"