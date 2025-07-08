#!/bin/bash

# Fix remaining pipeline issues more aggressively
set -e

echo "Starting aggressive pipeline fix..."

# Pattern 1: variable |> Enum.reduce(init, fn...)
find lib -name "*.ex" -type f -exec sed -i -E '
/\|> Enum\.reduce\(/,/)/ {
  s/^([[:space:]]*)([a-zA-Z_][a-zA-Z0-9_]*)\s*\|>\s*Enum\.reduce\(([^,]*),\s*(.*)/\1Enum.reduce(\2, \3, \4/
}
' {} \;

# Pattern 2: variable |> Enum.map(fn...)  
find lib -name "*.ex" -type f -exec sed -i -E '
s/^([[:space:]]*)([a-zA-Z_][a-zA-Z0-9_]*)\s*\|>\s*Enum\.map\((.*)\)/\1Enum.map(\2, \3)/g
' {} \;

# Pattern 3: variable |> Enum.filter(fn...)
find lib -name "*.ex" -type f -exec sed -i -E '
s/^([[:space:]]*)([a-zA-Z_][a-zA-Z0-9_]*)\s*\|>\s*Enum\.filter\((.*)\)/\1Enum.filter(\2, \3)/g
' {} \;

# Pattern 4: variable |> Enum.flat_map(fn...)
find lib -name "*.ex" -type f -exec sed -i -E '
s/^([[:space:]]*)([a-zA-Z_][a-zA-Z0-9_]*)\s*\|>\s*Enum\.flat_map\((.*)\)/\1Enum.flat_map(\2, \3)/g
' {} \;

# Pattern 5: variable |> elem(n)
find lib -name "*.ex" -type f -exec sed -i -E '
s/^([[:space:]]*)([a-zA-Z_][a-zA-Z0-9_()\.]*)\s*\|>\s*elem\(([^)]*)\)/\1elem(\2, \3)/g
' {} \;

# Pattern 6: variable |> length()
find lib -name "*.ex" -type f -exec sed -i -E '
s/^([[:space:]]*)([a-zA-Z_][a-zA-Z0-9_]*)\s*\|>\s*length\(\)/\1length(\2)/g
' {} \;

# Pattern 7: variable |> hd()
find lib -name "*.ex" -type f -exec sed -i -E '
s/^([[:space:]]*)([a-zA-Z_][a-zA-Z0-9_]*)\s*\|>\s*hd\(\)/\1hd(\2)/g
' {} \;

# Pattern 8: variable |> tl() 
find lib -name "*.ex" -type f -exec sed -i -E '
s/^([[:space:]]*)([a-zA-Z_][a-zA-Z0-9_]*)\s*\|>\s*tl\(\)/\1tl(\2)/g
' {} \;

# Pattern 9: variable |> Enum.count()
find lib -name "*.ex" -type f -exec sed -i -E '
s/^([[:space:]]*)([a-zA-Z_][a-zA-Z0-9_]*)\s*\|>\s*Enum\.count\(\)/\1Enum.count(\2)/g
' {} \;

# Pattern 10: variable |> Enum.empty?()
find lib -name "*.ex" -type f -exec sed -i -E '
s/^([[:space:]]*)([a-zA-Z_][a-zA-Z0-9_]*)\s*\|>\s*Enum\.empty\?\(\)/\1Enum.empty?(\2)/g
' {} \;

# Pattern 11: variable |> Map.get(key)
find lib -name "*.ex" -type f -exec sed -i -E '
s/^([[:space:]]*)([a-zA-Z_][a-zA-Z0-9_]*)\s*\|>\s*Map\.get\(([^)]*)\)/\1Map.get(\2, \3)/g
' {} \;

# Pattern 12: variable |> Map.put(key, value)
find lib -name "*.ex" -type f -exec sed -i -E '
s/^([[:space:]]*)([a-zA-Z_][a-zA-Z0-9_]*)\s*\|>\s*Map\.put\(([^)]*)\)/\1Map.put(\2, \3)/g
' {} \;

# Pattern 13: variable |> String.trim()
find lib -name "*.ex" -type f -exec sed -i -E '
s/^([[:space:]]*)([a-zA-Z_][a-zA-Z0-9_]*)\s*\|>\s*String\.trim\(\)/\1String.trim(\2)/g
' {} \;

# Pattern 14: variable |> String.downcase()
find lib -name "*.ex" -type f -exec sed -i -E '
s/^([[:space:]]*)([a-zA-Z_][a-zA-Z0-9_]*)\s*\|>\s*String\.downcase\(\)/\1String.downcase(\2)/g
' {} \;

# Pattern 15: variable |> String.upcase()
find lib -name "*.ex" -type f -exec sed -i -E '
s/^([[:space:]]*)([a-zA-Z_][a-zA-Z0-9_]*)\s*\|>\s*String\.upcase\(\)/\1String.upcase(\2)/g
' {} \;

echo "Aggressive pipeline fixes applied!"