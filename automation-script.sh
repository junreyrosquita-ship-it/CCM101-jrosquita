#!/bin/bash
# =============================================================
# CloudNova Technologies - Database Backup + Health Check
# Run daily by cron. Dumps the MySQL database, compresses it,
# and deletes backups older than 7 days.
# =============================================================
set -euo pipefail

STACK_DIR="${STACK_DIR:-$HOME/enterprise-stack}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/backups}"
LOG_FILE="$BACKUP_DIR/backup.log"
RETENTION_DAYS=7
STAMP=$(date +%F_%H-%M-%S)

mkdir -p "$BACKUP_DIR"

# Load database credentials
if [ ! -f "$STACK_DIR/.env" ]; then
  echo "[$STAMP] ERROR: $STACK_DIR/.env not found" >> "$LOG_FILE"
  exit 1
fi
# shellcheck disable=SC1091
source "$STACK_DIR/.env"

# Health check: is the database container running?
if ! docker ps --format '{{.Names}}' | grep -q '^cloudnova-db$'; then
  echo "[$STAMP] ERROR: cloudnova-db container is not running" >> "$LOG_FILE"
  exit 1
fi

# Health check: is the web container running?
if ! docker ps --format '{{.Names}}' | grep -q '^cloudnova-web$'; then
  echo "[$STAMP] WARNING: cloudnova-web container is not running" >> "$LOG_FILE"
fi

# Database dump (compressed)
OUT_FILE="$BACKUP_DIR/db_$STAMP.sql.gz"
docker exec cloudnova-db mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" \
  --single-transaction "$MYSQL_DATABASE" 2>/dev/null | gzip > "$OUT_FILE"

# Make sure the backup is not empty
if [ ! -s "$OUT_FILE" ]; then
  echo "[$STAMP] ERROR: backup file is empty, removing $OUT_FILE" >> "$LOG_FILE"
  rm -f "$OUT_FILE"
  exit 1
fi

# Rotate old backups
find "$BACKUP_DIR" -name "db_*.sql.gz" -mtime +"$RETENTION_DAYS" -delete

echo "[$STAMP] Backup OK: $(basename "$OUT_FILE") ($(du -h "$OUT_FILE" | cut -f1))" >> "$LOG_FILE"
