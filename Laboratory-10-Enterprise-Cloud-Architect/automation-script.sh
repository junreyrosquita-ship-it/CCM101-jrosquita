#!/usr/bin/env bash
# The Enterprise Cloud Architect — ROSQUITA Group
# Compressed MySQL backup, archive validation, logging, and 7-day retention.

set -Eeuo pipefail
umask 077

PROJECT_DIR="${HOME}/The-Enterprise-Cloud-Architect"
BACKUP_DIR="${PROJECT_DIR}/backups"
LOG_DIR="${PROJECT_DIR}/logs"
LOG_FILE="${LOG_DIR}/backup.log"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
FINAL_FILE="${BACKUP_DIR}/enterprise_cloud_${TIMESTAMP}.sql.gz"
TEMP_FILE="${FINAL_FILE}.tmp"

mkdir -p "$BACKUP_DIR" "$LOG_DIR"
cd "$PROJECT_DIR"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

cleanup() {
  rm -f "$TEMP_FILE"
}
trap cleanup EXIT

log "================================================"
log "THE ENTERPRISE CLOUD ARCHITECT — ROSQUITA GROUP"
log "Database backup started"

if ! docker info >/dev/null 2>&1; then
  log "ERROR: Docker is unavailable. Check Docker service and permissions."
  exit 1
fi

if ! docker compose ps --status running --services | grep -qx mysql; then
  log "ERROR: MySQL service is not running."
  log "Start services with: docker compose up -d"
  log "Inspect with: docker compose ps && docker compose logs mysql"
  exit 1
fi

log "MySQL service is running. Creating compressed database dump..."

if ! docker compose exec -T mysql sh -c \
  'exec mysqldump --single-transaction --routines --triggers -uroot -p"$MYSQL_ROOT_PASSWORD" --databases "$MYSQL_DATABASE"' \
  | gzip -c > "$TEMP_FILE"; then
  log "ERROR: mysqldump or compression failed."
  exit 1
fi

if [[ ! -s "$TEMP_FILE" ]] || ! gzip -t "$TEMP_FILE"; then
  log "ERROR: Backup is empty or gzip validation failed."
  exit 1
fi

mv "$TEMP_FILE" "$FINAL_FILE"
chmod 600 "$FINAL_FILE"
log "Backup completed and verified: $FINAL_FILE"
log "Backup size: $(du -h "$FINAL_FILE" | cut -f1)"

find "$BACKUP_DIR" -type f -name 'enterprise_cloud_*.sql.gz' -mtime +7 -print -delete \
  | while IFS= read -r removed; do log "Removed expired backup: $removed"; done

log "Backup process completed successfully."
log "================================================"
