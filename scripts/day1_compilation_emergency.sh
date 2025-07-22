#!/bin/bash
# Day 1 Emergency Compilation Validation Gate
# Sprint 22: Current State Quality Recovery
# 
# CRITICAL CHECKPOINT: ALL compilation warnings MUST be resolved
# before ANY workstream can proceed to Phase 2

set -e

echo "🚨 DAY 1 EMERGENCY VALIDATION GATE"
echo "CRITICAL: Compilation must be clean before proceeding"
echo "This gate BLOCKS all workstreams until warnings = 0"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Gate status tracking
GATE_PASSED=true

echo "📊 COMPILATION EMERGENCY STATUS CHECK"
echo "======================================"

# Check compilation status
echo "🔍 Checking compilation with warnings-as-errors..."
if mix compile --warnings-as-errors >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Compilation Status: PASS${NC}"
    compilation_status="PASS"
else
    echo -e "${RED}❌ Compilation Status: FAIL${NC}"
    compilation_status="FAIL"
    GATE_PASSED=false
fi

# Count remaining warnings
echo "🔍 Counting compilation warnings..."
warning_count=$(mix compile 2>&1 | grep "warning:" | wc -l || echo "0")
echo "Remaining Warnings: $warning_count"

if [ "$warning_count" -eq 0 ]; then
    echo -e "${GREEN}✅ Warning Count: 0 (TARGET MET)${NC}"
else
    echo -e "${RED}❌ Warning Count: $warning_count (MUST BE: 0)${NC}"
    GATE_PASSED=false
fi

# Check test status (informational, not blocking)
echo "🧪 Checking test status..."
test_output=$(mix test 2>&1 | grep -E "[0-9]+ tests, [0-9]+ failures" | tail -1 || echo "0 tests, 0 failures")
test_failures=$(echo "$test_output" | awk '{print $3}' | tr -d ',')

echo "Test Status: $test_output"
if [ "$test_failures" = "0" ] || [ -z "$test_failures" ]; then
    echo -e "${GREEN}✅ Test Failures: 0 (GOOD)${NC}"
else
    echo -e "${YELLOW}⚠️  Test Failures: $test_failures (INVESTIGATE)${NC}"
    # Tests failing due to non-compilation issues don't block the gate
fi

echo ""
echo "🚨 EMERGENCY STATUS SUMMARY"
echo "=========================="
echo "Compilation Status: $compilation_status (MUST BE: PASS)"
echo "Remaining Warnings: $warning_count (MUST BE: 0)"
echo "Test Failures: $test_failures (TARGET: 0)"

echo ""

# Final gate decision
if [ "$GATE_PASSED" = true ]; then
    echo -e "${GREEN}🎉 DAY 1 EMERGENCY GATE: PASSED${NC}"
    echo ""
    echo "✅ PROCEED to Day 2 - All workstreams cleared for Phase 2"
    echo "✅ Compilation is clean - quality work can begin"
    echo ""
    echo "Next steps:"
    echo "1. All workstreams can now proceed to Phase 2 (Credo resolution)"
    echo "2. Run individual workstream scripts: ws_a_analytics_quality_fix.sh phase2"
    echo "3. Daily validation: ./scripts/week1_distributed_quality_validation.sh"
    echo ""
    exit 0
else
    echo -e "${RED}🛑 DAY 1 EMERGENCY GATE: FAILED${NC}"
    echo ""
    echo "❌ STOP ALL WORK - Compilation warnings must be resolved first"
    echo "❌ NO workstream can proceed to Phase 2 until this gate passes"
    echo ""
    echo "Emergency actions required:"
    echo "1. Continue emergency compilation fixes in all workstreams"
    echo "2. Focus on unused variables and unreturned expressions"
    echo "3. Fix 5-10 files at a time, validate after each batch"
    echo "4. Re-run this gate: ./scripts/day1_compilation_emergency.sh"
    echo ""
    
    # Show specific warnings to help with fixes
    echo "🔍 CURRENT WARNINGS TO FIX:"
    mix compile 2>&1 | grep "warning:" | head -10
    echo ""
    echo "Focus on these patterns:"
    echo "- 'variable X in code block has no effect' → Add: _ = X"
    echo "- 'variable X is unused' → Remove or prefix with _"
    echo "- 'expression has no effect' → Add: _ = expression"
    echo ""
    exit 1
fi