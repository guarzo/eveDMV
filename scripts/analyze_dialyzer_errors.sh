#!/bin/bash

echo "=== Comprehensive Dialyzer Error Analysis ==="
echo "Date: $(date)"
echo ""

# Create temporary directory for analysis
mkdir -p /tmp/dialyzer_analysis

# Function to analyze a specific directory
analyze_directory() {
    local dir=$1
    local name=$2
    echo "Analyzing $name..."
    
    if [ -d "$dir" ]; then
        # Run dialyzer on this directory only
        timeout 60 mix dialyzer --format short "$dir"/*.ex 2>&1 | head -500 > "/tmp/dialyzer_analysis/${name}.txt" || true
        
        # Count error types
        local total=$(grep -c "^lib/" "/tmp/dialyzer_analysis/${name}.txt" 2>/dev/null || echo 0)
        local unknown=$(grep -c "unknown_function" "/tmp/dialyzer_analysis/${name}.txt" 2>/dev/null || echo 0)
        local no_return=$(grep -c "no_return" "/tmp/dialyzer_analysis/${name}.txt" 2>/dev/null || echo 0)
        local pattern=$(grep -c "pattern_match" "/tmp/dialyzer_analysis/${name}.txt" 2>/dev/null || echo 0)
        local unused=$(grep -c "unused_fun" "/tmp/dialyzer_analysis/${name}.txt" 2>/dev/null || echo 0)
        local callback=$(grep -c "callback" "/tmp/dialyzer_analysis/${name}.txt" 2>/dev/null || echo 0)
        local contract=$(grep -c "contract" "/tmp/dialyzer_analysis/${name}.txt" 2>/dev/null || echo 0)
        
        echo "  Total errors: $total"
        echo "  - unknown_function: $unknown"
        echo "  - no_return: $no_return"
        echo "  - pattern_match: $pattern"
        echo "  - unused_fun: $unused"
        echo "  - callback: $callback"
        echo "  - contract: $contract"
        echo ""
    fi
}

# Analyze major directories
echo "## Error Analysis by Component:"
echo ""

analyze_directory "/workspace/lib/eve_dmv_web/live" "LiveViews"
analyze_directory "/workspace/lib/eve_dmv_web/controllers" "Controllers"
analyze_directory "/workspace/lib/eve_dmv_web/components" "Components"
analyze_directory "/workspace/lib/eve_dmv/contexts/battle_analysis" "BattleAnalysis"
analyze_directory "/workspace/lib/eve_dmv/contexts/surveillance" "Surveillance"
analyze_directory "/workspace/lib/eve_dmv/contexts/intelligence" "Intelligence"
analyze_directory "/workspace/lib/eve_dmv/contexts/wormhole_operations" "WormholeOps"
analyze_directory "/workspace/lib/eve_dmv/contexts/corporation" "Corporation"
analyze_directory "/workspace/lib/eve_dmv/platform/database" "Database"
analyze_directory "/workspace/lib/eve_dmv/platform/cache" "Cache"
analyze_directory "/workspace/lib/eve_dmv/platform/monitoring" "Monitoring"
analyze_directory "/workspace/lib/eve_dmv/workers" "Workers"

# Aggregate results
echo "## Top Error Patterns:"
echo ""

# Find most common unknown functions
echo "### Most Common Unknown Functions:"
cat /tmp/dialyzer_analysis/*.txt 2>/dev/null | grep -o "Function [^ ]* does not exist" | sort | uniq -c | sort -nr | head -20

echo ""
echo "### Most Common Pattern Match Issues:"
cat /tmp/dialyzer_analysis/*.txt 2>/dev/null | grep -A1 "pattern_match" | grep -v "^--$" | sort | uniq -c | sort -nr | head -10

echo ""
echo "### Files with Most Errors:"
cat /tmp/dialyzer_analysis/*.txt 2>/dev/null | grep "^lib/" | cut -d: -f1 | sort | uniq -c | sort -nr | head -20