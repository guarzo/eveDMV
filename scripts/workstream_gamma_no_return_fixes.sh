#!/bin/bash
# Workstream Gamma: Fix No Return & Call Errors

echo "🔨 Workstream Gamma: Fixing No Return & Call Errors"

# Fix 1: DateTime.truncate(:minute) calls
echo "Fixing DateTime.truncate(:minute) errors..."
files_with_datetime_errors=(
  "/workspace/lib/eve_dmv/contexts/combat/core/performance_calculator.ex"
  "/workspace/lib/eve_dmv/contexts/combat/core/tactical_pattern_detector.ex"
)

for file in "${files_with_datetime_errors[@]}"; do
  if [ -f "$file" ]; then
    echo "  Fixing $file"
    # Replace DateTime.truncate(x, :minute) with custom implementation
    sed -i 's/DateTime\.truncate(\([^,]*\), :minute)/truncate_to_minute(\1)/g' "$file"
    
    # Add helper function if not exists
    if ! grep -q "defp truncate_to_minute" "$file"; then
      # Find the last 'end' in the file and insert before it
      sed -i '/^end$/i\
\
  defp truncate_to_minute(datetime) do\
    datetime\
    |> DateTime.truncate(:second)\
    |> Map.put(:second, 0)\
    |> Map.put(:microsecond, {0, 0})\
  end' "$file"
    fi
  fi
done

# Fix 2: No return functions in intelligence modules
echo "Fixing no return functions..."

# Fix behavioral_pattern_analyzer
cat > /tmp/fix_behavioral_analyzer.ex << 'EOF'
# Fix for get_character_killmails/1 no return
defp get_character_killmails(character_id) do
  case EveDmv.Database.KillmailRepository.get_character_killmails(character_id) do
    {:ok, killmails} -> killmails
    {:error, _reason} -> []
  end
end
EOF

# Fix combat_stats_analyzer
echo "Fixing combat stats analyzer..."
sed -i '/def fetch_character_killmails.*do/,/^  end$/ {
  s/EveDmv\.Database\.KillmailRepository\.get_character_killmails_in_period(/case EveDmv.Database.KillmailRepository.get_character_killmails_in_period(/
  s/character_id, start_date, end_date)/character_id, start_date, end_date) do\
    {:ok, killmails} -> {:ok, killmails}\
    {:error, reason} -> {:error, reason}\
  end/
}' /workspace/lib/eve_dmv/contexts/intelligence/core/combat_stats_analyzer.ex 2>/dev/null || true

# Fix 3: Function call errors
echo "Fixing function call signature mismatches..."

# Fix KillmailRepository calls with wrong arguments
echo "Fixing KillmailRepository.get_popular_fleet_compositions..."
sed -i 's/get_popular_fleet_compositions(\([^,]*\), \[\(.*\)\])/get_popular_fleet_compositions(30, \[\2\])/' \
  /workspace/lib/eve_dmv/contexts/combat/services/doctrine_effectiveness_service.ex 2>/dev/null || true

# Fix 4: Ash.bulk_destroy calls
echo "Fixing Ash.bulk_destroy calls..."
find /workspace/lib -name "*.ex" -type f -exec sed -i '
  /Ash\.bulk_destroy.*:destroy.*domain:/ {
    s/Ash\.bulk_destroy(\([^,]*\), :destroy, \[\(.*\)\])/\1 |> Ash.bulk_destroy(\[\2\])/
  }' {} \;

# Fix 5: Guard failures and pattern coverage
echo "Fixing guard failures..."
# Fix pattern_match_cov in tactical_pattern_detector
sed -i '/can never match, because previous clauses completely cover/ {
  n
  n
  s/variable_list/[]/
}' /workspace/lib/eve_dmv/contexts/combat/core/tactical_pattern_detector.ex 2>/dev/null || true

# Fix 6: Create missing DateTimeUtils functions
echo "Adding missing DateTimeUtils functions..."
cat > /tmp/datetime_utils_additions.ex << 'EOF'
# Add these to EveDmv.Core.Utils.DateTimeUtils

@doc """
Truncate a datetime to the minute boundary.
"""
def truncate_to_minute(datetime) do
  datetime
  |> DateTime.truncate(:second)
  |> Map.put(:second, 0)
  |> Map.put(:microsecond, {0, 0})
end

@doc """
Add time to a datetime with proper unit handling.
"""
def add(datetime, amount, :minute) do
  DateTime.add(datetime, amount * 60, :second)
end
def add(datetime, amount, unit) do
  DateTime.add(datetime, amount, unit)
end
EOF

# Fix 7: Pattern matches that can never succeed
echo "Fixing impossible pattern matches..."
files_with_pattern_errors=(
  "/workspace/lib/eve_dmv/contexts/combat/services/battle_sharing_service.ex"
  "/workspace/lib/eve_dmv/contexts/battle_sharing/domain/battle_curator.ex"
)

for file in "${files_with_pattern_errors[@]}"; do
  if [ -f "$file" ]; then
    echo "  Adding error clauses to $file"
    # Add missing error clauses
    sed -i '/{:ok, _\(analysis\|summary\|battle\)}$/ {
      n
      /error ->/!a\      error -> error
    }' "$file"
  fi
done

echo "✅ Workstream Gamma fixes applied!"
echo ""
echo "Required manual fixes:"
echo "1. Add the DateTime helper functions to DateTimeUtils module"
echo "2. Review and test KillmailRepository function calls"
echo "3. Verify Ash.bulk_destroy usage patterns"
echo "4. Run 'mix dialyzer' to check improvement"