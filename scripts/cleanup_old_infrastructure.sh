#!/bin/bash

# Script to clean up old infrastructure files after unified infrastructure migration

echo "Cleaning up old infrastructure files..."

# Files to remove (now replaced by unified infrastructure)
OLD_INFRASTRUCTURE_FILES=(
  "lib/eve_dmv/contexts/market_intelligence/infrastructure/price_cache.ex"
  "lib/eve_dmv/contexts/threat_assessment/infrastructure/threat_cache.ex"
  "lib/eve_dmv/contexts/combat_intelligence/infrastructure/analysis_cache.ex"
  "lib/eve_dmv/contexts/surveillance/infrastructure/match_cache.ex"
  "lib/eve_dmv/contexts/corporation_analysis/infrastructure/analysis_cache.ex"
  "lib/eve_dmv/contexts/surveillance/infrastructure/killmail_event_processor.ex"
  "lib/eve_dmv/contexts/combat_intelligence/infrastructure/killmail_event_processor.ex"
  "lib/eve_dmv/contexts/threat_assessment/infrastructure/threat_repository.ex"
  "lib/eve_dmv/contexts/fleet_operations/infrastructure/fleet_repository.ex"
  "lib/eve_dmv/contexts/corporation_analysis/infrastructure/corporation_repository.ex"
  "lib/eve_dmv/contexts/player_profile/infrastructure/player_repository.ex"
)

# Check which files exist and show what will be removed
echo "Files that will be removed:"
for file in "${OLD_INFRASTRUCTURE_FILES[@]}"; do
  if [ -f "$file" ]; then
    echo "  ✓ $file"
  else
    echo "  ✗ $file (not found)"
  fi
done

# Ask for confirmation
echo ""
read -p "Do you want to proceed with removing these files? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "Removing old infrastructure files..."
  
  for file in "${OLD_INFRASTRUCTURE_FILES[@]}"; do
    if [ -f "$file" ]; then
      rm "$file"
      echo "  Removed: $file"
    fi
  done
  
  echo ""
  echo "✅ Old infrastructure files removed successfully!"
  echo ""
  echo "Next steps:"
  echo "1. Run 'mix compile' to check for any remaining references"
  echo "2. Run 'mix test' to ensure all tests pass"
  echo "3. Update any remaining references to use unified infrastructure"
else
  echo "Cleanup cancelled."
fi