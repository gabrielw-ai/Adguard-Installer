# 🚀 AdGuard Home Installer for Ubuntu & CentOS

An automatic installer for AdGuard Home that includes **DNS validation**, **SSL setup via Certbot**, and **DNS resolver configuration**. Perfect for sysadmins who want a fast and secure setup on their private servers.

---

## ✨ Key Features

- Validates DNS domain and server IP
- Automatically installs SSL using Certbot
- Installs the latest version of AdGuard Home
- Auto-starts AdGuard Home as a service
- Frees up port 53 from `systemd-resolved`
- DNS resolver options (Cloudflare, Google, Quad9)
- **Complete uninstaller** for rollback

---

## 📦 Installation

### Steps:

1. **Clone** this repository to your server:

    ```bash
    git clone https://github.com/gabrielw-ai/adguard-installer.git
    cd adguard-installer
    ```

2. **Run the installer** with the following command:

    ```bash
    chmod +x install_adguard.sh
    ./install_adguard.sh
    ```

    The installer will guide you through:

    - Entering your DNS domain name
    - Validating whether the domain points to your server IP
    - Automatically installing SSL if not already present
    - Downloading and installing AdGuard Home
    - Configuring DNS resolver (`1.1.1.1` / `8.8.8.8` / `9.9.9.9`)
    - Starting AdGuard Home as a service
    - Displaying access URL: `http://<IP>:3000`

3. **Uninstall (if needed):**

   Re-run the script

    The uninstaller will:

    - Remove AdGuard Home and its service
    - Offer to delete SSL certificates
    - Restore `systemd-resolved` and default DNS resolver

---

### ✅ Compatibility

- Ubuntu 20.04 / 22.04
- CentOS 7 / 8

---

### 📄 License

MIT License — free to use and modify.

