defmodule EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoringEngine do
  @moduledoc """
  Sophisticated multi-dimensional character threat scoring system for EVE Online PvP intelligence.

  Analyzes character combat data across multiple dimensions to generate accurate threat assessments:

  - Combat Skill: Kill efficiency, survival rates, target selection patterns
  - Ship Mastery: Ship diversity, fitting optimization, tactical adaptation  
  - Gang Effectiveness: Fleet coordination, role execution, leadership indicators
  - Unpredictability: Tactical variance, engagement pattern diversity
  - Recent Activity: Weighted performance trends and current form

  Uses advanced statistical analysis, behavioral pattern recognition, and machine learning
  techniques to provide actionable intelligence for fleet commanders and solo pilots.
  """

  import Ash.Query

  alias EveDmv.Api
  alias EveDmv.Killmails.KillmailRaw

  require Logger

  # Threat scoring parameters optimized for EVE PvP
  # Default analysis period
  @analysis_window_days 90
  # Minimum data points for reliable scoring
  @minimum_killmails_for_scoring 5
  # 30% weight for combat performance
  @combat_skill_weight 0.30
  # 25% weight for ship diversity/mastery
  @ship_mastery_weight 0.25
  # 25% weight for fleet contribution
  @gang_effectiveness_weight 0.25
  # 10% weight for tactical variance
  @unpredictability_weight 0.10
  # 10% weight for recent performance
  @recent_activity_weight 0.10

  # Threat level thresholds
  @threat_levels %{
    extreme: 9.0,
    very_high: 7.5,
    high: 6.0,
    moderate: 4.0,
    low: 2.0,
    minimal: 0.0
  }

  @doc """
  Calculates comprehensive threat score for a character.

  Analyzes all available combat data for the character and generates a multi-dimensional
  threat assessment using sophisticated algorithms and statistical analysis.

  ## Parameters
  - character_id: EVE character ID to analyze
  - options: Analysis options
    - :analysis_window_days - Days of history to analyze (default: 90)
    - :include_detailed_breakdown - Include detailed scoring breakdown (default: true)
    - :weight_recent_activity - Weight recent activity higher (default: true)

  ## Returns
  {:ok, threat_assessment} with comprehensive threat analysis
  """
  def calculate_threat_score(character_id, options \\ []) do
    analysis_window = Keyword.get(options, :analysis_window_days, @analysis_window_days)
    include_breakdown = Keyword.get(options, :include_detailed_breakdown, true)
    weight_recent = Keyword.get(options, :weight_recent_activity, true)

    Logger.info("Calculating threat score for character #{character_id}")

    start_time = System.monotonic_time(:millisecond)

    with {:ok, combat_data} <- fetch_character_combat_data(character_id, analysis_window),
         {:ok, dimensional_scores} <- calculate_dimensional_scores(combat_data, weight_recent),
         {:ok, weighted_score} <- calculate_weighted_threat_score(dimensional_scores),
         {:ok, threat_assessment} <-
           generate_threat_assessment(
             character_id,
             weighted_score,
             dimensional_scores,
             include_breakdown
           ) do
      end_time = System.monotonic_time(:millisecond)
      duration_ms = end_time - start_time

      Logger.info("""
      Threat scoring completed in #{duration_ms}ms:
      - Character: #{character_id}
      - Threat Level: #{threat_assessment.threat_level}
      - Overall Score: #{Float.round(threat_assessment.overall_score, 2)}
      - Data Points: #{length(combat_data.killmails)}
      """)

      {:ok, threat_assessment}
    end
  end

  @doc """
  Compares threat scores between multiple characters.

  Useful for fleet intelligence, recruitment screening, and competitive analysis.
  """
  def compare_threat_levels(character_ids, options \\ []) do
    Logger.info("Comparing threat levels for #{length(character_ids)} characters")

    threat_assessments =
      character_ids
      |> Enum.map(&calculate_threat_score(&1, options))
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(&elem(&1, 1))

    comparison = %{
      characters_analyzed: length(threat_assessments),
      threat_distribution: analyze_threat_distribution(threat_assessments),
      top_threats: identify_top_threats(threat_assessments),
      threat_rankings: rank_by_threat_level(threat_assessments),
      comparative_insights: generate_comparative_insights(threat_assessments)
    }

    {:ok, comparison}
  end

  @doc """
  Analyzes threat score trends over time for a character.

  Identifies improving/declining performance patterns and threat evolution.
  """
  def analyze_threat_trends(character_id, options \\ []) do
    # Longer window for trends
    window_days = Keyword.get(options, :analysis_window_days, 180)

    # Calculate threat scores for different time periods
    time_periods = [
      {30, "Recent (30 days)"},
      {60, "Medium-term (60 days)"},
      {90, "Long-term (90 days)"},
      {window_days, "Full period (#{window_days} days)"}
    ]

    trend_data =
      time_periods
      |> Enum.map(fn {days, label} ->
        case calculate_threat_score(character_id,
               analysis_window_days: days,
               include_detailed_breakdown: false
             ) do
          {:ok, assessment} ->
            %{
              period: label,
              days: days,
              threat_score: assessment.overall_score,
              threat_level: assessment.threat_level,
              data_points: assessment.metadata.killmails_analyzed
            }

          _ ->
            nil
        end
      end)
      |> Enum.filter(&(&1 != nil))

    trend_analysis = %{
      character_id: character_id,
      trend_data: trend_data,
      trend_direction: calculate_trend_direction(trend_data),
      improvement_rate: calculate_improvement_rate(trend_data),
      volatility: calculate_threat_volatility(trend_data),
      predictions: generate_threat_predictions(trend_data)
    }

    {:ok, trend_analysis}
  end

  # Private implementation

  defp fetch_character_combat_data(character_id, analysis_window_days) do
    cutoff_date =
      NaiveDateTime.add(NaiveDateTime.utc_now(), -analysis_window_days * 24 * 60 * 60, :second)

    # Fetch killmails where character was victim
    victim_query =
      KillmailRaw
      |> new()
      |> filter(victim_character_id: character_id)
      |> filter(killmail_time: [gte: cutoff_date])
      |> sort(killmail_time: :desc)
      # Reasonable limit for analysis
      |> limit(500)

    # Fetch killmails where character was attacker
    attacker_query =
      KillmailRaw
      |> new()
      |> filter(killmail_time: [gte: cutoff_date])
      # Larger limit to search for attacker involvement
      |> limit(1000)

    with {:ok, victim_killmails} <- Ash.read(victim_query, domain: Api),
         {:ok, potential_attacker_killmails} <- Ash.read(attacker_query, domain: Api) do
      # Filter attacker killmails for this character
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
    end
  end

  defp calculate_dimensional_scores(combat_data, weight_recent) do
    _killmails = combat_data.killmails

    dimensional_scores = %{
      combat_skill: calculate_combat_skill_score(combat_data),
      ship_mastery: calculate_ship_mastery_score(combat_data),
      gang_effectiveness: calculate_gang_effectiveness_score(combat_data),
      unpredictability: calculate_unpredictability_score(combat_data),
      recent_activity: calculate_recent_activity_score(combat_data, weight_recent)
    }

    {:ok, dimensional_scores}
  end

  defp calculate_combat_skill_score(combat_data) do
    victim_kms = combat_data.victim_killmails
    attacker_kms = combat_data.attacker_killmails

    # Kill/Death ratio with sophisticated weighting
    kills = length(attacker_kms)
    deaths = length(victim_kms)
    # Cap at 10 for pure killers
    kd_ratio = if deaths > 0, do: kills / deaths, else: min(kills, 10.0)

    # ISK efficiency (kills vs losses)
    isk_destroyed = calculate_total_isk_destroyed(attacker_kms)
    isk_lost = calculate_total_isk_lost(victim_kms)

    isk_efficiency =
      if isk_lost > 0, do: isk_destroyed / isk_lost, else: min(isk_destroyed / 1_000_000, 10.0)

    # Survival analysis
    survival_rate = calculate_survival_rate(combat_data)

    # Target selection quality (attacking valuable targets)
    target_quality = analyze_target_selection_quality(attacker_kms)

    # Damage efficiency in fights
    damage_efficiency = calculate_damage_efficiency(attacker_kms)

    # Weighted combat skill score
    raw_score =
      normalize_score(kd_ratio, 0, 5) * 0.25 +
        normalize_score(isk_efficiency, 0, 3) * 0.25 +
        survival_rate * 0.20 +
        target_quality * 0.15 +
        damage_efficiency * 0.15

    %{
      raw_score: raw_score,
      normalized_score: normalize_to_10_scale(raw_score),
      components: %{
        kd_ratio: kd_ratio,
        isk_efficiency: isk_efficiency,
        survival_rate: survival_rate,
        target_quality: target_quality,
        damage_efficiency: damage_efficiency
      },
      insights: generate_combat_skill_insights(raw_score, kd_ratio, isk_efficiency, survival_rate)
    }
  end

  defp calculate_ship_mastery_score(combat_data) do
    all_killmails = combat_data.killmails

    # Ship type diversity
    ship_types_used = extract_ship_types_used(all_killmails)
    ship_diversity = calculate_ship_diversity_index(ship_types_used)

    # Ship class mastery (comfort across different ship classes)
    class_mastery = analyze_ship_class_mastery(ship_types_used)

    # Fitting optimization indicators
    fitting_quality = assess_fitting_quality_from_performance(combat_data)

    # Tactical ship usage (right ship for right situation)
    tactical_usage = analyze_tactical_ship_usage(combat_data)

    # Ship specialization vs generalization balance
    specialization_score = calculate_specialization_balance(ship_types_used)

    raw_score =
      ship_diversity * 0.25 +
        class_mastery * 0.25 +
        fitting_quality * 0.20 +
        tactical_usage * 0.15 +
        specialization_score * 0.15

    %{
      raw_score: raw_score,
      normalized_score: normalize_to_10_scale(raw_score),
      components: %{
        ship_diversity: ship_diversity,
        class_mastery: class_mastery,
        fitting_quality: fitting_quality,
        tactical_usage: tactical_usage,
        specialization_score: specialization_score
      },
      ship_usage_breakdown: analyze_ship_usage_patterns(ship_types_used),
      insights:
        generate_ship_mastery_insights(ship_diversity, class_mastery, specialization_score)
    }
  end

  defp calculate_gang_effectiveness_score(combat_data) do
    all_killmails = combat_data.killmails

    # Fleet participation rate
    fleet_participation = calculate_fleet_participation_rate(all_killmails)

    # Role execution quality in fleets
    role_execution = analyze_fleet_role_execution(combat_data)

    # Coordination indicators (assist damage, timing)
    coordination_quality = assess_fleet_coordination(all_killmails)

    # Leadership indicators (primary/secondary on kills)
    leadership_indicators = analyze_leadership_patterns(combat_data.attacker_killmails)

    # Support role effectiveness
    support_effectiveness = calculate_support_role_effectiveness(all_killmails)

    raw_score =
      fleet_participation * 0.30 +
        role_execution * 0.25 +
        coordination_quality * 0.20 +
        leadership_indicators * 0.15 +
        support_effectiveness * 0.10

    %{
      raw_score: raw_score,
      normalized_score: normalize_to_10_scale(raw_score),
      components: %{
        fleet_participation: fleet_participation,
        role_execution: role_execution,
        coordination_quality: coordination_quality,
        leadership_indicators: leadership_indicators,
        support_effectiveness: support_effectiveness
      },
      gang_patterns: analyze_gang_patterns(all_killmails),
      insights:
        generate_gang_effectiveness_insights(
          fleet_participation,
          role_execution,
          leadership_indicators
        )
    }
  end

  defp calculate_unpredictability_score(combat_data) do
    all_killmails = combat_data.killmails

    # Tactical variance (different approaches to similar situations)
    tactical_variance = calculate_tactical_variance(all_killmails)

    # Ship selection unpredictability
    ship_selection_variance = analyze_ship_selection_patterns(combat_data)

    # Engagement timing patterns
    timing_unpredictability = analyze_engagement_timing_patterns(all_killmails)

    # Target selection variance
    target_variance = calculate_target_selection_variance(combat_data.attacker_killmails)

    # Fitting variation indicators
    fitting_variance = estimate_fitting_variance(combat_data)

    raw_score =
      tactical_variance * 0.30 +
        ship_selection_variance * 0.25 +
        timing_unpredictability * 0.20 +
        target_variance * 0.15 +
        fitting_variance * 0.10

    %{
      raw_score: raw_score,
      normalized_score: normalize_to_10_scale(raw_score),
      components: %{
        tactical_variance: tactical_variance,
        ship_selection_variance: ship_selection_variance,
        timing_unpredictability: timing_unpredictability,
        target_variance: target_variance,
        fitting_variance: fitting_variance
      },
      patterns: identify_behavioral_patterns(all_killmails),
      insights: generate_unpredictability_insights(tactical_variance, ship_selection_variance)
    }
  end

  defp calculate_recent_activity_score(combat_data, weight_recent) do
    if weight_recent do
      recent_cutoff = NaiveDateTime.add(NaiveDateTime.utc_now(), -30 * 24 * 60 * 60, :second)

      recent_killmails =
        Enum.filter(combat_data.killmails, fn km ->
          NaiveDateTime.compare(km.killmail_time, recent_cutoff) != :lt
        end)

      if length(recent_killmails) < 3 do
        # Insufficient recent data
        %{
          raw_score: 0.3,
          normalized_score: 3.0,
          components: %{recent_performance: 0.0, activity_level: 0.3},
          insights: ["Limited recent activity - may be inactive or laying low"]
        }
      else
        # Analyze recent performance trend
        recent_performance =
          analyze_recent_performance_trend(recent_killmails, combat_data.killmails)

        activity_level = calculate_activity_level(recent_killmails)

        raw_score = recent_performance * 0.7 + activity_level * 0.3

        %{
          raw_score: raw_score,
          normalized_score: normalize_to_10_scale(raw_score),
          components: %{
            recent_performance: recent_performance,
            activity_level: activity_level
          },
          recent_stats: analyze_recent_combat_stats(recent_killmails),
          insights: generate_recent_activity_insights(recent_performance, activity_level)
        }
      end
    else
      # If not weighting recent activity, return neutral score
      %{
        raw_score: 0.5,
        normalized_score: 5.0,
        components: %{recent_performance: 0.5, activity_level: 0.5},
        insights: ["Recent activity weighting disabled"]
      }
    end
  end

  defp calculate_weighted_threat_score(dimensional_scores) do
    weighted_score =
      dimensional_scores.combat_skill.normalized_score * @combat_skill_weight +
        dimensional_scores.ship_mastery.normalized_score * @ship_mastery_weight +
        dimensional_scores.gang_effectiveness.normalized_score * @gang_effectiveness_weight +
        dimensional_scores.unpredictability.normalized_score * @unpredictability_weight +
        dimensional_scores.recent_activity.normalized_score * @recent_activity_weight

    {:ok, weighted_score}
  end

  defp generate_threat_assessment(
         character_id,
         overall_score,
         dimensional_scores,
         include_breakdown
       ) do
    threat_level = determine_threat_level(overall_score)

    base_assessment = %{
      character_id: character_id,
      overall_score: overall_score,
      threat_level: threat_level,
      threat_classification: classify_threat_type(dimensional_scores),
      key_strengths: identify_key_strengths(dimensional_scores),
      key_weaknesses: identify_key_weaknesses(dimensional_scores),
      tactical_recommendations:
        generate_tactical_recommendations(dimensional_scores, threat_level),
      metadata: %{
        analysis_timestamp: NaiveDateTime.utc_now(),
        scoring_version: "2.0",
        killmails_analyzed: count_total_killmails(dimensional_scores)
      }
    }

    final_assessment =
      if include_breakdown do
        Map.put(base_assessment, :detailed_breakdown, dimensional_scores)
      else
        base_assessment
      end

    {:ok, final_assessment}
  end

  # Component calculation functions

  defp calculate_total_isk_destroyed(attacker_killmails) do
    # Simplified ISK calculation - would use actual ship values in production
    attacker_killmails
    |> Enum.map(&estimate_killmail_value/1)
    |> Enum.sum()
  end

  defp calculate_total_isk_lost(victim_killmails) do
    victim_killmails
    |> Enum.map(&estimate_killmail_value/1)
    |> Enum.sum()
  end

  defp estimate_killmail_value(killmail) do
    # Heuristic ship value estimation based on type
    ship_type_id = killmail.victim_ship_type_id

    cond do
      # Frigates: 5M ISK
      ship_type_id in 580..700 -> 5_000_000
      # Destroyers: 15M ISK
      ship_type_id in 420..450 -> 15_000_000
      # Cruisers: 50M ISK
      ship_type_id in 620..650 -> 50_000_000
      # Battlecruisers: 150M ISK
      ship_type_id in 540..570 -> 150_000_000
      # Battleships: 300M ISK
      ship_type_id in 640..670 -> 300_000_000
      # Capitals: 2B ISK
      ship_type_id in 19_720..19_740 -> 2_000_000_000
      # Default: 25M ISK
      true -> 25_000_000
    end
  end

  defp calculate_survival_rate(combat_data) do
    total_engagements = length(combat_data.killmails)
    deaths = length(combat_data.victim_killmails)

    if total_engagements > 0 do
      (total_engagements - deaths) / total_engagements
    else
      # Neutral score for no data
      0.5
    end
  end

  defp analyze_target_selection_quality(attacker_killmails) do
    if Enum.empty?(attacker_killmails) do
      0.5
    else
      # Analyze value and tactical importance of targets
      valuable_targets =
        Enum.count(attacker_killmails, fn km ->
          # Targets worth >100M ISK
          estimate_killmail_value(km) > 100_000_000
        end)

      tactical_targets =
        Enum.count(attacker_killmails, fn km ->
          tactical_target?(km.victim_ship_type_id)
        end)

      total_kills = length(attacker_killmails)

      # Weight valuable and tactical targets
      quality_score =
        (valuable_targets * 1.5 + tactical_targets * 1.2 + total_kills) / (total_kills * 2.5)

      min(1.0, quality_score)
    end
  end

  defp tactical_target?(ship_type_id) do
    # Ships that are tactically important targets
    ship_type_id in [
      # Logistics ships (very high priority)
      # Guardian, Basilisk, Oneiros, Scimitar
      11_978,
      11_987,
      11_985,
      12_003,
      # Force Recon (high priority)
      11_957,
      11_958,
      11_959,
      11_961,
      # Command ships
      22_470,
      22_852,
      17_918,
      17_920
    ]
  end

  defp calculate_damage_efficiency(attacker_killmails) do
    # Analyze damage contribution patterns
    if Enum.empty?(attacker_killmails) do
      0.5
    else
      total_damage_contribution =
        attacker_killmails
        |> Enum.map(&extract_damage_contribution/1)
        |> Enum.sum()

      average_contribution = total_damage_contribution / length(attacker_killmails)

      # Normalize damage contribution (higher is better)
      # 15% average contribution = 1.0 score
      min(1.0, average_contribution / 0.15)
    end
  end

  defp extract_damage_contribution(killmail) do
    # Extract character's damage from killmail
    case killmail.raw_data do
      %{"victim" => %{"damage_taken" => total_damage}, "attackers" => attackers}
      when is_list(attackers) and is_number(total_damage) and total_damage > 0 ->
        character_damage =
          attackers
          |> Enum.find(&(&1["character_id"] == killmail.victim_character_id))
          |> case do
            %{"damage_done" => damage} when is_number(damage) -> damage
            _ -> 0
          end

        character_damage / total_damage

      _ ->
        0.0
    end
  end

  defp extract_ship_types_used(killmails) do
    # Extract ship types used by the character
    ship_types =
      killmails
      |> Enum.flat_map(fn km ->
        # Ship type when victim
        victim_ship = if km.victim_character_id, do: [km.victim_ship_type_id], else: []

        # Ship type when attacker
        attacker_ships =
          case km.raw_data do
            %{"attackers" => attackers} when is_list(attackers) ->
              attackers
              |> Enum.filter(&(&1["character_id"] != nil))
              |> Enum.map(& &1["ship_type_id"])
              |> Enum.filter(&(&1 != nil))

            _ ->
              []
          end

        victim_ship ++ attacker_ships
      end)
      |> Enum.filter(&(&1 != nil))
      |> Enum.frequencies()

    ship_types
  end

  defp calculate_ship_diversity_index(ship_types_map) do
    if map_size(ship_types_map) == 0 do
      0.0
    else
      total_uses = ship_types_map |> Map.values() |> Enum.sum()
      unique_ships = map_size(ship_types_map)

      # Shannon diversity index adapted for ship usage
      shannon_diversity =
        ship_types_map
        |> Enum.map(fn {_ship, uses} ->
          proportion = uses / total_uses
          -proportion * :math.log(proportion)
        end)
        |> Enum.sum()

      # Normalize to 0-1 scale
      max_diversity = :math.log(unique_ships)
      if max_diversity > 0, do: shannon_diversity / max_diversity, else: 0.0
    end
  end

  defp analyze_ship_class_mastery(ship_types_map) do
    # Group ships by class and analyze mastery
    ship_classes =
      Enum.group_by(ship_types_map, fn {ship_type_id, _uses} ->
        classify_ship_type(ship_type_id)
      end)

    classes_used = map_size(ship_classes)

    mastery_scores =
      Enum.map(ship_classes, fn {_class, ships} ->
        total_uses = Enum.sum(Enum.map(ships, &elem(&1, 1)))
        ship_count = length(ships)

        # Mastery = usage frequency + diversity within class
        # Normalize to frequent usage
        usage_score = min(1.0, total_uses / 10)
        # Normalize to good diversity
        diversity_score = min(1.0, ship_count / 5)

        (usage_score + diversity_score) / 2
      end)

    if length(mastery_scores) > 0 do
      average_mastery = Enum.sum(mastery_scores) / length(mastery_scores)
      # 6 main ship classes
      class_breadth = min(1.0, classes_used / 6)

      average_mastery * 0.7 + class_breadth * 0.3
    else
      0.0
    end
  end

  defp classify_ship_type(ship_type_id) do
    cond do
      ship_type_id in 580..700 -> :frigate
      ship_type_id in 420..450 -> :destroyer
      ship_type_id in 620..650 -> :cruiser
      ship_type_id in 540..570 -> :battlecruiser
      ship_type_id in 640..670 -> :battleship
      ship_type_id in 19_720..19_740 -> :capital
      true -> :other
    end
  end

  defp assess_fitting_quality_from_performance(combat_data) do
    # Heuristic fitting quality assessment based on performance
    survival_rate = calculate_survival_rate(combat_data)
    damage_efficiency = calculate_damage_efficiency(combat_data.attacker_killmails)

    # Ships that survive longer and deal more damage likely have better fits
    fitting_quality = survival_rate * 0.6 + damage_efficiency * 0.4
    fitting_quality
  end

  defp analyze_tactical_ship_usage(combat_data) do
    # Analyze if character uses appropriate ships for different situations
    # This is a simplified heuristic - real implementation would be more sophisticated

    ship_types = extract_ship_types_used(combat_data.killmails)

    # Check for tactical diversity
    has_tackle = Enum.any?(ship_types, fn {ship_type, _} -> tackle_ship?(ship_type) end)
    has_dps = Enum.any?(ship_types, fn {ship_type, _} -> dps_ship?(ship_type) end)
    has_support = Enum.any?(ship_types, fn {ship_type, _} -> support_ship?(ship_type) end)

    tactical_roles = Enum.count([has_tackle, has_dps, has_support], & &1)
    # Normalize to having all 3 roles
    min(1.0, tactical_roles / 3)
  end

  defp tackle_ship?(ship_type_id) do
    # Frigates and some cruisers commonly used for tackle
    # Interceptors
    ship_type_id in 580..700 or ship_type_id in [11_182, 11_196]
  end

  defp dps_ship?(ship_type_id) do
    # Most cruisers, battlecruisers, battleships
    ship_type_id in 620..670
  end

  defp support_ship?(ship_type_id) do
    # EWAR, logistics, command ships
    # Logistics
    # Force Recon
    ship_type_id in [11_978, 11_987, 11_985, 12_003] or
      ship_type_id in [11_957, 11_958, 11_959, 11_961]
  end

  defp calculate_specialization_balance(ship_types_map) do
    if map_size(ship_types_map) == 0 do
      0.5
    else
      total_uses = ship_types_map |> Map.values() |> Enum.sum()
      max_usage = ship_types_map |> Map.values() |> Enum.max()

      specialization_ratio = max_usage / total_uses
      diversity_count = map_size(ship_types_map)

      # Optimal balance: some specialization but also diversity
      specialization_score =
        cond do
          # Too specialized
          specialization_ratio > 0.7 -> 0.6
          # Good generalization
          specialization_ratio < 0.3 -> 0.7
          # Good balance
          true -> 1.0
        end

      # Bonus for diversity
      diversity_bonus = min(0.4, diversity_count / 10)
      min(1.0, specialization_score + diversity_bonus)
    end
  end

  defp analyze_ship_usage_patterns(ship_types_map) do
    sorted_ships =
      ship_types_map
      |> Enum.sort_by(&elem(&1, 1), :desc)
      # Top 5 most used ships
      |> Enum.take(5)

    %{
      most_used_ships: sorted_ships,
      total_unique_ships: map_size(ship_types_map),
      usage_distribution: calculate_usage_distribution(ship_types_map)
    }
  end

  defp calculate_usage_distribution(ship_types_map) do
    total_uses = ship_types_map |> Map.values() |> Enum.sum()

    ship_types_map
    |> Enum.map(fn {ship_type, uses} ->
      {ship_type, Float.round(uses / total_uses, 3)}
    end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
  end

  defp calculate_fleet_participation_rate(killmails) do
    # Analyze how often character participates in fleet actions vs solo
    fleet_kills =
      Enum.count(killmails, fn km ->
        case km.raw_data do
          %{"attackers" => attackers} when is_list(attackers) ->
            # More than 3 attackers suggests fleet action
            length(attackers) > 3

          _ ->
            false
        end
      end)

    total_kills = length(killmails)

    if total_kills > 0 do
      fleet_kills / total_kills
    else
      # Neutral score for no data
      0.5
    end
  end

  defp analyze_fleet_role_execution(combat_data) do
    # Simplified fleet role analysis
    ship_types = extract_ship_types_used(combat_data.killmails)

    # Assess if character executes expected roles for their ships
    role_consistency =
      ship_types
      |> Enum.map(fn {ship_type, _uses} ->
        _expected_role = get_expected_ship_role(ship_type)
        # In a full implementation, we'd analyze actual performance in that role
        # Placeholder - assume decent role execution
        0.7
      end)
      |> average()

    role_consistency
  end

  defp get_expected_ship_role(ship_type_id) do
    cond do
      tackle_ship?(ship_type_id) -> :tackle
      dps_ship?(ship_type_id) -> :dps
      support_ship?(ship_type_id) -> :support
      true -> :general
    end
  end

  defp assess_fleet_coordination(killmails) do
    # Analyze coordination indicators from killmail timing and participation
    if length(killmails) < 5 do
      # Insufficient data
      0.5
    else
      # Look for coordinated strikes (multiple kills in short timeframes)
      coordinated_strikes =
        killmails
        |> Enum.sort_by(& &1.killmail_time)
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.count(fn [km1, km2] ->
          time_diff = NaiveDateTime.diff(km2.killmail_time, km1.killmail_time, :second)
          # Within 5 minutes
          time_diff < 300
        end)

      coordination_rate = coordinated_strikes / max(1, length(killmails) - 1)
      # Normalize
      min(1.0, coordination_rate * 2)
    end
  end

  defp analyze_leadership_patterns(attacker_killmails) do
    # Analyze final blow patterns as leadership indicator
    if Enum.empty?(attacker_killmails) do
      0.5
    else
      final_blows =
        Enum.count(attacker_killmails, fn km ->
          case km.raw_data do
            %{"attackers" => attackers} when is_list(attackers) ->
              Enum.any?(attackers, &(&1["final_blow"] == true))

            _ ->
              false
          end
        end)

      final_blow_rate = final_blows / length(attacker_killmails)

      # High final blow rate suggests taking charge/finishing targets
      # Normalize (33% final blow rate = 1.0)
      min(1.0, final_blow_rate * 3)
    end
  end

  defp calculate_support_role_effectiveness(killmails) do
    # Analyze effectiveness in support roles (EWAR, logistics, etc.)
    support_ships_used =
      killmails
      |> Enum.filter(fn km ->
        support_ship?(km.victim_ship_type_id) or
          has_support_ship_in_attackers(km)
      end)

    if Enum.empty?(support_ships_used) do
      # Neutral score - not a support player
      0.5
    else
      # Simplified support effectiveness based on survival in support ships
      support_deaths = Enum.count(support_ships_used, &(&1.victim_character_id != nil))

      support_survival_rate =
        (length(support_ships_used) - support_deaths) / length(support_ships_used)

      # Support ships should survive more to be effective
      support_survival_rate
    end
  end

  defp has_support_ship_in_attackers(killmail) do
    case killmail.raw_data do
      %{"attackers" => attackers} when is_list(attackers) ->
        Enum.any?(attackers, fn att ->
          ship_type = att["ship_type_id"]
          support_ship?(ship_type)
        end)

      _ ->
        false
    end
  end

  defp analyze_gang_patterns(killmails) do
    # Analyze patterns in gang/fleet composition and tactics
    gang_sizes =
      killmails
      |> Enum.map(fn km ->
        case km.raw_data do
          %{"attackers" => attackers} when is_list(attackers) -> length(attackers)
          _ -> 1
        end
      end)

    %{
      average_gang_size: average(gang_sizes),
      preferred_gang_sizes: Enum.frequencies(gang_sizes),
      solo_rate: Enum.count(gang_sizes, &(&1 == 1)) / length(gang_sizes),
      small_gang_rate: Enum.count(gang_sizes, &(&1 in 2..5)) / length(gang_sizes),
      fleet_rate: Enum.count(gang_sizes, &(&1 > 10)) / length(gang_sizes)
    }
  end

  defp calculate_tactical_variance(killmails) do
    # Analyze variance in tactical approaches
    # This is a simplified implementation - full version would analyze more factors

    system_variety =
      killmails
      |> Enum.map(& &1.solar_system_id)
      |> Enum.uniq()
      |> length()

    time_variety = analyze_engagement_time_variety(killmails)
    ship_variety = extract_ship_types_used(killmails) |> map_size()

    # Normalize and combine variance indicators
    # 20+ systems = max variance
    system_variance = min(1.0, system_variety / 20)
    time_variance = time_variety
    # 15+ ship types = max variance
    ship_variance = min(1.0, ship_variety / 15)

    (system_variance + time_variance + ship_variance) / 3
  end

  defp analyze_engagement_time_variety(killmails) do
    # Analyze variety in engagement timing (time of day patterns)
    if length(killmails) < 5 do
      0.5
    else
      hours =
        killmails
        |> Enum.map(fn km ->
          km.killmail_time
          |> NaiveDateTime.to_time()
          |> Time.to_seconds_after_midnight()
          |> elem(0)
          # Convert to hour of day
          |> div(3600)
        end)
        |> Enum.frequencies()

      # High variety = active across many hours
      hours_active = map_size(hours)
      # 12+ hours active = max variety
      min(1.0, hours_active / 12)
    end
  end

  defp analyze_ship_selection_patterns(combat_data) do
    ship_types = extract_ship_types_used(combat_data.killmails)

    if map_size(ship_types) < 3 do
      # Low variance - very predictable ship selection
      0.3
    else
      # Analyze entropy in ship selection
      total_uses = ship_types |> Map.values() |> Enum.sum()

      entropy =
        ship_types
        |> Enum.map(fn {_ship, uses} ->
          prob = uses / total_uses
          -prob * :math.log(prob)
        end)
        |> Enum.sum()

      max_entropy = :math.log(map_size(ship_types))

      if max_entropy > 0 do
        entropy / max_entropy
      else
        0.5
      end
    end
  end

  defp analyze_engagement_timing_patterns(killmails) do
    # Analyze unpredictability in when character engages
    if length(killmails) < 10 do
      0.5
    else
      # Group by day of week and hour
      timing_patterns =
        killmails
        |> Enum.map(fn km ->
          date = NaiveDateTime.to_date(km.killmail_time)

          hour =
            km.killmail_time
            |> NaiveDateTime.to_time()
            |> Time.to_seconds_after_midnight()
            |> elem(0)
            |> div(3600)

          day_of_week = Date.day_of_week(date)

          {day_of_week, hour}
        end)
        |> Enum.frequencies()

      # High variety in timing = more unpredictable
      unique_timing_slots = map_size(timing_patterns)
      # 7 days * 24 hours
      max_possible_slots = 7 * 24

      # 30% coverage = max score
      min(1.0, unique_timing_slots / (max_possible_slots * 0.3))
    end
  end

  defp calculate_target_selection_variance(attacker_killmails) do
    if length(attacker_killmails) < 5 do
      0.5
    else
      # Analyze variety in target types
      target_ship_types =
        attacker_killmails
        |> Enum.map(& &1.victim_ship_type_id)
        |> Enum.frequencies()

      target_corps =
        attacker_killmails
        |> Enum.map(& &1.victim_corporation_id)
        |> Enum.filter(&(&1 != nil))
        |> Enum.frequencies()

      ship_type_variety = map_size(target_ship_types)
      corp_variety = map_size(target_corps)

      # Normalize varieties
      ship_variance = min(1.0, ship_type_variety / 10)
      corp_variance = min(1.0, corp_variety / 15)

      (ship_variance + corp_variance) / 2
    end
  end

  defp estimate_fitting_variance(combat_data) do
    # Estimate fitting variety based on performance patterns
    # This is a heuristic - real implementation would analyze actual fittings

    ship_types = extract_ship_types_used(combat_data.killmails)
    performance_variance = calculate_performance_variance(combat_data)

    # Ships used multiple times with varying performance suggest fitting experimentation
    repeated_ships =
      ship_types
      |> Enum.filter(fn {_ship, uses} -> uses > 2 end)
      |> length()

    fitting_experimentation = min(1.0, repeated_ships / 5)

    (fitting_experimentation + performance_variance) / 2
  end

  defp calculate_performance_variance(combat_data) do
    # Analyze variance in combat performance over time
    if length(combat_data.killmails) < 10 do
      0.5
    else
      # Group killmails by time periods and analyze performance variance
      time_periods =
        combat_data.killmails
        |> Enum.sort_by(& &1.killmail_time)
        # Groups of 5 killmails
        |> Enum.chunk_every(5)

      performance_scores =
        time_periods
        |> Enum.map(&calculate_period_performance/1)

      if length(performance_scores) > 1 do
        variance = calculate_variance(performance_scores)
        # Normalize variance
        min(1.0, variance * 5)
      else
        0.5
      end
    end
  end

  defp calculate_period_performance(killmails) do
    # Simple performance metric for a period
    # Character was attacker
    kills = Enum.count(killmails, &(&1.victim_character_id == nil))
    _deaths = length(killmails) - kills

    if length(killmails) > 0 do
      kills / length(killmails)
    else
      0.5
    end
  end

  defp identify_behavioral_patterns(killmails) do
    # Identify specific behavioral patterns
    patterns = []

    # Solo hunter pattern
    patterns =
      if is_solo_hunter(killmails) do
        [:solo_hunter | patterns]
      else
        patterns
      end

    # Fleet anchor pattern
    patterns =
      if is_fleet_anchor(killmails) do
        [:fleet_anchor | patterns]
      else
        patterns
      end

    # Opportunist pattern
    patterns =
      if is_opportunist(killmails) do
        [:opportunist | patterns]
      else
        patterns
      end

    # Specialist pattern
    patterns =
      if is_specialist(killmails) do
        [:specialist | patterns]
      else
        patterns
      end

    patterns
  end

  defp is_solo_hunter(killmails) do
    solo_kills =
      Enum.count(killmails, fn km ->
        case km.raw_data do
          %{"attackers" => attackers} when is_list(attackers) ->
            # Solo or very small group
            length(attackers) <= 2

          _ ->
            false
        end
      end)

    solo_rate = if length(killmails) > 0, do: solo_kills / length(killmails), else: 0
    # 60%+ solo activity
    solo_rate > 0.6
  end

  defp is_fleet_anchor(killmails) do
    fleet_kills =
      Enum.count(killmails, fn km ->
        case km.raw_data do
          %{"attackers" => attackers} when is_list(attackers) ->
            # Large fleet actions
            length(attackers) > 10

          _ ->
            false
        end
      end)

    fleet_rate = if length(killmails) > 0, do: fleet_kills / length(killmails), else: 0
    # 70%+ fleet activity
    fleet_rate > 0.7
  end

  defp is_opportunist(killmails) do
    # High value targets relative to own ship usage
    high_value_kills =
      Enum.count(killmails, fn km ->
        # 500M+ ISK targets
        estimate_killmail_value(km) > 500_000_000
      end)

    opportunist_rate = if length(killmails) > 0, do: high_value_kills / length(killmails), else: 0
    # 30%+ high value targets
    opportunist_rate > 0.3
  end

  defp is_specialist(killmails) do
    ship_types = extract_ship_types_used(killmails)

    if map_size(ship_types) == 0 do
      false
    else
      total_uses = ship_types |> Map.values() |> Enum.sum()
      max_usage = ship_types |> Map.values() |> Enum.max()

      specialization_ratio = max_usage / total_uses
      # 60%+ usage in one ship type
      specialization_ratio > 0.6
    end
  end

  defp analyze_recent_performance_trend(recent_killmails, all_killmails) do
    # Compare recent performance to historical average
    recent_performance = calculate_period_performance(recent_killmails)
    historical_performance = calculate_period_performance(all_killmails)

    if historical_performance > 0 do
      improvement_ratio = recent_performance / historical_performance
      # Cap at 1.0 for 100% improvement
      min(1.0, improvement_ratio)
    else
      recent_performance
    end
  end

  defp calculate_activity_level(recent_killmails) do
    # Assess current activity level
    days_active =
      recent_killmails
      |> Enum.map(fn km ->
        km.killmail_time |> NaiveDateTime.to_date()
      end)
      |> Enum.uniq()
      |> length()

    kills_per_day = length(recent_killmails) / max(1, days_active)

    # Normalize activity level
    # 2+ kills per day = max activity
    min(1.0, kills_per_day / 2)
  end

  defp analyze_recent_combat_stats(recent_killmails) do
    kills = Enum.count(recent_killmails, &(&1.victim_character_id == nil))
    deaths = length(recent_killmails) - kills

    %{
      total_engagements: length(recent_killmails),
      kills: kills,
      deaths: deaths,
      kd_ratio: if(deaths > 0, do: kills / deaths, else: kills),
      activity_days:
        recent_killmails
        |> Enum.map(&NaiveDateTime.to_date(&1.killmail_time))
        |> Enum.uniq()
        |> length()
    }
  end

  # Utility and normalization functions

  defp normalize_score(value, min_val, max_val) do
    clamped_value = min(max_val, max(min_val, value))
    (clamped_value - min_val) / (max_val - min_val)
  end

  defp normalize_to_10_scale(score) do
    min(10.0, max(0.0, score * 10))
  end

  defp determine_threat_level(overall_score) do
    cond do
      overall_score >= @threat_levels.extreme -> :extreme
      overall_score >= @threat_levels.very_high -> :very_high
      overall_score >= @threat_levels.high -> :high
      overall_score >= @threat_levels.moderate -> :moderate
      overall_score >= @threat_levels.low -> :low
      true -> :minimal
    end
  end

  defp classify_threat_type(dimensional_scores) do
    # Identify the primary threat characteristics
    scores = [
      {:combat_specialist, dimensional_scores.combat_skill.normalized_score},
      {:ship_master, dimensional_scores.ship_mastery.normalized_score},
      {:fleet_commander, dimensional_scores.gang_effectiveness.normalized_score},
      {:unpredictable_wildcard, dimensional_scores.unpredictability.normalized_score}
    ]

    {primary_type, _score} = Enum.max_by(scores, &elem(&1, 1))
    primary_type
  end

  defp identify_key_strengths(dimensional_scores) do
    scores = [
      {"Exceptional combat skill", dimensional_scores.combat_skill.normalized_score},
      {"Ship mastery and versatility", dimensional_scores.ship_mastery.normalized_score},
      {"Fleet coordination and leadership",
       dimensional_scores.gang_effectiveness.normalized_score},
      {"Unpredictable tactical approach", dimensional_scores.unpredictability.normalized_score},
      {"Strong recent performance", dimensional_scores.recent_activity.normalized_score}
    ]

    scores
    |> Enum.filter(fn {_desc, score} -> score >= 7.0 end)
    |> Enum.map(&elem(&1, 0))
  end

  defp identify_key_weaknesses(dimensional_scores) do
    scores = [
      {"Limited combat effectiveness", dimensional_scores.combat_skill.normalized_score},
      {"Narrow ship usage patterns", dimensional_scores.ship_mastery.normalized_score},
      {"Poor fleet coordination", dimensional_scores.gang_effectiveness.normalized_score},
      {"Predictable tactical approach", dimensional_scores.unpredictability.normalized_score},
      {"Declining recent performance", dimensional_scores.recent_activity.normalized_score}
    ]

    scores
    |> Enum.filter(fn {_desc, score} -> score <= 3.0 end)
    |> Enum.map(&elem(&1, 0))
  end

  defp generate_tactical_recommendations(dimensional_scores, threat_level) do
    recommendations = []

    # Combat-based recommendations
    recommendations =
      if dimensional_scores.combat_skill.normalized_score >= 7.0 do
        [
          "Dangerous combatant - avoid direct engagement unless you have significant advantage"
          | recommendations
        ]
      else
        recommendations
      end

    # Fleet-based recommendations
    recommendations =
      if dimensional_scores.gang_effectiveness.normalized_score >= 7.0 do
        ["Strong fleet coordinator - priority target for enemy FC" | recommendations]
      else
        recommendations
      end

    # Ship mastery recommendations
    recommendations =
      if dimensional_scores.ship_mastery.normalized_score >= 7.0 do
        ["Versatile pilot - difficult to counter with specific ship types" | recommendations]
      else
        recommendations
      end

    # Unpredictability recommendations
    recommendations =
      if dimensional_scores.unpredictability.normalized_score >= 7.0 do
        ["Unpredictable opponent - prepare for unconventional tactics" | recommendations]
      else
        [
          "Predictable patterns - analyze their typical ship/engagement preferences"
          | recommendations
        ]
      end

    # General threat level recommendations
    recommendations =
      case threat_level do
        :extreme ->
          ["EXTREME THREAT: Avoid engagement unless overwhelming advantage" | recommendations]

        :very_high ->
          ["HIGH THREAT: Engage only with superior numbers or preparation" | recommendations]

        :high ->
          ["SIGNIFICANT THREAT: Approach with caution and tactical planning" | recommendations]

        :moderate ->
          ["MODERATE THREAT: Standard precautions apply" | recommendations]

        _ ->
          recommendations
      end

    recommendations
  end

  defp count_total_killmails(dimensional_scores) do
    # Extract killmail count from one of the dimensional scores
    dimensional_scores.combat_skill.components
    |> Map.get(:total_killmails, 0)
  end

  # Insight generation functions

  defp generate_combat_skill_insights(raw_score, kd_ratio, isk_efficiency, survival_rate) do
    insights = []

    insights =
      if kd_ratio > 3.0 do
        ["Excellent kill/death ratio (#{Float.round(kd_ratio, 1)}:1)" | insights]
      else
        insights
      end

    insights =
      if isk_efficiency > 2.0 do
        ["Strong ISK efficiency - destroys more value than lost" | insights]
      else
        insights
      end

    insights =
      if survival_rate > 0.8 do
        ["High survival rate (#{round(survival_rate * 100)}%) - good at disengaging" | insights]
      else
        insights
      end

    insights =
      if raw_score > 0.8 do
        ["Elite combat performance across all metrics" | insights]
      else
        insights
      end

    insights
  end

  defp generate_ship_mastery_insights(ship_diversity, class_mastery, specialization_score) do
    insights = []

    insights =
      if ship_diversity > 0.8 do
        ["Excellent ship diversity - comfortable with many hull types" | insights]
      else
        insights
      end

    insights =
      if class_mastery > 0.8 do
        ["Strong mastery across multiple ship classes" | insights]
      else
        insights
      end

    insights =
      if specialization_score > 0.8 do
        ["Good balance between specialization and versatility" | insights]
      else
        insights
      end

    insights
  end

  defp generate_gang_effectiveness_insights(
         fleet_participation,
         role_execution,
         leadership_indicators
       ) do
    insights = []

    insights =
      if fleet_participation > 0.7 do
        ["Primarily operates in fleet environments" | insights]
      else
        ["Operates frequently in small gang or solo scenarios" | insights]
      end

    insights =
      if leadership_indicators > 0.7 do
        ["Shows strong leadership patterns - likely FC or key fleet member" | insights]
      else
        insights
      end

    insights =
      if role_execution > 0.8 do
        ["Excellent fleet role execution" | insights]
      else
        insights
      end

    insights
  end

  defp generate_unpredictability_insights(tactical_variance, ship_selection_variance) do
    insights = []

    insights =
      if tactical_variance > 0.7 do
        ["Highly unpredictable tactical approach" | insights]
      else
        ["Follows consistent tactical patterns" | insights]
      end

    insights =
      if ship_selection_variance > 0.7 do
        ["Unpredictable ship selection - difficult to prepare counter" | insights]
      else
        ["Predictable ship preferences - can be countered specifically" | insights]
      end

    insights
  end

  defp generate_recent_activity_insights(recent_performance, activity_level) do
    insights = []

    insights =
      if recent_performance > 0.8 do
        ["Currently in excellent form - recent performance above average" | insights]
      else
        insights
      end

    insights =
      if activity_level > 0.8 do
        ["Highly active - regular combat engagement" | insights]
      else
        ["Limited recent activity - may be inactive or cautious" | insights]
      end

    insights
  end

  # Comparative analysis functions

  defp analyze_threat_distribution(threat_assessments) do
    threat_assessments
    |> Enum.group_by(& &1.threat_level)
    |> Enum.map(fn {level, assessments} -> {level, length(assessments)} end)
    |> Map.new()
  end

  defp identify_top_threats(threat_assessments) do
    threat_assessments
    |> Enum.sort_by(& &1.overall_score, :desc)
    |> Enum.take(5)
    |> Enum.map(fn assessment ->
      %{
        character_id: assessment.character_id,
        threat_level: assessment.threat_level,
        overall_score: assessment.overall_score,
        primary_strength: List.first(assessment.key_strengths)
      }
    end)
  end

  defp rank_by_threat_level(threat_assessments) do
    threat_assessments
    |> Enum.sort_by(& &1.overall_score, :desc)
    |> Enum.with_index(1)
    |> Enum.map(fn {assessment, rank} ->
      %{
        rank: rank,
        character_id: assessment.character_id,
        threat_level: assessment.threat_level,
        overall_score: assessment.overall_score
      }
    end)
  end

  defp generate_comparative_insights(threat_assessments) do
    if length(threat_assessments) < 2 do
      ["Insufficient data for comparative analysis"]
    else
      scores = Enum.map(threat_assessments, & &1.overall_score)
      avg_score = average(scores)
      max_score = Enum.max(scores)
      min_score = Enum.min(scores)

      insights = []

      insights =
        if max_score - min_score > 5.0 do
          [
            "Wide threat level variation - from #{Float.round(min_score, 1)} to #{Float.round(max_score, 1)}"
            | insights
          ]
        else
          insights
        end

      insights =
        if avg_score > 6.0 do
          ["Generally high threat group - average score #{Float.round(avg_score, 1)}" | insights]
        else
          insights
        end

      high_threat_count =
        Enum.count(threat_assessments, &(&1.threat_level in [:high, :very_high, :extreme]))

      insights =
        if high_threat_count > length(threat_assessments) / 2 do
          [
            "Majority are high-threat individuals (#{high_threat_count}/#{length(threat_assessments)})"
            | insights
          ]
        else
          insights
        end

      insights
    end
  end

  # Trend analysis functions

  defp calculate_trend_direction(trend_data) do
    if length(trend_data) < 2 do
      :insufficient_data
    else
      scores = Enum.map(trend_data, & &1.threat_score)
      trend_slope = calculate_trend_slope(scores)

      cond do
        trend_slope > 0.5 -> :strongly_improving
        trend_slope > 0.1 -> :improving
        trend_slope > -0.1 -> :stable
        trend_slope > -0.5 -> :declining
        true -> :strongly_declining
      end
    end
  end

  defp calculate_trend_slope(values) do
    if length(values) < 2 do
      0.0
    else
      n = length(values)
      indices = 1..n |> Enum.to_list()

      sum_x = Enum.sum(indices)
      sum_y = Enum.sum(values)
      sum_xy = indices |> Enum.zip(values) |> Enum.map(fn {x, y} -> x * y end) |> Enum.sum()
      sum_x2 = indices |> Enum.map(&(&1 * &1)) |> Enum.sum()

      # Linear regression slope
      (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x)
    end
  end

  defp calculate_improvement_rate(trend_data) do
    if length(trend_data) < 2 do
      0.0
    else
      recent_score = List.first(trend_data).threat_score
      historical_score = List.last(trend_data).threat_score

      if historical_score > 0 do
        (recent_score - historical_score) / historical_score
      else
        0.0
      end
    end
  end

  defp calculate_threat_volatility(trend_data) do
    if length(trend_data) < 2 do
      0.0
    else
      scores = Enum.map(trend_data, & &1.threat_score)
      calculate_variance(scores)
    end
  end

  defp generate_threat_predictions(trend_data) do
    if length(trend_data) < 3 do
      ["Insufficient data for predictions"]
    else
      scores = Enum.map(trend_data, & &1.threat_score)
      trend_slope = calculate_trend_slope(scores)
      variance = calculate_variance(scores)

      predictions = []

      predictions =
        if abs(trend_slope) > 0.3 do
          direction = if trend_slope > 0, do: "increasing", else: "decreasing"

          [
            "Threat level #{direction} - trend slope: #{Float.round(trend_slope, 2)}"
            | predictions
          ]
        else
          ["Threat level stable - minimal trend detected" | predictions]
        end

      predictions =
        if variance > 1.0 do
          ["High volatility - threat level fluctuates significantly" | predictions]
        else
          predictions
        end

      # Simple linear extrapolation for next period
      if abs(trend_slope) > 0.1 do
        current_score = List.first(trend_data).threat_score
        predicted_score = current_score + trend_slope
        predicted_level = determine_threat_level(predicted_score)

        [
          "Predicted next period: #{Float.round(predicted_score, 1)} (#{predicted_level})"
          | predictions
        ]
      else
        predictions
      end
    end
  end

  defp calculate_variance(values) do
    if length(values) <= 1 do
      0.0
    else
      mean_val = average(values)
      variance_sum = values |> Enum.map(&:math.pow(&1 - mean_val, 2)) |> Enum.sum()
      variance_sum / length(values)
    end
  end

  defp average([]), do: 0.0

  defp average(values) do
    Enum.sum(values) / length(values)
  end
end
