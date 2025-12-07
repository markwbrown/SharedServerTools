#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "[-] Please run this script as root."
  exit 1
fi

# 👉 EDIT THIS: set your new server host/IP
NEW_SERVER_HOST="NEW_SERVER_IP_OR_HOSTNAME"

# Optional: non-standard SSH port
SSH_PORT=22

REMOTE_BASE="/root/migrate"
REMOTE_NGINX="${REMOTE_BASE}/etc-nginx"
REMOTE_LE="${REMOTE_BASE}/etc-letsencrypt"

echo "[*] Migrating Nginx config and Let's Encrypt data"
echo "[*]  From: this (infected) server"
echo "[*]  To:   root@${NEW_SERVER_HOST}:${REMOTE_BASE}"
echo

read -rp "[?] Continue with rsync? (yes/no) " ANSWER
if [[ "${ANSWER}" != "yes" ]]; then
  echo "[-] Aborting."
  exit 1
fi

RSYNC_BASE="rsync -avz --numeric-ids --progress -e 'ssh -p ${SSH_PORT}'"

echo "[*] Rsync Nginx config..."
eval ${RSYNC_BASE} /etc/nginx/ "root@${NEW_SERVER_HOST}:${REMOTE_NGINX}/"

echo
echo "[*] Rsync Let's Encrypt data..."
eval ${RSYNC_BASE} /etc/letsencrypt/ "root@${NEW_SERVER_HOST}:${REMOTE_LE}/"

echo
echo "[*] Done."
echo "[*] On the NEW server, your files are now staged under:"
echo "    - ${REMOTE_NGINX}"
echo "    - ${REMOTE_LE}"
echo
echo "[!] Remember: treat these certs/keys as compromised."
echo "    After the new server is live, force-renew or re-issue certs with certbot."
