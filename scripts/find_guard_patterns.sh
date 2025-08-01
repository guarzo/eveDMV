#!/bin/bash

echo "=== Finding potential guard failures ==="

# Look for guards with redundant conditions
echo "1. Redundant guard conditions:"
find lib/eve_dmv -name "*.ex" -exec grep -Hn "when.*>=.*and.*>=" {} \; | head -5

# Look for impossible guard combinations
echo -e "\n2. Potentially impossible guard combinations:"
find lib/eve_dmv -name "*.ex" -exec grep -Hn "when.*and.*and.*and" {} \; | head -5

# Look for guards that might always be true/false
echo -e "\n3. Complex guard patterns:"
find lib/eve_dmv -name "*.ex" -exec grep -Hn "when.*score.*and.*score.*and.*score" {} \; | head -5

# Look for guards with variable comparisons
echo -e "\n4. Variable comparison guards:"
find lib/eve_dmv -name "*.ex" -exec grep -Hn "when.*>.*and.*<" {} \; | head -10

echo -e "\n=== Files mentioned in the plan ==="
echo "Files to check based on plan:"
echo "- lib/eve_dmv/contexts/character_intelligence.ex:475-478"
echo "- lib/eve_dmv/contexts/battle_analysis/domain/strategic/trend_analyzer.ex:851,860"
echo "- lib/eve_dmv/contexts/battle_analysis/domain/tactical_pattern_detector.ex:844-846"
echo "- lib/eve_dmv/contexts/combat/core/fleet_composition_analyzer.ex:184"