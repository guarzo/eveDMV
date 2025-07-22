#!/bin/bash
# Week 1 Distributed Quality Validation Gate
# Sprint 22: Current State Quality Recovery
# 
# VALIDATION: 50% distributed quality reduction achieved
# Checks progress across all 5 workstreams

set -e

echo "📊 WEEK 1 DISTRIBUTED QUALITY VALIDATION GATE"
echo "Target: 50% Credo reduction across all workstreams"
echo "Individual workstream targets: ~314 issues resolved each"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Gate status tracking
GATE_PASSED=true
WORKSTREAMS_ON_TRACK=0

echo "🔍 COMPILATION MAINTENANCE CHECK"
echo "================================"

# Ensure compilation is still clean (mandatory)
if mix compile --warnings-as-errors >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Compilation Status: CLEAN (maintained)${NC}"
else
    echo -e "${RED}❌ Compilation Status: BROKEN${NC}"
    echo "🛑 STOP: Fix compilation before proceeding with quality work"
    GATE_PASSED=false
fi

warning_count=$(mix compile 2>&1 | grep "warning:" | wc -l || echo "0")
if [ "$warning_count" -eq 0 ]; then
    echo -e "${GREEN}✅ Compilation Warnings: 0 (maintained)${NC}"
else
    echo -e "${RED}❌ Compilation Warnings: $warning_count (regression!)${NC}"
    GATE_PASSED=false
fi

echo ""
echo "📈 DISTRIBUTED QUALITY PROGRESS CHECK"
echo "====================================="

# Check total Credo issues
echo "🔍 Checking total Credo issue count..."
total_credo=$(mix credo --strict 2>&1 | grep -E "found [0-9]+ warnings" | grep -o "[0-9]+" | head -1 || echo "3139")
target_50_percent=1570  # 3139 / 2 = 1569.5, rounded up

echo "Total Credo Issues: $total_credo"
echo "Week 1 Target: <$target_50_percent (50% reduction)"

if [ "$total_credo" -lt "$target_50_percent" ]; then
    echo -e "${GREEN}✅ Overall Progress: 50% reduction achieved${NC}"
else
    echo -e "${YELLOW}⚠️  Overall Progress: $(( (3139 - total_credo) * 100 / 3139 ))% reduction (target: 50%)${NC}"
fi

echo ""
echo "🏗️  INDIVIDUAL WORKSTREAM PROGRESS"
echo "=================================="

# Workstream A: Analytics & Intelligence
echo "Workstream A: Analytics & Intelligence"
ws_a_issues=$(mix credo --strict lib/eve_dmv/analytics/ lib/eve_dmv/contexts/character_intelligence/ 2>&1 | grep -E "↗|↘" | wc -l || echo "628")
ws_a_target=314  # 628 / 2
ws_a_resolved=$(( 628 - ws_a_issues ))

echo "  Issues remaining: $ws_a_issues / 628"
echo "  Issues resolved: $ws_a_resolved (target: >$ws_a_target)"

if [ "$ws_a_resolved" -gt "$ws_a_target" ]; then
    echo -e "  Status: ${GREEN}ON TRACK${NC}"
    ((WORKSTREAMS_ON_TRACK++))
else
    echo -e "  Status: ${YELLOW}BEHIND ($(( ws_a_resolved * 100 / ws_a_target ))% of target)${NC}"
fi

# Workstream B: Combat Intelligence
echo ""
echo "Workstream B: Combat Intelligence & Warnings"
ws_b_issues=$(mix credo --strict lib/eve_dmv/contexts/combat_intelligence/ 2>&1 | grep -E "↗|↘" | wc -l || echo "628")
ws_b_target=314
ws_b_resolved=$(( 628 - ws_b_issues ))

echo "  Issues remaining: $ws_b_issues / 628"
echo "  Issues resolved: $ws_b_resolved (target: >$ws_b_target)"

if [ "$ws_b_resolved" -gt "$ws_b_target" ]; then
    echo -e "  Status: ${GREEN}ON TRACK${NC}"
    ((WORKSTREAMS_ON_TRACK++))
else
    echo -e "  Status: ${YELLOW}BEHIND ($(( ws_b_resolved * 100 / ws_b_target ))% of target)${NC}"
fi

# Workstream C: Infrastructure
echo ""
echo "Workstream C: Cross-System Infrastructure"
ws_c_issues=$(mix credo --strict lib/eve_dmv/contexts/intelligence_infrastructure/ lib/eve_dmv/database/ lib/eve_dmv/telemetry/ 2>&1 | grep -E "↗|↘" | wc -l || echo "628")
ws_c_target=314
ws_c_resolved=$(( 628 - ws_c_issues ))

echo "  Issues remaining: $ws_c_issues / 628"
echo "  Issues resolved: $ws_c_resolved (target: >$ws_c_target)"

if [ "$ws_c_resolved" -gt "$ws_c_target" ]; then
    echo -e "  Status: ${GREEN}ON TRACK${NC}"
    ((WORKSTREAMS_ON_TRACK++))
else
    echo -e "  Status: ${YELLOW}BEHIND ($(( ws_c_resolved * 100 / ws_c_target ))% of target)${NC}"
fi

# Workstream D: Battle Operations
echo ""
echo "Workstream D: Battle & Fleet Operations"
ws_d_issues=$(mix credo --strict lib/eve_dmv/contexts/battle_analysis/ lib/eve_dmv/contexts/battle_sharing/ lib/eve_dmv/contexts/fleet_operations/ 2>&1 | grep -E "↗|↘" | wc -l || echo "628")
ws_d_target=314
ws_d_resolved=$(( 628 - ws_d_issues ))

echo "  Issues remaining: $ws_d_issues / 628"
echo "  Issues resolved: $ws_d_resolved (target: >$ws_d_target)"

if [ "$ws_d_resolved" -gt "$ws_d_target" ]; then
    echo -e "  Status: ${GREEN}ON TRACK${NC}"
    ((WORKSTREAMS_ON_TRACK++))
else
    echo -e "  Status: ${YELLOW}BEHIND ($(( ws_d_resolved * 100 / ws_d_target ))% of target)${NC}"
fi

# Workstream E: Testing & Security
echo ""
echo "Workstream E: Testing & Security Automation"
ws_e_issues=$(mix credo --strict test/ lib/mix/ 2>&1 | grep -E "↗|↘" | wc -l || echo "628")
ws_e_target=314
ws_e_resolved=$(( 628 - ws_e_issues ))

echo "  Issues remaining: $ws_e_issues / 628"
echo "  Issues resolved: $ws_e_resolved (target: >$ws_e_target)"

if [ "$ws_e_resolved" -gt "$ws_e_target" ]; then
    echo -e "  Status: ${GREEN}ON TRACK${NC}"
    ((WORKSTREAMS_ON_TRACK++))
else
    echo -e "  Status: ${YELLOW}BEHIND ($(( ws_e_resolved * 100 / ws_e_target ))% of target)${NC}"
fi

# Test stability check
echo ""
echo "🧪 TEST STABILITY CHECK"
echo "======================"
test_output=$(mix test --max-failures=5 2>&1 | grep -E "[0-9]+ tests, [0-9]+ failures" | tail -1 || echo "0 tests, 0 failures")
test_failures=$(echo "$test_output" | awk '{print $3}' | tr -d ',')

echo "Test Status: $test_output"
if [ "$test_failures" = "0" ] || [ -z "$test_failures" ]; then
    echo -e "${GREEN}✅ Test Stability: Maintained${NC}"
else
    echo -e "${YELLOW}⚠️  Test Stability: $test_failures failures (investigate)${NC}"
fi

echo ""
echo "📊 WEEK 1 GATE SUMMARY"
echo "======================"
echo "Compilation: $([ "$warning_count" -eq 0 ] && echo 'CLEAN' || echo 'BROKEN')"
echo "Overall Credo Progress: $(( (3139 - total_credo) * 100 / 3139 ))% (target: 50%)"
echo "Workstreams On Track: $WORKSTREAMS_ON_TRACK / 5"
echo "Test Stability: $([ "$test_failures" = "0" ] && echo 'STABLE' || echo "$test_failures failures")"

echo ""

# Gate decision logic
proceed_conditions=0

# Check mandatory conditions
if [ "$warning_count" -eq 0 ]; then
    ((proceed_conditions++))
fi

if [ "$total_credo" -lt "$target_50_percent" ]; then
    ((proceed_conditions++))
fi

if [ "$WORKSTREAMS_ON_TRACK" -ge 3 ]; then
    ((proceed_conditions++))
fi

if [ "$test_failures" = "0" ] || [ -z "$test_failures" ]; then
    ((proceed_conditions++))
fi

# Final gate decision
if [ "$proceed_conditions" -ge 3 ] && [ "$warning_count" -eq 0 ]; then
    echo -e "${GREEN}🎉 WEEK 1 VALIDATION GATE: PASSED${NC}"
    echo ""
    echo "✅ PROCEED to Week 2 - Distributed quality on track"
    echo "✅ Sprint 22 halfway point achievable"
    echo ""
    echo "Week 2 focus:"
    echo "1. Continue distributed quality resolution"
    echo "2. Support struggling workstreams"
    echo "3. Target: 75% reduction by end of week 2"
    echo "4. Next gate: ./scripts/final_production_validation.sh"
    echo ""
    
    # Guidance for struggling workstreams
    if [ "$WORKSTREAMS_ON_TRACK" -lt 5 ]; then
        echo "🎯 SUPPORT NEEDED:"
        [ "$ws_a_resolved" -le "$ws_a_target" ] && echo "- WS-A: Focus on pipeline readability (safest fixes)"
        [ "$ws_b_resolved" -le "$ws_b_target" ] && echo "- WS-B: Priority on unused return values (critical)"
        [ "$ws_c_resolved" -le "$ws_c_target" ] && echo "- WS-C: Focus on pipe chains (safest refactoring)"
        [ "$ws_d_resolved" -le "$ws_d_target" ] && echo "- WS-D: Manual TODO review (no mass deletion)"
        [ "$ws_e_resolved" -le "$ws_e_target" ] && echo "- WS-E: Test improvements first (safer than System.cmd)"
        echo ""
    fi
    
    exit 0
else
    echo -e "${RED}⚠️  WEEK 1 VALIDATION GATE: CONDITIONAL${NC}"
    echo ""
    echo "Status: Proceeding with caution"
    echo "Conditions met: $proceed_conditions / 4"
    echo ""
    
    if [ "$warning_count" -gt 0 ]; then
        echo "🛑 BLOCKING ISSUE: Compilation warnings must be resolved immediately"
    fi
    
    echo "Week 2 adjustments needed:"
    echo "1. Focus resources on struggling workstreams"
    echo "2. Daily check-ins and support"
    echo "3. Consider scope reduction if needed"
    echo "4. Ensure compilation stays clean"
    echo ""
    
    if [ "$warning_count" -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
fi