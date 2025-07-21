#!/bin/bash

echo "=== Fixing Complex Parsing Patterns ==="

# Files with known parsing errors from the previous run
files_to_fix=(
  "lib/eve_dmv/analytics/battle_detector.ex"
  "lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/analyzers/attack_pattern_analyzer.ex"
  "lib/eve_dmv/analytics/battle_detector/grouping.ex"
  "lib/eve_dmv/analytics/fleet_analyzer.ex"
  "lib/eve_dmv/analytics/player_stats_engine.ex"
  # Add more files from the error output
)

# Function to check if file exists
check_file() {
  if [ ! -f "$1" ]; then
    echo "Warning: File not found - $1"
    return 1
  fi
  return 0
}

# Fix pattern: if |> Enum.empty?(list) -> if Enum.empty?(list)
fix_if_pipe_patterns() {
  local file=$1
  echo "  Fixing if |> patterns in $file"
  
  # Fix: if |> Enum.empty?(x) -> if Enum.empty?(x)
  sed -i 's/if[[:space:]]*|>[[:space:]]*Enum\.empty?(\([^)]*\))/if Enum.empty?(\1)/g' "$file"
  
  # Fix: if |> is_nil(x) -> if is_nil(x)
  sed -i 's/if[[:space:]]*|>[[:space:]]*is_nil(\([^)]*\))/if is_nil(\1)/g' "$file"
  
  # Fix: if |> length(x) -> if length(x)
  sed -i 's/if[[:space:]]*|>[[:space:]]*length(\([^)]*\))/if length(\1)/g' "$file"
  
  # Fix: if |> Map.get(x, y) -> if Map.get(x, y)
  sed -i 's/if[[:space:]]*|>[[:space:]]*\([A-Za-z0-9_\.]*\)(\([^)]*\))/if \1(\2)/g' "$file"
}

# Fix pattern: not |> Function(x) -> not Function(x)
fix_not_pipe_patterns() {
  local file=$1
  echo "  Fixing not |> patterns in $file"
  
  # Fix: not |> Enum.empty?(x) -> not Enum.empty?(x)
  sed -i 's/not[[:space:]]*|>[[:space:]]*Enum\.empty?(\([^)]*\))/not Enum.empty?(\1)/g' "$file"
  
  # Fix: not |> is_nil(x) -> not is_nil(x)
  sed -i 's/not[[:space:]]*|>[[:space:]]*is_nil(\([^)]*\))/not is_nil(\1)/g' "$file"
  
  # Fix generic: not |> Function(x) -> not Function(x)
  sed -i 's/not[[:space:]]*|>[[:space:]]*\([A-Za-z0-9_\.]*\)(\([^)]*\))/not \1(\2)/g' "$file"
}

# Fix pattern: case |> Function(x) -> case Function(x)
fix_case_pipe_patterns() {
  local file=$1
  echo "  Fixing case |> patterns in $file"
  
  # Fix: case |> Map.get(x, y) -> case Map.get(x, y)
  sed -i 's/case[[:space:]]*|>[[:space:]]*\([A-Za-z0-9_\.]*\)(\([^)]*\))/case \1(\2)/g' "$file"
}

# Fix malformed function concatenation: Enum.mapEnum.sum -> Enum.map |> Enum.sum
fix_malformed_concatenation() {
  local file=$1
  echo "  Fixing malformed function concatenation in $file"
  
  # Fix: Enum.mapEnum.sum -> Enum.map |> Enum.sum
  sed -i 's/Enum\.map[[:space:]]*Enum\./Enum.map |> Enum./g' "$file"
  sed -i 's/Enum\.filter[[:space:]]*Enum\./Enum.filter |> Enum./g' "$file"
  sed -i 's/Enum\.reduce[[:space:]]*Enum\./Enum.reduce |> Enum./g' "$file"
  sed -i 's/Enum\.flat_map[[:space:]]*Enum\./Enum.flat_map |> Enum./g' "$file"
  
  # Fix patterns where functions are incorrectly concatenated
  sed -i 's/\([A-Za-z0-9_]*\)\.\([a-z_]*\)\([A-Z][A-Za-z0-9_]*\)\.\([a-z_]*\)/\1.\2 |> \3.\4/g' "$file"
}

# Fix patterns from attack_pattern_analyzer.ex
fix_attack_pattern_specific() {
  local file=$1
  echo "  Fixing attack_pattern_analyzer specific issues in $file"
  
  # Fix: Enum.flat_map(attack_relationships, fn rel -> [rel.attacker, rel.victim] end) Enum.uniq()
  # Should have |> between end) and Enum.uniq()
  sed -i 's/end)[[:space:]]*Enum\./end) |> Enum./g' "$file"
  
  # Fix: Enum.map() |> Enum.map(entities, fn entity ->
  # Should be: entities |> Enum.map(fn entity ->
  sed -i 's/Enum\.map()[[:space:]]*|>[[:space:]]*Enum\.map(\([^,]*\),/\1 |> Enum.map(/g' "$file"
  
  # Fix: Enum.filter(attack_relationships, fn rel -> rel.attacker == entity end, & &1.victim
  # Should have ) |> Enum.map(& &1.victim)
  sed -i 's/end,[[:space:]]*&[[:space:]]*&1\.\([a-z_]*\)[[:space:]]*$/end) |> Enum.map(\& \&1.\1)/g' "$file"
  
  # Fix: Enum.filter() |> Enum.map(attack_relationships, fn rel -> rel.victim == entity end, & &1.attacker
  sed -i 's/Enum\.filter()[[:space:]]*|>[[:space:]]*Enum\.map(\([^,]*\), fn/Enum.filter(\1, fn/g' "$file"
  
  # Fix: Map.keys |> Enum.filter((entity1.targets), &Map.has_key?(entity2.targets, &1))
  # Should be: Map.keys(entity1.targets) |> Enum.filter(&Map.has_key?(entity2.targets, &1))
  sed -i 's/Map\.keys[[:space:]]*|>[[:space:]]*Enum\.filter((\([^)]*\)), \([^)]*\))/Map.keys(\1) |> Enum.filter(\2)/g' "$file"
}

# Fix battle_detector.ex specific patterns
fix_battle_detector_specific() {
  local file=$1
  echo "  Fixing battle_detector specific issues in $file"
  
  # Fix: timeline
  #      Enum.flat_map(&(&1[:sides] || []))
  # Should be: timeline |> Enum.flat_map(&(&1[:sides] || []))
  perl -i -pe 's/^(\s*)timeline\s*\n\s*Enum\./$1timeline |> Enum./g' "$file"
  
  # Fix: events
  #      Enum.map(& &1.timestamp)
  #      Enum.min(fn -> nil end)
  perl -i -0pe 's/events\s*\n(\s*)Enum\.map/events |>\n$1Enum.map/g' "$file"
  perl -i -0pe 's/Enum\.map\([^)]*\)\s*\n(\s*)Enum\./Enum.map($1) |>\n$1Enum./g' "$file"
}

# Fix grouping.ex specific patterns
fix_grouping_specific() {
  local file=$1
  echo "  Fixing grouping specific issues in $file"
  
  # Fix: hash_input |> then(&:crypto.hash(:md5, &1))
  #      |> String.slice(Base.encode16(), 0, 8)
  # Should be: |> Base.encode16() |> String.slice(0, 8)
  sed -i 's/|>[[:space:]]*String\.slice(Base\.encode16(), \([0-9]*\), \([0-9]*\))/|> Base.encode16() |> String.slice(\1, \2)/g' "$file"
}

# Fix fleet_analyzer.ex specific patterns
fix_fleet_analyzer_specific() {
  local file=$1
  echo "  Fixing fleet_analyzer specific issues in $file"
  
  # Fix: dominant_tank: if(armor_ratio > shield_ratio, do: "armor", else: "shield)"),
  # Should be: dominant_tank: if(armor_ratio > shield_ratio, do: "armor", else: "shield"),
  sed -i 's/else:[[:space:]]*"shield)"/else: "shield"/g' "$file"
}

# Fix patterns where reduce has incorrect arguments
fix_reduce_patterns() {
  local file=$1
  echo "  Fixing reduce patterns in $file"
  
  # Fix: |> Enum.reduce(entity_patterns, {groups, unassigned}, fn entity,
  # Should be: Enum.reduce(entity_patterns, {[], unassigned}, fn entity,
  perl -i -pe 's/\|>\s*Enum\.reduce\(entity_patterns, \{groups, unassigned\}/Enum.reduce(entity_patterns, {[], unassigned}/g' "$file"
}

# Process all files
total_files=${#files_to_fix[@]}
fixed_count=0

for file in "${files_to_fix[@]}"; do
  if check_file "$file"; then
    echo "Processing: $file"
    
    # Create backup
    cp "$file" "$file.bak"
    
    # Apply all fixes
    fix_if_pipe_patterns "$file"
    fix_not_pipe_patterns "$file"
    fix_case_pipe_patterns "$file"
    fix_malformed_concatenation "$file"
    fix_attack_pattern_specific "$file"
    fix_battle_detector_specific "$file"
    fix_grouping_specific "$file"
    fix_fleet_analyzer_specific "$file"
    fix_reduce_patterns "$file"
    
    # Check if file was actually modified
    if ! diff -q "$file" "$file.bak" > /dev/null; then
      ((fixed_count++))
      echo "  ✓ Fixed"
      rm "$file.bak"
    else
      echo "  - No changes needed"
      rm "$file.bak"
    fi
  fi
done

echo ""
echo "=== Summary ==="
echo "Files processed: $total_files"
echo "Files fixed: $fixed_count"
echo ""
echo "Now running Credo to check for remaining parsing errors..."
mix credo list --only=Credo.Check.Readability.ParenthesesOnZeroArityDefs,Credo.Check.Readability.ParenthesesInCondition,Credo.Check.Consistency.LineEndings | grep -E "(Parsing|Error|Warning)" | head -20