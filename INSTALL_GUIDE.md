# OpenClaw 在线一键安装指南

## 🚀 快速安装

### 基础安装
```bash
curl -fsSL https://raw.githubusercontent.com/zhengweiyu/openclaw/main/online_install.sh | bash
```

### 高级安装选项

#### 1. 自动安装（无交互）
```bash
AUTO_ACCEPT=1 curl -fsSL https://raw.githubusercontent.com/zhengweiyu/openclaw/main/online_install.sh | bash
```

#### 2. 调试模式
```bash
DEBUG=1 curl -fsSL https://raw.githubusercontent.com/zhengweiyu/openclaw/main/online_install.sh | bash
```

#### 3. 跳过Tailscale安装
```bash
SKIP_TAILSCALE=1 curl -fsSL https://raw.githubusercontent.com/zhengweiyu/openclaw/main/online_install.sh | bash
```

#### 4. 选择LLM提供商
```bash
# MiniMax (默认)
LLM_PROVIDER=minimax curl -fsSL https://raw.githubusercontent.com/zhengweiyu/openclaw/main/online_install.sh | bash

# Claude
LLM_PROVIDER=claude curl -fsSL https://raw.githubusercontent.com/zhengweiyu/openclaw/main/online_install.sh | bash

# OpenAI GPT
LLM_PROVIDER=gpt curl -fsSL https://raw.githubusercontent.com/zhengweiyu/openclaw/main/online_install.sh | bash
```

#### 5. 组合选项
```bash
# 完全自动化安装 + Claude + 调试
AUTO_ACCEPT=1 LLM_PROVIDER=claude DEBUG=1 curl -fsSL https://raw.githubusercontent.com/zhengweiyu/openclaw/main/online_install.sh | bash

# 跳过Tailscale + MiniMax + 无交互
SKIP_TAILSCALE=1 LLM_PROVIDER=minimax AUTO_ACCEPT=1 curl -fsSL https://raw.githubusercontent.com/zhengweiyu/openclaw/main/online_install.sh | bash
```

## 📋 环境变量说明

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `DEBUG` | 0 | 启用调试模式，显示详细日志 |
| `AUTO_ACCEPT` | 0 | 自动确认所有提示，无需用户交互 |
| `SKIP_TAILSCALE` | 0 | 跳过Tailscale安装和配置 |
| `LLM_PROVIDER` | minimax | LLM提供商：minimax/claude/gpt |

## 🔧 LLM提供商配置

### MiniMax (默认)
- **注册地址**: https://api.minimax.chat/
- **需要准备**: Group ID 和 API Key
- **优势**: 性价比高，中文支持好

### Claude
- **注册地址**: https://console.anthropic.com/
- **需要准备**: API Key
- **优势**: 推理能力强，安全性高

### OpenAI GPT
- **注册地址**: https://platform.openai.com/
- **需要准备**: API Key
- **优势**: 生态完善，功能丰富

## 🌐 系统要求

### 支持的操作系统
- **macOS**: 10.15+ (Catalina 及以上版本)
- **Ubuntu**: 20.04 LTS 及以上版本

### 网络要求
- 稳定的互联网连接
- 可访问 GitHub、npm 和相关API服务
- 如果使用Tailscale，需要能够访问 Tailscale 服务

### 权限要求
- 管理员权限（用于安装系统服务和配置防火墙）
- Shell 访问权限

### 资源要求
- 至少 2GB 可用磁盘空间
- 至少 1GB 可用内存

## ⚡ 安装过程

脚本会自动执行以下步骤：

1. **系统检测** - 检测操作系统版本和配置
2. **依赖安装** - 安装 curl、wget、git 等基础工具
3. **网络安全** - 安装和配置 Tailscale（可选）
4. **Node.js** - 安装 Node.js 24 运行环境
5. **OpenClaw** - 安装 OpenClaw CLI 工具
6. **初始化** - 配置 LLM 提供商
7. **插件安装** - 安装 Matrix 插件和安全组件
8. **服务配置** - 创建系统服务，支持开机自启动
9. **安全加固** - 设置文件权限和防护机制

## 🛡️ 安全特性

### 网络安全
- **Tailscale VPN**: 端到端加密网络访问
- **防火墙配置**: 最小化攻击面
- **Zero Trust**: 基于身份的访问控制

### 应用安全
- **提示词注入防护**: 防止恶意AI攻击
- **技能审计系统**: 安全的插件管理
- **认知免疫保护**: 高级防护机制

### 系统安全
- **严格权限控制**: 最小权限原则
- **服务隔离**: 进程隔离和沙盒
- **安全日志**: 完整的审计追踪

## 🔄 安装后操作

### 验证安装
```bash
# 检查OpenClaw版本
openclaw --version

# 检查服务状态
# macOS
launchctl list | grep openclaw

# Ubuntu
sudo systemctl status openclaw

# 查看日志
tail -f ~/.openclaw/logs/stdout.log
```

### 启动服务
```bash
# 启动OpenClaw网关
openclaw gateway

# 访问Web控制台
open http://localhost:18789
```

### 配置LLM提供商（如果跳过初始化）
```bash
# 重新运行初始化
openclaw onboard

# 或手动配置
openclaw config set llm.provider minimax
openclaw config set minimax.group_id <your_group_id>
openclaw config set minimax.api_key <your_api_key>
```

### 管理Matrix通信
```bash
# 配对Telegram
openclaw pairing approve telegram <配对码>

# 查看配对状态
openclaw pairing list
```

## 🔧 故障排除

### 常见问题

#### 1. 网络连接问题
```bash
# 检查网络连接
curl -I https://api.minimax.chat

# 使用代理（如果需要）
export https_proxy=http://proxy.company.com:8080
export http_proxy=http://proxy.company.com:8080
```

#### 2. 权限问题
```bash
# 修复文件权限
sudo chown -R $USER:$USER ~/.openclaw
chmod 700 ~/.openclaw
chmod 600 ~/.openclaw/*.json
```

#### 3. 服务启动失败
```bash
# 查看详细错误
# macOS
launchctl print com.openclaw.ai

# Ubuntu
journalctl -u openclaw --no-pager
```

#### 4. Node.js版本问题
```bash
# 重新安装Node.js
nvm install 24
nvm use 24
nvm alias default 24
```

### 重新安装
```bash
# 完全卸载
sudo systemctl stop openclaw 2>/dev/null || true
sudo systemctl disable openclaw 2>/dev/null || true
sudo rm -f /etc/systemd/system/openclaw.service
sudo systemctl daemon-reload 2>/dev/null || true

launchctl unload ~/Library/LaunchAgents/com.openclaw.ai.plist 2>/dev/null || true
rm -f ~/Library/LaunchAgents/com.openclaw.ai.plist

rm -rf ~/.openclaw
npm uninstall -g @openclaw/cli 2>/dev/null || true

# 重新安装
curl -fsSL https://raw.githubusercontent.com/zhengweiyu/openclaw/main/online_install.sh | bash
```

## 📚 更多资源

- **官方文档**: https://openclaw.ai/docs
- **社区论坛**: https://community.openclaw.ai
- **GitHub仓库**: https://github.com/openclaw
- **支持邮件**: support@openclaw.ai

## ⚠️ 免责声明

本安装脚本用于生产环境部署，请确保：
1. 在测试环境中充分验证
2. 了解所有安装步骤
3. 准备好必要的API密钥和凭据
4. 遵循企业安全政策

安装过程中如遇到问题，请查看日志文件 `/tmp/openclaw_online_install_*.log` 或联系技术支持。