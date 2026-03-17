# PXE 启动调试记录

本文档记录了 ArceOS 通过 PXE 在 x86_64 物理开发板启动的完整调试过程。

## 问题描述

**目标**: 通过 PXE 网络启动方式，在 x86_64 物理开发板上启动 ArceOS 内核。

**初始状态**:
- DHCP 握手成功
- iPXE 加载成功
- 无法启动 ArceOS 内核
- 错误: `Exec format error` (https://ipxe.org/2e008081)

## 根本原因分析

### 1. 内核格式问题

ArceOS 内核是 **multiboot 格式**（魔数 `0x1BADB002`），不是 UEFI 可执行文件（PE32+ 格式）。

```
$ hexdump -C kernel | head -3
00000000  89 c7 89 de eb 22 66 90  02 b0 ad 1b 02 00 01 00
```

**结论**: UEFI iPXE 只能直接启动 `.efi` 文件，不能直接启动 multiboot/ELF 格式的内核。

### 2. 解决方案选择

| 方案 | 描述 | 复杂度 | 结果 |
|------|------|--------|------|
| Legacy BIOS 模式 | 使用 undionly.kpxe | 低 | 开发板不支持 Legacy PXE |
| GRUB 中间层 | iPXE → GRUB → 内核 | 中 | ✅ 成功 |
| 重新编译 ArceOS | 编译为 .efi 格式 | 高 | 需要修改源码 |

**最终方案**: 使用 **GRUB 作为中间 bootloader**

## 调试过程

### Phase 1: 尝试 Legacy 模式（失败）

切换 BIOS 为 Legacy 模式，但开发板无法识别网络启动。

**问题**: 网卡 Boot ROM 未启用或网卡不支持 Legacy PXE。

### Phase 2: UEFI + GRUB 尝试

#### 尝试 2.1: 基础 GRUB 配置（失败）

创建 GRUB 镜像和配置文件，但 GRUB 进入命令行模式。

**错误**: `Boot option loading failed`

**原因**: 
- GRUB 无法从 TFTP 加载外部配置文件
- UEFI 网络驱动初始化失败

#### 尝试 2.2: 内嵌配置（部分成功）

将配置内嵌到 GRUB 镜像中，但 `net_bootp` 命令失败：

```
grub> net_bootp
error: couldn't autoconfigure efinet0.
error: couldn't autoconfigure efinet1.
```

#### 尝试 2.3: 静态 IP 配置（成功）

放弃 DHCP，直接使用静态 IP：

```bash
# GRUB 内嵌配置
serial --unit=0 --speed=115200
terminal_input console serial
terminal_output console serial

net_bootp  # 尝试 DHCP（会失败，但初始化网络设备）
set net_default_ip=192.168.1.192
set net_default_server=192.168.1.229

multiboot (tftp,192.168.1.229)/kernel
boot
```

**结果**: ArceOS 成功启动！

```
       d8888                            .d88888b.   .d8888b.
      d88888                           d88P" "Y88b d88P  Y88b
     ...
Hello, world!
```

## 关键技术点

### 1. GRUB 镜像生成

```bash
sudo grub-mkimage -o grubx64.efi -O x86_64-efi \
  -p "" \
  -c grub-embedded.cfg \
  normal tftp net boot multiboot multiboot2 \
  efinet linux linux16 serial terminal \
  echo cat ls test
```

**关键模块**:
- `tftp`, `net`, `efinet`: 网络支持
- `multiboot`, `multiboot2`: 多引导协议支持
- `serial`, `terminal`: 串口终端支持

### 2. iPXE 启动脚本

```ipxe
#!ipxe
echo Loading GRUB EFI bootloader...
chain tftp://192.168.1.229/grubx64.efi
```

### 3. dnsmasq 配置要点

```conf
# 识别 UEFI 客户端
dhcp-match=set:efi-x86_64,option:client-arch,7
dhcp-match=set:efi-x86_64,option:client-arch,9

# UEFI 客户端使用 iPXE
dhcp-boot=tag:!ipxe,tag:efi-x86_64,ipxe-mb.efi,,192.168.1.229

# iPXE 第二阶段加载 boot.ipxe
dhcp-boot=tag:ipxe,boot.ipxe,,192.168.1.229
```

## 遇到的错误及解决

### 错误 1: Exec format error

**症状**: iPXE 直接加载 kernel 失败

**解决**: 使用 GRUB 作为中间层

### 错误 2: destination unreachable

**症状**: GRUB 无法访问 TFTP 服务器

**解决**: 在 GRUB 中先执行 `net_bootp` 初始化网络，再配置静态 IP

### 错误 3: couldn't autoconfigure efinet

**症状**: GRUB 无法通过 DHCP 获取 IP

**解决**: 使用静态 IP 配置（`set net_default_ip`）

### 错误 4: Boot option loading failed

**症状**: GRUB 无法加载外部 grub.cfg

**解决**: 将配置内嵌到 GRUB EFI 镜像中（使用 `-c` 参数）

## 最终架构

```
开发板 UEFI 固件
    ↓ (PXE Boot)
iPXE (ipxe-mb.efi) ──→ TFTP 下载 boot.ipxe
    ↓ (执行 boot.ipxe)
GRUB (grubx64.efi) ──→ 内嵌配置自动执行
    ↓ (multiboot 协议)
ArceOS 内核 (kernel)
    ↓
Hello, world!
```

## 关键命令速查

### 手动调试 GRUB

```bash
grub> net_bootp                    # 初始化网络
grub> set net_default_ip=192.168.1.192
grub> set net_default_server=192.168.1.229
grub> multiboot (tftp,192.168.1.229)/kernel
grub> boot
```

### 检查内核格式

```bash
# 检查 multiboot 魔数
hexdump -C kernel | grep "02 b0 ad 1b"

# 或查看文件类型
file kernel  # 显示: data (multiboot 原始二进制)
```

### 测试 TFTP 服务

```bash
# 本地测试
tftp 192.168.1.229 -c get kernel /tmp/test_kernel

# 监控 TFTP 日志
sudo tail -f /var/log/syslog | grep tftp
```

## 经验教训

1. **UEFI iPXE 限制**: 不能直接启动 ELF/multiboot 内核，必须通过 GRUB 等 bootloader

2. **GRUB UEFI 网络**: UEFI 环境下 GRUB 的网络初始化不稳定，静态 IP 比 DHCP 更可靠

3. **配置内嵌**: 将 GRUB 配置内嵌到 EFI 镜像中，避免外部文件加载失败的问题

4. **串口调试**: 物理机调试务必使用串口，屏幕输出可能不可用

## 参考链接

- [iPXE 错误代码](https://ipxe.org/err)
- [GRUB Multiboot 规范](https://www.gnu.org/software/grub/manual/multiboot/multiboot.html)
- [ArceOS 文档](https://github.com/arceos-org/arceos)

---

**调试时间**: 2026-03-17
**调试人员**: Josen-B
**状态**: ✅ 已成功启动
