#!/usr/bin/env elixir

# Debug script to understand battle detection logic
Mix.install([
  :jason,
  :postgrex
])

# Connect to database
{:ok, pid} =
  Postgrex.start_link(
    hostname: "db",
    username: "postgres",
    password: "postgres",
    database: "eve_tracker_gamma"
  )

# Get recent killmails with attacker data
{:ok, result} =
  Postgrex.query(
    pid,
    """
      SELECT killmail_id, killmail_time, solar_system_id, victim_character_id, victim_ship_type_id, raw_data
      FROM killmails_raw 
      WHERE killmail_time >= NOW() - INTERVAL '2 hours'
      ORDER BY killmail_time DESC
      LIMIT 100
    """,
    []
  )

IO.puts("Found #{length(result.rows)} killmails in the last 2 hours")

# Simulate the battle detection clustering logic
defmodule BattleClusterer do
  def cluster_killmails(killmails) do
    killmails
    |> Enum.sort_by(fn [_id, time, _sys, _char, _ship, _raw] -> time end)
    |> Enum.reduce([], fn killmail, clusters ->
      # 10 minute max gap
      add_to_cluster(killmail, clusters, 10)
    end)
    |> Enum.map(&Map.put(&1, :killmails, Enum.reverse(&1.killmails)))
  end

  defp add_to_cluster(killmail, [], _max_time_gap) do
    [_id, time, system_id, _char, _ship, _raw] = killmail
    [%{killmails: [killmail], start_time: time, end_time: time, system_id: system_id}]
  end

  defp add_to_cluster(killmail, [current_cluster | rest_clusters], max_time_gap_minutes) do
    [_id, time, system_id, _char, _ship, _raw] = killmail
    time_gap_minutes = NaiveDateTime.diff(time, current_cluster.end_time, :second) / 60

    can_add_to_cluster =
      time_gap_minutes <= max_time_gap_minutes and
        system_id == current_cluster.system_id

    if can_add_to_cluster do
      # Add to current cluster
      updated_cluster = %{
        current_cluster
        | killmails: [killmail | current_cluster.killmails],
          end_time: time
      }

      [updated_cluster | rest_clusters]
    else
      # Start new cluster
      new_cluster = %{
        killmails: [killmail],
        start_time: time,
        end_time: time,
        system_id: system_id
      }

      [new_cluster, current_cluster | rest_clusters]
    end
  end

  def count_unique_participants(killmails) do
    participants =
      killmails
      |> Enum.flat_map(&extract_participants/1)
      |> Enum.uniq()

    length(participants)
  end

  defp extract_participants([_id, _time, _sys, victim_char_id, _ship, raw_data]) do
    participants = if victim_char_id, do: [victim_char_id], else: []

    # Extract attacker character IDs from raw_data
    attackers =
      case raw_data do
        %{"attackers" => attackers} when is_list(attackers) ->
          attackers
          |> Enum.map(& &1["character_id"])
          |> Enum.filter(&(&1 != nil))
          |> Enum.map(fn
            id when is_binary(id) -> String.to_integer(id)
            id when is_integer(id) -> id
          end)

        _ ->
          []
      end

    participants ++ attackers
  end

  def calculate_duration_minutes(killmails) do
    case killmails do
      [] ->
        0

      # Single kill battles have minimum 1 minute duration
      [_single] ->
        1

      multiple ->
        times = Enum.map(multiple, fn [_id, time, _sys, _char, _ship, _raw] -> time end)
        start_time = Enum.min(times)
        end_time = Enum.max(times)
        duration = NaiveDateTime.diff(end_time, start_time, :second) / 60
        # Ensure minimum 1 minute duration for battles
        max(duration, 1)
    end
  end
end

# Cluster killmails into battles
battles = BattleClusterer.cluster_killmails(result.rows)

IO.puts("\nFound #{length(battles)} potential battle clusters")

# Analyze each cluster
Enum.with_index(battles, fn battle, index ->
  participant_count = BattleClusterer.count_unique_participants(battle.killmails)
  duration = BattleClusterer.calculate_duration_minutes(battle.killmails)

  IO.puts("\nBattle #{index + 1}:")
  IO.puts("  System: #{battle.system_id}")
  IO.puts("  Killmails: #{length(battle.killmails)}")
  IO.puts("  Participants: #{participant_count}")
  IO.puts("  Duration: #{:erlang.float_to_binary(duration * 1.0, [{:decimals, 2}])} minutes")
  IO.puts("  Passes 3-minute filter: #{duration >= 3}")
  IO.puts("  Passes participant filter: #{participant_count >= 2}")
  IO.puts("  Passes significant battle filter: #{length(battle.killmails) > 1 and duration >= 3}")

  # Show first few killmails
  IO.puts("  First few killmails:")

  battle.killmails
  |> Enum.take(3)
  |> Enum.each(fn [id, time, _sys, _char, _ship, _raw] ->
    IO.puts("    #{id} at #{time}")
  end)
end)

# Count battles that pass the filters
significant_battles =
  Enum.filter(battles, fn battle ->
    participant_count = BattleClusterer.count_unique_participants(battle.killmails)
    duration = BattleClusterer.calculate_duration_minutes(battle.killmails)

    length(battle.killmails) > 1 and duration >= 3 and participant_count >= 2
  end)

IO.puts("\n=== SUMMARY ===")
IO.puts("Total battle clusters: #{length(battles)}")

IO.puts(
  "Significant battles (>1 kill, >=3 min, >=2 participants): #{length(significant_battles)}"
)

if length(significant_battles) == 0 do
  IO.puts("\nNo significant battles found! This explains why the UI shows no battles.")
  IO.puts("Reasons battles might be filtered out:")

  single_kill_battles = Enum.count(battles, fn b -> length(b.killmails) == 1 end)

  short_battles =
    Enum.count(battles, fn b ->
      BattleClusterer.calculate_duration_minutes(b.killmails) < 3
    end)

  few_participants =
    Enum.count(battles, fn b ->
      BattleClusterer.count_unique_participants(b.killmails) < 2
    end)

  IO.puts("- Single kill battles: #{single_kill_battles}")
  IO.puts("- Battles under 3 minutes: #{short_battles}")
  IO.puts("- Battles with <2 participants: #{few_participants}")
end
