#!/usr/bin/env bash
set -e

# --- PARAMETRE KONTROLÜ ---
RESET=false
if [[ "$1" == "--reset" ]]; then
  RESET=true
fi

BASE_DIR="$HOME/pi-home-server"
COMPOSE_FILE="$BASE_DIR/docker-compose.yml"

echo "🔧 Raspberry Pi Home Server Installer (v7.0 - Hybrid Edition)"
echo "-------------------------------------------------------------------"
echo "🖨️  Mimari: Uygulamalar Docker'da, Yazıcı Ana Sistemde (Native) çalışacak."
echo "-------------------------------------------------------------------"

# -------------------------
# 1. ŞİFRELERİ BAŞTA AL
# -------------------------
echo "🔐 KURULUM ÖNCESİ YAPILANDIRMA"
echo ""

# qBittorrent Şifresi
while true; do
    read -p "👉 qBittorrent arayüz şifresi ne olsun?: " QBIT_PASS
    if [ -z "$QBIT_PASS" ]; then echo "❌ Şifre boş olamaz!"; else break; fi
done

echo ""
echo "ℹ️  Not: Yazıcı paneline (CUPS) girmek için Raspberry Pi kullanıcı adını (ibo) ve şifreni kullanacaksın."
echo "✅ Bilgiler alındı."
echo "-------------------------------------------------------------------"

# -------------------------
# 2. RESET (TAM TEMİZLİK)
# -------------------------
if $RESET; then
  echo "⚠️  RESET MODE: Temizlik yapılıyor..."
  
  # Docker temizliği
  if command -v docker >/dev/null 2>&1; then
    if [ -f "$COMPOSE_FILE" ]; then docker compose -f "$COMPOSE_FILE" down -v || true; fi
    # Eski CUPS konteyneri varsa zorla sil
    docker stop cups 2>/dev/null || true
    docker rm cups 2>/dev/null || true
    docker volume rm portainer_data 2>/dev/null || true
  fi
  
  # Dosya temizliği
  if [ -d "$BASE_DIR" ]; then
      echo "🗑️ Dosyalar siliniyor (Sudo yetkisi gerekebilir)..."
      sudo rm -rf "$BASE_DIR"
  fi
  
  echo "🧹 Eski dosyalar temizlendi."
fi

# -------------------------
# 3. SİSTEM VE YAZICI KURULUMU (HYBRID KISIM)
# -------------------------
echo "📦 Sistem güncelleniyor ve YAZICI SÜRÜCÜLERİ (Native) kuruluyor..."
sudo apt update -y >/dev/null 2>&1

# HPLIP (HP Sürücüleri) ve CUPS'ı ana sisteme kuruyoruz
sudo apt install -y curl git net-tools ntfs-3g python3 cups hplip >/dev/null 2>&1

# Kullanıcıyı yazıcı yöneticisi yap
sudo usermod -aG lpadmin $USER

# CUPS'ı dış dünyaya aç (Telefondan yazdırmak için şart)
echo "🌍 Yazıcı sunucusu ağa açılıyor..."
sudo cupsctl --remote-any
sudo systemctl enable cups
sudo systemctl restart cups

# Docker Kurulumu
if ! command -v docker >/dev/null 2>&1; then
  echo "🐳 Docker kuruluyor..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker $USER
fi

# Docker Compose Eklentisi
if ! docker compose version >/dev/null 2>&1; then sudo apt install -y docker-compose-plugin; fi

sudo systemctl enable docker
sudo systemctl start docker

# -------------------------
# 4. DOSYA YAPISI
# -------------------------
echo "📁 Dizinler oluşturuluyor..."
# CUPS klasörüne artık gerek yok, çünkü native çalışıyor
mkdir -p "$BASE_DIR"/{data,nginx,pihole,filebrowser,jellyfin,qbittorrent}
mkdir -p "$BASE_DIR/data"/{downloads,movies,series}
sudo mkdir -p /mnt/external
sudo chmod 777 /mnt/external
touch "$BASE_DIR/filebrowser/filebrowser.db"
chmod 666 "$BASE_DIR/filebrowser/filebrowser.db"

# -------------------------
# 5. DOCKER COMPOSE OLUŞTURMA (CUPS YOK)
# -------------------------
echo "📝 Docker konfigürasyonu hazırlanıyor..."

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

  qbittorrent:
    image: linuxserver/qbittorrent:latest
    container_name: qbittorrent
    restart: unless-stopped
    environment:
      - PUID=$(id -u)
      - PGID=$(id -g)
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

# -------------------------
# 6. DASHBOARD OLUŞTURMA
# -------------------------
cat <<EOF > "$BASE_DIR/nginx/index.html"
<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pi Home Server</title>
    <style>
        :root { --bg-color: #1a1a2e; --card-bg: #16213e; --text-color: #e94560; --text-secondary: #fff; --hover-color: #0f3460; }
        body { font-family: 'Segoe UI', sans-serif; background-color: var(--bg-color); color: var(--text-secondary); display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; }
        h1 { color: var(--text-color); margin-bottom: 40px; font-size: 2.5rem; text-shadow: 2px 2px 4px rgba(0,0,0,0.5); }
        .container { display: flex; flex-wrap: wrap; gap: 20px; justify-content: center; }
        .card { background-color: var(--card-bg); border-radius: 15px; padding: 30px; width: 200px; text-align: center; text-decoration: none; color: white; transition: transform 0.3s, background-color 0.3s; box-shadow: 0 4px 6px rgba(0,0,0,0.3); }
        .card:hover { transform: translateY(-5px); background-color: var(--hover-color); }
        .icon { font-size: 3rem; margin-bottom: 15px; display: block; }
        .title { font-size: 1.2rem; font-weight: bold; }
        .desc { font-size: 0.8rem; opacity: 0.7; margin-top: 5px; }
    </style>
</head>
<body>
    <h1>🚀 Pi Home Server</h1>
    <div class="container">
        <a id="link-portainer" href="#" class="card"><span class="icon">📦</span><div class="title">Portainer</div><div class="desc">Sistem Yönetimi</div></a>
        <a id="link-files" href="#" class="card"><span class="icon">📁</span><div class="title">Dosyalar</div><div class="desc">File Browser</div></a>
        <a id="link-pihole" href="#" class="card"><span class="icon">🛡️</span><div class="title">Pi-hole</div><div class="desc">Reklam Engelleyici</div></a>
        <a id="link-jellyfin" href="#" class="card"><span class="icon">🍿</span><div class="title">Jellyfin</div><div class="desc">Film & Dizi İzle</div></a>
        <a id="link-qbit" href="#" class="card"><span class="icon">⬇️</span><div class="title">qBittorrent</div><div class="desc">Torrent İndirici</div></a>
        <a id="link-cups" href="#" class="card"><span class="icon">🖨️</span><div class="title">Yazıcı</div><div class="desc">CUPS (Native)</div></a>
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

# -------------------------
# 7. SERVİSLERİ BAŞLAT
# -------------------------
echo "🚀 Docker servisleri başlatılıyor..."
cd "$BASE_DIR"
docker compose up -d

echo ""
echo "⏳ Konteynerlerin tam açılması için 10 saniye bekleniyor..."
sleep 10

# -------------------------
# 8. QBITTORRENT AYARI
# -------------------------
echo "⚙️  qBittorrent şifresi ve 'Unauthorized' hatası ayarlanıyor..."
docker stop qbittorrent >/dev/null 2>&1
HASHed_PASS=$(python3 -c "import base64, hashlib, os; salt = os.urandom(16); pwd = '$QBIT_PASS'.encode(); h = hashlib.pbkdf2_hmac('sha512', pwd, salt, 100000); print(f'@ByteArray({base64.b64encode(salt).decode()}:{base64.b64encode(h).decode()})')")
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
echo "✅ qBittorrent ayarlandı."

# -------------------------
# 9. PI-HOLE ŞİFRE AYARI
# -------------------------
echo ""
echo "🔐 PI-HOLE ŞİFRE AYARI"
echo "------------------------------------------------------------------"
echo "👉 Birazdan Pi-hole şifre ekranı açılacak."
echo "👉 İstediğin şifreyi yaz ve Enter'a bas (Ekranda görünmez)."
echo "------------------------------------------------------------------"
docker exec -it pihole pihole setpassword
echo "✅ Pi-hole şifresi kaydedildi!"

# -------------------------
# 10. TAILSCALE
# -------------------------
echo "-----------------------------------------------------------------"
if ! command -v tailscale >/dev/null 2>&1; then
  echo "⬇️ Tailscale indiriliyor..."
  curl -fsSL https://tailscale.com/install.sh | sh
fi
echo "🔄 Tailscale servisleri kontrol ediliyor..."
sudo tailscale up

# -------------------------
# 11. BİTİŞ VE HP YAZICI KURULUMU
# -------------------------
LOCAL_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "🎉 UYGULAMALAR KURULDU! ŞİMDİ YAZICI ZAMANI..."
echo "====================================================="
echo "🌍 DASHBOARD: http://$LOCAL_IP"
echo "====================================================="
echo ""
echo "🛑 SON ADIM: HP YAZICINI USB İLE BAĞLA 🛑"
echo "HP LaserJet P1102 gibi yazıcılar için şu işlemi bir kez yapmalısın:"
echo ""
echo "    1. Yazıcıyı USB'ye tak ve aç."
echo "    2. Şu komutu yaz ve yönergeleri izle:"
echo "       sudo hp-setup -i"
echo "    3. (Connection: 'b' -> USB, Firmware Download: 'y')"
echo ""
echo "Bu işlemden sonra yazıcın 'Filtre Hatası' vermeden çalışacaktır."
echo "Güle güle kullan!"