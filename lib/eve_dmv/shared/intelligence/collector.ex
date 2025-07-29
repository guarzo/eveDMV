defmodule EveDmv.Shared.Intelligence.Collector do
  @moduledoc """
  Intelligence collection service responsible for gathering raw data from various sources.

  This module handles the initial collection phase of intelligence gathering,
  supporting multiple source types including killmails, player reports, scanning data,
  market activity, and jump logs.
  """

  alias EveDmv.Api
  alias EveDmv.Killmails.KillmailRaw

  require Logger

  # Intelligence source configuration
  @intelligence_sources [
    :killmails,
    :player_reports,
    :scanning_data,
    :market_activity,
    :jump_logs
  ]

  @doc """
  Collects raw intelligence from multiple sources for a given analysis area.

  ## Parameters
  - analysis_area: Map containing area definition (e.g., %{systems: [30000142, 30000143]})
  - options: Keyword list of options
    - :time_window_hours - Hours of data to collect (default: 24)
    - :sources - List of sources to query (default: all sources)

  ## Returns
  {:ok, %{
    analysis_area: map(),
    collection_time: DateTime.t(),
    time_window_hours: integer(),
    sources_queried: list(),
    raw_data: map(),
    data_quality: atom()
  }}
  """
  def collect_raw_intelligence(analysis_area, options \\ []) do
    time_window_hours = Keyword.get(options, :time_window_hours, 24)
    sources = Keyword.get(options, :sources, @intelligence_sources)

    Logger.info(
      "Collecting intelligence from #{length(sources)} sources for area: #{inspect(analysis_area)}"
    )

    intelligence_data =
      sources
      |> Enum.map(fn source ->
        {source, collect_from_source(source, analysis_area, time_window_hours)}
      end)
      |> Enum.into(%{})

    {:ok,
     %{
       analysis_area: analysis_area,
       collection_time: DateTime.utc_now(),
       time_window_hours: time_window_hours,
       sources_queried: sources,
       raw_data: intelligence_data,
       data_quality: assess_data_quality(intelligence_data)
     }}
  end

  @doc """
  Lists available intelligence sources.
  """
  def available_sources, do: @intelligence_sources

  # Private collection functions

  defp collect_from_source(:killmails, analysis_area, time_window_hours) do
    system_ids = extract_system_ids(analysis_area)
    since = DateTime.add(DateTime.utc_now(), -time_window_hours * 3600, :second)

    Logger.debug("Collecting killmails for systems: #{inspect(system_ids)} since: #{since}")

    collect_killmail_data(system_ids, since)
  end

  defp collect_from_source(:player_reports, analysis_area, time_window_hours) do
    # Generate intelligence reports from killmail analysis patterns
    # This analyzes killmail data to infer player activity reports
    system_ids = extract_system_ids(analysis_area)
    since = DateTime.add(DateTime.utc_now(), -time_window_hours * 3600, :second)

    case collect_killmail_data(system_ids, since) do
      {:ok, killmail_data} ->
        reports = analyze_killmails_for_intelligence_reports(killmail_data.killmails, system_ids)

        {:ok,
         %{
           reports: reports,
           count: length(reports),
           average_reliability: calculate_report_reliability(reports),
           time_window_hours: time_window_hours
         }}

      {:error, _} ->
        {:ok,
         %{
           reports: [],
           count: 0,
           average_reliability: 0.0,
           time_window_hours: time_window_hours
         }}
    end
  end

  defp collect_from_source(:scanning_data, analysis_area, time_window_hours) do
    # Generate scanning data from killmail participant analysis
    # This analyzes ship presence patterns from killmail data
    system_ids = extract_system_ids(analysis_area)
    since = DateTime.add(DateTime.utc_now(), -time_window_hours * 3600, :second)

    case collect_killmail_data(system_ids, since) do
      {:ok, killmail_data} ->
        scans = analyze_ship_presence_from_killmails(killmail_data.killmails, system_ids, since)
        total_ships = Enum.sum(Enum.map(scans, & &1.ship_count))

        {:ok,
         %{
           scans: scans,
           total_ships_detected: total_ships,
           coverage: calculate_scan_coverage(scans, system_ids),
           temporal_distribution: analyze_temporal_distribution(scans)
         }}

      {:error, _} ->
        {:ok,
         %{
           scans: [],
           total_ships_detected: 0,
           coverage: 0.0,
           temporal_distribution: %{}
         }}
    end
  end

  defp collect_from_source(:market_activity, _analysis_area, _time_window_hours) do
    # Market activity tracking is not yet implemented
    # Return empty data structure instead of random data
    {:ok,
     %{
       trade_volume: 0,
       active_orders: 0,
       price_changes: [],
       activity_level: :unknown
     }}
  end

  defp collect_from_source(:jump_logs, analysis_area, time_window_hours) do
    # Generate jump activity from killmail participant movements
    # This analyzes character movement patterns from killmail data
    system_ids = extract_system_ids(analysis_area)
    since = DateTime.add(DateTime.utc_now(), -time_window_hours * 3600, :second)

    case collect_killmail_data(system_ids, since) do
      {:ok, killmail_data} ->
        jumps = analyze_character_movements_from_killmails(killmail_data.killmails, system_ids)
        unique_pilots = jumps |> Enum.map(& &1.character_id) |> Enum.uniq() |> length()

        {:ok,
         %{
           jumps: jumps,
           total_jumps: length(jumps),
           unique_pilots: unique_pilots,
           traffic_density: calculate_traffic_density_by_system(jumps, system_ids)
         }}

      {:error, _} ->
        {:ok,
         %{
           jumps: [],
           total_jumps: 0,
           unique_pilots: 0,
           traffic_density: Map.new(system_ids, fn id -> {id, 0.0} end)
         }}
    end
  end

  defp collect_killmail_data(system_ids, since) do
    # Query actual killmail data
    killmails =
      system_ids
      |> Enum.flat_map(fn system_id ->
        case Api.read!(KillmailRaw,
               filter: [
                 solar_system_id: system_id,
                 occurred_at: [greater_than: since]
               ],
               limit: 100
             ) do
          {:ok, kills} -> kills
          _ -> []
        end
      end)

    {:ok,
     %{
       killmails: killmails,
       count: length(killmails),
       systems_queried: system_ids,
       time_range: %{since: since, until: DateTime.utc_now()}
     }}
  rescue
    error ->
      Logger.error("Failed to collect killmail data: #{inspect(error)}")
      {:error, :collection_failed}
  end

  # Helper functions

  defp extract_system_ids(%{systems: system_ids}) when is_list(system_ids), do: system_ids
  defp extract_system_ids(%{system_id: system_id}), do: [system_id]
  defp extract_system_ids(_), do: []

  defp assess_data_quality(intelligence_data) do
    # Simple quality assessment based on data completeness
    successful_sources =
      intelligence_data
      |> Enum.count(fn {_source, result} ->
        case result do
          {:ok, _} -> true
          _ -> false
        end
      end)

    total_sources = map_size(intelligence_data)
    quality_ratio = if total_sources > 0, do: successful_sources / total_sources, else: 0

    cond do
      quality_ratio >= 0.8 -> :excellent
      quality_ratio >= 0.6 -> :good
      quality_ratio >= 0.4 -> :fair
      true -> :poor
    end
  end

  # Helper functions for intelligence analysis

  defp analyze_killmails_for_intelligence_reports(killmails, system_ids) do
    killmails
    |> Enum.group_by(& &1.solar_system_id)
    |> Enum.flat_map(fn {system_id, system_killmails} ->
      if system_id in system_ids do
        # Analyze killmail patterns for intelligence value
        Enum.map(system_killmails, fn km ->
          %{
            report_id: generate_report_id(km),
            system_id: system_id,
            timestamp: km.killmail_time,
            participant_count: length(km.participants || []),
            ship_classes: extract_ship_classes(km.participants || []),
            intelligence_type: classify_intelligence_type(km),
            reliability: calculate_killmail_reliability(km)
          }
        end)
      else
        []
      end
    end)
  end

  defp analyze_ship_presence_from_killmails(killmails, system_ids, since) do
    killmails
    |> Enum.group_by(& &1.solar_system_id)
    |> Enum.flat_map(fn {system_id, system_killmails} ->
      if system_id in system_ids do
        ship_presence =
          system_killmails
          |> Enum.flat_map(&(&1.participants || []))
          |> Enum.group_by(& &1.ship_type_id)
          |> Enum.map(fn {ship_type_id, ships} ->
            %{
              ship_type_id: ship_type_id,
              count: length(ships),
              last_seen: Enum.max_by(ships, & &1.killmail_time).killmail_time
            }
          end)

        [
          %{
            system_id: system_id,
            scan_time: since,
            ship_count: length(ship_presence),
            ships_detected: ship_presence
          }
        ]
      else
        []
      end
    end)
  end

  defp analyze_character_movements_from_killmails(killmails, system_ids) do
    killmails
    |> Enum.flat_map(&(&1.participants || []))
    |> Enum.group_by(& &1.character_id)
    |> Enum.flat_map(fn {character_id, participations} ->
      # Analyze movement patterns from killmail locations
      participations
      |> Enum.sort_by(& &1.killmail_time)
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.filter(fn [prev, curr] ->
        # Only include if moving between systems in our analysis area
        prev.solar_system_id != curr.solar_system_id and
          prev.solar_system_id in system_ids and
          curr.solar_system_id in system_ids
      end)
      |> Enum.map(fn [prev, curr] ->
        %{
          character_id: character_id,
          from_system_id: prev.solar_system_id,
          to_system_id: curr.solar_system_id,
          jump_time: curr.killmail_time,
          ship_type_id: curr.ship_type_id
        }
      end)
    end)
  end

  defp calculate_report_reliability(reports) do
    if Enum.empty?(reports) do
      0.0
    else
      avg_reliability =
        reports
        |> Enum.map(& &1.reliability)
        |> Enum.sum()
        |> Kernel./(length(reports))

      Float.round(avg_reliability, 2)
    end
  end

  defp calculate_scan_coverage(scans, system_ids) do
    if Enum.empty?(system_ids) do
      0.0
    else
      scanned_systems = scans |> Enum.map(& &1.system_id) |> Enum.uniq()
      coverage = length(scanned_systems) / length(system_ids)
      Float.round(coverage * 100, 1)
    end
  end

  defp analyze_temporal_distribution(scans) do
    if Enum.empty?(scans) do
      %{}
    else
      scans
      |> Enum.group_by(fn scan ->
        scan.scan_time
        |> DateTime.to_time()
        |> Time.to_erl()
        # Extract hour
        |> elem(0)
      end)
      |> Enum.map(fn {hour, hour_scans} ->
        {hour, length(hour_scans)}
      end)
      |> Enum.into(%{})
    end
  end

  defp calculate_traffic_density_by_system(jumps, system_ids) do
    system_densities =
      jumps
      |> Enum.group_by(& &1.to_system_id)
      |> Enum.map(fn {system_id, system_jumps} ->
        {system_id, length(system_jumps)}
      end)
      |> Enum.into(%{})

    # Ensure all systems have a density value
    system_ids
    |> Enum.map(fn system_id ->
      density = Map.get(system_densities, system_id, 0)
      {system_id, Float.round(density / 1.0, 1)}
    end)
    |> Enum.into(%{})
  end

  # Utility functions for intelligence processing

  defp generate_report_id(killmail) do
    # Generate a unique report ID based on killmail data
    :crypto.hash(:md5, "#{killmail.killmail_id}_#{killmail.solar_system_id}")
    |> Base.encode16(case: :lower)
    |> String.slice(0, 8)
  end

  defp extract_ship_classes(participants) do
    participants
    |> Enum.map(& &1.ship_type_id)
    |> Enum.map(&classify_ship_class/1)
    |> Enum.uniq()
  end

  defp classify_ship_class(ship_type_id) do
    # Basic ship classification - this would use actual EVE ship data
    cond do
      ship_type_id in 500..600 -> :frigate
      ship_type_id in 600..700 -> :cruiser
      ship_type_id in 700..800 -> :battleship
      true -> :unknown
    end
  end

  defp classify_intelligence_type(killmail) do
    participant_count = length(killmail.participants || [])

    cond do
      participant_count >= 20 -> :fleet_engagement
      participant_count >= 5 -> :small_gang
      participant_count >= 2 -> :skirmish
      true -> :solo_activity
    end
  end

  defp calculate_killmail_reliability(killmail) do
    # Calculate reliability based on killmail characteristics
    participant_count = length(killmail.participants || [])

    base_reliability =
      cond do
        participant_count >= 10 -> 0.9
        participant_count >= 5 -> 0.8
        participant_count >= 2 -> 0.7
        true -> 0.6
      end

    # Adjust for security status if available
    security_adjustment =
      case Map.get(killmail, :security_status, 0.0) do
        # Bonus for null/lowsec
        sec when sec < 0.0 -> 0.1
        _ -> 0.0
      end

    min(1.0, base_reliability + security_adjustment)
  end
end
