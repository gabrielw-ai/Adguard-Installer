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
read -p "Enter your DNS domain name (e.g. dns.domain.com): " DOMAIN
SERVER_IP=$(curl -s https://ipinfo.io/ip)
DNS_IP=$(dig +short "$DOMAIN")

if [[ "$DNS_IP" != "$SERVER_IP" ]]; then
  echo "❌ ERROR: DNS $DOMAIN is not pointing to the server IP ($SERVER_IP)."
  exit 1
else
  echo "✅ DNS $DOMAIN is correctly pointing to the server IP."
fi

if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
  echo "🔒 SSL certificate for $DOMAIN is already installed."
else
  echo "🔐 This script will now install an SSL certificate for $DOMAIN using Certbot."
  echo "ℹ️ Make sure ports 80 and 443 are open and not blocked by firewall or other services."
  read -p "Proceed with SSL installation? (y/yes/n/no): " SSL_CONFIRM
  case "$SSL_CONFIRM" in
    y|yes)
      sudo apt update
      sudo apt install -y certbot
      sudo certbot certonly --standalone -d "$DOMAIN"
      ;;
    n|no)
      echo "❌ SSL installation skipped. Exiting setup."
      exit 1
      ;;
    *)
      echo "❌ Invalid input. Please enter y/yes or n/no."
      exit 1
      ;;
  esac
fi

# Step 2: Install AdGuard
read -p "Proceed with AdGuard Home installation? (y/yes/n/no): " CONFIRM
case "$CONFIRM" in
  y|yes)
    echo "📦 Downloading and installing AdGuard Home using official script..."
    curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v
    ;;
  n|no)
    echo "❌ Installation cancelled."
    exit 1
    ;;
  *)
    echo "❌ Invalid input. Please enter y/yes or n/no."
    exit 1
    ;;
esac

# Step 3: Free Port 53
echo "🔓 Freeing up port 53 from systemd-resolved..."
sudo systemctl disable systemd-resolved
sudo systemctl stop systemd-resolved
sudo rm -f /etc/resolv.conf

echo "🧠 Choose a DNS resolver:"
echo "1) 1.1.1.1 (Cloudflare)"
echo "2) 8.8.8.8 (Google)"
echo "3) 9.9.9.9 (Quad9)"
read -p "Enter your choice (1/2/3): " DNS_CHOICE

case "$DNS_CHOICE" in
  1) DNS="1.1.1.1" ;;
  2) DNS="8.8.8.8" ;;
  3) DNS="9.9.9.9" ;;
  *) echo "❌ Invalid choice."; exit 1 ;;
esac

echo "nameserver $DNS" | sudo tee /etc/resolv.conf
sudo chattr +i /etc/resolv.conf

# Final
echo "🎉 AdGuard Home is ready to use!"
echo "🔗 Open in your browser: http://$SERVER_IP:3000"

