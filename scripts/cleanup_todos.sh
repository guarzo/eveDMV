#!/bin/bash

# TODO Cleanup Script for EVE DMV
# Analyzes and helps clean up TODO comments in the codebase

set -e

echo "📝 EVE DMV TODO Cleanup Analysis"
echo "==============================="

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Create temporary files
TODO_FILE=$(mktemp)
PLACEHOLDER_FILE=$(mktemp)
IMPLEMENTATION_FILE=$(mktemp)

echo -e "\n${YELLOW}Scanning for TODO comments...${NC}"

# Extract all TODOs with context
grep -rn "TODO" lib --include="*.ex" > "$TODO_FILE" 2>/dev/null || echo "No TODOs found"

TOTAL_TODOS=$(wc -l < "$TODO_FILE" 2>/dev/null || echo "0")
echo "Total TODO comments found: $TOTAL_TODOS"

if [ "$TOTAL_TODOS" -eq 0 ]; then
    echo -e "${GREEN}✅ No TODO comments found!${NC}"
    rm -f "$TODO_FILE" "$PLACEHOLDER_FILE" "$IMPLEMENTATION_FILE"
    exit 0
fi

echo -e "\n${YELLOW}Categorizing TODOs...${NC}"

# Categorize TODOs by type
echo -e "\n${RED}🚨 CRITICAL - Placeholder implementations (must fix):${NC}"
grep -i "implement\|placeholder\|stub\|hardcode\|hardcoded\|fake\|mock\|return.*%{}\|return.*\[\]" "$TODO_FILE" | head -10 > "$PLACEHOLDER_FILE"
PLACEHOLDER_COUNT=$(wc -l < "$PLACEHOLDER_FILE")
if [ "$PLACEHOLDER_COUNT" -gt 0 ]; then
    cat "$PLACEHOLDER_FILE" | while IFS=: read -r file line content; do
        echo -e "  ${RED}📁 $file:$line${NC}"
        echo -e "     ${PURPLE}$(echo "$content" | sed 's/^[[:space:]]*//')${NC}"
        echo ""
    done
else
    echo "  ✅ No placeholder implementations found"
fi

echo -e "\n${YELLOW}⚠️  HIGH PRIORITY - Missing implementations:${NC}"
grep -i "filter\|calculation\|algorithm\|optimization\|validation\|error handling" "$TODO_FILE" | head -10 > "$IMPLEMENTATION_FILE"
IMPLEMENTATION_COUNT=$(wc -l < "$IMPLEMENTATION_FILE")
if [ "$IMPLEMENTATION_COUNT" -gt 0 ]; then
    cat "$IMPLEMENTATION_FILE" | while IFS=: read -r file line content; do
        echo -e "  ${YELLOW}📄 $file:$line${NC}"
        echo -e "     ${PURPLE}$(echo "$content" | sed 's/^[[:space:]]*//')${NC}"
        echo ""
    done
else
    echo "  ✅ No high-priority implementations found"
fi

echo -e "\n${BLUE}ℹ️  MEDIUM PRIORITY - Future enhancements:${NC}"
grep -v -i "implement\|placeholder\|stub\|hardcode\|hardcoded\|fake\|mock\|return.*%{}\|return.*\[\]\|filter\|calculation\|algorithm\|optimization\|validation\|error handling" "$TODO_FILE" | head -15 | while IFS=: read -r file line content; do
    echo -e "  ${BLUE}📝 $file:$line${NC}"
    echo -e "     ${PURPLE}$(echo "$content" | sed 's/^[[:space:]]*//')${NC}"
    echo ""
done

# Statistics
echo -e "\n${YELLOW}📊 TODO Statistics:${NC}"
echo "Total TODOs: $TOTAL_TODOS"
echo -e "${RED}Placeholder implementations: $PLACEHOLDER_COUNT${NC}"
echo -e "${YELLOW}Missing implementations: $IMPLEMENTATION_COUNT${NC}"
FUTURE_COUNT=$((TOTAL_TODOS - PLACEHOLDER_COUNT - IMPLEMENTATION_COUNT))
echo -e "${BLUE}Future enhancements: $FUTURE_COUNT${NC}"

# File-by-file breakdown
echo -e "\n${YELLOW}📁 Files with most TODOs:${NC}"
cut -d: -f1 "$TODO_FILE" | sort | uniq -c | sort -rn | head -10 | while read -r count file; do
    echo -e "  ${BLUE}$count TODOs${NC} in $(basename "$file")"
done

# Generate actionable recommendations
echo -e "\n${GREEN}🎯 Action Plan:${NC}"

if [ "$PLACEHOLDER_COUNT" -gt 0 ]; then
    echo ""
    echo -e "${RED}IMMEDIATE (Week 1):${NC}"
    echo "1. Fix placeholder implementations ($PLACEHOLDER_COUNT critical)"
    echo "   - Replace hardcoded values with real calculations"
    echo "   - Implement functions returning empty data structures"
    echo "   - Remove or properly implement mock/stub functions"
    echo ""
    echo -e "${RED}Commands to find critical placeholders:${NC}"
    echo "   grep -r \"return %{}\" lib --include=\"*.ex\""
    echo "   grep -r \"return \\[\\]\" lib --include=\"*.ex\""
    echo "   grep -r \"# TODO.*implement\" lib --include=\"*.ex\""
fi

if [ "$IMPLEMENTATION_COUNT" -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}SHORT TERM (Weeks 2-3):${NC}"
    echo "2. Implement missing functionality ($IMPLEMENTATION_COUNT items)"
    echo "   - Add proper error handling"
    echo "   - Implement missing algorithms"
    echo "   - Add data validation"
fi

if [ "$FUTURE_COUNT" -gt 0 ]; then
    echo ""
    echo -e "${BLUE}MEDIUM TERM (Month 2+):${NC}"
    echo "3. Address future enhancements ($FUTURE_COUNT items)"
    echo "   - Convert to GitHub issues for tracking"
    echo "   - Prioritize based on business value"
    echo "   - Plan implementation in future sprints"
fi

# Generate commands for cleanup
echo -e "\n${BLUE}🔧 Cleanup Commands:${NC}"
echo ""
echo "# Remove completed TODOs (after manual verification):"
echo "# grep -l \"TODO.*completed\\|TODO.*done\\|TODO.*fixed\" lib/**/*.ex | xargs sed -i '/TODO.*completed\\|TODO.*done\\|TODO.*fixed/d'"
echo ""
echo "# Find functions that need implementation:"
echo "grep -A 5 -B 5 \"TODO.*implement\" lib --include=\"*.ex\""
echo ""
echo "# Create GitHub issues from remaining TODOs:"
echo "grep -n \"TODO\" lib --include=\"*.ex\" | awk -F: '{print \"File: \" \$1 \":\" \$2 \" - \" \$3}' > github_issues.txt"

# Cleanup detection
echo -e "\n${YELLOW}🧹 Automated Cleanup Opportunities:${NC}"

# Find completed/outdated TODOs
COMPLETED_TODOS=$(grep -c -i "TODO.*complet\|TODO.*done\|TODO.*fix\|TODO.*implement.*when.*available" "$TODO_FILE" 2>/dev/null || echo "0")
if [ "$COMPLETED_TODOS" -gt 0 ]; then
    echo "- $COMPLETED_TODOS TODOs appear to be completed and can be removed"
fi

# Find TODOs that could be GitHub issues
ISSUE_TODOS=$(grep -c -i "TODO.*add\|TODO.*create\|TODO.*improve\|TODO.*enhance" "$TODO_FILE" 2>/dev/null || echo "0")
if [ "$ISSUE_TODOS" -gt 0 ]; then
    echo "- $ISSUE_TODOS TODOs could be converted to GitHub issues"
fi

# Priority scoring
PRIORITY_SCORE=$((PLACEHOLDER_COUNT * 3 + IMPLEMENTATION_COUNT * 2 + FUTURE_COUNT))
echo -e "\n${YELLOW}Priority Score: $PRIORITY_SCORE${NC}"
if [ "$PRIORITY_SCORE" -gt 50 ]; then
    echo -e "${RED}🚨 HIGH PRIORITY: Immediate cleanup needed${NC}"
elif [ "$PRIORITY_SCORE" -gt 20 ]; then
    echo -e "${YELLOW}⚠️  MEDIUM PRIORITY: Cleanup recommended${NC}"
else
    echo -e "${GREEN}✅ LOW PRIORITY: TODOs are manageable${NC}"
fi

# Cleanup
rm -f "$TODO_FILE" "$PLACEHOLDER_FILE" "$IMPLEMENTATION_FILE"

echo -e "\n${GREEN}✅ TODO analysis complete!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Start with placeholder implementations (critical)"
echo "2. Create GitHub issues for future enhancements"
echo "3. Set up TODO monitoring in CI pipeline"
echo "4. Establish TODO hygiene practices for the team"