defmodule EveDmv.Contexts.SystemAnalysis.Domain.ActivityIntensityCalculator do
  @moduledoc """
  Calculates activity intensity metrics for systems.
  Provides normalized scoring for comparison across regions.
  """

  import Ash.Query

  alias EveDmv.Api
  alias EveDmv.Killmails.KillmailRaw

  @doc """
  Calculates comprehensive intensity score for a system
  """
  def calculate_intensity(system_id, timeframe_opts \\ []) do
    timeframe = build_timeframe(timeframe_opts)

    with {:ok, metrics} <- gather_intensity_metrics(system_id, timeframe) do
      # Calculate component scores
      scores = %{
        volume_score: calculate_volume_score(metrics),
        value_score: calculate_value_score(metrics),
        participant_score: calculate_participant_score(metrics),
        complexity_score: calculate_complexity_score(metrics),
        persistence_score: calculate_persistence_score(metrics)
      }

      # Weighted combination
      overall_intensity = calculate_weighted_intensity(scores)

      {:ok,
       %{
         system_id: system_id,
         timeframe: timeframe,
         raw_metrics: metrics,
         component_scores: scores,
         overall_intensity: overall_intensity,
         classification: classify_intensity(overall_intensity),
         percentile: calculate_percentile(overall_intensity, timeframe)
       }}
    end
  end

  @doc """
  Calculates relative intensity compared to neighboring systems
  """
  def calculate_relative_intensity(system_id, neighbor_ids, timeframe_opts \\ []) do
    _timeframe = build_timeframe(timeframe_opts)

    # Get intensity for target and neighbors
    with {:ok, target_intensity} <- calculate_intensity(system_id, timeframe_opts),
         {:ok, neighbor_intensities} <- get_neighbor_intensities(neighbor_ids, timeframe_opts) do
      average_neighbor = calculate_average(neighbor_intensities)

      {:ok,
       %{
         system_intensity: target_intensity.overall_intensity,
         neighbor_average: average_neighbor,
         relative_score: target_intensity.overall_intensity / max(average_neighbor, 0.1),
         classification:
           classify_relative_intensity(target_intensity.overall_intensity, average_neighbor),
         outlier_status:
           detect_outlier_status(target_intensity.overall_intensity, neighbor_intensities)
       }}
    end
  end

  defp build_timeframe(opts) do
    default_hours = Keyword.get(opts, :hours, 24)
    default_days = Keyword.get(opts, :days, 0)

    total_hours = default_hours + default_days * 24

    %{
      start_time: DateTime.add(DateTime.utc_now(), -total_hours * 3600, :second),
      end_time: DateTime.utc_now(),
      duration_hours: total_hours
    }
  end

  defp gather_intensity_metrics(system_id, timeframe) do
    # Query killmails for the system
    killmails =
      KillmailRaw
      |> filter(solar_system_id == ^system_id)
      |> filter(killmail_time >= ^timeframe.start_time)
      |> filter(killmail_time <= ^timeframe.end_time)
      |> select([
        :killmail_id,
        :killmail_time,
        :total_value,
        :victim_character_id,
        :victim_ship_type_id,
        :data
      ])
      |> Api.read!()

    metrics = %{
      total_kills: length(killmails),
      unique_victims: count_unique_victims(killmails),
      unique_attackers: count_unique_attackers(killmails),
      total_isk_destroyed: sum_isk_value(killmails),
      average_fleet_size: calculate_avg_fleet_size(killmails),
      time_distribution: analyze_time_distribution(killmails),
      ship_diversity: calculate_ship_diversity(killmails),
      alliance_diversity: calculate_alliance_diversity(killmails),
      solo_vs_fleet_ratio: calculate_engagement_types(killmails),
      capital_involvement: count_capital_kills(killmails)
    }

    {:ok, metrics}
  rescue
    error ->
      {:error, {:metrics_gathering_failed, error}}
  end

  defp count_unique_victims(killmails) do
    killmails
    |> Enum.map(& &1.victim_character_id)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> length()
  end

  defp count_unique_attackers(killmails) do
    killmails
    |> Enum.flat_map(fn killmail ->
      case killmail.data do
        %{"attackers" => attackers} when is_list(attackers) ->
          attackers
          |> Enum.map(&Map.get(&1, "character_id"))
          |> Enum.reject(&is_nil/1)

        _ ->
          []
      end
    end)
    |> Enum.uniq()
    |> length()
  end

  defp sum_isk_value(killmails) do
    killmails
    |> Enum.map(&(&1.total_value || 0))
    |> Enum.sum()
  end

  defp calculate_avg_fleet_size(killmails) do
    case killmails do
      [] ->
        0.0

      kills ->
        total_attackers =
          kills
          |> Enum.map(fn killmail ->
            case killmail.data do
              %{"attackers" => attackers} when is_list(attackers) ->
                length(attackers)

              _ ->
                0
            end
          end)
          |> Enum.sum()

        total_attackers / length(kills)
    end
  end

  defp analyze_time_distribution(killmails) do
    # Group by hour to see activity distribution
    hourly_counts =
      killmails
      |> Enum.group_by(fn killmail -> killmail.killmail_time.hour end)
      |> Enum.map(fn {hour, kills} -> {hour, length(kills)} end)
      |> Map.new()

    # Calculate time coverage (how many different hours had activity)
    hours_with_activity = Map.keys(hourly_counts) |> length()

    %{
      hourly_distribution: hourly_counts,
      hours_covered: hours_with_activity,
      coverage_percentage: hours_with_activity / 24 * 100
    }
  end

  defp calculate_ship_diversity(killmails) do
    unique_ships =
      killmails
      |> Enum.map(& &1.victim_ship_type_id)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> length()

    case killmails do
      [] -> 0.0
      kills -> unique_ships / length(kills)
    end
  end

  defp calculate_alliance_diversity(killmails) do
    unique_alliances =
      killmails
      |> Enum.flat_map(fn killmail ->
        victim_alliance =
          case killmail.data do
            %{"victim" => %{"alliance_id" => alliance_id}} -> [alliance_id]
            _ -> []
          end

        attacker_alliances =
          case killmail.data do
            %{"attackers" => attackers} when is_list(attackers) ->
              attackers
              |> Enum.map(&Map.get(&1, "alliance_id"))
              |> Enum.reject(&is_nil/1)

            _ ->
              []
          end

        victim_alliance ++ attacker_alliances
      end)
      |> Enum.uniq()
      |> length()

    unique_alliances
  end

  defp calculate_engagement_types(killmails) do
    grouped =
      killmails
      |> Enum.group_by(fn killmail ->
        attacker_count =
          case killmail.data do
            %{"attackers" => attackers} when is_list(attackers) ->
              length(attackers)

            _ ->
              1
          end

        cond do
          attacker_count == 1 -> :solo
          attacker_count <= 5 -> :small_gang
          attacker_count <= 15 -> :medium_gang
          true -> :fleet
        end
      end)

    total = length(killmails)

    if total > 0 do
      %{
        solo: length(Map.get(grouped, :solo, [])) / total,
        small_gang: length(Map.get(grouped, :small_gang, [])) / total,
        medium_gang: length(Map.get(grouped, :medium_gang, [])) / total,
        fleet: length(Map.get(grouped, :fleet, [])) / total
      }
    else
      %{solo: 0, small_gang: 0, medium_gang: 0, fleet: 0}
    end
  end

  defp count_capital_kills(killmails) do
    # Count kills involving capital ships
    # This is simplified - would check actual ship types in production
    killmails
    |> Enum.count(fn killmail ->
      capital_ship?(killmail.victim_ship_type_id)
    end)
  end

  defp capital_ship?(ship_type_id) do
    # Simplified capital ship detection
    # In production, would query actual ship data
    ship_type_id && ship_type_id > 20_000
  end

  defp calculate_volume_score(metrics) do
    # Score based on kill volume
    # Use logarithmic scale to handle outliers
    base_score = :math.log10(max(metrics.total_kills, 1)) * 10
    min(100, base_score * 3)
  end

  defp calculate_value_score(metrics) do
    # Score based on ISK destroyed
    billions_destroyed = metrics.total_isk_destroyed / 1_000_000_000
    base_score = :math.log10(max(billions_destroyed, 0.1)) * 15
    min(100, base_score + 50)
  end

  defp calculate_participant_score(metrics) do
    # Score based on unique participants
    total_participants = metrics.unique_victims + metrics.unique_attackers
    base_score = :math.sqrt(total_participants) * 5
    min(100, base_score)
  end

  defp calculate_complexity_score(metrics) do
    # Score based on diversity and complexity of engagements
    diversity_score = metrics.ship_diversity * 20
    alliance_score = min(30, metrics.alliance_diversity * 10)
    fleet_complexity = min(30, metrics.average_fleet_size * 2)
    capital_bonus = if metrics.capital_involvement > 0, do: 20, else: 0

    min(100, diversity_score + alliance_score + fleet_complexity + capital_bonus)
  end

  defp calculate_persistence_score(metrics) do
    # Score based on sustained activity over time
    time_coverage = metrics.time_distribution.coverage_percentage
    consistency = calculate_consistency(metrics.time_distribution.hourly_distribution)

    time_coverage * 0.6 + consistency * 0.4
  end

  defp calculate_consistency(hourly_distribution) do
    if map_size(hourly_distribution) == 0 do
      0.0
    else
      counts = Map.values(hourly_distribution)
      mean = Enum.sum(counts) / length(counts)

      variance =
        counts
        |> Enum.map(fn count -> :math.pow(count - mean, 2) end)
        |> Enum.sum()
        |> Kernel./(length(counts))

      # Lower variance = higher consistency
      # Normalize to 0-100 scale
      max(0, 100 - :math.sqrt(variance) * 5)
    end
  end

  defp calculate_weighted_intensity(scores) do
    # Weighted combination of all scores
    weights = %{
      volume_score: 0.25,
      value_score: 0.20,
      participant_score: 0.20,
      complexity_score: 0.20,
      persistence_score: 0.15
    }

    Enum.reduce(scores, 0, fn {key, value}, acc ->
      acc + value * Map.get(weights, key, 0)
    end)
  end

  defp classify_intensity(score) do
    cond do
      score >= 80 -> :extreme
      score >= 60 -> :high
      score >= 40 -> :moderate
      score >= 20 -> :low
      true -> :minimal
    end
  end

  defp calculate_percentile(_score, _timeframe) do
    # Placeholder for percentile calculation
    # Would compare against historical data
    50.0
  end

  defp get_neighbor_intensities(neighbor_ids, timeframe_opts) do
    intensities =
      neighbor_ids
      |> Enum.map(fn neighbor_id ->
        case calculate_intensity(neighbor_id, timeframe_opts) do
          {:ok, intensity} -> intensity.overall_intensity
          _ -> 0.0
        end
      end)

    {:ok, intensities}
  end

  defp calculate_average(values) do
    case values do
      [] -> 0.0
      list -> Enum.sum(list) / length(list)
    end
  end

  defp classify_relative_intensity(system_intensity, neighbor_average) do
    ratio = system_intensity / max(neighbor_average, 0.1)

    cond do
      ratio >= 3.0 -> :major_hotspot
      ratio >= 2.0 -> :hotspot
      ratio >= 1.5 -> :above_average
      ratio >= 0.5 -> :average
      ratio >= 0.25 -> :below_average
      true -> :quiet
    end
  end

  defp detect_outlier_status(system_intensity, neighbor_intensities) do
    case neighbor_intensities do
      [] ->
        :unknown

      intensities ->
        mean = calculate_average(intensities)
        std_dev = calculate_standard_deviation(intensities, mean)

        z_score = abs(system_intensity - mean) / max(std_dev, 0.1)

        cond do
          z_score >= 3.0 -> :extreme_outlier
          z_score >= 2.0 -> :outlier
          z_score >= 1.0 -> :moderate_outlier
          true -> :normal
        end
    end
  end

  defp calculate_standard_deviation(values, mean) do
    variance =
      values
      |> Enum.map(fn value -> :math.pow(value - mean, 2) end)
      |> Enum.sum()
      |> Kernel./(length(values))

    :math.sqrt(variance)
  end
end
