defmodule EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.ThreatScoringCoordinator do
  @moduledoc """
  Main coordinator for threat scoring analysis.

  Orchestrates the various threat scoring engines and combines their results into
  a comprehensive threat assessment.
  """

  alias EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.Engines.{
    CombatThreatEngine,
    ShipMasteryEngine,
    GangEffectivenessEngine,
    UnpredictabilityEngine
  }

  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Api
  alias EveDmv.Intelligence.Cache.IntelligenceCache

  import Ash.Query

  require Logger

  # Threat scoring parameters optimized for EVE PvP
  @analysis_window_days 90
  @minimum_killmails_for_scoring 5
  @combat_skill_weight 0.30
  @ship_mastery_weight 0.25
  @gang_effectiveness_weight 0.25
  @unpredictability_weight 0.10
  @recent_activity_weight 0.10

  # Cache configuration for performance optimization
  # 6 hours for basic threat scores
  @cache_ttl_threat_score :timer.hours(6)
  # 12 hours for trend analysis
  @cache_ttl_trend_analysis :timer.hours(12)
  # 4 hours for comparisons
  @cache_ttl_comparison :timer.hours(4)

  @threat_levels %{
    extreme: 9.0,
    very_high: 7.5,
    high: 6.0,
    moderate: 4.0,
    low: 2.0,
    minimal: 0.0
  }

  @doc """
  Calculates comprehensive threat score for a character with caching.
  """
  def calculate_threat_score(character_id, options \\ []) do
    ttl = Keyword.get(options, :cache_ttl, @cache_ttl_threat_score)

    case IntelligenceCache.get_threat_score(character_id, options, ttl) do
      {:ok, result} -> {:ok, result}
      {:error, _} = error -> error
    end
  end

  @doc """
  Calculates comprehensive threat score for a character without caching.

  This is the internal implementation called by the cache system.
  """
  def calculate_threat_score_uncached(character_id, options \\ []) do
    Logger.info("Calculating threat score for character #{character_id}")

    analysis_window_days = Keyword.get(options, :analysis_window_days, @analysis_window_days)

    # Fetch real combat data from the database
    case fetch_character_combat_data(character_id, analysis_window_days) do
      {:error, :insufficient_data} ->
        {:error, :insufficient_data}

      {:ok, combat_data} ->
        # Calculate dimensional scores using the real engines with real data
        combat_score = CombatThreatEngine.calculate_combat_skill_score(combat_data)
        ship_score = ShipMasteryEngine.calculate_ship_mastery_score(combat_data)
        gang_score = GangEffectivenessEngine.calculate_gang_effectiveness_score(combat_data)

        unpredictability_score =
          UnpredictabilityEngine.calculate_unpredictability_score(combat_data)

        recent_activity_score = calculate_recent_activity_score(combat_data)

        dimensional_scores = %{
          combat_skill: combat_score,
          ship_mastery: ship_score,
          gang_effectiveness: gang_score,
          unpredictability: unpredictability_score,
          recent_activity: recent_activity_score
        }

        # Calculate weighted threat score
        weighted_score = calculate_weighted_threat_score(dimensional_scores)
        threat_level = determine_threat_level(weighted_score)

        {:ok,
         %{
           character_id: character_id,
           threat_score: weighted_score,
           threat_level: threat_level,
           confidence: calculate_confidence(dimensional_scores),
           analysis_window_days: analysis_window_days,
           total_killmails: length(combat_data.killmails),
           dimensional_scores: dimensional_scores,
           insights: generate_insights(dimensional_scores, threat_level),
           analyzed_at: DateTime.utc_now()
         }}

      {:error, reason} ->
        Logger.warning(
          "Failed to fetch combat data for character #{character_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Compare threat levels between multiple characters with caching.
  """
  def compare_threat_levels(character_ids, options \\ []) when is_list(character_ids) do
    ttl = Keyword.get(options, :cache_ttl, @cache_ttl_comparison)

    case IntelligenceCache.get_threat_comparison(character_ids, options, ttl) do
      {:ok, result} -> {:ok, result}
      {:error, _} = error -> error
    end
  end

  @doc """
  Compare threat levels between multiple characters without caching.

  This is the internal implementation called by the cache system.
  """
  def compare_threat_levels_uncached(character_ids, options \\ []) when is_list(character_ids) do
    Logger.info("Comparing threat levels for #{length(character_ids)} characters")

    # Calculate threat scores for all characters
    {successful_comparisons, failed_comparisons} =
      character_ids
      |> Enum.map(fn character_id ->
        case calculate_threat_score_uncached(character_id, options) do
          {:ok, threat_data} -> {:ok, threat_data}
          {:error, reason} -> {:error, {character_id, reason}}
        end
      end)
      |> Enum.split_with(&match?({:ok, _}, &1))

    # Extract successful threat data
    comparisons =
      successful_comparisons
      |> Enum.map(fn {:ok, data} -> data end)
      |> Enum.sort_by(& &1.threat_score, :desc)

    if Enum.empty?(comparisons) do
      {:error, :no_valid_threat_data}
    else
      # Calculate real statistics
      threat_scores = Enum.map(comparisons, & &1.threat_score)
      average_threat = Enum.sum(threat_scores) / length(threat_scores)

      # Count threat level distribution
      threat_distribution =
        comparisons
        |> Enum.group_by(& &1.threat_level)
        |> Map.new(fn {level, chars} -> {level, length(chars)} end)
        |> Map.merge(%{extreme: 0, very_high: 0, high: 0, moderate: 0, low: 0, minimal: 0})

      {:ok,
       %{
         characters: comparisons,
         highest_threat: List.first(comparisons),
         lowest_threat: List.last(comparisons),
         average_threat: Float.round(average_threat, 2),
         threat_distribution: threat_distribution,
         successful_analyses: length(comparisons),
         failed_analyses: length(failed_comparisons),
         failures: Enum.map(failed_comparisons, fn {:error, failure} -> failure end)
       }}
    end
  end

  @doc """
  Analyze threat trends for a character over time with caching.
  """
  def analyze_threat_trends(character_id, options \\ []) do
    ttl = Keyword.get(options, :cache_ttl, @cache_ttl_trend_analysis)

    case IntelligenceCache.get_threat_trends(character_id, options, ttl) do
      {:ok, result} -> {:ok, result}
      {:error, _} = error -> error
    end
  end

  @doc """
  Analyze threat trends for a character over time without caching.

  This is the internal implementation called by the cache system.
  """
  def analyze_threat_trends_uncached(character_id, options \\ []) do
    Logger.info("Analyzing threat trends for character #{character_id}")

    # Calculate threat scores for different time periods to establish trend
    # days
    analysis_periods = [30, 60, 90]

    historical_scores =
      Enum.map(analysis_periods, fn days ->
        case calculate_threat_score_uncached(
               character_id,
               Keyword.put(options, :analysis_window_days, days)
             ) do
          {:ok, threat_data} ->
            %{
              period_days: days,
              threat_score: threat_data.threat_score,
              threat_level: threat_data.threat_level,
              total_killmails: threat_data.total_killmails,
              confidence: threat_data.confidence
            }

          {:error, _} ->
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    if length(historical_scores) < 2 do
      {:error, :insufficient_data_for_trend_analysis}
    else
      # Calculate trend direction and strength
      scores = Enum.map(historical_scores, & &1.threat_score)
      {trend_direction, trend_strength} = calculate_trend_metrics(scores)

      # Analyze recent changes (30-day vs 60-day)
      recent_changes = analyze_recent_changes(historical_scores)

      # Simple prediction based on trend
      latest_score = List.first(scores)
      predicted_score = latest_score + trend_strength * 0.5

      # Confidence based on data consistency
      confidence = calculate_trend_confidence(historical_scores)

      {:ok,
       %{
         character_id: character_id,
         trend_direction: trend_direction,
         trend_strength: Float.round(trend_strength, 3),
         historical_scores: historical_scores,
         recent_changes: recent_changes,
         prediction: %{
           next_30_days: Float.round(max(0.0, min(10.0, predicted_score)), 2),
           confidence: Float.round(confidence, 2)
         },
         analysis_periods: analysis_periods,
         analyzed_at: DateTime.utc_now()
       }}
    end
  end

  # Private helper functions

  defp calculate_weighted_threat_score(dimensional_scores) do
    dimensional_scores.combat_skill.normalized_score * @combat_skill_weight +
      dimensional_scores.ship_mastery.normalized_score * @ship_mastery_weight +
      dimensional_scores.gang_effectiveness.normalized_score * @gang_effectiveness_weight +
      dimensional_scores.unpredictability.normalized_score * @unpredictability_weight +
      dimensional_scores.recent_activity.normalized_score * @recent_activity_weight
  end

  defp determine_threat_level(score) do
    cond do
      score >= @threat_levels.extreme -> :extreme
      score >= @threat_levels.very_high -> :very_high
      score >= @threat_levels.high -> :high
      score >= @threat_levels.moderate -> :moderate
      score >= @threat_levels.low -> :low
      true -> :minimal
    end
  end

  defp calculate_recent_activity_score(combat_data) do
    killmails = combat_data.killmails
    analysis_window_days = combat_data.analysis_period_days

    if Enum.empty?(killmails) do
      %{
        normalized_score: 0.0,
        recent_kills: 0,
        activity_trend: :inactive,
        last_activity: nil
      }
    else
      # Calculate activity metrics
      total_killmails = length(killmails)
      attacker_killmails = length(combat_data.attacker_killmails)
      victim_killmails = length(combat_data.victim_killmails)

      # Recent activity score based on killmail frequency
      kills_per_day = total_killmails / analysis_window_days

      # Normalize activity score (5 kills/day = max score)
      activity_score = min(10.0, kills_per_day * 2.0)

      # Determine activity trend based on temporal distribution
      activity_trend = analyze_activity_trend(killmails)

      # Get last activity timestamp
      last_activity =
        killmails
        |> Enum.max_by(& &1.killmail_time, DateTime)
        |> Map.get(:killmail_time)

      %{
        normalized_score: activity_score,
        recent_kills: attacker_killmails,
        recent_losses: victim_killmails,
        total_engagements: total_killmails,
        kills_per_day: Float.round(kills_per_day, 2),
        activity_trend: activity_trend,
        last_activity: last_activity
      }
    end
  end

  defp calculate_confidence(dimensional_scores) do
    # Calculate confidence based on data quality and consistency
    scores = [
      dimensional_scores.combat_skill.normalized_score,
      dimensional_scores.ship_mastery.normalized_score,
      dimensional_scores.gang_effectiveness.normalized_score,
      dimensional_scores.unpredictability.normalized_score,
      dimensional_scores.recent_activity.normalized_score
    ]

    # Simple confidence calculation - higher variance means lower confidence
    variance =
      Enum.reduce(scores, 0, fn score, acc -> acc + (score - 5.0) * (score - 5.0) end) /
        length(scores)

    max(0.1, 1.0 - variance / 25.0)
  end

  defp generate_insights(dimensional_scores, threat_level) do
    insights = ["Character shows #{threat_level} threat level"]

    # Add specific insights based on dimensional scores
    insights =
      if dimensional_scores.combat_skill.normalized_score > 7.0 do
        insights ++ ["High combat proficiency detected"]
      else
        insights ++ ["Moderate combat capabilities"]
      end

    # Add more detailed insights from each dimensional score
    insights = insights ++ dimensional_scores.combat_skill.insights
    insights = insights ++ dimensional_scores.ship_mastery.insights
    insights = insights ++ dimensional_scores.gang_effectiveness.insights
    insights = insights ++ dimensional_scores.unpredictability.insights

    # Activity insights
    insights =
      case dimensional_scores.recent_activity.activity_trend do
        :increasing -> insights ++ ["Increasing activity levels - becoming more active"]
        :decreasing -> insights ++ ["Decreasing activity levels - less engaged recently"]
        :stable -> insights ++ ["Stable activity pattern"]
        :inactive -> insights ++ ["Low recent activity"]
      end

    insights
  end

  defp fetch_character_combat_data(character_id, analysis_window_days) do
    cutoff_date =
      DateTime.add(DateTime.utc_now(), -analysis_window_days * 24 * 60 * 60, :second)

    # Optimized: Fetch killmails where character was victim using existing index
    victim_query =
      KillmailRaw
      |> new()
      |> filter(victim_character_id: character_id)
      |> filter(killmail_time: [gte: cutoff_date])
      |> sort(killmail_time: :desc)
      |> limit(500)

    # Optimized: Use a more targeted approach for attacker queries
    # We'll still need to post-filter but limit the initial dataset more aggressively
    attacker_query =
      KillmailRaw
      |> new()
      |> filter(killmail_time: [gte: cutoff_date])
      |> sort(killmail_time: :desc)
      # Increased limit but still manageable
      |> limit(2000)

    # Execute both queries in parallel for better performance
    tasks = [
      Task.async(fn -> Ash.read(victim_query, domain: Api) end),
      Task.async(fn -> Ash.read(attacker_query, domain: Api) end)
    ]

    case Task.await_many(tasks, 10_000) do
      [{:ok, victim_killmails}, {:ok, potential_attacker_killmails}] ->
        # Filter attacker killmails for this character - optimized filtering
        attacker_killmails =
          Enum.filter(potential_attacker_killmails, fn km ->
            case km.raw_data do
              %{"attackers" => attackers} when is_list(attackers) ->
                Enum.any?(attackers, &(&1["character_id"] == character_id))

              _ ->
                false
            end
          end)

        all_killmails = Enum.uniq_by(victim_killmails ++ attacker_killmails, & &1.killmail_id)

        if length(all_killmails) < @minimum_killmails_for_scoring do
          {:error, :insufficient_data}
        else
          combat_data = %{
            killmails: all_killmails,
            analysis_period_days: analysis_window_days,
            data_cutoff: cutoff_date,
            victim_killmails: victim_killmails,
            attacker_killmails: attacker_killmails
          }

          {:ok, combat_data}
        end

      [victim_result, attacker_result] ->
        # Handle partial failures - use what we have
        case {victim_result, attacker_result} do
          {{:ok, victim_killmails}, {:ok, potential_attacker_killmails}} ->
            attacker_killmails =
              Enum.filter(potential_attacker_killmails, fn km ->
                case km.raw_data do
                  %{"attackers" => attackers} when is_list(attackers) ->
                    Enum.any?(attackers, &(&1["character_id"] == character_id))

                  _ ->
                    false
                end
              end)

            all_killmails = Enum.uniq_by(victim_killmails ++ attacker_killmails, & &1.killmail_id)

            if length(all_killmails) < @minimum_killmails_for_scoring do
              {:error, :insufficient_data}
            else
              combat_data = %{
                killmails: all_killmails,
                analysis_period_days: analysis_window_days,
                data_cutoff: cutoff_date,
                victim_killmails: victim_killmails,
                attacker_killmails: attacker_killmails
              }

              {:ok, combat_data}
            end

          {{:ok, victim_killmails}, _} ->
            # Only victim data available
            if length(victim_killmails) < @minimum_killmails_for_scoring do
              {:error, :insufficient_data}
            else
              Logger.warning("Only victim data available for character #{character_id}")

              combat_data = %{
                killmails: victim_killmails,
                analysis_period_days: analysis_window_days,
                data_cutoff: cutoff_date,
                victim_killmails: victim_killmails,
                attacker_killmails: []
              }

              {:ok, combat_data}
            end

          {_, {:ok, potential_attacker_killmails}} ->
            # Only attacker data available
            attacker_killmails =
              Enum.filter(potential_attacker_killmails, fn km ->
                case km.raw_data do
                  %{"attackers" => attackers} when is_list(attackers) ->
                    Enum.any?(attackers, &(&1["character_id"] == character_id))

                  _ ->
                    false
                end
              end)

            if length(attacker_killmails) < @minimum_killmails_for_scoring do
              {:error, :insufficient_data}
            else
              Logger.warning("Only attacker data available for character #{character_id}")

              combat_data = %{
                killmails: attacker_killmails,
                analysis_period_days: analysis_window_days,
                data_cutoff: cutoff_date,
                victim_killmails: [],
                attacker_killmails: attacker_killmails
              }

              {:ok, combat_data}
            end

          _ ->
            {:error, :database_error}
        end

      error ->
        Logger.error("Failed to fetch combat data: #{inspect(error)}")
        {:error, :database_error}
    end
  rescue
    error ->
      Logger.error("Exception during combat data fetch: #{inspect(error)}")
      {:error, :database_error}
  end

  defp analyze_activity_trend(killmails) do
    if length(killmails) < 5 do
      :stable
    else
      # Sort killmails by time
      sorted_killmails = Enum.sort_by(killmails, & &1.killmail_time, DateTime)

      # Split into early and recent periods
      split_point = div(length(sorted_killmails), 2)
      early_period = Enum.take(sorted_killmails, split_point)
      recent_period = Enum.drop(sorted_killmails, split_point)

      early_count = length(early_period)
      recent_count = length(recent_period)

      # Calculate trend based on activity change
      cond do
        recent_count > early_count * 1.3 -> :increasing
        recent_count < early_count * 0.7 -> :decreasing
        true -> :stable
      end
    end
  end

  defp calculate_trend_metrics(scores) when length(scores) >= 2 do
    # Calculate linear trend between first (most recent) and last (oldest) scores
    first_score = List.first(scores)
    last_score = List.last(scores)

    trend_strength = first_score - last_score

    trend_direction =
      cond do
        trend_strength > 0.5 -> :increasing
        trend_strength < -0.5 -> :decreasing
        true -> :stable
      end

    {trend_direction, trend_strength}
  end

  defp analyze_recent_changes(historical_scores) do
    if length(historical_scores) >= 2 do
      recent_30_day = Enum.find(historical_scores, &(&1.period_days == 30))
      recent_60_day = Enum.find(historical_scores, &(&1.period_days == 60))

      if recent_30_day && recent_60_day do
        score_change = recent_30_day.threat_score - recent_60_day.threat_score

        level_change =
          if recent_30_day.threat_level != recent_60_day.threat_level do
            "#{recent_60_day.threat_level} -> #{recent_30_day.threat_level}"
          else
            "stable at #{recent_30_day.threat_level}"
          end

        [
          %{
            change_type: :threat_score,
            value: Float.round(score_change, 2),
            description: if(score_change > 0, do: "threat increasing", else: "threat decreasing")
          },
          %{
            change_type: :threat_level,
            value: level_change,
            description: "threat level change"
          }
        ]
      else
        []
      end
    else
      []
    end
  end

  defp calculate_trend_confidence(historical_scores) do
    # Confidence based on data volume and consistency
    total_killmails = Enum.sum(Enum.map(historical_scores, & &1.total_killmails))

    avg_confidence =
      Enum.sum(Enum.map(historical_scores, & &1.confidence)) / length(historical_scores)

    # More killmails and higher individual confidence = higher trend confidence
    # 50+ killmails = max confidence
    killmail_factor = min(1.0, total_killmails / 50.0)

    avg_confidence * killmail_factor
  end
end
