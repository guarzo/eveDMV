#!/bin/bash
echo "=== Fixing Workstream Delta Guard Fail Errors ==="

# Fix 1: battle_analyzer.ex lines 158-159 - Remove unnecessary || %{} guards
echo "Fixing battle_analyzer.ex guard fails..."
sed -i '158s/participants\.by_corporation || %{}/participants.by_corporation/' /workspace/lib/eve_dmv/contexts/battle_analysis/core/battle_analyzer.ex
sed -i '159s/participants\.by_alliance || %{}/participants.by_alliance/' /workspace/lib/eve_dmv/contexts/battle_analysis/core/battle_analyzer.ex

# Fix 2: battle_analyzer.ex line 580 - Change is_map to proper MapSet check
sed -i '580s/when is_map(all_chars)/when is_list(all_chars)/' /workspace/lib/eve_dmv/contexts/battle_analysis/core/battle_analyzer.ex
# Also fix the MapSet.size call to handle list
sed -i '581s/MapSet.size(all_chars)/length(all_chars)/' /workspace/lib/eve_dmv/contexts/battle_analysis/core/battle_analyzer.ex

# Fix 3: character_intelligence.ex lines 544-547 - Fix guard clauses
echo "Fixing character_intelligence.ex guard fails..."
# First, let's check what these lines contain
echo "Checking character_intelligence.ex lines 544-547..."
sed -n '544,547p' /workspace/lib/eve_dmv/contexts/character_intelligence.ex

# Fix 4: combat/core/performance_calculator.ex line 693
echo "Fixing performance_calculator.ex guard fail..."
sed -n '693p' /workspace/lib/eve_dmv/contexts/combat/core/performance_calculator.ex

# Fix 5: combat_intelligence/domain/battle_analysis/battle_comparison_engine.ex line 332
echo "Fixing battle_comparison_engine.ex guard fail..."
sed -n '332p' /workspace/lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/battle_comparison_engine.ex

# Fix 6: tactical_extractor.ex line 193
echo "Fixing tactical_extractor.ex guard fail..."
sed -n '193p' /workspace/lib/eve_dmv/contexts/combat_intelligence/domain/extractors/tactical_extractor.ex

# Fix 7: corporation/core/corporation_analyzer.ex line 308
echo "Fixing corporation_analyzer.ex guard fail..."
sed -n '308p' /workspace/lib/eve_dmv/contexts/corporation/core/corporation_analyzer.ex

# Fix 8: organizational_health_analyzer.ex lines 951-952, 1036, 1046, 1056
echo "Fixing organizational_health_analyzer.ex guard fails..."
sed -n '951,952p' /workspace/lib/eve_dmv/contexts/corporation/core/organizational_health_analyzer.ex
sed -n '1036p' /workspace/lib/eve_dmv/contexts/corporation/core/organizational_health_analyzer.ex
sed -n '1046p' /workspace/lib/eve_dmv/contexts/corporation/core/organizational_health_analyzer.ex
sed -n '1056p' /workspace/lib/eve_dmv/contexts/corporation/core/organizational_health_analyzer.ex

# Fix 9: corporation_intelligence.ex lines 616-618
echo "Fixing corporation_intelligence.ex guard fails..."
sed -n '616,618p' /workspace/lib/eve_dmv/contexts/corporation_intelligence.ex

echo "Guard fail investigation complete!"