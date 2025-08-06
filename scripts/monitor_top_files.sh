#!/bin/bash
# monitor_top_files.sh - Monitor files with most Dialyzer errors
# Part of DIALYZER_ZERO_ERROR_PLAN_FINAL.md Phase 0

echo "=== Files with Most Errors ==="
echo "Top 20 files requiring attention:"
echo ""

if [ -f "dialyzer_current.txt" ]; then
    grep "^lib/" dialyzer_current.txt | cut -d':' -f1 | sort | uniq -c | sort -nr | head -20 | while read count file; do
        # Determine workstream based on file path
        workstream="Other"
        if echo "$file" | grep -qE "(utilities/analyzers/|core/domain/|platform/database/)"; then
            workstream="Alpha"
        elif echo "$file" | grep -qE "(contexts/battle_analysis/|contexts/battle_sharing/|contexts/combat_intelligence/|contexts/threat_surveillance/)"; then
            workstream="Beta"
        elif echo "$file" | grep -qE "(contexts/character_intelligence/|contexts/corporation_intelligence/|contexts/player_profile/|enrichment/)"; then
            workstream="Gamma"
        elif echo "$file" | grep -qE "(contexts/market_intelligence/|contexts/wormhole_operations/|contexts/surveillance/|core/infrastructure/)"; then
            workstream="Delta"
        elif echo "$file" | grep -qE "(lib/eve_dmv_web/|platform/monitoring/|error_handler.ex)"; then
            workstream="Epsilon"
        fi
        
        printf "%-3s %-8s %s\n" "$count" "[$workstream]" "$file"
    done
else
    echo "No dialyzer_current.txt found. Run analyze_dialyzer.sh first."
fi

echo ""
echo "=== Priority Recommendations ==="
echo "🎯 Focus on files with 5+ errors first"
echo "📊 Group fixes by workstream for efficiency"
echo "🔄 Re-run this script after each batch of fixes"

echo ""
echo "Workstream Legend:"
echo "  Alpha   = Core Infrastructure & Utilities"
echo "  Beta    = Battle & Combat Systems" 
echo "  Gamma   = Intelligence & Analytics"
echo "  Delta   = Market & Operations"
echo "  Epsilon = Web Interface & Platform"