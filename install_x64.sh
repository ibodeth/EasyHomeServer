#!/usr/bin/env bash
set -e

# --- PARAMETER CHECK ---
RESET=false
if [[ "$1" == "--reset" ]]; then
  RESET=true
fi

# --- 1. RESOLVE USER (SUDO FIX) ---
if [ "$SUDO_USER" ]; then
    REAL_USER=$SUDO_USER
else
    REAL_USER=$(whoami)
fi
REAL_UID=$(id -u $REAL_USER)
REAL_GID=$(id -g $REAL_USER)

BASE_DIR="/home/$REAL_USER/home-server"
COMPOSE_FILE="$BASE_DIR/docker-compose.yml"

echo "🔧 Linux Home Server Installer (v1.0 - x64 Edition)"
echo "-------------------------------------------------------------------"
echo "🖨️  Architecture: x86_64 (Intel/AMD) compatible."
echo "👤  User: $REAL_USER (UID: $REAL_UID)"
echo "🌍  Network: Local IP + Tailscale IP support."
echo "-------------------------------------------------------------------"

# --- 2. CONFIGURATION PROMPTS ---
echo "🔐 PRE-INSTALLATION CONFIGURATION"
echo ""
while true; do
    read -p "👉 Choose a password for the qBittorrent WebUI: " QBIT_PASS
    if [ -z "$QBIT_PASS" ]; then echo "❌ Password cannot be empty!"; else break; fi
done
echo ""
echo "✅ Configuration successfully saved."
echo "-------------------------------------------------------------------"

# --- 3. RESET (CLEANUP) ---
if $RESET; then
  echo "⚠️  RESET MODE: Cleaning up existing configuration..."
  if command -v docker >/dev/null 2>&1; then
    if [ -f "$COMPOSE_FILE" ]; then docker compose -f "$COMPOSE_FILE" down -v || true; fi
    docker stop $(docker ps -a -q) 2>/dev/null || true
    docker rm $(docker ps -a -q) 2>/dev/null || true
    echo "🧹 Cleaning unused images..."
    docker image prune -a -f >/dev/null 2>&1
    docker volume rm portainer_data 2>/dev/null || true
  fi
  if [ -d "$BASE_DIR" ]; then
      echo "🗑️ Deleting files..."
      sudo rm -rf "$BASE_DIR"
  fi
  echo "🧹 Cleanup complete."
fi

# --- 4. SYSTEM AND PRINTER DEPENDENCIES ---
echo "📦 Updating system and installing required packages..."
sudo apt update -y >/dev/null 2>&1
sudo apt install -y curl git net-tools ntfs-3g python3 cups hplip jq >/dev/null 2>&1
sudo usermod -aG lpadmin $REAL_USER
echo "🌍 Enabling printer sharing on network..."
sudo cupsctl --remote-any
sudo systemctl enable cups
sudo systemctl restart cups

# --- 5. DOCKER SETUP ---
if ! command -v docker >/dev/null 2>&1; then
  echo "🐳 Installing Docker..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker $REAL_USER
fi
if ! docker compose version >/dev/null 2>&1; then sudo apt install -y docker-compose-plugin; fi
sudo systemctl enable docker
sudo systemctl start docker
sudo chmod 666 /var/run/docker.sock

# --- 6. DIRECTORY STRUCTURE ---
echo "📁 Creating directories..."
mkdir -p "$BASE_DIR"/{data,nginx,pihole,filebrowser,jellyfin,qbittorrent}
mkdir -p "$BASE_DIR/data"/{downloads,movies,series}
sudo mkdir -p /mnt/external
sudo chmod 777 /mnt/external
touch "$BASE_DIR/filebrowser/filebrowser.db"
chmod 666 "$BASE_DIR/filebrowser/filebrowser.db"

# --- 7. DOCKER COMPOSE CONFIGURATION ---
echo "📝 Generating Docker compose file (x64)..."
cat <<EOF > "$COMPOSE_FILE"
services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data

  nginx:
    image: nginx:alpine
    container_name: web
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - ./nginx:/usr/share/nginx/html:ro

  filebrowser:
    image: filebrowser/filebrowser:latest
    container_name: filebrowser
    user: "0:0"
    restart: unless-stopped
    ports:
      - "8080:80"
    volumes:
      - ./data:/srv
      - ./filebrowser/filebrowser.db:/database.db
      - /mnt/external:/srv/external_disk
    command: --noauth --database /database.db

  pihole:
    image: pihole/pihole:latest
    container_name: pihole
    restart: unless-stopped
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "8081:80"
    environment:
      TZ: "Europe/Istanbul"
      PIHOLE_DNS_: "1.1.1.1;1.0.0.1"
      DNSMASQ_LISTENING: "all"
    dns:
      - 127.0.0.1
      - 1.1.1.1
    volumes:
      - ./pihole:/etc/pihole
      - ./pihole/dnsmasq:/etc/dnsmasq.d

  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    restart: unless-stopped
    ports:
      - "8096:8096"
    volumes:
      - ./jellyfin/config:/config
      - ./jellyfin/cache:/cache
      - ./data:/media
      - /mnt/external:/media/external_disk
    # Hardware Acceleration (Intel/AMD) for x64 Systems
    devices:
      - /dev/dri:/dev/dri
    environment:
      - JELLYFIN_PublishedServerUrl=http://localhost:8096

  qbittorrent:
    image: linuxserver/qbittorrent:latest
    container_name: qbittorrent
    restart: unless-stopped
    environment:
      - PUID=$REAL_UID
      - PGID=$REAL_GID
      - TZ=Europe/Istanbul
      - WEBUI_PORT=8082
    ports:
      - "8082:8082"
      - "6881:6881"
      - "6881:6881/udp"
    volumes:
      - ./qbittorrent/config:/config
      - ./data/downloads:/downloads
      - /mnt/external:/downloads/external_disk

volumes:
  portainer_data:
EOF

# --- 8. GENERATING DASHBOARD ---
echo "🖼️ Generating dashboard..."
cat <<EOF > "$BASE_DIR/nginx/index.html"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Home Server</title>
<style>
:root { --bg-color: #1a1a2e; --card-bg: #16213e; --text-color: #00ADB5; --text-secondary: #eee; --hover-color: #0f3460; }
body { font-family: 'Segoe UI', sans-serif; background-color: var(--bg-color); color: var(--text-secondary); display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; }
h1 { color: var(--text-color); margin-bottom: 40px; font-size: 2.5rem; letter-spacing: 2px; }
.container { display: flex; flex-wrap: wrap; gap: 20px; justify-content: center; max-width: 1200px; }
.card { background-color: var(--card-bg); border-radius: 12px; padding: 25px; width: 180px; text-align: center; text-decoration: none; color: white; transition: all 0.3s ease; border: 1px solid #2a2a4e; }
.card:hover { transform: translateY(-7px); background-color: var(--hover-color); border-color: var(--text-color); box-shadow: 0 10px 20px rgba(0,0,0,0.4); }
.icon { font-size: 3rem; margin-bottom: 10px; display: block; }
.title { font-size: 1.1rem; font-weight: 600; }
.desc { font-size: 0.75rem; opacity: 0.6; margin-top: 5px; }
</style>
</head>
<body>
<h1>🏠 Home Server Dashboard</h1>
<div class="container">
<a id="link-portainer" href="#" class="card"><span class="icon">📦</span><div class="title">Portainer</div><div class="desc">System Management</div></a>
<a id="link-files" href="#" class="card"><span class="icon">📁</span><div class="title">Files</div><div class="desc">File Browser</div></a>
<a id="link-pihole" href="#" class="card"><span class="icon">🛡️</span><div class="title">Pi-hole</div><div class="desc">Ad Blocker</div></a>
<a id="link-jellyfin" href="#" class="card"><span class="icon">🎬</span><div class="title">Jellyfin</div><div class="desc">Media Center</div></a>
<a id="link-qbit" href="#" class="card"><span class="icon">⬇️</span><div class="title">qBittorrent</div><div class="desc">Torrent Downloader</div></a>
<a id="link-cups" href="#" class="card"><span class="icon">🖨️</span><div class="title">Printer</div><div class="desc">CUPS Dashboard</div></a>
</div>
<script>
const host = window.location.hostname;
document.getElementById('link-portainer').href = 'http://' + host + ':9000';
document.getElementById('link-files').href = 'http://' + host + ':8080';
document.getElementById('link-pihole').href = 'http://' + host + ':8081/admin';
document.getElementById('link-jellyfin').href = 'http://' + host + ':8096';
document.getElementById('link-qbit').href = 'http://' + host + ':8082';
document.getElementById('link-cups').href = 'https://' + host + ':631';
</script>
</body>
</html>
EOF

# --- 9. START SERVICES ---
echo "🚀 Starting Docker services..."
cd "$BASE_DIR"
docker compose pull
docker compose up -d

# --- 10. CONFIGURE QBITTORRENT ---
echo "⚙️  Configuring qBittorrent..."
sleep 5
docker stop qbittorrent >/dev/null 2>&1
HASHed_PASS=$(python3 -c "import base64, hashlib, os; salt=os.urandom(16); pwd='$QBIT_PASS'.encode(); h=hashlib.pbkdf2_hmac('sha512', pwd, salt, 100000); print(f'@ByteArray({base64.b64encode(salt).decode()}:{base64.b64encode(h).decode()})')")
CONFIG_DIR="$BASE_DIR/qbittorrent/config/qBittorrent"
mkdir -p "$CONFIG_DIR"
cat <<EOF > "$CONFIG_DIR/qBittorrent.conf"
[LegalNotice]
Accepted=true
[Preferences]
WebUI\CSRFProtection=false
WebUI\ClickjackingProtection=false
WebUI\HostHeaderValidation=false
WebUI\Password_PBKDF2="$HASHed_PASS"
WebUI\Port=8082
WebUI\Username=admin
EOF
docker start qbittorrent >/dev/null 2>&1
echo "✅ qBittorrent configured."

# --- 11. PI-HOLE PASSWORD CONFIGURATION ---
echo ""
echo "🔐 PI-HOLE PASSWORD CONFIGURATION"
echo "⏳ Waiting for Pi-hole to start..."
MAX_RETRIES=30
COUNT=0
while [ $COUNT -lt $MAX_RETRIES ]; do
    if [ "$(docker inspect -f '{{.State.Running}}' pihole 2>/dev/null)" == "true" ]; then
        echo "✅ Pi-hole is active!"
        sleep 5
        docker exec -it pihole pihole setpassword
        break
    fi
    echo "   ...Waiting ($COUNT/$MAX_RETRIES)"
    sleep 2
    COUNT=$((COUNT+1))
done

# --- 12. FILE PERMISSIONS CONFIGURATION ---
echo "🔧 Configuring file permissions..."
sudo chown -R $REAL_USER:$REAL_USER "$BASE_DIR"
sudo chmod -R 777 "$BASE_DIR/data"
sudo chmod -R 777 "$BASE_DIR/nginx"

# --- 13. TAILSCALE SETUP ---
echo "-----------------------------------------------------------------"
if ! command -v tailscale >/dev/null 2>&1; then
  echo "⬇️ Installing Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh
fi
sudo tailscale up || true

# --- 14. INSTALLATION COMPLETE ---
LOCAL_IP=$(hostname -I | awk '{print $1}')
TS_IP=$(tailscale ip -4 2>/dev/null)

echo ""
echo "🎉 INSTALLATION COMPLETE!"
echo "------------------------------------------------------"
echo "🏠 LOCAL NETWORK (LAN): http://$LOCAL_IP"
if [ -n "$TS_IP" ]; then
echo "🌍 TAILSCALE (EXTERNAL): http://$TS_IP"
else
echo "🌍 TAILSCALE:           Not connected (Run 'sudo tailscale up')"
fi
echo "------------------------------------------------------"
echo "🛑 PRINTER SETUP: Run 'sudo hp-setup -i'"