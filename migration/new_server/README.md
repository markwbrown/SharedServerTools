# If your configs landed at /root/migrate/home-git-configs
./root/rotate_env_secrets.py /root/migrate/home-git-configs

# And/or if you have .env files under /root/migrate/git
./root/rotate_env_secrets.py /root/migrate/git

For each .env:

You’ll get prompted key-by-key:

k → keep the value as-is (knowing it came from compromised box)

r → replace with a new strong random value

s → stop touching this whole file, leave it exactly as-is

q → quit the script immediately

Every time a file is modified, a backup is created as whatever.env.bak right next to it.