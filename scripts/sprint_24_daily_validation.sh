#!/bin/bash
# Sprint 24 Daily Validation Script
# Final Quality Cleanup & Production Readiness
# 
# CRITICAL: Daily progress validation to prevent false completion claims
# Must show measurable progress every day

set -e

echo "📊 SPRINT 24 DAILY VALIDATION"
echo "Target: 60 unparseable files → 0, 40 warnings → 0"
echo "Focus: Honest, measurable progress tracking"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Progress tracking
VALIDATION_PASSED=true
ISSUES_FOUND=0

echo -e "${BLUE}📈 PARSING PROGRESS CHECK${NC}"
echo "=========================="

# Check total files
total_files=$(find lib/ -name "*.ex" | wc -l)
echo "Total .ex files: $total_files"

# Get unparseable file count from Credo
echo "🔍 Counting unparseable files..."
credo_output=$(mix credo --strict 2>&1)

# Count unparseable files
unparseable_count=$(echo "$credo_output" | grep -A 200 "Some source files could not be parsed" | grep "^  [0-9]" | wc -l || echo "0")

if [ "$unparseable_count" -eq 0 ]; then
    # Check if there's actually a parsing section or if it's truly 0
    if echo "$credo_output" | grep -q "Some source files could not be parsed"; then
        unparseable_count=$(echo "$credo_output" | grep -A 500 "Some source files could not be parsed" | grep "^  [0-9]" | wc -l || echo "0")
    fi
fi

echo "Unparseable files: $unparseable_count / $total_files"

# Calculate parsing success rate
if [ "$total_files" -gt 0 ]; then
    parsing_success=$((100 - (unparseable_count * 100 / total_files)))
    echo "Parsing success rate: $parsing_success%"
else
    parsing_success=0
fi

# Validate parsing progress
if [ "$unparseable_count" -eq 0 ]; then
    echo -e "${GREEN}✅ PARSING: All files parseable (100% success)${NC}"
elif [ "$unparseable_count" -le 30 ]; then
    echo -e "${YELLOW}⚠️  PARSING: $unparseable_count files unparseable (progress made)${NC}"
else
    echo -e "${RED}❌ PARSING: $unparseable_count files unparseable (insufficient progress)${NC}"
    VALIDATION_PASSED=false
    ((ISSUES_FOUND++))
fi

echo ""
echo -e "${BLUE}🔧 COMPILATION PROGRESS CHECK${NC}"
echo "=============================="

# Check compilation status
echo "🔍 Checking compilation warnings..."
warning_count=$(mix compile 2>&1 | grep "warning:" | wc -l || echo "0")
echo "Compilation warnings: $warning_count"

# Check if compilation succeeds with warnings-as-errors
if mix compile --warnings-as-errors >/dev/null 2>&1; then
    echo -e "${GREEN}✅ COMPILATION: Clean (warnings-as-errors succeeds)${NC}"
    compilation_clean=true
else
    echo -e "${RED}❌ COMPILATION: Failed (warnings-as-errors fails)${NC}"
    compilation_clean=false
fi

# Validate compilation progress
if [ "$warning_count" -eq 0 ] && [ "$compilation_clean" = true ]; then
    echo -e "${GREEN}✅ WARNINGS: Zero compilation warnings${NC}"
elif [ "$warning_count" -le 20 ]; then
    echo -e "${YELLOW}⚠️  WARNINGS: $warning_count warnings remaining (progress made)${NC}"
else
    echo -e "${RED}❌ WARNINGS: $warning_count warnings remaining (insufficient progress)${NC}"
    VALIDATION_PASSED=false
    ((ISSUES_FOUND++))
fi

echo ""
echo -e "${BLUE}🧪 TEST STATUS CHECK${NC}"
echo "==================="

# Check test status (quick check, not full suite)
echo "🔍 Testing basic functionality..."
if timeout 60s mix test --max-failures=3 test/eve_dmv/quality_regression_test.exs >/dev/null 2>&1; then
    echo -e "${GREEN}✅ TESTS: Quality regression tests passing${NC}"
    tests_passing=true
else
    echo -e "${RED}❌ TESTS: Quality regression tests failing${NC}"
    tests_passing=false
    VALIDATION_PASSED=false
    ((ISSUES_FOUND++))
fi

echo ""
echo -e "${BLUE}📊 CREDO ANALYSIS CAPABILITY${NC}"
echo "============================="

# Check how many files Credo can analyze
parseable_files=$(echo "$credo_output" | grep "Checking" | grep -o "[0-9]\+ source files" | grep -o "[0-9]\+" | head -1 || echo "0")
echo "Files Credo can analyze: $parseable_files / $total_files"

if [ "$parseable_files" -eq "$total_files" ]; then
    echo -e "${GREEN}✅ ANALYSIS: Credo can analyze all files${NC}"
elif [ "$parseable_files" -ge 625 ]; then
    echo -e "${YELLOW}⚠️  ANALYSIS: Credo analyzing $parseable_files files (good progress)${NC}"
else
    echo -e "${RED}❌ ANALYSIS: Only $parseable_files files analyzable (blocking quality work)${NC}"
    VALIDATION_PASSED=false
    ((ISSUES_FOUND++))
fi

# Show actual Credo issue count if measurement is reliable
if [ "$unparseable_count" -le 10 ]; then
    echo ""
    echo "🔍 Current Credo issue count (measurement becoming reliable):"
    credo_summary=$(echo "$credo_output" | grep -E "found [0-9]+ warnings" | head -1 || echo "No summary available")
    echo "$credo_summary"
fi

echo ""
echo -e "${BLUE}📈 DAILY PROGRESS SUMMARY${NC}"
echo "========================="

# Calculate overall progress score
progress_score=0
max_score=4

[ "$unparseable_count" -eq 0 ] && progress_score=$((progress_score + 1))
[ "$warning_count" -eq 0 ] && progress_score=$((progress_score + 1))  
[ "$tests_passing" = true ] && progress_score=$((progress_score + 1))
[ "$parseable_files" -eq "$total_files" ] && progress_score=$((progress_score + 1))

echo "Progress Score: $progress_score / $max_score"
echo "Issues Found: $ISSUES_FOUND"
echo ""

# Individual workstream guidance
echo -e "${BLUE}🏗️  WORKSTREAM STATUS GUIDANCE${NC}"
echo "=============================="

if [ "$unparseable_count" -gt 0 ]; then
    echo "Workstreams with unparseable files should focus on:"
    echo "• Fixing 1-2 parsing errors per day"
    echo "• Validating each file individually before system check"
    echo "• Common issues: missing 'end', unclosed parentheses, broken pipes"
fi

if [ "$warning_count" -gt 0 ]; then
    echo "All workstreams should address compilation warnings:"
    echo "• Fix unused variables: add '_ = variable'"
    echo "• Fix unreturned expressions: return value or add '_ = expression'"
    echo "• Test after each batch of fixes"
fi

echo ""

# Final validation decision
if [ "$VALIDATION_PASSED" = true ] && [ "$progress_score" -ge 3 ]; then
    echo -e "${GREEN}🎉 DAILY VALIDATION: PASSED${NC}"
    echo -e "${GREEN}✅ Sprint 24 making good progress${NC}"
    echo ""
    echo "Continue current approach:"
    echo "• Systematic file-by-file fixes"
    echo "• Daily measurable progress"
    echo "• Focus on parsing completion first"
    echo ""
    exit 0

elif [ "$VALIDATION_PASSED" = true ] && [ "$progress_score" -ge 2 ]; then
    echo -e "${YELLOW}⚠️  DAILY VALIDATION: CONDITIONAL PASS${NC}"
    echo -e "${YELLOW}📊 Progress made but acceleration needed${NC}"
    echo ""
    echo "Recommendations:"
    echo "• Increase daily targets (2 files per workstream)"
    echo "• Focus on highest-impact unparseable files"
    echo "• Daily sync to address blockers immediately"
    echo ""
    exit 0

else
    echo -e "${RED}❌ DAILY VALIDATION: FAILED${NC}"
    echo -e "${RED}🛑 Insufficient progress - Sprint 24 at risk${NC}"
    echo ""
    echo "IMMEDIATE ACTIONS REQUIRED:"
    
    [ "$unparseable_count" -gt 50 ] && echo "• CRITICAL: $unparseable_count unparseable files blocking quality measurement"
    [ "$warning_count" -gt 30 ] && echo "• CRITICAL: $warning_count warnings blocking production deployment"  
    [ "$tests_passing" = false ] && echo "• CRITICAL: Tests failing - system stability compromised"
    
    echo ""
    echo "ESCALATION PROTOCOL:"
    echo "1. All-hands focus on most critical blocking files"
    echo "2. Pair programming on complex parsing issues"  
    echo "3. Daily check-ins instead of weekly"
    echo "4. Technical lead review of approach"
    echo ""
    echo "🔍 FILES NEEDING IMMEDIATE ATTENTION:"
    if [ "$unparseable_count" -gt 0 ] && [ "$unparseable_count" -le 20 ]; then
        echo "$credo_output" | grep -A 100 "Some source files could not be parsed" | grep "^  [0-9]" | head -10
    fi
    
    exit 1
fi