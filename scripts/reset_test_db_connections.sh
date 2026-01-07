#!/bin/bash
# Kill all connections to test database before running tests
# This prevents FATAL 53300 (too_many_connections) errors

set -e

DB_HOST="${DB_HOST:-db}"
DB_USER="${DB_USER:-postgres}"
DB_PASS="${DB_PASS:-postgres}"
DB_NAME="${DB_NAME:-eve_dmv_test}"

echo "Terminating existing connections to ${DB_NAME}..."

PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -U "$DB_USER" -d postgres -c "
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname LIKE '${DB_NAME}%'
  AND pid <> pg_backend_pid();
" 2>/dev/null || echo "No connections to terminate"

echo "Connections cleared."
