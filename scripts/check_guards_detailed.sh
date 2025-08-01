#!/bin/bash

echo "=== Detailed Guard Analysis ==="

# Check specific files mentioned in the plan
echo "1. Checking character_intelligence.ex around line 475-478:"
grep -n -A5 -B5 "when.*and.*and" lib/eve_dmv/contexts/character_intelligence.ex | head -20

echo -e "\n2. Checking tactical_pattern_detector.ex around line 844-846:"
grep -n -A5 -B5 "when.*>=.*and.*>=.*and.*>=" lib/eve_dmv/contexts/battle_analysis/domain/tactical_pattern_detector.ex

echo -e "\n3. Checking fleet_composition_analyzer.ex around line 184:"
sed -n '180,190p' lib/eve_dmv/contexts/combat/core/fleet_composition_analyzer.ex | cat -n

echo -e "\n4. Looking for guards with multiple score comparisons:"
find lib/eve_dmv -name "*.ex" -exec grep -Hn "score.*>=.*score" {} \;

echo -e "\n5. Looking for guards that might always be true/false:"
find lib/eve_dmv -name "*.ex" -exec grep -Hn "when.*>=.*and.*<=.*and.*>=" {} \;

echo -e "\n6. Checking for impossible combinations:"
find lib/eve_dmv -name "*.ex" -exec grep -Hn "when.*>=.*and.*>=.*and.*>=.*and.*>=" {} \;