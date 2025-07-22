#!/bin/bash
# Workstream C: Cross-System Infrastructure & Refactoring Fix Script
# Sprint 22: Current State Quality Recovery
# 
# CRITICAL SAFETY PROTOCOL - FUNCTION EXTRACTION CAN BREAK LOGIC
# Target: 21 compilation warnings + 628 Credo issues

set -e

echo "🏗️  WORKSTREAM C: Cross-System Infrastructure & Refactoring"
echo "Target: 21 compilation warnings + 628 Credo issues"
echo "Focus: Refactoring opportunities with EXTREME CAUTION"
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
    # Count Infrastructure specific issues
    issues=$(mix credo --strict lib/eve_dmv/contexts/intelligence_infrastructure/ lib/eve_dmv/database/ lib/eve_dmv/telemetry/ | grep -E "↗|↘" | wc -l || echo "0")
    echo "Current WS-C Credo issues: $issues"
    return $issues
}

run_tests() {
    echo "🧪 Running infrastructure tests..."
    if ! mix test test/eve_dmv/contexts/intelligence_infrastructure/ test/eve_dmv/database/ --max-failures=1 2>/dev/null; then
        echo "❌ TESTS FAILED - Infrastructure changes broke functionality"
        return 1
    fi
    echo "✅ Tests passing"
}

# Phase 1: Emergency Compilation Fix (Days 1-2)
phase1_compilation_fix() {
    echo ""
    echo "📊 PHASE 1: EMERGENCY COMPILATION FIX (Infrastructure)"
    echo "Target: 21 compilation warnings → 0"
    echo "⚠️  CAUTION: Infrastructure changes affect all systems"
    echo ""
    
    count_warnings
    initial_warnings=$?
    
    if [ $initial_warnings -eq 0 ]; then
        echo "✅ No compilation warnings in infrastructure - proceeding to Phase 2"
        return 0
    fi
    
    echo "🚨 CRITICAL: $initial_warnings warnings found in infrastructure/"
    echo ""
    echo "EMERGENCY PROTOCOL:"
    echo "1. Fix warnings in intelligence_infrastructure/ directory ONLY"
    echo "2. Fix 3-5 files at a time (FEWER than other workstreams)"
    echo "3. CRITICAL: Test cross-system functionality after each batch"
    echo "4. Commit successful changes immediately"
    echo ""
    
    # Show specific warnings for infrastructure
    echo "Infrastructure warnings to fix:"
    mix compile 2>&1 | grep "warning:" | grep -E "lib/eve_dmv/contexts/intelligence_infrastructure/|lib/eve_dmv/database/|lib/eve_dmv/telemetry/"
    echo ""
    
    echo "⚠️  MANUAL ACTION REQUIRED - INFRASTRUCTURE CRITICAL:"
    echo "   1. Open lib/eve_dmv/contexts/intelligence_infrastructure/ in editor"
    echo "   2. Fix unused variables in database queries (CAREFULLY!)"
    echo "   3. Fix unused expressions in telemetry (affects monitoring!)"
    echo "   4. Run: ./scripts/ws_c_infrastructure_refactoring_fix.sh validate"
    echo "   5. MANDATORY: Test that database connections still work"
    echo "   6. Commit: git add -A && git commit -m 'fix: WS-C infrastructure warnings batch 1'"
    echo ""
    echo "🛑 DO NOT PROCEED TO PHASE 2 UNTIL WARNINGS = 0"
    echo "🛑 Infrastructure affects ALL other workstreams"
    
    return 1
}

# Phase 2: Distributed Credo Resolution (Days 3-21)
phase2_credo_resolution() {
    echo ""
    echo "📊 PHASE 2: CREDO QUALITY RESOLUTION (Infrastructure Refactoring)"
    echo "Target: 628 Credo issues"
    echo "⚠️  EXTREME CAUTION: Function extraction has broken logic before"
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
    
    echo "🎯 WS-C FOCUS AREAS (Infrastructure Refactoring):"
    echo "Priority 1: Function complexity reduction (250 issues) - CAREFUL!"
    echo "Priority 2: Pipe chain structure fixes (200 issues) - SAFE"  
    echo "Priority 3: Function length issues (178 issues) - DANGEROUS"
    echo ""
    
    # Show specific Credo issues
    echo "Infrastructure refactoring Credo issues:"
    mix credo --strict lib/eve_dmv/contexts/intelligence_infrastructure/ lib/eve_dmv/database/ | head -10
    echo ""
    
    echo "⚠️  MANUAL ACTION REQUIRED - REFACTORING SAFETY PROTOCOL:"
    echo "   1. START with pipe chain fixes (SAFEST) - just add formatting"
    echo "   2. Reduce nesting depth by adding early returns (NOT function extraction)"
    echo "   3. AVOID extracting functions unless absolutely necessary"
    echo "   4. Run: ./scripts/ws_c_infrastructure_refactoring_fix.sh validate"
    echo "   5. MANDATORY: Test database operations and telemetry"
    echo "   6. Commit: git add -A && git commit -m 'fix: WS-C safe refactoring batch X'"
    echo ""
    echo "Daily target: 33 issues resolved (628 ÷ 19 days)"
    echo "🛑 NEVER extract functions without extensive testing!"
    echo "🛑 Function extraction has caused subtle logic errors before!"
    
    return $current_issues
}

# Infrastructure functionality check
test_infrastructure() {
    echo "🏗️  Testing Infrastructure Functionality..."
    echo ""
    
    # Test database connectivity
    echo "Testing database operations..."
    if mix run -e "
        case EveDmv.Repo.query('SELECT 1', []) do
            {:ok, _result} -> IO.puts('✅ Database connectivity working')
            {:error, reason} -> IO.puts('❌ Database broken: #{inspect(reason)}'); System.halt(1)
        end
    " 2>/dev/null; then
        echo "✅ Database operations functional"
    else
        echo "❌ Database operations broken - rollback changes!"
        return 1
    fi
    
    # Test telemetry/monitoring
    echo "Testing telemetry systems..."
    if mix run -e "
        try do
            # Test basic telemetry loading
            :telemetry.list_handlers([])
            IO.puts('✅ Telemetry system working')
        rescue
            error -> IO.puts('❌ Telemetry broken: #{inspect(error)}'); System.halt(1)
        end
    " 2>/dev/null; then
        echo "✅ Telemetry systems functional"
    else
        echo "❌ Telemetry systems broken - rollback changes!"
        return 1
    fi
    
    # Test intelligence infrastructure
    echo "Testing intelligence infrastructure..."
    if mix run -e "
        try do
            # Test intelligence infrastructure module loading
            Code.ensure_loaded!(EveDmv.Contexts.IntelligenceInfrastructure)
            IO.puts('✅ Intelligence infrastructure loadable')
        rescue
            error -> IO.puts('❌ Intelligence infrastructure broken: #{inspect(error)}'); System.halt(1)
        end
    " 2>/dev/null; then
        echo "✅ Intelligence infrastructure functional"
    else
        echo "❌ Intelligence infrastructure broken - rollback changes!"
        return 1
    fi
    
    return 0
}

# Validation function
validate() {
    echo "🔍 VALIDATION CHECKPOINT - INFRASTRUCTURE"
    echo ""
    
    # Check compilation first (most critical)
    check_compilation
    
    # Count current state
    count_warnings
    warnings=$?
    
    count_credo_issues  
    credo_issues=$?
    
    # Test infrastructure functionality (CRITICAL for WS-C)
    test_infrastructure
    infra_test=$?
    
    # Run tests for affected modules
    run_tests
    test_result=$?
    
    echo ""
    echo "📊 WORKSTREAM C STATUS:"
    echo "Compilation warnings: $warnings (Target: 0)"
    echo "Credo issues: $credo_issues (Target: <628)"
    echo "Infrastructure: $([ $infra_test -eq 0 ] && echo 'FUNCTIONAL' || echo 'BROKEN')"
    echo "Tests: $([ $test_result -eq 0 ] && echo 'PASSING' || echo 'FAILING')"
    echo ""
    
    if [ $warnings -gt 0 ]; then
        echo "🛑 COMPILATION WARNINGS STILL PRESENT - PHASE 1 INCOMPLETE"
        echo "Cannot proceed to Credo fixes until compilation is clean"
        return 1
    fi
    
    if [ $infra_test -ne 0 ]; then
        echo "🛑 INFRASTRUCTURE BROKEN - ROLLBACK IMMEDIATELY"
        echo "This affects ALL other workstreams and core functionality"
        return 1
    fi
    
    if [ $test_result -ne 0 ]; then
        echo "⚠️  TESTS FAILING - Review recent changes"
        return 1
    fi
    
    echo "✅ Validation passed - infrastructure functional"
    return 0
}

# Progress tracking
progress() {
    echo "📈 WORKSTREAM C PROGRESS REPORT"
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
    
    # Check infrastructure health
    if test_infrastructure >/dev/null 2>&1; then
        echo "✅ Infrastructure functionality: INTACT"
    else
        echo "❌ Infrastructure functionality: BROKEN"
    fi
    
    if [ $warnings -eq 0 ] && [ $credo_issues -lt 314 ]; then
        echo "🎉 HALFWAY MILESTONE REACHED!"
    fi
    
    if [ $warnings -eq 0 ] && [ $credo_issues -eq 0 ]; then
        echo "🏆 WORKSTREAM C COMPLETE!"
        echo "Ready for Sprint 22 final validation"
    fi
}

# Function complexity analysis (safer than extraction)
analyze_complexity() {
    echo "🔍 FUNCTION COMPLEXITY ANALYSIS"
    echo "Showing functions that can be SAFELY simplified:"
    echo ""
    
    # Find complex functions but suggest safe fixes
    find lib/eve_dmv/contexts/intelligence_infrastructure/ -name "*.ex" -exec grep -l "cond do\|case " {} \; | head -5 | while read file; do
        echo "File: $file"
        echo "Safe fixes: Add early returns, reduce nesting with guard clauses"
        echo "AVOID: Extracting functions (can break logic)"
        echo ""
    done
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
    "test-infra")
        test_infrastructure
        ;;
    "analyze-complexity")
        analyze_complexity
        ;;
    *)
        echo "🚀 Starting Workstream C Quality Fix Process"
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