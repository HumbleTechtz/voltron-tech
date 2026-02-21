# ⚡ VOLTRON TECH ULTIMATE - SSH Over DNSTT Manager

<p align="center">
  <img src="https://img.shields.io/badge/Version-4.0-blue?style=for-the-badge">
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge">
  <img src="https://img.shields.io/badge/OS-Linux%20%7C%20Ubuntu%20%7C%20Debian%20%7C%20CentOS%20%7C%20Fedora-orange?style=for-the-badge">
  <img src="https://img.shields.io/badge/Arch-x86__64%20%7C%20ARM64-purple?style=for-the-badge">
</p>

<p align="center">
  <b>Ultimate SSH + DNS Tunnel Manager with BBR Optimization, MTU Booster, and Zero Loss Protection</b>
</p>

---

## 📋 **Table of Contents**
- [Features](#-features)
- [Supported OS](#-supported-os)
- [Quick Installation](#-quick-installation)
- [Usage](#-usage)
- [MTU Optimization](#-mtu-optimization)
- [Protocols & Panels](#-protocols--panels)
- [User Management](#-user-management)
- [Performance](#-performance)
- [Uninstall](#-uninstall)
- [Screenshots](#-screenshots)
- [FAQ](#-faq)
- [Support](#-support)
- [License](#-license)

---

## 🚀 **Features**

| Feature | Description |
|---------|-------------|
| **SSH User Management** | Create, delete, lock, unlock, list, renew users |
| **DNS Tunnel (DNSTT)** | SlowDNS server with automatic key generation |
| **MTU Optimization** | Support for 512-1800 MTU with per-MTU boosters |
| **BBR Congestion Control** | Enable BBR for maximum speed |
| **Loss Protection** | FEC + Packet Duplication - Zero packet loss guaranteed |
| **Traffic Monitoring** | Monitor user connections in real-time |
| **Auto Expiry Remover** | Automatically remove expired users |
| **Cloudflare Integration** | Auto-generate DNS records |
| **Multiple Protocols** | badvpn, udp-custom, SSL Tunnel, Nginx Proxy, ZiVPN, X-UI Panel, DT Proxy |
| **Firewall Management** | Auto-configure UFW, firewalld, iptables |
| **System Detection** | Works on all Linux distributions |

---

## 💻 **Supported OS**

| Distribution | Versions | Status |
|--------------|----------|--------|
| **Ubuntu** | 18.04, 20.04, 22.04, 24.04 | ✅ Full Support |
| **Debian** | 10, 11, 12, 13 | ✅ Full Support |
| **CentOS** | 7, 8, 9 | ✅ Full Support |
| **Rocky Linux** | 8, 9 | ✅ Full Support |
| **AlmaLinux** | 8, 9 | ✅ Full Support |
| **Fedora** | 38, 39, 40 | ✅ Full Support |
| **RHEL** | 7, 8, 9 | ✅ Full Support |
| **Amazon Linux** | 2, 2023 | ✅ Full Support |
| **Arch Linux** | Latest | ✅ Full Support |
| **openSUSE** | 15.x | ✅ Full Support |

### **Architectures**
- ✅ x86_64 (amd64)
- ✅ ARM64 (aarch64)
- ✅ ARM32 (armv7l) - Limited support

---

## ⚡ **Quick Installation**

### **One-Line Installation**
```bash
curl -s https://raw.githubusercontent.com/HumbleTechtz/voltron-tech/main/install.sh | bash
