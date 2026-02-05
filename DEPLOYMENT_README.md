# OpenClaw 在线安装部署说明

## 📋 部署清单

### 🔧 文件清单

| 文件名 | 用途 | 状态 |
|--------|------|------|
| `online_install.sh` | 在线一键安装脚本 | ✅ 完成 |
| `openclaw_secure_install.sh` | 本地安装脚本 | ✅ 已优化 |
| `INSTALL_GUIDE.md` | 在线安装指南 | ✅ 完成 |
| `DEPLOYMENT_README.md` | 部署说明文档 | ✅ 本文档 |
| `demo_install.sh` | 安装演示脚本 | ✅ 完成 |
| `README.md` | 项目主文档 | ✅ 已更新 |
| `git_commit.sh` | Git提交脚本 | ✅ 完成 |
| `quick_commit.sh` | 快速提交脚本 | ✅ 完成 |
| `COMMIT_GUIDE.md` | Git提交指南 | ✅ 完成 |

### 🌐 部署要求

#### 服务器端
- 将 `online_install.sh` 部署到可访问的URL
- 推荐路径: `https://raw.githubusercontent.com/zhengweiyu/openclaw/main/online_install.sh`
- 备用路径: `https://raw.githubusercontent.com/openclaw/deployment-scripts/main/online_install.sh`

#### 客户端要求
- macOS 10.15+ 或 Ubuntu 20.04+
- 网络连接（可访问GitHub、npm、LLM API）
- 管理员权限
- 2GB+ 可用磁盘空间

## 🚀 部署步骤

### 1. 服务器部署

#### 方法A: 直接部署到网站
```bash
# 上传到Web服务器
scp online_install.sh user@server:/var/www/html/install_secure_online.sh

# 设置权限
ssh user@server "chmod +x /var/www/html/install_secure_online.sh"
```

#### 方法B: GitHub部署
```bash
# 推送到GitHub仓库
git add online_install.sh
git commit -m "feat: 添加在线一键安装脚本"
git push origin main
```

### 2. 测试验证

#### 本地测试
```bash
# 测试脚本语法
bash -n online_install.sh

# 测试帮助信息
CURL_EXECUTION=1 ./online_install.sh --help

# 模拟安装（不实际执行）
DEBUG=1 CURL_EXECUTION=1 ./online_install.sh 2>&1 | head -20
```

#### 在线测试
```bash
# 测试URL可访问性
curl -I https://raw.githubusercontent.com/zhengweiyu/openclaw/main/online_install.sh

# 测试脚本下载
curl -fsSL https://raw.githubusercontent.com/zhengweiyu/openclaw/main/online_install.sh | head -10

# 完整测试（在测试环境中）
curl -fsSL https://raw.githubusercontent.com/zhengweiyu/openclaw/main/online_install.sh | bash
```

### 3. 发布说明

#### 更新文档
- 确保README.md包含正确的安装命令
- 更新INSTALL_GUIDE.md中的URL
- 检查所有相关文档的链接

#### 用户通知
- 发布更新日志
- 发送社区通知
- 更新网站首页

## 📊 使用统计

### 安装命令统计

| 安装类型 | 命令 | 预期使用比例 |
|--------|------|------------|
| 基础安装 | `curl -fsSL URL | bash` | 60% |
| 自动安装 | `AUTO_ACCEPT=1 curl -fsSL URL | bash` | 25% |
| Claude提供商 | `LLM_PROVIDER=claude curl -fsSL URL | bash` | 10% |
| 其他组合 | 各种环境变量组合 | 5% |

### LLM提供商分布

| 提供商 | 优势 | 预期用户群体 |
|--------|------|------------|
| MiniMax | 性价比高，中文支持好 | 个人开发者，中小企业 |
| Claude | 推理能力强，安全性高 | 企业用户，注重安全 |
| GPT | 生态完善，功能丰富 | 技术团队，集成开发者 |

## 🔧 维护和更新

### 版本管理

#### 脚本版本控制
```bash
# 更新版本号
readonly SCRIPT_VERSION="2.1"

# 更新日期
readonly UPDATE_DATE="2024-02-05"

# 添加变更日志
update_changelog() {
    echo "v2.1 (2024-02-05):"
    echo "- 添加新的LLM提供商支持"
    echo "- 优化安装速度"
    echo "- 修复已知问题"
}
```

#### 向后兼容
- 保持环境变量命名的一致性
- 维护API兼容性
- 提供迁移指南

### 监控和日志

#### 安装成功率监控
```bash
# 在脚本末尾添加统计上报（可选）
if [[ "${STATISTICS:-0}" == "1" ]]; then
    curl -s -X POST https://api.openclaw.ai/stats \
        -d "version=${SCRIPT_VERSION}" \
        -d "os=${OS}" \
        -d "provider=${LLM_PROVIDER}" \
        -d "success=true" \
        2>/dev/null || true
fi
```

#### 错误收集
```bash
# 错误上报函数
report_error() {
    local error_msg="$1"
    local error_code="${2:-1}"
    
    if [[ "${ERROR_REPORTING:-0}" == "1" ]]; then
        curl -s -X POST https://api.openclaw.ai/error \
            -d "version=${SCRIPT_VERSION}" \
            -d "os=${OS}" \
            -d "error=${error_msg}" \
            -d "code=${error_code}" \
            2>/dev/null || true
    fi
}
```

### 安全更新

#### 定期安全审查
- 检查下载URL的安全性
- 验证所有外部依赖的完整性
- 更新安全最佳实践

#### 证书和密钥管理
- 定期轮换API密钥
- 更新SSL证书
- 审查权限设置

## 📈 性能优化

### 安装速度优化

#### 并行安装
```bash
# 并行下载依赖
download_dependencies() {
    local pids=()
    
    # 并行下载多个包
    (download_homebrew &) && pids+=($!)
    (download_nodejs &) && pids+=($!)
    (download_tailscale &) && pids+=($!)
    
    # 等待所有下载完成
    for pid in "${pids[@]}"; do
        wait $pid
    done
}
```

#### 缓存优化
```bash
# 检查本地缓存
check_cache() {
    local cache_dir="$HOME/.openclaw/cache"
    local cache_file="$cache_dir/install_cache.tar.gz"
    
    if [[ -f "$cache_file" && $(find "$cache_file" -mtime -7) ]]; then
        log "INFO" "使用本地缓存"
        tar -xzf "$cache_file" -C /tmp/
        return 0
    fi
    
    return 1
}
```

### 网络优化

#### 多镜像源
```bash
# 多个下载源
DOWNLOAD_SOURCES=(
    "https://github.com/openclaw"
    "https://mirrors.tuna.tsinghua.edu.cn/openclaw"
    "https://cdn.jsdelivr.net/gh/openclaw"
)

download_with_fallback() {
    local file="$1"
    local output="$2"
    
    for source in "${DOWNLOAD_SOURCES[@]}"; do
        if curl -fsSL "${source}/${file}" -o "$output"; then
            return 0
        fi
    done
    
    return 1
}
```

## 🔄 自动化测试

### CI/CD 集成

#### GitHub Actions 工作流
```yaml
name: Test Install Script

on:
  push:
    paths:
      - 'online_install.sh'
  pull_request:
    paths:
      - 'online_install.sh'

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Test script syntax
      run: bash -n online_install.sh
    
    - name: Test help output
      run: |
        export CURL_EXECUTION=1
        ./online_install.sh --help
    
    - name: Test installation
      run: |
        AUTO_ACCEPT=1 SKIP_TAILSCALE=1 \
        curl -fsSL ./online_install.sh | bash
```

#### 自动化测试脚本
```bash
# test_install.sh
#!/bin/bash

test_install_script() {
    local test_env="$1"
    
    echo "Testing in $test_env..."
    
    # 测试基本功能
    export CURL_EXECUTION=1
    ./online_install.sh --help > /dev/null
    
    # 测试语法
    bash -n online_install.sh
    
    # 模拟安装（在容器中）
    if [[ "$test_env" == "docker" ]]; then
        docker run --rm -v "$PWD:/app" ubuntu:20.04 \
            bash -c "cd /app && AUTO_ACCEPT=1 ./online_install.sh"
    fi
    
    echo "✅ $test_env test passed"
}
```

## 📞 支持和反馈

### 用户支持渠道

#### 文档支持
- 完整的安装指南
- 故障排除文档
- 视频教程

#### 社区支持
- GitHub Issues
- 社区论坛
- 技术交流群

#### 商业支持
- 企业级技术支持
- 定制化部署方案
- 优先问题响应

### 反馈收集

#### 用户调研
```bash
# 安装后反馈收集
collect_feedback() {
    if [[ "${FEEDBACK_ENABLED:-0}" == "1" && "${AUTO_ACCEPT}" != "1" ]]; then
        echo -e "\n${YELLOW}📝 您愿意提供安装反馈吗？${NC}"
        read -p "是否参与用户体验改进？(y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            open https://openclaw.ai/feedback 2>/dev/null || \
            echo "请访问: https://openclaw.ai/feedback"
        fi
    fi
}
```

---

**📅 最后更新**: 2024-02-05  
**🔄 版本**: v2.0  
**📧 联系方式**: support@openclaw.ai