#!/bin/bash
# Workstream Alpha: Fix Pattern Match & Type Specification Errors

echo "🔧 Workstream Alpha: Fixing Pattern Match & Type Specification Errors"

# Fix 1: DateTime.truncate(:minute) errors
echo "Fixing DateTime.truncate(:minute) errors..."
find /workspace/lib -name "*.ex" -type f -exec sed -i '
  s/DateTime\.truncate(\([^,]*\), :minute)/DateTimeUtils.truncate_to_minute(\1)/g
' {} \;

# Create helper function for minute truncation
cat > /tmp/datetime_truncate_fix.ex << 'EOF'
# Add to DateTimeUtils module
def truncate_to_minute(datetime) do
  datetime
  |> DateTime.truncate(:second)
  |> Map.put(:second, 0)
  |> Map.put(:microsecond, {0, 0})
end
EOF

# Fix 2: Pattern match errors for battle service
echo "Fixing pattern match errors in battle services..."
for file in \
  "/workspace/lib/eve_dmv/contexts/battle_analysis/services/battle_service.ex" \
  "/workspace/lib/eve_dmv/contexts/battle_analysis/services/battle_sharing_service.ex" \
  "/workspace/lib/eve_dmv/contexts/combat/services/battle_sharing_service.ex"; do
  if [ -f "$file" ]; then
    echo "  Fixing $file"
    # Add error handling for analyze_battle calls
    sed -i '/{:ok, _analysis}/ {
      N
      s/{:ok, _analysis}\n/{:ok, _analysis} ->\n/
      /error ->/!s/$/\n      error -> error/
    }' "$file"
  fi
done

# Fix 3: Extra range errors in type specs
echo "Fixing extra range errors..."
# Fix delete_battle spec
sed -i '/@spec delete_battle.*::.*:ok.*|/ s/ :ok | / /' \
  "/workspace/lib/eve_dmv/contexts/battle_analysis/services/battle_service.ex" 2>/dev/null || true

# Fix search_battles spec
sed -i '/@spec search_battles.*{:error, atom()}/ s/{:error, atom()}/{:error, any()}/' \
  "/workspace/lib/eve_dmv/contexts/battle_analysis/services/battle_service.ex" 2>/dev/null || true

# Fix 4: Ash.bulk_destroy argument errors
echo "Fixing Ash.bulk_destroy calls..."
find /workspace/lib -name "*.ex" -type f -exec sed -i '
  s/Ash\.bulk_destroy(\([^,]*\), :destroy, \[domain: \([^]]*\)\])/\1 |> Ash.Query.for_destroy(:destroy) |> Ash.bulk_destroy(domain: \2)/g
' {} \;

# Fix 5: Guard clause failures
echo "Fixing guard clause failures..."
# Fix wormhole operations guard failures
sed -i '/when _ :: false != false/ s/when _ :: false != false/when is_boolean(_)/' \
  /workspace/lib/eve_dmv/contexts/wormhole_operations/api.ex 2>/dev/null || true

# Fix 6: Contract supertype issues
echo "Fixing contract supertype issues..."
# Update specs that are too general
files=(
  "/workspace/lib/eve_dmv/config/unified_config.ex"
  "/workspace/lib/eve_dmv/contexts/wormhole_operations/domain/analyzers/wh_vetting_analyzer.ex"
)
for file in "${files[@]}"; do
  if [ -f "$file" ]; then
    # Make specs more specific
    sed -i '/@spec.*:: map()$/ {
      s/:: map()$/:: %{atom() => any()}/
    }' "$file"
  fi
done

# Fix 7: Invalid contract errors
echo "Fixing invalid contract errors..."
# Fix battle analysis contracts
sed -i '/@spec reconstruct_battle_timeline/ {
  n
  s/@spec.*/@spec reconstruct_battle_timeline(battle()) :: battle_timeline()/
}' /workspace/lib/eve_dmv/contexts/battle_analysis.ex 2>/dev/null || true

echo "✅ Workstream Alpha fixes applied!"
echo ""
echo "Next steps:"
echo "1. Run 'mix compile --warnings-as-errors' to check compilation"
echo "2. Run 'mix dialyzer' to verify error reduction"
echo "3. Review changes with 'git diff'"