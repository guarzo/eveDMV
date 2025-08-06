#!/bin/bash
echo "=== Fixing Invalid Contract Errors ==="

# Fix 1: battle_analysis.ex - Remove type aliases and use map()
echo "Fixing battle_analysis.ex invalid contracts..."
# Line 132 - reconstruct_battle_timeline
sed -i '132s/@spec reconstruct_battle_timeline(battle()) :: battle_timeline()/@spec reconstruct_battle_timeline(map()) :: map()/' /workspace/lib/eve_dmv/contexts/battle_analysis.ex

# Line 142 - analyze_battle_sequence  
sed -i '142s/@spec analyze_battle_sequence(\[battle()\]) :: battle_sequence_analysis()/@spec analyze_battle_sequence([map()]) :: map()/' /workspace/lib/eve_dmv/contexts/battle_analysis.ex

# Fix 2: character_intelligence.ex
echo "Fixing character_intelligence.ex invalid contracts..."
# These seem to actually match their types, so let's check the actual issue
grep -n "analyze_character_threat" /workspace/lib/eve_dmv/contexts/character_intelligence.ex | head -5

# Fix 3: combat_intelligence/api.ex
echo "Fixing combat_intelligence/api.ex..."
for line in 67 82 94 106 238; do
  echo "Checking line $line in combat_intelligence/api.ex"
  sed -n "${line}p" /workspace/lib/eve_dmv/contexts/combat_intelligence/api.ex
done

# Fix 4: external_group_analyzer.ex
echo "Fixing external_group_analyzer.ex..."
sed -n '14p' /workspace/lib/eve_dmv/contexts/combat_intelligence/domain/external_group_analyzer.ex

# Fix 5: analysis_cache.ex 
echo "Fixing analysis_cache.ex..."
sed -n '211p' /workspace/lib/eve_dmv/contexts/combat_intelligence/infrastructure/analysis_cache.ex

echo "Invalid contract investigation complete!"