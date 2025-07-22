#!/bin/bash
# Parsing Recovery Validation Script
# Sprint 22: Emergency Parsing & Compilation Recovery
# 
# CRITICAL: Validates that all files can be parsed by Elixir tools
# BLOCKING: No quality work can proceed until this passes

set -e

echo "🚨 PARSING RECOVERY VALIDATION"
echo "CRITICAL: Fixing parsing errors that block quality measurement"
echo "This must pass before any quality work can be reliable"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track validation status
VALIDATION_PASSED=true
CRITICAL_ISSUES=0

echo -e "${BLUE}📊 PARSING STATUS CHECK${NC}"
echo "========================"

# 1. Check total file count
echo "🔍 Counting total Elixir files..."
total_files=$(find lib/ -name "*.ex" | wc -l)
echo "Total .ex files: $total_files"

# 2. Check how many files Credo can parse
echo ""
echo "🔍 Checking Credo parsing capability..."
credo_output=$(mix credo --strict 2>&1 | grep "Checking" | head -1 || echo "Checking 0 source files")
parseable_files=$(echo "$credo_output" | grep -o "[0-9]\+" | head -1 || echo "0")

echo "Credo parseable files: $parseable_files"
echo "$credo_output"

# Calculate unparseable files
unparseable_files=$((total_files - parseable_files))
echo "Unparseable files: $unparseable_files"

# 3. Show parsing success rate
if [ "$total_files" -gt 0 ]; then
    parsing_success_rate=$(( parseable_files * 100 / total_files ))
    echo "Parsing success rate: $parsing_success_rate%"
else
    parsing_success_rate=0
    echo "Parsing success rate: 0% (no files found)"
fi

# 4. Validate parsing status
echo ""
echo -e "${BLUE}🎯 PARSING VALIDATION RESULTS${NC}"
echo "==============================="

if [ "$unparseable_files" -eq 0 ]; then
    echo -e "${GREEN}✅ PARSING: All files parseable${NC}"
    echo -e "${GREEN}   Status: READY for quality analysis${NC}"
else
    echo -e "${RED}❌ PARSING: $unparseable_files files unparseable${NC}"
    echo -e "${RED}   Status: BLOCKING quality analysis${NC}"
    VALIDATION_PASSED=false
    ((CRITICAL_ISSUES++))
fi

# 5. List unparseable files if any
if [ "$unparseable_files" -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}🔍 FILES WITH PARSING ERRORS:${NC}"
    echo "================================"
    
    # Get detailed error list from Credo
    echo "Files excluded from Credo analysis:"
    mix credo --strict 2>&1 | grep -A 200 "Some source files could not be parsed" | grep "^  [0-9]" | head -20
    
    echo ""
    echo "🛠️  COMMON PARSING ERROR TYPES:"
    echo "• Missing 'end' keywords (unclosed def, if, case, etc.)"
    echo "• Unclosed parentheses, brackets, or braces"  
    echo "• Malformed pipe operators |>"
    echo "• Syntax errors in with/for statements"
    echo "• Module definition errors"
fi

# 6. Check basic compilation status
echo ""
echo -e "${BLUE}🔧 COMPILATION STATUS${NC}"
echo "===================="

echo "🔍 Checking if files compile..."
if mix compile >/dev/null 2>&1; then
    echo -e "${GREEN}✅ COMPILATION: Succeeds${NC}"
else
    echo -e "${RED}❌ COMPILATION: Fails${NC}"
    VALIDATION_PASSED=false
    ((CRITICAL_ISSUES++))
fi

# Count compilation warnings
warning_count=$(mix compile 2>&1 | grep "warning:" | wc -l || echo "0")
echo "Compilation warnings: $warning_count"

if [ "$warning_count" -eq 0 ]; then
    echo -e "${GREEN}✅ WARNINGS: Zero compilation warnings${NC}"
else
    echo -e "${YELLOW}⚠️  WARNINGS: $warning_count warnings remaining${NC}"
fi

# 7. Test basic tool functionality
echo ""
echo -e "${BLUE}🧪 TOOL FUNCTIONALITY CHECK${NC}"
echo "============================"

# Check if formatter works
echo "🔍 Testing code formatter..."
if mix format --check-formatted >/dev/null 2>&1; then
    echo -e "${GREEN}✅ FORMATTER: Working${NC}"
else
    echo -e "${YELLOW}⚠️  FORMATTER: Issues detected${NC}"
fi

# Check if tests can run
echo "🔍 Testing basic test execution..."
if timeout 30s mix test --max-failures=1 >/dev/null 2>&1; then
    echo -e "${GREEN}✅ TESTS: Can execute${NC}"
else
    echo -e "${RED}❌ TESTS: Cannot execute${NC}"
    VALIDATION_PASSED=false
    ((CRITICAL_ISSUES++))
fi

# 8. Final validation decision
echo ""
echo -e "${BLUE}📊 PARSING RECOVERY SUMMARY${NC}"
echo "============================"
echo "Total Files: $total_files"
echo "Parseable: $parseable_files ($parsing_success_rate%)"  
echo "Unparseable: $unparseable_files"
echo "Warnings: $warning_count"
echo "Critical Issues: $CRITICAL_ISSUES"

echo ""

# Final gate decision
if [ "$VALIDATION_PASSED" = true ] && [ "$unparseable_files" -eq 0 ]; then
    echo -e "${GREEN}🎉 PARSING RECOVERY: COMPLETE${NC}"
    echo -e "${GREEN}✅ ALL FILES PARSEABLE - QUALITY ANALYSIS READY${NC}"
    echo ""
    echo "✅ Credo can analyze all source files"
    echo "✅ Compilation succeeds"  
    echo "✅ Tools functioning properly"
    echo ""
    echo -e "${GREEN}NEXT STEP: Fix compilation warnings${NC}"
    echo "Run: ./scripts/day1_compilation_emergency.sh"
    echo ""
    exit 0

elif [ "$unparseable_files" -eq 0 ] && [ "$warning_count" -gt 0 ]; then
    echo -e "${YELLOW}🎯 PARSING RECOVERY: PARTIAL SUCCESS${NC}"
    echo -e "${GREEN}✅ ALL FILES PARSEABLE${NC}"
    echo -e "${YELLOW}⚠️  $warning_count COMPILATION WARNINGS REMAIN${NC}"
    echo ""
    echo "✅ Ready for quality analysis"
    echo "⚠️  Still need compilation warning cleanup"
    echo ""
    echo -e "${YELLOW}NEXT STEP: Fix remaining compilation warnings${NC}"
    echo "Run: ./scripts/day1_compilation_emergency.sh"
    echo ""
    exit 0

else
    echo -e "${RED}❌ PARSING RECOVERY: FAILED${NC}"
    echo -e "${RED}🛑 $unparseable_files FILES CANNOT BE PARSED${NC}"
    echo ""
    echo "❌ Quality analysis is unreliable"
    echo "❌ Workstream completion claims are invalid"
    echo "❌ Sprint 22 progress is blocked"
    echo ""
    echo -e "${RED}IMMEDIATE ACTIONS REQUIRED:${NC}"
    echo "1. Fix parsing errors in unparseable files"
    echo "2. Focus on syntax errors: missing 'end', unclosed brackets"
    echo "3. Fix ONE file at a time, validate after each"
    echo "4. Run: mix compile [filename] to test individual files"
    echo "5. Re-run this validation: ./scripts/parsing_recovery_validation.sh"
    echo ""
    
    if [ "$unparseable_files" -le 10 ]; then
        echo "🎯 GOOD NEWS: Only $unparseable_files files need fixing (manageable!)"
        echo "🎯 Focus workstreams on these specific files first"
    else
        echo "⚠️  WARNING: $unparseable_files files need fixing (significant effort)"
        echo "⚠️  Consider parallel workstream effort on parsing fixes"
    fi
    
    echo ""
    echo "🛑 DO NOT PROCEED WITH QUALITY WORK UNTIL PARSING IS FIXED"
    exit 1
fi