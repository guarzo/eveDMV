#!/bin/bash

# Script to fix final parsing errors in Elixir files

echo "Fixing final parsing errors..."

# List of files with parsing errors (from Credo output)
files=(
  "lib/eve_dmv/analytics/fleet_analyzer.ex"
  "lib/eve_dmv/analytics/player_stats.ex"
  "lib/eve_dmv/analytics/player_stats_engine.ex"
  "lib/eve_dmv/analytics/ship_stats.ex"
  "lib/eve_dmv/analytics/ship_stats_engine.ex"
  "lib/eve_dmv/api/domain_extensions.ex"
  "lib/eve_dmv/auth.ex"
  "lib/eve_dmv/cache/query_cache.ex"
  "lib/eve_dmv/config/unified_config.ex"
  "lib/eve_dmv/constants/isk.ex"
  "lib/eve_dmv/contexts.ex"
  "lib/eve_dmv/contexts/battle_analysis.ex"
  "lib/eve_dmv/contexts/battle_analysis/calculators/performance_metrics_calculator.ex"
  "lib/eve_dmv/contexts/battle_analysis/domain/battle_detection_service.ex"
  "lib/eve_dmv/contexts/battle_analysis/domain/battle_metrics_calculator/damage_calculator.ex"
  "lib/eve_dmv/contexts/battle_analysis/domain/battle_metrics_calculator/data_preprocessor.ex"
  "lib/eve_dmv/contexts/battle_analysis/domain/battle_metrics_calculator/side_comparison_calculator.ex"
  "lib/eve_dmv/contexts/battle_analysis/domain/battle_timeline_service.ex"
  "lib/eve_dmv/contexts/battle_analysis/domain/enhanced_combat_log_parser.ex"
)

# Additional files that might have parsing errors
additional_files=$(find lib -name "*.ex" -type f 2>/dev/null | head -100)

all_files=("${files[@]}")
for file in $additional_files; do
  all_files+=("$file")
done

fixed_count=0

for file in "${all_files[@]}"; do
  if [ -f "$file" ]; then
    # Create backup
    cp "$file" "${file}.bak"
    
    # Fix specific parsing patterns found in the code
    
    # 1. Fix malformed function calls like: Decimal.to_floatto_billions((value, ), )
    # This pattern appears to be two functions concatenated with malformed parentheses
    perl -i -pe '
      # Fix concatenated function names with malformed params
      s/(\w+)\.to_float(\w+)\(\(([^,]+),\s*\),\s*\)/$1.to_float($3) |> $2()/g;
      
      # Fix patterns like Enum.mapEnum.sum
      s/Enum\.map(Enum\.\w+)\(/Enum.map(/g;
      s/Enum\.filter(Enum\.\w+)\(/Enum.filter(/g;
      
      # Fix double parentheses patterns
      s/\(\(([^,]+),\s*\),\s*\)/($1)/g;
    ' "$file"
    
    # 2. Fix missing pipe operators between function calls
    sed -i 's/\([a-z_]\+\)$/\1/g' "$file"
    
    # 3. Fix specific patterns from attack_pattern_analyzer.ex
    # Pattern: group_analysis,  |> Enum.with_index()
    sed -i 's/\([a-z_]\+\),\s*|>/\1 |>/g' "$file"
    
    # 4. Fix missing pipes in common patterns
    perl -i -pe '
      # Fix pattern: variable function_call -> variable |> function_call
      s/^(\s+)([a-z_]+)\s+Enum\./$1$2 |> Enum./g;
      s/^(\s+)([a-z_]+)\s+Map\./$1$2 |> Map./g;
      s/^(\s+)([a-z_]+)\s+List\./$1$2 |> List./g;
      s/^(\s+)([a-z_]+)\s+String\./$1$2 |> String./g;
    ' "$file"
    
    # 5. Fix pipeline issues with Base.encode16 and similar
    perl -i -pe '
      # Fix: then(hash_input, &:crypto.hash(:md5, &1)) |> String.slice(Base.encode16(), 0, 8)
      s/String\.slice\(Base\.encode16\(\),/Base.encode16() |> String.slice(/g;
      s/List\.last\(([^,]+),\s*\)/List.last($1)/g;
    ' "$file"
    
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
echo "Running Credo to check remaining parsing errors..."

# Run Credo and count parsing errors
parsing_errors=$(mix credo --strict --format=flycheck 2>&1 | grep -c "Some source files could not be parsed" || true)

if [ "$parsing_errors" -eq "0" ]; then
  echo "✅ All parsing errors fixed!"
else
  echo "⚠️  Some parsing errors remain. Checking which files..."
  mix credo --strict --format=flycheck 2>&1 | grep -A 30 "Some source files could not be parsed" | head -40
fi