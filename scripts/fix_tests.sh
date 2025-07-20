#!/bin/bash

# Test Fix Helper Script
# This script helps identify and fix failing tests systematically

set -e

echo "🔧 EVE DMV Test Fix Helper"
echo "=========================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Run tests and capture output
echo -e "\n${YELLOW}Running tests to identify failures...${NC}"
MIX_ENV=test mix test --trace 2>&1 | tee test_output.log || true

# Extract failure information
echo -e "\n${YELLOW}Analyzing test failures...${NC}"

# Count failures
FAILURES=$(grep -c "test .* (.*Test)" test_output.log 2>/dev/null || echo "0")
echo -e "${RED}Total test failures: $FAILURES${NC}"

# Extract specific failure patterns
echo -e "\n${YELLOW}Common failure patterns:${NC}"

# Database constraint errors
DB_ERRORS=$(grep -c "ON CONFLICT specification" test_output.log 2>/dev/null || echo "0")
if [ "$DB_ERRORS" -gt 0 ]; then
    echo -e "${RED}► Database constraint errors: $DB_ERRORS${NC}"
    echo "  Fix: Add missing unique constraints to ship_role_analysis table"
    echo "  Migration needed for: ON CONFLICT (ship_type_id)"
fi

# Assertion failures
ASSERTION_ERRORS=$(grep -c "Assertion with .* failed" test_output.log 2>/dev/null || echo "0")
if [ "$ASSERTION_ERRORS" -gt 0 ]; then
    echo -e "${RED}► Assertion failures: $ASSERTION_ERRORS${NC}"
    echo "  Review test expectations and scoring thresholds"
fi

# KeyError failures
KEY_ERRORS=$(grep -c "KeyError" test_output.log 2>/dev/null || echo "0")
if [ "$KEY_ERRORS" -gt 0 ]; then
    echo -e "${RED}► KeyError failures: $KEY_ERRORS${NC}"
    echo "  Fix nil handling in analyze_target_switching"
fi

# Generate fix commands
echo -e "\n${YELLOW}Suggested fixes:${NC}"

if [ "$DB_ERRORS" -gt 0 ]; then
    echo -e "\n${BLUE}1. Create migration for ship_role_analysis constraints:${NC}"
    cat << 'EOF'
mix ecto.gen.migration add_ship_role_analysis_constraints

# In the migration file:
def change do
  create unique_index(:ship_role_analysis, [:ship_type_id])
end
EOF
fi

echo -e "\n${BLUE}2. Run specific failing tests:${NC}"
echo "# Test ShipRoleAnalysisWorker fixes:"
echo "mix test test/eve_dmv/workers/ship_role_analysis_worker_test.exs"

echo -e "\n${BLUE}3. Test TacticalPatternDetector fixes:${NC}"
echo "mix test test/eve_dmv/contexts/battle_analysis/domain/tactical_pattern_detector_test.exs"

echo -e "\n${BLUE}4. Test BattleDetectionService fixes:${NC}"
echo "mix test test/eve_dmv/contexts/battle_analysis/domain/battle_detection_service_test.exs"

# Check for specific issues
echo -e "\n${YELLOW}Checking for specific issues...${NC}"

# Check if ship_role_analysis table exists
echo -n "Checking ship_role_analysis table... "
if mix run -e "EveDmv.Repo.query!(\"SELECT 1 FROM information_schema.tables WHERE table_name = 'ship_role_analysis'\")" &>/dev/null; then
    echo -e "${GREEN}exists${NC}"
    
    # Check for unique constraint
    echo -n "Checking unique constraint on ship_type_id... "
    if mix run -e "EveDmv.Repo.query!(\"SELECT 1 FROM pg_indexes WHERE tablename = 'ship_role_analysis' AND indexdef LIKE '%UNIQUE%ship_type_id%'\")" &>/dev/null; then
        echo -e "${GREEN}exists${NC}"
    else
        echo -e "${RED}missing!${NC}"
        echo -e "${YELLOW}  → Run: mix ecto.gen.migration add_ship_role_analysis_unique_constraint${NC}"
    fi
else
    echo -e "${RED}missing!${NC}"
    echo -e "${YELLOW}  → Table needs to be created${NC}"
fi

# Summary
echo -e "\n${YELLOW}Summary:${NC}"
echo "- Total failures: $FAILURES"
echo "- Database issues: $DB_ERRORS"
echo "- Assertion issues: $ASSERTION_ERRORS"
echo "- KeyError issues: $KEY_ERRORS"

# Cleanup
rm -f test_output.log

echo -e "\n${GREEN}Fix helper complete!${NC}"
echo "Run this script after making fixes to track progress."