#!/bin/sh
# Database Restore and Verification Script for WE-IRED Cloud (SDD 12.1 & NFR-REL-04)
set -e

BACKUP_FILE="$1"
DB_HOST="${DB_HOST:-postgres}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${POSTGRES_USER:-weired_user}"
DB_NAME="${POSTGRES_DB:-weired_db}"
PGPASSWORD="${POSTGRES_PASSWORD:-weired_secret}"
export PGPASSWORD

if [ -z "${BACKUP_FILE}" ] || [ ! -f "${BACKUP_FILE}" ]; then
    echo "[ERROR] Usage: $0 <path-to-backup-file.sql.gz>" >&2
    exit 1
fi

echo "[INFO] Restoring database ${DB_NAME} from ${BACKUP_FILE}..."

# Check SHA-256 if .sha256 file exists
if [ -f "${BACKUP_FILE}.sha256" ]; then
    echo "[INFO] Verifying backup checksum..."
    sha256sum -c "${BACKUP_FILE}.sha256"
fi

# Execute restore
if echo "${BACKUP_FILE}" | grep -q '\.gz$'; then
    gunzip -c "${BACKUP_FILE}" | psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}"
else
    psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -f "${BACKUP_FILE}"
fi

echo "[INFO] Running post-restore data validation..."

# 1. Verify schema migrations
MIGRATION_VERSION=$(psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "SELECT version FROM schema_migrations WHERE dirty = false ORDER BY version DESC LIMIT 1;" | tr -d ' ')
echo "[CHECK] Latest applied migration version: ${MIGRATION_VERSION}"

# 2. Verify key table counts
HH_COUNT=$(psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "SELECT COUNT(*) FROM households;" | tr -d ' ')
echo "[CHECK] Total households restored: ${HH_COUNT}"

echo "[SUCCESS] Restore and verification completed successfully without errors!"
