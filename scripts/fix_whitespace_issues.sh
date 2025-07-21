#!/bin/bash

# Script to fix common whitespace issues identified by Credo

echo "Fixing trailing whitespace in all Elixir files..."
find lib test -name "*.ex" -o -name "*.exs" | while read file; do
  # Remove trailing whitespace
  sed -i 's/[[:space:]]*$//' "$file"
  
  # Ensure single newline at end of file
  if [ -n "$(tail -c 1 "$file")" ]; then
    echo >> "$file"
  fi
done

echo "Fixing redundant blank lines (more than 1 consecutive)..."
find lib test -name "*.ex" -o -name "*.exs" | while read file; do
  # Replace multiple consecutive blank lines with single blank line
  awk 'BEGIN{bl=0}/^$/{bl++;if(bl==1)print;next}{bl=0;print}' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
done

echo "Whitespace fixes complete!"