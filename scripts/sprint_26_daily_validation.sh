#!/bin/bash

# Sprint 26 Daily Progress Validation
# Emergency recovery from Sprint 25 regression - rigorous tracking required

set -euo pipefail  # Exit on error, undefined variables, pipe failures

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly LOG_FILE="${PROJECT_ROOT}/logs/sprint_26_validation_$(date +%Y%m%d).log"

# Ensure logs directory exists
mkdir -p "${PROJECT_ROOT}/logs"

# Logging function
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

# Error handling function
handle_error() {
    log "❌ ERROR: Validation script failed at line $1"
    log "   Last command: $2"
    log "   Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    exit 1
}

# Set error trap
trap 'handle_error $LINENO "$BASH_COMMAND"' ERR

# Change to project root
cd "$PROJECT_ROOT" || {
    echo "❌ ERROR: Cannot change to project root directory: $PROJECT_ROOT"
    exit 1
}

echo "SPRINT 26 DAILY VALIDATION - QUALITY CRISIS RECOVERY"
echo "==================================================="
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# CRITICAL: Compilation status
log "1. COMPILATION STATUS (CRITICAL)"
log "==============================="

# Safe compilation check with error handling
compilation_output=$(mktemp)
if mix compile 2>&1 | tee "$compilation_output"; then
    warnings=$(grep -c "warning:" "$compilation_output" || echo "0")
    compilation_errors=$(grep -c "error:" "$compilation_output" || echo "0")
else
    log "   ❌ CRITICAL: Compilation command failed completely"
    rm -f "$compilation_output"
    exit 1
fi

rm -f "$compilation_output"

log "   Current warnings: $warnings (target: 0)"
if [ "$compilation_errors" -gt 0 ]; then
    log "   🚨 CRITICAL: $compilation_errors compilation errors detected!"
    log "   ⚠️  EMERGENCY: All work must stop until errors are resolved"
fi

# Sprint 26 started with 42 warnings (regression from Sprint 25's 17)
baseline_warnings=42

if [ "$warnings" -eq 0 ]; then
    echo "   ✅ COMPILATION: Clean! Emergency phase complete."
elif [ "$warnings" -le 14 ]; then
    echo "   🔄 COMPILATION: Good progress, continue systematic fixes"
elif [ "$warnings" -le 28 ]; then
    echo "   ⚠️  COMPILATION: Behind target, need acceleration"
else
    echo "   🚨 COMPILATION: CRISIS - Major intervention needed"
fi

warnings_fixed=$((baseline_warnings - warnings))
compilation_progress=$((warnings_fixed * 100 / baseline_warnings))
echo "   Progress: $warnings_fixed / $baseline_warnings fixed ($compilation_progress%)"
echo ""

# Test status
log "2. TEST SUITE STATUS" 
log "===================="

# Safe test execution with timeout and error handling
test_output=$(mktemp)
test_status="unknown"

if timeout 300 mix test --max-failures=5 >"$test_output" 2>&1; then
    log "   ✅ TESTS: All passing"
    test_status="passing"
else
    test_exit_code=$?
    if [ $test_exit_code -eq 124 ]; then
        log "   ⏰ TESTS: Timed out after 5 minutes (investigate performance issues)"
        test_status="timeout"
    else
        failed_tests=$(grep -c "failed" "$test_output" || echo "unknown")
        log "   ❌ TESTS: $failed_tests tests failing"
        test_status="failing"
    fi
fi

rm -f "$test_output"
log ""

# Credo issue analysis
log "3. CREDO ISSUE ANALYSIS"
log "======================="

# Safe Credo check with error handling
credo_output=$(mktemp)
if timeout 120 mix credo --format=oneline >"$credo_output" 2>&1; then
    credo_issues=$(grep -c " ↗ " "$credo_output" || echo "0")
else
    credo_exit_code=$?
    if [ $credo_exit_code -eq 124 ]; then
        log "   ⏰ CREDO: Analysis timed out after 2 minutes"
        credo_issues="unknown"
    else
        log "   ❌ CREDO: Analysis failed (check configuration)"
        credo_issues="error"
    fi
fi

rm -f "$credo_output"

if [[ "$credo_issues" =~ ^[0-9]+$ ]]; then
    log "   Total Credo issues: $credo_issues (target: <500)"
else
    log "   ⚠️  Could not determine Credo issue count: $credo_issues"
    credo_issues=2493  # Use baseline for calculations
fi

# Sprint 26 progress (started with 2,493 from Sprint 25 failure)
baseline_issues=2493
target_issues=500
reduction_needed=$((baseline_issues - target_issues))
issues_resolved=$((baseline_issues - credo_issues))
credo_progress=$((issues_resolved * 100 / reduction_needed))

echo "   Sprint 26 progress: $issues_resolved / $reduction_needed resolved ($credo_progress%)"

# Daily target assessment (1,993 issues ÷ 21 days ≈ 95 issues/day total)
daily_target=95
days_elapsed=1  # Update manually each day

expected_resolved=$((daily_target * days_elapsed))
if [ "$issues_resolved" -ge "$expected_resolved" ]; then
    echo "   ✅ CREDO: On or ahead of target pace"
else
    behind_by=$((expected_resolved - issues_resolved))
    echo "   ⚠️  CREDO: Behind target by $behind_by issues"
fi
echo ""

# Workstream-specific breakdown
echo "4. WORKSTREAM PROGRESS BREAKDOWN"
echo "==============================="
echo "   Target daily issue resolution:"
echo "   - WS-A: Days 1-3: 14 warnings/day, then 28 issues/day"  
echo "   - WS-B: 24 security issues/day"
echo "   - WS-C: 24 interface issues/day"
echo "   - WS-D: 24 domain issues/day"
echo "   - WS-E: 23 infrastructure issues/day"
echo "   TOTAL: ~95 issues per day across all workstreams"
echo ""

# Quality regression check
echo "5. REGRESSION MONITORING"
echo "========================"
echo "   Sprint 25 ended with:"
echo "   - 17 compilation warnings → NOW: $warnings warnings"
echo "   - 2,493 Credo issues → NOW: $credo_issues issues"

if [ "$warnings" -gt 17 ]; then
    regression_warnings=$((warnings - 17))
    echo "   🚨 REGRESSION: +$regression_warnings compilation warnings since Sprint 25"
else
    improvement_warnings=$((17 - warnings))
    echo "   ✅ IMPROVEMENT: -$improvement_warnings compilation warnings since Sprint 25"
fi

if [ "$credo_issues" -gt 2493 ]; then
    regression_issues=$((credo_issues - 2493))
    echo "   🚨 REGRESSION: +$regression_issues Credo issues since Sprint 25"
else
    improvement_issues=$((2493 - credo_issues))
    echo "   ✅ IMPROVEMENT: -$improvement_issues Credo issues since Sprint 25"
fi
echo ""

# Quality gates assessment
echo "6. QUALITY GATES STATUS"
echo "======================="
gates_passed=0
total_gates=4

if [ "$warnings" -eq 0 ]; then
    echo "   ✅ Gate 1: Zero compilation warnings"
    gates_passed=$((gates_passed + 1))
else
    echo "   ❌ Gate 1: Compilation warnings blocking deployment"
fi

if [ "$test_status" = "passing" ]; then
    echo "   ✅ Gate 2: All tests passing"
    gates_passed=$((gates_passed + 1))
else
    echo "   ❌ Gate 2: Tests failing"
fi

if [ "$credo_issues" -lt 500 ]; then
    echo "   ✅ Gate 3: Credo target achieved (<500 issues)"
    gates_passed=$((gates_passed + 1))
else
    remaining_credo=$((credo_issues - 500))
    echo "   ❌ Gate 3: Credo target not met (need $remaining_credo fewer issues)"
fi

# Production readiness assessment
if [ "$warnings" -eq 0 ] && [ "$test_status" = "passing" ] && [ "$credo_issues" -lt 500 ]; then
    echo "   ✅ Gate 4: Production deployment ready"
    gates_passed=$((gates_passed + 1))
else
    echo "   ❌ Gate 4: Production deployment blocked"
fi

echo ""
echo "   OVERALL: $gates_passed / $total_gates quality gates passed"

if [ "$gates_passed" -eq "$total_gates" ]; then
    echo "   🎉 SPRINT 26 SUCCESS: All quality gates achieved!"
    echo "   ✅ Ready for production deployment"
elif [ "$gates_passed" -ge 2 ]; then
    echo "   🔄 SPRINT 26 PROGRESS: Good progress, continue systematic work"
else
    echo "   🚨 SPRINT 26 CRISIS: Major intervention required"
fi

echo ""
echo "7. EMERGENCY PROTOCOLS"
echo "======================"
if [ "$warnings" -gt 42 ] || [ "$credo_issues" -gt 2493 ]; then
    echo "   🚨 QUALITY REGRESSION DETECTED!"
    echo "   ⚠️  IMMEDIATE ACTIONS REQUIRED:"
    echo "   1. Stop all current work"
    echo "   2. Identify regression source" 
    echo "   3. Rollback problematic changes"
    echo "   4. Review and strengthen change protocols"
    echo "   5. Resume only after regression resolved"
elif [ "$warnings" -eq 0 ] && [ "$test_status" = "passing" ]; then
    echo "   ✅ Stable foundation achieved"
    echo "   🔄 Continue systematic Credo reduction"
    echo "   📈 Focus on achieving <500 Credo issues"
else
    echo "   🔄 Continue emergency stabilization phase"
    echo "   🎯 Priority: Fix compilation warnings first"
    echo "   ⚡ Use individual file validation protocol"
fi

log ""
log "8. VALIDATION SUMMARY"
log "===================="
log "   Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
log "   Log file: $LOG_FILE"
log "   Compilation warnings: $warnings (baseline: $baseline_warnings)"
if [[ "$credo_issues" =~ ^[0-9]+$ ]]; then
    log "   Credo issues: $credo_issues (baseline: $baseline_issues, target: $target_issues)"
else
    log "   Credo issues: $credo_issues (unable to calculate progress)"
fi
log "   Tests: $test_status"
log "   Quality gates passed: $gates_passed / $total_gates"

# Return appropriate exit code
if [ "$compilation_errors" -gt 0 ]; then
    log "   🚨 EXIT CODE 2: Compilation errors detected"
    exit 2
elif [ "$warnings" -gt 42 ] || ([[ "$credo_issues" =~ ^[0-9]+$ ]] && [ "$credo_issues" -gt 2493 ]); then
    log "   🚨 EXIT CODE 3: Quality regression detected"  
    exit 3
elif [ "$gates_passed" -eq "$total_gates" ]; then
    log "   ✅ EXIT CODE 0: All quality gates passed"
    exit 0
else
    log "   🔄 EXIT CODE 1: Work in progress"
    exit 1
fi