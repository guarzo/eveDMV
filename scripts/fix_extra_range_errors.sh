#!/bin/bash
echo "=== Fixing Extra Range Errors ==="

# Fix 1: battle_service.ex - Remove rescue clauses that dialyzer says are unreachable
echo "Fixing battle_service.ex extra_range errors..."
# Line 176 - get_battle_statistics
sed -i '180s/{:ok, map()} | {:error, atom()}/{:ok, map()}/' /workspace/lib/eve_dmv/contexts/battle_analysis/services/battle_service.ex
# Remove the rescue clause (lines 196-197)
sed -i '196,197d' /workspace/lib/eve_dmv/contexts/battle_analysis/services/battle_service.ex

# Line 222 - get_character_battles
sed -i '227s/{:ok, \[Battle.t()\]} | {:error, atom()}/{:ok, [Battle.t()]}/' /workspace/lib/eve_dmv/contexts/battle_analysis/services/battle_service.ex

# Fix 2: character_intelligence.ex 
echo "Fixing character_intelligence.ex extra_range errors..."
# Line 150 - compare_character_threats spec
sed -i '150s/{:ok, \[{integer(), map()}\]} | {:error, atom()}/{:ok, [{integer(), map()}]}/' /workspace/lib/eve_dmv/contexts/character_intelligence.ex

# Line 170 - get_character_intelligence_report - this one actually can return error
# Leave it as is

# Lines 198/206 - These have no_return issues, need to check implementation
echo "Checking get_character_ship_intelligence implementation..."
sed -n '198,210p' /workspace/lib/eve_dmv/contexts/character_intelligence.ex

# Fix 3: combat_intelligence domain files
echo "Fixing combat_intelligence extra_range errors..."
# corporation_analyzer.ex
for line in 20 28 39 48 56; do
  sed -i "${line}s/{:ok, map()} | {:error, atom()}/{:ok, map()}/" /workspace/lib/eve_dmv/contexts/combat_intelligence/domain/corporation_analyzer.ex 2>/dev/null || true
done

# threat_assessor.ex  
for line in 20 28 39 48 61; do
  sed -i "${line}s/{:ok, map()} | {:error, atom()}/{:ok, map()}/" /workspace/lib/eve_dmv/contexts/combat_intelligence/domain/threat_assessor.ex 2>/dev/null || true
done

# intelligence_scoring.ex
echo "Checking intelligence_scoring.ex line 38..."
sed -n '35,40p' /workspace/lib/eve_dmv/contexts/combat_intelligence/domain/intelligence_scoring.ex

echo "Extra range fix complete!"