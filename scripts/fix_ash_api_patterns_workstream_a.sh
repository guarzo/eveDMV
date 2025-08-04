#!/bin/bash
# Workstream A: Fix Ash API patterns in core infrastructure files

echo "Fixing Ash API patterns in Workstream A directories..."

# Define directories for Workstream A
directories=(
    "/workspace/lib/eve_dmv/platform/"
    "/workspace/lib/eve_dmv/external/"
    "/workspace/lib/eve_dmv/cache/"
    "/workspace/lib/eve_dmv/*.ex"
)

# Also fix files found in the grep search
specific_files=(
    "/workspace/lib/eve_dmv/search/search_suggestion_service.ex"
    "/workspace/lib/eve_dmv/contexts/fleet_operations/domain/analyzers/fleet_pilot_analyzer.ex"
    "/workspace/lib/eve_dmv/contexts/character_intelligence.ex"
    "/workspace/lib/eve_dmv/contexts/surveillance/domain/chain_analysis/system_inhabitants_manager.ex"
    "/workspace/lib/eve_dmv/contexts/surveillance/domain/chain_analysis/chain_data_sync.ex"
    "/workspace/lib/eve_dmv/contexts/surveillance/domain/chain_analysis/chain_event_handlers.ex"
)

# Function to fix Ash patterns in a file
fix_file() {
    local file="$1"
    if [ -f "$file" ]; then
        echo "Processing $file..."
        
        # Fix Ash.read patterns
        sed -i 's/Ash\.read(\([^,]*\), domain: Api)/Api.read(\1)/g' "$file"
        sed -i 's/Ash\.read!(\([^,]*\), domain: Api)/Api.read!(\1)/g' "$file"
        
        # Fix Ash.create patterns
        sed -i 's/Ash\.create(\([^,]*\), \([^,]*\), domain: Api)/Api.create(\1, \2)/g' "$file"
        sed -i 's/Ash\.create!(\([^,]*\), \([^,]*\), domain: Api)/Api.create!(\1, \2)/g' "$file"
        
        # Fix Ash.update patterns
        sed -i 's/Ash\.update(\([^,]*\), \([^,]*\), domain: Api)/Api.update(\1, \2)/g' "$file"
        sed -i 's/Ash\.update!(\([^,]*\), \([^,]*\), domain: Api)/Api.update!(\1, \2)/g' "$file"
        
        # Fix Ash.destroy patterns
        sed -i 's/Ash\.destroy(\([^,]*\), domain: Api)/Api.destroy(\1)/g' "$file"
        sed -i 's/Ash\.destroy!(\([^,]*\), domain: Api)/Api.destroy!(\1)/g' "$file"
        
        # Fix Ash.get patterns
        sed -i 's/Ash\.get(\([^,]*\), \([^,]*\), domain: Api)/Api.get(\1, \2)/g' "$file"
        sed -i 's/Ash\.get!(\([^,]*\), \([^,]*\), domain: Api)/Api.get!(\1, \2)/g' "$file"
        
        # Fix Ash.bulk_create patterns
        sed -i 's/Ash\.bulk_create(\([^,]*\), \([^,]*\), \([^,]*\), domain: Api)/Api.bulk_create(\1, \2, \3)/g' "$file"
        
        # Fix Ash.bulk_update patterns
        sed -i 's/Ash\.bulk_update(\([^,]*\), \([^,]*\), \([^,]*\), domain: Api)/Api.bulk_update(\1, \2, \3)/g' "$file"
        
        # Fix Ash.count patterns
        sed -i 's/Ash\.count(\([^,]*\), domain: Api)/Api.count(\1)/g' "$file"
        sed -i 's/Ash\.count!(\([^,]*\), domain: Api)/Api.count!(\1)/g' "$file"
        
        # Fix Ash.exists? patterns
        sed -i 's/Ash\.exists?(\([^,]*\), domain: Api)/Api.exists?(\1)/g' "$file"
        
        # Fix Ash.load patterns
        sed -i 's/Ash\.load(\([^,]*\), \([^,]*\), domain: Api)/Api.load(\1, \2)/g' "$file"
        sed -i 's/Ash\.load!(\([^,]*\), \([^,]*\), domain: Api)/Api.load!(\1, \2)/g' "$file"
        
        # Fix Ash.page patterns
        sed -i 's/Ash\.page(\([^,]*\), \([^,]*\), domain: Api)/Api.page(\1, \2)/g' "$file"
        sed -i 's/Ash\.page!(\([^,]*\), \([^,]*\), domain: Api)/Api.page!(\1, \2)/g' "$file"
        
        # Fix Ash.run_action patterns
        sed -i 's/Ash\.run_action(\([^,]*\), \([^,]*\), domain: Api)/Api.run_action(\1, \2)/g' "$file"
        sed -i 's/Ash\.run_action!(\([^,]*\), \([^,]*\), domain: Api)/Api.run_action!(\1, \2)/g' "$file"
        
        # Fix Ash.read_one patterns
        sed -i 's/Ash\.read_one(\([^,]*\), domain: Api)/Api.read_one(\1)/g' "$file"
        sed -i 's/Ash\.read_one!(\([^,]*\), domain: Api)/Api.read_one!(\1)/g' "$file"
    fi
}

# Fix specific files first
for file in "${specific_files[@]}"; do
    fix_file "$file"
done

# Process directories
for dir in "${directories[@]}"; do
    if [[ "$dir" == *"*.ex" ]]; then
        # Handle glob pattern for root directory files
        for file in $dir; do
            if [ -f "$file" ]; then
                fix_file "$file"
            fi
        done
    else
        # Find all .ex files in directory
        find "$dir" -name "*.ex" -type f 2>/dev/null | while read -r file; do
            fix_file "$file"
        done
    fi
done

echo "Ash API pattern fixes complete for Workstream A!"
echo ""
echo "Files that were modified:"
git status --porcelain | grep "^ M" | grep -E "(platform/|external/|cache/|search/|surveillance/|character_intelligence\.ex|fleet_operations/)" | wc -l
echo ""
echo "Next steps:"
echo "1. Run 'mix compile --warnings-as-errors' to verify compilation"
echo "2. Run dialyzer on specific modules to check error reduction"
echo "3. Commit changes with message: 'fix(dialyzer): resolve Ash API patterns in Workstream A'"