#!/bin/bash

# Fix all "|> end" patterns that should just be "end"

echo "Fixing |> end syntax errors..."

# Find all .ex files and fix the pattern
find lib -name "*.ex" -type f -exec sed -i 's/|> end$/end/g' {} \;

echo "Fixed all |> end patterns"

# Also fix any remaining pipeline issues
find lib -name "*.ex" -type f -exec sed -i 's/|> rescue$/rescue/g' {} \;
find lib -name "*.ex" -type f -exec sed -i 's/|> catch$/catch/g' {} \;
find lib -name "*.ex" -type f -exec sed -i 's/|> after$/after/g' {} \;
find lib -name "*.ex" -type f -exec sed -i 's/|> else$/else/g' {} \;

echo "Fixed pipeline keyword errors"

# Check if compilation works now
echo "Checking compilation..."
mix compile --force 2>&1 | head -10