#!/bin/bash
set -e

echo "🚀 AdGuard Home Installer — Ubuntu/CentOS Edition"

# OS Validation
OS=$(grep ^ID= /etc/os-release | cut -d= -f2 | tr -d '"')
ARCH=$(uname -m)

if [[ "$OS" != "ubuntu" && "$OS" != "centos" ]]; then
  echo "❌ Unsupported OS: $OS. Only Ubuntu and CentOS are supported."
  exit 1
fi

echo "🧠 OS: $OS | Architecture: $ARCH"

# Step 1: Preinstallation
echo "🔧 Setting up HTTPS & DNS Validation"
read -p "Enter your DNS domain name (e.g. dns.ratcha.net): " DOMAIN
SERVER_IP=$(curl -s https://ipinfo.io/ip)
DNS_IP=$(dig +short "$DOMAIN")

if [[ "$DNS_IP" != "$SERVER_IP" ]]; then
  echo "❌ ERROR: DNS $DOMAIN is not pointing to the server IP ($SERVER_IP)."
  exit 1
else
  echo "✅ DNS $DOMAIN is correctly pointing to the server IP."
fi

if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
  echo "🔒 SSL for $DOMAIN is already installed."
else
  echo "🔐 Installing SSL with Certbot..."
  sudo apt update
  sudo apt install -y certbot
  sudo certbot certonly --standalone -d "$DOMAIN"
fi

# Step 2: Install AdGuard
read -p "Proceed with AdGuard Home installation? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
  echo "❌ Installation cancelled."
  exit 1
fi

echo "📦 Downloading and installing AdGuard Home..."
curl -s -S -L https://static.adguard.com/adguardhome/release/AdGuardHome_linux_amd64.tar.gz -o adguard.tar.gz
tar -xzf adguard.tar.gz
cd AdGuardHome
sudo ./AdGuardHome -s install

# Auto-start AdGuard Home
echo "🔁 Ensuring AdGuard Home is running as a service..."
sudo systemctl enable AdGuardHome
sudo systemctl start AdGuardHome
sudo systemctl status AdGuardHome --no-pager

# Step 3: Free Port 53
echo "🔓 Freeing up port 53 from systemd-resolved..."
sudo systemctl disable systemd-resolved
sudo systemctl stop systemd
