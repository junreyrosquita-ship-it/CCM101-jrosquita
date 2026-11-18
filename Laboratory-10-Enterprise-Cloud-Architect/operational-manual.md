# Operational Manual
## The Enterprise Cloud Architect — ROSQUITA Group

**Course:** CCM101 – Cloud Computing  
**Platform:** Ubuntu Server on VirtualBox  
**Application stack:** WordPress + MySQL 8.4  
**Container platform:** Docker Engine and Docker Compose

## 1. Purpose

This manual explains how to deploy, secure, operate, back up, and recover the ROSQUITA Group's multi-tier WordPress infrastructure. It is intended for a classroom/laboratory environment. A production deployment should additionally use HTTPS, external backup storage, monitoring/alerting, and a documented update process.

## 2. Architecture

A Windows host runs VirtualBox, which hosts an Ubuntu Server VM. UFW provides host-level firewall policy. Docker Compose runs WordPress and MySQL on a private bridge network. WordPress publishes host port 8080 by default; MySQL has no host-published port. Named volumes persist WordPress and database data. A Bash script creates compressed database backups, and Cron schedules the script.

See `architecture-diagram.png`.

## 3. Requirements

- Ubuntu Server VM with network connectivity
- Suggested lab resources: 2 vCPU, 4 GB RAM, 25 GB disk
- Docker Engine and Docker Compose plugin
- SSH access if remote administration is needed
- Browser on a device that can reach the VM
- Two strong, unique MySQL passwords

## 4. Project structure

```text
The-Enterprise-Cloud-Architect/
├── docker-compose.yml
├── .env                  # create locally; do not commit
├── .env.example
├── .gitignore
├── automation-script.sh
├── README.md
├── operational-manual.md
├── final-reflection.md
├── two-person-presentation-script.md
├── architecture-diagram.png
├── backups/
└── logs/
```

## 5. Environment configuration

```bash
cd ~/The-Enterprise-Cloud-Architect
cp .env.example .env
nano .env
chmod 600 .env
```

Set a long, unique `MYSQL_ROOT_PASSWORD` and a different `MYSQL_PASSWORD`. Keep `.env` private. The default WordPress host port is 8080.

## 6. Deploy WordPress and MySQL

```bash
docker compose config
docker compose pull
docker compose up -d
docker compose ps
```

Wait until MySQL is healthy. If a service does not start:

```bash
docker compose logs --tail=100 mysql
docker compose logs --tail=100 wordpress
```

Open `http://YOUR-UBUNTU-IP:8080` and complete the WordPress installation. Create a WordPress administrator account; do not reuse the MySQL credentials as the WordPress administrator password.

## 7. Firewall and network security

If SSH and WordPress are required, allow the correct SSH port and port 8080 before enabling UFW:

```bash
sudo ufw allow 22/tcp
sudo ufw allow 8080/tcp
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
sudo ufw status verbose
```

If SSH uses a different port, allow that port instead. Do not publish MySQL port 3306. WordPress connects to MySQL using `mysql:3306` on the private Compose network.

**Docker firewall caveat:** Docker-published ports can bypass ordinary UFW rules depending on host configuration. Test reachability from another device and apply Docker-aware filtering (for example, through the `DOCKER-USER` chain) or upstream network restrictions. Do not claim a port is blocked until it has been tested.

For production, use HTTPS through a reverse proxy, restrict access to trusted networks, keep packages updated, and apply appropriate protections to the WordPress administration interface.

## 8. Persistent storage

The named volumes are:
- `rosquita_enterprise_mysql_data`
- `rosquita_enterprise_wordpress_data`

Inspect them:

```bash
docker volume ls
docker volume inspect rosquita_enterprise_mysql_data
docker volume inspect rosquita_enterprise_wordpress_data
```

Restart without deleting data:

```bash
docker compose restart
```

Routine stop (preserves volumes):

```bash
docker compose down
```

**Do not use `docker compose down -v` for routine shutdown or reboot testing.** The `-v` option removes named volumes and deletes persistent application/database data.

## 9. Manual database backup

```bash
chmod +x automation-script.sh
./automation-script.sh
ls -lh backups/
tail -30 logs/backup.log
```

The script checks Docker and MySQL, runs `mysqldump`, compresses the SQL dump, validates the gzip archive, logs the result, and removes matching archives older than seven days.

A backup on the same VM does not protect against VM or disk loss. Copy verified archives to separate protected storage.

## 10. Cron scheduling

Check the server timezone:

```bash
timedatectl
```

Edit the current user's crontab:

```bash
crontab -e
```

Add a daily 2:00 AM schedule, replacing the username/path if needed:

```cron
0 2 * * * /home/YOUR_USERNAME/The-Enterprise-Cloud-Architect/automation-script.sh
```

Verify:

```bash
crontab -l
sudo systemctl status cron
```

For a brief test only, temporarily use `* * * * *`, wait for a run, inspect `logs/backup.log`, then restore the daily schedule.

## 11. Database restore

**Caution:** Restoring a database changes its contents. Make a fresh backup first, verify the selected archive, and perform the restore during a planned recovery window or in a disposable test environment.

List and validate archives:

```bash
ls -lh backups/
gzip -t backups/enterprise_cloud_TIMESTAMP.sql.gz
```

Restore the chosen archive:

```bash
gunzip -c backups/enterprise_cloud_TIMESTAMP.sql.gz |   docker compose exec -T mysql sh -c   'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD"'
```

Replace `TIMESTAMP` with the actual filename. Verify:

```bash
docker compose exec mysql sh -c   'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SHOW DATABASES; SHOW TABLES FROM enterprise_cloud;"'
```

## 12. Monitoring and maintenance

```bash
docker compose ps
docker stats --no-stream
df -h
free -h
docker compose logs --tail=100
sudo journalctl -u cron --no-pager -n 50
```

Before updating images, create and verify a backup, review release notes, update during a maintenance window, and verify the site and database afterward:

```bash
docker compose pull
docker compose up -d
docker compose ps
```

For repeatable deployments, pin tested image versions rather than relying indefinitely on moving tags.

## 13. Troubleshooting

### MySQL is not running/healthy

```bash
docker compose ps -a
docker compose logs mysql --tail=100
docker compose config
```

Check `.env`, passwords, disk space, and logs. Changing `.env` after MySQL has initialized its data volume does not automatically change an existing MySQL account password.

### WordPress cannot connect to MySQL

Check that:
- `WORDPRESS_DB_HOST` is `mysql:3306`
- Both services are on the Compose network
- Database name, username, and password match
- MySQL reports healthy

```bash
docker compose logs wordpress --tail=100
docker compose logs mysql --tail=100
```

### Website cannot be reached

```bash
hostname -I
docker compose ps
sudo ufw status verbose
sudo ss -tulpn
```

Confirm that the browser uses `http://VM-IP:8080` and that VirtualBox networking allows host-to-guest access.

## 14. Recovery after Ubuntu reboot

```bash
sudo systemctl status docker
sudo systemctl status cron
cd ~/The-Enterprise-Cloud-Architect
docker compose ps
```

Containers should restart automatically because of `restart: unless-stopped`, provided they were not explicitly stopped using `docker compose down`.

## 15. Operational checklist

- [ ] WordPress page loads from the host browser
- [ ] MySQL is healthy
- [ ] MySQL port is not published to the host
- [ ] Firewall policy and actual network access have been tested
- [ ] Both named volumes exist
- [ ] Backup script creates a valid archive
- [ ] Cron schedule is installed and verified
- [ ] Restore procedure has been tested safely
- [ ] A copy of backups exists outside the VM
- [ ] `.env` is excluded from Git
