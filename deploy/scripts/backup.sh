#!/bin/sh
# Daily PostgreSQL Backup Script for WE-IRED Cloud (SDD 12.1 & NFR-REL-04)
set -e

BACKUP_DIR="${BACKUP_DIR:-/backups}"
DB_HOST="${DB_HOST:-postgres}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${POSTGRES_USER:-weired_user}"
DB_NAME="${POSTGRES_DB:-weired_db}"
PGPASSWORD="${POSTGRES_PASSWORD:-weired_secret}"
export PGPASSWORD

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/weired_backup_${TIMESTAMP}.sql.gz"

mkdir -p "${BACKUP_DIR}"

echo "[INFO] Starting database backup for ${DB_NAME} at $(date)..."
pg_dump -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" --clean --if-exists | gzip -9 > "${BACKUP_FILE}"

# Verify file exists and has non-zero size
if [ ! -s "${BACKUP_FILE}" ]; then
    echo "[ERROR] Backup failed: file is empty or missing!" >&2
    exit 1
fi

# Generate SHA-256 checksum
sha256sum "${BACKUP_FILE}" > "${BACKUP_FILE}.sha256"
FILE_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)

echo "[SUCCESS] Backup created successfully: ${BACKUP_FILE} (${FILE_SIZE})"
cat "${BACKUP_FILE}.sha256"

# Rotate: remove backups older than 7 days
find "${BACKUP_DIR}" -name "weired_backup_*.sql.gz*" -mtime +7 -delete 2>/dev/null || true
echo "[INFO] Old backups cleaned up. Backup complete."
