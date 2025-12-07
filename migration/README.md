Usage on new server
sudo bash prepare_new_server.sh


Usage on infected server:
NEW_SERVER_HOST="your.new.server.ip.or.hostname"
SSH_PORT=22  # change if needed

sudo bash migrate_nginx_letsencrypt.sh


3️⃣ Applying configs on the new server (manual but straightforward)
# On new server, as root

# 1) Inspect:
ls -R /root/migrate/etc-nginx
ls -R /root/migrate/etc-letsencrypt

# 2) Copy site configs (NOT blindly nginx.conf unless you intend to):
cp /root/migrate/etc-nginx/sites-available/* /etc/nginx/sites-available/
cp /root/migrate/etc-nginx/sites-enabled/*   /etc/nginx/sites-enabled/

# If you want to merge nginx.conf, do a diff first:
diff -u /etc/nginx/nginx.conf /root/migrate/etc-nginx/nginx.conf || true

# 3) Copy certbot tree into place:
mkdir -p /etc/letsencrypt
cp -a /root/migrate/etc-letsencrypt/* /etc/letsencrypt/


nginx -t
systemctl restart nginx

Once you’re happy HTTPS is working, force-renew certs so you’re not relying on potentially-exposed private keys:
certbot renew --force-renewal
# or per-domain:
# certbot certonly --nginx -d yourdomain.com -d www.yourdomain.com
