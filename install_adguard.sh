#!/bin/bash
set -e

echo "🚀 AdGuard Home Installer — Ubuntu/CentOS Edition"

# OS Validation
OS=$(grep ^ID= /etc/os-release | cut -d= -f2 | tr -d '"')
ARCH=$(uname -m)

if [ "$OS" != "ubuntu" ] && [ "$OS" != "centos" ]; then
  echo "❌ Unsupported OS: $OS. Only Ubuntu and CentOS are supported."
  exit 1
fi

echo "🧠 OS: $OS | Architecture: $ARCH"
# Initial AdGuard check
if [ -f "/opt/AdGuardHome/AdGuardHome" ]; then
  echo "⚠️ AdGuard Home is already installed."
  echo "Choose an option:"
  echo "1) Reinstall AdGuard Home"
  echo "2) Uninstall AdGuard Home and optionally clean up system"
  echo "3) Continue to configure DoH and upstream settings"
  read -p "Enter your choice (1/2/3): " EXISTING_CHOICE
  case "$EXISTING_CHOICE" in
    1)
      curl -sSL https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | bash -s -- -r -v
      ;;
    2)
      curl -sSL https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | bash -s -- -u -v
      echo "✅ AdGuard Home uninstalled."

      read -p "Do you want to delete SSL certificates for your domain? (y/n): " DELETE_CERT
      if [[ "$DELETE_CERT" =~ ^(y|yes)$ ]]; then
        read -p "Enter your domain name (e.g. dns.domain.com): " DOMAIN
        sudo rm -rf "/etc/letsencrypt/live/$DOMAIN"
        sudo rm -rf "/etc/letsencrypt/archive/$DOMAIN"
        sudo rm -rf "/etc/letsencrypt/renewal/$DOMAIN.conf"
        echo "✅ SSL certificates deleted."
      else
        echo "➡️ Keeping SSL certificates."
      fi

      read -p "Do you want to restore systemd-resolved and default DNS resolver? (y/n): " RESTORE_DNS
      if [[ "$RESTORE_DNS" =~ ^(y|yes)$ ]]; then
        echo "🔁 Restoring systemd-resolved..."
        sudo systemctl enable systemd-resolved
        sudo systemctl start systemd-resolved

        echo "🔧 Resetting /etc/resolv.conf..."
        sudo chattr -i /etc/resolv.conf 2>/dev/null || true
        sudo rm -f /etc/resolv.conf
        sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
        echo "✅ DNS resolver restored."
      else
        echo "➡️ Skipping DNS resolver restore."
      fi

      echo "🧼 Uninstall cleanup complete."
      exit 0
      ;;
    3)
      echo "➡️ Proceeding to configure DoH and upstream settings..."
      ;;
    *)
      echo "❌ Invalid choice."
      exit 1
      ;;
  esac
else
  echo "📦 Installing AdGuard Home..."
  curl -sSL https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | bash -s -- -v
fi


# DNS & SSL Setup
read -p "Enter your DNS domain name (e.g. dns.domain.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
  echo "❌ Aborted: You must enter a valid domain name."
  exit 1
fi

SERVER_IP=$(curl -s https://ipinfo.io/ip)
DNS_IP=$(dig +short "$DOMAIN")

if [ "$DNS_IP" != "$SERVER_IP" ]; then
  echo "❌ ERROR: DNS $DOMAIN is not pointing to the server IP ($SERVER_IP)."
  exit 1
else
  echo "✅ DNS $DOMAIN is correctly pointing to the server IP."
fi

if [ ! -d "/etc/letsencrypt/live/$DOMAIN" ]; then
  echo "🔐 Installing SSL certificate using Certbot..."
  sudo apt update
  sudo apt install -y certbot
  sudo certbot certonly --standalone -d "$DOMAIN"
fi

# Validate cert
if ! sudo openssl x509 -in /etc/letsencrypt/live/$DOMAIN/fullchain.pem -noout -dates; then
  echo "❌ SSL certificate validation failed."
  exit 1
fi

# Optional: Setup Unbound as upstream
read -p "Do you want to install and use Unbound at 127.0.0.1:5353 as upstream DNS? (y/n): " UNBOUND_CONFIRM
if [[ "$UNBOUND_CONFIRM" =~ ^(y|yes)$ ]]; then
  echo "🔍 Checking Unbound..."
  if ! command -v unbound &>/dev/null; then
    echo "⚠️ Unbound not found. Installing..."
    if [ "$OS" = "ubuntu" ]; then
      sudo apt install -y unbound
    else
      sudo yum install -y unbound
    fi
  fi

  UNBOUND_CONF="/etc/unbound/unbound.conf"
  if ! grep -q "port: 5353" "$UNBOUND_CONF" 2>/dev/null; then
    echo "🔧 Writing minimal Unbound config..."
    sudo tee "$UNBOUND_CONF" > /dev/null <<EOF
server:
  interface: 127.0.0.1
  port: 5353
EOF
  fi

  echo "🔁 Restarting Unbound..."
  sudo systemctl restart unbound

  echo "🔍 Testing Unbound..."
  if dig @127.0.0.1 -p 5353 google.com +short | grep -qE '^[0-9]+\.'; then
    echo "✅ Unbound is working. Proceeding to inject upstream_dns..."
  else
    echo "❌ Unbound test failed. Skipping upstream injection."
    UNBOUND_CONFIRM="no"
  fi
else
  echo "➡️ Skipping Unbound setup."
fi

# Free Port 53
echo "🔓 Freeing up port 53 from systemd-resolved..."
sudo systemctl disable systemd-resolved
sudo systemctl stop systemd-resolved

if lsattr /etc/resolv.conf 2>/dev/null | grep -q 'i'; then
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

# Locate AdGuardHome.yaml
echo "🔍 Locating AdGuardHome.yaml..."
CONFIG_PATH=$(sudo find /opt /etc /var /home -type f -name "AdGuardHome.yaml" 2>/dev/null | head -n 1)

if [ -z "$CONFIG_PATH" ]; then
  echo "❌ AdGuardHome.yaml not found. Please complete initial setup via browser first."
  echo "🔗 Visit: http://$SERVER_IP:3000"
  exit 1
fi

echo "✅ Found config at: $CONFIG_PATH"
sudo cp "$CONFIG_PATH" "$CONFIG_PATH.bak"

# Replace upstream_dns inside dns block (only if Unbound confirmed)
if [[ "$UNBOUND_CONFIRM" =~ ^(y|yes)$ ]]; then
  echo "🔧 Replacing upstream_dns inside dns block..."
  sudo awk '
    BEGIN {in_dns=0; skip=0}
    /^dns:/ {in_dns=1}
    in_dns && /^  upstream_dns:/ {print "  upstream_dns:\n    - 127.0.0.1:5353"; skip=1; next}
    in_dns && skip && /^  [^ ]/ {skip=0}
    {if (!skip) print}
  ' "$CONFIG_PATH" | sudo tee "$CONFIG_PATH.tmp" > /dev/null && sudo mv "$CONFIG_PATH.tmp" "$CONFIG_PATH"
fi

# Replace tls block safely
echo "🔧 Replacing tls block..."
sudo awk -v domain="$DOMAIN" '
  BEGIN {in_tls=0}
  /^tls:/ {in_tls=1; print "# tls block replaced"; next}
  in_tls && /^[^ ]/ {in_tls=0}
  !in_tls || ($0 !~ /^  enabled:/) {print}
  END {
    print "tls:";
    print "  enabled: true";
    print "  server_name: \"" domain "\"";
    print "  force_https: false";
    print "  port_https: 443";
    print "  port_dns_over_tls: 853";
    print "  port_dns_over_quic: 853";
    print "  port_dnscrypt: 0";
    print "  dnscrypt_config_file: \"\"";
    print "  allow_unencrypted_doh: false";
    print "  certificate_chain: \"\"";
    print "  private_key: \"\"";
    print "  certificate_path: \"/etc/letsencrypt/live/" domain "/fullchain.pem\"";
    print "  private_key_path: \"/etc/letsencrypt/live/" domain "/privkey.pem\"";
    print "  strict_sni_check: false";
  }
' "$CONFIG_PATH" | sudo tee "$CONFIG_PATH.tmp" > /dev/null && sudo mv "$CONFIG_PATH.tmp" "$CONFIG_PATH"

# Restart AdGuard
echo "🔁 Restarting AdGuard Home..."
sudo systemctl restart AdGuardHome || sudo /opt/AdGuardHome/AdGuardHome -s restart

# DoH Test
read -p "Do you want to test DoH endpoint? (y/n): " TEST_CONFIRM
if [[ "$TEST_CONFIRM" =~ ^(y|yes)$ ]]; then
  echo "🔍 Testing DoH endpoint..."
  curl -I "https://$DOMAIN/dns-query" || echo "❌ DoH test failed."
  echo "✅ If you see HTTP 200 or 403, DoH is active."
else
  echo "➡️ Skipping DoH test."
fi

# Final message
echo "🎉 AdGuard Home setup complete!"
echo "🔗 Access it at: http://$SERVER_IP:3000"
echo "🔐 DoH endpoint: https://$DOMAIN/dns-query"

