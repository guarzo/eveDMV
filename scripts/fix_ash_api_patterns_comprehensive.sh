#!/bin/bash

echo "Fixing comprehensive Ash API patterns across the codebase..."

# Find all Elixir files
files=$(find /workspace/lib -name "*.ex" -type f)

for file in $files; do
    if [ -f "$file" ]; then
        echo "Processing $file..."
        
        # Fix Ash.read/2 -> Api.read/1
        sed -i 's/Ash\.read(\([^,]*\), domain: Api)/Api.read(\1)/g' "$file"
        sed -i 's/Ash\.read(\([^,]*\), domain: __MODULE__)/read(\1)/g' "$file"
        
        # Fix Ash.read!/2 -> Api.read!/1
        sed -i 's/Ash\.read!(\([^,]*\), domain: Api)/Api.read!(\1)/g' "$file"
        sed -i 's/Ash\.read!(\([^,]*\), domain: __MODULE__)/read!(\1)/g' "$file"
        
        # Fix Ash.read_one/2 -> Api.read_one/1
        sed -i 's/Ash\.read_one(\([^,]*\), domain: Api)/Api.read_one(\1)/g' "$file"
        sed -i 's/Ash\.read_one(\([^,]*\), domain: __MODULE__)/read_one(\1)/g' "$file"
        
        # Fix Ash.read_one!/2 -> Api.read_one!/1
        sed -i 's/Ash\.read_one!(\([^,]*\), domain: Api)/Api.read_one!(\1)/g' "$file"
        sed -i 's/Ash\.read_one!(\([^,]*\), domain: __MODULE__)/read_one!(\1)/g' "$file"
        
        # Fix Ash.create/3 -> Api.create/2
        sed -i 's/Ash\.create(\([^,]*\), \([^,]*\), domain: Api)/Api.create(\1, \2)/g' "$file"
        sed -i 's/Ash\.create(\([^,]*\), \([^,]*\), domain: __MODULE__)/create(\1, \2)/g' "$file"
        
        # Fix Ash.update/3 -> Api.update/2
        sed -i 's/Ash\.update(\([^,]*\), \([^,]*\), domain: Api)/Api.update(\1, \2)/g' "$file"
        sed -i 's/Ash\.update(\([^,]*\), \([^,]*\), domain: __MODULE__)/update(\1, \2)/g' "$file"
        
        # Fix Ash.destroy/2 -> Api.destroy/1
        sed -i 's/Ash\.destroy(\([^,]*\), domain: Api)/Api.destroy(\1)/g' "$file"
        sed -i 's/Ash\.destroy(\([^,]*\), domain: __MODULE__)/destroy(\1)/g' "$file"
        
        # Fix Ash.get/3 -> Api.get/2
        sed -i 's/Ash\.get(\([^,]*\), \([^,]*\), domain: Api)/Api.get(\1, \2)/g' "$file"
        sed -i 's/Ash\.get(\([^,]*\), \([^,]*\), domain: __MODULE__)/get(\1, \2)/g' "$file"
        
        # Fix Ash.count/2 -> Api.count/1
        sed -i 's/Ash\.count(\([^,]*\), domain: Api)/Api.count(\1)/g' "$file"
        sed -i 's/Ash\.count!(\([^,]*\), domain: Api)/Api.count!(\1)/g' "$file"
        
        # Fix Ash.bulk_create/4 -> Api.bulk_create/3
        sed -i 's/Ash\.bulk_create(\([^,]*\), \([^,]*\), \([^,]*\), domain: Api)/Api.bulk_create(\1, \2, \3)/g' "$file"
        
        # Fix Ash.Query.do_filter/2 -> Ash.Query.filter/2
        sed -i 's/Ash\.Query\.do_filter/Ash.Query.filter/g' "$file"
        
        # Fix standalone Ash calls without domain (most likely should use Api)
        # Only if the file already imports or aliases Api
        if grep -q "alias EveDmv\.Api" "$file" || grep -q "import EveDmv\.Api" "$file"; then
            # Fix standalone Ash.read!/1
            sed -i 's/\bAsh\.read!(\([^)]*\))/Api.read!(\1)/g' "$file"
            
            # Fix standalone Ash.read/1
            sed -i 's/\bAsh\.read(\([^)]*\))/Api.read(\1)/g' "$file"
            
            # Fix standalone Ash.read_one/1
            sed -i 's/\bAsh\.read_one(\([^)]*\))/Api.read_one(\1)/g' "$file"
            
            # Fix standalone Ash.create/1
            sed -i 's/\bAsh\.create(\([^)]*\))/Api.create(\1)/g' "$file"
            
            # Fix standalone Ash.create/2
            sed -i 's/\bAsh\.create(\([^,]*\), \([^)]*\))/Api.create(\1, \2)/g' "$file"
            
            # Fix standalone Ash.update/2
            sed -i 's/\bAsh\.update(\([^,]*\), \([^)]*\))/Api.update(\1, \2)/g' "$file"
        fi
    fi
done

echo "Comprehensive Ash API pattern fixes complete!"