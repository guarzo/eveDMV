#!/bin/bash
# analyze_dialyzer.sh - Analyze current Dialyzer errors
# Part of DIALYZER_ZERO_ERROR_PLAN_FINAL.md Phase 0

echo "=== Dialyzer Error Analysis ==="
echo "Running Dialyzer analysis..."

mix dialyzer --format short > dialyzer_current.txt 2>&1 || true

TOTAL_ERRORS=$(grep -c "^lib/" dialyzer_current.txt || echo "0")
echo "Total errors: $TOTAL_ERRORS"

echo ""
echo "=== Error Distribution by Type ==="
grep "^lib/" dialyzer_current.txt | awk -F':[0-9]+:' '{print $2}' | awk '{print $1}' | sort | uniq -c | sort -nr

echo ""
echo "=== Top 10 Files with Most Errors ==="
grep "^lib/" dialyzer_current.txt | cut -d':' -f1 | sort | uniq -c | sort -nr | head -10

echo ""
echo "=== Workstream Breakdown ==="
echo "Alpha (Core Infrastructure & Utilities):"
grep "^lib/" dialyzer_current.txt | grep -E "(utilities/analyzers/|core/domain/|platform/database/)" | wc -l || echo "0"

echo "Beta (Battle & Combat Systems):"
grep "^lib/" dialyzer_current.txt | grep -E "(contexts/battle_analysis/|contexts/battle_sharing/|contexts/combat_intelligence/|contexts/threat_surveillance/)" | wc -l || echo "0"

echo "Gamma (Intelligence & Analytics):"
grep "^lib/" dialyzer_current.txt | grep -E "(contexts/character_intelligence/|contexts/corporation_intelligence/|contexts/player_profile/|enrichment/)" | wc -l || echo "0"

echo "Delta (Market & Operations):"
grep "^lib/" dialyzer_current.txt | grep -E "(contexts/market_intelligence/|contexts/wormhole_operations/|contexts/surveillance/|core/infrastructure/)" | wc -l || echo "0"

echo "Epsilon (Web Interface & Platform):"
grep "^lib/" dialyzer_current.txt | grep -E "(lib/eve_dmv_web/|platform/monitoring/|error_handler.ex)" | wc -l || echo "0"

echo ""
echo "=== Analysis Complete ==="
echo "Detailed errors saved to: dialyzer_current.txt"