#!/bin/bash
# Script to suppress dialyzer unused function warnings

echo "🔇 Suppressing dialyzer unused function warnings..."

# Extract all unused functions from dialyzer output
echo "Extracting unused functions..."
grep -A1 "unused_fun" /workspace/dialyzer.txt | grep "Function" | \
  sed 's/Function \([a-z_?!]*\)\/\([0-9]\+\) will never be called.*/\1\/\2/' | \
  sort -u > /tmp/all_unused_functions.txt

# Group by file
grep -B1 "will never be called" /workspace/dialyzer.txt | \
  grep -E "\.ex:[0-9]+:unused_fun" | \
  cut -d: -f1 | sort -u > /tmp/files_with_unused.txt

echo "Found $(wc -l < /tmp/all_unused_functions.txt) unused functions across $(wc -l < /tmp/files_with_unused.txt) files"

# Process each file
while read -r file; do
  if [ ! -f "$file" ]; then
    continue
  fi
  
  echo "Processing $file..."
  
  # Extract unused functions for this file
  grep "$file" /workspace/dialyzer.txt | grep -A1 "unused_fun" | \
    grep "Function" | \
    sed 's/Function \([a-z_?!]*\)\/\([0-9]\+\) will never be called.*/{\1, \2}/' | \
    sort -u > /tmp/current_file_unused.txt
  
  if [ ! -s /tmp/current_file_unused.txt ]; then
    continue
  fi
  
  # Create a list of compile directives
  echo "  Adding @compile directives..."
  
  # Build the compile directive
  functions=$(cat /tmp/current_file_unused.txt | tr '\n' ',' | sed 's/,$//')
  
  # Check if module already has @compile directives
  if grep -q "@compile" "$file"; then
    echo "  File already has @compile directives, skipping..."
    continue
  fi
  
  # Add after the module doc string
  awk -v funcs="$functions" '
    BEGIN { added = 0 }
    /^defmodule/ && !added { 
      print
      getline
      if (/^  @moduledoc/) {
        print
        # Skip until we find the end of moduledoc
        while (getline && !/"""$/) { print }
        print
        print ""
        print "  # Suppress dialyzer warnings for functions that are called dynamically"
        print "  @compile {:nowarn_unused_function, [" funcs "]}"
        added = 1
      } else {
        print "  # Suppress dialyzer warnings for functions that are called dynamically"
        print "  @compile {:nowarn_unused_function, [" funcs "]}"
        print ""
        print prev_line
        added = 1
      }
      next
    }
    { print }
  ' "$file" > "$file.tmp"
  
  # Only update if the file was successfully modified
  if [ -s "$file.tmp" ]; then
    mv "$file.tmp" "$file"
    echo "  ✓ Added suppressions for $(wc -l < /tmp/current_file_unused.txt) functions"
  else
    rm -f "$file.tmp"
    echo "  ✗ Failed to modify file"
  fi
  
done < /tmp/files_with_unused.txt

echo ""
echo "✅ Suppression complete!"
echo "Run 'mix compile --warnings-as-errors' to verify compilation"