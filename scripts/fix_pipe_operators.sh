#!/bin/bash

# Script to fix pipe operator syntax issues introduced by auto-formatter

echo "🔧 Fixing pipe operator syntax issues..."

# Fix .sum() -> |> Enum.sum()
find lib -name "*.ex" -type f -exec sed -i 's/\.sum()/|> Enum.sum()/g' {} \;

# Fix .length() -> |> length()
find lib -name "*.ex" -type f -exec sed -i 's/\.length()/|> length()/g' {} \;

# Fix .uniq() -> |> Enum.uniq()
find lib -name "*.ex" -type f -exec sed -i 's/\.uniq()/|> Enum.uniq()/g' {} \;

# Fix .elem(0) -> |> elem(0)
find lib -name "*.ex" -type f -exec sed -i 's/\.elem(0)/|> elem(0)/g' {} \;

# Fix .elem(1) -> |> elem(1)
find lib -name "*.ex" -type f -exec sed -i 's/\.elem(1)/|> elem(1)/g' {} \;

echo "✅ Pipe operator syntax fixes applied"

# Check if there are any compilation issues
echo "🔍 Checking compilation..."
mix compile 2>&1 | grep -E "(error:|warning:.*undefined)" | head -10