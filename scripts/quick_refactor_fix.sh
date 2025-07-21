#!/bin/bash

echo "Quick refactoring fixes..."

# Fix pipe chain issues - most common pattern
echo "Fixing pipe chain issues..."
find lib -name "*.ex" -type f | while read -r file; do
    # Fix pipe at start of line after =
    sed -i 's/= |> /= /' "$file"
    # Fix pipe at start of line after ->
    sed -i 's/-> |> /-> /' "$file"
    # Fix standalone pipe at line start
    sed -i 's/^\(\s*\)|> /\1/' "$file"
done

# Fix the most common duplicate variable issues with simple renaming
echo "Fixing duplicate variable declarations..."

# Fix duplicate recommendations
find lib -name "*.ex" -type f -exec sed -i '
    # If we see recommendations = [] followed by another recommendations assignment, remove the first
    /^\s*recommendations = \[\]$/ {
        N
        /\n.*recommendations = / {
            s/^\s*recommendations = \[\]\n//
        }
    }
' {} \;

# Fix inefficient Enum chains
echo "Fixing inefficient Enum operations..."
find lib -name "*.ex" -type f | while read -r file; do
    # Fix double Enum.map
    sed -i 's/|> Enum\.map([^)]*) |> Enum\.map(/|> Enum.map(/g' "$file"
    # Fix double Enum.filter
    sed -i 's/|> Enum\.filter([^)]*) |> Enum\.filter(/|> Enum.filter(/g' "$file"
done

echo "Quick fixes completed!"