# Laboratory 10 - Enterprise Cloud Architect

**CCM101 - Cloud Computing** | University of Eastern Pangasinan | College of Information Technology

## Overview

A secure, automated, multi-tier private cloud environment built for the CloudNova Technologies Fortune 500 contract. A WordPress web tier talks to a MySQL database tier over a private Docker network. The database lives on a persistent volume, the host is locked down with UFW (default deny), and a Bash script backs up the database every night through cron.

## Stack

| Layer | Technology |
|---|---|
| Host | Physical laptop, any OS |
| Hypervisor | VirtualBox (Type 2) |
| Guest OS | Ubuntu Server (headless, latest LTS) |
| Firewall | UFW, default deny incoming |
| Container runtime | Docker Engine + Docker Compose |
| Web tier | WordPress (`wordpress:latest`) |
| Database tier | MySQL 8.0 (`mysql:8.0`) |
| Persistence | Named volumes `db_data` and `wp_data` |
| Automation | `automation-script.sh` + cron (daily, 2:00 AM) |

## How to View the Files

| File | What it is |
|---|---|
| [`architecture-diagram.png`](architecture-diagram.png) | Network topology: host, hypervisor, VM, firewall, containers, volumes |
| [`docker-compose.yml`](docker-compose.yml) | Infrastructure as Code for the two-tier stack |
| [`.env.example`](.env.example) | Template for credentials (copy to `.env`, never commit the real one) |
| [`automation-script.sh`](automation-script.sh) | Backup + health check script run by cron |
| [`operational-manual.md`](operational-manual.md) | Handover manual: deploy, secure, maintain, troubleshoot |
| [`final-reflection.md`](final-reflection.md) | Reflection on Missions 1 to 10 |

## Quick Start

```bash
git clone https://github.com/<your-username>/CCM101-jentorres.git
cd CCM101-jentorres/Laboratory-10-Enterprise-Cloud-Architect
cp .env.example .env && nano .env      # set real passwords
docker compose up -d
docker compose ps
```

Then open `http://<vm-ip>` in a browser to finish the WordPress setup. The full procedure, including VM setup, firewall rules and cron, is in the [operational manual](operational-manual.md).

## Screenshots

Add your own screenshots to a `screenshots/` folder and link them below.

| # | Evidence | File |
|---|---|---|
| 1 | VirtualBox VM settings (CPU, RAM, network) | `screenshots/01-vm-settings.png` |
| 2 | `ssh` login from the host to the VM | `screenshots/02-ssh-login.png` |
| 3 | `docker --version` and `docker compose version` | `screenshots/03-docker-versions.png` |
| 4 | `docker compose ps` showing both containers | `screenshots/04-compose-ps.png` |
| 5 | WordPress site open in the host browser | `screenshots/05-wordpress-site.png` |
| 6 | `sudo ufw status verbose` | `screenshots/06-ufw-status.png` |
| 7 | `nmap` scan showing only ports 22 and 80 | `screenshots/07-nmap-scan.png` |
| 8 | Backup script output and `ls -lh ~/backups` | `screenshots/08-backup-run.png` |
| 9 | `crontab -l` | `screenshots/09-crontab.png` |
| 10 | Site and data intact after `sudo reboot` | `screenshots/10-after-reboot.png` |

## Mission Requirements Checklist

- [x] Requirement 1: Architecture diagram, Ubuntu Server VM, browser access from host
- [x] Requirement 2: Docker + Compose, two linked containers, persistent database volume
- [x] Requirement 3: UFW enabled, default deny, only SSH and HTTP allowed
- [x] Requirement 4: Executable Bash script scheduled with cron
- [x] Requirement 5: Operational manual, raw code and final reflection in this folder

## Prepared By

Prepared by: *(your name / group members)*
Section: *(your section)*
Instructor: Jenkielyn C. Torres
Date: November 2026
