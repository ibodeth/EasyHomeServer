# EasyHomeServer

An automated installation script to set up a dockerized personal home server environment on Linux or Raspberry Pi systems.

## How it Works
The installation script installs Docker and Docker Compose on the host machine, pulls and runs services (Portainer, FileBrowser, Pi-hole, Jellyfin, qBittorrent, CUPS, and Tailscale), and mounts the configured reverse proxy dashboard on local ports for unified network access and file administration.

## Tech Stack
- **Languages/Frameworks:** Bash, HTML
- **Services/Libraries:** Nginx, Jellyfin, FileBrowser, Pi-hole, qBittorrent, Portainer, Tailscale, CUPS
- **Infrastructure:** Docker, Docker Compose, Linux/Raspberry Pi OS

## Local Setup
1. Clone the repository:
   ```bash
   git clone https://github.com/ibodeth/EasyHomeServer.git
   cd EasyHomeServer
   ```
2. Run the installer script for Raspberry Pi:
   ```bash
   sudo bash install.sh
   ```
   Or for x86/x64 systems:
   ```bash
   sudo bash install_x64.sh
   ```
3. Access the dashboard in your browser at:
   ```text
   http://localhost
   ```

## License
MIT
