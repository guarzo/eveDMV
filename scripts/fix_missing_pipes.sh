#!/bin/bash
# Fix missing pipe operators in Elixir files

echo "Fixing missing pipe operators in Elixir files..."

# Function to fix missing pipes in a file
fix_pipes_in_file() {
    local file=$1
    local temp_file="${file}.tmp"
    
    # Create a backup
    cp "$file" "${file}.bak"
    
    # Fix patterns where lines start with function calls but are missing pipes
    # Pattern 1: Lines that start with |> (these are correct, skip them)
    # Pattern 2: Lines that start with Enum., Map., List., etc. after a line that doesn't end with certain characters
    
    awk '
    BEGIN { prev_line = "" }
    {
        # If current line starts with common module calls and previous line exists
        if (match($0, /^[[:space:]]*(Enum\.|Map\.|List\.|Keyword\.|String\.|MapSet\.|then\(|case |filter\(|Ash\.Query\.)/) && 
            prev_line != "" &&
            !match(prev_line, /(->|do|{|\||=|,|^[[:space:]]*$)$/)) {
            
            # Check if previous line already ends with |>
            if (!match(prev_line, /\|>[[:space:]]*$/)) {
                # Add pipe to current line
                sub(/^[[:space:]]*/, "&|> ", $0)
            }
        }
        
        # Special case for "then" function - it often follows a pipeline
        if (match($0, /^[[:space:]]*then\(/) && 
            prev_line != "" &&
            !match(prev_line, /(->|do|{|\||=|,|^[[:space:]]*$|\|>[[:space:]]*)$/)) {
            sub(/^[[:space:]]*/, "&|> ", $0)
        }
        
        print
        prev_line = $0
    }
    ' "$file" > "$temp_file"
    
    # Check if the file was modified
    if ! cmp -s "$file" "$temp_file"; then
        mv "$temp_file" "$file"
        echo "Fixed pipes in: $file"
        return 0
    else
        rm "$temp_file"
        rm "${file}.bak"
        return 1
    fi
}

# Fix specific files with parsing errors
files_to_fix=(
    "lib/eve_dmv/contexts/battle_analysis/domain/battle_metrics_calculator.ex"
    "lib/eve_dmv/analytics/battle_detector.ex"
    "lib/eve_dmv/analytics/battle_detector_fixed.ex"
    "lib/eve_dmv/contexts/battle_analysis/domain/combat_log_parser.ex"
    "lib/eve_dmv/contexts/combat_intelligence/domain/intelligence_scoring.ex"
    "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/phases/fleet_composition_analyzer.ex"
    "lib/eve_dmv/contexts/killmail_processing/domain/killmail_orchestrator.ex"
    "lib/eve_dmv/contexts/threat_assessment/analyzers/threat_analyzer.ex"
    "lib/eve_dmv/contexts/surveillance/matching/match_evaluator.ex"
    "lib/eve_dmv/surveillance/matching_engine.ex"
    "lib/eve_dmv/intelligence/analyzers/member_activity_data_collector.ex"
    "lib/eve_dmv/intelligence/analyzers/character_analyzer.ex"
    "lib/eve_dmv/intelligence/analyzers/corporation_analyzer.ex"
    "lib/eve_dmv/intelligence/analyzers/home_defense_analyzer.ex"
    "lib/eve_dmv/intelligence/analyzers/wh_vetting_analyzer.ex"
    "lib/eve_dmv/intelligence/core/intelligence_coordinator.ex"
    "lib/eve_dmv/intelligence/real_time_coordinator.ex"
    "lib/eve_dmv/contexts/battle_analysis/domain/participant_extractor.ex"
    "lib/eve_dmv/contexts/corporation_analysis/domain/corporation_analyzer.ex"
    "lib/eve_dmv/contexts/fleet_operations/domain/fleet_analyzer.ex"
    "lib/eve_dmv/contexts/market_intelligence/domain/valuation_service.ex"
    "lib/eve_dmv/contexts/player_profile/infrastructure/player_repository.ex"
    "lib/eve_dmv/contexts/surveillance/domain/chain_activity_tracker.ex"
    "lib/eve_dmv/contexts/wormhole_operations/domain/chain_intelligence_service.ex"
    "lib/eve_dmv/database/incremental_view_refresher.ex"
    "lib/eve_dmv/database/query_plan_analyzer/index_analyzer.ex"
    "lib/eve_dmv/database/surveillance_repository.ex"
    "lib/eve_dmv/eve/name_resolver.ex"
    "lib/eve_dmv/eve/name_resolver/esi_entity_resolver.ex"
    "lib/eve_dmv/killmails/killmail_processor.ex"
    "lib/eve_dmv/utils/fleet_utils.ex"
    "lib/eve_dmv/utils/surveillance_utils.ex"
    "lib/eve_dmv/contexts/character_intelligence/domain/threat_scoring_engine.ex"
    "lib/eve_dmv/contexts/character_intelligence/domain/threat_scoring/shared_calculations.ex"
    "lib/eve_dmv/contexts/character_intelligence/domain/threat_scoring/threat_scoring_coordinator.ex"
    "lib/eve_dmv/contexts/combat_intelligence/domain/shared/killmail_mapper.ex"
)

fixed_count=0
for file in "${files_to_fix[@]}"; do
    if [[ -f "$file" ]]; then
        if fix_pipes_in_file "$file"; then
            ((fixed_count++))
        fi
    else
        echo "Warning: File not found: $file"
    fi
done

echo "Fixed $fixed_count files with missing pipes"

# Now let's also fix some specific patterns that are common
echo -e "\nFixing specific missing pipe patterns..."

# Pattern: Variable followed by Enum/Map/List function on next line
find lib test -name "*.ex" -o -name "*.exs" | while read file; do
    # Skip backup files
    [[ "$file" == *.bak ]] && continue
    
    # Use perl for more complex pattern matching
    perl -i -pe '
        # If line ends with a variable/function call and next line starts with Enum/Map/List
        if (/^(.*)([a-zA-Z_][a-zA-Z0-9_]*(?:\([^)]*\))?)\s*$/ && !/(->|do|\||=|,)\s*$/) {
            $needs_pipe = 1;
            $indent = "";
            if ($1 =~ /^(\s*)/) {
                $indent = $1;
            }
        } elsif ($needs_pipe && /^(\s*)(Enum\.|Map\.|List\.|Keyword\.|String\.|MapSet\.)/) {
            $_ = "$1|> $_";
            $needs_pipe = 0;
        } else {
            $needs_pipe = 0;
        }
    ' "$file" 2>/dev/null || true
done

echo "Pipe operator fixing complete!"