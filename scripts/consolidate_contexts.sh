#!/bin/bash

# Script to consolidate overlapping contexts after migration

echo "Consolidating overlapping contexts..."

# Directories that will be consolidated
COMBAT_CONTEXTS=(
  "lib/eve_dmv/contexts/combat_intelligence/"
  "lib/eve_dmv/contexts/battle_sharing/"
  "lib/eve_dmv/contexts/battle_analysis/"
)

THREAT_CONTEXTS=(
  "lib/eve_dmv/contexts/surveillance/"
  "lib/eve_dmv/contexts/threat_assessment/"
)

# Context files that will be replaced
OLD_CONTEXT_FILES=(
  "lib/eve_dmv/contexts/combat_intelligence.ex"
  "lib/eve_dmv/contexts/battle_sharing.ex"
  "lib/eve_dmv/contexts/battle_analysis.ex"
  "lib/eve_dmv/contexts/surveillance.ex"
)

echo "=== CONTEXT CONSOLIDATION PLAN ==="
echo ""
echo "Combat Analysis Consolidation:"
echo "  ✓ CombatIntelligence + BattleSharing + BattleAnalysis → CombatAnalysis"
echo "  ✓ New unified context: lib/eve_dmv/contexts/combat_analysis.ex"
echo ""
echo "Threat Surveillance Consolidation:"
echo "  ✓ Surveillance + ThreatAssessment → ThreatSurveillance"  
echo "  ✓ New unified context: lib/eve_dmv/contexts/threat_surveillance.ex"
echo ""

# Show which directories will be archived
echo "Directories that will be archived (not deleted):"
for dir in "${COMBAT_CONTEXTS[@]}" "${THREAT_CONTEXTS[@]}"; do
  if [ -d "$dir" ]; then
    echo "  📁 $dir → ${dir%./}_archived/"
  fi
done

echo ""
echo "Context files that will be replaced:"
for file in "${OLD_CONTEXT_FILES[@]}"; do
  if [ -f "$file" ]; then
    echo "  📄 $file → ${file%.ex}_archived.ex"
  else
    echo "  ✗ $file (not found)"
  fi
done

echo ""
read -p "Do you want to proceed with context consolidation? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "Proceeding with context consolidation..."
  
  # Create archive directory
  mkdir -p lib/eve_dmv/contexts/_archived
  
  # Archive combat contexts
  echo ""
  echo "📦 Archiving combat contexts..."
  for dir in "${COMBAT_CONTEXTS[@]}"; do
    if [ -d "$dir" ]; then
      dirname=$(basename "$dir")
      mv "$dir" "lib/eve_dmv/contexts/_archived/${dirname}_archived"
      echo "  Archived: $dir → lib/eve_dmv/contexts/_archived/${dirname}_archived"
    fi
  done
  
  # Archive threat contexts  
  echo ""
  echo "📦 Archiving threat contexts..."
  for dir in "${THREAT_CONTEXTS[@]}"; do
    if [ -d "$dir" ]; then
      dirname=$(basename "$dir") 
      mv "$dir" "lib/eve_dmv/contexts/_archived/${dirname}_archived"
      echo "  Archived: $dir → lib/eve_dmv/contexts/_archived/${dirname}_archived"
    fi
  done
  
  # Archive old context files
  echo ""
  echo "📦 Archiving old context files..."
  for file in "${OLD_CONTEXT_FILES[@]}"; do
    if [ -f "$file" ]; then
      filename=$(basename "$file" .ex)
      mv "$file" "lib/eve_dmv/contexts/_archived/${filename}_archived.ex"
      echo "  Archived: $file → lib/eve_dmv/contexts/_archived/${filename}_archived.ex"
    fi
  done
  
  echo ""
  echo "✅ Context consolidation completed!"
  echo ""
  echo "New unified contexts created:"
  echo "  🎯 lib/eve_dmv/contexts/combat_analysis.ex"
  echo "  🎯 lib/eve_dmv/contexts/threat_surveillance.ex"
  echo ""
  echo "Archived contexts available in:"
  echo "  📁 lib/eve_dmv/contexts/_archived/"
  echo ""
  echo "Next steps:"
  echo "1. Update application.ex to use new unified contexts"
  echo "2. Run 'mix compile' to check for any remaining references"
  echo "3. Update any code that references old contexts"
  echo "4. Run 'mix test' to ensure all tests pass"
  echo "5. Create domain services for the new unified contexts"
  
else
  echo "Context consolidation cancelled."
fi