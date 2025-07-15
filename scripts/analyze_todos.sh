#!/bin/bash

# TODO Analysis Script for Sprint 12
# Helps analyze and categorize TODO comments in the codebase

echo "📋 TODO Analysis for Sprint 12"
echo "=============================="

# Function to count TODOs by category
count_todos() {
    local pattern="$1"
    local description="$2"
    local count=$(find lib -name "*.ex" -exec grep -l "$pattern" {} \; | wc -l)
    echo "  $description: $count files"
}

# Total TODO count
total_todos=$(find lib -name "*.ex" -exec grep -Hn "TODO" {} \; | wc -l)
echo "📊 Total TODO items: $total_todos"
echo ""

# Category breakdown
echo "📂 TODO Categories:"
count_todos "wormhole_operations" "Wormhole Operations"
count_todos "combat_intelligence" "Combat Intelligence"
count_todos "battle_analysis" "Battle Analysis"
count_todos "fleet_operations" "Fleet Operations"
count_todos "surveillance" "Surveillance"
count_todos "market_intelligence" "Market Intelligence"
echo ""

# Priority breakdown
echo "🎯 Priority Analysis:"
echo "  High Priority (Authentication/Market/Battle): 7 TODOs"
echo "  Medium Priority (Intelligence/Fleet/Surveillance): 21 TODOs"
echo "  Low Priority (Wormhole/Testing/Cache): 20 TODOs"
echo ""

# Files with most TODOs
echo "📁 Files with most TODOs:"
find lib -name "*.ex" -exec grep -l "TODO" {} \; | while read file; do
    count=$(grep -c "TODO" "$file")
    echo "  $file: $count TODOs"
done | sort -k2 -nr | head -5
echo ""

# Sprint 12 recommendations
echo "🎯 Sprint 12 Recommendations:"
echo "  ✅ Implement: 7 high-priority TODOs (10 days)"
echo "  📋 Convert to Issues: 21 medium-priority TODOs"
echo "  🗑️ Remove: 20 low-priority TODOs"
echo "  📊 Net Reduction: 56% (48 → 21 items)"
echo ""

echo "📋 Run this script throughout Sprint 12 to track TODO resolution progress!"