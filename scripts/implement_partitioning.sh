#!/bin/bash
# EVE DMV Table Partitioning Implementation Script
# This script safely implements table partitioning for killmails_raw

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DATABASE_URL="${DATABASE_URL:-}"
DRY_RUN="${DRY_RUN:-false}"
BATCH_SIZE="${BATCH_SIZE:-10000}"
START_DATE="${START_DATE:-2024-01-01}"

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if [ -z "$DATABASE_URL" ]; then
        log_error "DATABASE_URL environment variable is not set"
        exit 1
    fi
    
    # Check PostgreSQL version (needs 11+ for partitioning)
    PG_VERSION=$(psql $DATABASE_URL -t -c "SELECT version();" | grep -oP 'PostgreSQL \K[0-9]+')
    if [ "$PG_VERSION" -lt 11 ]; then
        log_error "PostgreSQL version $PG_VERSION is too old. Need version 11+ for partitioning"
        exit 1
    fi
    
    # Check if killmails_raw exists
    TABLE_EXISTS=$(psql $DATABASE_URL -t -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'killmails_raw');")
    if [ "$TABLE_EXISTS" != " t" ]; then
        log_error "Table killmails_raw does not exist"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

# Get table statistics
get_table_stats() {
    log_info "Gathering table statistics..."
    
    TOTAL_ROWS=$(psql $DATABASE_URL -t -c "SELECT COUNT(*) FROM killmails_raw;")
    TABLE_SIZE=$(psql $DATABASE_URL -t -c "SELECT pg_size_pretty(pg_total_relation_size('killmails_raw'));")
    MIN_DATE=$(psql $DATABASE_URL -t -c "SELECT MIN(killmail_time)::date FROM killmails_raw;")
    MAX_DATE=$(psql $DATABASE_URL -t -c "SELECT MAX(killmail_time)::date FROM killmails_raw;")
    
    log_info "Table statistics:"
    log_info "  Total rows: $TOTAL_ROWS"
    log_info "  Table size: $TABLE_SIZE"
    log_info "  Date range: $MIN_DATE to $MAX_DATE"
}

# Create partition structure
create_partition_structure() {
    log_info "Creating partition structure..."
    
    if [ "$DRY_RUN" = "true" ]; then
        log_warn "DRY RUN MODE - Showing SQL that would be executed"
    fi
    
    # Create the partitioned table
    SQL="
    -- Create new partitioned table with same structure
    CREATE TABLE killmails_raw_partitioned (LIKE killmails_raw INCLUDING ALL) 
    PARTITION BY RANGE (killmail_time);
    
    -- Create partitions for each month
    "
    
    # Generate monthly partitions
    CURRENT_DATE="$START_DATE"
    END_DATE=$(date +%Y-%m-01)
    
    while [ "$CURRENT_DATE" \< "$END_DATE" ]; do
        YEAR=$(date -d "$CURRENT_DATE" +%Y)
        MONTH=$(date -d "$CURRENT_DATE" +%m)
        PARTITION_NAME="killmails_raw_${YEAR}_${MONTH}"
        NEXT_MONTH=$(date -d "$CURRENT_DATE +1 month" +%Y-%m-01)
        
        SQL="$SQL
        CREATE TABLE $PARTITION_NAME PARTITION OF killmails_raw_partitioned
        FOR VALUES FROM ('$CURRENT_DATE') TO ('$NEXT_MONTH');"
        
        CURRENT_DATE=$NEXT_MONTH
    done
    
    # Create future partitions (3 months ahead)
    for i in 1 2 3; do
        FUTURE_DATE=$(date -d "$END_DATE +$i month" +%Y-%m-01)
        YEAR=$(date -d "$FUTURE_DATE" +%Y)
        MONTH=$(date -d "$FUTURE_DATE" +%m)
        PARTITION_NAME="killmails_raw_${YEAR}_${MONTH}"
        NEXT_MONTH=$(date -d "$FUTURE_DATE +1 month" +%Y-%m-01)
        
        SQL="$SQL
        CREATE TABLE $PARTITION_NAME PARTITION OF killmails_raw_partitioned
        FOR VALUES FROM ('$FUTURE_DATE') TO ('$NEXT_MONTH');"
    done
    
    if [ "$DRY_RUN" = "true" ]; then
        echo "$SQL"
    else
        log_info "Creating partitioned table structure..."
        psql $DATABASE_URL -c "$SQL"
    fi
}

# Migrate data in batches
migrate_data() {
    log_info "Starting data migration..."
    
    if [ "$DRY_RUN" = "true" ]; then
        log_warn "DRY RUN MODE - Skipping actual data migration"
        return
    fi
    
    # Create progress tracking table
    psql $DATABASE_URL -c "
    CREATE TABLE IF NOT EXISTS partition_migration_progress (
        batch_id SERIAL PRIMARY KEY,
        min_id BIGINT,
        max_id BIGINT,
        row_count INT,
        started_at TIMESTAMP DEFAULT NOW(),
        completed_at TIMESTAMP
    );"
    
    # Get ID range
    MIN_ID=$(psql $DATABASE_URL -t -c "SELECT MIN(killmail_id) FROM killmails_raw;")
    MAX_ID=$(psql $DATABASE_URL -t -c "SELECT MAX(killmail_id) FROM killmails_raw;")
    
    CURRENT_ID=$MIN_ID
    BATCH_NUM=0
    
    while [ "$CURRENT_ID" -le "$MAX_ID" ]; do
        BATCH_NUM=$((BATCH_NUM + 1))
        NEXT_ID=$((CURRENT_ID + BATCH_SIZE))
        
        log_info "Processing batch $BATCH_NUM: IDs $CURRENT_ID to $NEXT_ID"
        
        # Record batch start
        psql $DATABASE_URL -c "
        INSERT INTO partition_migration_progress (min_id, max_id) 
        VALUES ($CURRENT_ID, $NEXT_ID);"
        
        # Migrate batch
        MIGRATED=$(psql $DATABASE_URL -t -c "
        WITH migrated AS (
            INSERT INTO killmails_raw_partitioned
            SELECT * FROM killmails_raw
            WHERE killmail_id >= $CURRENT_ID 
            AND killmail_id < $NEXT_ID
            ON CONFLICT DO NOTHING
            RETURNING killmail_id
        )
        SELECT COUNT(*) FROM migrated;")
        
        # Update progress
        psql $DATABASE_URL -c "
        UPDATE partition_migration_progress 
        SET completed_at = NOW(), row_count = $MIGRATED
        WHERE min_id = $CURRENT_ID AND max_id = $NEXT_ID;"
        
        log_info "  Migrated $MIGRATED rows"
        
        CURRENT_ID=$NEXT_ID
        
        # Brief pause to avoid overwhelming the database
        sleep 0.1
    done
    
    log_info "Data migration completed"
}

# Verify migration
verify_migration() {
    log_info "Verifying migration..."
    
    if [ "$DRY_RUN" = "true" ]; then
        log_warn "DRY RUN MODE - Skipping verification"
        return
    fi
    
    OLD_COUNT=$(psql $DATABASE_URL -t -c "SELECT COUNT(*) FROM killmails_raw;")
    NEW_COUNT=$(psql $DATABASE_URL -t -c "SELECT COUNT(*) FROM killmails_raw_partitioned;")
    
    if [ "$OLD_COUNT" -eq "$NEW_COUNT" ]; then
        log_info "Verification passed: $NEW_COUNT rows migrated successfully"
    else
        log_error "Verification failed: Old table has $OLD_COUNT rows, new table has $NEW_COUNT rows"
        exit 1
    fi
    
    # Verify indexes
    log_info "Verifying indexes..."
    OLD_INDEXES=$(psql $DATABASE_URL -t -c "SELECT COUNT(*) FROM pg_indexes WHERE tablename = 'killmails_raw';")
    NEW_INDEXES=$(psql $DATABASE_URL -t -c "SELECT COUNT(*) FROM pg_indexes WHERE tablename LIKE 'killmails_raw_%' AND tablename != 'killmails_raw';")
    
    log_info "  Original table indexes: $OLD_INDEXES"
    log_info "  Partitioned table indexes: $NEW_INDEXES"
}

# Swap tables
swap_tables() {
    log_info "Swapping tables..."
    
    if [ "$DRY_RUN" = "true" ]; then
        log_warn "DRY RUN MODE - Would swap tables here"
        return
    fi
    
    psql $DATABASE_URL -c "
    BEGIN;
    -- Rename original table
    ALTER TABLE killmails_raw RENAME TO killmails_raw_old;
    
    -- Rename partitioned table
    ALTER TABLE killmails_raw_partitioned RENAME TO killmails_raw;
    
    -- Update any views that reference the table
    -- (Add specific view updates here if needed)
    
    COMMIT;"
    
    log_info "Table swap completed"
}

# Create automated partition management
setup_auto_partitioning() {
    log_info "Setting up automated partition management..."
    
    SQL="
    -- Function to create monthly partitions
    CREATE OR REPLACE FUNCTION create_monthly_partition(table_name text, start_date date)
    RETURNS void AS \$\$
    DECLARE
        partition_name text;
        end_date date;
    BEGIN
        partition_name := table_name || '_' || to_char(start_date, 'YYYY_MM');
        end_date := start_date + interval '1 month';
        
        EXECUTE format('CREATE TABLE IF NOT EXISTS %I PARTITION OF %I FOR VALUES FROM (%L) TO (%L)',
            partition_name, table_name, start_date, end_date);
    END;
    \$\$ LANGUAGE plpgsql;
    
    -- Function to ensure future partitions exist
    CREATE OR REPLACE FUNCTION ensure_future_partitions(table_name text, months_ahead int DEFAULT 3)
    RETURNS void AS \$\$
    DECLARE
        current_date date;
        i int;
    BEGIN
        current_date := date_trunc('month', CURRENT_DATE);
        
        FOR i IN 0..months_ahead LOOP
            PERFORM create_monthly_partition(table_name, current_date + (i || ' months')::interval);
        END LOOP;
    END;
    \$\$ LANGUAGE plpgsql;
    "
    
    if [ "$DRY_RUN" = "false" ]; then
        psql $DATABASE_URL -c "$SQL"
    fi
}

# Main execution
main() {
    log_info "Starting killmails_raw partitioning process..."
    log_info "Configuration:"
    log_info "  DATABASE_URL: [REDACTED]"
    log_info "  DRY_RUN: $DRY_RUN"
    log_info "  BATCH_SIZE: $BATCH_SIZE"
    log_info "  START_DATE: $START_DATE"
    
    check_prerequisites
    get_table_stats
    
    # Confirm before proceeding
    if [ "$DRY_RUN" = "false" ]; then
        log_warn "This will partition the killmails_raw table. This is a major operation."
        read -p "Are you sure you want to continue? (yes/no): " CONFIRM
        if [ "$CONFIRM" != "yes" ]; then
            log_info "Operation cancelled"
            exit 0
        fi
    fi
    
    # Record start time
    START_TIME=$(date +%s)
    
    # Execute partitioning steps
    create_partition_structure
    migrate_data
    verify_migration
    swap_tables
    setup_auto_partitioning
    
    # Calculate duration
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    log_info "Partitioning completed successfully in $DURATION seconds"
    
    if [ "$DRY_RUN" = "false" ]; then
        log_info "Next steps:"
        log_info "  1. Monitor application for any issues"
        log_info "  2. Run ANALYZE on the new partitioned table"
        log_info "  3. Consider dropping killmails_raw_old after verification period"
        log_info "  4. Set up cron job to run: ensure_future_partitions('killmails_raw')"
    fi
}

# Run main function
main "$@"