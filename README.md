# 🏠 Pi Home Server 🚀

**Docker + Tailscale + Media + Download + Network Toolbox**

![Docker](https://img.shields.io/badge/Docker-Ready-blue?style=for-the-badge\&logo=docker)
![Raspberry](https://img.shields.io/badge/Raspberry%20Pi-ARM64-red?style=for-the-badge\&logo=raspberrypi)
![Linux](https://img.shields.io/badge/Linux-Debian-green?style=for-the-badge\&logo=linux)
![License](https://img.shields.io/badge/license-MIT-success?style=for-the-badge)

**Pi Home Server** is a fully automated **personal home server solution** for Raspberry Pi and Linux machines.
It is **installed with a single command**, **Docker-based**, and includes **media, file sharing, torrent, DNS, and a unified dashboard**.

After installation, just open your browser and manage everything from one panel.

---

## ⚡ Installation (One Command)

### 🥧 Raspberry Pi

```bash
curl -fsSL https://raw.githubusercontent.com/ibodeth/pi-home-server/main/install.sh -o /tmp/install.sh && sudo bash /tmp/install.sh
```

---

### 💻 PC / Server

```bash
curl -fsSL https://raw.githubusercontent.com/ibodeth/pi-home-server/main/install_x64.sh -o /tmp/install_x64.sh && sudo bash /tmp/install_x64.sh
```

---

## ✨ Features

### 📦 Docker-Based Architecture

* Automatic Docker installation
* Docker Compose service management
* ARM64 optimized

---

### 🖥️ Web Dashboard

An automatic dashboard is created after setup:

* Portainer
* FileBrowser
* Pi-hole
* Jellyfin
* qBittorrent
* CUPS Printer

All services in a single page.

---

### 📁 File Server

* FileBrowser web UI
* Local disk + external disk mount
* Upload / download from browser

---

### 🍿 Media Server

* Jellyfin media center
* Movies / Series / Music
* Mobile, TV and desktop compatible

---

### ⬇️ Torrent Management

* qBittorrent WebUI
* Automatic password hashing
* Download directory management

---

### 🛡️ Network & DNS

* Pi-hole ad blocker
* Local DNS cache
* Remote access with Tailscale

---

### 🖨️ Print Server

* Native CUPS
* Network printing
* HP driver support

---

### 🌍 Remote Access

* Automatic Tailscale installation
* Shows Local IP + Tailscale IP
* Access from outside your home

---

## 🧠 Architecture Overview

```
User
 └── Browser
     └── Nginx Dashboard
         ├── Portainer
         ├── FileBrowser
         ├── Pi-hole
         ├── Jellyfin
         ├── qBittorrent
         └── CUPS
```

All services run as Docker containers.
The system is lightweight, fast and modular.

---

## 📋 Requirements

* Raspberry Pi 4 / 5 (recommended)
* Debian / Ubuntu / Raspberry Pi OS
* 64-bit OS
* Internet connection
* Minimum 2GB RAM

---



During installation:

* qBittorrent password is requested
* Pi-hole admin password is set
* Dashboard is created automatically

---

## ▶️ Usage

After installation you will see:

```text
LAN:        http://192.168.x.x
TAILSCALE:  http://100.x.x.x
```

Open in browser → manage everything from the dashboard.

---

## ♻️ Reset Mode

For a clean reinstall:

```bash
sudo bash install.sh --reset
```

* Removes containers
* Cleans volumes
* Reinstalls everything

---

## 📂 Service Ports

| Service     | Port |
| ----------- | ---- |
| Dashboard   | 80   |
| Portainer   | 9000 |
| FileBrowser | 8080 |
| Pi-hole     | 8081 |
| Jellyfin    | 8096 |
| qBittorrent | 8082 |
| CUPS        | 631  |

---

## 🔐 Security

* qBittorrent PBKDF2 hash
* Pi-hole admin password
* Tailscale VPN
* Local network isolation

---

## 🛠 Technologies Used

* Bash
* Docker
* Docker Compose
* Nginx
* Jellyfin
* FileBrowser
* Pi-hole
* qBittorrent
* Portainer
* Tailscale
* CUPS

---

## 👨‍💻 Developer

**İbrahim Nuryağınlı**

* YouTube: [https://www.youtube.com/@ibrahim.python](https://www.youtube.com/@ibrahim.python)
* GitHub: [https://github.com/ibodeth](https://github.com/ibodeth)
* LinkedIn: [https://www.linkedin.com/in/ibrahimnuryaginli](https://www.linkedin.com/in/ibrahimnuryaginli)
* Website: [https://ibodeth.github.io](https://ibodeth.github.io)

---

## 📄 License

This project is licensed under the **MIT License**.
See the `LICENSE` file for details.

---

⭐ If you like the project, don’t forget to give it a star!
