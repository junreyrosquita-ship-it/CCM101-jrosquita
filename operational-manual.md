CCM101 - Cloud Computing
# Enterprise Cloud Architect - Operational Manual

**Project:** Secure Multi-Tier Web Application
**Application Stack:** WordPress + MySQL
**Prepared by:** *(Your Name | Group Member 2 | Group Member 3)*
**Section:** *(Your Section)*
**Instructor:** Jenkielyn C. Torres
**Date:** November 2026

*Page size for hardcopy: Coupon 5.5 x 8.5 in (portrait)*

---

## 1. Executive Summary

CloudNova Technologies needs a highly secure, automated and observable private cloud environment for a Fortune 500 client. This project delivers a two-tier web application (WordPress and MySQL) running in Docker containers on an Ubuntu Server virtual machine.

Key properties of the delivered system:

- **Multi-tier:** a web tier and a database tier on a private Docker network.
- **Persistent:** database and website data live on named Docker volumes and survive container removal and VM reboots.
- **Secure:** UFW with a default-deny policy allows only SSH (22) and HTTP (80). The database is never published to the network.
- **Self-managing:** a cron job runs a Bash script every night to check container health, back up the database, and delete backups older than 7 days.
- **Reproducible:** the whole stack is defined in one `docker-compose.yml` and deploys with a single command.

## 2. Architecture Overview

![Architecture diagram](architecture-diagram.png)

Traffic flows from the browser on the host laptop, through the hypervisor's virtual network, into the Ubuntu VM. UFW inspects the traffic and only lets ports 22 and 80 through. Port 80 reaches the WordPress container, which talks to the MySQL container over the private `backend` Docker network. MySQL stores data on the `db_data` volume. The cron job runs on the VM and writes compressed backups to `~/backups`.

| Component | Role | Exposed? |
|---|---|---|
| WordPress container (`cloudnova-web`) | Web tier | Port 80 |
| MySQL container (`cloudnova-db`) | Database tier | No, internal network only |
| `db_data` volume | Database files | No |
| `wp_data` volume | WordPress files and uploads | No |
| `~/backups` | Compressed SQL dumps | No |

## 3. Prerequisites

| Item | Requirement |
|---|---|
| Host | Laptop or PC with virtualization enabled in BIOS/UEFI |
| Hypervisor | VirtualBox (or VMware Workstation Player) |
| ISO | Ubuntu Server (latest LTS) |
| VM resources | 2 CPUs, 2 to 4 GB RAM, 20 GB disk |
| Network | Internet access for package and image downloads |
| Accounts | GitHub account holding this repository |

## 4. Deployment Guide

### 4.1 Create the virtual machine

1. In VirtualBox choose **New**, name the VM, select the Ubuntu Server ISO, set 2 CPUs, 2 to 4 GB RAM and a 20 GB disk.
2. Start the VM and install Ubuntu Server. Enable **OpenSSH server** when asked. Skip optional snaps.
3. Reboot and log in.

### 4.2 Configure networking

Choose one option.

**Option A: Bridged Adapter.** In VM Settings, Network, set Attached to *Bridged Adapter*. The VM gets an address on your LAN. Find it with `ip a`. Use `http://<vm-ip>` and `ssh user@<vm-ip>`.

**Option B: NAT with port forwarding.** In VM Settings, Network, Advanced, Port Forwarding, add:

| Name | Host port | Guest port |
|---|---|---|
| SSH | 2222 | 22 |
| HTTP | 8080 | 80 |

Use `http://localhost:8080` and `ssh -p 2222 user@127.0.0.1`.

Test SSH from the host, then update the system:

```bash
sudo apt update && sudo apt upgrade -y
```

### 4.3 Install Docker and Docker Compose

Follow the official instructions at <https://docs.docker.com/engine/install/ubuntu/> (apt repository method, which also installs the Compose plugin). Then:

```bash
sudo usermod -aG docker $USER      # log out and back in afterwards
docker --version
docker compose version
docker run hello-world
```

### 4.4 Deploy the stack

```bash
mkdir -p ~/enterprise-stack && cd ~/enterprise-stack
# copy docker-compose.yml and .env.example here (git clone or scp)
cp .env.example .env
nano .env                          # replace all passwords
chmod 600 .env
docker compose up -d
docker compose ps
```

Open the site in the host browser and complete the WordPress installer (site title, admin user, strong admin password).

### 4.5 Verify persistence

```bash
docker volume ls                   # db_data and wp_data should be listed
sudo reboot
# after the VM comes back:
cd ~/enterprise-stack && docker compose ps
```

The containers restart automatically (`restart: unless-stopped`) and the site content is still present.

## 5. Security Guide

### 5.1 Firewall (UFW)

Always add the SSH rule **before** enabling UFW, otherwise you lock yourself out.

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'WordPress HTTP'
sudo ufw enable
sudo ufw status verbose
```

| Rule | Why |
|---|---|
| Default deny incoming | Anything not explicitly allowed is blocked |
| Default allow outgoing | The server can download updates and images |
| 22/tcp | Remote administration over SSH |
| 80/tcp | The WordPress web interface |
| 3306 (MySQL) | **Not opened.** The database is only reachable inside Docker |

### 5.2 Container exposure

Only the WordPress container publishes a port. MySQL has no `ports:` entry, so it is reachable only from other containers on the `backend` network.

> **Known caveat:** Docker publishes ports by writing iptables rules directly, which can bypass UFW for any port listed under `ports:`. This is why the stack publishes only port 80 and never the database. Do not add `3306:3306` to the compose file.

### 5.3 Additional hardening

- Disable root SSH login: set `PermitRootLogin no` in `/etc/ssh/sshd_config`, then `sudo systemctl restart ssh`.
- Keep credentials in `.env` with `chmod 600 .env`. Never commit `.env`.
- Optionally install fail2ban: `sudo apt install fail2ban`.
- Keep the system patched: `sudo apt update && sudo apt upgrade -y`.

### 5.4 Verification

From the host laptop, scan the VM and confirm that only ports 22 and 80 are open:

```bash
nmap <vm-ip>
```

## 6. Maintenance Guide

### 6.1 Automated backup

`automation-script.sh` performs these steps:

1. Loads credentials from `~/enterprise-stack/.env`.
2. Checks that `cloudnova-db` is running (aborts with an error log if not) and warns if `cloudnova-web` is down.
3. Dumps the database with `mysqldump` and compresses it to `~/backups/db_<timestamp>.sql.gz`.
4. Rejects empty backups.
5. Deletes backups older than 7 days.
6. Writes a result line to `~/backups/backup.log`.

Install and schedule it:

```bash
cp automation-script.sh ~/enterprise-stack/
chmod +x ~/enterprise-stack/automation-script.sh
~/enterprise-stack/automation-script.sh && ls -lh ~/backups
crontab -e
```

Add this line (daily at 2:00 AM). Replace `youruser` with your username:

```
0 2 * * * /home/youruser/enterprise-stack/automation-script.sh
```

Verify with `crontab -l`. To demonstrate it live, temporarily use `* * * * *` (every minute) and change it back afterwards.

### 6.2 Restore from backup

```bash
cd ~/enterprise-stack && source .env
gunzip < ~/backups/db_<timestamp>.sql.gz | \
  docker exec -i cloudnova-db mysql -u root -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"
```

### 6.3 Updating the containers

```bash
cd ~/enterprise-stack
docker compose pull
docker compose up -d
docker image prune -f
```

Run a backup before every update.

### 6.4 Logs and monitoring

```bash
docker compose logs -f --tail=50         # live logs, both containers
docker compose logs db                   # database only
docker stats --no-stream                 # CPU and memory per container
cat ~/backups/backup.log                 # backup history
sudo ufw status verbose                  # firewall state
df -h                                    # disk space
```

### 6.5 Stopping and removing

| Command | Effect on data |
|---|---|
| `docker compose stop` / `start` | Data kept |
| `docker compose down` | Containers and network removed, **volumes kept** |
| `docker compose down -v` | Containers **and volumes deleted. Data is lost** |

## 7. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Browser cannot reach the site | Wrong IP, NAT forwarding missing, or UFW blocking 80 | Check `ip a`, VirtualBox port forwarding, and `sudo ufw status` |
| Locked out of SSH after enabling UFW | Port 22 rule was not added first | Use the VM console in VirtualBox, run `sudo ufw allow 22/tcp` |
| "Error establishing a database connection" | DB still starting, or wrong credentials in `.env` | Wait 30 seconds, check `docker compose logs db`, confirm `.env` values |
| Changed `.env` password has no effect | MySQL only reads the passwords on first initialization of the volume | Change the password inside MySQL, or recreate the volume (loses data, restore from backup) |
| `permission denied` running docker | User not in the docker group | `sudo usermod -aG docker $USER`, then log out and in |
| Backup log says container not running | Stack is down | `docker compose up -d`, then re-run the script |
| Cron does not run the script | Wrong path or script not executable | Use absolute paths, `chmod +x`, check `grep CRON /var/log/syslog` |
| Port 80 already in use | Another service on the VM | `sudo ss -tlnp | grep :80`, stop the other service |

## 8. Appendices

### Appendix A: docker-compose.yml

```yaml
services:
  db:
    image: mysql:8.0
    container_name: cloudnova-db
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - db_data:/var/lib/mysql
    networks:
      - backend

  wordpress:
    image: wordpress:latest
    container_name: cloudnova-web
    restart: unless-stopped
    depends_on:
      - db
    ports:
      - "80:80"
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_USER: ${MYSQL_USER}
      WORDPRESS_DB_PASSWORD: ${MYSQL_PASSWORD}
      WORDPRESS_DB_NAME: ${MYSQL_DATABASE}
    volumes:
      - wp_data:/var/www/html
    networks:
      - backend

volumes:
  db_data:
  wp_data:

networks:
  backend:
```

### Appendix B: .env.example

```
MYSQL_ROOT_PASSWORD=ChangeMe_Root_123
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
MYSQL_PASSWORD=ChangeMe_User_123
```

### Appendix C: automation-script.sh

```bash
#!/bin/bash
set -euo pipefail

STACK_DIR="${STACK_DIR:-$HOME/enterprise-stack}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/backups}"
LOG_FILE="$BACKUP_DIR/backup.log"
RETENTION_DAYS=7
STAMP=$(date +%F_%H-%M-%S)

mkdir -p "$BACKUP_DIR"

if [ ! -f "$STACK_DIR/.env" ]; then
  echo "[$STAMP] ERROR: $STACK_DIR/.env not found" >> "$LOG_FILE"
  exit 1
fi
source "$STACK_DIR/.env"

if ! docker ps --format '{{.Names}}' | grep -q '^cloudnova-db$'; then
  echo "[$STAMP] ERROR: cloudnova-db container is not running" >> "$LOG_FILE"
  exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q '^cloudnova-web$'; then
  echo "[$STAMP] WARNING: cloudnova-web container is not running" >> "$LOG_FILE"
fi

OUT_FILE="$BACKUP_DIR/db_$STAMP.sql.gz"
docker exec cloudnova-db mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" \
  --single-transaction "$MYSQL_DATABASE" 2>/dev/null | gzip > "$OUT_FILE"

if [ ! -s "$OUT_FILE" ]; then
  echo "[$STAMP] ERROR: backup file is empty, removing $OUT_FILE" >> "$LOG_FILE"
  rm -f "$OUT_FILE"
  exit 1
fi

find "$BACKUP_DIR" -name "db_*.sql.gz" -mtime +"$RETENTION_DAYS" -delete

echo "[$STAMP] Backup OK: $(basename "$OUT_FILE") ($(du -h "$OUT_FILE" | cut -f1))" >> "$LOG_FILE"
```

### Appendix D: Command quick reference

| Task | Command |
|---|---|
| Start stack | `docker compose up -d` |
| Status | `docker compose ps` |
| Logs | `docker compose logs -f` |
| Stop stack | `docker compose stop` |
| Manual backup | `~/enterprise-stack/automation-script.sh` |
| Firewall status | `sudo ufw status verbose` |
| Scheduled jobs | `crontab -l` |
