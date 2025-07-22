#!/bin/bash
# Workstream E: Testing & Security Automation Fix Script
# Sprint 22: Current State Quality Recovery
# 
# CRITICAL SAFETY PROTOCOL - SYSTEM.CMD AFFECTS PROCESS EXECUTION
# Target: 21 compilation warnings + 628 Credo issues

set -e

echo "🛡️  WORKSTREAM E: Testing & Security Automation"
echo "Target: 21 compilation warnings + 628 Credo issues"
echo "Focus: Security issues - System.cmd replacements need careful testing"
echo ""

# Safety check functions
check_compilation() {
    echo "🔍 Checking compilation status..."
    if ! mix compile --warnings-as-errors 2>/dev/null; then
        echo "❌ COMPILATION FAILED - STOPPING ALL WORK"
        echo "Fix compilation errors manually before proceeding"
        exit 1
    fi
    echo "✅ Compilation clean"
}

count_warnings() {
    warnings=$(mix compile 2>&1 | grep "warning:" | wc -l || echo "0")
    echo "Current warnings: $warnings"
    return $warnings
}

count_credo_issues() {
    # Count Testing & Security specific issues
    issues=$(mix credo --strict test/ lib/mix/ scripts/ | grep -E "↗|↘" | wc -l || echo "0")
    echo "Current WS-E Credo issues: $issues"
    return $issues
}

run_tests() {
    echo "🧪 Running test suite (full)..."
    if ! mix test --max-failures=3 2>/dev/null; then
        echo "❌ TESTS FAILED - Security/test changes broke functionality"
        return 1
    fi
    echo "✅ All tests passing"
}

# Phase 1: Emergency Compilation Fix (Days 1-2)
phase1_compilation_fix() {
    echo ""
    echo "📊 PHASE 1: EMERGENCY COMPILATION FIX (Testing & Security)"
    echo "Target: 21 compilation warnings → 0"
    echo "⚠️  CAUTION: Test/build changes affect CI/CD pipeline"
    echo ""
    
    count_warnings
    initial_warnings=$?
    
    if [ $initial_warnings -eq 0 ]; then
        echo "✅ No compilation warnings in test/build files - proceeding to Phase 2"
        return 0
    fi
    
    echo "🚨 CRITICAL: $initial_warnings warnings found in test/build files/"
    echo ""
    echo "EMERGENCY PROTOCOL:"
    echo "1. Fix warnings in test/, build, misc files ONLY"
    echo "2. Fix 8-10 files at a time (safe for tests)"
    echo "3. CRITICAL: Run test suite after each batch"
    echo "4. Commit successful changes immediately"
    echo ""
    
    # Show specific warnings for test/build files
    echo "Test & Build warnings to fix:"
    mix compile 2>&1 | grep "warning:" | grep -E "test/|lib/mix/|scripts/"
    echo ""
    
    echo "⚠️  MANUAL ACTION REQUIRED - TEST/BUILD CRITICAL:"
    echo "   1. Open test/ and lib/mix/ directories in editor"
    echo "   2. Fix unused variables in test files (safe)"
    echo "   3. Fix unused expressions in mix tasks (affects CLI!)"
    echo "   4. Run: ./scripts/ws_e_testing_security_automation_fix.sh validate"
    echo "   5. MANDATORY: Run full test suite to verify"
    echo "   6. Commit: git add -A && git commit -m 'fix: WS-E test/build warnings batch 1'"
    echo ""
    echo "🛑 DO NOT PROCEED TO PHASE 2 UNTIL WARNINGS = 0"
    echo "🛑 Test changes affect CI/CD pipeline"
    
    return 1
}

# Phase 2: Distributed Credo Resolution (Days 3-21)
phase2_credo_resolution() {
    echo ""
    echo "📊 PHASE 2: CREDO QUALITY RESOLUTION (Security & Automation)"
    echo "Target: 628 Credo issues"
    echo "🛡️  SECURITY WARNING: System.cmd replacements affect process execution"
    echo ""
    
    count_credo_issues
    current_issues=$?
    
    if [ $current_issues -eq 0 ]; then
        echo "✅ No Credo issues - workstream complete!"
        return 0
    fi
    
    echo "Current issues: $current_issues"
    echo "Target: 628 → 0 issues"
    echo ""
    
    echo "🎯 WS-E FOCUS AREAS (Security & Automation):"
    echo "Priority 1: System.cmd security replacements (100 issues) - DANGEROUS!"
    echo "Priority 2: Test quality improvements (200 issues) - SAFE"  
    echo "Priority 3: Build automation quality (328 issues) - MODERATE"
    echo ""
    
    # Show specific Credo issues
    echo "Security & Automation Credo issues:"
    mix credo --strict test/ lib/mix/ | head -10
    echo ""
    
    echo "⚠️  MANUAL ACTION REQUIRED - SECURITY SAFETY PROTOCOL:"
    echo "   1. Replace System.cmd with Port.cmd (test thoroughly!)"
    echo "   2. Replace :os.cmd with secure alternatives where possible"
    echo "   3. Improve test assertions and descriptions (safe)"
    echo "   4. Clean up build automation scripts"
    echo "   5. Run: ./scripts/ws_e_testing_security_automation_fix.sh validate"
    echo "   6. MANDATORY: Test CLI commands and build process"
    echo "   7. Commit: git add -A && git commit -m 'fix: WS-E security/automation batch X'"
    echo ""
    echo "Daily target: 33 issues resolved (628 ÷ 19 days)"
    echo "🛡️  NEVER change System.cmd without extensive testing!"
    echo "🛡️  Process execution changes can break deployment!"
    
    return $current_issues
}

# Security & Testing functionality check
test_security_automation() {
    echo "🛡️  Testing Security & Automation Functionality..."
    echo ""
    
    # Test that tests still run
    echo "Testing test suite functionality..."
    if mix test test/eve_dmv/quality_regression_test.exs --max-failures=1 2>/dev/null; then
        echo "✅ Test suite functional"
    else
        echo "❌ Test suite broken - rollback changes!"
        return 1
    fi
    
    # Test mix tasks
    echo "Testing mix tasks..."
    if mix help | grep -q "mix eve."; then
        echo "✅ Custom mix tasks functional"
    else
        echo "❌ Mix tasks broken - rollback changes!"
        return 1
    fi
    
    # Test that quality checks work
    echo "Testing quality automation..."
    if mix credo --version >/dev/null 2>&1 && mix format --check-formatted test/eve_dmv/quality_regression_test.exs >/dev/null 2>&1; then
        echo "✅ Quality automation functional"
    else
        echo "❌ Quality automation broken - rollback changes!"
        return 1
    fi
    
    return 0
}

# System.cmd analysis helper
analyze_system_cmd() {
    echo "🛡️  SYSTEM.CMD SECURITY ANALYSIS"
    echo "Showing System.cmd calls that need secure replacements:"
    echo ""
    
    # Find System.cmd usage
    find test/ lib/mix/ scripts/ -name "*.ex" -o -name "*.exs" | xargs grep -n "System.cmd\|:os.cmd" | head -10 | while IFS=: read file line_num command; do
        echo "File: $file:$line_num"
        echo "Command: $command"
        echo "Replacement: Use Port.cmd or GenServer with controlled execution"
        echo "CRITICAL: Test thoroughly - affects process execution"
        echo ""
    done
}

# Validation function
validate() {
    echo "🔍 VALIDATION CHECKPOINT - SECURITY & AUTOMATION"
    echo ""
    
    # Check compilation first (most critical)
    check_compilation
    
    # Count current state
    count_warnings
    warnings=$?
    
    count_credo_issues  
    credo_issues=$?
    
    # Test security & automation functionality (CRITICAL for WS-E)
    test_security_automation
    security_test=$?
    
    # Run full test suite
    run_tests
    test_result=$?
    
    echo ""
    echo "📊 WORKSTREAM E STATUS:"
    echo "Compilation warnings: $warnings (Target: 0)"
    echo "Credo issues: $credo_issues (Target: <628)"
    echo "Security/Automation: $([ $security_test -eq 0 ] && echo 'FUNCTIONAL' || echo 'BROKEN')"
    echo "Full test suite: $([ $test_result -eq 0 ] && echo 'PASSING' || echo 'FAILING')"
    echo ""
    
    if [ $warnings -gt 0 ]; then
        echo "🛑 COMPILATION WARNINGS STILL PRESENT - PHASE 1 INCOMPLETE"
        echo "Cannot proceed to Credo fixes until compilation is clean"
        return 1
    fi
    
    if [ $security_test -ne 0 ]; then
        echo "🛡️  SECURITY/AUTOMATION BROKEN - ROLLBACK IMMEDIATELY"
        echo "This affects CI/CD pipeline and deployment process"
        return 1
    fi
    
    if [ $test_result -ne 0 ]; then
        echo "❌ FULL TEST SUITE FAILING - CRITICAL ISSUE"
        echo "Security/test changes broke functionality"
        return 1
    fi
    
    echo "✅ Validation passed - security/automation functional"
    return 0
}

# Progress tracking
progress() {
    echo "📈 WORKSTREAM E PROGRESS REPORT"
    echo ""
    
    count_warnings
    warnings=$?
    
    count_credo_issues
    credo_issues=$?
    
    # Calculate progress percentages
    warning_progress=$(( (21 - warnings) * 100 / 21 ))
    credo_progress=$(( (628 - credo_issues) * 100 / 628 ))
    
    echo "📊 PROGRESS SUMMARY:"
    echo "Phase 1 (Compilation): $warning_progress% complete ($warnings warnings remaining)"
    echo "Phase 2 (Credo): $credo_progress% complete ($credo_issues issues remaining)"
    echo ""
    
    # Check security/automation health
    if test_security_automation >/dev/null 2>&1; then
        echo "✅ Security/Automation: INTACT"
    else
        echo "❌ Security/Automation: BROKEN"
    fi
    
    # Show System.cmd progress
    system_cmd_count=$(find test/ lib/mix/ scripts/ -name "*.ex" -o -name "*.exs" | xargs grep -c "System.cmd\|:os.cmd" 2>/dev/null | awk '{sum += $1} END {print sum}' || echo "0")
    echo "🛡️  System.cmd calls remaining: $system_cmd_count (security risk)"
    
    if [ $warnings -eq 0 ] && [ $credo_issues -lt 314 ]; then
        echo "🎉 HALFWAY MILESTONE REACHED!"
    fi
    
    if [ $warnings -eq 0 ] && [ $credo_issues -eq 0 ]; then
        echo "🏆 WORKSTREAM E COMPLETE!"
        echo "Ready for Sprint 22 final validation"
    fi
}

# Test coverage check
check_coverage() {
    echo "📊 TEST COVERAGE ANALYSIS"
    echo "Checking current test coverage status..."
    echo ""
    
    if mix test --cover 2>/dev/null | grep "Total coverage"; then
        echo "✅ Coverage reporting functional"
    else
        echo "❌ Coverage reporting broken"
    fi
}

# Main execution
case "${1:-run}" in
    "validate")
        validate
        ;;
    "progress")
        progress
        ;;
    "phase1")
        phase1_compilation_fix
        ;;
    "phase2") 
        phase2_credo_resolution
        ;;
    "test-security")
        test_security_automation
        ;;
    "analyze-system-cmd")
        analyze_system_cmd
        ;;
    "check-coverage")
        check_coverage
        ;;
    *)
        echo "🚀 Starting Workstream E Quality Fix Process"
        echo ""
        
        # Always start with compilation fix
        if phase1_compilation_fix; then
            echo "✅ Phase 1 complete - proceeding to Phase 2"
            phase2_credo_resolution
        else
            echo "🛑 Phase 1 incomplete - fix compilation warnings first"
            exit 1
        fi
        ;;
esac