#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "[-] Please run this script as root."
  exit 1
fi

MIGRATE_BASE="/root/migrate"
NGINX_STAGING="${MIGRATE_BASE}/etc-nginx"
LE_STAGING="${MIGRATE_BASE}/etc-letsencrypt"

echo "[*] Creating staging directories under ${MIGRATE_BASE}..."

mkdir -p "${NGINX_STAGING}"
mkdir -p "${LE_STAGING}"

chown root:root "${MIGRATE_BASE}" -R
chmod 700 "${MIGRATE_BASE}"

echo "[*] Staging dirs created:"
echo "    - ${NGINX_STAGING}"
echo "    - ${LE_STAGING}"
echo
echo "[*] Next step: from the OLD (infected) server, run the rsync script"
echo "    and point it at this host and these paths."
echo
echo "    For example, from the old box:"
echo "      rsync -avz --numeric-ids /etc/nginx/       root@NEW_SERVER_IP:${NGINX_STAGING}/"
echo "      rsync -avz --numeric-ids /etc/letsencrypt/ root@NEW_SERVER_IP:${LE_STAGING}/"
echo
echo "[!] Do NOT overwrite /etc/nginx or /etc/letsencrypt directly on this server."
echo "    Review files in ${MIGRATE_BASE} first, then copy selectively."
