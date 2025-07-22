#!/bin/bash

echo "Finding and fixing orphaned pipeline operators..."

# Find all orphaned pipelines that start a line and fix them
find lib -name "*.ex" -type f -exec sed -i 's/^\s*|>\s*\([a-zA-Z_][a-zA-Z0-9_]*\)/    \1/g' {} \;

# Find patterns where we have:
# variable_name
# |> Something
# And convert to:
# variable_name |> Something
find lib -name "*.ex" -type f -exec perl -i -pe '
  BEGIN { undef $/; }
  s/(\w+)\s*\n\s*\|\>\s*([A-Z][a-zA-Z0-9_]*\.[a-z_]+)/\1 |> \2/gms;
  s/(\w+)\s*\n\s*\|\>\s*([a-z_]+)/\1 |> \2/gms;
' {} \;

echo "Fixed orphaned pipelines"

# Also fix broken function calls that got separated
find lib -name "*.ex" -type f -exec sed -i 's/^\s*\([A-Z][a-zA-Z0-9_]*\.[a-z_]*\)()$/    |> \1()/g' {} \;

echo "Fixed broken function calls"

# Check if we can now compile
echo "Testing compilation..."
mix compile --force 2>&1 | head -5