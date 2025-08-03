#!/bin/bash
# Master Dialyzer Fix Coordinator Script

echo "🚀 Dialyzer Error Resolution Coordinator"
echo "======================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to run a workstream
run_workstream() {
    local name=$1
    local script=$2
    local color=$3
    
    echo -e "${color}Starting Workstream $name...${NC}"
    if [ -f "$script" ]; then
        chmod +x "$script"
        bash "$script"
        echo -e "${GREEN}✓ Workstream $name completed${NC}"
    else
        echo -e "${RED}✗ Workstream $name script not found: $script${NC}"
    fi
    echo ""
}

# Check current dialyzer status
echo -e "${BLUE}Current Dialyzer Status:${NC}"
if [ -f "/workspace/dialyzer.txt" ]; then
    total_errors=$(grep "Total errors:" /workspace/dialyzer.txt | grep -oE "[0-9]+" | head -1)
    echo "Total errors: $total_errors"
else
    echo -e "${RED}No dialyzer.txt found. Run 'mix dialyzer' first.${NC}"
fi
echo ""

# Menu
echo "Select workstream to run:"
echo "1) Alpha - Pattern Match & Type Specs (450 errors)"
echo "2) Beta - Unused Functions (680 errors)"
echo "3) Gamma - No Return & Call Errors (320 errors)"
echo "4) Delta - Business Logic (451 errors)"
echo "5) Epsilon - Infrastructure (200 errors)"
echo "6) ALL - Run all workstreams in sequence"
echo "7) STATUS - Check current error count"
echo "8) VERIFY - Run compilation and basic dialyzer check"
echo ""

read -p "Enter choice [1-8]: " choice

case $choice in
    1)
        run_workstream "Alpha" "/workspace/scripts/workstream_alpha_pattern_fixes.sh" "$BLUE"
        ;;
    2)
        run_workstream "Beta" "/workspace/scripts/workstream_beta_unused_functions.sh" "$YELLOW"
        ;;
    3)
        run_workstream "Gamma" "/workspace/scripts/workstream_gamma_no_return_fixes.sh" "$GREEN"
        ;;
    4)
        run_workstream "Delta" "/workspace/scripts/workstream_delta_business_logic.sh" "$RED"
        ;;
    5)
        run_workstream "Epsilon" "/workspace/scripts/workstream_epsilon_infrastructure.sh" "$BLUE"
        ;;
    6)
        echo -e "${YELLOW}Running all workstreams...${NC}"
        run_workstream "Alpha" "/workspace/scripts/workstream_alpha_pattern_fixes.sh" "$BLUE"
        run_workstream "Gamma" "/workspace/scripts/workstream_gamma_no_return_fixes.sh" "$GREEN"
        run_workstream "Beta" "/workspace/scripts/workstream_beta_unused_functions.sh" "$YELLOW"
        run_workstream "Delta" "/workspace/scripts/workstream_delta_business_logic.sh" "$RED"
        run_workstream "Epsilon" "/workspace/scripts/workstream_epsilon_infrastructure.sh" "$BLUE"
        ;;
    7)
        echo -e "${BLUE}Checking current status...${NC}"
        echo "Compilation check:"
        mix compile --warnings-as-errors 2>&1 | tail -20
        echo ""
        echo "Dialyzer error count:"
        if command -v timeout >/dev/null 2>&1; then
            timeout 30 mix dialyzer --format short 2>&1 | grep -E "Total errors:|done in"
        else
            echo "Run 'mix dialyzer' to get current count"
        fi
        ;;
    8)
        echo -e "${BLUE}Running verification...${NC}"
        echo "1. Compilation check:"
        if mix compile --warnings-as-errors; then
            echo -e "${GREEN}✓ Compilation successful${NC}"
        else
            echo -e "${RED}✗ Compilation failed${NC}"
        fi
        echo ""
        echo "2. Format check:"
        if mix format --check-formatted; then
            echo -e "${GREEN}✓ Code properly formatted${NC}"
        else
            echo -e "${YELLOW}⚠ Code needs formatting${NC}"
        fi
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}Done!${NC}"
echo ""
echo "Next steps:"
echo "1. Review changes with 'git diff'"
echo "2. Run 'mix test' to ensure nothing broke"
echo "3. Run 'mix dialyzer' to check progress"
echo "4. Commit fixes in logical chunks"