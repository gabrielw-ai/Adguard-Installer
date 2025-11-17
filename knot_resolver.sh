#!/bin/bash
# Script Instalasi Knot Resolver (KR) dengan Mitigasi DDoS Lua (VERSI AKHIR & ROBUST)
# KR di Port 53 (Publik, Mitigasi) -> Forward ke AdGuard Home di 127.0.0.1:5300

# Konfigurasi File
LUA_SCRIPT_NAME="dynamic_ddos_detector.lua"
KR_CONF_DIR="/etc/knot-resolver"
KR_CONF_FILE="$KR_CONF_DIR/kresd.conf"
LUA_SCRIPT_PATH="$KR_CONF_DIR/$LUA_SCRIPT_NAME"

# Port Default
LISTEN_PORTS=(53 5353) 
AGH_INTERNAL_PORT="5300" 

echo "=== Memulai Instalasi Knot Resolver dan Konfigurasi Mitigasi ==="

# --- FUNGSI UTAMA ---

# Fungsi untuk memeriksa apakah port sedang digunakan oleh layanan (FIXED: Abaikan header ss)
check_port_conflict() {
    local port=$1
    
    # Menghapus baris header (grep -v 'Netid') dan mengecek apakah ada listener yang tersisa.
    listener=$(sudo ss -tuln sport = :$port | grep -v 'Netid')

    if [[ -n "$listener" ]]; then
        echo "⚠️ Konflik terdeteksi di Port $port!"
        service_info=$(sudo lsof -i :$port | grep -v 'COMMAND' | awk '{print $1}' | head -n 1)
        if [[ -n "$service_info" ]]; then
             echo "   Port $port sedang digunakan oleh service: $service_info"
        else
             echo "   Port $port sedang digunakan oleh proses lain."
        fi
        return 0 # Konflik
    fi
    return 1 # Aman
}

# Fungsi untuk mencari port alternatif yang aman
find_alternative_port() {
    local start_port=$1
    local alt_port=$start_port

    while check_port_conflict "$alt_port"; do
        alt_port=$((alt_port + 1))
        if [[ $alt_port -gt 5400 ]]; then
            echo "Error: Tidak dapat menemukan port alternatif yang aman."
            exit 1
        fi
    done
    echo "$alt_port"
}


# --- 1. Deteksi OS & Instalasi Tools Dasar ---

if grep -q "ID=debian\|ID=ubuntu" /etc/os-release; then
    echo "Sistem terdeteksi: Debian/Ubuntu. Mempersiapkan tools pengecekan..."
    sudo apt update
    sudo apt install -y iproute2 lsof
    PACKAGE_MANAGER="apt"
elif grep -q "ID=centos\|ID=rhel\|ID=rocky\|ID=almalinux" /etc/os-release || [ -f /etc/redhat-release ]; then
    echo "Sistem terdeteksi: RHEL/CentOS/AlmaLinux/Rocky Linux. Mempersiapkan tools pengecekan..."
    if command -v dnf &> /dev/null; then
        sudo dnf install -y iproute lsof
        PACKAGE_MANAGER="dnf"
    elif command -v yum &> /dev/null; then
        sudo yum install -y iproute lsof
        PACKAGE_MANAGER="yum"
    else
        echo "Error: Manajer paket (dnf/yum) tidak ditemukan."
        exit 1
    fi
else
    echo "Sistem operasi tidak didukung atau tidak dapat dideteksi."
    exit 1
fi

# --- 2. Cek Konflik Port DULU & Tentukan Port Final ---

echo "--- Cek Konflik Port 53 & 5353 Sebelum Instalasi Knot Resolver ---"

PORT_PUB=${LISTEN_PORTS[0]} 
PORT_SEC=${LISTEN_PORTS[1]} 
PORT_CONFLICT_FOUND=false

if check_port_conflict "$PORT_PUB"; then
    PORT_CONFLICT_FOUND=true
    PORT_PUB=$(find_alternative_port $PORT_PUB)
    echo "   Port Primer (53) dialihkan ke: $PORT_PUB"
else
    echo "   Port Primer (53): ✅ Aman."
fi

if check_port_conflict "$PORT_SEC"; then
    PORT_CONFLICT_FOUND=true
    PORT_SEC=$(find_alternative_port $PORT_SEC)
    echo "   Port Sekunder (5353) dialihkan ke: $PORT_SEC"
else
    echo "   Port Sekunder (5353): ✅ Aman."
fi

# --- 3. Konfirmasi Pengguna ---

if $PORT_CONFLICT_FOUND; then
    echo "--------------------------------------------------------"
    echo "Konflik port terdeteksi! Knot Resolver akan menggunakan Port $PORT_PUB dan $PORT_SEC."
    read -r -p "Gunakan konfigurasi port yang disarankan dan lanjutkan instalasi? (y/n): " confirm
else
    echo "--------------------------------------------------------"
    echo "Port 53 dan 5353 aman. KR akan dikonfigurasi sebagai Mitigasi di Port $PORT_PUB."
    read -r -p "Lanjutkan instalasi dan konfigurasi forwarding ke AGH di Port $AGH_INTERNAL_PORT? (y/n): " confirm
fi

if [[ "$confirm" != [yY] ]]; then
    echo "Operasi dibatalkan oleh pengguna."
    exit 1
fi

# --- 4. Instalasi Knot Resolver (PENGUATAN INSTALASI) ---

echo "--- Melanjutkan Instalasi Knot Resolver ---"
# Coba install knot-resolver dan lua
if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
    sudo apt install -y knot-resolver lua5.3
elif [[ "$PACKAGE_MANAGER" == "dnf" || "$PACKAGE_MANAGER" == "yum" ]]; then
    # Menghapus cache dan mencoba instalasi ulang jika gagal sebelumnya
    sudo $PACKAGE_MANAGER clean all
    sudo $PACKAGE_MANAGER install -y knot-resolver lua
fi

# Verifikasi biner knot-resolver ada
if ! command -v kresd &> /dev/null; then
    echo "❌ ERROR KRITIKAL: Biner 'kresd' tidak ditemukan setelah instalasi. Cek repository/link paket Anda."
    exit 1
fi

echo "Instalasi Knot Resolver selesai."

# Hentikan layanan kresd (jika berhasil diinstal dan berjalan)
# Menggunakan '|| true' agar skrip tidak crash jika service belum terdaftar
sudo systemctl stop kresd 2>/dev/null || true

# --- 5. Buat dan Tulis Skrip Lua Dynamic Detector ---

echo "Menulis skrip Lua Dynamic Detector ke $LUA_SCRIPT_PATH..."
cat <<EOF | sudo tee $LUA_SCRIPT_PATH > /dev/null
-- File: $LUA_SCRIPT_NAME
local cache = require('policy.cache')
local log = require('policy.log')

-- === KONFIGURASI BATAS DINAMIS ===
local WINDOW_TTL = 5          
local THRESHOLD_PERCENT = 0.5 
local MIN_TOTAL_QPS = 50      
--------------------------------------

policy.register(policy.FLAGS.ALWAYS_PROCESS, function (state)
    local qname = state.query_state.qname:to_string()
    local total_qps_key = 'total_qps'
    
    local total_qps = cache:get(total_qps_key) or 0
    total_qps = total_qps + 1
    if total_qps == 1 then
        cache:set(total_qps_key, total_qps, WINDOW_TTL)
    else
        cache:set(total_qps_key, total_qps)
    end
    
    local qname_count_key = 'qname_' .. qname
    local qname_count = cache:get(qname_count_key) or 0
    qname_count = qname_count + 1
    if qname_count == 1 then
        cache:set(qname_count_key, qname_count, WINDOW_TTL)
    else
        cache:set(qname_count_key, qname_count)
    end

    if total_qps >= MIN_TOTAL_QPS then
        local ratio = qname_count / total_qps
        
        if ratio >= THRESHOLD_PERCENT then
            log.warn('ANOMALY DETECTED: ' .. qname .. ' contributes ' .. math.floor(ratio*100) .. '% of all QPS. DENYING.')
            return policy.DENY 
        end
    end
    
    return policy.PASS
end)
EOF
echo "Skrip Lua mitigasi berhasil dibuat."

# --- 6. Modifikasi File Konfigurasi Knot Resolver (FINAL) ---

echo "Memodifikasi $KR_CONF_FILE untuk Dual Port $PORT_PUB & $PORT_SEC, Forwarding ke AGH ($AGH_INTERNAL_PORT)..."

# Hapus konfigurasi lama 
sudo sed -i '/^listen = {/,/^}$/d' $KR_CONF_FILE
sudo sed -i '/^modules = {/d' $KR_CONF_FILE
sudo sed -i '/^policy.add(/d' $KR_CONF_FILE

# Tambahkan konfigurasi baru
cat <<EOF | sudo tee -a $KR_CONF_FILE

-- === KONFIGURASI LISTEN DUAL PORT ===
listen = { 
    '0.0.0.0@$PORT_PUB',     -- Port Primer (Publik/Mitigasi)
    '::@$PORT_PUB',          -- Port Primer (IPv6)
    '0.0.0.0@$PORT_SEC',   -- Port Sekunder (Internal/Pengujian)
    '::@$PORT_SEC'         -- Port Sekunder (IPv6)
}

-- === MODUL DAN KEBIJAKAN MITIGASI & FORWARDING ===
modules = {
    'policy', 
    'cache', 
    'stats',
    'ratelimit', 
    'forward', 
}

-- 1. Kebijakan Mitigasi Dinamis Lua (QNAME Flood) - Dijalankan PERTAMA
policy.add(policy.all(
    policy.lua('./$LUA_SCRIPT_NAME')
))

-- 2. Kebijakan Response Rate Limiting (Amplifikasi) - Dijalankan KEDUA
policy.add(policy.all(
    policy.ratelimit(
        { per_ip = 20 }
    )
))

-- 3. Nonaktifkan Rekursi KR & FORWARD ke AGH (127.0.0.1:5300) - Dijalankan TERAKHIR
policy.add(policy.all(
    policy.no_recurse(), 
    policy.forward({
        '127.0.0.1@$AGH_INTERNAL_PORT', 
        '::1@$AGH_INTERNAL_PORT'
    })
))

EOF
echo "Konfigurasi Knot Resolver berhasil diupdate."

# --- 7. Aktifkan dan Mulai Ulang Layanan (PENANGANAN SYSTEMD) ---

echo "Mengaktifkan layanan Knot Resolver..."

# Perintah daemon-reload diperlukan untuk memuat service file yang baru diinstal
sudo systemctl daemon-reload 2>/dev/null || true 

sudo systemctl enable kresd
sudo systemctl start kresd

# Cek status layanan
sudo systemctl status kresd | head -n 10

echo "=== Instalasi Knot Resolver dan Mitigasi DDoS Selesai. ==="

# Verifikasi konfigurasi
if command -v knot-resolver &> /dev/null; then
    sudo knot-resolver -c $KR_CONF_FILE --configtest
else
    echo "⚠️ Peringatan: knot-resolver command tidak ditemukan, tidak bisa menjalankan configtest."
fi
