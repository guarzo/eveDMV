#!/bin/bash

# EVE DMV - Remove Wormhole Operations Script
# This script safely removes all wormhole operations related code
# Run with: ./scripts/remove_wormhole_operations.sh

set -e  # Exit on error

echo "================================"
echo "Removing Wormhole Operations"
echo "================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Backup function
backup_file() {
    if [ -f "$1" ]; then
        cp "$1" "$1.backup_$(date +%Y%m%d_%H%M%S)"
        echo -e "${GREEN}✓${NC} Backed up: $1"
    fi
}

# Step 1: Backup critical files that will be modified
echo -e "\n${YELLOW}Step 1: Creating backups...${NC}"
backup_file "lib/eve_dmv_web/router.ex"
backup_file "lib/eve_dmv/application.ex"
backup_file "test/support/factories.ex"
backup_file "test/support/mocks.ex"

# Step 2: Remove Wormhole Operations context
echo -e "\n${YELLOW}Step 2: Removing Wormhole Operations context...${NC}"
if [ -d "lib/eve_dmv/contexts/wormhole_operations" ]; then
    rm -rf lib/eve_dmv/contexts/wormhole_operations
    echo -e "${GREEN}✓${NC} Removed lib/eve_dmv/contexts/wormhole_operations"
else
    echo -e "${YELLOW}⚠${NC} Directory not found: lib/eve_dmv/contexts/wormhole_operations"
fi

# Step 3: Remove LiveView files
echo -e "\n${YELLOW}Step 3: Removing LiveView files...${NC}"
files_to_remove=(
    "lib/eve_dmv_web/live/wh_vetting_live.ex"
    "lib/eve_dmv_web/live/wh_vetting_live.html.heex"
    "lib/eve_dmv_web/live/chain_intelligence_live.ex"
    "lib/eve_dmv_web/live/chain_intelligence_live.html.heex"
)

for file in "${files_to_remove[@]}"; do
    if [ -f "$file" ]; then
        rm "$file"
        echo -e "${GREEN}✓${NC} Removed $file"
    else
        echo -e "${YELLOW}⚠${NC} File not found: $file"
    fi
done

# Step 4: Remove test files
echo -e "\n${YELLOW}Step 4: Removing test files...${NC}"
test_files=(
    "test/eve_dmv/intelligence/wh_fleet_analyzer_test.exs"
    "test/eve_dmv/intelligence/wh_vetting_analyzer_test.exs"
)

for file in "${test_files[@]}"; do
    if [ -f "$file" ]; then
        rm "$file"
        echo -e "${GREEN}✓${NC} Removed $file"
    else
        echo -e "${YELLOW}⚠${NC} File not found: $file"
    fi
done

# Step 5: Update router to remove routes
echo -e "\n${YELLOW}Step 5: Updating router...${NC}"
if [ -f "lib/eve_dmv_web/router.ex" ]; then
    # Remove wh-vetting route
    sed -i '/live.*"\/wh-vetting"/d' lib/eve_dmv_web/router.ex
    sed -i '/live.*WHVettingLive/d' lib/eve_dmv_web/router.ex
    
    # Remove chain-intelligence routes
    sed -i '/live.*"\/chain-intelligence"/d' lib/eve_dmv_web/router.ex
    sed -i '/live.*ChainIntelligenceLive/d' lib/eve_dmv_web/router.ex
    
    echo -e "${GREEN}✓${NC} Updated router.ex"
else
    echo -e "${RED}✗${NC} Router file not found"
fi

# Step 6: Check for remaining references
echo -e "\n${YELLOW}Step 6: Checking for remaining references...${NC}"

echo "Searching for WormholeOperations references..."
remaining_refs=$(grep -r "WormholeOperations" lib/ test/ --exclude-dir=.git 2>/dev/null | wc -l)
if [ "$remaining_refs" -gt 0 ]; then
    echo -e "${YELLOW}⚠${NC} Found $remaining_refs remaining references to WormholeOperations:"
    grep -r "WormholeOperations" lib/ test/ --exclude-dir=.git 2>/dev/null | head -10
fi

echo "Searching for wh_vetting references..."
wh_refs=$(grep -r "wh_vetting\|WHVetting" lib/ test/ --exclude-dir=.git 2>/dev/null | wc -l)
if [ "$wh_refs" -gt 0 ]; then
    echo -e "${YELLOW}⚠${NC} Found $wh_refs remaining references to wh_vetting:"
    grep -r "wh_vetting\|WHVetting" lib/ test/ --exclude-dir=.git 2>/dev/null | head -10
fi

# Step 7: Run quality checks
echo -e "\n${YELLOW}Step 7: Running quality checks...${NC}"

echo "Checking compilation..."
if mix compile --warnings-as-errors 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Compilation successful"
else
    echo -e "${RED}✗${NC} Compilation failed - manual intervention required"
    exit 1
fi

echo "Running formatter..."
mix format

echo "Running Credo..."
if mix credo --strict 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Credo passed"
else
    echo -e "${YELLOW}⚠${NC} Credo found issues"
fi

echo "Running tests..."
if mix test 2>/dev/null; then
    echo -e "${GREEN}✓${NC} All tests passed"
else
    echo -e "${RED}✗${NC} Some tests failed - review and fix"
fi

echo -e "\n${GREEN}================================${NC}"
echo -e "${GREEN}Wormhole Operations Removal Complete${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "Next steps:"
echo "1. Review any remaining references listed above"
echo "2. Update documentation to remove wormhole mentions"
echo "3. Commit changes with message: 'Remove incomplete Wormhole Operations feature'"
echo ""
echo "Backup files created with .backup_* extension"