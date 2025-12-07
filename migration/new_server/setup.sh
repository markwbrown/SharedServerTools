#!/bin/bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "[-] Please run this script as root (sudo)."
  exit 1
fi

echo "[*] Updating package index..."
apt-get update -y

########################################
# 0. Credentials file                  #
########################################

CRED_FILE="/home/server-bootstrap-credentials.txt"
touch "${CRED_FILE}"
chmod 600 "${CRED_FILE}"
chown root:root "${CRED_FILE}"

########################################
# 1. Base packages                     #
########################################

echo "[*] Installing base packages (git, python, dbs, nginx, clamav, ufw, mosh, tools)..."
apt-get install -y \
  git \
  python3 python3-venv python3-pip \
  nginx \
  mariadb-server \
  postgresql postgresql-contrib \
  clamav clamav-daemon \
  ufw \
  mosh \
  htop tmux \
  build-essential \
  curl \
  openssl \
  rsync \
  jq \
  ripgrep \
  fd-find \
  tree \
  ncdu \
  iotop \
  dnsutils \
  net-tools \
  whois \
  zip unzip \
  bash-completion \
  etckeeper

########################################
# 2. Create users: git + mark          #
########################################

echo "[*] Ensuring 'git' and 'mark' users exist with passwords..."

# git user (no sudo)
if id -u git >/dev/null 2>&1; then
  echo "[*] User 'git' already exists, not modifying password."
else
  echo "[*] Creating user 'git'..."
  PASS_GIT=$(openssl rand -base64 20)
  useradd -m -s /bin/bash git
  echo "git:${PASS_GIT}" | chpasswd

  {
    echo "### Linux user 'git'"
    echo "username: git"
    echo "password: ${PASS_GIT}"
    echo
  } >> "${CRED_FILE}"
fi

# mark user (with sudo)
if id -u mark >/dev/null 2>&1; then
  echo "[*] User 'mark' already exists, not modifying password."
else
  echo "[*] Creating user 'mark' with sudo..."
  PASS_MARK=$(openssl rand -base64 20)
  useradd -m -s /bin/bash mark
  usermod -aG sudo mark
  echo "mark:${PASS_MARK}" | chpasswd

  {
    echo "### Linux user 'mark'"
    echo "username: mark"
    echo "password: ${PASS_MARK}"
    echo "sudo: yes (member of sudo group)"
    echo
  } >> "${CRED_FILE}"
fi

########################################
# 3. NVM + Node 18 & 22                #
########################################

NVM_DIR="/usr/local/nvm"
NVM_PROFILE="/etc/profile.d/nvm.sh"

if [[ ! -d "${NVM_DIR}" ]]; then
  echo "[*] Installing NVM system-wide into ${NVM_DIR}..."
  git clone https://github.com/nvm-sh/nvm.git "${NVM_DIR}"
  cd "${NVM_DIR}"
  git checkout v0.40.0 || true
  cd -
else
  echo "[*] NVM already present at ${NVM_DIR}."
fi

echo "[*] Writing ${NVM_PROFILE}..."
cat > "${NVM_PROFILE}" <<'EOL'
export NVM_DIR="/usr/local/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
EOL

chmod 644 "${NVM_PROFILE}"

echo "[*] Loading NVM to install Node 18 and 22..."
bash -lc '
  set -e
  if [ -s "/usr/local/nvm/nvm.sh" ]; then
    . /usr/local/nvm/nvm.sh
    echo "[*] Installing Node 18..."
    nvm install 18
    echo "[*] Installing Node 22..."
    nvm install 22
    echo "[*] Setting Node 22 as default..."
    nvm alias default 22
    echo "[*] Node versions installed:"
    nvm ls
  else
    echo "[-] NVM not found at /usr/local/nvm/nvm.sh"
  fi
'

########################################
# 4. Ollama                            #
########################################

if ! command -v ollama &> /dev/null; then
  echo "[*] Installing Ollama..."
  curl -fsSL https://ollama.com/install.sh | sh
else
  echo "[*] Ollama already installed."
fi

########################################
# 5. MariaDB basic configuration       #
########################################

echo "[*] Configuring MariaDB (basic dev_admin user)..."

systemctl enable mariadb
systemctl start mariadb

DEV_ADMIN_MYSQL_PASS=$(openssl rand -base64 32 || true)

echo "[*] Creating MariaDB dev_admin user if it does not exist..."
mysql -u root <<MYSQL_EOF
CREATE USER IF NOT EXISTS 'dev_admin'@'localhost' IDENTIFIED BY '${DEV_ADMIN_MYSQL_PASS}';
GRANT ALL PRIVILEGES ON *.* TO 'dev_admin'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
MYSQL_EOF

{
  echo "### MariaDB dev_admin"
  echo "user: dev_admin"
  echo "host: localhost"
  echo "password: ${DEV_ADMIN_MYSQL_PASS}"
  echo
} >> "${CRED_FILE}"

########################################
# 6. PostgreSQL basic configuration    #
########################################

echo "[*] Configuring PostgreSQL (basic dev_admin role)..."

systemctl enable postgresql
systemctl start postgresql

DEV_ADMIN_PG_PASS=$(openssl rand -base64 32 || true)

sudo -u postgres bash -lc "
  set -e
  EXISTS=\$(psql -Atqc \"SELECT 1 FROM pg_roles WHERE rolname = 'dev_admin'\")
  if [ \"\$EXISTS\" != \"1\" ]; then
    echo \"[*] Creating dev_admin role in Postgres...\"
    psql -c \"CREATE ROLE dev_admin LOGIN PASSWORD '${DEV_ADMIN_PG_PASS}' SUPERUSER CREATEDB CREATEROLE;\"
  else
    echo \"[*] Postgres role dev_admin already exists; not modifying password.\"
  fi
"

{
  echo "### PostgreSQL dev_admin"
  echo "user: dev_admin"
  echo "host: localhost"
  echo "password: ${DEV_ADMIN_PG_PASS}"
  echo
} >> "${CRED_FILE}"

echo "[*] Bootstrap credentials written to ${CRED_FILE} (root-only)."

########################################
# 7. ClamAV setup                      #
########################################

echo "[*] Configuring ClamAV (freshclam + daemon)..."
systemctl stop clamav-freshclam || true
freshclam || true
systemctl enable clamav-freshclam || true
systemctl start clamav-freshclam || true
systemctl enable clamav-daemon || true
systemctl start clamav-daemon || true

########################################
# 7b. Unattended Security Upgrades     #
########################################

echo "[*] Enabling unattended security upgrades..."
apt-get install -y unattended-upgrades

# Enable & start the service
systemctl enable unattended-upgrades
systemctl start unattended-upgrades

########################################
# 7c. Rootkit Hunter (rkhunter)        #
########################################

echo "[*] Installing and configuring rkhunter (rootkit hunter)..."
apt-get install -y rkhunter

echo "[*] Updating rkhunter definitions..."
rkhunter --update || true

echo "[*] Initializing rkhunter file properties database (baseline)..."
# This should be run on a *clean* system; if you later change a lot of system files,
# you can re-run it manually: rkhunter --propupd
rkhunter --propupd -q || true

# Ensure a simple daily cron job exists for automated checks
RKHUNTER_CRON="/etc/cron.daily/rkhunter-custom"
if [[ ! -f "${RKHUNTER_CRON}" ]]; then
  echo "[*] Creating daily rkhunter cron job at ${RKHUNTER_CRON}..."
  cat > "${RKHUNTER_CRON}" <<'EOL'
#!/bin/sh
# Daily rkhunter check (quiet) with log
LOGFILE="/var/log/rkhunter.daily.log"
/usr/bin/rkhunter --cronjob --update --quiet >> "$LOGFILE" 2>&1
/usr/bin/rkhunter --cronjob --check --quiet >> "$LOGFILE" 2>&1
EOL
  chmod 755 "${RKHUNTER_CRON}"
else
  echo "[*] rkhunter cron job already exists at ${RKHUNTER_CRON}, not overwriting."
fi

echo "[*] rkhunter installed. You can run an interactive check anytime with:"
echo "    rkhunter --check"

########################################
# 8. Nginx security snippet            #
########################################

echo "[*] Ensuring /etc/nginx/snippets exists..."
mkdir -p /etc/nginx/snippets

RCE_SNIPPET="/etc/nginx/snippets/rce-global.conf"
echo "[*] Creating Nginx security snippet at ${RCE_SNIPPET}..."
cat > "${RCE_SNIPPET}" <<'EOL'
# Block obvious RCE-style paths
location ~* ^/(exec|ignite|run|shell|system|cmd|debug) {
    return 444;
}

# Block requests that include a ?cmd=... query parameter
if ($arg_cmd) {
    return 444;
}

# Block direct access to sensitive file types (env/config/log/backup/sql)
location ~* \.(env|ini|log|bak|old|sql)$ {
    deny all;
}

# Block access to dotfiles and dot-directories (e.g. .git, .env, .ht*)
location ~ /\. {
    deny all;
}
EOL

echo "[*] Security snippet written."
echo "    -> Remember to add inside each server {} you want protected:"
echo "       include snippets/rce-global.conf;"
echo

########################################
# 9. Fail2Ban filter & jail (Nginx 444)#
########################################

echo "[*] Installing / ensuring Fail2Ban..."
if ! command -v fail2ban-client &> /dev/null; then
  apt-get install -y fail2ban
fi

F2B_FILTER="/etc/fail2ban/filter.d/nginx-444-rce.conf"
echo "[*] Creating Fail2Ban filter for Nginx 444 responses at ${F2B_FILTER}..."
cat > "${F2B_FILTER}" <<'EOL'
[Definition]
# Match any Nginx access log line where the response status is 444
failregex = ^<HOST> .*"[^"]*" 444 .*
ignoreregex =
EOL

JAIL_LOCAL="/etc/fail2ban/jail.local"
echo "[*] Ensuring jail.local exists..."
touch "${JAIL_LOCAL}"

if ! grep -q "\[nginx-444-rce\]" "${JAIL_LOCAL}"; then
  echo "[*] Adding [nginx-444-rce] jail to ${JAIL_LOCAL}..."
  cat >> "${JAIL_LOCAL}" <<'EOL'

[nginx-444-rce]
enabled  = true
port     = http,https
filter   = nginx-444-rce
logpath  = /var/log/nginx/access.log
maxretry = 3
findtime = 600
bantime  = 86400
EOL
else
  echo "[*] [nginx-444-rce] jail already present in jail.local, not modifying."
fi

########################################
# 9b. Fail2Ban SSH brute-force jail    #
########################################

# Ensure sshd jail is enabled
if ! grep -q "\[sshd\]" "${JAIL_LOCAL}"; then
  echo "[*] Adding [sshd] jail to ${JAIL_LOCAL}..."
  cat >> "${JAIL_LOCAL}" <<'EOL'

[sshd]
enabled  = true
port     = ssh
logpath  = /var/log/auth.log
maxretry = 5
findtime = 600
bantime  = 86400
EOL
else
  echo "[*] [sshd] jail already present in jail.local, not modifying."
fi

########################################
# 10. UFW firewall baseline            #
########################################

echo "[*] Configuring UFW firewall..."

if ! command -v ufw &> /dev/null; then
  apt-get install -y ufw
fi

ufw default deny incoming
ufw default allow outgoing

ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 60000:61000/udp   # mosh

echo
echo "[*] Current UFW rules (pre-enable):"
ufw status verbose || true

echo
read -rp "[?] Enable UFW now? This will apply the firewall rules. (y/n) " ANSWER
if [[ "${ANSWER}" == "y" || "${ANSWER}" == "Y" ]]; then
  echo "[*] Enabling UFW..."
  ufw --force enable
else
  echo "[*] Skipping UFW enable. You can enable later with: ufw enable"
fi

########################################
# 10b. Ensure Nginx & Fail2Ban enabled #
########################################

echo "[*] Ensuring nginx and fail2ban are enabled on boot..."
systemctl enable nginx || true
systemctl enable fail2ban || true

########################################
# 11. Docker CE + Compose + hardening  #
########################################

echo "[*] Installing Docker CE and Docker Compose..."

# Remove any conflicting old versions (just in case)
apt-get remove -y docker docker-engine docker.io containerd runc || true

# Install Docker repo dependencies
apt-get install -y ca-certificates curl gnupg

# Add Docker’s official GPG key if not present
install -m 0755 -d /etc/apt/keyrings
if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
  echo "[*] Adding Docker GPG key..."
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
fi

# Add Docker’s official apt repo
echo "[*] Adding Docker APT repository..."
cat > /etc/apt/sources.list.d/docker.list <<EOL
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable
EOL

apt-get update -y

# Install Docker engine, CLI, buildx, compose v2
apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

# Docker data-root (default)
DOCKER_DATA_ROOT="/var/lib/docker"
mkdir -p "${DOCKER_DATA_ROOT}"
chown root:root "${DOCKER_DATA_ROOT}"

# Harden Docker daemon config
DAEMON_JSON="/etc/docker/daemon.json"
mkdir -p /etc/docker

if [[ -f "${DAEMON_JSON}" ]]; then
  echo "[*] Backing up existing ${DAEMON_JSON} to ${DAEMON_JSON}.bak"
  cp "${DAEMON_JSON}" "${DAEMON_JSON}.bak"
fi

cat > "${DAEMON_JSON}" <<EOF
{
  "data-root": "${DOCKER_DATA_ROOT}",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "5"
  },
  "live-restore": true,
  "no-new-privileges": true
}
EOF

echo "[*] Enabling and restarting Docker..."
systemctl enable docker
systemctl restart docker

echo "[*] Docker version:"
docker --version || echo "[-] Docker failed to report version."

echo "[*] Docker Compose version:"
docker compose version || echo "[-] Docker Compose failed to report version."

echo "[*] Adding users 'mark' and 'git' to docker group..."
usermod -aG docker mark || true
usermod -aG docker git || true

echo "[*] Docker installed with:"
echo "    - data-root: ${DOCKER_DATA_ROOT}"
echo "    - log rotation: 10m per file, 5 files"
echo "    - live-restore: true"
echo "    - no-new-privileges: true (default for containers)"

########################################
# 12. Restart Nginx & Fail2Ban         #
########################################

echo
echo "[*] Testing Nginx config..."
nginx -t

echo "[*] Restarting Nginx and Fail2Ban..."
systemctl restart nginx
systemctl restart fail2ban

echo
echo "[*] Fail2Ban jail status for nginx-444-rce:"
fail2ban-client status nginx-444-rce || echo "   (jail not active, check jail.local & logpath)"

echo
echo "[+] Bootstrap + hardening complete."
echo "    - Credentials file: ${CRED_FILE} (root-only)"
echo "    - Nginx security snippet: ${RCE_SNIPPET}"
echo "    - Fail2Ban jails: nginx-444-rce (RCE probes) and sshd (SSH brute-force)"
echo "    - UFW: deny incoming, allow 22/tcp, 80/tcp, 443/tcp, 60000:61000/udp"
echo "    - ClamAV + rkhunter: AV + daily rootkit scan"
echo "    - NVM: /usr/local/nvm, Node 18 & 22, default 22"
echo "    - Databases: dev_admin user in MariaDB & Postgres"
echo "    - Docker: hardened daemon, data-root ${DOCKER_DATA_ROOT}, log rotation"
echo
echo "    Remember to include in each server block you want protected:"
echo
echo "        server {"
echo "            include snippets/rce-global.conf;"
echo "            # ...your existing config..."
echo "        }"
