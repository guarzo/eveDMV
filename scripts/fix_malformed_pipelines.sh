#!/bin/bash
# Fix malformed pipeline syntax introduced by automated fixes

echo "🔧 Fixing malformed pipeline syntax..."

# Create backup
backup_dir="backup_malformed_fix_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$backup_dir"

# List of files with issues
files=(
    "lib/eve_dmv/contexts/corporation_analysis/analyzers/participation_analyzer.ex"
    "lib/eve_dmv/contexts/battle_analysis/domain/ship_performance_analyzer.ex"
    "lib/eve_dmv/contexts/battle_analysis/domain/enhanced_combat_log_parser.ex"
    "lib/eve_dmv/contexts/character_intelligence/domain/threat_scoring/engines/gang_effectiveness_engine.ex"
    "lib/eve_dmv/contexts/combat_intelligence/domain/ewar_analyzer.ex"
    "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/analyzers/side_determination_engine.ex"
    "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/analyzers/battle_comparison_engine.ex"
    "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/phases/timeline_analyzer.ex"
    "lib/eve_dmv/contexts/intelligence_infrastructure/domain/cross_system/analyzers/constellation_analyzer.ex"
    "lib/eve_dmv/contexts/intelligence_infrastructure/domain/cross_system/cross_system_coordinator.ex"
    "lib/eve_dmv/contexts/intelligence_infrastructure/domain/cross_system/correlators/activity_correlator.ex"
    "lib/eve_dmv/contexts/intelligence_infrastructure/domain/cross_system/correlators/threat_correlator.ex"
    "lib/eve_dmv/contexts/battle_sharing/domain/tactical_highlight_manager.ex"
    "lib/eve_dmv/contexts/battle_sharing/domain/battle_curator.ex"
    "lib/eve_dmv/intelligence/analyzers/wh_vetting_analyzer.ex"
    "lib/eve_dmv/eve/static_data_loader/item_type_processor.ex"
    "lib/eve_dmv/database/cache_warmer.ex"
)

for file in "${files[@]}"; do
    if [[ -f "$file" ]]; then
        echo "Processing: $file"
        
        # Create backup
        cp "$file" "$backup_dir/$(basename "$file")_$(date +%H%M%S)"
        
        # Fix malformed patterns using sed
        # Pattern: |> & &1.field |> Enum.map Enum.function()
        # Fix to: |> Enum.map(& &1.field) |> Enum.function()
        
        sed -i 's/|> & &1\.\([a-zA-Z_][a-zA-Z0-9_]*\) |> Enum\.map Enum\.\([a-zA-Z_][a-zA-Z0-9_]*\)()/|> Enum.map(\& \&1.\1) |> Enum.\2()/g' "$file"
        
        # Pattern: |> & &1.field |> Enum.map Enum.function
        # Fix to: |> Enum.map(& &1.field) |> Enum.function
        sed -i 's/|> & &1\.\([a-zA-Z_][a-zA-Z0-9_]*\) |> Enum\.map Enum\.\([a-zA-Z_][a-zA-Z0-9_]*\)/|> Enum.map(\& \&1.\1) |> Enum.\2/g' "$file"
        
        # Pattern: |> & &1.field |> Enum.map
        # Fix to: |> Enum.map(& &1.field)
        sed -i 's/|> & &1\.\([a-zA-Z_][a-zA-Z0-9_]*\) |> Enum\.map/|> Enum.map(\& \&1.\1)/g' "$file"
        
        echo "  Fixed malformed patterns in $file"
    fi
done

echo "✅ Malformed pipeline syntax fixes complete"
echo "Backup directory: $backup_dir"

# Test compilation
echo "🔍 Testing compilation..."
if mix compile > /dev/null 2>&1; then
    echo "✅ Compilation successful"
else
    echo "❌ Compilation issues remain"
fi