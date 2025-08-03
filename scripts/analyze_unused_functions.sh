#!/bin/bash
# Comprehensive script to analyze and categorize unused functions

echo "🔍 Analyzing unused functions from dialyzer..."

# Create working directory
mkdir -p /tmp/unused_analysis

# Extract all unused function warnings with context
echo "Extracting unused function warnings..."
grep -B1 -A1 "unused_fun" /workspace/dialyzer.txt > /tmp/unused_analysis/raw_warnings.txt

# Parse the warnings to extract file, line, function name, and arity
python3 << 'EOF' > /tmp/unused_analysis/parsed_unused.csv
import re

with open('/tmp/unused_analysis/raw_warnings.txt', 'r') as f:
    lines = f.readlines()

# Process in chunks of 3 lines (location, type, message)
i = 0
results = []

while i < len(lines):
    line = lines[i].strip()
    
    # Look for the unused_fun line
    if ':unused_fun' in line:
        # Extract file and line number
        match = re.match(r'(.+\.ex):(\d+):unused_fun', line)
        if match and i + 1 < len(lines):
            file_path = match.group(1)
            line_num = match.group(2)
            
            # Next line should have the function info
            next_line = lines[i + 1].strip()
            func_match = re.search(r'Function (\w+)/(\d+) will never be called', next_line)
            
            if func_match:
                func_name = func_match.group(1)
                arity = func_match.group(2)
                results.append(f"{file_path},{line_num},{func_name},{arity}")
    
    i += 1

# Output as CSV
print("file,line,function,arity")
for result in results:
    print(result)
EOF

total_unused=$(tail -n +2 /tmp/unused_analysis/parsed_unused.csv | wc -l)
echo "Found $total_unused unused functions"

# Analyze by module
echo ""
echo "Top 10 modules with unused functions:"
tail -n +2 /tmp/unused_analysis/parsed_unused.csv | \
  cut -d, -f1 | sort | uniq -c | sort -nr | head -10

# Categorize functions
echo ""
echo "Categorizing unused functions..."

# Create categories
mkdir -p /tmp/unused_analysis/categories

# 1. Test helper functions (likely safe to remove)
echo "Finding test helper functions..."
tail -n +2 /tmp/unused_analysis/parsed_unused.csv | \
  grep -E "test_helper|_test\.ex|test/support" > /tmp/unused_analysis/categories/test_helpers.csv

# 2. Private formatting functions (often false positives)
echo "Finding formatting functions..."
tail -n +2 /tmp/unused_analysis/parsed_unused.csv | \
  grep -E ",format_|,build_|,prepare_|,serialize_" > /tmp/unused_analysis/categories/formatting.csv

# 3. Analysis/calculation functions
echo "Finding analysis functions..."
tail -n +2 /tmp/unused_analysis/parsed_unused.csv | \
  grep -E ",analyze_|,calculate_|,compute_|,detect_" > /tmp/unused_analysis/categories/analysis.csv

# 4. Helper functions
echo "Finding helper functions..."
tail -n +2 /tmp/unused_analysis/parsed_unused.csv | \
  grep -E ",.*_helper|,do_|,maybe_|,handle_" > /tmp/unused_analysis/categories/helpers.csv

# Create focused removal candidates
echo ""
echo "Identifying safe removal candidates..."

# Functions that are definitely unused (no references in codebase)
> /tmp/unused_analysis/safe_to_remove.csv
echo "file,line,function,arity,references" > /tmp/unused_analysis/safe_to_remove.csv

tail -n +2 /tmp/unused_analysis/parsed_unused.csv | while IFS=, read -r file line func arity; do
  # Count references (excluding the definition itself)
  ref_count=$(rg -c "\\b$func\\b" lib test --type elixir 2>/dev/null | \
    grep -v "^$file:" | \
    awk -F: '{sum+=$2} END {print sum+0}')
  
  if [ "$ref_count" -eq 0 ]; then
    echo "$file,$line,$func,$arity,$ref_count" >> /tmp/unused_analysis/safe_to_remove.csv
  fi
done

safe_count=$(tail -n +2 /tmp/unused_analysis/safe_to_remove.csv | wc -l)

echo ""
echo "Summary:"
echo "- Total unused functions: $total_unused"
echo "- Test helpers: $(wc -l < /tmp/unused_analysis/categories/test_helpers.csv)"
echo "- Formatting functions: $(wc -l < /tmp/unused_analysis/categories/formatting.csv)"
echo "- Analysis functions: $(wc -l < /tmp/unused_analysis/categories/analysis.csv)"
echo "- Helper functions: $(wc -l < /tmp/unused_analysis/categories/helpers.csv)"
echo "- Safe to remove (no references): $safe_count"

echo ""
echo "Files saved to /tmp/unused_analysis/"
echo ""
echo "Recommended next steps:"
echo "1. Review safe removal candidates: cat /tmp/unused_analysis/safe_to_remove.csv"
echo "2. Focus on test helpers first: cat /tmp/unused_analysis/categories/test_helpers.csv"
echo "3. Check specific module: grep 'module_name' /tmp/unused_analysis/parsed_unused.csv"