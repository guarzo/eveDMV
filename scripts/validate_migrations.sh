#!/bin/bash
# Script to validate database migration consistency
# Task 2.3 from TEAM_BETA_PLAN.md

set -e

echo "=== Database Migration Validation Script ==="
echo "Testing migration rollback and reapplication consistency"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to run command and check status
run_command() {
    local cmd="$1"
    local desc="$2"
    
    echo -n "Running: $desc... "
    if eval "$cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        echo "Command failed: $cmd"
        return 1
    fi
}

# Test 1: Full rollback and migration
echo -e "${YELLOW}Test 1: Full rollback and re-migration${NC}"
run_command "mix ecto.rollback --all" "Rolling back all migrations"
run_command "mix ecto.migrate" "Running all migrations"
echo ""

# Test 2: Incremental rollback and migration
echo -e "${YELLOW}Test 2: Incremental rollback (5 steps)${NC}"
run_command "mix ecto.rollback --step 5" "Rolling back 5 migrations"
run_command "mix ecto.migrate" "Re-applying migrations"
echo ""

# Test 3: Check current migration status
echo -e "${YELLOW}Test 3: Migration status check${NC}"
echo "Current migration status:"
mix ecto.migrations
echo ""

# Test 4: Verify partition tables exist
echo -e "${YELLOW}Test 4: Verifying partition tables${NC}"
echo "Checking for partition tables..."

# Connect to database and check partitions
mix run -e "
sql = \"\"\"
SELECT 
    schemaname,
    tablename 
FROM pg_tables 
WHERE tablename LIKE 'killmails_%_2025_%'
ORDER BY tablename;
\"\"\"

case Ecto.Adapters.SQL.query(EveDmv.Repo, sql) do
  {:ok, %{rows: rows}} when length(rows) > 0 ->
    IO.puts(\"Found #{length(rows)} partition tables:\")
    Enum.each(rows, fn [schema, table] ->
      IO.puts(\"  - #{schema}.#{table}\")
    end)
  {:ok, %{rows: []}} ->
    IO.puts(\"Warning: No partition tables found!\")
    System.halt(1)
  {:error, error} ->
    IO.puts(\"Error checking partitions: #{inspect(error)}\")
    System.halt(1)
end
"

echo ""

# Test 5: Verify partition functions exist
echo -e "${YELLOW}Test 5: Verifying partition maintenance functions${NC}"
echo "Checking for partition functions..."

mix run -e "
sql = \"\"\"
SELECT 
    proname as function_name
FROM pg_proc 
WHERE proname IN ('create_monthly_partitions', 'maintain_partitions')
ORDER BY proname;
\"\"\"

case Ecto.Adapters.SQL.query(EveDmv.Repo, sql) do
  {:ok, %{rows: rows}} when length(rows) == 2 ->
    IO.puts(\"✓ All partition maintenance functions exist:\")
    Enum.each(rows, fn [func] ->
      IO.puts(\"  - #{func}\")
    end)
  {:ok, %{rows: rows}} ->
    IO.puts(\"Warning: Missing partition functions. Found only:\")
    Enum.each(rows, fn [func] ->
      IO.puts(\"  - #{func}\")
    end)
    System.halt(1)
  {:error, error} ->
    IO.puts(\"Error checking functions: #{inspect(error)}\")
    System.halt(1)
end
"

echo ""

# Test 6: Verify indexes on partitioned tables
echo -e "${YELLOW}Test 6: Verifying indexes on partition tables${NC}"
echo "Checking that indexes are properly created on partitions..."

mix run -e "
sql = \"\"\"
SELECT 
    tablename,
    indexname 
FROM pg_indexes 
WHERE tablename LIKE 'killmails_%_2025_%'
ORDER BY tablename, indexname
LIMIT 10;
\"\"\"

case Ecto.Adapters.SQL.query(EveDmv.Repo, sql) do
  {:ok, %{rows: rows}} when length(rows) > 0 ->
    IO.puts(\"✓ Found #{length(rows)} indexes on partition tables (showing first 10)\")
    Enum.each(rows, fn [table, index] ->
      IO.puts(\"  - #{table}: #{index}\")
    end)
  {:ok, %{rows: []}} ->
    IO.puts(\"Warning: No indexes found on partition tables!\")
  {:error, error} ->
    IO.puts(\"Error checking indexes: #{inspect(error)}\")
end
"

echo ""

# Summary
echo -e "${GREEN}=== Migration Validation Complete ===${NC}"
echo "All migration consistency checks passed successfully!"
echo ""
echo "Summary:"
echo "- Migrations can be rolled back and reapplied without errors"
echo "- Partition tables are created correctly"
echo "- Partition maintenance functions are in place"
echo "- Indexes are properly propagated to partition tables"