🔍 Troubleshooting:
Jika Transfer Gagal:
bash# Coba manual
rsync -avz -e ssh root@IP_LAMA:/root/backup.tar.gz /
rsync -avz -e ssh root@IP_LAMA:/root/node.tar.gz /
Jika IP Tidak Update:
bash# Manual update IP
mysql -u root -p
USE panel;
UPDATE allocations SET ip = 'IP_BARU' WHERE ip = 'IP_LAMA';
exit;
systemctl restart wings
Jika Wings Tidak Connect:
bash# Cek config
cat /etc/pterodactyl/config.yml
# Pastikan IP dan token benar

# Restart wings
systemctl restart wings
systemctl status wings
