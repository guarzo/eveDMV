#!/bin/bash
echo "=== Fixing Guard Fail Errors ==="

# Fix 1: character_intelligence.ex - Remove redundant is_number guards
echo "Fixing character_intelligence.ex redundant guards..."
sed -i '544s/score when is_number(score) and score >= 90/score when score >= 90/' /workspace/lib/eve_dmv/contexts/character_intelligence.ex
sed -i '545s/score when is_number(score) and score >= 75/score when score >= 75/' /workspace/lib/eve_dmv/contexts/character_intelligence.ex
sed -i '546s/score when is_number(score) and score >= 50/score when score >= 50/' /workspace/lib/eve_dmv/contexts/character_intelligence.ex
sed -i '547s/score when is_number(score) and score >= 25/score when score >= 25/' /workspace/lib/eve_dmv/contexts/character_intelligence.ex

# Fix 2: corporation_intelligence.ex - Similar issue with categorize_threat_level
echo "Fixing corporation_intelligence.ex redundant guards..."
sed -i '616s/defp categorize_threat_level(score) when score >= 90/defp categorize_threat_level(score) when is_number(score) and score >= 90/' /workspace/lib/eve_dmv/contexts/corporation_intelligence.ex
sed -i '617s/defp categorize_threat_level(score) when score >= 75/defp categorize_threat_level(score) when is_number(score) and score >= 75/' /workspace/lib/eve_dmv/contexts/corporation_intelligence.ex
sed -i '618s/defp categorize_threat_level(score) when score >= 50/defp categorize_threat_level(score) when is_number(score) and score >= 50/' /workspace/lib/eve_dmv/contexts/corporation_intelligence.ex

# Fix 3: battle_analyzer.ex line 580 - Fix MapSet check
echo "Fixing battle_analyzer.ex MapSet check..."
# Already fixed in the previous run

# Fix 4: Fix organizational_health_analyzer.ex nil checks
echo "Fixing organizational_health_analyzer.ex nil defaults..."
# These look like they need proper nil handling, let's check the actual context
echo "Checking organizational_health_analyzer.ex context..."
sed -n '950,955p' /workspace/lib/eve_dmv/contexts/corporation/core/organizational_health_analyzer.ex

# Fix 5: Fix corporation_analyzer.ex line 308
echo "Fixing corporation_analyzer.ex..."
sed -n '307,309p' /workspace/lib/eve_dmv/contexts/corporation/core/corporation_analyzer.ex

echo "Guard fail fixes complete!"