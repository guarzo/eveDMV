#!/bin/bash
echo "Fixing Ash API patterns in Workstream E files..."

# Get all files in Workstream E directories
files=$(find /workspace/lib/eve_dmv/contexts/wormhole_operations \
             /workspace/lib/eve_dmv/contexts/corporation* \
             /workspace/lib/eve_dmv/contexts/fleet_operations \
             -name "*.ex" -type f)

echo "Found $(echo "$files" | wc -l) files to process"

# Apply the systematic Ash API pattern fixes
for file in $files; do
  if [ -f "$file" ]; then
    echo "Processing $file"
    
    # Fix the main Ash API patterns with domain parameter
    # Handle multi-parameter versions first (to avoid partial replacements)
    sed -i 's/Ash\.bulk_create(\([^,]*\), \([^,]*\), \([^,]*\), domain: \([^)]*\))/\4.bulk_create(\1, \2, \3)/g' "$file"
    sed -i 's/Ash\.bulk_update(\([^,]*\), \([^,]*\), \([^,]*\), domain: \([^)]*\))/\4.bulk_update(\1, \2, \3)/g' "$file"
    sed -i 's/Ash\.create(\([^,]*\), \([^,]*\), domain: \([^)]*\))/\3.create(\1, \2)/g' "$file"
    sed -i 's/Ash\.update(\([^,]*\), \([^,]*\), domain: \([^)]*\))/\3.update(\1, \2)/g' "$file"
    sed -i 's/Ash\.get(\([^,]*\), \([^,]*\), domain: \([^)]*\))/\3.get(\1, \2)/g' "$file"
    sed -i 's/Ash\.load(\([^,]*\), \([^,]*\), domain: \([^)]*\))/\3.load(\1, \2)/g' "$file"
    sed -i 's/Ash\.page(\([^,]*\), \([^,]*\), domain: \([^)]*\))/\3.page(\1, \2)/g' "$file"
    sed -i 's/Ash\.run_action(\([^,]*\), \([^,]*\), domain: \([^)]*\))/\3.run_action(\1, \2)/g' "$file"
    sed -i 's/Ash\.bulk_destroy(\([^,]*\), \([^,]*\), domain: \([^)]*\))/\3.bulk_destroy(\1, \2)/g' "$file"
    
    # Single parameter versions
    sed -i 's/Ash\.read(\([^,]*\), domain: \([^)]*\))/\2.read(\1)/g' "$file"
    sed -i 's/Ash\.read!(\([^,]*\), domain: \([^)]*\))/\2.read!(\1)/g' "$file"
    sed -i 's/Ash\.read_one(\([^,]*\), domain: \([^)]*\))/\2.read_one(\1)/g' "$file"
    sed -i 's/Ash\.read_one!(\([^,]*\), domain: \([^)]*\))/\2.read_one!(\1)/g' "$file"
    sed -i 's/Ash\.destroy(\([^,]*\), domain: \([^)]*\))/\2.destroy(\1)/g' "$file"
    sed -i 's/Ash\.destroy!(\([^,]*\), domain: \([^)]*\))/\2.destroy!(\1)/g' "$file"
    sed -i 's/Ash\.count(\([^,]*\), domain: \([^)]*\))/\2.count(\1)/g' "$file"
    sed -i 's/Ash\.count!(\([^,]*\), domain: \([^)]*\))/\2.count!(\1)/g' "$file"
    sed -i 's/Ash\.exists(\([^,]*\), domain: \([^)]*\))/\2.exists(\1)/g' "$file"
    sed -i 's/Ash\.exists?(\([^,]*\), domain: \([^)]*\))/\2.exists?(\1)/g' "$file"
    
    # Fix cases where EveDmv.Api is used
    sed -i 's/EveDmv\.Api\.bulk_create/Api.bulk_create/g' "$file"
    sed -i 's/EveDmv\.Api\.bulk_update/Api.bulk_update/g' "$file"
    sed -i 's/EveDmv\.Api\.bulk_destroy/Api.bulk_destroy/g' "$file"
  fi
done

echo "Completed fixing Ash API patterns in Workstream E files"