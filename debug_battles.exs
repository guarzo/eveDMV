#!/usr/bin/env elixir

# Debug script to understand battle detection
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

# Get recent killmails
{:ok, result} =
  Postgrex.query(
    pid,
    """
      SELECT killmail_id, killmail_time, solar_system_id, victim_character_id, victim_ship_type_id
      FROM killmails_raw 
      WHERE killmail_time >= NOW() - INTERVAL '2 hours'
      ORDER BY killmail_time DESC
      LIMIT 50
    """,
    []
  )

IO.puts("Found #{length(result.rows)} killmails in the last 2 hours")

# Group by system and time to understand clustering
killmails_by_system =
  result.rows
  |> Enum.group_by(fn [_id, _time, system_id, _char, _ship] -> system_id end)

IO.puts("\nKillmails by system:")

Enum.each(killmails_by_system, fn {system_id, killmails} ->
  IO.puts("System #{system_id}: #{length(killmails)} killmails")

  # Check time gaps between killmails in this system
  times = killmails |> Enum.map(fn [_id, time, _sys, _char, _ship] -> time end) |> Enum.sort()

  if length(times) > 1 do
    time_gaps =
      times
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [t1, t2] ->
        NaiveDateTime.diff(t2, t1, :second) / 60
      end)

    if length(time_gaps) > 0 do
      max_gap = Enum.max(time_gaps)
      IO.puts("  Max time gap: #{max_gap} minutes")
    end
  end
end)

# Check for systems with multiple killmails close in time
potential_battles =
  killmails_by_system
  |> Enum.filter(fn {_system_id, killmails} -> length(killmails) > 1 end)
  |> Enum.map(fn {system_id, killmails} ->
    times = killmails |> Enum.map(fn [_id, time, _sys, _char, _ship] -> time end) |> Enum.sort()

    if length(times) > 1 do
      duration = NaiveDateTime.diff(List.last(times), List.first(times), :second) / 60
      {system_id, length(killmails), duration}
    else
      {system_id, length(killmails), 0}
    end
  end)

IO.puts("\nPotential battles:")

Enum.each(potential_battles, fn {system_id, kill_count, duration} ->
  IO.puts("System #{system_id}: #{kill_count} kills over #{Float.round(duration, 1)} minutes")
end)
