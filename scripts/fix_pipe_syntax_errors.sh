#!/bin/bash

echo "Fixing pipe syntax errors..."

# Fix broken pipes that were over-aggressively changed
files_to_fix=(
    "lib/eve_dmv/analytics/player_stats_engine.ex"
    "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/analyzers/doctrine_analyzer.ex"
    "lib/eve_dmv/contexts/corporation_intelligence/analyzers/doctrine_classification_engine.ex"
    "lib/eve_dmv/contexts/wormhole_operations/domain/mass_optimizer.ex"
    "lib/eve_dmv/static_data.ex"
    "lib/eve_dmv/contexts/character_intelligence/domain/threat_scoring/threat_scoring_coordinator.ex"
    "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis_service.ex"
)

for file in "${files_to_fix[@]}"; do
    if [[ -f "$file" ]]; then
        echo "Fixing $file"
        
        # Fix pipe operators that got broken
        # Pattern: |>       Enum -> |> Enum  
        sed -i 's/|>\s*Enum/|> Enum/g' "$file"
        sed -i 's/|>\s*Map/|> Map/g' "$file"
        sed -i 's/|>\s*String/|> String/g' "$file"
        sed -i 's/|>\s*Keyword/|> Keyword/g' "$file"
        sed -i 's/|>\s*DateTime/|> DateTime/g' "$file"
        
        # Fix missing pipes that were removed
        sed -i '/Enum\.map/s/^\(\s*\)\([^|]*\)\(\s*\)Enum\.map/\1\2\3|> Enum.map/' "$file"
        sed -i '/Enum\.filter/s/^\(\s*\)\([^|]*\)\(\s*\)Enum\.filter/\1\2\3|> Enum.filter/' "$file"
        sed -i '/Enum\.reduce/s/^\(\s*\)\([^|]*\)\(\s*\)Enum\.reduce/\1\2\3|> Enum.reduce/' "$file"
        sed -i '/Enum\.sort_by/s/^\(\s*\)\([^|]*\)\(\s*\)Enum\.sort_by/\1\2\3|> Enum.sort_by/' "$file"
        sed -i '/Enum\.uniq/s/^\(\s*\)\([^|]*\)\(\s*\)Enum\.uniq/\1\2\3|> Enum.uniq/' "$file"
        sed -i '/Enum\.take/s/^\(\s*\)\([^|]*\)\(\s*\)Enum\.take/\1\2\3|> Enum.take/' "$file"
        sed -i '/Enum\.frequencies/s/^\(\s*\)\([^|]*\)\(\s*\)Enum\.frequencies/\1\2\3|> Enum.frequencies/' "$file"
    fi
done

echo "Pipe syntax errors fixed!"