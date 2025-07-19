#!/bin/bash
# Script to handle migration timeouts, especially for concurrent index creation

set -e

echo "=== Migration Timeout Handler ==="
echo "This script helps manage long-running migrations that timeout"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check migration status
check_migration_status() {
    echo -e "${YELLOW}Checking migration status...${NC}"
    mix ecto.migrations
}

# Function to skip problematic migration
skip_migration() {
    local migration_id=$1
    echo -e "${YELLOW}Marking migration $migration_id as completed without running...${NC}"
    
    # Insert migration record directly into database
    mix eval "
    EveDmv.Repo.query!(
      \"INSERT INTO schema_migrations (version, inserted_at) VALUES ($1, $2) ON CONFLICT DO NOTHING\",
      [\"$migration_id\", DateTime.utc_now()]
    )
    "
    
    echo -e "${GREEN}Migration $migration_id marked as completed${NC}"
}

# Function to run indexes separately
run_indexes_async() {
    local migration_id=$1
    echo -e "${YELLOW}Running indexes from migration $migration_id asynchronously...${NC}"
    mix eve.create_indexes_async --migration $migration_id
}

# Main menu
echo "Options:"
echo "1. Check migration status"
echo "2. Skip Sprint 16 comprehensive indexes migration (20250718035000)"
echo "3. Skip Sprint 17 battle detection indexes migration (20250718191219)"
echo "4. Run indexes asynchronously for a specific migration"
echo "5. Run all pending indexes asynchronously"
echo

read -p "Select option (1-5): " option

case $option in
    1)
        check_migration_status
        ;;
    2)
        skip_migration "20250718035000"
        run_indexes_async "20250718035000"
        ;;
    3)
        skip_migration "20250718191219"
        run_indexes_async "20250718191219"
        ;;
    4)
        read -p "Enter migration ID: " migration_id
        run_indexes_async "$migration_id"
        ;;
    5)
        echo -e "${YELLOW}Running all pending indexes asynchronously...${NC}"
        mix eve.create_indexes_async
        ;;
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

echo
echo -e "${GREEN}Done!${NC}"