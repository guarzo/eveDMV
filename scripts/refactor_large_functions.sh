#!/bin/bash

# Refactor Large Functions - Sprint 22 Quality Standards
# This script identifies and helps refactor functions longer than 30 lines

set -e

echo "🔧 EVE DMV Large Function Refactoring"
echo "===================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Function to count functions over certain line limits
count_large_functions() {
    local limit=$1
    find lib -name "*.ex" -exec awk -v limit="$limit" '
    FNR==1{lines=0; file=FILENAME; count=0} 
    /^[[:space:]]*def / {start=FNR; func=$0} 
    /^[[:space:]]*end[[:space:]]*$/ && start {
        lines=FNR-start+1; 
        if(lines>limit) count++; 
        start=0
    } 
    END {print file ":" count}' {} \; | awk -F: '{sum+=$2} END {print sum}'
}

echo -e "\n${YELLOW}📊 Current Function Size Analysis:${NC}"
CRITICAL_50=$(count_large_functions 50)
LARGE_30=$(count_large_functions 30)
HUGE_100=$(count_large_functions 100)

echo "Functions >100 lines (critical): $HUGE_100"
echo "Functions >50 lines (high priority): $CRITICAL_50"  
echo "Functions >30 lines (refactor target): $LARGE_30"

echo -e "\n${YELLOW}🎯 Sprint 22 Targets:${NC}"
echo "• 0 functions >50 lines (hard limit)"
echo "• <10 functions >30 lines (soft target)"
echo "• Current: $LARGE_30 functions >30 lines"

REDUCTION_NEEDED=$((LARGE_30 - 10))
if [ "$REDUCTION_NEEDED" -gt 0 ]; then
    echo -e "${RED}• Need to refactor: $REDUCTION_NEEDED functions${NC}"
else
    echo -e "${GREEN}• Target already achieved!${NC}"
fi

echo -e "\n${YELLOW}🔍 Finding worst offenders (>100 lines):${NC}"
find lib -name "*.ex" -exec awk '
FNR==1{lines=0; file=FILENAME} 
/^[[:space:]]*def / {start=FNR; func=$0} 
/^[[:space:]]*end[[:space:]]*$/ && start {
    lines=FNR-start+1; 
    if(lines>100) print file":"start":"lines" " func; 
    start=0
}' {} \; | head -10

echo -e "\n${YELLOW}🔍 Finding medium priority targets (50-100 lines):${NC}"
find lib -name "*.ex" -exec awk '
FNR==1{lines=0; file=FILENAME} 
/^[[:space:]]*def / {start=FNR; func=$0} 
/^[[:space:]]*end[[:space:]]*$/ && start {
    lines=FNR-start+1; 
    if(lines>50 && lines<=100) print file":"start":"lines" " func; 
    start=0
}' {} \; | head -15

echo -e "\n${BLUE}📋 Refactoring Strategy:${NC}"
echo "1. Focus on logic-heavy functions (avoid pure UI templates)"
echo "2. Extract helper functions for complex calculations"
echo "3. Break down conditional logic into separate functions"
echo "4. Extract data transformation pipelines"
echo "5. Create private utility functions"

echo -e "\n${BLUE}💡 Refactoring Guidelines:${NC}"
echo "• Extract 'do_*' helper functions for complex logic"
echo "• Create 'calculate_*' functions for computations"
echo "• Use 'validate_*' functions for input validation"
echo "• Split 'handle_*' functions into smaller handlers"
echo "• Extract 'format_*' functions for data formatting"

echo -e "\n${GREEN}✅ Function analysis complete!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review worst offenders manually"
echo "2. Extract helper functions from complex logic"
echo "3. Run tests after each refactoring"
echo "4. Measure progress with this script"