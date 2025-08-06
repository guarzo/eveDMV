#!/bin/bash

# Script to fix Ash framework calls throughout the codebase
# Converts Ash.method(..., domain: Api) to Api.method(...)

echo "Fixing Ash framework calls..."

# Function to fix Ash calls in a file
fix_ash_calls() {
    local file="$1"
    
    # Skip if file doesn't exist
    [ ! -f "$file" ] && return
    
    # Create backup
    cp "$file" "$file.bak"
    
    # Fix Ash.create/update/read/destroy/get calls with domain parameter
    sed -i -E 's/Ash\.create\(([^,]+), ([^,]+), domain: ([A-Za-z0-9\.]+)\)/\3.create(\1, \2)/g' "$file"
    sed -i -E 's/Ash\.create!\(([^,]+), ([^,]+), domain: ([A-Za-z0-9\.]+)\)/\3.create!(\1, \2)/g' "$file"
    sed -i -E 's/Ash\.create\(([^)]+), domain: ([A-Za-z0-9\.]+)\)/\2.create(\1)/g' "$file"
    sed -i -E 's/Ash\.create!\(([^)]+), domain: ([A-Za-z0-9\.]+)\)/\2.create!(\1)/g' "$file"
    sed -i -E 's/Ash\.create\(domain: ([A-Za-z0-9\.]+)\)/\1.create()/g' "$file"
    sed -i -E 's/Ash\.create!\(domain: ([A-Za-z0-9\.]+)\)/\1.create!()/g' "$file"
    
    sed -i -E 's/Ash\.update\(([^,]+), ([^,]+), domain: ([A-Za-z0-9\.]+)\)/\3.update(\1, \2)/g' "$file"
    sed -i -E 's/Ash\.update!\(([^,]+), ([^,]+), domain: ([A-Za-z0-9\.]+)\)/\3.update!(\1, \2)/g' "$file"
    sed -i -E 's/Ash\.update\(([^)]+), domain: ([A-Za-z0-9\.]+)\)/\2.update(\1)/g' "$file"
    sed -i -E 's/Ash\.update!\(([^)]+), domain: ([A-Za-z0-9\.]+)\)/\2.update!(\1)/g' "$file"
    sed -i -E 's/Ash\.update\(domain: ([A-Za-z0-9\.]+)\)/\1.update()/g' "$file"
    sed -i -E 's/Ash\.update!\(domain: ([A-Za-z0-9\.]+)\)/\1.update!()/g' "$file"
    
    sed -i -E 's/Ash\.read\(([^,]+), domain: ([A-Za-z0-9\.]+)\)/\2.read(\1)/g' "$file"
    sed -i -E 's/Ash\.read!\(([^,]+), domain: ([A-Za-z0-9\.]+)\)/\2.read!(\1)/g' "$file"
    sed -i -E 's/Ash\.read\(domain: ([A-Za-z0-9\.]+)\)/\1.read()/g' "$file"
    sed -i -E 's/Ash\.read!\(domain: ([A-Za-z0-9\.]+)\)/\1.read!()/g' "$file"
    
    sed -i -E 's/Ash\.read_one\(([^,]+), domain: ([A-Za-z0-9\.]+)\)/\2.read_one(\1)/g' "$file"
    sed -i -E 's/Ash\.read_one!\(([^,]+), domain: ([A-Za-z0-9\.]+)\)/\2.read_one!(\1)/g' "$file"
    
    sed -i -E 's/Ash\.destroy\(([^,]+), domain: ([A-Za-z0-9\.]+)\)/\2.destroy(\1)/g' "$file"
    sed -i -E 's/Ash\.destroy!\(([^,]+), domain: ([A-Za-z0-9\.]+)\)/\2.destroy!(\1)/g' "$file"
    sed -i -E 's/Ash\.destroy\(domain: ([A-Za-z0-9\.]+)\)/\1.destroy()/g' "$file"
    sed -i -E 's/Ash\.destroy!\(domain: ([A-Za-z0-9\.]+)\)/\1.destroy!()/g' "$file"
    
    sed -i -E 's/Ash\.get\(([^,]+), ([^,]+), domain: ([A-Za-z0-9\.]+)\)/\3.get(\1, \2)/g' "$file"
    sed -i -E 's/Ash\.get!\(([^,]+), ([^,]+), domain: ([A-Za-z0-9\.]+)\)/\3.get!(\1, \2)/g' "$file"
    
    # Check if any changes were made
    if ! diff -q "$file" "$file.bak" > /dev/null; then
        echo "Fixed Ash calls in: $file"
        rm "$file.bak"
    else
        rm "$file.bak"
    fi
}

# Fix all Elixir files in the specified directories
for dir in lib/eve_dmv/platform lib/eve_dmv/external lib/eve_dmv/cache; do
    if [ -d "$dir" ]; then
        echo "Processing directory: $dir"
        find "$dir" -name "*.ex" -type f | while read -r file; do
            fix_ash_calls "$file"
        done
    fi
done

echo "Ash framework call fixes complete!"