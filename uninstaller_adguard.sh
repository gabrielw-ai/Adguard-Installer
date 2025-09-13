#!/bin/bash
set -e

echo "⚠️ Uninstaller AdGuard Home + SSL + DNS Resolver"

read -p "Yakin ingin menghapus semuanya? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
  echo "❌ Proses dibatalkan."
  exit 1
fi

# Stop & remove AdGuard
echo "🧼 Menghapus AdGuard Home..."
sudo systemctl stop AdGuardHome
sudo systemctl disable AdGuardHome
sudo rm -rf /opt/AdGuardHome
sudo rm -f /etc/systemd/system/AdGuardHome.service
sudo systemctl daemon-reexec
sudo systemctl daemon-reload

# Remove SSL certs
read -p "Hapus sertifikat SSL juga? (y/n): " SSL_CONFIRM
if [[ "$SSL_CONFIRM" == "y" ]]; then
  read -p "Masukkan domain SSL yang ingin dihapus: " DOMAIN
  sudo rm -rf "/etc/letsencrypt/live/$DOMAIN"
  sudo rm -rf "/etc/letsencrypt/archive/$DOMAIN"
  sudo rm -rf "/etc/letsencrypt/renewal/$DOMAIN.conf"
  echo "🔒 Sertifikat SSL untuk $DOMAIN dihapus."
fi

# Restore DNS resolver
echo "🔁 Mengembalikan systemd-resolved..."
sudo chattr -i /etc/resolv.conf
echo "nameserver 127.0.0.53" | sudo tee /etc/resolv.conf
sudo systemctl enable systemd-resolved
sudo systemctl start systemd-resolved

echo "✅ Uninstall selesai."

