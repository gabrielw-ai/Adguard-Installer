#!/bin/bash
set -e

echo "🚀 AdGuard Home Installer — Ubuntu/CentOS Edition"

# Validasi OS
OS=$(grep ^ID= /etc/os-release | cut -d= -f2 | tr -d '"')
ARCH=$(uname -m)

if [[ "$OS" != "ubuntu" && "$OS" != "centos" ]]; then
  echo "❌ OS tidak didukung: $OS. Hanya Ubuntu dan CentOS yang didukung."
  exit 1
fi

echo "🧠 OS: $OS | Arsitektur: $ARCH"

# Step 1: Preinstallation
echo "🔧 Setup HTTPS & DNS Validation"
read -p "Masukkan nama domain DNS (contoh: dns.ratcha.net): " DOMAIN
SERVER_IP=$(curl -s https://ipinfo.io/ip)
DNS_IP=$(dig +short "$DOMAIN")

if [[ "$DNS_IP" != "$SERVER_IP" ]]; then
  echo "❌ ERROR: DNS $DOMAIN belum mengarah ke IP server ($SERVER_IP)."
  exit 1
else
  echo "✅ DNS $DOMAIN sudah mengarah ke IP server."
fi

if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
  echo "🔒 SSL untuk $DOMAIN sudah terpasang."
else
  echo "🔐 Memasang SSL dengan Certbot..."
  sudo apt update
  sudo apt install -y certbot
  sudo certbot certonly --standalone -d "$DOMAIN"
fi

# Step 2: Installasi AdGuard
read -p "Lanjutkan installasi AdGuard Home? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
  echo "❌ Installasi dibatalkan."
  exit 1
fi

echo "📦 Mengunduh dan menginstall AdGuard Home..."
curl -s -S -L https://static.adguard.com/adguardhome/release/AdGuardHome_linux_amd64.tar.gz -o adguard.tar.gz
tar -xzf adguard.tar.gz
cd AdGuardHome
sudo ./AdGuardHome -s install

# Auto-start AdGuard Home
echo "🔁 Memastikan AdGuard Home berjalan sebagai service..."
sudo systemctl enable AdGuardHome
sudo systemctl start AdGuardHome
sudo systemctl status AdGuardHome --no-pager

# Step 3: Free Port 53
echo "🔓 Membebaskan port 53 dari systemd-resolved..."
sudo systemctl disable systemd-resolved
sudo systemctl stop systemd-resolved
sudo rm -f /etc/resolv.conf

echo "🧠 Pilih DNS resolver:"
echo "1) 1.1.1.1 (Cloudflare)"
echo "2) 8.8.8.8 (Google)"
echo "3) 9.9.9.9 (Quad9)"
read -p "Masukkan pilihan (1/2/3): " DNS_CHOICE

case "$DNS_CHOICE" in
  1) DNS="1.1.1.1" ;;
  2) DNS="8.8.8.8" ;;
  3) DNS="9.9.9.9" ;;
  *) echo "❌ Pilihan tidak valid."; exit 1 ;;
esac

echo "nameserver $DNS" | sudo tee /etc/resolv.conf
sudo chattr +i /etc/resolv.conf

# Final
echo "🎉 AdGuard Home siap digunakan!"
echo "🔗 Buka di browser: http://$SERVER_IP:3000"

