#!/bin/bash
# Workstream Alpha: Extract and analyze unused functions from dialyzer output

echo "=== Workstream Alpha: Unused Function Analysis ==="
echo "Extracting unused functions from dialyzer output..."

# Create output directory
mkdir -p /tmp/alpha_analysis

# Extract all unused_fun errors with context
grep -B1 -A1 "unused_fun" /workspace/dialyzer.txt > /tmp/alpha_analysis/unused_functions_raw.txt

# Parse and extract file:line:function information
echo "Parsing unused function details..."
grep -A1 "unused_fun" /workspace/dialyzer.txt | grep "Function" | \
  sed -E 's/Function ([^ ]+)\/.*/\1/' > /tmp/alpha_analysis/function_names.txt

# Extract file paths with line numbers
grep "unused_fun" /workspace/dialyzer.txt | \
  sed -E 's/^([^:]+:[0-9]+):unused_fun$/\1/' > /tmp/alpha_analysis/file_locations.txt

# Combine file locations and function names
paste /tmp/alpha_analysis/file_locations.txt /tmp/alpha_analysis/function_names.txt > /tmp/alpha_analysis/unused_functions.txt

# Sort by file to group functions together
sort -t: -k1,1 /tmp/alpha_analysis/unused_functions.txt > /tmp/alpha_analysis/unused_functions_sorted.txt

# Count unused functions per file
echo -e "\n=== Unused Functions Per File ==="
cut -d: -f1 /tmp/alpha_analysis/unused_functions_sorted.txt | uniq -c | sort -nr | head -20

# Total count
total_count=$(wc -l < /tmp/alpha_analysis/unused_functions_sorted.txt)
echo -e "\n=== Total Unused Functions: $total_count ==="

# Categorize functions as private (no def) or public (def)
echo -e "\n=== Analyzing Function Visibility ==="
rm -f /tmp/alpha_analysis/private_functions.txt /tmp/alpha_analysis/public_functions.txt

while IFS=$'\t' read -r location function; do
  file=$(echo "$location" | cut -d: -f1)
  line=$(echo "$location" | cut -d: -f2)
  
  # Check if function is private (defp) or public (def)
  if grep -q "^[[:space:]]*defp[[:space:]]\+$function[[:space:]]*(" "$file" 2>/dev/null; then
    echo "$location	$function" >> /tmp/alpha_analysis/private_functions.txt
  else
    echo "$location	$function" >> /tmp/alpha_analysis/public_functions.txt
  fi
done < /tmp/alpha_analysis/unused_functions_sorted.txt

private_count=$(wc -l < /tmp/alpha_analysis/private_functions.txt 2>/dev/null || echo 0)
public_count=$(wc -l < /tmp/alpha_analysis/public_functions.txt 2>/dev/null || echo 0)

echo "Private functions (safe to remove): $private_count"
echo "Public functions (need review): $public_count"

echo -e "\n=== Files with Most Unused Functions ==="
cut -d: -f1 /tmp/alpha_analysis/unused_functions_sorted.txt | uniq -c | sort -nr | head -10

echo -e "\nAnalysis complete. Results saved in /tmp/alpha_analysis/"