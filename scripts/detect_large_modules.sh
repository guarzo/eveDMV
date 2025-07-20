#!/bin/bash

# Large Module Detector for EVE DMV
# Identifies modules that need refactoring due to size

set -e

echo "📊 EVE DMV Large Module Analysis"
echo "================================"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "\n${YELLOW}Analyzing module sizes...${NC}"

# Create temporary file for analysis
TEMP_FILE=$(mktemp)

# Get all .ex files with line counts
find lib -name "*.ex" -exec wc -l {} \; | sort -rn > "$TEMP_FILE"

echo -e "\n${RED}🔴 CRITICAL - Modules >1000 lines (immediate refactoring needed):${NC}"
awk '$1 > 1000 { printf "  %s lines: %s\n", $1, $2 }' "$TEMP_FILE" | head -10

echo -e "\n${YELLOW}⚠️  LARGE - Modules 500-1000 lines (refactoring recommended):${NC}"
awk '$1 > 500 && $1 <= 1000 { printf "  %s lines: %s\n", $1, $2 }' "$TEMP_FILE" | head -15

echo -e "\n${BLUE}ℹ️  MODERATE - Modules 300-500 lines (monitor for growth):${NC}"
awk '$1 > 300 && $1 <= 500 { printf "  %s lines: %s\n", $1, $2 }' "$TEMP_FILE" | head -10

# Statistics
TOTAL_FILES=$(wc -l < "$TEMP_FILE")
CRITICAL_COUNT=$(awk '$1 > 1000' "$TEMP_FILE" | wc -l)
LARGE_COUNT=$(awk '$1 > 500 && $1 <= 1000' "$TEMP_FILE" | wc -l)
MODERATE_COUNT=$(awk '$1 > 300 && $1 <= 500' "$TEMP_FILE" | wc -l)
GOOD_COUNT=$(awk '$1 <= 300' "$TEMP_FILE" | wc -l)

echo -e "\n${YELLOW}📈 Statistics:${NC}"
echo "Total modules: $TOTAL_FILES"
echo -e "${RED}Critical (>1000): $CRITICAL_COUNT${NC}"
echo -e "${YELLOW}Large (500-1000): $LARGE_COUNT${NC}"
echo -e "${BLUE}Moderate (300-500): $MODERATE_COUNT${NC}"
echo -e "${GREEN}Good (≤300): $GOOD_COUNT${NC}"

# Calculate percentage of problematic modules
PROBLEMATIC=$((CRITICAL_COUNT + LARGE_COUNT))
PERCENTAGE=$((PROBLEMATIC * 100 / TOTAL_FILES))

echo ""
echo -e "${YELLOW}🎯 Refactoring Priority:${NC}"
echo "Modules needing attention: $PROBLEMATIC ($PERCENTAGE%)"

# Specific refactoring suggestions
echo -e "\n${BLUE}🔧 Refactoring Suggestions:${NC}"

if [ "$CRITICAL_COUNT" -gt 0 ]; then
    echo ""
    echo "IMMEDIATE ACTION NEEDED:"
    awk '$1 > 1000 { 
        printf "  📁 %s (%s lines)\n", $2, $1
        printf "     → Split into 3-4 smaller modules\n"
        printf "     → Extract domain-specific logic\n"
        printf "     → Move utilities to shared modules\n\n"
    }' "$TEMP_FILE" | head -15
fi

if [ "$LARGE_COUNT" -gt 0 ]; then
    echo "RECOMMENDED REFACTORING:"
    awk '$1 > 500 && $1 <= 1000 { 
        printf "  📄 %s (%s lines)\n", $2, $1
        printf "     → Extract helper modules\n"
        printf "     → Separate concerns\n\n"
    }' "$TEMP_FILE" | head -10
fi

# Analyze function counts in large modules
echo -e "\n${YELLOW}🔍 Analyzing function density in large modules...${NC}"
while IFS= read -r file; do
    if [ -f "$file" ]; then
        LINES=$(wc -l < "$file" 2>/dev/null || echo "0")
        if [ "$LINES" -gt 500 ]; then
            FUNCTIONS=$(grep -c "^[[:space:]]*def " "$file" 2>/dev/null || echo "0")
            if [ "$FUNCTIONS" -gt 0 ]; then
                AVG_LINES=$((LINES / FUNCTIONS))
                printf "  %s: %d functions, ~%d lines/function\n" "$(basename "$file")" "$FUNCTIONS" "$AVG_LINES"
            fi
        fi
    fi
done < <(awk '$1 > 500 { print $2 }' "$TEMP_FILE" | head -10)

# Cleanup
rm -f "$TEMP_FILE"

echo -e "\n${GREEN}✅ Analysis complete!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Start with critical modules (>1000 lines)"
echo "2. Use 'mix credo --only design' for additional insights"
echo "3. Create refactoring plan for top 5 largest modules"
echo "4. Set up monitoring to prevent future growth"

echo -e "\n${BLUE}Refactoring Guidelines:${NC}"
echo "- Target: ≤300 lines per module"
echo "- Max: ≤500 lines per module"
echo "- Extract utilities to shared modules"
echo "- Separate business logic from infrastructure"
echo "- Use behaviors for common patterns"