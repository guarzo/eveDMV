#!/bin/bash
# Workstream D: Battle & Fleet Operations Design Fix Script
# Sprint 22: Current State Quality Recovery
# 
# CRITICAL SAFETY PROTOCOL - TODO REMOVAL ELIMINATED CONTEXT
# Target: 22 compilation warnings + 628 Credo issues

set -e

echo "⚔️  WORKSTREAM D: Battle & Fleet Operations Design"
echo "Target: 22 compilation warnings + 628 Credo issues"
echo "Focus: Design suggestions with CAREFUL TODO handling"
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
    # Count Battle & Fleet Operations specific issues
    issues=$(mix credo --strict lib/eve_dmv/contexts/battle_analysis/ lib/eve_dmv/contexts/battle_sharing/ lib/eve_dmv/contexts/fleet_operations/ | grep -E "↗|↘" | wc -l || echo "0")
    echo "Current WS-D Credo issues: $issues"
    return $issues
}

run_tests() {
    echo "🧪 Running battle & fleet operations tests..."
    if ! mix test test/eve_dmv/contexts/battle_analysis/ test/eve_dmv/contexts/fleet_operations/ --max-failures=1 2>/dev/null; then
        echo "❌ TESTS FAILED - Battle/fleet functionality broken"
        return 1
    fi
    echo "✅ Tests passing"
}

# Phase 1: Emergency Compilation Fix (Days 1-2)
phase1_compilation_fix() {
    echo ""
    echo "📊 PHASE 1: EMERGENCY COMPILATION FIX (Battle & Fleet Operations)"
    echo "Target: 22 compilation warnings → 0"
    echo "⚠️  CAUTION: Battle operations are core functionality"
    echo ""
    
    count_warnings
    initial_warnings=$?
    
    if [ $initial_warnings -eq 0 ]; then
        echo "✅ No compilation warnings in battle operations - proceeding to Phase 2"
        return 0
    fi
    
    echo "🚨 CRITICAL: $initial_warnings warnings found in battle/fleet operations/"
    echo ""
    echo "EMERGENCY PROTOCOL:"
    echo "1. Fix warnings in battle/fleet operations directories ONLY"
    echo "2. Fix 5-8 files at a time (moderate batching)"
    echo "3. CRITICAL: Test battle analysis after each batch"
    echo "4. Commit successful changes immediately"
    echo ""
    
    # Show specific warnings for battle operations
    echo "Battle & Fleet Operations warnings to fix:"
    mix compile 2>&1 | grep "warning:" | grep -E "lib/eve_dmv/contexts/battle_analysis/|lib/eve_dmv/contexts/battle_sharing/|lib/eve_dmv/contexts/fleet_operations/"
    echo ""
    
    echo "⚠️  MANUAL ACTION REQUIRED - BATTLE OPERATIONS:"
    echo "   1. Open battle/fleet operations directories in editor"
    echo "   2. Fix unused variables in battle analyzers (CRITICAL!)"
    echo "   3. Fix unused expressions in fleet composition analysis"
    echo "   4. Run: ./scripts/ws_d_battle_operations_design_fix.sh validate"
    echo "   5. MANDATORY: Test battle detection and fleet analysis"
    echo "   6. Commit: git add -A && git commit -m 'fix: WS-D battle ops warnings batch 1'"
    echo ""
    echo "🛑 DO NOT PROCEED TO PHASE 2 UNTIL WARNINGS = 0"
    echo "🛑 Battle operations are critical user-facing features"
    
    return 1
}

# Phase 2: Distributed Credo Resolution (Days 3-21)
phase2_credo_resolution() {
    echo ""
    echo "📊 PHASE 2: CREDO QUALITY RESOLUTION (Battle & Fleet Design)"
    echo "Target: 628 Credo issues"
    echo "⚠️  WARNING: Mass TODO removal eliminated important implementation context"
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
    
    echo "🎯 WS-D FOCUS AREAS (Battle & Fleet Design):"
    echo "Priority 1: TODO comment resolution (182 issues) - MANUAL REVIEW!"
    echo "Priority 2: Nested module aliasing (150 issues) - SAFE"  
    echo "Priority 3: Module documentation (296 issues) - SAFE"
    echo ""
    
    # Show specific Credo issues
    echo "Battle & Fleet Operations Credo issues:"
    mix credo --strict lib/eve_dmv/contexts/battle_analysis/ lib/eve_dmv/contexts/fleet_operations/ | head -10
    echo ""
    
    echo "⚠️  MANUAL ACTION REQUIRED - TODO SAFETY PROTOCOL:"
    echo "   1. REVIEW each TODO comment individually (don't mass delete!)"
    echo "   2. Either: Implement the TODO, document why deferred, or remove if obsolete"
    echo "   3. Fix nested module aliases (safe - just move alias declarations)"
    echo "   4. Add module documentation (@moduledoc and @doc)"
    echo "   5. Run: ./scripts/ws_d_battle_operations_design_fix.sh validate"
    echo "   6. MANDATORY: Test battle and fleet functionality"
    echo "   7. Commit: git add -A && git commit -m 'fix: WS-D design improvements batch X'"
    echo ""
    echo "Daily target: 33 issues resolved (628 ÷ 19 days)"
    echo "🛑 NEVER mass-delete TODO comments!"
    echo "🛑 TODOs often contain important implementation context!"
    
    return $current_issues
}

# Battle & Fleet functionality check
test_battle_fleet_operations() {
    echo "⚔️  Testing Battle & Fleet Operations Functionality..."
    echo ""
    
    # Test battle analysis
    echo "Testing battle analysis..."
    if mix run -e "
        alias EveDmv.Analytics.BattleDetector
        case BattleDetector.detect_character_battles(123456789, 1) do
            battles when is_list(battles) -> IO.puts('✅ Battle analysis working')
            _ -> IO.puts('❌ Battle analysis broken'); System.halt(1)
        end
    " 2>/dev/null; then
        echo "✅ Battle analysis functional"
    else
        echo "❌ Battle analysis broken - rollback changes!"
        return 1
    fi
    
    # Test fleet operations
    echo "Testing fleet operations..."
    if mix run -e "
        try do
            # Test fleet operations module loading
            Code.ensure_loaded!(EveDmv.Contexts.FleetOperations)
            IO.puts('✅ Fleet operations loadable')
        rescue
            error -> IO.puts('❌ Fleet operations broken: #{inspect(error)}'); System.halt(1)
        end
    " 2>/dev/null; then
        echo "✅ Fleet operations functional"
    else
        echo "❌ Fleet operations broken - rollback changes!"
        return 1
    fi
    
    # Test battle sharing
    echo "Testing battle sharing..."
    if mix run -e "
        try do
            # Test battle sharing module loading
            Code.ensure_loaded!(EveDmv.Contexts.BattleSharing)
            IO.puts('✅ Battle sharing loadable')
        rescue
            error -> IO.puts('❌ Battle sharing broken: #{inspect(error)}'); System.halt(1)
        end
    " 2>/dev/null; then
        echo "✅ Battle sharing functional"
    else
        echo "❌ Battle sharing broken - rollback changes!"
        return 1
    fi
    
    return 0
}

# TODO analysis helper
analyze_todos() {
    echo "📝 TODO COMMENT ANALYSIS"
    echo "Showing TODO comments that need manual review:"
    echo ""
    
    # Find TODO comments in battle/fleet operations
    find lib/eve_dmv/contexts/battle_analysis/ lib/eve_dmv/contexts/battle_sharing/ lib/eve_dmv/contexts/fleet_operations/ -name "*.ex" -exec grep -n "TODO\|FIXME\|XXX" {} + | head -10 | while IFS=: read file line_num comment; do
        echo "File: $file:$line_num"
        echo "Comment: $comment"
        echo "Action: Review and decide - implement, document, or remove"
        echo ""
    done
}

# Validation function
validate() {
    echo "🔍 VALIDATION CHECKPOINT - BATTLE & FLEET OPERATIONS"
    echo ""
    
    # Check compilation first (most critical)
    check_compilation
    
    # Count current state
    count_warnings
    warnings=$?
    
    count_credo_issues  
    credo_issues=$?
    
    # Test battle & fleet functionality (CRITICAL for WS-D)
    test_battle_fleet_operations
    ops_test=$?
    
    # Run tests for affected modules
    run_tests
    test_result=$?
    
    echo ""
    echo "📊 WORKSTREAM D STATUS:"
    echo "Compilation warnings: $warnings (Target: 0)"
    echo "Credo issues: $credo_issues (Target: <628)"
    echo "Battle/Fleet ops: $([ $ops_test -eq 0 ] && echo 'FUNCTIONAL' || echo 'BROKEN')"
    echo "Tests: $([ $test_result -eq 0 ] && echo 'PASSING' || echo 'FAILING')"
    echo ""
    
    if [ $warnings -gt 0 ]; then
        echo "🛑 COMPILATION WARNINGS STILL PRESENT - PHASE 1 INCOMPLETE"
        echo "Cannot proceed to Credo fixes until compilation is clean"
        return 1
    fi
    
    if [ $ops_test -ne 0 ]; then
        echo "🛑 BATTLE/FLEET OPERATIONS BROKEN - ROLLBACK IMMEDIATELY"
        echo "This breaks core user-facing functionality"
        return 1
    fi
    
    if [ $test_result -ne 0 ]; then
        echo "⚠️  TESTS FAILING - Review recent changes"
        return 1
    fi
    
    echo "✅ Validation passed - battle/fleet operations functional"
    return 0
}

# Progress tracking
progress() {
    echo "📈 WORKSTREAM D PROGRESS REPORT"
    echo ""
    
    count_warnings
    warnings=$?
    
    count_credo_issues
    credo_issues=$?
    
    # Calculate progress percentages
    warning_progress=$(( (22 - warnings) * 100 / 22 ))
    credo_progress=$(( (628 - credo_issues) * 100 / 628 ))
    
    echo "📊 PROGRESS SUMMARY:"
    echo "Phase 1 (Compilation): $warning_progress% complete ($warnings warnings remaining)"
    echo "Phase 2 (Credo): $credo_progress% complete ($credo_issues issues remaining)"
    echo ""
    
    # Check battle/fleet operations health
    if test_battle_fleet_operations >/dev/null 2>&1; then
        echo "✅ Battle/Fleet operations: INTACT"
    else
        echo "❌ Battle/Fleet operations: BROKEN"
    fi
    
    # Show TODO progress
    todo_count=$(find lib/eve_dmv/contexts/battle_analysis/ lib/eve_dmv/contexts/battle_sharing/ lib/eve_dmv/contexts/fleet_operations/ -name "*.ex" -exec grep -c "TODO\|FIXME\|XXX" {} + 2>/dev/null | awk '{sum += $1} END {print sum}' || echo "0")
    echo "📝 TODO comments remaining: $todo_count (requires manual review)"
    
    if [ $warnings -eq 0 ] && [ $credo_issues -lt 314 ]; then
        echo "🎉 HALFWAY MILESTONE REACHED!"
    fi
    
    if [ $warnings -eq 0 ] && [ $credo_issues -eq 0 ]; then
        echo "🏆 WORKSTREAM D COMPLETE!"
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
    "test-ops")
        test_battle_fleet_operations
        ;;
    "analyze-todos")
        analyze_todos
        ;;
    *)
        echo "🚀 Starting Workstream D Quality Fix Process"
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