#!/bin/bash

echo "Fixing remaining with statement syntax errors..."

# Find all files with potential with statement errors
echo "Searching for files with potential issues..."

# Look for patterns where we have error handling without else
grep -r "{\s*:error,.*} ->" /workspace/lib --include="*.ex" | grep -B5 "with " | grep -l "\.ex" | sort | uniq > /tmp/files_to_check.txt

# Process each file
while read -r file; do
    if [ -f "$file" ]; then
        echo "Checking $file..."
        
        # Use perl to fix with statements missing else clauses
        # This pattern looks for with blocks followed by error handling without else
        perl -i -0pe 's/(\n\s+\{:ok,[^}]+\})\n\n(\s+)(\{:error[^}]*\} ->)/\1\n    else\n\2\3/g' "$file"
        
        # Also fix patterns where there's just a result without {:ok, ...}
        perl -i -0pe 's/(with[^d][^o][^\n]+\n[^\n]+\n[^\n]+)\n\n(\s+)(\{:error[^}]*\} ->)/\1\n    else\n\2\3/g' "$file"
    fi
done < /tmp/files_to_check.txt

echo "Fixing complete!"