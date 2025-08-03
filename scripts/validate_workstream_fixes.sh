#!/bin/bash
# Script to validate fixes from other workstreams
# Part of Workstream E: Testing & Validation

set -e

echo "🔍 Validating Workstream Fixes"
echo "=============================="
echo ""

# Function to check if specific patterns have been fixed
check_pattern_fixed() {
    local pattern="$1"
    local description="$2"
    
    if mix dialyzer 2>&1 | grep -q "$pattern"; then
        echo "❌ $description - Still present"
        return 1
    else
        echo "✅ $description - Fixed!"
        return 0
    fi
}

# Workstream A: Type Specification Fixes
echo "📋 Workstream A - Type Specifications:"
echo "-------------------------------------"

# Check if supertype warning pattern was removed from ignore file
if grep -q "Type specification.*is a supertype" .dialyzer_ignore.exs; then
    echo "❌ Supertype ignore pattern still in .dialyzer_ignore.exs"
else
    echo "✅ Supertype ignore pattern removed from .dialyzer_ignore.exs"
fi

# Count remaining supertype warnings if pattern was removed
echo ""
echo "Checking for actual supertype warnings..."
SUPERTYPE_COUNT=$(mix dialyzer 2>&1 | grep -c "is a supertype of the success typing" || true)
echo "  Found $SUPERTYPE_COUNT supertype warnings"

# Workstream B: Battle & Combat Module Fixes
echo ""
echo "📋 Workstream B - Battle & Combat Modules:"
echo "-----------------------------------------"

check_pattern_fixed "timeline_builder.*:not_implemented" "Timeline builder :not_implemented errors"
check_pattern_fixed "battle_sharing.*:curator_unavailable" "Battle curator unavailable errors"
check_pattern_fixed "tactical_highlight_manager.*:battle_data_unavailable" "Tactical highlight manager errors"

# Workstream C: Enum & Pattern Coverage
echo ""
echo "📋 Workstream C - Enum & Pattern Coverage:"
echo "-----------------------------------------"

check_pattern_fixed "threat_detector.*:stable" "Corporation threat detector :stable patterns"
check_pattern_fixed "external_group_analyzer.*enum" "External group analyzer enum patterns"
check_pattern_fixed "combat_intelligence_engine.*:minimal" "Combat intelligence :minimal patterns"

# Workstream D: Infrastructure & Cache Patterns
echo ""
echo "📋 Workstream D - Infrastructure & Cache:"
echo "----------------------------------------"

check_pattern_fixed "doctrine_effectiveness_service.*:miss.*{:ok, _}" "Cache miss pattern matches"
check_pattern_fixed "wanderer.*client.*pattern_match" "Wanderer client patterns"
check_pattern_fixed "authentication.*manager.*pattern_match" "Authentication manager patterns"

# Generate validation report
echo ""
echo "📊 Generating Validation Report..."

# Run full dialyzer and capture metrics
./scripts/dialyzer_metrics.sh > /dev/null 2>&1 || true

if [ -f dialyzer_metrics.json ]; then
    TOTAL_ERRORS=$(jq -r .total_errors dialyzer_metrics.json)
    NET_ERRORS=$(jq -r .net_errors dialyzer_metrics.json)
    
    echo ""
    echo "📈 Current Status:"
    echo "  Total Errors: $TOTAL_ERRORS"
    echo "  Net Errors: $NET_ERRORS"
    echo ""
    
    # Check if we're meeting targets for each workstream
    if [ "$TOTAL_ERRORS" -lt 1500 ]; then
        echo "✅ Good progress! Errors reduced by $((1916 - TOTAL_ERRORS)) from baseline"
    else
        echo "⚠️  Limited progress. Only $((1916 - TOTAL_ERRORS)) errors fixed so far"
    fi
fi

# Check for any new patterns that should be added to ignore file
echo ""
echo "🔍 Checking for New Patterns:"
echo "-----------------------------"

# Look for recurring patterns that might need temporary ignores
mix dialyzer 2>&1 | grep -E "^lib/.*:[0-9]+:" | \
    sed 's/^[^:]*:[0-9]*://' | \
    cut -d' ' -f1 | \
    sort | uniq -c | sort -nr | \
    head -10 | \
    while read count type; do
        if [ "$count" -gt 50 ]; then
            echo "⚠️  Pattern '$type' appears $count times - consider temporary ignore"
        fi
    done

echo ""
echo "✅ Validation complete!"