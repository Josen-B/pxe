#!/bin/bash
# 实时监控PXE启动过程中的DHCP和TFTP活动

echo "========================================="
echo "PXE + TFTP 实时监控"
echo "========================================="
echo "监控时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "服务器IP: 192.168.1.2"
echo "客户端IP: 192.168.1.4"
echo "客户端MAC: 88:88:88:88:87:88"
echo ""
echo "按 Ctrl+C 停止监控"
echo "========================================="
echo ""

# 清空日志缓冲区
sudo journalctl --vacuum-time=1s > /dev/null 2>&1

# 实时监控dnsmasq日志
sudo journalctl -u dnsmasq -f --no-pager
