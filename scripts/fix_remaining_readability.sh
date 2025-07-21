#!/bin/bash
# Fix remaining readability issues to get under 800 total

echo "Fixing remaining readability issues..."

# 1. Fix LargeNumbers (297 issues) - Add underscores to numbers >= 10,000
echo "Fixing large numbers..."
find lib test -name "*.ex" -o -name "*.exs" | while read file; do
    # Skip backup files
    [[ "$file" == *.bak ]] && continue
    
    # Add underscores to large numbers
    perl -i -pe 's/\b([1-9]\d{4,})\b/sprintf("%s", reverse(join("_", reverse(split("", sprintf("%d", $1))) =~ m{.{1,3}}))/ge' "$file" 2>/dev/null || true
done

# 2. Fix TrailingWhiteSpace (94 issues)
echo "Fixing trailing whitespace..."
find lib test -name "*.ex" -o -name "*.exs" | while read file; do
    [[ "$file" == *.bak ]] && continue
    sed -i 's/[[:space:]]*$//' "$file"
done

# 3. Fix TrailingBlankLine (41 issues)
echo "Fixing trailing blank lines..."
find lib test -name "*.ex" -o -name "*.exs" | while read file; do
    [[ "$file" == *.bak ]] && continue
    
    # Remove trailing blank lines but ensure file ends with single newline
    perl -i -0pe 's/\n+$/\n/g' "$file"
done

# 4. Fix SinglePipe (48 issues) - Convert single-function pipelines to direct calls
echo "Fixing single pipe issues..."
find lib test -name "*.ex" -o -name "*.exs" | while read file; do
    [[ "$file" == *.bak ]] && continue
    
    # Pattern: variable |> SomeFunction(...)  -> SomeFunction(variable, ...)
    perl -i -pe 's/(\w+)\s*\|\>\s*([A-Z][a-zA-Z0-9_.]*)\(/\2(\1, /g' "$file" 2>/dev/null || true
done

# 5. Fix ImplTrue (62 issues) - @impl true -> @impl ModuleName
echo "Fixing @impl true issues requires manual intervention - these are behavioural implementations"

echo "Completed fixing major readability issues!"

# Check final count
echo "Getting final readability count..."
mix credo --strict --format=json 2>/dev/null | jq -r '.issues[] | select(.category == "readability")' | wc -l