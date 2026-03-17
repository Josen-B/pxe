# ArceOS PXE 启动部署指南

本文档详细说明如何在 x86_64 物理开发板上通过 PXE 启动 ArceOS 内核。

## 环境要求

- **服务器**: Ubuntu 22.04+
- **网卡**: `enp3s0`，IP `192.168.1.229`
- **开发板**: x86_64 UEFI 模式，支持网络启动 (PXE)
- **网络**: 网线直连服务器，或同一局域网

## 架构说明

### 启动流程

```
开发板 UEFI
    ↓ (PXE 启动)
iPXE (ipxe-mb.efi)
    ↓ (下载 boot.ipxe)
GRUB (grubx64.efi)
    ↓ (multiboot 协议)
ArceOS 内核
    ↓
Hello, world!
```

### 组件说明

| 组件 | 功能 | 文件位置 |
|------|------|----------|
| dnsmasq | DHCP + TFTP 服务 | 系统服务 |
| iPXE | 网络引导程序 | `/var/lib/tftpboot/ipxe-mb.efi` |
| GRUB | 内核加载器 | `/var/lib/tftpboot/grubx64.efi` |
| ArceOS | 目标内核 | `/var/lib/tftpboot/kernel` |

### 项目目录结构

```
/code/pxe/
├── README.md                 # 本文件
├── docs/
│   └── QUICK_START.md       # 快速上手指南
├── scripts/                  # 部署脚本
│   ├── pxe-physical-deploy.sh
│   ├── switch-mode.sh
│   └── monitor-pxe-tftp.sh
└── tftpboot/                 # 启动文件备份
    ├── ipxe-mb.efi          # iPXE 引导程序 (1.2M)
    ├── grubx64.efi          # GRUB EFI 镜像 (704K)
    ├── boot.ipxe            # iPXE 启动脚本
    └── kernel               # ArceOS 内核 (77K)
```

**注意**: `tftpboot/` 目录是启动文件的备份，实际运行时会复制到 `/var/lib/tftpboot/`。

## 部署步骤

### 1. 安装依赖

```bash
sudo apt-get update
sudo apt-get install -y dnsmasq grub-efi-amd64-bin
```

### 2. 执行部署脚本

```bash
cd /code/pxe/scripts
sudo ./pxe-physical-deploy.sh --install --mode direct
```

部署脚本将自动：
- 配置 dnsmasq DHCP/TFTP
- 复制启动文件到 `/var/lib/tftpboot/`
- 生成 GRUB EFI 镜像（内嵌配置）
- 启动 dnsmasq 服务

### 3. 验证部署

```bash
sudo ./pxe-physical-deploy.sh --status
```

应显示：
```
✅ dnsmasq: running
✅ TFTP root: /var/lib/tftpboot/
✅ boot.ipxe: exists
✅ grubx64.efi: exists
✅ kernel: exists
```

## 开发板配置

### BIOS 设置

1. **Boot Mode**: UEFI (不是 Legacy/CSM)
2. **Network Boot**: Enabled
3. **PXE Boot**: Enabled
4. **Secure Boot**: Disabled (可选)

### 启动步骤

1. 连接网线到服务器
2. 重启开发板
3. 按 **F12** 或 **F11** 进入启动菜单
4. 选择 **UEFI: Network** 或 **PXE Boot**

## 网络模式

### 直连模式 (direct)

服务器作为 DHCP 服务器，分配 192.168.1.x 地址。

**适用场景**: 开发板直连服务器网线

```bash
cd /code/pxe/scripts
sudo ./switch-mode.sh direct
```

### 代理模式 (proxy)

不分配 IP，只响应 PXE 请求。

**适用场景**: 局域网中已有 DHCP 服务器

```bash
cd /code/pxe/scripts
sudo ./switch-mode.sh proxy
```

**注意**: 代理模式需要主 DHCP 服务器配合配置 next-server

## 核心配置

### GRUB EFI 配置

GRUB 镜像内嵌以下配置：

```bash
# 初始化串口
serial --unit=0 --speed=115200
terminal_input console serial
terminal_output console serial

# 初始化网络
net_bootp
set net_default_ip=192.168.1.192
set net_default_server=192.168.1.229

# 加载内核
multiboot (tftp,192.168.1.229)/kernel
boot
```

### dnsmasq 配置

```conf
# DHCP 范围
dhcp-range=192.168.1.100,192.168.1.200,255.255.255.0,12h

# UEFI 启动文件
dhcp-boot=tag:efi-x86_64,ipxe-mb.efi,,192.168.1.229

# iPXE 第二阶段
dhcp-boot=tag:ipxe,boot.ipxe,,192.168.1.229

# TFTP 配置
enable-tftp
tftp-root=/var/lib/tftpboot
```

## 启动效果
```
Initializing network device...
error: couldn't autoconfigure efinet0.
error: couldn't autoconfigure efinet1.
Unknown command `#'.
Configuring network...
Unknown command `#'.
Loading ArceOS kernel...
WARNING: no console will be available to OS
Starting ArceOS...
error: no suitable video mode found.

Initialize IDT & GDT...
Got TSC frequency by CPUID: 2500 MHz

       d8888                            .d88888b.   .d8888b.
      d88888                           d88P" "Y88b d88P  Y88b
     d88P888                           888     888 Y88b.
    d88P 888 888d888  .d8888b  .d88b.  888     888  "Y888b.
   d88P  888 888P"   d88P"    d8P  Y8b 888     888     "Y88b.
  d88P   888 888     888      88888888 888     888       "888
 d8888888888 888     Y88b.    Y8b.     Y88b. .d88P Y88b  d88P
d88P     888 888      "Y8888P  "Y8888   "Y88888P"   "Y8888P"

arch = x86_64
platform = x86_64-pc-oslab
target = x86_64-unknown-none
smp = 1
build_mode = release
log_level = debug

[  0.059501 0 axruntime:130] Logging is enabled.
[  0.065795 0 axruntime:131] Primary CPU 0 started, dtb = 0x0.
[  0.073420 0 axruntime:133] Found physcial memory regions:
[  0.080768 0 axruntime:135]   [PA:0x200000, PA:0x20a000) .text (READ | EXECUTE | RESERVED)
[  0.091159 0 axruntime:135]   [PA:0x20a000, PA:0x20d000) .rodata (READ | RESERVED)
[  0.100794 0 axruntime:135]   [PA:0x20d000, PA:0x214000) .data .tdata .tbss .percpu (READ | WRITE | RESERVED)
[  0.112995 0 axruntime:135]   [PA:0x214000, PA:0x254000) boot stack (READ | WRITE | RESERVED)
[  0.123675 0 axruntime:135]   [PA:0x254000, PA:0x256000) .bss (READ | WRITE | RESERVED)
[  0.133786 0 axruntime:135]   [PA:0x1000, PA:0x9f000) low memory (READ | WRITE | RESERVED)
[  0.144177 0 axruntime:135]   [PA:0x256000, PA:0x80000000) free memory (READ | WRITE | FREE)
[  0.154762 0 axruntime:135]   [PA:0xfec00000, PA:0xfec01000) mmio (READ | WRITE | DEVICE | RESERVED)
[  0.166112 0 axruntime:135]   [PA:0xfed00000, PA:0xfed01000) mmio (READ | WRITE | DEVICE | RESERVED)
[  0.177458 0 axruntime:135]   [PA:0xfee00000, PA:0xfee01000) mmio (READ | WRITE | DEVICE | RESERVED)
[  0.188803 0 axruntime:135]   [PA:0xc0000000, PA:0xc1000000) mmio (READ | WRITE | DEVICE | RESERVED)
[  0.200148 0 axruntime:135]   [PA:0xfcd80000, PA:0xfce00000) mmio (READ | WRITE | DEVICE | RESERVED)
[  0.211499 0 axruntime:135]   [PA:0x80900000, PA:0x80920000) mmio (READ | WRITE | DEVICE | RESERVED)
[  0.222844 0 axruntime:150] Initialize platform devices...
[  0.230186 0 axhal::platform::x86_pc::apic:87] Initialize Local APIC...
[  0.238780 0 axhal::platform::x86_pc::apic:102] Using x2APIC.
[  0.246394 0 axhal::platform::x86_pc::apic:116] Initialize IO APIC...
[  0.254785 0 axruntime:186] Primary CPU 0 init OK.
Hello, world!
[  0.262796 0 axruntime:199] main task exited: exit_code=0
[  0.270042 0 axhal::platform::x86_pc::misc:7] Shutting down...
System will reboot, press any key to continue ...

```

## 故障排查

### 无法获取 IP

**症状**: iPXE 显示 `No configuration methods succeeded`

**解决**:
1. 检查网线连接
2. 确认 switch-mode.sh direct: `sudo ./switch-mode.sh direct`
3. 检查 dnsmasq: `sudo systemctl status dnsmasq`

### TFTP 超时

**症状**: `Operation not permitted` 或超时

**解决**:
1. 检查防火墙: `sudo ufw disable`
2. 检查文件权限: `ls -la /var/lib/tftpboot/`
3. 测试 TFTP: `tftp 192.168.1.229 -c get kernel /tmp/test`

### 内核格式错误

**症状**: `Exec format error`

**原因**: iPXE 不能直接启动 ELF/multiboot 格式

**解决**: 使用 GRUB 作为中间加载器（已配置）

### GRUB 进入命令行

**症状**: 显示 `grub>` 提示符

**解决**: GRUB 配置已内嵌到 grubx64.efi，如果仍进入命令行，手动执行：
```bash
grub> net_bootp
grub> multiboot (tftp,192.168.1.229)/kernel
grub> boot
```

## 技术细节

### 为什么使用 GRUB？

UEFI iPXE 只能直接启动 PE32+ 格式（.efi 文件），不能启动 ELF/multiboot 格式的 ArceOS 内核。

解决方案：
1. iPXE 加载 GRUB (grubx64.efi)
2. GRUB 使用 multiboot 协议加载 ArceOS 内核

### multiboot 协议

ArceOS 内核遵循 multiboot 规范，头部包含魔数 `0x1BADB002`。

GRUB `multiboot` 命令可以正确识别和加载此类内核。

### 静态 IP 配置

开发板 MAC 地址: `88:88:88:88:87:88`

静态 IP: `192.168.1.192`

GRUB 配置中使用静态 IP 避免 DHCP 失败。

## 更新内核

```bash
# 编译新的 ArceOS 内核
cd /path/to/arceos
make ARCH=x86_64

# 复制到 TFTP 目录
sudo cp target/x86_64/release/arceos-helloworld /var/lib/tftpboot/kernel

# 无需重启服务，直接测试
```

## 参考

- [iPXE 文档](https://ipxe.org/docs)
- [GRUB Multiboot](https://www.gnu.org/software/grub/manual/multiboot/multiboot.html)
- [dnsmasq 文档](http://www.thekelleys.org.uk/dnsmasq/doc.html)

## 快速命令速查

```bash
# 部署
sudo ./pxe-physical-deploy.sh --install --mode direct

# 状态
sudo ./pxe-physical-deploy.sh --status

# 切换模式
sudo ./switch-mode.sh direct
sudo ./switch-mode.sh proxy
sudo ./switch-mode.sh status

# 监控
sudo ./monitor-pxe-tftp.sh

# 重启服务
sudo systemctl restart dnsmasq

# 查看日志
sudo journalctl -u dnsmasq -f
```
