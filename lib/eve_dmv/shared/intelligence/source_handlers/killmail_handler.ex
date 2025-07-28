defmodule EveDmv.Shared.Intelligence.SourceHandlers.KillmailHandler do
  @moduledoc """
  Handles killmail-specific intelligence processing.

  Responsible for extracting meaningful intelligence from killmail data,
  including threat indicators, activity patterns, and engagement analysis.
  """

  require Logger

  @doc """
  Processes raw killmail data into structured intelligence.
  """
  def process_killmail_data(data) do
    killmails = Map.get(data, :killmails, [])

    %{
      processed: true,
      source_type: :killmails,
      summary: %{
        total_kills: length(killmails),
        active_systems: extract_active_systems(killmails),
        unique_participants: count_unique_participants(killmails),
        total_value_destroyed: calculate_total_value_destroyed(killmails),
        timeline: build_timeline(killmails)
      },
      threat_indicators: extract_threat_indicators(killmails),
      patterns: analyze_patterns(killmails),
      reliability: 0.95
    }
  end

  @doc """
  Extracts active systems from killmail data.
  """
  def extract_active_systems(killmails) do
    killmails
    |> Enum.map(& &1.solar_system_id)
    |> Enum.uniq()
    |> Enum.map(fn system_id ->
      kill_count = Enum.count(killmails, &(&1.solar_system_id == system_id))

      %{
        system_id: system_id,
        kill_count: kill_count,
        activity_level: classify_activity_level(kill_count)
      }
    end)
  end

  @doc """
  Counts unique participants across all killmails.
  """
  def count_unique_participants(killmails) do
    victim_ids = Enum.map(killmails, & &1.victim.character_id)

    attacker_ids =
      killmails
      |> Enum.flat_map(& &1.attackers)
      |> Enum.map(& &1.character_id)
      |> Enum.reject(&is_nil/1)

    unique_ids = Enum.uniq(victim_ids ++ attacker_ids)

    %{
      total: length(unique_ids),
      victims: length(Enum.uniq(victim_ids)),
      attackers: length(Enum.uniq(attacker_ids))
    }
  end

  @doc """
  Calculates total ISK value destroyed.
  """
  def calculate_total_value_destroyed(killmails) do
    killmails
    |> Enum.map(&Map.get(&1, :zkb_total_value, 0))
    |> Enum.sum()
  end

  @doc """
  Builds activity timeline from killmails.
  """
  def build_timeline(killmails) do
    killmails
    |> Enum.sort_by(& &1.occurred_at, DateTime)
    |> Enum.map(fn killmail ->
      %{
        timestamp: killmail.occurred_at,
        system_id: killmail.solar_system_id,
        participants: count_participants(killmail),
        value: Map.get(killmail, :zkb_total_value, 0),
        ship_type: get_ship_type(killmail),
        is_capital: is_capital_kill?(killmail),
        is_pod: is_pod_kill?(killmail)
      }
    end)
  end

  @doc """
  Extracts threat indicators from killmail patterns.
  """
  def extract_threat_indicators(killmails) do
    %{
      capital_kills: count_capital_kills(killmails),
      fleet_engagements: detect_fleet_engagements(killmails),
      pod_kills: count_pod_kills(killmails),
      structure_kills: count_structure_kills(killmails),
      hotdrop_indicators: detect_hotdrop_patterns(killmails),
      sustained_camping: detect_camping_patterns(killmails)
    }
  end

  @doc """
  Analyzes patterns in killmail data.
  """
  def analyze_patterns(killmails) do
    %{
      peak_activity_times: find_peak_activity_times(killmails),
      common_ship_types: analyze_ship_usage(killmails),
      engagement_sizes: categorize_engagement_sizes(killmails),
      geographic_concentration: analyze_geographic_patterns(killmails)
    }
  end

  # Private helper functions

  defp classify_activity_level(kill_count) do
    cond do
      kill_count >= 20 -> :very_high
      kill_count >= 10 -> :high
      kill_count >= 5 -> :medium
      kill_count >= 1 -> :low
      true -> :none
    end
  end

  defp count_participants(killmail) do
    victim_count = 1
    attacker_count = length(killmail.attackers)
    victim_count + attacker_count
  end

  defp get_ship_type(killmail) do
    killmail.victim.ship_type_id
  end

  defp is_capital_kill?(killmail) do
    # In production, would check against actual capital ship type IDs
    ship_type_id = killmail.victim.ship_type_id
    ship_type_id >= 20000 && ship_type_id <= 30000
  end

  defp is_pod_kill?(killmail) do
    # Capsule type ID is typically 670
    killmail.victim.ship_type_id == 670
  end

  defp count_capital_kills(killmails) do
    Enum.count(killmails, &is_capital_kill?/1)
  end

  defp detect_fleet_engagements(killmails) do
    killmails
    |> Enum.filter(fn km -> length(km.attackers) >= 5 end)
    |> length()
  end

  defp count_pod_kills(killmails) do
    Enum.count(killmails, &is_pod_kill?/1)
  end

  defp count_structure_kills(killmails) do
    # In production, would check against structure type IDs
    Enum.count(killmails, fn km ->
      ship_type_id = km.victim.ship_type_id
      ship_type_id >= 35000 && ship_type_id <= 40000
    end)
  end

  defp detect_hotdrop_patterns(killmails) do
    # Look for sudden appearance of capitals in engagements
    # 5 minute windows
    grouped_by_time = group_by_time_window(killmails, 300)

    hotdrop_count =
      grouped_by_time
      |> Enum.count(fn {_time, kills} ->
        has_capitals = Enum.any?(kills, &is_capital_kill?/1)
        large_fleet = length(kills) >= 3
        has_capitals && large_fleet
      end)

    %{
      potential_hotdrops: hotdrop_count,
      confidence: if(hotdrop_count > 0, do: :medium, else: :none)
    }
  end

  defp detect_camping_patterns(killmails) do
    # Look for repeated kills in same system over time
    system_kills = Enum.group_by(killmails, & &1.solar_system_id)

    camping_systems =
      system_kills
      |> Enum.filter(fn {_system, kills} ->
        # 5+ kills over 1+ hour
        length(kills) >= 5 && time_span(kills) >= 3600
      end)
      |> Enum.map(fn {system, kills} ->
        %{
          system_id: system,
          kill_count: length(kills),
          duration_seconds: time_span(kills)
        }
      end)

    %{
      camping_detected: not Enum.empty?(camping_systems),
      systems: camping_systems
    }
  end

  defp find_peak_activity_times(killmails) do
    killmails
    |> Enum.group_by(fn km ->
      km.occurred_at
      |> DateTime.to_time()
      |> Map.get(:hour)
    end)
    |> Enum.map(fn {hour, kills} ->
      %{hour: hour, kill_count: length(kills)}
    end)
    |> Enum.sort_by(& &1.kill_count, :desc)
    |> Enum.take(3)
  end

  defp analyze_ship_usage(killmails) do
    killmails
    |> Enum.map(& &1.victim.ship_type_id)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_type, count} -> count end, :desc)
    |> Enum.take(10)
    |> Enum.map(fn {type_id, count} ->
      %{ship_type_id: type_id, usage_count: count}
    end)
  end

  defp categorize_engagement_sizes(killmails) do
    killmails
    |> Enum.map(fn km ->
      size = length(km.attackers)

      category =
        cond do
          size == 1 -> :solo
          size <= 5 -> :small_gang
          size <= 15 -> :medium_gang
          size <= 50 -> :fleet
          true -> :large_fleet
        end

      {category, km}
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.map(fn {category, kills} ->
      {category, length(kills)}
    end)
    |> Enum.into(%{})
  end

  defp analyze_geographic_patterns(killmails) do
    system_groups = Enum.group_by(killmails, & &1.solar_system_id)

    %{
      systems_active: map_size(system_groups),
      most_dangerous: find_most_dangerous_system(system_groups),
      kill_distribution: calculate_distribution(system_groups)
    }
  end

  defp group_by_time_window(killmails, window_seconds) do
    killmails
    |> Enum.group_by(fn km ->
      unix = DateTime.to_unix(km.occurred_at)
      div(unix, window_seconds) * window_seconds
    end)
  end

  defp time_span([]), do: 0

  defp time_span(killmails) do
    sorted = Enum.sort_by(killmails, & &1.occurred_at, DateTime)
    first = List.first(sorted)
    last = List.last(sorted)

    DateTime.diff(last.occurred_at, first.occurred_at)
  end

  defp find_most_dangerous_system(system_groups) do
    case Enum.max_by(system_groups, fn {_system, kills} -> length(kills) end, fn -> nil end) do
      nil ->
        nil

      {system_id, kills} ->
        %{
          system_id: system_id,
          kill_count: length(kills),
          total_value: calculate_total_value_destroyed(kills)
        }
    end
  end

  defp calculate_distribution(system_groups) do
    total_kills = system_groups |> Map.values() |> Enum.map(&length/1) |> Enum.sum()

    system_groups
    |> Enum.map(fn {system_id, kills} ->
      percentage = if total_kills > 0, do: length(kills) / total_kills * 100, else: 0

      %{
        system_id: system_id,
        percentage: Float.round(percentage, 1)
      }
    end)
    |> Enum.sort_by(& &1.percentage, :desc)
    |> Enum.take(5)
  end
end
