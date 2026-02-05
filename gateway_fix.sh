#!/bin/bash
set -euo pipefail

# ==================== 脚本说明 ====================
echo -e "===== Gateway 一键修复脚本（用户级systemd持久化）=====\n"
echo "作用：修复用户级systemd总线不通、XDG_RUNTIME_DIR缺失、daemon-reload失败等问题"
echo "适用：所有基于systemd的Linux发行版（Ubuntu 18.04+/CentOS 7+/Debian 10+）"
echo "注意：脚本需要root权限（会自动提权），请确保当前用户有sudo权限\n"

# ==================== 1. 检查系统是否为systemd ====================
check_systemd() {
  if ! command -v systemctl &> /dev/null; then
    echo "[错误] 当前系统不是systemd架构，该脚本不适用！"
    exit 1
  fi
}
check_systemd

# ==================== 2. 获取目标用户名（交互输入）====================
read -p "请输入需要修复的目标用户名（如app/ubuntu/pi）：" TARGET_USER
# 验证用户是否存在
if ! id -u "$TARGET_USER" &> /dev/null; then
  echo "[错误] 用户名 $TARGET_USER 不存在！"
  exit 1
fi
TARGET_UID=$(id -u "$TARGET_USER")  # 提前获取UID备用

# ==================== 3. Root提权并开启linger持久化 ====================
echo -e "\n[步骤1/5] 提权至root并开启用户linger持久化..."
if [[ $EUID -ne 0 ]]; then
  echo "正在提权到root..."
  if ! sudo -i bash -c "
    loginctl enable-linger $TARGET_USER && \
    echo '✅ linger已开启' && \
    loginctl show-user $TARGET_USER | grep Linger && \
    systemctl daemon-reload && \
    echo '✅ 系统级systemd已重载'
  "; then
    echo "[错误] root操作失败，请手动执行 loginctl enable-linger $TARGET_USER"
    exit 1
  fi
else
  # 已为root直接执行
  loginctl enable-linger "$TARGET_USER"
  echo "✅ linger已开启"
  loginctl show-user "$TARGET_USER" | grep Linger
  systemctl daemon-reload
  echo "✅ 系统级systemd已重载"
fi

# ==================== 4. 切换到目标用户并验证环境 ====================
echo -e "\n[步骤2/5] 切换到目标用户并验证核心环境..."
# 用sudo -iu切换（保证完整登录环境），执行验证逻辑
sudo -iu "$TARGET_USER" bash -c "
  echo '当前用户：' && whoami
  echo -e '\n[验证XDG_RUNTIME_DIR环境变量]'
  if [[ -n \$XDG_RUNTIME_DIR ]]; then
    echo '✅ XDG_RUNTIME_DIR已存在：' \$XDG_RUNTIME_DIR
    ls -ld \$XDG_RUNTIME_DIR || echo '⚠️ 目录存在但无法访问'
  else
    echo '⚠️ XDG_RUNTIME_DIR缺失，手动创建修复...'
    mkdir -p /run/user/$TARGET_UID
    chmod 700 /run/user/$TARGET_UID
    chown -R $TARGET_USER:$TARGET_USER /run/user/$TARGET_UID
    export XDG_RUNTIME_DIR=/run/user/$TARGET_UID
    echo '✅ 已手动创建：' \$XDG_RUNTIME_DIR
  fi

  echo -e '\n[验证用户级systemd总线]'
  if systemctl --user status &> /dev/null; then
    echo '✅ 用户级systemd总线连通成功！'
    systemctl --user status | head -10
  else
    echo '[错误] 用户级systemd总线仍不通，请检查系统配置！'
    exit 1
  fi

  echo -e '\n[执行用户级daemon-reload]'
  systemctl --user daemon-reload
  echo '✅ daemon-reload执行成功！'
"

# ==================== 5. 最终验证与提示 ====================
echo -e "\n===== 修复完成！最终验证 ====="
echo "1. Linger状态验证："
sudo loginctl show-user "$TARGET_USER" | grep Linger
echo -e "\n2. 建议操作："
echo "   - 退出当前终端，重新连接服务器（确保环境完全加载）"
echo "   - 重新启动Gateway服务：sudo -iu $TARGET_USER systemctl --user restart gateway"
echo "   - 查看Gateway日志：sudo -iu $TARGET_USER journalctl --user -u gateway -f"
echo -e "\n✅ 脚本执行完成，核心问题已修复！"