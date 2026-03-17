#!/bin/bash
# PXE模式切换脚本

CONFIG_DIR="/etc/dnsmasq.d"
PROXY_CONF="$CONFIG_DIR/pxe-physical.conf"
DIRECT_CONF="$CONFIG_DIR/pxe-direct.conf"
DISABLED_DIR="$CONFIG_DIR/disabled"

# 创建disabled目录
sudo mkdir -p "$DISABLED_DIR"

show_status() {
    echo "========================================="
    echo "当前配置状态"
    echo "========================================="

    if [ -f "$PROXY_CONF" ]; then
        echo "✅ 代理模式配置: $PROXY_CONF"
        grep "^dhcp-range" "$PROXY_CONF" | head -1
    else
        echo "❌ 代理模式配置: 不存在"
    fi

    if [ -f "$DIRECT_CONF" ]; then
        echo "✅ 独立模式配置: $DIRECT_CONF"
        grep "^dhcp-range" "$DIRECT_CONF" | head -1
    else
        echo "❌ 独立模式配置: 不存在"
    fi

    echo ""
    echo "当前dnsmasq加载的配置："
    ls -1 $CONFIG_DIR/*.conf 2>/dev/null | grep -v "$(basename $0)" || echo "无配置文件"

    echo ""
    echo "========================================="
}

switch_to_proxy() {
    echo "切换到代理模式（DHCP Proxy）..."
    echo "适用场景：现有网络环境，与主DHCP共存"
    echo ""

    # 禁用独立模式
    if [ -f "$DIRECT_CONF" ]; then
        sudo mv "$DIRECT_CONF" "$DISABLED_DIR/"
        echo "✅ 已禁用独立模式配置"
    fi

    # 确保代理模式配置存在
    if [ ! -f "$PROXY_CONF" ]; then
        echo "❌ 错误：代理模式配置文件不存在"
        exit 1
    fi

    # 重启服务
    sudo systemctl restart dnsmasq
    echo "✅ dnsmasq已重启"
    echo ""
    echo "⚠️  警告：代理模式下，主DHCP服务器可能抢占响应"
    echo "   如果PXE启动失败，请考虑使用独立模式"
}

switch_to_direct() {
    echo "切换到独立模式（Standalone DHCP）..."
    echo "适用场景：直连网络或独立网络环境"
    echo ""

    # 禁用代理模式
    if [ -f "$PROXY_CONF" ]; then
        sudo mv "$PROXY_CONF" "$DISABLED_DIR/"
        echo "✅ 已禁用代理模式配置"
    fi

    # 启用独立模式
    if [ -f "$DISABLED_DIR/$(basename $DIRECT_CONF)" ]; then
        sudo mv "$DISABLED_DIR/$(basename $DIRECT_CONF)" "$DIRECT_CONF"
        echo "✅ 已启用独立模式配置"
    elif [ ! -f "$DIRECT_CONF" ]; then
        echo "❌ 错误：独立模式配置文件不存在"
        exit 1
    fi

    # 重启服务
    sudo systemctl restart dnsmasq
    echo "✅ dnsmasq已重启"
    echo ""
    echo "ℹ️  提示：请确保网线已直连服务器和开发板"
    echo "   或确保网络中没有其他DHCP服务器"
}

# 主程序
case "${1:-status}" in
    status)
        show_status
        ;;
    proxy)
        switch_to_proxy
        show_status
        ;;
    direct)
        switch_to_direct
        show_status
        ;;
    *)
        echo "用法: $0 {status|proxy|direct}"
        echo ""
        echo "  status - 显示当前配置状态"
        echo "  proxy  - 切换到DHCP代理模式"
        echo "  direct - 切换到独立DHCP模式"
        echo ""
        echo "示例:"
        echo "  $0 direct  # 切换到直连模式"
        echo "  $0 status  # 查看状态"
        exit 1
        ;;
esac
