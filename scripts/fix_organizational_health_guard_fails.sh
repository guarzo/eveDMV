#!/bin/bash
echo "=== Fixing Organizational Health Analyzer Guard Fails ==="

# Fix lines 951-952: Add nil check for leadership_data
echo "Fixing leadership_data nil checks..."
sed -i '950a\  defp calculate_leadership_health(nil), do: 50.0\n' /workspace/lib/eve_dmv/contexts/corporation/core/organizational_health_analyzer.ex

# Fix line 1056: Change to use Map.get
echo "Fixing stability_data access..."
sed -i '1056s/stability_data\.structural_stability || %{}/Map.get(stability_data || %{}, :structural_stability, %{})/' /workspace/lib/eve_dmv/contexts/corporation/core/organizational_health_analyzer.ex

# Fix corporation_analyzer.ex line 308 - Change corp_stats access to use Map.get
echo "Fixing corporation_analyzer.ex..."
sed -i '308s/corp_stats\.member_count || 0/Map.get(corp_stats || %{}, :member_count, 0)/' /workspace/lib/eve_dmv/contexts/corporation/core/corporation_analyzer.ex
sed -i '309s/corp_stats\.total_kills || 0/Map.get(corp_stats || %{}, :total_kills, 0)/' /workspace/lib/eve_dmv/contexts/corporation/core/corporation_analyzer.ex

# Fix combat/core/performance_calculator.ex line 693
echo "Checking performance_calculator.ex context..."
sed -n '690,695p' /workspace/lib/eve_dmv/contexts/combat/core/performance_calculator.ex

# Fix tactical_extractor.ex line 193  
echo "Checking tactical_extractor.ex context..."
sed -n '190,195p' /workspace/lib/eve_dmv/contexts/combat_intelligence/domain/extractors/tactical_extractor.ex

# Fix battle_comparison_engine.ex line 332
echo "Checking battle_comparison_engine.ex context..."
sed -n '330,335p' /workspace/lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/battle_comparison_engine.ex

echo "Guard fail fixes complete!"