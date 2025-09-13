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

# Check if AdGuardHome already installed
if [ -f "/opt/AdGuardHome/AdGuardHome" ]; then
  echo "⚠️ AdGuard Home is already installed."
  echo "Choose an option:"
  echo "1) Reinstall"
  echo "2) Uninstall"
  echo "3) Continue without changes"
  read -p "Enter your choice (1/2/3): " EXISTING_CHOICE
  case "$EXISTING_CHOICE" in
    1)
      curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -r -v
      ;;
    2)
      curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -u -v
      echo "✅ AdGuard Home uninstalled."
      exit 0
      ;;
    3)
      echo "➡️ Continuing with existing installation..."
      ;;
    *)
      echo "❌ Invalid choice."; exit 1 ;;
  esac
else
  echo "📦 Installing AdGuard Home..."
  curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v
fi

# DNS & SSL Setup
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

# Free Port 53
echo "🔓 Freeing up port 53 from systemd-resolved..."
sudo systemctl disable systemd-resolved
sudo systemctl stop systemd-resolved

# Unlock resolv.conf if previously locked
if lsattr /etc/resolv.conf 2>/dev/null | grep -q 'i'; then
  echo "🔓 Unlocking /etc/resolv.conf..."
  sudo chattr -i /etc/resolv.conf
fi

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

# DoH Activation
CONFIG_PATH="/opt/AdGuardHome/AdGuardHome.yaml"

if [ ! -f "$CONFIG_PATH" ]; then
  echo "⚠️ AdGuardHome.yaml not found. Please access AdGuard Home via browser at http://$SERVER_IP:3000 and complete initial setup."
  echo "🔁 After that, re-run this script to apply DoH and upstream settings."
  exit 1
fi

read -p "Do you want to enable DNS-over-HTTPS (DoH)? (y/yes/n/no): " DOH_CONFIRM
case "$DOH_CONFIRM" in
  y|yes)
    echo "📁 Backing up AdGuardHome.yaml..."
    sudo cp "$CONFIG_PATH" "$CONFIG_PATH.bak"

    echo "🔧 Injecting DoH and upstream settings into AdGuardHome.yaml..."
    sudo tee -a "$CONFIG_PATH" > /dev/null <<EOF

tls:
  enabled: true
  server_name: "$DOMAIN"
  certificate_chain: "/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
  private_key: "/etc/letsencrypt/live/$DOMAIN/privkey.pem"

upstream_dns:
  - 127.0.0.1:5353
EOF

    echo "🔁 Restarting AdGuard Home to apply changes..."
    sudo systemctl restart AdGuardHome
    ;;
  n|no)
    echo "➡️ Skipping DoH setup."
    ;;
  *)
    echo "❌ Invalid input."; exit 1 ;;
esac

# DoH Test
read -p "Do you want to test DoH endpoint? (y/yes/n/no): " TEST_CONFIRM
case "$TEST_CONFIRM" in
  y|yes)
    echo "🔍 Testing DoH endpoint..."
    curl -I "https://$DOMAIN/dns-query" || echo "❌ DoH test failed."
    echo "✅ If you see HTTP 200 or 403, DoH is active."
    ;;
  n|no)
    echo "➡️ Skipping DoH test."
    ;;
  *)
    echo "❌ Invalid input."; exit 1 ;;
esac

# Final
echo "🎉 AdGuard Home setup complete!"
echo "🔗 Access it at: http://$SERVER_IP:3000"

