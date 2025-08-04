#!/bin/bash

echo "Fixing Ash calls missing domain parameter..."

# Process specific files that are showing errors in dialyzer
files=(
    "/workspace/lib/eve_dmv/admin.ex"
    "/workspace/lib/eve_dmv/api.ex"
    "/workspace/lib/eve_dmv/contexts/character_intelligence.ex"
    "/workspace/lib/eve_dmv/contexts/character_intelligence/domain/data_fetchers/combat_data_fetcher.ex"
    "/workspace/lib/eve_dmv/contexts/character_intelligence/domain/engines/player_stats_engine.ex"
    "/workspace/lib/eve_dmv/contexts/character_intelligence/domain/generators/insight_generator.ex"
    "/workspace/lib/eve_dmv/contexts/character_intelligence/domain/threat_assessment.ex"
    "/workspace/lib/eve_dmv/contexts/character_intelligence/domain/threat_scoring_engine.ex"
    "/workspace/lib/eve_dmv/contexts/character_intelligence/domain/threat_scoring/shared_utilities.ex"
    "/workspace/lib/eve_dmv/contexts/battle_analysis/domain/battle_detection_service.ex"
    "/workspace/lib/eve_dmv/contexts/battle_analysis/domain/combat_log_helper.ex"
    "/workspace/lib/eve_dmv/contexts/battle_analysis/services/battle_service.ex"
    "/workspace/lib/eve_dmv/contexts/battle_analysis/services/battle_sharing_service.ex"
    "/workspace/lib/eve_dmv/contexts/battle_analysis/services/combat_log_service.ex"
    "/workspace/lib/eve_dmv/contexts/battle_analysis/core/battle_analyzer.ex"
    "/workspace/lib/eve_dmv/contexts/combat/resources/ship_fitting.ex"
    "/workspace/lib/eve_dmv/contexts/combat/services/battle_service.ex"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "Processing $file..."
        
        # First check if Api is aliased or imported
        if grep -q "alias EveDmv\.Api" "$file"; then
            # File has Api alias, we can safely replace
            
            # Fix Ash.read/2 with explicit domain
            sed -i 's/Ash\.read(\([^,)]*\), domain: EveDmv\.Api)/Api.read(\1)/g' "$file"
            sed -i 's/Ash\.read!(\([^,)]*\), domain: EveDmv\.Api)/Api.read!(\1)/g' "$file"
            
            # Fix Ash.create/3 with domain as third parameter
            sed -i 's/Ash\.create(\([^,]*\), \([^,]*\), domain: EveDmv\.Api)/Api.create(\1, \2)/g' "$file"
            
            # Fix Ash.get/3 with domain as third parameter
            sed -i 's/Ash\.get(\([^,]*\), \([^,]*\), domain: EveDmv\.Api)/Api.get(\1, \2)/g' "$file"
            
            # Fix Ash calls without any domain parameter - these need domain added
            # For admin.ex specifically
            if [[ "$file" == *"admin.ex" ]]; then
                sed -i 's/Ash\.read_one(\([^)]*\))/Api.read_one(\1)/g' "$file"
                sed -i 's/Ash\.read!(\([^)]*\))/Api.read!(\1)/g' "$file"
                sed -i 's/Ash\.count!(\([^)]*\))/Api.count!(\1)/g' "$file"
            fi
            
            # For api.ex specifically - these should use domain: __MODULE__
            if [[ "$file" == *"/api.ex" ]] && [[ "$file" != *"contexts/"* ]]; then
                sed -i 's/Ash\.read!(\([^,)]*\), \([^)]*\))/Ash.read!(\1, \2, domain: __MODULE__)/g' "$file"
                sed -i 's/Ash\.read(\([^,)]*\), \([^)]*\))/Ash.read(\1, \2, domain: __MODULE__)/g' "$file"
                sed -i 's/Ash\.create(\([^,)]*\), \([^,)]*\), \([^)]*\))/Ash.create(\1, \2, \3, domain: __MODULE__)/g' "$file"
                sed -i 's/Ash\.update(\([^,)]*\), \([^,)]*\), \([^)]*\))/Ash.update(\1, \2, \3, domain: __MODULE__)/g' "$file"
                sed -i 's/Ash\.destroy(\([^,)]*\), \([^)]*\))/Ash.destroy(\1, \2, domain: __MODULE__)/g' "$file"
                sed -i 's/Ash\.bulk_create(\([^,)]*\), \([^,)]*\), \([^,)]*\), \([^)]*\))/Ash.bulk_create(\1, \2, \3, \4, domain: __MODULE__)/g' "$file"
                sed -i 's/Ash\.get(\([^,)]*\), \([^,)]*\), \([^)]*\))/Ash.get(\1, \2, \3, domain: __MODULE__)/g' "$file"
                sed -i 's/Ash\.count(\([^,)]*\), \([^)]*\))/Ash.count(\1, \2, domain: __MODULE__)/g' "$file"
                sed -i 's/Ash\.read_one(\([^,)]*\), \([^)]*\))/Ash.read_one(\1, \2, domain: __MODULE__)/g' "$file"
                sed -i 's/Ash\.read_one!(\([^,)]*\), \([^)]*\))/Ash.read_one!(\1, \2, domain: __MODULE__)/g' "$file"
            fi
        fi
        
        # Check if it's a domain-specific API module that should delegate
        if [[ "$file" == *"/contexts/"*"/api.ex" ]]; then
            # These should have domain: __MODULE__
            sed -i 's/Ash\.read(\([^,)]*\), \([^)]*\))/Ash.read(\1, \2, domain: __MODULE__)/g' "$file"
            sed -i 's/Ash\.create(\([^,)]*\), \([^)]*\))/Ash.create(\1, \2, domain: __MODULE__)/g' "$file"
            sed -i 's/Ash\.update(\([^,)]*\), \([^)]*\))/Ash.update(\1, \2, domain: __MODULE__)/g' "$file"
            sed -i 's/Ash\.destroy(\([^,)]*\), \([^)]*\))/Ash.destroy(\1, \2, domain: __MODULE__)/g' "$file"
        fi
    fi
done

echo "Ash missing domain fixes complete!"