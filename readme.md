# 🚀 AdGuard Home Installer for Ubuntu & CentOS

Installer otomatis untuk AdGuard Home yang dilengkapi dengan validasi DNS, pemasangan SSL via Certbot, dan konfigurasi resolver DNS. Cocok untuk sysadmin yang ingin setup cepat dan aman di server pribadi.

## ✨ Fitur Utama

- Validasi domain DNS dan IP server
- Pemasangan SSL otomatis menggunakan Certbot
- Installasi AdGuard Home versi terbaru
- Auto-start service AdGuard Home
- Membebaskan port 53 dari systemd-resolved
- Pilihan resolver DNS (Cloudflare, Google, Quad9)
- Uninstaller lengkap untuk rollback

## 📦 Instalasi

### 1. Clone repository

```bash
git clone https://github.com/username/adguard-installer.git
cd adguard-installer

