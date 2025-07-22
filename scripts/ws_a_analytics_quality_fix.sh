#!/bin/bash
# Workstream A: Analytics & Intelligence Quality Fix Script
# Sprint 22: Current State Quality Recovery
# 
# CRITICAL SAFETY PROTOCOL - MANUAL INCREMENTAL APPROACH
# Target: 21 compilation warnings + 628 Credo issues

set -e

echo "🚨 WORKSTREAM A: Analytics & Intelligence Quality Fix"
echo "Target: 21 compilation warnings + 628 Credo issues"
echo "Safety: Manual incremental approach - NO BULK OPERATIONS"
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
    # Count Analytics & Intelligence specific issues
    issues=$(mix credo --strict lib/eve_dmv/analytics/ lib/eve_dmv/contexts/character_intelligence/ | grep -E "↗|↘" | wc -l || echo "0")
    echo "Current WS-A Credo issues: $issues"
    return $issues
}

run_tests() {
    echo "🧪 Running affected tests..."
    if ! mix test test/eve_dmv/analytics/ test/eve_dmv/intelligence/ --max-failures=1 2>/dev/null; then
        echo "❌ TESTS FAILED - Review changes"
        return 1
    fi
    echo "✅ Tests passing"
}

# Phase 1: Emergency Compilation Fix (Days 1-2)
phase1_compilation_fix() {
    echo ""
    echo "📊 PHASE 1: EMERGENCY COMPILATION FIX (Analytics)"
    echo "Target: 21 compilation warnings → 0"
    echo ""
    
    count_warnings
    initial_warnings=$?
    
    if [ $initial_warnings -eq 0 ]; then
        echo "✅ No compilation warnings in analytics - proceeding to Phase 2"
        return 0
    fi
    
    echo "🚨 CRITICAL: $initial_warnings warnings found in analytics/"
    echo ""
    echo "EMERGENCY PROTOCOL:"
    echo "1. Fix warnings in analytics/ directory ONLY"
    echo "2. Fix 5-10 files at a time (never more)"
    echo "3. Run validation after EACH batch"
    echo "4. Commit successful changes immediately"
    echo ""
    
    # Show specific warnings for analytics
    echo "Analytics warnings to fix:"
    mix compile 2>&1 | grep "warning:" | grep -E "lib/eve_dmv/analytics/|lib/eve_dmv/contexts/character_intelligence/"
    echo ""
    
    echo "⚠️  MANUAL ACTION REQUIRED:"
    echo "   1. Open lib/eve_dmv/analytics/ in your editor"
    echo "   2. Fix unused variables: add '_ = variable' or remove"
    echo "   3. Fix unreturned expressions: add '_ = expression' or return value"
    echo "   4. Run: ./scripts/ws_a_analytics_quality_fix.sh validate"
    echo "   5. Commit: git add -A && git commit -m 'fix: WS-A compilation warnings batch 1'"
    echo ""
    echo "🛑 DO NOT PROCEED TO PHASE 2 UNTIL WARNINGS = 0"
    
    return 1
}

# Phase 2: Distributed Credo Resolution (Days 3-21)
phase2_credo_resolution() {
    echo ""
    echo "📊 PHASE 2: CREDO QUALITY RESOLUTION (Analytics & Intelligence)"
    echo "Target: 628 Credo issues"
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
    
    echo "🎯 WS-A FOCUS AREAS:"
    echo "Priority 1: Pipeline readability issues (300 issues)"
    echo "Priority 2: Module organization issues (200 issues)"  
    echo "Priority 3: TODO comment resolution (128 issues)"
    echo ""
    
    # Show specific Credo issues
    echo "Analytics & Intelligence Credo issues:"
    mix credo --strict lib/eve_dmv/analytics/ lib/eve_dmv/contexts/character_intelligence/ | head -10
    echo ""
    
    echo "⚠️  MANUAL ACTION REQUIRED - INCREMENTAL APPROACH:"
    echo "   1. Pick ONE readability issue from the list above"
    echo "   2. Fix it manually (NO bulk find/replace)"
    echo "   3. Run: ./scripts/ws_a_analytics_quality_fix.sh validate"
    echo "   4. If clean, commit: git add -A && git commit -m 'fix: WS-A readability batch X'"
    echo "   5. Repeat for next issue"
    echo ""
    echo "Daily target: 33 issues resolved (628 ÷ 19 days)"
    echo "Never fix more than 5 issues without validation!"
    
    return $current_issues
}

# Validation function
validate() {
    echo "🔍 VALIDATION CHECKPOINT"
    echo ""
    
    # Check compilation first (most critical)
    check_compilation
    
    # Count current state
    count_warnings
    warnings=$?
    
    count_credo_issues  
    credo_issues=$?
    
    # Run tests for affected modules
    run_tests
    test_result=$?
    
    echo ""
    echo "📊 WORKSTREAM A STATUS:"
    echo "Compilation warnings: $warnings (Target: 0)"
    echo "Credo issues: $credo_issues (Target: <628)"
    echo "Tests: $([ $test_result -eq 0 ] && echo 'PASSING' || echo 'FAILING')"
    echo ""
    
    if [ $warnings -gt 0 ]; then
        echo "🛑 COMPILATION WARNINGS STILL PRESENT - PHASE 1 INCOMPLETE"
        echo "Cannot proceed to Credo fixes until compilation is clean"
        return 1
    fi
    
    if [ $test_result -ne 0 ]; then
        echo "⚠️  TESTS FAILING - Review recent changes"
        return 1
    fi
    
    echo "✅ Validation passed - safe to continue"
    return 0
}

# Progress tracking
progress() {
    echo "📈 WORKSTREAM A PROGRESS REPORT"
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
    
    if [ $warnings -eq 0 ] && [ $credo_issues -lt 314 ]; then
        echo "🎉 HALFWAY MILESTONE REACHED!"
    fi
    
    if [ $warnings -eq 0 ] && [ $credo_issues -eq 0 ]; then
        echo "🏆 WORKSTREAM A COMPLETE!"
        echo "Ready for Sprint 22 final validation"
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
    *)
        echo "🚀 Starting Workstream A Quality Fix Process"
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