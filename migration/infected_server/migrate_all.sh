#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "[-] Please run this script as root."
  exit 1
fi

#####################
# EDIT THESE VALUES #
#####################

NEW_SERVER_HOST="NEW_SERVER_IP_OR_HOSTNAME"
SSH_PORT=22

REMOTE_BASE="/root/migrate"

RSYNC="rsync -avz --numeric-ids --progress -e 'ssh -p ${SSH_PORT}'"

echo "[*] Migrating data to root@${NEW_SERVER_HOST}:${REMOTE_BASE}"
echo

read -rp "[?] Continue with rsync? (yes/no) " ANSWER
if [[ "${ANSWER}" != "yes" ]]; then
  echo "[-] Aborting."
  exit 1
fi

#########################
# 1. DB / SQL DUMPS     #
#########################

mkdir -p /tmp/migrate-mark  # local scratch if needed (not strictly required)

echo "[*] Rsync DB / SQL dump files..."
${RSYNC} /mnt/moreMas/jgmtr.sql                root@${NEW_SERVER_HOST}:${REMOTE_BASE}/db/
${RSYNC} /mnt/moreMas/recipes.sql              root@${NEW_SERVER_HOST}:${REMOTE_BASE}/db/
${RSYNC} /home/mark/vinovest_2024-10-07.sql    root@${NEW_SERVER_HOST}:${REMOTE_BASE}/db/

#########################
# 2. Persistent storage #
#########################

echo
echo "[*] Rsync jgmtr persistent storage..."
${RSYNC} /mnt/moreMas/jgmtr-persistent-storage/ \
  root@${NEW_SERVER_HOST}:${REMOTE_BASE}/jgmtr-persistent-storage/

echo "[*] Rsync jgmtr git repo..."
${RSYNC} /mnt/moreMas/jgmtr-git/ \
  root@${NEW_SERVER_HOST}:${REMOTE_BASE}/jgmtr-git/

echo "[*] Rsync shared git repos (canonical path)..."
${RSYNC} /mnt/moreMas/git/ \
  root@${NEW_SERVER_HOST}:${REMOTE_BASE}/git/

#########################
# 3. Websites (without  #
#    node_modules/etc)  #
#########################

echo
echo "[*] Rsync websites (excluding node_modules, .next, dist, build)..."
${RSYNC} \
  --exclude='node_modules' \
  --exclude='.next' \
  --exclude='dist' \
  --exclude='build' \
  /mnt/moreMas/websites/ \
  root@${NEW_SERVER_HOST}:${REMOTE_BASE}/websites/

#########################
# 4. Nginx site configs #
#########################

echo
echo "[*] Rsync Nginx site configs (NOT overwriting /etc on new server)..."
${RSYNC} /etc/nginx/sites-available/ \
  root@${NEW_SERVER_HOST}:${REMOTE_BASE}/etc-nginx/sites-available/

${RSYNC} /etc/nginx/sites-enabled/ \
  root@${NEW_SERVER_HOST}:${REMOTE_BASE}/etc-nginx/sites-enabled/

#########################
# 5. git configs / misc #
#########################

echo
echo "[*] Rsync /home/git/configs..."
${RSYNC} /home/git/configs/ \
  root@${NEW_SERVER_HOST}:${REMOTE_BASE}/home-git-configs/

#########################
# 6. mark's configs     #
#########################

echo
echo "[*] Rsync mark's env / conf / scripts / seed data..."
${RSYNC} /home/mark/stephenshugerman.com.env \
  root@${NEW_SERVER_HOST}:${REMOTE_BASE}/home-mark/

${RSYNC} /home/mark/loststash-stocks.conf \
  root@${NEW_SERVER_HOST}:${REMOTE_BASE}/home-mark/

${RSYNC} /home/mark/createsql.py \
  root@${NEW_SERVER_HOST}:${REMOTE_BASE}/home-mark/

${RSYNC} /home/mark/create_sql.py \
  root@${NEW_SERVER_HOST}:${REMOTE_BASE}/home-mark/

${RSYNC} /home/mark/createvuesite.sh \
  root@${NEW_SERVER_HOST}:${REMOTE_BASE}/home-mark/

${RSYNC} /home/mark/createsite.sh \
  root@${NEW_SERVER_HOST}:${REMOTE_BASE}/home-mark/

${RSYNC} /home/mark/clean.sh \
  root@${NEW_SERVER_HOST}:${REMOTE_BASE}/home-mark/

${RSYNC} /home/mark/amaze/amaze.sh \
  root@${NEW_SERVER_HOST}:${REMOTE_BASE}/home-mark/amaze/

${RSYNC} /home/mark/seed/ \
  root@${NEW_SERVER_HOST}:${REMOTE_BASE}/home-mark/seed/

echo
echo "[*] All requested paths have been rsynced to:"
echo "    root@${NEW_SERVER_HOST}:${REMOTE_BASE}"
echo
echo "[!] On the NEW server:"
echo "    - Treat *.env, *.conf as sensitive and compromised (reference only)."
echo "    - Review all .sh/.py scripts before executing."
echo "    - Integrate Nginx configs by manually copying from:"
echo "        ${REMOTE_BASE}/etc-nginx/sites-available"
echo "        ${REMOTE_BASE}/etc-nginx/sites-enabled"
