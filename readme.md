# 🚀 AdGuard Home Installer for Ubuntu & CentOS

Installer otomatis untuk AdGuard Home yang dilengkapi dengan **validasi DNS**, **pemasangan SSL via Certbot**, dan **konfigurasi resolver DNS**. Sangat cocok untuk sysadmin yang ingin melakukan setup cepat dan aman di server pribadi mereka.

---

## ✨ Fitur Utama

- Validasi domain DNS dan IP server
- Pemasangan SSL otomatis menggunakan Certbot
- Installasi AdGuard Home versi terbaru
- Auto-start service AdGuard Home
- Membebaskan port 53 dari `systemd-resolved`
- Pilihan resolver DNS (Cloudflare, Google, Quad9)
- **Uninstaller lengkap** untuk rollback

---

## 📦 Instalasi

### Langkah-langkah:

1.  **Clone** repositori ini ke server Anda:

    ```bash
    git clone [https://github.com/username/adguard-installer.git](https://github.com/username/adguard-installer.git)
    cd adguard-installer
    ```

2.  **Jalankan installer** dengan perintah berikut:

    ```bash
    chmod +x install-adguard.sh
    ./install-adguard.sh
    ```

Installer akan memandu Anda melalui beberapa tahapan, seperti:

-   Memasukkan nama domain DNS
-   Validasi apakah domain sudah mengarah ke IP server
-   Pemasangan SSL otomatis jika belum tersedia
-   Download dan install AdGuard Home
-   Konfigurasi DNS resolver (`1.1.1.1` / `8.8.8.8` / `9.9.9.9`)
-   Menjalankan AdGuard sebagai service
-   Menampilkan URL akses: `http://<IP>:3000`

### ✅ Kompatibilitas

-   Ubuntu 20.04 / 22.04
-   CentOS 7 / 8
