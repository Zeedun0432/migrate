#!/bin/bash

# ========================================
# PTERODACTYL MIGRATION SCRIPT - PLUG N PLAY
# Sekali klik langsung jadi tanpa setting manual!
# ========================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Banner
echo -e "${PURPLE}"
echo "==========================================="
echo "   PTERODACTYL MIGRATION SCRIPT v1.0"
echo "   Sekali Klik Langsung Plug N Play!"
echo "==========================================="
echo -e "${NC}"

# Fungsi untuk log
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${CYAN}[INFO] $1${NC}"
}

# Cek apakah running sebagai root
if [[ $EUID -ne 0 ]]; then
   error "Script ini harus dijalankan sebagai root!"
fi

# Cek syarat work
echo -e "${PURPLE}Sebelum mulai, bilang 'chiwa kawaii' dulu >\\< mwehehe${NC}"
read -p "Ketik 'chiwa kawaii' untuk melanjutkan: " chiwa_check
if [[ "$chiwa_check" != "chiwa kawaii" ]]; then
    error "Ga bilang chiwa kawaii, ga work :3"
fi

echo -e "${GREEN}Chiwa kawaii! Script siap bekerja~ >\\<${NC}"

# Menu utama
echo -e "${BLUE}"
echo "Pilih mode operasi:"
echo "1. BACKUP - VPS Lama (Backup Panel & Node)"
echo "2. RESTORE - VPS Baru (Install & Restore)"
echo "3. UPDATE IP - Update IP di database"
echo "4. DNS FLUSH - Flush DNS dan cache"
echo -e "${NC}"

read -p "Pilih opsi (1-4): " mode

case $mode in
    1)
        # MODE BACKUP
        log "MODE BACKUP - Membackup Panel & Node dari VPS lama..."
        
        # Backup Database
        log "Backup database..."
        mysqldump -u root -p --all-databases > /alldb.sql || error "Gagal backup database!"
        
        # Backup Panel, SSL, nginx
        log "Backup Panel, SSL, dan konfigurasi nginx..."
        tar -cvpzf /backup.tar.gz /etc/letsencrypt /var/www/pterodactyl /etc/nginx/sites-available/pterodactyl.conf /alldb.sql || error "Gagal backup panel!"
        
        # Backup Node
        log "Backup Node data..."
        tar -cvzf /node.tar.gz /var/lib/pterodactyl /etc/pterodactyl || error "Gagal backup node!"
        
        log "Backup selesai! File tersimpan di:"
        echo -e "${GREEN}  - /backup.tar.gz (Panel + Database)${NC}"
        echo -e "${GREEN}  - /node.tar.gz (Node)${NC}"
        echo -e "${YELLOW}Transfer kedua file ini ke VPS baru!${NC}"
        
        # Generate transfer command
        read -p "Masukkan IP VPS baru: " new_ip
        echo -e "${CYAN}Jalankan command ini di VPS baru:${NC}"
        echo "scp root@$(hostname -I | awk '{print $1}'):/root/{backup.tar.gz,node.tar.gz} /"
        ;;
        
    2)
        # MODE RESTORE
        log "MODE RESTORE - Install & Restore di VPS baru..."
        
        # Install Pterodactyl
        log "Install Pterodactyl Panel & Node..."
        info "Pastikan pilih opsi install Panel & Node, tapi JANGAN pilih HTTPS/SSL!"
        bash <(curl -s https://pterodactyl-installer.se) || error "Gagal install Pterodactyl!"
        
        # Cek apakah backup files ada
        if [[ ! -f "/backup.tar.gz" ]] || [[ ! -f "/node.tar.gz" ]]; then
            error "File backup tidak ditemukan! Pastikan sudah transfer backup.tar.gz dan node.tar.gz ke /"
        fi
        
        # Restore Panel
        log "Restore Panel dan konfigurasi..."
        tar -xvpzf /backup.tar.gz -C / || error "Gagal restore panel!"
        
        # Restart nginx
        log "Restart nginx..."
        systemctl restart nginx || error "Gagal restart nginx!"
        
        # Restore Node
        log "Restore Node data..."
        tar -xvzf /node.tar.gz -C / || error "Gagal restore node!"
        
        # Restore Database
        log "Restore Database..."
        mysql -u root -p < /alldb.sql || error "Gagal restore database!"
        
        # Update IP
        read -p "Masukkan IP VPS lama: " old_ip
        read -p "Masukkan IP VPS baru: " new_ip
        
        log "Update IP di database..."
        mysql -u root -p -e "USE panel; UPDATE allocations SET ip = '$new_ip' WHERE ip = '$old_ip';" || error "Gagal update IP!"
        
        # Restart Wings
        log "Restart Wings..."
        systemctl restart wings || error "Gagal restart wings!"
        
        log "Restore selesai! Panel sudah bisa diakses."
        echo -e "${YELLOW}Jangan lupa update DNS di domain manager!${NC}"
        ;;
        
    3)
        # UPDATE IP
        log "MODE UPDATE IP - Update IP di database..."
        
        read -p "Masukkan IP lama: " old_ip
        read -p "Masukkan IP baru: " new_ip
        
        log "Update IP di database..."
        mysql -u root -p -e "USE panel; UPDATE allocations SET ip = '$new_ip' WHERE ip = '$old_ip';" || error "Gagal update IP!"
        
        # Restart services
        log "Restart services..."
        systemctl restart nginx
        systemctl restart wings
        
        log "IP berhasil diupdate dari $old_ip ke $new_ip"
        ;;
        
    4)
        # DNS FLUSH
        log "MODE DNS FLUSH - Flush DNS dan cache..."
        
        # Flush DNS (jika systemd-resolved)
        if command -v systemd-resolve &> /dev/null; then
            log "Flush DNS menggunakan systemd-resolve..."
            systemd-resolve --flush-caches
        fi
        
        # Restart networking
        log "Restart networking services..."
        systemctl restart systemd-resolved 2>/dev/null || true
        systemctl restart NetworkManager 2>/dev/null || true
        
        # Cloudflare cache clear
        echo -e "${YELLOW}Untuk clear cache Cloudflare:${NC}"
        echo "1. Manual: Domain > Caching > Caching Configuration > Purge Everything"
        echo "2. API: Gunakan command berikut (ganti ZONE_ID dan APIKEY):"
        echo "curl -X POST \"https://api.cloudflare.com/client/v4/zones/ZONE_ID/purge_cache\" \\"
        echo "     -H \"Authorization: Bearer APIKEY\" \\"
        echo "     -H \"Content-Type: application/json\" \\"
        echo "     --data '{\"purge_everything\":true}'"
        
        echo -e "${YELLOW}Untuk clear cache browser: tekan CTRL + F5${NC}"
        
        log "DNS flush selesai!"
        ;;
        
    *)
        error "Pilihan tidak valid!"
        ;;
esac

# Cleanup
log "Membersihkan file temporary..."
rm -f /alldb.sql 2>/dev/null || true

echo -e "${PURPLE}"
echo "==========================================="
echo "       SCRIPT SELESAI DIJALANKAN!"
echo "      Makasih udah pake script ini >_<"
echo "==========================================="
echo -e "${NC}"

# Auto-reboot option
read -p "Reboot sekarang? (y/N): " reboot_choice
if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
    log "Rebooting dalam 5 detik..."
    sleep 5
    reboot
fi
