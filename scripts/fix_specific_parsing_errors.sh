#!/bin/bash

echo "=== Fixing Specific Parsing Errors ==="

# Fix the module declaration errors first
echo "Fixing module and alias declarations..."

# Fix defmodule lines that got corrupted
find lib -name "*.ex" -type f -exec sed -i 's/defmodule EveDmv\. |> /defmodule EveDmv./g' {} \;
find lib -name "*.ex" -type f -exec sed -i 's/alias EveDmv\. |> /alias EveDmv./g' {} \;

# Fix the specific files that had parsing errors

# Fix attack_pattern_analyzer.ex
FILE1="lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/analyzers/attack_pattern_analyzer.ex"
if [ -f "$FILE1" ]; then
  echo "Fixing $FILE1"
  
  # Fix the missing function arguments in Enum.map
  sed -i 's/Enum\.map(\s*\s*)/Enum.map(\& \&1.victim)/g' "$FILE1"
  
  # Fix the incomplete Enum.map patterns
  sed -i 's/|> Enum\.map(\s*\s*) |>/|> Enum.map(\& \&1.victim) |>/g' "$FILE1"
  
  # Fix the Create attack relationships line
  sed -i 's/# Create attack Enum\.map(relationships, attackers, fn attacker_id ->/# Create attack relationships\n      Enum.map(attackers, fn attacker_id ->/g' "$FILE1"
  
  # Fix the alliances pattern
  sed -i 's/alliances\s*Enum\.frequencies()/alliances |> Enum.frequencies()/g' "$FILE1"
  sed -i 's/Enum\.max_by(fn {_alliance, count} -> count end, fn -> {nil, 0} end) elem(0)/|> Enum.max_by(fn {_alliance, count} -> count end, fn -> {nil, 0} end) |> elem(0)/g' "$FILE1"
  
  # Fix the filtering pattern
  sed -i 's/Enum\.map() |> Enum\.filter(entities, fn entity ->/Enum.filter(entities, fn entity ->/g' "$FILE1"
fi

# Fix grouping.ex - it looks mostly correct now

# Fix battle_detector.ex  
FILE2="lib/eve_dmv/analytics/battle_detector.ex"
if [ -f "$FILE2" ]; then
  echo "Fixing $FILE2"
  # The battle_detector.ex file actually looks mostly correct now
fi

# Fix fleet_analyzer.ex
FILE3="lib/eve_dmv/analytics/fleet_analyzer.ex"
if [ -f "$FILE3" ]; then
  echo "Fixing $FILE3"
  # Already fixed the shield quote issue
fi

# Fix player_stats_engine.ex
FILE4="lib/eve_dmv/analytics/player_stats_engine.ex"
if [ -f "$FILE4" ]; then
  echo "Fixing $FILE4"
  # Already looks mostly correct
fi

echo "Running syntax check on fixed files..."
for file in "$FILE1" "$FILE2" "$FILE3" "$FILE4"; do
  if [ -f "$file" ]; then
    echo "Checking: $file"
    if ! elixir -c "$file" 2>/dev/null; then
      echo "  ❌ Syntax error in $file"
    else
      echo "  ✅ Syntax OK"
    fi
  fi
done

echo "=== Fix Complete ==="