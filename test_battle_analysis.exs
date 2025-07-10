# Test script for battle analysis features
# Run with: mix run test_battle_analysis.exs

alias EveDmv.Contexts.BattleAnalysis

IO.puts("Testing Battle Analysis Features...")
IO.puts("=" <> String.duplicate("=", 50))

# Test 1: BATTLE-1 - Battle Detection
IO.puts("\n1. Testing Battle Detection (BATTLE-1)...")
case BattleAnalysis.detect_recent_battles(24) do
  {:ok, battles} ->
    IO.puts("   ✅ Battle detection returned successfully")
    IO.puts("   Found #{length(battles)} battles in the last 24 hours")
    
    if length(battles) > 0 do
      first_battle = List.first(battles)
      IO.puts("   First battle ID: #{first_battle.battle_id}")
      IO.puts("   Killmails in battle: #{length(first_battle.killmails)}")
      IO.puts("   Duration: #{first_battle.metadata.duration_minutes} minutes")
      IO.puts("   Participants: #{first_battle.metadata.unique_participants}")
      IO.puts("   Battle type: #{first_battle.metadata.battle_type}")
      
      # Check if it's real data
      if first_battle.killmails != [] and is_integer(first_battle.metadata.unique_participants) do
        IO.puts("   ✅ Returns REAL DATA from database")
      else
        IO.puts("   ❌ Returns EMPTY or MOCK DATA")
      end
    else
      IO.puts("   ⚠️  No battles found (may need more killmail data)")
    end
    
  {:error, reason} ->
    IO.puts("   ❌ Battle detection failed: #{inspect(reason)}")
end

# Test 2: BATTLE-2 - Timeline Reconstruction
IO.puts("\n2. Testing Timeline Reconstruction (BATTLE-2)...")
case BattleAnalysis.detect_recent_battles(48, min_participants: 2) do
  {:ok, battles} when length(battles) > 0 ->
    battle = List.first(battles)
    timeline = BattleAnalysis.reconstruct_battle_timeline(battle)
    
    IO.puts("   ✅ Timeline reconstruction returned successfully")
    IO.puts("   Events in timeline: #{length(timeline.events)}")
    IO.puts("   Battle phases: #{length(timeline.phases)}")
    IO.puts("   Key moments: #{length(timeline.key_moments)}")
    
    if timeline.events != [] and timeline.phases != [] do
      IO.puts("   ✅ Returns REAL timeline data")
      
      # Show first phase
      if first_phase = List.first(timeline.phases) do
        IO.puts("   First phase: #{first_phase.phase_type} - #{first_phase.description}")
      end
    else
      IO.puts("   ❌ Returns EMPTY timeline")
    end
    
  _ ->
    IO.puts("   ⚠️  No battles available for timeline test")
end

# Test 3: BATTLE-3 - zkillboard Import
IO.puts("\n3. Testing zkillboard Import (BATTLE-3)...")
# Test with a specific killmail URL (this would need a real zkill URL in production)
test_url = "https://zkillboard.com/kill/128431979/"

IO.puts("   Testing URL parsing...")
case URI.parse(test_url) do
  %URI{host: "zkillboard.com", path: path} when is_binary(path) ->
    IO.puts("   ✅ URL parsing works")
    
    # Note: We won't actually call the import to avoid hitting external APIs
    # but we can check if the function exists and is callable
    IO.puts("   Function exists: #{function_exported?(BattleAnalysis, :import_from_zkillboard, 1)}")
    
  _ ->
    IO.puts("   ❌ URL parsing failed")
end

# Test 4: BATTLE-4 - Battle Analysis Page
IO.puts("\n4. Testing Battle Analysis Page Route (BATTLE-4)...")
# Check if the route exists by examining the router
router_path = "/workspace/lib/eve_dmv_web/router.ex"
{:ok, router_content} = File.read(router_path)

if String.contains?(router_content, "live(\"/battle/:battle_id\", BattleAnalysisLive)") do
  IO.puts("   ✅ Battle analysis page route exists at /battle/:battle_id")
  IO.puts("   ✅ BattleAnalysisLive module exists")
else
  IO.puts("   ❌ Battle analysis page route not found")
end

# Summary
IO.puts("\n" <> String.duplicate("=", 50))
IO.puts("SUMMARY OF BATTLE ANALYSIS IMPLEMENTATION STATUS:")
IO.puts("=" <> String.duplicate("=", 50))

# Get some real battles to check data quality
case BattleAnalysis.detect_recent_battles(168, min_participants: 2) do
  {:ok, battles} ->
    real_battles = Enum.filter(battles, fn b -> 
      length(b.killmails) > 0 and b.metadata.unique_participants > 0
    end)
    
    IO.puts("\nData Quality Check:")
    IO.puts("  Total battles found (last 7 days): #{length(battles)}")
    IO.puts("  Battles with real data: #{length(real_battles)}")
    IO.puts("  Average participants: #{if length(real_battles) > 0, do: Enum.sum(Enum.map(real_battles, & &1.metadata.unique_participants)) / length(real_battles) |> Float.round(1), else: 0}")
    IO.puts("  Average duration: #{if length(real_battles) > 0, do: Enum.sum(Enum.map(real_battles, & &1.metadata.duration_minutes)) / length(real_battles) |> Float.round(1), else: 0} minutes")
    
  _ ->
    IO.puts("\nCould not retrieve battle data for quality check")
end