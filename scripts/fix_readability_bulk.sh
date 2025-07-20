#!/bin/bash

# Bulk Readability Fixes for EVE DMV
# This script automatically fixes common Credo readability issues

set -e

echo "🔧 EVE DMV Bulk Readability Fixes"
echo "================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counter for fixes
FIXES=0

echo -e "\n${YELLOW}1. Removing trailing whitespace...${NC}"
if find lib -name "*.ex" -exec sed -i 's/[[:space:]]*$//' {} \; 2>/dev/null; then
    TRAILING_FIXES=$(find lib -name "*.ex" -exec grep -l '[[:space:]]$' {} \; 2>/dev/null | wc -l)
    FIXES=$((FIXES + TRAILING_FIXES))
    echo -e "${GREEN}✓ Fixed trailing whitespace in files${NC}"
else
    echo "⚠️  Could not fix trailing whitespace (files may already be clean)"
fi

echo -e "\n${YELLOW}2. Fixing single-function pipelines...${NC}"
# Fix patterns like: data |> function() -> function(data)
find lib -name "*.ex" -type f | while read -r file; do
    if sed -i.bak -E 's/([[:alnum:]_]+)[[:space:]]+\|>[[:space:]]+([[:alnum:]_]+)\(\)/\2(\1)/g' "$file" 2>/dev/null; then
        if ! cmp -s "$file" "$file.bak"; then
            FIXES=$((FIXES + 1))
            echo -e "${BLUE}  ↳ Fixed pipeline in $(basename "$file")${NC}"
        fi
        rm -f "$file.bak"
    fi
done

echo -e "\n${YELLOW}3. Removing parentheses from zero-arity function definitions...${NC}"
# Fix patterns like: def config() -> def config
find lib -name "*.ex" -type f | while read -r file; do
    if sed -i.bak -E 's/def[[:space:]]+([[:alnum:]_]+)\(\)[[:space:]]*do/def \1 do/g' "$file" 2>/dev/null; then
        if ! cmp -s "$file" "$file.bak"; then
            FIXES=$((FIXES + 1))
            echo -e "${BLUE}  ↳ Fixed function definition in $(basename "$file")${NC}"
        fi
        rm -f "$file.bak"
    fi
done

echo -e "\n${YELLOW}4. Running mix format...${NC}"
if mix format; then
    echo -e "${GREEN}✓ Code formatted successfully${NC}"
else
    echo "⚠️  Mix format encountered issues"
fi

echo -e "\n${YELLOW}5. Checking results...${NC}"
READABILITY_BEFORE=$(mix credo --only readability 2>/dev/null | grep -c "↗\|↘" || echo "0")
echo "Readability issues remaining: $READABILITY_BEFORE"

echo -e "\n${GREEN}✅ Bulk readability fixes complete!${NC}"
echo "Fixes applied: $FIXES files processed"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review changes with: git diff"
echo "2. Run: mix credo --only readability"
echo "3. Commit changes: git add . && git commit -m 'fix: Apply bulk readability improvements'"

echo -e "\n${BLUE}Manual fixes still needed for:${NC}"
echo "- Complex pipeline chains (need human review)"
echo "- Module/function organization"
echo "- Documentation placement"