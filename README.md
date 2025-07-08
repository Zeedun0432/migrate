# 🔍 Troubleshooting:

*Jika Transfer Gagal:*
rsync -avz -e ssh root@IP_LAMA:/root/backup.tar.gz /
rsync -avz -e ssh root@IP_LAMA:/root/node.tar.gz /

*Jika IP Tidak Update:*
mysql -u root -p
USE panel;
UPDATE allocations SET ip = 'IP_BARU' WHERE ip = 'IP_LAMA';
exit;
systemctl restart wings

*Jika Wings Tidak Connect:*
cat /etc/pterodactyl/config.yml
systemctl restart wings
systemctl status wings
