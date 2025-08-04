#!/bin/bash

# Script to fix Ash API method calls throughout the codebase

echo "Fixing Ash API method calls..."

# Function to fix API calls in a file
fix_api_calls() {
    local file="$1"
    
    # Skip if file doesn't exist
    [ ! -f "$file" ] && return
    
    # Create backup
    cp "$file" "$file.bak"
    
    # Fix Api.create!() with no args - should pass the changeset
    sed -i -E 's/Api\.create!\(\)/Api.create!(changeset)/g' "$file"
    sed -i -E 's/EveDmv\.Api\.create!\(\)/EveDmv.Api.create!(changeset)/g' "$file"
    
    # Fix Api.update!() with one arg - needs resource and changeset
    sed -i -E 's/\|> Api\.update!\(\)/|> then(fn changeset -> Api.update(changeset.data, changeset) end)/g' "$file"
    sed -i -E 's/\|> EveDmv\.Api\.update!\(\)/|> then(fn changeset -> EveDmv.Api.update(changeset.data, changeset) end)/g' "$file"
    
    # Fix Api.update!(resource) - needs changeset
    sed -i -E 's/Api\.update!\(([^,)]+)\)$/Api.update(\1, Ash.Changeset.new(\1))/g' "$file"
    sed -i -E 's/EveDmv\.Api\.update!\(([^,)]+)\)$/EveDmv.Api.update(\1, Ash.Changeset.new(\1))/g' "$file"
    
    # Fix Api.destroy!(resource) - Ash doesn't have bang version
    sed -i -E 's/Api\.destroy!\(([^)]+)\)/case Api.destroy(\1) do {:ok, _} -> :ok; error -> raise "Destroy failed: #{inspect(error)}" end/g' "$file"
    
    # Fix Api.create() with one arg
    sed -i -E 's/\|> Api\.create\(\)/|> Api.create()/g' "$file"
    sed -i -E 's/\|> EveDmv\.Api\.create\(\)/|> EveDmv.Api.create()/g' "$file"
    
    # Fix Api.update() with one arg
    sed -i -E 's/\|> Api\.update\(\)/|> then(fn changeset -> Api.update(changeset.data, changeset) end)/g' "$file"
    
    # Fix read_one - doesn't exist in Ash, use read with limit
    sed -i -E 's/Api\.read_one\(([^)]+)\)/Api.read(Ash.Query.limit(\1, 1)) |> case do {:ok, [result]} -> {:ok, result}; {:ok, []} -> {:error, :not_found}; error -> error end/g' "$file"
    sed -i -E 's/EveDmv\.Api\.read_one\(([^)]+)\)/EveDmv.Api.read(Ash.Query.limit(\1, 1)) |> case do {:ok, [result]} -> {:ok, result}; {:ok, []} -> {:error, :not_found}; error -> error end/g' "$file"
    
    # Check if any changes were made
    if ! diff -q "$file" "$file.bak" > /dev/null; then
        echo "Fixed API calls in: $file"
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
            fix_api_calls "$file"
        done
    fi
done

echo "Ash API call fixes complete!"