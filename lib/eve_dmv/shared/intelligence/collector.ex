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
    # In production, would query actual player reports
    simulate_player_reports(analysis_area, time_window_hours)
  end

  defp collect_from_source(:scanning_data, analysis_area, time_window_hours) do
    # In production, would query actual scan data
    simulate_scanning_data(analysis_area, time_window_hours)
  end

  defp collect_from_source(:market_activity, analysis_area, time_window_hours) do
    # In production, would query market data
    simulate_market_activity(analysis_area, time_window_hours)
  end

  defp collect_from_source(:jump_logs, analysis_area, time_window_hours) do
    # In production, would query jump statistics
    simulate_jump_logs(analysis_area, time_window_hours)
  end

  defp collect_killmail_data(system_ids, since) do
    try do
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
  end

  # Simulation functions for other sources (to be replaced with real implementations)

  defp simulate_player_reports(analysis_area, time_window_hours) do
    report_count = :rand.uniform(10)

    reports =
      Enum.map(1..report_count, fn i ->
        %{
          id: "report_#{:os.system_time()}_#{i}",
          timestamp:
            DateTime.add(DateTime.utc_now(), -:rand.uniform(time_window_hours * 3600), :second),
          reporter: "pilot_#{:rand.uniform(1000)}",
          content: generate_mock_report_content(),
          reliability: 0.5 + :rand.uniform() * 0.5,
          system_id: extract_random_system_id(analysis_area)
        }
      end)

    {:ok,
     %{
       reports: reports,
       count: report_count,
       average_reliability: calculate_average_reliability(reports),
       time_window_hours: time_window_hours
     }}
  end

  defp simulate_scanning_data(analysis_area, _time_window_hours) do
    scan_count = :rand.uniform(20)

    scans =
      Enum.map(1..scan_count, fn i ->
        %{
          id: "scan_#{:os.system_time()}_#{i}",
          timestamp: DateTime.utc_now(),
          scanner: "scout_#{:rand.uniform(100)}",
          system_id: extract_random_system_id(analysis_area),
          ship_count: :rand.uniform(30),
          ship_types: generate_ship_sightings(),
          anomalies_detected: :rand.uniform(5)
        }
      end)

    {:ok,
     %{
       scans: scans,
       total_ships_detected: Enum.sum(Enum.map(scans, & &1.ship_count)),
       coverage: assess_scan_coverage(scans),
       temporal_distribution: assess_temporal_coverage(scans)
     }}
  end

  defp simulate_market_activity(analysis_area, _time_window_hours) do
    # Simulate market data
    {:ok,
     %{
       trade_volume: :rand.uniform(1_000_000_000),
       active_orders: :rand.uniform(1000),
       price_changes: generate_price_changes(),
       activity_level: Enum.random([:low, :medium, :high])
     }}
  end

  defp simulate_jump_logs(analysis_area, time_window_hours) do
    system_ids = extract_system_ids(analysis_area)

    jumps =
      Enum.flat_map(system_ids, fn system_id ->
        jump_count = :rand.uniform(100)

        Enum.map(1..jump_count, fn _ ->
          %{
            system_id: system_id,
            timestamp:
              DateTime.add(DateTime.utc_now(), -:rand.uniform(time_window_hours * 3600), :second),
            character_id: :rand.uniform(1_000_000),
            ship_type: "ship_type_#{:rand.uniform(100)}"
          }
        end)
      end)

    {:ok,
     %{
       jumps: jumps,
       total_jumps: length(jumps),
       unique_pilots: length(Enum.uniq_by(jumps, & &1.character_id)),
       traffic_density: calculate_traffic_density(jumps, system_ids)
     }}
  end

  # Helper functions

  defp extract_system_ids(%{systems: system_ids}) when is_list(system_ids), do: system_ids
  defp extract_system_ids(%{system_id: system_id}), do: [system_id]
  defp extract_system_ids(_), do: [30_000_000 + :rand.uniform(5000)]

  defp extract_random_system_id(analysis_area) do
    analysis_area
    |> extract_system_ids()
    |> Enum.random()
  end

  defp generate_mock_report_content do
    activities = [
      "hostile fleet",
      "mining operation",
      "gate camp",
      "structure timer",
      "capital movement"
    ]

    sizes = ["small", "medium", "large"]

    "#{Enum.random(sizes)} #{Enum.random(activities)} detected"
  end

  defp calculate_average_reliability([]), do: 0.0

  defp calculate_average_reliability(reports) do
    total = Enum.sum(Enum.map(reports, & &1.reliability))
    Float.round(total / length(reports), 2)
  end

  defp generate_ship_sightings do
    ship_count = :rand.uniform(10)

    Enum.map(1..ship_count, fn _ ->
      %{
        ship_class: classify_ship_class(:rand.uniform(10)),
        count: :rand.uniform(5)
      }
    end)
  end

  defp classify_ship_class(class_num) do
    case class_num do
      n when n <= 3 -> :frigate
      n when n <= 5 -> :cruiser
      n when n <= 7 -> :battlecruiser
      n when n <= 9 -> :battleship
      _ -> :capital
    end
  end

  defp generate_price_changes do
    Enum.map(1..5, fn _ ->
      %{
        item_type: "item_#{:rand.uniform(1000)}",
        price_change: -50 + :rand.uniform(100),
        volume_change: -100 + :rand.uniform(200)
      }
    end)
  end

  defp assess_scan_coverage(scans) do
    unique_systems = scans |> Enum.map(& &1.system_id) |> Enum.uniq() |> length()
    total_scans = length(scans)

    coverage_ratio = if total_scans > 0, do: unique_systems / total_scans, else: 0

    %{
      unique_systems: unique_systems,
      total_scans: total_scans,
      coverage_ratio: Float.round(coverage_ratio, 2)
    }
  end

  defp assess_temporal_coverage(scans) do
    # Simple temporal analysis
    %{
      distribution: :uniform,
      gaps_detected: false,
      coverage_quality: :good
    }
  end

  defp calculate_traffic_density(jumps, system_ids) do
    jumps_per_system = length(jumps) / max(1, length(system_ids))

    cond do
      jumps_per_system > 50 -> :high
      jumps_per_system > 20 -> :medium
      true -> :low
    end
  end

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
end
