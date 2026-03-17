# ArceOS PXE 启动快速指南

## 环境要求

- 服务器：Ubuntu 22.04+，网卡 `enp3s0`，IP `192.168.1.229`
- 开发板：x86_64 UEFI 模式，支持网络启动
- 连接：网线直连或同一局域网

## 快速开始（3步）

### 1. 部署 PXE 环境

```bash
cd /code/pxe/scripts
sudo ./pxe-physical-deploy.sh --install --mode direct
```

### 2. 开发板设置

1. 进入 BIOS，设置为 **UEFI 模式**
2. 启用 **Network Boot / PXE Boot**
3. 重启，按 **F12/F11** 选择网络启动

### 3. 观察启动

开发板将自动：
- 获取 IP 地址
- 下载 iPXE → GRUB → ArceOS 内核
- 启动 ArceOS，显示 `Hello, world!`

## 常用命令

```bash
# 查看服务状态
sudo ./pxe-physical-deploy.sh --status

# 切换模式（直连/代理）
sudo ./switch-mode.sh direct      # 直连模式
sudo ./switch-mode.sh proxy       # 代理模式
sudo ./switch-mode.sh status      # 查看当前模式

# 监控传输
sudo ./monitor-pxe-tftp.sh

# 重启服务
sudo systemctl restart dnsmasq
```

## 文件说明

### 项目目录结构

```
/code/pxe/
├── doc/
│   └── QUICK_START.md       # 本文档
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

### 运行时文件位置

部署后，启动文件会被复制到：

```
/var/lib/tftpboot/
├── ipxe-mb.efi      # iPXE 引导程序
├── grubx64.efi      # GRUB EFI 引导程序
├── boot.ipxe        # iPXE 启动脚本
└── kernel           # ArceOS 内核
```

### 启动文件说明

| 文件 | 大小 | 功能 | 来源 |
|------|------|------|------|
| `ipxe-mb.efi` | 1.2M | UEFI 网络引导程序，支持 multiboot | 预编译 |
| `grubx64.efi` | 704K | GRUB2 EFI 镜像，内嵌配置，加载内核 | 动态生成 |
| `boot.ipxe` | 192B | iPXE 启动脚本，链式加载 GRUB | 静态配置 |
| `kernel` | 77K | ArceOS 内核 (multiboot 格式) | 编译生成 |

## 故障排查

| 问题 | 解决 |
|------|------|
| 无法获取 IP | 检查网线，确认 `switch-mode.sh direct` |
| TFTP 失败 | 检查防火墙：`sudo ufw disable` |
| 内核不启动 | 确认 BIOS 为 UEFI 模式 |

## 技术栈

- **DHCP/TFTP**: dnsmasq
- **网络引导**: iPXE (支持 multiboot)
- **内核加载**: GRUB2 (EFI)
- **启动协议**: multiboot

---

完整配置说明见 [README.md](../README.md)
