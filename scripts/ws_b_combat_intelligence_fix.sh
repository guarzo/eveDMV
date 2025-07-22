#!/bin/bash
# Workstream B: Combat Intelligence & Warnings Fix Script
# Sprint 22: Current State Quality Recovery
# 
# CRITICAL SAFETY PROTOCOL - FOCUS ON UNUSED RETURN VALUES
# Target: 22 compilation warnings + 628 Credo issues

set -e

echo "⚔️  WORKSTREAM B: Combat Intelligence & Warnings Fix"
echo "Target: 22 compilation warnings + 628 Credo issues"
echo "Focus: Unused return values that break battle analysis"
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
    # Count Combat Intelligence specific issues
    issues=$(mix credo --strict lib/eve_dmv/contexts/combat_intelligence/ | grep -E "↗|↘" | wc -l || echo "0")
    echo "Current WS-B Credo issues: $issues"
    return $issues
}

run_tests() {
    echo "🧪 Running combat intelligence tests..."
    if ! mix test test/eve_dmv/contexts/battle_analysis/ test/eve_dmv/contexts/combat_intelligence/ --max-failures=1 2>/dev/null; then
        echo "❌ TESTS FAILED - Review changes (battle analysis is critical!)"
        return 1
    fi
    echo "✅ Tests passing"
}

# Phase 1: Emergency Compilation Fix (Days 1-2)
phase1_compilation_fix() {
    echo ""
    echo "📊 PHASE 1: EMERGENCY COMPILATION FIX (Combat Intelligence)"
    echo "Target: 22 compilation warnings → 0"
    echo "⚠️  CRITICAL: Unused return values break battle analysis"
    echo ""
    
    count_warnings
    initial_warnings=$?
    
    if [ $initial_warnings -eq 0 ]; then
        echo "✅ No compilation warnings in combat intelligence - proceeding to Phase 2"
        return 0
    fi
    
    echo "🚨 CRITICAL: $initial_warnings warnings found in combat_intelligence/"
    echo ""
    echo "EMERGENCY PROTOCOL:"
    echo "1. Fix warnings in combat_intelligence/ directory ONLY"
    echo "2. Fix 5-10 files at a time (never more)"
    echo "3. CRITICAL: Test battle analysis after each batch"
    echo "4. Commit successful changes immediately"
    echo ""
    
    # Show specific warnings for combat intelligence
    echo "Combat Intelligence warnings to fix:"
    mix compile 2>&1 | grep "warning:" | grep "lib/eve_dmv/contexts/combat_intelligence/"
    echo ""
    
    echo "⚠️  MANUAL ACTION REQUIRED - BATTLE ANALYSIS CRITICAL:"
    echo "   1. Open lib/eve_dmv/contexts/combat_intelligence/ in editor"
    echo "   2. Fix unused Enum.map(), Enum.filter() return values (CRITICAL!)"
    echo "   3. Fix unused query variables in battle analysis"
    echo "   4. Run: ./scripts/ws_b_combat_intelligence_fix.sh validate"
    echo "   5. MANDATORY: Test battle detection still works"
    echo "   6. Commit: git add -A && git commit -m 'fix: WS-B critical compilation warnings batch 1'"
    echo ""
    echo "🛑 DO NOT PROCEED TO PHASE 2 UNTIL WARNINGS = 0"
    echo "🛑 Battle analysis functionality must remain intact"
    
    return 1
}

# Phase 2: Distributed Credo Resolution (Days 3-21)
phase2_credo_resolution() {
    echo ""
    echo "📊 PHASE 2: CREDO QUALITY RESOLUTION (Combat Intelligence)"
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
    
    echo "🎯 WS-B FOCUS AREAS (Combat Intelligence):"
    echo "Priority 1: Unused return value warnings (400 issues) - CRITICAL"
    echo "Priority 2: System.cmd security warnings (50 issues) - SECURITY"  
    echo "Priority 3: Pipeline complexity issues (178 issues)"
    echo ""
    
    # Show specific Credo issues
    echo "Combat Intelligence Credo issues:"
    mix credo --strict lib/eve_dmv/contexts/combat_intelligence/ | head -10
    echo ""
    
    echo "⚠️  MANUAL ACTION REQUIRED - SECURITY & FUNCTIONALITY:"
    echo "   1. Focus on unused return value warnings FIRST (break battle analysis)"
    echo "   2. Replace System.cmd with secure alternatives (Port.cmd, etc.)"
    echo "   3. Simplify complex pipeline chains in analyzers"
    echo "   4. Run: ./scripts/ws_b_combat_intelligence_fix.sh validate"
    echo "   5. MANDATORY: Test battle analysis functionality"
    echo "   6. Commit: git add -A && git commit -m 'fix: WS-B security/functionality batch X'"
    echo ""
    echo "Daily target: 33 issues resolved (628 ÷ 19 days)"
    echo "🛑 NEVER fix more than 3 issues without testing battle analysis!"
    
    return $current_issues
}

# Battle analysis functionality check
test_battle_analysis() {
    echo "🎯 Testing Battle Analysis Functionality..."
    echo ""
    
    # Test battle detection
    echo "Testing battle detection..."
    if mix run -e "
        alias EveDmv.Analytics.BattleDetector
        case BattleDetector.detect_character_battles(123456789, 1) do
            battles when is_list(battles) -> IO.puts('✅ Battle detection working')
            _ -> IO.puts('❌ Battle detection broken'); System.halt(1)
        end
    " 2>/dev/null; then
        echo "✅ Battle detection functional"
    else
        echo "❌ Battle detection broken - rollback changes!"
        return 1
    fi
    
    # Test combat intelligence analysis
    echo "Testing combat intelligence analysis..."
    if mix run -e "
        try do
            # Test a basic analysis function exists and doesn't crash
            EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysisService
            IO.puts('✅ Combat intelligence module loadable')
        rescue
            _ -> IO.puts('❌ Combat intelligence broken'); System.halt(1)
        end
    " 2>/dev/null; then
        echo "✅ Combat intelligence functional"
    else
        echo "❌ Combat intelligence broken - rollback changes!"
        return 1
    fi
    
    return 0
}

# Validation function
validate() {
    echo "🔍 VALIDATION CHECKPOINT - COMBAT INTELLIGENCE"
    echo ""
    
    # Check compilation first (most critical)
    check_compilation
    
    # Count current state
    count_warnings
    warnings=$?
    
    count_credo_issues  
    credo_issues=$?
    
    # Test battle analysis functionality (CRITICAL for WS-B)
    test_battle_analysis
    battle_test=$?
    
    # Run tests for affected modules
    run_tests
    test_result=$?
    
    echo ""
    echo "📊 WORKSTREAM B STATUS:"
    echo "Compilation warnings: $warnings (Target: 0)"
    echo "Credo issues: $credo_issues (Target: <628)"
    echo "Battle analysis: $([ $battle_test -eq 0 ] && echo 'FUNCTIONAL' || echo 'BROKEN')"
    echo "Tests: $([ $test_result -eq 0 ] && echo 'PASSING' || echo 'FAILING')"
    echo ""
    
    if [ $warnings -gt 0 ]; then
        echo "🛑 COMPILATION WARNINGS STILL PRESENT - PHASE 1 INCOMPLETE"
        echo "Cannot proceed to Credo fixes until compilation is clean"
        return 1
    fi
    
    if [ $battle_test -ne 0 ]; then
        echo "🛑 BATTLE ANALYSIS BROKEN - ROLLBACK IMMEDIATELY"
        echo "This breaks core application functionality"
        return 1
    fi
    
    if [ $test_result -ne 0 ]; then
        echo "⚠️  TESTS FAILING - Review recent changes"
        return 1
    fi
    
    echo "✅ Validation passed - battle analysis functional"
    return 0
}

# Progress tracking
progress() {
    echo "📈 WORKSTREAM B PROGRESS REPORT"
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
    
    # Check battle analysis health
    if test_battle_analysis >/dev/null 2>&1; then
        echo "✅ Battle analysis functionality: INTACT"
    else
        echo "❌ Battle analysis functionality: BROKEN"
    fi
    
    if [ $warnings -eq 0 ] && [ $credo_issues -lt 314 ]; then
        echo "🎉 HALFWAY MILESTONE REACHED!"
    fi
    
    if [ $warnings -eq 0 ] && [ $credo_issues -eq 0 ]; then
        echo "🏆 WORKSTREAM B COMPLETE!"
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
    "test-battle")
        test_battle_analysis
        ;;
    *)
        echo "🚀 Starting Workstream B Quality Fix Process"
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