#!/bin/bash

# Historical Killmail Import Script
# This script runs in an init container to import historical killmail data
# from JSON files on the host system into the database.

set -e

echo "🚀 Starting historical killmail import..."

# Configuration
ARCHIVE_DIR="/data/killmail_archives"
LOCK_FILE="/data/.import_completed"
LOG_FILE="/data/import.log"

# Check if import already completed
if [ -f "$LOCK_FILE" ]; then
    echo "✅ Import already completed (lock file exists)"
    echo "   Delete $LOCK_FILE to re-run import"
    exit 0
fi

# Check if archive directory exists
if [ ! -d "$ARCHIVE_DIR" ]; then
    echo "📁 Archive directory not found: $ARCHIVE_DIR"
    echo "   Create directory and place JSON files there to enable import"
    exit 0
fi

# Check if archive files exist
archive_files=$(find "$ARCHIVE_DIR" -name "*.json" -type f 2>/dev/null | wc -l)
if [ "$archive_files" -eq 0 ]; then
    echo "📄 No JSON archive files found in $ARCHIVE_DIR"
    echo "   Place killmail archive files (*.json) there to enable import"
    exit 0
fi

echo "📊 Found $archive_files archive files"

# Wait for database to be ready
echo "🔄 Waiting for database..."
while ! mix ecto.migrate 2>/dev/null; do
    echo "   Database not ready, waiting 5 seconds..."
    sleep 5
done

echo "✅ Database ready"

# Start import process
echo "🔥 Starting import process..."
echo "   Batch size: 500"
echo "   Log file: $LOG_FILE"

# Run the import task
if mix eve.import_historical_killmails \
    --batch-size 500 \
    --file "$ARCHIVE_DIR/*.json" 2>&1 | tee "$LOG_FILE"; then
    
    # Create lock file on success
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) Import completed successfully" > "$LOCK_FILE"
    echo "✅ Import completed successfully!"
    
    # Log summary
    total_imported=$(grep -c "✅ Imported" "$LOG_FILE" || echo "0")
    echo "📈 Total files processed: $total_imported"
    
else
    echo "❌ Import failed - check logs at $LOG_FILE"
    exit 1
fi

echo "🎉 Historical killmail import complete!"