defmodule EveDmv.Shared.Strategic.Patterns.ResourcePattern do
  @moduledoc """
  Identifies resource control and competition patterns.

  Responsible for:
  - Resource control pattern detection
  - Competition analysis
  - Strategic value assessment
  - Resource flow tracking
  """

  require Logger

  @doc """
  Identifies resource control patterns.
  """
  def identify_resource_control(strategic_data) do
    resource_metrics = analyze_resource_activity(strategic_data)
    control_indicators = identify_control_indicators(resource_metrics, strategic_data)

    confidence = calculate_control_confidence(control_indicators, resource_metrics)

    %{
      type: :resource_control,
      category: :economic,
      confidence: confidence,
      description: describe_resource_pattern(control_indicators, resource_metrics),
      metrics: resource_metrics,
      indicators: control_indicators,
      spatial_data: extract_spatial_data(strategic_data),
      temporal_data: extract_temporal_data(strategic_data),
      resource_assessment: assess_resource_value(resource_metrics)
    }
  end

  @doc """
  Analyzes resource competition between entities.
  """
  def analyze_resource_competition(strategic_data) do
    competitors = identify_competitors(strategic_data)
    competition_metrics = calculate_competition_metrics(competitors, strategic_data)

    %{
      competitor_count: length(competitors),
      competitors: competitors,
      competition_intensity: competition_metrics.intensity,
      dominant_competitor: competition_metrics.dominant,
      resource_distribution: competition_metrics.distribution,
      competition_trends: analyze_competition_trends(strategic_data)
    }
  end

  @doc """
  Assesses strategic value of resource areas.
  """
  def assess_strategic_value(resource_metrics, strategic_data) do
    location_value = calculate_location_value(strategic_data)
    activity_value = calculate_activity_value(resource_metrics)
    control_value = calculate_control_value(resource_metrics)

    overall_value = (location_value + activity_value + control_value) / 3

    %{
      overall_value: Float.round(overall_value, 3),
      location_value: location_value,
      activity_value: activity_value,
      control_value: control_value,
      value_classification: classify_strategic_value(overall_value)
    }
  end

  # Private functions

  defp analyze_resource_activity(strategic_data) do
    killmails = extract_all_killmails(strategic_data)

    %{
      mining_activity: detect_mining_activity(killmails),
      hauling_activity: detect_hauling_activity(killmails),
      resource_conflicts: identify_resource_conflicts(killmails),
      activity_concentration: calculate_activity_concentration(killmails),
      time_patterns: analyze_time_patterns(killmails)
    }
  end

  defp extract_all_killmails(strategic_data) do
    case strategic_data.scope do
      :single_system -> strategic_data.killmails
      :multi_system -> Enum.flat_map(strategic_data.killmail_data, & &1.killmails)
    end
  end

  defp detect_mining_activity(killmails) do
    # Look for mining ship losses
    mining_ships = [
      # Simplified ship type IDs - in production would use actual IDs
      :venture,
      :procurer,
      :retriever,
      :covetor,
      :skiff,
      :mackinaw,
      :hulk,
      :orca,
      :rorqual
    ]

    mining_losses =
      killmails
      |> Enum.filter(fn km ->
        # Simplified check - would use actual ship type IDs
        ship_class = classify_ship_type(km.victim.ship_type_id)
        ship_class in mining_ships
      end)

    %{
      mining_losses: length(mining_losses),
      mining_intensity: calculate_mining_intensity(mining_losses, length(killmails)),
      peak_mining_times: identify_peak_mining_times(mining_losses),
      mining_entities: extract_mining_entities(mining_losses)
    }
  end

  defp classify_ship_type(ship_type_id) do
    # Use actual ship classification from static data
    case EveDmv.StaticData.ShipTypes.classify_ship_type(ship_type_id) do
      {:ok, :mining_frigate} -> :venture
      {:ok, :mining_barge} -> :retriever
      # Group with mining barges
      {:ok, :exhumer} -> :retriever
      {:ok, :industrial} -> :hauler
      {:ok, :transport} -> :hauler
      {:ok, :freighter} -> :hauler
      {:ok, _} -> :combat
      {:error, _} -> :combat
    end
  end

  defp calculate_mining_intensity(mining_losses, total_kills) do
    if total_kills > 0 do
      Float.round(length(mining_losses) / total_kills, 3)
    else
      0.0
    end
  end

  defp identify_peak_mining_times(mining_losses) do
    if Enum.empty?(mining_losses) do
      []
    else
      mining_losses
      |> Enum.group_by(& &1.timestamp.hour)
      |> Enum.map(fn {hour, losses} -> {hour, length(losses)} end)
      |> Enum.sort_by(fn {_, count} -> count end, :desc)
      |> Enum.take(3)
      |> Enum.map(fn {hour, count} ->
        %{hour: hour, loss_count: count}
      end)
    end
  end

  defp extract_mining_entities(mining_losses) do
    mining_losses
    |> Enum.map(& &1.victim.corporation_id)
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(5)
    |> Enum.map(fn {corp_id, count} ->
      %{corporation_id: corp_id, mining_losses: count}
    end)
  end

  defp detect_hauling_activity(killmails) do
    hauler_types = [:hauler, :freighter, :transport]

    hauling_losses =
      killmails
      |> Enum.filter(fn km ->
        ship_class = classify_ship_type(km.victim.ship_type_id)
        ship_class in hauler_types
      end)

    %{
      hauling_losses: length(hauling_losses),
      hauling_intensity: calculate_hauling_intensity(hauling_losses, length(killmails)),
      hauling_routes: identify_hauling_routes(hauling_losses),
      cargo_value: estimate_cargo_value(hauling_losses)
    }
  end

  defp calculate_hauling_intensity(hauling_losses, total_kills) do
    if total_kills > 0 do
      Float.round(length(hauling_losses) / total_kills, 3)
    else
      0.0
    end
  end

  defp identify_hauling_routes(hauling_losses) do
    # Simplified route identification
    hauling_losses
    |> Enum.group_by(& &1.solar_system_id)
    |> Enum.map(fn {system, losses} ->
      %{system_id: system, hauler_losses: length(losses)}
    end)
    |> Enum.sort_by(& &1.hauler_losses, :desc)
  end

  defp estimate_cargo_value(hauling_losses) do
    # Simplified cargo value estimation
    hauling_losses
    |> Enum.map(fn km ->
      # Assume 30% is cargo
      Map.get(km, :zkb_total_value, 0) * 0.3
    end)
    |> Enum.sum()
    |> round()
  end

  defp identify_resource_conflicts(killmails) do
    # Look for conflicts over resource operations
    resource_related =
      killmails
      |> Enum.filter(fn km ->
        ship_class = classify_ship_type(km.victim.ship_type_id)
        ship_class in [:venture, :retriever, :hauler, :orca, :rorqual]
      end)

    conflicts =
      resource_related
      |> Enum.group_by(fn km ->
        {DateTime.to_date(km.timestamp), km.solar_system_id}
      end)
      |> Enum.filter(fn {_, kms} -> length(kms) >= 2 end)
      |> Enum.map(fn {{date, system}, kms} ->
        %{
          date: date,
          system_id: system,
          conflict_intensity: length(kms),
          participants: extract_conflict_participants(kms)
        }
      end)

    %{
      conflict_count: length(conflicts),
      conflicts: conflicts,
      conflict_systems: Enum.uniq(Enum.map(conflicts, & &1.system_id))
    }
  end

  defp extract_conflict_participants(killmails) do
    attackers =
      killmails
      |> Enum.flat_map(& &1.attackers)
      |> Enum.map(& &1.corporation_id)
      |> Enum.reject(&is_nil/1)
      |> Enum.frequencies()

    victims =
      killmails
      |> Enum.map(& &1.victim.corporation_id)
      |> Enum.reject(&is_nil/1)
      |> Enum.frequencies()

    %{attackers: attackers, victims: victims}
  end

  defp calculate_activity_concentration(killmails) do
    if Enum.empty?(killmails) do
      0.0
    else
      # Time-based concentration
      hourly_distribution =
        killmails
        |> Enum.group_by(& &1.timestamp.hour)
        |> Enum.map(fn {_, kms} -> length(kms) end)

      if Enum.empty?(hourly_distribution) do
        0.0
      else
        max_hourly = Enum.max(hourly_distribution)
        total = Enum.sum(hourly_distribution)
        Float.round(max_hourly / total, 3)
      end
    end
  end

  defp analyze_time_patterns(killmails) do
    hourly_activity =
      killmails
      |> Enum.group_by(& &1.timestamp.hour)
      |> Enum.map(fn {hour, kms} -> {hour, length(kms)} end)
      |> Map.new()

    %{
      peak_hours: identify_peak_hours(hourly_activity),
      activity_pattern: classify_activity_pattern(hourly_activity),
      timezone_indication: estimate_timezone(hourly_activity)
    }
  end

  defp identify_peak_hours(hourly_activity) do
    if map_size(hourly_activity) == 0 do
      []
    else
      avg_activity = Enum.sum(Map.values(hourly_activity)) / 24

      hourly_activity
      |> Enum.filter(fn {_, count} -> count > avg_activity end)
      |> Enum.sort_by(fn {_, count} -> count end, :desc)
      |> Enum.take(3)
      |> Enum.map(fn {hour, _} -> hour end)
    end
  end

  defp classify_activity_pattern(hourly_activity) do
    peak_hours = identify_peak_hours(hourly_activity)

    cond do
      Enum.empty?(peak_hours) -> :no_pattern
      consecutive_hours?(peak_hours) -> :concentrated
      european_hours?(peak_hours) -> :eu_timezone
      american_hours?(peak_hours) -> :us_timezone
      asian_hours?(peak_hours) -> :au_timezone
      true -> :distributed
    end
  end

  defp consecutive_hours?(hours) do
    sorted = Enum.sort(hours)

    sorted
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.all?(fn [h1, h2] -> h2 - h1 == 1 || (h1 == 23 && h2 == 0) end)
  end

  defp european_hours?(hours), do: Enum.all?(hours, &(&1 >= 18 && &1 <= 23))
  defp american_hours?(hours), do: Enum.all?(hours, &(&1 >= 0 && &1 <= 5))
  defp asian_hours?(hours), do: Enum.all?(hours, &(&1 >= 10 && &1 <= 16))

  defp estimate_timezone(hourly_activity) do
    pattern = classify_activity_pattern(hourly_activity)

    case pattern do
      :eu_timezone -> "European"
      :us_timezone -> "American"
      :au_timezone -> "Asian/Australian"
      _ -> "Mixed/Unknown"
    end
  end

  defp identify_control_indicators(resource_metrics, _strategic_data) do
    []
    |> then(fn indicators ->
      # Mining dominance
      if resource_metrics.mining_activity.mining_intensity > 0.2 do
        indicators ++ [{:mining_dominance, resource_metrics.mining_activity.mining_intensity}]
      else
        indicators
      end
    end)
    |> then(fn indicators ->
      # Hauling control
      if resource_metrics.hauling_activity.hauling_intensity > 0.1 do
        indicators ++ [{:hauling_control, resource_metrics.hauling_activity.hauling_intensity}]
      else
        indicators
      end
    end)
    |> then(fn indicators ->
      # Resource conflicts
      if resource_metrics.resource_conflicts.conflict_count > 3 do
        indicators ++ [{:active_competition, resource_metrics.resource_conflicts.conflict_count}]
      else
        indicators
      end
    end)
    |> then(fn indicators ->
      # Time control
      if resource_metrics.activity_concentration > 0.5 do
        indicators ++ [{:time_dominance, resource_metrics.activity_concentration}]
      else
        indicators
      end
    end)
  end

  defp calculate_control_confidence(indicators, resource_metrics) do
    base_confidence = length(indicators) * 0.15

    # Activity level bonus
    activity_bonus =
      if resource_metrics.mining_activity.mining_losses > 5 ||
           resource_metrics.hauling_activity.hauling_losses > 3 do
        0.2
      else
        0.0
      end

    # Conflict bonus
    conflict_bonus =
      if resource_metrics.resource_conflicts.conflict_count > 0 do
        0.1
      else
        0.0
      end

    min(1.0, base_confidence + activity_bonus + conflict_bonus)
  end

  defp describe_resource_pattern(indicators, _resource_metrics) do
    indicator_types = Enum.map(indicators, fn {type, _} -> type end)

    cond do
      :mining_dominance in indicator_types && :active_competition in indicator_types ->
        "Contested resource extraction with active competition"

      :mining_dominance in indicator_types && :time_dominance in indicator_types ->
        "Organized resource extraction with timezone control"

      :hauling_control in indicator_types ->
        "Resource transportation network under control"

      :active_competition in indicator_types ->
        "Resource area with high competition"

      :mining_dominance in indicator_types ->
        "Active mining operations detected"

      true ->
        "Limited resource activity"
    end
  end

  defp assess_resource_value(resource_metrics) do
    mining_value = resource_metrics.mining_activity.mining_losses * 0.3
    # In millions
    hauling_value = resource_metrics.hauling_activity.cargo_value / 1_000_000
    conflict_value = resource_metrics.resource_conflicts.conflict_count * 0.1

    total_value = mining_value + hauling_value + conflict_value

    %{
      estimated_value: Float.round(total_value, 2),
      value_sources: %{
        mining: Float.round(mining_value, 2),
        hauling: Float.round(hauling_value, 2),
        competition: Float.round(conflict_value, 2)
      },
      value_classification: classify_resource_value(total_value)
    }
  end

  defp classify_resource_value(value) do
    cond do
      value >= 10.0 -> :high_value
      value >= 5.0 -> :moderate_value
      value >= 1.0 -> :low_value
      true -> :minimal_value
    end
  end

  defp extract_spatial_data(strategic_data) do
    systems =
      case strategic_data.scope do
        :single_system -> [strategic_data.system_id]
        :multi_system -> Enum.map(strategic_data.killmail_data, & &1.system_id)
      end

    %{
      systems: systems,
      system_count: length(Enum.uniq(systems))
    }
  end

  defp extract_temporal_data(strategic_data) do
    %{
      start_time: strategic_data.time_range.since,
      end_time: strategic_data.time_range.until,
      duration_days:
        DateTime.diff(
          strategic_data.time_range.until,
          strategic_data.time_range.since,
          :day
        )
    }
  end

  defp identify_competitors(strategic_data) do
    killmails = extract_all_killmails(strategic_data)

    # Extract entities involved in resource activities
    resource_entities =
      killmails
      |> Enum.filter(fn km ->
        ship_class = classify_ship_type(km.victim.ship_type_id)
        ship_class in [:venture, :retriever, :hauler, :orca, :rorqual]
      end)
      |> Enum.flat_map(fn km ->
        victim = if km.victim.corporation_id, do: [km.victim.corporation_id], else: []

        attackers =
          km.attackers
          |> Enum.map(& &1.corporation_id)
          |> Enum.reject(&is_nil/1)

        victim ++ attackers
      end)
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_, count} -> count end, :desc)
      |> Enum.take(10)
      |> Enum.map(fn {corp_id, activity_count} ->
        %{
          corporation_id: corp_id,
          activity_count: activity_count,
          activity_type: determine_activity_type(corp_id, killmails)
        }
      end)

    resource_entities
  end

  defp determine_activity_type(corp_id, killmails) do
    corp_activities =
      killmails
      |> Enum.filter(fn km ->
        km.victim.corporation_id == corp_id ||
          Enum.any?(km.attackers, &(&1.corporation_id == corp_id))
      end)

    victim_count = Enum.count(corp_activities, &(&1.victim.corporation_id == corp_id))
    attacker_count = length(corp_activities) - victim_count

    cond do
      victim_count > attacker_count * 2 -> :miner
      attacker_count > victim_count * 2 -> :hunter
      true -> :mixed
    end
  end

  defp calculate_competition_metrics(competitors, _strategic_data) do
    if Enum.empty?(competitors) do
      %{
        intensity: 0.0,
        dominant: nil,
        distribution: %{}
      }
    else
      total_activity = Enum.sum(Enum.map(competitors, & &1.activity_count))
      dominant = List.first(competitors)

      distribution =
        competitors
        |> Enum.map(fn comp ->
          {comp.corporation_id, Float.round(comp.activity_count / total_activity, 3)}
        end)
        |> Map.new()

      # Herfindahl index for competition intensity
      hhi =
        Map.values(distribution)
        |> Enum.map(&(&1 * &1))
        |> Enum.sum()

      %{
        # Higher = more competition
        intensity: Float.round(1.0 - hhi, 3),
        dominant: dominant,
        distribution: distribution
      }
    end
  end

  defp analyze_competition_trends(strategic_data) do
    # Simplified trend analysis
    killmails = extract_all_killmails(strategic_data)

    time_windows = create_time_windows(strategic_data.time_range)

    window_competition =
      time_windows
      |> Enum.map(fn {start_time, end_time} ->
        window_kills =
          killmails
          |> Enum.filter(fn km ->
            DateTime.compare(km.timestamp, start_time) != :lt &&
              DateTime.compare(km.timestamp, end_time) == :lt
          end)

        competitors = identify_window_competitors(window_kills)

        %{
          window: {start_time, end_time},
          competitor_count: length(competitors),
          competition_intensity: calculate_window_competition(competitors)
        }
      end)

    %{
      trend: determine_competition_trend(window_competition),
      peak_competition: find_peak_competition(window_competition),
      average_competitors: calculate_average_competitors(window_competition)
    }
  end

  defp create_time_windows(time_range) do
    duration_hours = DateTime.diff(time_range.until, time_range.since, :hour)
    window_size = max(24, div(duration_hours, 7))

    Stream.unfold(time_range.since, fn current ->
      if DateTime.compare(current, time_range.until) == :lt do
        window_end = DateTime.add(current, window_size * 3600, :second)

        window_end =
          if DateTime.compare(window_end, time_range.until) == :gt do
            time_range.until
          else
            window_end
          end

        {{current, window_end}, window_end}
      else
        nil
      end
    end)
    |> Enum.to_list()
  end

  defp identify_window_competitors(killmails) do
    killmails
    |> Enum.flat_map(fn km ->
      [km.victim.corporation_id | Enum.map(km.attackers, & &1.corporation_id)]
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
    |> Enum.filter(fn {_, count} -> count >= 2 end)
    |> Map.keys()
  end

  defp calculate_window_competition(competitors) do
    # Simple competition metric based on competitor count
    cond do
      length(competitors) >= 5 -> 1.0
      length(competitors) >= 3 -> 0.7
      length(competitors) >= 2 -> 0.4
      true -> 0.1
    end
  end

  defp determine_competition_trend(window_competition) do
    if length(window_competition) < 2 do
      :insufficient_data
    else
      intensities = Enum.map(window_competition, & &1.competition_intensity)

      first_half_avg =
        intensities
        |> Enum.take(div(length(intensities), 2))
        |> average()

      second_half_avg =
        intensities
        |> Enum.drop(div(length(intensities), 2))
        |> average()

      cond do
        second_half_avg > first_half_avg * 1.2 -> :increasing
        second_half_avg < first_half_avg * 0.8 -> :decreasing
        true -> :stable
      end
    end
  end

  defp find_peak_competition(window_competition) do
    if Enum.empty?(window_competition) do
      nil
    else
      Enum.max_by(window_competition, & &1.competition_intensity)
    end
  end

  defp calculate_average_competitors(window_competition) do
    if Enum.empty?(window_competition) do
      0.0
    else
      total = Enum.sum(Enum.map(window_competition, & &1.competitor_count))
      Float.round(total / length(window_competition), 1)
    end
  end

  defp average(list) do
    if Enum.empty?(list) do
      0.0
    else
      Enum.sum(list) / length(list)
    end
  end

  defp calculate_location_value(strategic_data) do
    # Simplified location value based on system count
    system_count =
      case strategic_data.scope do
        :single_system -> 1
        :multi_system -> length(strategic_data.killmail_data)
      end

    cond do
      system_count >= 5 -> 1.0
      system_count >= 3 -> 0.7
      system_count >= 2 -> 0.4
      true -> 0.2
    end
  end

  defp calculate_activity_value(resource_metrics) do
    mining_activity = resource_metrics.mining_activity.mining_intensity
    hauling_activity = resource_metrics.hauling_activity.hauling_intensity

    combined_activity = mining_activity + hauling_activity

    cond do
      combined_activity >= 0.5 -> 1.0
      combined_activity >= 0.3 -> 0.7
      combined_activity >= 0.1 -> 0.4
      true -> 0.1
    end
  end

  defp calculate_control_value(resource_metrics) do
    concentration = resource_metrics.activity_concentration
    conflicts = resource_metrics.resource_conflicts.conflict_count

    if conflicts > 0 do
      # Contested resources have lower control value
      max(0.1, concentration * 0.5)
    else
      concentration
    end
  end

  defp classify_strategic_value(value) do
    cond do
      value >= 0.8 -> :critical
      value >= 0.6 -> :high
      value >= 0.4 -> :moderate
      value >= 0.2 -> :low
      true -> :minimal
    end
  end
end
