#\!/bin/bash

echo "Fixing with statement syntax errors..."

# Fix corporation_analyzer.ex - convert pattern match lines after with blocks to else clauses
perl -i -0pe 's/(\n\s+\{:ok,[^}]+\})\n\n(\s+)(\{:error, reason\} ->)/\1\n    else\n\2\3/g' /workspace/lib/eve_dmv/contexts/corporation/core/corporation_analyzer.ex

echo "Fixed with statements in corporation_analyzer.ex"

# Look for similar patterns in other files
echo "Checking for similar patterns in other files..."
grep -r "^\s*{:error, reason} ->" /workspace/lib --include="*.ex" | grep -v "else" | head -20
