#!/bin/bash

# 测试在线安装脚本

echo "🧪 测试 OpenClaw 在线安装脚本..."
echo

# 测试URL可访问性
echo "1️⃣ 测试脚本URL可访问性..."
if curl -s -I https://raw.githubusercontent.com/zhengweiyu/openclaw/main/online_install.sh | grep -q "HTTP/2 200"; then
    echo "✅ 脚本URL可正常访问"
else
    echo "❌ 脚本URL访问失败"
    exit 1
fi

# 测试脚本语法
echo
echo "2️⃣ 测试脚本语法..."
if curl -fsSL https://raw.githubusercontent.com/zhengweiyu/openclaw/main/online_install.sh | bash -n; then
    echo "✅ 脚本语法正确"
else
    echo "❌ 脚本语法错误"
    exit 1
fi

# 显示安装命令
echo
echo "3️⃣ 可用的安装命令:"
echo
echo "🚀 基础安装:"
echo "curl -fsSL https://raw.githubusercontent.com/zhengweiyu/openclaw/main/online_install.sh | bash"
echo
echo "🔧 高级选项:"
echo "AUTO_ACCEPT=1 curl -fsSL https://raw.githubusercontent.com/zhengweiyu/openclaw/main/online_install.sh | bash"
echo
echo "🤖 选择LLM提供商:"
echo "LLM_PROVIDER=claude curl -fsSL https://raw.githubusercontent.com/zhengweiyu/openclaw/main/online_install.sh | bash"
echo

echo "✅ 在线安装脚本测试完成！"