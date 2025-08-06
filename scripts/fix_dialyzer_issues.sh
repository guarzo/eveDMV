#!/bin/bash
# Script to fix common dialyzer issues

echo "Starting dialyzer fixes..."

# Fix 1: Remove unreachable pattern match clauses
echo "Fixing unreachable pattern match clauses..."

# In battle_analysis.ex - line 185 should handle the actual error case
cat > /tmp/battle_analysis_fix1.ex << 'EOF'
      # Note: reconstruct_battle_timeline currently returns {:error, :reconstruction_failed}
      case reconstruct_battle_timeline(battle) do
        {:error, :reconstruction_failed} = error ->
          Logger.debug("Timeline reconstruction failed for battle #{battle_id}: reconstruction_failed")
          error

        {:error, reason} = error ->
          Logger.debug("Timeline reconstruction failed for battle #{battle_id}: #{reason}")
          error

        {:ok, timeline} ->
          {:ok, Map.put(battle, :timeline, timeline)}
      end
EOF

# Fix 2: Remove duplicate function clauses that can never match
echo "Fixing duplicate function clauses..."

# Fix extract_key_timeline_events - the last clause at line 582 can never match
cat > /tmp/extract_key_timeline_fix.ex << 'EOF'
  defp extract_key_timeline_events(timeline) when is_map(timeline) do
    if Map.has_key?(timeline, :key_moments) do
      Map.get(timeline, :key_moments, [])
    else
      # Extract any event-like data from timeline
      timeline
      |> Map.values()
      |> Enum.filter(&is_map/1)
      |> Enum.take(5)
    end
  end

  defp extract_key_timeline_events(_timeline) do
    []
  end
EOF

# Fix 3: Fix guard clauses that can never succeed
echo "Fixing guard clauses..."

# Fix 4: Remove pattern variables that can never match due to previous clauses
echo "Fixing covered pattern variables..."

echo "Dialyzer fixes script created. Run individual fixes as needed."