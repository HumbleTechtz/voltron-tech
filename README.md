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

---

## ⚡ **Quick Installation**

### **One-Line Installation**
```bash
curl -s https://raw.githubusercontent.com/HumbleTechtz/voltron-tech/main/install.sh | bash
```

Manual Installation

```bash
wget https://raw.githubusercontent.com/HumbleTechtz/voltron-tech/main/main.sh
chmod +x main.sh
./main.sh
```

Auto-Install Mode

```bash
curl -s https://raw.githubusercontent.com/HumbleTechtz/voltron-tech/main/main.sh | bash -s -- --auto
```

---

📖 Usage

After installation, type:

```bash
menu
```

Or

```bash
voltron
```

Main Menu Options

```
╔═══════════════════════════════════════════════════════════════╗
║                    👤 USER MANAGEMENT                         ║
╠═══════════════════════════════════════════════════════════════╣
║  1) Create New User         5) Unlock User Account            ║
║  2) Delete User             6) List All Managed Users         ║
║  3) Edit User Details       7) Renew User Account             ║
║  4) Lock User Account                                          ║
╠═══════════════════════════════════════════════════════════════╣
║                    ⚙️ SYSTEM UTILITIES                        ║
╠═══════════════════════════════════════════════════════════════╣
║  8) Protocols & Panels      12) SSH Banner                    ║
║  9) Backup Users            13) Cleanup Expired                ║
║ 10) Restore Users           14) MTU Optimization              ║
║ 11) DNS Domain              15) DT Proxy                       ║
╠═══════════════════════════════════════════════════════════════╣
║                    🔥 DANGER ZONE                             ║
╠═══════════════════════════════════════════════════════════════╣
║ 99) Uninstall Script        0) Exit                            ║
╚═══════════════════════════════════════════════════════════════╝
```

---

📡 MTU Optimization

MTU Selection Menu

```
╔═══════════════════════════════════════════════════════════════╗
║           📡 VOLTRON TECH ULTIMATE MTU OPTIMIZATION          ║
║              🔥 MTU 512 NOW HAS 512MB BUFFERS! 🔥             ║
╠═══════════════════════════════════════════════════════════════╣
║  [01] MTU 512   - ⚡⚡⚡ ULTRA BOOST (512MB buffers!)         ║
║  [02] MTU 800   - ⚡⚡ HYPER BOOST MODE                       ║
║  [03] MTU 1000  - ⚡⚡ SUPER BOOST MODE                       ║
║  [04] MTU 1200  - ⚡⚡ MEGA BOOST MODE                        ║
║  [05] MTU 1500  - ⚡⚡ TURBO BOOST MODE                       ║
║  [06] MTU 1600  - ⚡⚡ JUMBO BOOST MODE                       ║
║  [07] MTU 1700  - ⚡⚡ EXTREME BOOST MODE                     ║
║  [08] MTU 1800  - 🔥 ULTIMATE BOOST MODE                     ║
║  [09] Auto-detect optimal MTU                                 ║
║  [10] View Current MTU Settings                               ║
║  [11] Restart Loss Protection                                 ║
╚═══════════════════════════════════════════════════════════════╝
```

MTU 512 Ultimate Boost

· Buffers: 512MB (instead of default 20MB)
· FEC Ratio: 1.5x - 4.0x (up to 300% redundancy)
· Packet Duplication: 2x - 4x
· Speed: Up to 12 Mbps (same as MTU 1800 on bad networks)

---

🔌 Protocols & Panels

Option Protocol Description
1 badvpn UDP gateway on port 7300
2 udp-custom Custom UDP proxy
3 SSL Tunnel HAProxy SSL tunnel for SSH
4 DNSTT DNS tunnel on port 53 (SlowDNS)
5 VOLTRON Proxy WebSocket/Socks proxy
6 Nginx Proxy HTTP/HTTPS reverse proxy
7 ZiVPN UDP VPN on port 5667
8 X-UI Panel X-UI management panel
9 DT Proxy DTunnel proxy

Each protocol shows (installed) status when active.

---

👥 User Management

Create User

```
👉 Enter username: testuser
👉 Enter password: ********
👉 Enter expire days: 30
👉 Enter connection limit: 2

✅ User 'testuser' created successfully!

  - 👤 Username:          testuser
  - 🔑 Password:          ********
  - 🗓️ Expires on:        2026-03-23
  - 📶 Connection Limit:  2
```

List Users

```
╔═══════════════════════════════════════════════════════════════╗
║                      📋 MANAGED USERS                         ║
╠═══════════════════════════════════════════════════════════════╣
║ USERNAME    | EXPIRES    | CONNECTIONS | STATUS               ║
╠───────────────────────────────────────────────────────────────╣
║ testuser    | 2026-03-23 | 1 / 2       | ACTIVE              ║
║ admin       | 2026-04-01 | 0 / 5       | ACTIVE              ║
║ guest       | 2026-02-15 | 0 / 1       | EXPIRED             ║
╚═══════════════════════════════════════════════════════════════╝
```

User Status Colors

· 🟢 ACTIVE - Account is active and within expiry
· 🟡 LOCKED - Account is locked by admin
· 🔴 EXPIRED - Account has passed expiry date

---

📊 Performance

Speed Estimates for MTU 512

Network Condition Before Booster After Booster Improvement
Good (Loss 1%) 6-8 Mbps 9-12 Mbps +50%
Average (Loss 5%) 2-3 Mbps 7-9 Mbps +200%
Bad (Loss 10%) 1-1.5 Mbps 5-7 Mbps +400%
Very Bad (Loss 15%) 0.5-0.8 Mbps 4-6 Mbps +600%

MTU 512 vs MTU 1800

Network MTU 512 MTU 1800 Winner
Good (1% loss) 10 Mbps 22 Mbps MTU 1800
Average (5% loss) 8 Mbps 9 Mbps Almost equal
Bad (10% loss) 6 Mbps 6 Mbps Equal
Very Bad (15% loss) 5 Mbps 4 Mbps MTU 512

---

🗑️ Uninstall

To completely remove VOLTRON TECH:

```bash
# From main menu, select option 99
# Or run:
voltron-uninstall
```

Warning: This will remove all configurations and data including users, protocols, and settings!

---

❓ FAQ

Q: Which MTU should I choose?

A:

· MTU 512 - Best for bad networks (high loss, high latency)
· MTU 800-1000 - Good for mobile networks
· MTU 1500 - Standard for good networks
· MTU 1800 - Maximum speed for perfect networks

Q: How do I get my public key?

A: After installing DNSTT (option 4 in protocols menu), the public key is displayed. You can also view it later by selecting "View Details" from the DNSTT menu.

Q: Does it work on all Linux distributions?

A: Yes! Supports Ubuntu, Debian, CentOS, Rocky Linux, AlmaLinux, Fedora, RHEL, Amazon Linux, Arch, openSUSE.

Q: How do I backup my users?

A: Use option 9 in the main menu to backup all user data. The backup file will be saved as /root/voltrontech_users.tar.gz.

Q: Can I change MTU after installation?

A: Yes! Use option 14 (MTU Optimization) in the main menu to change MTU anytime.

Q: What if Cloudflare auto-generation fails?

A: The script automatically switches to manual mode where you can enter your own domains.

Q: How do I know if a protocol is installed?

A: In the protocols menu, installed protocols show (installed) in blue next to their name.

---

🆘 Support

Contact Information

· WhatsApp: +255 65451444
· Email: voltrontechtx@gmail.com
· GitHub: HumbleTechtz/voltron-tech

Report Issues

If you encounter any problems, please create an issue on GitHub.

---

📜 License

This project is licensed under the MIT License.

```
MIT License

Copyright (c) 2026 VOLTRON TECH

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

⭐ Show Your Support

If you find this project useful, please consider giving it a ⭐ on GitHub!

---

<p align="center">
  <b>Made with ❤️ in Tanzania</b><br>
  <i>VOLTRON TECH - GLOBAL TECHNOLOGY</i>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/WhatsApp-25D366?style=for-the-badge&logo=whatsapp&logoColor=white">
  <img src="https://img.shields.io/badge/GitHub-100000?style=for-the-badge&logo=github&logoColor=white">
  <img src="https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black">
</p>
```
