#!/bin/bash
# Script to find truly dead code in the codebase

echo "🔍 Finding dead code patterns..."

# Create output directory
mkdir -p /tmp/dead_code_analysis

# 1. Find private functions that are never called
echo "Finding uncalled private functions..."
rg "^\s*defp\s+(\w+)" --type elixir -o -r '$1' lib/ | sort -u > /tmp/dead_code_analysis/all_private_functions.txt

# Check each private function for references
> /tmp/dead_code_analysis/uncalled_private_functions.txt
while read -r func; do
  # Count occurrences (excluding the definition)
  count=$(rg "\b$func\b" lib/ --type elixir -c | awk -F: '{sum+=$2} END {print sum}')
  
  # If only appears once (the definition), it's uncalled
  if [ "$count" -eq 1 ]; then
    echo "$func" >> /tmp/dead_code_analysis/uncalled_private_functions.txt
  fi
done < /tmp/dead_code_analysis/all_private_functions.txt

# 2. Find commented out code blocks
echo "Finding commented out code..."
rg "^\s*#.*def\s+" lib/ --type elixir > /tmp/dead_code_analysis/commented_functions.txt

# 3. Find TODO/FIXME/HACK comments that might indicate dead code
echo "Finding TODO markers..."
rg "# (TODO|FIXME|HACK|XXX|DEPRECATED|UNUSED)" lib/ --type elixir > /tmp/dead_code_analysis/todo_markers.txt

# 4. Find empty function bodies
echo "Finding empty functions..."
rg -U "def[p]?\s+\w+.*do\s*\n\s*(nil|:ok|{:ok,\s*nil}|{:error,\s*:not_implemented})\s*\n\s*end" lib/ --type elixir > /tmp/dead_code_analysis/empty_functions.txt

# 5. Find modules with no public functions
echo "Finding modules with no public functions..."
for file in $(find lib -name "*.ex" -type f); do
  public_count=$(grep -c "^\s*def\s" "$file" 2>/dev/null || echo 0)
  if [ "$public_count" -eq 0 ]; then
    # Check if it has any functions at all
    total_count=$(grep -c "^\s*defp\?\s" "$file" 2>/dev/null || echo 0)
    if [ "$total_count" -gt 0 ]; then
      echo "$file" >> /tmp/dead_code_analysis/private_only_modules.txt
    fi
  fi
done

# 6. Find duplicate function definitions
echo "Finding duplicate functions..."
rg "^\s*def[p]?\s+(\w+)" --type elixir -o -r '$1' lib/ | sort | uniq -d > /tmp/dead_code_analysis/duplicate_functions.txt

# 7. Find unreferenced modules
echo "Finding unreferenced modules..."
for file in $(find lib -name "*.ex" -type f); do
  module_name=$(grep -m1 "^defmodule" "$file" | sed 's/defmodule \([^ ]*\).*/\1/')
  if [ -n "$module_name" ]; then
    # Count references to this module (excluding the definition)
    ref_count=$(rg "$module_name" lib/ --type elixir | grep -v "^$file:" | wc -l)
    if [ "$ref_count" -eq 0 ]; then
      echo "$file: $module_name" >> /tmp/dead_code_analysis/unreferenced_modules.txt
    fi
  fi
done

# Generate summary
echo ""
echo "=== Dead Code Analysis Summary ==="
echo "Uncalled private functions: $(wc -l < /tmp/dead_code_analysis/uncalled_private_functions.txt)"
echo "Commented out functions: $(wc -l < /tmp/dead_code_analysis/commented_functions.txt)"
echo "TODO/FIXME markers: $(wc -l < /tmp/dead_code_analysis/todo_markers.txt)"
echo "Empty functions: $(wc -l < /tmp/dead_code_analysis/empty_functions.txt)"
echo "Private-only modules: $(wc -l < /tmp/dead_code_analysis/private_only_modules.txt 2>/dev/null || echo 0)"
echo "Duplicate functions: $(wc -l < /tmp/dead_code_analysis/duplicate_functions.txt)"
echo "Unreferenced modules: $(wc -l < /tmp/dead_code_analysis/unreferenced_modules.txt 2>/dev/null || echo 0)"
echo ""
echo "Results saved to /tmp/dead_code_analysis/"