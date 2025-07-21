#!/bin/bash

# Script to fix remaining parsing errors with more specific patterns

echo "Fixing remaining parsing errors..."

# Find all Elixir files
files=$(find lib -name "*.ex" -type f)

fixed_count=0

for file in $files; do
  if [ -f "$file" ]; then
    # Create backup
    cp "$file" "${file}.bak"
    
    # 1. Fix pattern: if |> Enum.empty?(list) -> if Enum.empty?(list)
    sed -i 's/if |> Enum\./if Enum./g' "$file"
    sed -i 's/if |> List\./if List./g' "$file"
    sed -i 's/if |> Map\./if Map./g' "$file"
    sed -i 's/if |> String\./if String./g' "$file"
    
    # 2. Fix pattern: not |> Function -> not Function
    sed -i 's/not |> /not /g' "$file"
    
    # 3. Fix pattern: case |> Function -> case Function
    sed -i 's/case |> /case /g' "$file"
    
    # 4. Fix pattern: @Enum.function -> Enum.function (remove @ from module calls)
    sed -i 's/@Enum\./@contexts |> Enum./g' "$file"
    sed -i 's/@Map\./@contexts |> Map./g' "$file"
    sed -i 's/@List\./@contexts |> List./g' "$file"
    
    # 5. Fix malformed map/filter chains
    perl -i -pe '
      # Fix: Enum.map(list, fn), other_param) -> Enum.map(list, fn)
      s/Enum\.map\(([^,]+), ([^)]+)\), ([^)]+)\)/Enum.map(\1, \2)/g;
      s/Enum\.filter\(([^,]+), ([^)]+)\), ([^)]+)\)/Enum.filter(\1, \2)/g;
      
      # Fix: List.first(ps) do -> List.first(ps) do
      s/case \|> List\.first\((.*?)\) do/case List.first(\1) do/g;
      
      # Fix double function calls like Enum.mapEnum.sum
      s/Enum\.map(Enum\.\w+)\(/Enum.map(/g;
      s/Enum\.filter(Enum\.\w+)\(/Enum.filter(/g;
      
      # Fix: length(Enum.uniq(), ) -> Enum.uniq() |> length()
      s/length\(Enum\.uniq\(\), \)/Enum.uniq() |> length()/g;
      
      # Fix: Enum.filterMap.new -> Enum.filter |> Map.new
      s/Enum\.filterMap\.new/Enum.filter |> Map.new/g;
      
      # Fix: |> elem(1) at end of line
      s/\|>\s*elem\((\d+)\)\s*$/|> elem(\1)/g;
    ' "$file"
    
    # 6. Fix specific common malformed patterns
    # Fix: Enum.map((list, fn), param) -> Enum.map(list, fn)
    perl -i -pe 's/Enum\.map\(\(([^,]+), ([^)]+)\), ([^)]+)\)/Enum.map(\1, \2)/g' "$file"
    perl -i -pe 's/Enum\.filter\(\(([^,]+), ([^)]+)\), ([^)]+)\)/Enum.filter(\1, \2)/g' "$file"
    
    # 7. Fix trailing commas in function calls
    sed -i 's/, )/))/g' "$file"
    sed -i 's/, )/)/g' "$file"
    
    # 8. Fix pattern where comma appears before pipe
    # Example: group_analysis,  |> Enum.with_index()
    sed -i 's/,\s*|>/|>/g' "$file"
    
    # 9. Fix specific issue with then function
    # then(hash_input, &:crypto.hash(:md5, &1)) -> hash_input |> then(&:crypto.hash(:md5, &1))
    perl -i -pe 's/then\(([^,]+), (.*?)\)$/\1 |> then(\2)/g' "$file"
    
    # 10. Fix List.last patterns
    # List.last(events, ) -> List.last(events)
    sed -i 's/List\.last(\([^,]*\), )/List.last(\1)/g' "$file"
    
    # Check if file was modified
    if ! cmp -s "$file" "${file}.bak"; then
      ((fixed_count++))
      echo "  ✓ Fixed parsing issues in $file"
      rm "${file}.bak"
    else
      rm "${file}.bak"
    fi
  fi
done

echo ""
echo "Fixed $fixed_count files"
echo ""
echo "Checking remaining parsing errors..."

# Run Credo and show remaining errors
mix credo --strict --format=flycheck 2>&1 | grep -A 30 "Some source files could not be parsed" | head -40