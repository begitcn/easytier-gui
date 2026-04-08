#!/bin/bash

# EasyTier GUI Launcher Script
# This script runs EasyTier GUI with the necessary root privileges

echo "EasyTier GUI 启动脚本"
echo "====================="
echo ""
echo "EasyTier 需要 root 权限来创建 TUN 网络设备。"
echo "正在请求管理员权限..."
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Run the application with sudo
sudo "$SCRIPT_DIR/EasyTierGUI"
