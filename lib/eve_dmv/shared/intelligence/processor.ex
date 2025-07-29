defmodule EveDmv.Shared.Intelligence.Processor do
  @moduledoc """
  Processes and normalizes intelligence data from various sources.

  This module is responsible for taking raw intelligence data and converting it
  into a standardized format that can be used by the fusion engine.
  """

  alias EveDmv.Shared.Intelligence.SourceHandlers.KillmailHandler

  require Logger

  @source_reliability %{
    killmails: 0.95,
    player_reports: 0.70,
    scanning_data: 0.85,
    market_activity: 0.60,
    jump_logs: 0.90
  }

  @doc """
  Processes intelligence sources and prepares them for fusion.

  Takes raw intelligence data and applies source-specific processing
  to normalize and enhance the data.
  """
  def process_intelligence_sources(raw_intelligence) do
    processed_sources =
      raw_intelligence.raw_data
      |> Enum.map(fn {source, data} ->
        {source, process_source_data(source, data)}
      end)
      |> Enum.into(%{})

    %{
      processed_data: processed_sources,
      processing_metadata: %{
        total_sources: map_size(processed_sources),
        valid_sources: count_valid_sources(processed_sources),
        processing_time: DateTime.utc_now(),
        data_completeness: calculate_data_completeness(processed_sources),
        reliability_scores: calculate_reliability_scores(processed_sources)
      }
    }
  end

  @doc """
  Assesses the quality of processed intelligence data.
  """
  def assess_data_quality(processed_intelligence) do
    processed_data = processed_intelligence.processed_data

    quality_factors = %{
      source_coverage: assess_source_coverage(processed_data),
      data_freshness: assess_data_freshness(processed_data),
      reliability_average: calculate_average_reliability(processed_data),
      completeness: processed_intelligence.processing_metadata.data_completeness
    }

    overall_quality = calculate_overall_quality(quality_factors)

    %{
      factors: quality_factors,
      overall_score: overall_quality,
      classification: classify_quality_score(overall_quality)
    }
  end

  # Source-specific processing

  defp process_source_data(:killmails, {:ok, data}) do
    KillmailHandler.process_killmail_data(data)
  rescue
    error ->
      Logger.error("Failed to process killmail data: #{inspect(error)}")
      build_error_response(:killmails, :processing_failed)
  end

  defp process_source_data(:player_reports, {:ok, data}) do
    process_player_report_data(data)
  end

  defp process_source_data(:scanning_data, {:ok, data}) do
    process_scanning_data(data)
  end

  defp process_source_data(:market_activity, {:ok, data}) do
    process_market_data(data)
  end

  defp process_source_data(:jump_logs, {:ok, data}) do
    process_jump_log_data(data)
  end

  defp process_source_data(source, {:error, reason}) do
    build_error_response(source, reason)
  end

  # Player report processing

  defp process_player_report_data(data) do
    reports = Map.get(data, :reports, [])

    %{
      processed: true,
      source_type: :player_reports,
      summary: %{
        total_reports: length(reports),
        average_confidence: data[:average_reliability] || 0.0,
        threat_reports: filter_threat_reports(reports),
        activity_summary: summarize_report_activities(reports)
      },
      intelligence_items: convert_reports_to_items(reports),
      reliability: @source_reliability.player_reports * (data[:average_reliability] || 0.5)
    }
  end

  # Scanning data processing

  defp process_scanning_data(data) do
    scans = Map.get(data, :scans, [])

    %{
      processed: true,
      source_type: :scanning_data,
      summary: %{
        total_scans: length(scans),
        ships_detected: data[:total_ships_detected] || 0,
        coverage: data[:coverage] || %{},
        temporal_distribution: data[:temporal_distribution] || %{}
      },
      threat_assessment: assess_scan_threats(scans),
      force_composition: analyze_force_composition(scans),
      reliability: @source_reliability.scanning_data
    }
  end

  # Market data processing

  defp process_market_data(data) do
    %{
      processed: true,
      source_type: :market_activity,
      summary: %{
        trade_volume: data[:trade_volume] || 0,
        active_orders: data[:active_orders] || 0,
        activity_level: data[:activity_level] || :unknown
      },
      economic_indicators: extract_economic_indicators(data),
      supply_changes: analyze_supply_changes(data),
      reliability: @source_reliability.market_activity
    }
  end

  # Jump log processing

  defp process_jump_log_data(data) do
    jumps = Map.get(data, :jumps, [])

    %{
      processed: true,
      source_type: :jump_logs,
      summary: %{
        total_jumps: data[:total_jumps] || 0,
        unique_pilots: data[:unique_pilots] || 0,
        traffic_density: data[:traffic_density] || :unknown
      },
      traffic_patterns: analyze_traffic_patterns(jumps),
      pilot_movements: track_pilot_movements(jumps),
      peak_times: identify_peak_traffic_times(jumps),
      reliability: @source_reliability.jump_logs
    }
  end

  # Helper functions

  defp count_valid_sources(processed_sources) do
    processed_sources
    |> Enum.count(fn {_source, data} ->
      Map.get(data, :processed, false) && !Map.get(data, :error, false)
    end)
  end

  defp calculate_data_completeness(processed_sources) do
    if map_size(processed_sources) == 0 do
      0.0
    else
      valid_count = count_valid_sources(processed_sources)
      Float.round(valid_count / map_size(processed_sources), 2)
    end
  end

  defp calculate_reliability_scores(processed_sources) do
    processed_sources
    |> Enum.map(fn {source, data} ->
      reliability = Map.get(data, :reliability, 0.0)
      {source, reliability}
    end)
    |> Enum.into(%{})
  end

  defp assess_source_coverage(processed_data) do
    total_possible = length(Map.keys(@source_reliability))
    actual_sources = map_size(processed_data)

    Float.round(actual_sources / total_possible, 2)
  end

  defp assess_data_freshness(_processed_data) do
    # In production, would check actual timestamps
    # For now, return good freshness
    1.0
  end

  defp calculate_average_reliability(processed_data) do
    reliabilities =
      processed_data
      |> Enum.map(fn {_source, data} -> Map.get(data, :reliability, 0.0) end)
      |> Enum.reject(&(&1 == 0.0))

    if Enum.empty?(reliabilities) do
      0.0
    else
      Float.round(Enum.sum(reliabilities) / length(reliabilities), 2)
    end
  end

  defp calculate_overall_quality(factors) do
    weights = %{
      source_coverage: 0.25,
      data_freshness: 0.25,
      reliability_average: 0.30,
      completeness: 0.20
    }

    score =
      Enum.reduce(weights, 0.0, fn {factor, weight}, acc ->
        value = Map.get(factors, factor, 0.0)
        acc + value * weight
      end)

    Float.round(score, 2)
  end

  defp classify_quality_score(score) do
    cond do
      score >= 0.9 -> :excellent
      score >= 0.7 -> :good
      score >= 0.5 -> :fair
      score >= 0.3 -> :poor
      true -> :very_poor
    end
  end

  defp build_error_response(source, reason) do
    %{
      processed: false,
      source_type: source,
      error: true,
      error_reason: reason,
      reliability: 0.0
    }
  end

  defp filter_threat_reports(reports) do
    reports
    |> Enum.filter(fn report ->
      content = String.downcase(report.content)
      String.contains?(content, ["hostile", "enemy", "threat", "danger", "attack"])
    end)
    |> Enum.map(fn report ->
      %{
        id: report.id,
        timestamp: report.timestamp,
        content: report.content,
        reliability: report.reliability
      }
    end)
  end

  defp summarize_report_activities(reports) do
    reports
    |> Enum.group_by(fn report ->
      classify_report_activity(report.content)
    end)
    |> Enum.map(fn {activity_type, activity_reports} ->
      {activity_type, length(activity_reports)}
    end)
    |> Enum.into(%{})
  end

  defp classify_report_activity(content) do
    content_lower = String.downcase(content)

    cond do
      String.contains?(content_lower, ["fleet", "gang"]) -> :fleet_activity
      String.contains?(content_lower, ["mining", "industrial"]) -> :industrial
      String.contains?(content_lower, ["camp", "gatecamp"]) -> :camping
      String.contains?(content_lower, ["capital", "super", "titan"]) -> :capital_activity
      true -> :other
    end
  end

  defp convert_reports_to_items(reports) do
    Enum.map(reports, fn report ->
      %{
        type: :player_report,
        timestamp: report.timestamp,
        data: report,
        confidence: report.reliability
      }
    end)
  end

  defp assess_scan_threats(scans) do
    threat_scans =
      scans
      |> Enum.filter(fn scan ->
        scan.ship_count >= 10 ||
          Enum.any?(scan.ship_types, fn type -> type.ship_class == :capital end)
      end)

    %{
      threat_level: determine_scan_threat_level(threat_scans),
      hostile_fleets_detected: length(threat_scans),
      capital_presence: detect_capital_presence(scans)
    }
  end

  defp determine_scan_threat_level(threat_scans) do
    cond do
      length(threat_scans) >= 5 -> :critical
      length(threat_scans) >= 3 -> :high
      length(threat_scans) >= 1 -> :medium
      true -> :low
    end
  end

  defp detect_capital_presence(scans) do
    scans
    |> Enum.any?(fn scan ->
      Enum.any?(scan.ship_types, fn type -> type.ship_class == :capital end)
    end)
  end

  defp analyze_force_composition(scans) do
    all_ships =
      scans
      |> Enum.flat_map(& &1.ship_types)
      |> Enum.group_by(& &1.ship_class)
      |> Enum.map(fn {class, ships} ->
        total = Enum.sum(Enum.map(ships, & &1.count))
        {class, total}
      end)
      |> Enum.into(%{})

    %{
      composition: all_ships,
      dominant_class: find_dominant_class(all_ships),
      total_ships: Enum.sum(Map.values(all_ships))
    }
  end

  defp find_dominant_class(ship_composition) do
    case Enum.max_by(ship_composition, fn {_class, count} -> count end, fn -> {:unknown, 0} end) do
      {class, _count} -> class
      _ -> :unknown
    end
  end

  defp extract_economic_indicators(data) do
    %{
      market_volatility: assess_market_volatility(data),
      supply_demand_ratio: calculate_supply_demand_ratio(data),
      price_trend: determine_price_trend(data)
    }
  end

  defp assess_market_volatility(data) do
    # Simplified volatility assessment
    case data[:activity_level] do
      :high -> :volatile
      :medium -> :moderate
      :low -> :stable
      _ -> :unknown
    end
  end

  defp calculate_supply_demand_ratio(data) do
    # Simplified ratio calculation
    active_orders = data[:active_orders] || 1
    trade_volume = data[:trade_volume] || 0

    if trade_volume > 0 do
      Float.round(active_orders / (trade_volume / 1_000_000), 2)
    else
      0.0
    end
  end

  defp determine_price_trend(data) do
    price_changes = data[:price_changes] || []

    if Enum.empty?(price_changes) do
      :unknown
    else
      average_change =
        price_changes
        |> Enum.map(& &1.price_change)
        |> Enum.sum()
        |> Kernel./(length(price_changes))

      cond do
        average_change > 5 -> :increasing
        average_change < -5 -> :decreasing
        true -> :stable
      end
    end
  end

  defp analyze_supply_changes(data) do
    price_changes = data[:price_changes] || []

    price_changes
    |> Enum.map(fn change ->
      %{
        item: change.item_type,
        price_impact: classify_price_impact(change.price_change),
        volume_impact: classify_volume_impact(change.volume_change)
      }
    end)
  end

  defp classify_price_impact(change) when change > 20, do: :significant_increase
  defp classify_price_impact(change) when change > 5, do: :moderate_increase
  defp classify_price_impact(change) when change < -20, do: :significant_decrease
  defp classify_price_impact(change) when change < -5, do: :moderate_decrease
  defp classify_price_impact(_), do: :stable

  defp classify_volume_impact(change) when change > 50, do: :surge
  defp classify_volume_impact(change) when change > 20, do: :increase
  defp classify_volume_impact(change) when change < -50, do: :collapse
  defp classify_volume_impact(change) when change < -20, do: :decrease
  defp classify_volume_impact(_), do: :normal

  defp analyze_traffic_patterns(jumps) do
    grouped = Enum.group_by(jumps, & &1.system_id)

    patterns =
      grouped
      |> Enum.map(fn {system_id, system_jumps} ->
        %{
          system_id: system_id,
          traffic_volume: length(system_jumps),
          unique_pilots: length(Enum.uniq_by(system_jumps, & &1.character_id)),
          peak_time: find_peak_hour(system_jumps)
        }
      end)

    %{
      by_system: patterns,
      busiest_system: find_busiest_system(patterns),
      traffic_classification: classify_overall_traffic(jumps)
    }
  end

  defp track_pilot_movements(jumps) do
    jumps
    |> Enum.group_by(& &1.character_id)
    |> Enum.map(fn {pilot_id, pilot_jumps} ->
      systems_visited =
        pilot_jumps
        |> Enum.map(& &1.system_id)
        |> Enum.uniq()

      %{
        pilot_id: pilot_id,
        jump_count: length(pilot_jumps),
        systems_visited: length(systems_visited),
        movement_pattern: classify_movement_pattern(pilot_jumps)
      }
    end)
    # Only track active pilots
    |> Enum.filter(&(&1.jump_count >= 3))
  end

  defp identify_peak_traffic_times(jumps) do
    jumps
    |> Enum.group_by(fn jump ->
      jump.timestamp
      |> DateTime.to_time()
      |> Map.get(:hour)
    end)
    |> Enum.map(fn {hour, hour_jumps} ->
      %{
        hour: hour,
        jump_count: length(hour_jumps),
        unique_pilots: length(Enum.uniq_by(hour_jumps, & &1.character_id))
      }
    end)
    |> Enum.sort_by(& &1.jump_count, :desc)
    |> Enum.take(3)
  end

  defp find_peak_hour(jumps) do
    jumps
    |> Enum.group_by(fn jump ->
      jump.timestamp |> DateTime.to_time() |> Map.get(:hour)
    end)
    |> Enum.max_by(fn {_hour, hour_jumps} -> length(hour_jumps) end, fn -> {0, []} end)
    |> elem(0)
  end

  defp find_busiest_system(patterns) do
    case Enum.max_by(patterns, & &1.traffic_volume, fn -> nil end) do
      nil -> nil
      pattern -> Map.take(pattern, [:system_id, :traffic_volume])
    end
  end

  defp classify_overall_traffic(jumps) do
    jump_count = length(jumps)

    cond do
      jump_count > 500 -> :very_high
      jump_count > 200 -> :high
      jump_count > 50 -> :moderate
      jump_count > 10 -> :low
      true -> :minimal
    end
  end

  defp classify_movement_pattern(pilot_jumps) do
    systems = Enum.map(pilot_jumps, & &1.system_id)
    unique_systems = Enum.uniq(systems)

    repeat_ratio = (length(systems) - length(unique_systems)) / length(systems)

    cond do
      repeat_ratio > 0.5 -> :patrol
      length(unique_systems) > 5 -> :roaming
      length(unique_systems) == 2 -> :transit
      true -> :stationary
    end
  end
end
