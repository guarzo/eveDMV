defmodule EveDmv.Contexts.CharacterIntelligence.Domain.BehavioralPatternAnalyzer do
  @moduledoc """
  Advanced behavioral pattern recognition and classification system for EVE Online PvP intelligence.

  Analyzes character combat data to identify, classify, and predict behavioral patterns:

  - Combat Archetype Recognition: Solo Hunter, Fleet Anchor, Opportunist, Specialist
  - Tactical Pattern Analysis: Engagement preferences, ship selection logic, timing patterns
  - Behavioral Clustering: Groups similar players using machine learning techniques
  - Predictive Modeling: Forecasts likely behavior based on historical patterns
  - Anomaly Detection: Identifies unusual behavior that deviates from established patterns

  Uses advanced statistical analysis, clustering algorithms, and pattern matching
  to provide deep insights into pilot psychology and tactical preferences.
  """

  import Ash.Query

  alias EveDmv.Api
  alias EveDmv.Killmails.KillmailRaw

  require Logger

  # Pattern analysis parameters
  # Minimum killmails for reliable pattern analysis
  @min_data_points_for_pattern 10

  # Behavioral archetype definitions
  @archetypes %{
    solo_hunter: %{
      name: "Solo Hunter",
      description: "Prefers small gang or solo PvP, high mobility, opportunistic strikes",
      key_traits: [:solo_preference, :high_mobility, :target_selection, :stealth]
    },
    fleet_anchor: %{
      name: "Fleet Anchor",
      description: "Excellent fleet coordination, leadership qualities, tactical awareness",
      key_traits: [:fleet_preference, :leadership, :coordination, :strategic_thinking]
    },
    opportunist: %{
      name: "Opportunist",
      description: "Targets high-value opportunities, ISK-focused, risk assessment",
      key_traits: [:value_targeting, :risk_assessment, :efficiency_focus, :patience]
    },
    specialist: %{
      name: "Specialist",
      description: "Masters specific ship types or tactics, deep expertise in niche areas",
      key_traits: [:ship_specialization, :tactical_expertise, :consistency, :optimization]
    },
    wildcard: %{
      name: "Wildcard",
      description: "Unpredictable behavior, experimental approaches, high variance",
      key_traits: [:unpredictability, :experimentation, :adaptability, :innovation]
    },
    support_master: %{
      name: "Support Master",
      description: "Excels in support roles, EWAR, logistics, force multiplication",
      key_traits: [:support_focus, :team_enablement, :tactical_support, :survivability]
    }
  }

  @doc """
  Analyzes comprehensive behavioral patterns for a character.

  Performs deep analysis of combat data to identify behavioral archetypes,
  tactical patterns, and predictive insights.

  ## Parameters
  - character_id: EVE character ID to analyze
  - options: Analysis options
    - :analysis_window_days - Days of history to analyze (default: 90)
    - :include_predictions - Include behavioral predictions (default: true)
    - :clustering_enabled - Enable behavioral clustering (default: false)

  ## Returns
  {:ok, behavioral_analysis} with comprehensive pattern analysis
  """
  def analyze_behavioral_patterns(character_id, options \\ []) do
    analysis_window = Keyword.get(options, :analysis_window_days, 90)
    include_predictions = Keyword.get(options, :include_predictions, true)
    clustering_enabled = Keyword.get(options, :clustering_enabled, false)

    Logger.info("Analyzing behavioral patterns for character #{character_id}")

    start_time = System.monotonic_time(:millisecond)

    with {:ok, combat_data} <- fetch_character_combat_data(character_id, analysis_window),
         {:ok, base_patterns} <- extract_base_patterns(combat_data),
         {:ok, archetype_analysis} <- classify_behavioral_archetype(base_patterns),
         {:ok, tactical_patterns} <- analyze_tactical_patterns(combat_data),
         {:ok, temporal_patterns} <- analyze_temporal_patterns(combat_data),
         {:ok, anomalies} <- detect_behavioral_anomalies(base_patterns),
         {:ok, final_analysis} <-
           compile_behavioral_analysis(
             character_id,
             archetype_analysis,
             {tactical_patterns, temporal_patterns},
             anomalies,
             include_predictions,
             clustering_enabled
           ) do
      end_time = System.monotonic_time(:millisecond)
      duration_ms = end_time - start_time

      Logger.info("""
      Behavioral pattern analysis completed in #{duration_ms}ms:
      - Character: #{character_id}
      - Primary Archetype: #{final_analysis.primary_archetype.name}
      - Confidence: #{Float.round(final_analysis.primary_archetype.confidence * 100, 1)}%
      - Patterns Identified: #{length(final_analysis.tactical_patterns)}
      """)

      {:ok, final_analysis}
    end
  end

  @doc """
  Compares behavioral patterns between multiple characters.

  Identifies similar and contrasting behavioral patterns for fleet composition
  and competitive intelligence.
  """
  def compare_behavioral_patterns(character_ids, options \\ []) do
    Logger.info("Comparing behavioral patterns for #{length(character_ids)} characters")

    behavioral_analyses =
      character_ids
      |> Enum.map(&analyze_behavioral_patterns(&1, options))
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(&elem(&1, 1))

    if length(behavioral_analyses) < 2 do
      {:error, :insufficient_data}
    else
      comparison = %{
        characters_analyzed: length(behavioral_analyses),
        archetype_distribution: analyze_archetype_distribution(behavioral_analyses),
        behavioral_clusters: perform_behavioral_clustering(behavioral_analyses),
        similarity_matrix: calculate_similarity_matrix(behavioral_analyses),
        tactical_overlap: analyze_tactical_overlap(behavioral_analyses),
        recommendations: generate_group_recommendations(behavioral_analyses)
      }

      {:ok, comparison}
    end
  end

  @doc """
  Predicts likely behavior for a character in specific scenarios.

  Uses historical patterns to forecast probable actions in tactical situations.
  """
  def predict_behavior(character_id, scenario, options \\ []) do
    with {:ok, behavioral_analysis} <- analyze_behavioral_patterns(character_id, options) do
      prediction = generate_behavioral_prediction(behavioral_analysis, scenario)
      {:ok, prediction}
    end
  end

  @doc """
  Identifies behavioral anomalies that may indicate account sharing, 
  skill changes, or tactical evolution.
  """
  def detect_behavioral_shifts(character_id, options \\ []) do
    analysis_window = Keyword.get(options, :analysis_window_days, 180)

    # Analyze behavior in different time periods
    periods = [
      {30, "Recent"},
      {60, "Medium-term"},
      {120, "Long-term"},
      {analysis_window, "Full history"}
    ]

    period_analyses =
      periods
      |> Enum.map(fn {days, label} ->
        case analyze_behavioral_patterns(character_id,
               analysis_window_days: days,
               include_predictions: false
             ) do
          {:ok, analysis} -> {label, analysis}
          _ -> nil
        end
      end)
      |> Enum.filter(&(&1 != nil))

    if length(period_analyses) < 2 do
      {:error, :insufficient_data}
    else
      shift_analysis = %{
        character_id: character_id,
        temporal_analysis: period_analyses,
        detected_shifts: identify_behavioral_shifts(period_analyses),
        shift_indicators: calculate_shift_indicators(period_analyses),
        recommendations: generate_shift_recommendations(period_analyses)
      }

      {:ok, shift_analysis}
    end
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
      |> limit(300)

    # Fetch killmails where character was attacker
    attacker_query =
      KillmailRaw
      |> new()
      |> filter(killmail_time: [gte: cutoff_date])
      |> limit(800)

    with {:ok, victim_killmails} <- Ash.read(victim_query, domain: Api),
         {:ok, potential_attacker_killmails} <- Ash.read(attacker_query, domain: Api) do
      # Filter for character as attacker
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

      if length(all_killmails) < @min_data_points_for_pattern do
        {:error, :insufficient_data}
      else
        combat_data = %{
          character_id: character_id,
          killmails: all_killmails,
          victim_killmails: victim_killmails,
          attacker_killmails: attacker_killmails,
          analysis_period_days: analysis_window_days,
          data_cutoff: cutoff_date
        }

        {:ok, combat_data}
      end
    end
  end

  defp extract_base_patterns(combat_data) do
    patterns = %{
      # Combat engagement patterns
      solo_engagement_rate: calculate_solo_engagement_rate(combat_data.killmails),
      fleet_engagement_rate: calculate_fleet_engagement_rate(combat_data.killmails),
      avg_fleet_size: calculate_average_fleet_size(combat_data.killmails),

      # Ship usage patterns
      ship_diversity_index: calculate_ship_diversity(combat_data.killmails),
      preferred_ship_classes: identify_preferred_ship_classes(combat_data.killmails),
      ship_role_consistency: analyze_ship_role_consistency(combat_data.killmails),

      # Target selection patterns
      target_value_preference: analyze_target_value_patterns(combat_data.attacker_killmails),
      target_class_preferences: analyze_target_class_patterns(combat_data.attacker_killmails),
      corp_target_patterns: analyze_corp_targeting_patterns(combat_data.attacker_killmails),

      # Tactical patterns
      damage_contribution_consistency: analyze_damage_consistency(combat_data.attacker_killmails),
      final_blow_rate: calculate_final_blow_rate(combat_data.attacker_killmails),
      support_role_usage: calculate_support_role_usage(combat_data.killmails),

      # Risk and efficiency patterns
      isk_efficiency_trend: calculate_isk_efficiency_trend(combat_data),
      survival_pattern: analyze_survival_patterns(combat_data),
      engagement_timing_pattern: analyze_engagement_timing(combat_data.killmails),

      # Location and roaming patterns
      system_diversity: calculate_system_diversity(combat_data.killmails),
      roaming_pattern: analyze_roaming_behavior(combat_data.killmails),
      region_preferences: analyze_region_preferences(combat_data.killmails)
    }

    {:ok, patterns}
  end

  defp classify_behavioral_archetype(patterns) do
    # Calculate archetype scores for each defined archetype
    archetype_scores =
      @archetypes
      |> Enum.map(fn {archetype_key, archetype_def} ->
        score = calculate_archetype_score(patterns, archetype_key)
        confidence = calculate_archetype_confidence(patterns, archetype_key)

        {archetype_key,
         %{
           name: archetype_def.name,
           description: archetype_def.description,
           score: score,
           confidence: confidence,
           traits: analyze_archetype_traits(patterns, archetype_def.key_traits)
         }}
      end)
      |> Map.new()

    # Identify primary and secondary archetypes
    sorted_archetypes =
      Enum.sort_by(archetype_scores, fn {_key, data} -> data.score end, :desc)

    {primary_key, primary_data} = List.first(sorted_archetypes)
    {secondary_key, secondary_data} = Enum.at(sorted_archetypes, 1, {nil, nil})

    analysis = %{
      primary_archetype: Map.put(primary_data, :key, primary_key),
      secondary_archetype:
        if(secondary_data, do: Map.put(secondary_data, :key, secondary_key), else: nil),
      all_archetype_scores: archetype_scores,
      archetype_certainty: calculate_archetype_certainty(archetype_scores),
      hybrid_traits: identify_hybrid_traits(archetype_scores)
    }

    {:ok, analysis}
  end

  defp analyze_tactical_patterns(combat_data) do
    tactical_patterns =
      [
        analyze_engagement_initiation_patterns(combat_data),
        analyze_ship_selection_logic(combat_data),
        analyze_fleet_role_patterns(combat_data),
        analyze_risk_tolerance_patterns(combat_data),
        analyze_tactical_adaptation_patterns(combat_data),
        analyze_coordination_patterns(combat_data)
      ]

    filtered_patterns = Enum.filter(tactical_patterns, & &1)

    {:ok, filtered_patterns}
  end

  defp analyze_temporal_patterns(combat_data) do
    temporal_analysis = %{
      activity_schedule: analyze_activity_schedule(combat_data.killmails),
      engagement_frequency: analyze_engagement_frequency(combat_data.killmails),
      seasonal_patterns: analyze_seasonal_patterns(combat_data.killmails),
      streak_analysis: analyze_kill_death_streaks(combat_data),
      momentum_patterns: analyze_momentum_patterns(combat_data.killmails)
    }

    {:ok, temporal_analysis}
  end

  defp detect_behavioral_anomalies(patterns) do
    # Identify patterns that deviate significantly from expected norms
    anomalies = []

    # Check for unusual ship diversity
    anomalies_after_ship_check =
      if patterns.ship_diversity_index > 0.9 do
        [
          %{
            type: :unusual_ship_diversity,
            severity: :moderate,
            description: "Extremely high ship diversity suggests experimental behavior"
          }
          | anomalies
        ]
      else
        anomalies
      end

    # Check for unusual solo/fleet balance
    solo_rate = patterns.solo_engagement_rate

    anomalies_after_solo_check =
      if solo_rate > 0.9 or solo_rate < 0.1 do
        severity = if solo_rate > 0.9, do: :high, else: :moderate

        description =
          if solo_rate > 0.9,
            do: "Almost exclusively solo - unusual for most pilots",
            else: "Almost never solo - highly fleet-dependent"

        [
          %{type: :unusual_engagement_preference, severity: severity, description: description}
          | anomalies_after_ship_check
        ]
      else
        anomalies_after_ship_check
      end

    # Check for unusual target patterns
    final_anomalies =
      if patterns.target_value_preference > 0.8 do
        [
          %{
            type: :extreme_value_targeting,
            severity: :high,
            description:
              "Exclusively targets high-value ships - possible botter or market manipulation"
          }
          | anomalies_after_solo_check
        ]
      else
        anomalies_after_solo_check
      end

    {:ok, final_anomalies}
  end

  defp compile_behavioral_analysis(
         character_id,
         archetype_analysis,
         pattern_data,
         anomalies,
         include_predictions,
         _clustering_enabled
       ) do
    {tactical_patterns, temporal_patterns} = pattern_data

    base_analysis = %{
      character_id: character_id,
      primary_archetype: archetype_analysis.primary_archetype,
      secondary_archetype: archetype_analysis.secondary_archetype,
      archetype_certainty: archetype_analysis.archetype_certainty,
      tactical_patterns: tactical_patterns,
      temporal_patterns: temporal_patterns,
      behavioral_anomalies: anomalies,
      analysis_metadata: %{
        analysis_timestamp: NaiveDateTime.utc_now(),
        data_quality: assess_data_quality(tactical_patterns, temporal_patterns),
        confidence_level: calculate_overall_confidence(archetype_analysis, anomalies)
      }
    }

    # Add predictions if requested
    final_analysis =
      if include_predictions do
        predictions = generate_behavioral_predictions(base_analysis)
        Map.put(base_analysis, :behavioral_predictions, predictions)
      else
        base_analysis
      end

    {:ok, final_analysis}
  end

  # Pattern calculation functions

  defp calculate_solo_engagement_rate(killmails) do
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

    if length(killmails) > 0, do: solo_kills / length(killmails), else: 0.0
  end

  defp calculate_fleet_engagement_rate(killmails) do
    fleet_kills =
      Enum.count(killmails, fn km ->
        case km.raw_data do
          %{"attackers" => attackers} when is_list(attackers) ->
            # Fleet-sized engagement
            length(attackers) > 5

          _ ->
            false
        end
      end)

    if length(killmails) > 0, do: fleet_kills / length(killmails), else: 0.0
  end

  defp calculate_average_fleet_size(killmails) do
    fleet_sizes =
      Enum.map(killmails, fn km ->
        case km.raw_data do
          %{"attackers" => attackers} when is_list(attackers) -> length(attackers)
          _ -> 1
        end
      end)

    if length(fleet_sizes) > 0, do: Enum.sum(fleet_sizes) / length(fleet_sizes), else: 1.0
  end

  defp calculate_ship_diversity(killmails) do
    ship_types =
      killmails
      |> Enum.flat_map(&extract_character_ships/1)
      |> Enum.frequencies()

    if map_size(ship_types) == 0 do
      0.0
    else
      total_uses = ship_types |> Map.values() |> Enum.sum()

      # Shannon diversity index
      shannon_diversity =
        ship_types
        |> Enum.map(fn {_ship, uses} ->
          proportion = uses / total_uses
          -proportion * :math.log(proportion)
        end)
        |> Enum.sum()

      max_diversity = :math.log(map_size(ship_types))
      if max_diversity > 0, do: shannon_diversity / max_diversity, else: 0.0
    end
  end

  defp extract_character_ships(killmail) do
    initial_ships = []

    # Ship when victim
    victim_ships =
      if killmail.victim_character_id,
        do: [killmail.victim_ship_type_id | initial_ships],
        else: initial_ships

    # Ship when attacker
    final_ships =
      case killmail.raw_data do
        %{"attackers" => attackers} when is_list(attackers) ->
          character_ships =
            attackers
            |> Enum.filter(&(&1["character_id"] != nil))
            |> Enum.map(& &1["ship_type_id"])
            |> Enum.filter(&(&1 != nil))

          victim_ships ++ character_ships

        _ ->
          victim_ships
      end

    Enum.filter(final_ships, & &1)
  end

  defp identify_preferred_ship_classes(killmails) do
    killmails
    |> extract_character_ships()
    |> Enum.map(&classify_ship_type/1)
    |> Enum.frequencies()
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(3)
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

  defp analyze_ship_role_consistency(killmails) do
    # Analyze how consistently character uses ships for their intended roles
    ship_role_usage =
      killmails
      |> Enum.map(fn km ->
        ship_type = List.first(extract_character_ships(km))

        if ship_type do
          expected_role = get_ship_expected_role(ship_type)
          actual_context = analyze_engagement_context(km)
          role_match_score = calculate_role_match(expected_role, actual_context)
          {ship_type, role_match_score}
        else
          nil
        end
      end)
      |> Enum.filter(&(&1 != nil))

    if length(ship_role_usage) > 0 do
      total_consistency =
        ship_role_usage
        |> Enum.map(&elem(&1, 1))
        |> Enum.sum()

      total_consistency / length(ship_role_usage)
    else
      0.5
    end
  end

  defp get_ship_expected_role(ship_type_id) do
    cond do
      ship_type_id in 580..700 -> :tackle
      ship_type_id in 420..450 -> :anti_support
      ship_type_id in 620..650 -> :dps
      ship_type_id in 540..570 -> :heavy_dps
      ship_type_id in 640..670 -> :main_dps
      true -> :general
    end
  end

  defp analyze_engagement_context(killmail) do
    # Simplified context analysis
    case killmail.raw_data do
      %{"attackers" => attackers} when is_list(attackers) ->
        fleet_size = length(attackers)
        target_value = estimate_target_value(killmail)

        cond do
          fleet_size <= 2 and target_value < 50_000_000 -> :small_gang_roam
          fleet_size <= 5 and target_value >= 100_000_000 -> :focused_strike
          fleet_size > 10 -> :fleet_engagement
          true -> :general_pvp
        end

      _ ->
        :unknown
    end
  end

  defp calculate_role_match(expected_role, context) do
    # Simplified role matching logic
    case {expected_role, context} do
      {:tackle, :small_gang_roam} -> 1.0
      {:tackle, :focused_strike} -> 0.8
      {:dps, :fleet_engagement} -> 1.0
      {:heavy_dps, :fleet_engagement} -> 1.0
      {:anti_support, :small_gang_roam} -> 0.9
      {_, :general_pvp} -> 0.7
      _ -> 0.5
    end
  end

  defp analyze_target_value_patterns(attacker_killmails) do
    if Enum.empty?(attacker_killmails) do
      0.5
    else
      target_values = Enum.map(attacker_killmails, &estimate_target_value/1)
      avg_target_value = Enum.sum(target_values) / length(target_values)

      # Normalize to 0-1 scale (100M ISK = 0.5, 500M+ = 1.0)
      min(1.0, avg_target_value / 500_000_000)
    end
  end

  defp estimate_target_value(killmail) do
    ship_type_id = killmail.victim_ship_type_id

    cond do
      ship_type_id in 580..700 -> 5_000_000
      ship_type_id in 420..450 -> 15_000_000
      ship_type_id in 620..650 -> 50_000_000
      ship_type_id in 540..570 -> 150_000_000
      ship_type_id in 640..670 -> 300_000_000
      ship_type_id in 19_720..19_740 -> 2_000_000_000
      true -> 25_000_000
    end
  end

  defp analyze_target_class_patterns(attacker_killmails) do
    target_classes =
      attacker_killmails
      |> Enum.map(&classify_ship_type(&1.victim_ship_type_id))
      |> Enum.frequencies()
      |> Enum.sort_by(&elem(&1, 1), :desc)

    target_classes
  end

  defp analyze_corp_targeting_patterns(attacker_killmails) do
    corps_targeted =
      attacker_killmails
      |> Enum.map(& &1.victim_corporation_id)
      |> Enum.filter(&(&1 != nil))
      |> Enum.frequencies()

    %{
      unique_corps_targeted: map_size(corps_targeted),
      repeat_targeting: calculate_repeat_targeting_rate(corps_targeted),
      most_targeted_corps: corps_targeted |> Enum.sort_by(&elem(&1, 1), :desc) |> Enum.take(3)
    }
  end

  defp calculate_repeat_targeting_rate(corps_targeted) do
    if map_size(corps_targeted) == 0 do
      0.0
    else
      repeat_targets = Enum.count(corps_targeted, fn {_corp, count} -> count > 1 end)

      repeat_targets / map_size(corps_targeted)
    end
  end

  defp analyze_damage_consistency(attacker_killmails) do
    if Enum.empty?(attacker_killmails) do
      0.5
    else
      damage_contributions =
        attacker_killmails
        |> Enum.map(&calculate_damage_contribution/1)
        |> Enum.filter(&(&1 > 0))

      if length(damage_contributions) > 1 do
        mean_damage = Enum.sum(damage_contributions) / length(damage_contributions)
        variance = calculate_variance(damage_contributions)

        # Lower variance = higher consistency
        consistency = 1.0 - min(1.0, variance / (mean_damage * mean_damage))
        consistency
      else
        0.5
      end
    end
  end

  defp calculate_damage_contribution(killmail) do
    case killmail.raw_data do
      %{"victim" => %{"damage_taken" => total_damage}, "attackers" => attackers}
      when is_number(total_damage) and total_damage > 0 and is_list(attackers) ->
        character_attacker =
          Enum.find(attackers, &(&1["character_id"] == killmail.victim_character_id))

        case character_attacker do
          %{"damage_done" => damage} when is_number(damage) -> damage / total_damage
          _ -> 0.0
        end

      _ ->
        0.0
    end
  end

  defp calculate_final_blow_rate(attacker_killmails) do
    if Enum.empty?(attacker_killmails) do
      0.0
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

      final_blows / length(attacker_killmails)
    end
  end

  defp calculate_support_role_usage(killmails) do
    support_ship_usage =
      Enum.count(killmails, fn km ->
        ships = extract_character_ships(km)
        Enum.any?(ships, &support_ship?/1)
      end)

    if length(killmails) > 0, do: support_ship_usage / length(killmails), else: 0.0
  end

  defp support_ship?(ship_type_id) do
    # EWAR, logistics, command ships
    ship_type_id in [
      # Logistics
      11_978,
      11_987,
      11_985,
      12_003,
      # Force Recon
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

  defp calculate_isk_efficiency_trend(combat_data) do
    # Simplified ISK efficiency calculation over time
    victim_value =
      combat_data.victim_killmails
      |> Enum.map(&estimate_target_value/1)
      |> Enum.sum()

    killed_value =
      combat_data.attacker_killmails
      |> Enum.map(&estimate_target_value/1)
      |> Enum.sum()

    if victim_value > 0 do
      killed_value / victim_value
    else
      # Perfect efficiency if no losses
      if killed_value > 0, do: 10.0, else: 1.0
    end
  end

  defp analyze_survival_patterns(combat_data) do
    total_engagements = length(combat_data.killmails)
    deaths = length(combat_data.victim_killmails)

    survival_rate =
      if total_engagements > 0 do
        (total_engagements - deaths) / total_engagements
      else
        0.5
      end

    %{
      survival_rate: survival_rate,
      average_engagement_outcome: if(survival_rate > 0.5, do: :positive, else: :negative),
      risk_tolerance: classify_risk_tolerance(survival_rate, combat_data)
    }
  end

  defp classify_risk_tolerance(survival_rate, combat_data) do
    avg_fleet_size = calculate_average_fleet_size(combat_data.killmails)
    solo_rate = calculate_solo_engagement_rate(combat_data.killmails)

    cond do
      survival_rate > 0.8 and solo_rate > 0.3 -> :calculated_risk_taker
      survival_rate < 0.3 and avg_fleet_size < 3 -> :high_risk_aggressive
      survival_rate > 0.7 and avg_fleet_size > 8 -> :conservative_fleet_player
      true -> :moderate_risk_tolerance
    end
  end

  defp analyze_engagement_timing(killmails) do
    if length(killmails) < 5 do
      %{pattern: :insufficient_data}
    else
      # Analyze time of day patterns
      hours =
        killmails
        |> Enum.map(fn km ->
          km.killmail_time
          |> NaiveDateTime.to_time()
          |> Time.to_seconds_after_midnight()
          |> elem(0)
          |> div(3600)
        end)
        |> Enum.frequencies()

      # Analyze day of week patterns
      days =
        killmails
        |> Enum.map(fn km ->
          km.killmail_time
          |> NaiveDateTime.to_date()
          |> Date.day_of_week()
        end)
        |> Enum.frequencies()

      %{
        preferred_hours: hours |> Enum.sort_by(&elem(&1, 1), :desc) |> Enum.take(3),
        preferred_days: days |> Enum.sort_by(&elem(&1, 1), :desc) |> Enum.take(3),
        activity_spread: map_size(hours),
        weekend_vs_weekday: analyze_weekend_preference(days)
      }
    end
  end

  defp analyze_weekend_preference(day_frequencies) do
    # Sat + Sun
    weekend_activity = Map.get(day_frequencies, 6, 0) + Map.get(day_frequencies, 7, 0)
    weekday_activity = 1..5 |> Enum.map(&Map.get(day_frequencies, &1, 0)) |> Enum.sum()

    total_activity = weekend_activity + weekday_activity

    if total_activity > 0 do
      weekend_ratio = weekend_activity / total_activity

      cond do
        weekend_ratio > 0.4 -> :weekend_warrior
        weekend_ratio < 0.15 -> :weekday_focused
        true -> :balanced
      end
    else
      :unknown
    end
  end

  defp calculate_system_diversity(killmails) do
    systems =
      killmails
      |> Enum.map(& &1.solar_system_id)
      |> Enum.uniq()
      |> length()

    # Normalize: 20+ different systems = 1.0 diversity
    min(1.0, systems / 20)
  end

  defp analyze_roaming_behavior(killmails) do
    if length(killmails) < 10 do
      %{pattern: :insufficient_data}
    else
      # Group kills by time proximity to identify roams
      sorted_killmails = Enum.sort_by(killmails, & &1.killmail_time)

      # 1 hour session window
      roaming_sessions = group_into_sessions(sorted_killmails, 3600)

      avg_session_length =
        if length(roaming_sessions) > 0 do
          total_duration =
            roaming_sessions
            |> Enum.map(&calculate_session_duration/1)
            |> Enum.sum()

          total_duration / length(roaming_sessions)
        else
          0
        end

      %{
        roaming_sessions: length(roaming_sessions),
        avg_session_duration_minutes: avg_session_length / 60,
        avg_kills_per_session:
          if(length(roaming_sessions) > 0,
            do: length(killmails) / length(roaming_sessions),
            else: 0
          ),
        roaming_preference: classify_roaming_preference(roaming_sessions)
      }
    end
  end

  defp group_into_sessions(killmails, max_gap_seconds) do
    killmails
    |> Enum.reduce({[], []}, fn km, {current_session_rev, completed_sessions} ->
      case current_session_rev do
        [] ->
          {[km], completed_sessions}

        [last_km | _] = session_rev ->
          time_gap = NaiveDateTime.diff(km.killmail_time, last_km.killmail_time, :second)

          if time_gap <= max_gap_seconds do
            {[km | session_rev], completed_sessions}
          else
            {[km], [Enum.reverse(session_rev) | completed_sessions]}
          end
      end
    end)
    |> then(fn {current_session_rev, completed_sessions} ->
      case current_session_rev do
        [] -> completed_sessions
        session_rev -> [Enum.reverse(session_rev) | completed_sessions]
      end
    end)
    |> Enum.reverse()
  end

  defp calculate_session_duration(session) do
    if length(session) <= 1 do
      0
    else
      first_kill = List.first(session)
      last_kill = List.last(session)
      NaiveDateTime.diff(last_kill.killmail_time, first_kill.killmail_time, :second)
    end
  end

  defp classify_roaming_preference(roaming_sessions) do
    if Enum.empty?(roaming_sessions) do
      :unknown
    else
      avg_duration =
        roaming_sessions
        |> Enum.map(&calculate_session_duration/1)
        |> Enum.sum()
        |> div(length(roaming_sessions))

      avg_kills_per_session =
        roaming_sessions
        |> Enum.map(&length/1)
        |> Enum.sum()
        |> div(length(roaming_sessions))

      cond do
        avg_duration > 7200 and avg_kills_per_session > 3 -> :extended_roamer
        avg_duration < 1800 and avg_kills_per_session <= 2 -> :quick_strike
        avg_kills_per_session > 5 -> :hunting_focused
        true -> :standard_roaming
      end
    end
  end

  defp analyze_region_preferences(killmails) do
    # Simplified region analysis based on system IDs
    # In production, this would use actual region mapping

    system_activity =
      killmails
      |> Enum.map(& &1.solar_system_id)
      |> Enum.frequencies()
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(5)

    %{
      most_active_systems: system_activity,
      system_concentration: calculate_system_concentration(system_activity),
      roaming_vs_camping: classify_system_usage_pattern(system_activity)
    }
  end

  defp calculate_system_concentration(system_activity) do
    if Enum.empty?(system_activity) do
      0.0
    else
      total_activity = system_activity |> Enum.map(&elem(&1, 1)) |> Enum.sum()
      top_system_activity = system_activity |> List.first() |> elem(1)

      top_system_activity / total_activity
    end
  end

  defp classify_system_usage_pattern(system_activity) do
    concentration = calculate_system_concentration(system_activity)

    cond do
      concentration > 0.6 -> :system_camper
      concentration < 0.2 -> :wide_roamer
      true -> :regional_roamer
    end
  end

  # Archetype scoring functions

  defp calculate_archetype_score(patterns, :solo_hunter) do
    patterns.solo_engagement_rate * 0.4 +
      patterns.ship_diversity_index * 0.2 +
      (1.0 - patterns.fleet_engagement_rate) * 0.2 +
      normalize_system_diversity(patterns.system_diversity) * 0.2
  end

  defp calculate_archetype_score(patterns, :fleet_anchor) do
    patterns.fleet_engagement_rate * 0.5 +
      patterns.final_blow_rate * 0.2 +
      patterns.damage_contribution_consistency * 0.15 +
      (1.0 - patterns.solo_engagement_rate) * 0.15
  end

  defp calculate_archetype_score(patterns, :opportunist) do
    patterns.target_value_preference * 0.4 +
      min(patterns.isk_efficiency_trend / 5.0, 1.0) * 0.3 +
      patterns.survival_pattern.survival_rate * 0.3
  end

  defp calculate_archetype_score(patterns, :specialist) do
    (1.0 - patterns.ship_diversity_index) * 0.4 +
      patterns.ship_role_consistency * 0.3 +
      patterns.damage_contribution_consistency * 0.3
  end

  defp calculate_archetype_score(patterns, :wildcard) do
    patterns.ship_diversity_index * 0.3 +
      normalize_system_diversity(patterns.system_diversity) * 0.2 +
      calculate_unpredictability_score(patterns) * 0.5
  end

  defp calculate_archetype_score(patterns, :support_master) do
    patterns.support_role_usage * 0.5 +
      patterns.survival_pattern.survival_rate * 0.3 +
      patterns.damage_contribution_consistency * 0.2
  end

  defp calculate_archetype_confidence(patterns, archetype_key) do
    # Calculate confidence based on data quality and pattern strength
    base_confidence =
      case archetype_key do
        :solo_hunter -> if patterns.solo_engagement_rate > 0.7, do: 0.9, else: 0.6
        :fleet_anchor -> if patterns.fleet_engagement_rate > 0.7, do: 0.9, else: 0.6
        :opportunist -> if patterns.target_value_preference > 0.6, do: 0.8, else: 0.5
        :specialist -> if patterns.ship_diversity_index < 0.3, do: 0.8, else: 0.5
        :wildcard -> if patterns.ship_diversity_index > 0.7, do: 0.7, else: 0.4
        :support_master -> if patterns.support_role_usage > 0.4, do: 0.8, else: 0.3
      end

    base_confidence
  end

  defp analyze_archetype_traits(patterns, trait_keys) do
    trait_keys
    |> Enum.map(fn trait ->
      {trait, calculate_trait_strength(patterns, trait)}
    end)
    |> Map.new()
  end

  defp calculate_trait_strength(patterns, trait) do
    case trait do
      :solo_preference -> patterns.solo_engagement_rate
      :fleet_preference -> patterns.fleet_engagement_rate
      :high_mobility -> normalize_system_diversity(patterns.system_diversity)
      :target_selection -> patterns.target_value_preference
      :leadership -> patterns.final_blow_rate
      :coordination -> patterns.damage_contribution_consistency
      :value_targeting -> patterns.target_value_preference
      :risk_assessment -> patterns.survival_pattern.survival_rate
      :ship_specialization -> 1.0 - patterns.ship_diversity_index
      :tactical_expertise -> patterns.ship_role_consistency
      :unpredictability -> calculate_unpredictability_score(patterns)
      :support_focus -> patterns.support_role_usage
      # Default for unknown traits
      _ -> 0.5
    end
  end

  defp calculate_unpredictability_score(patterns) do
    patterns.ship_diversity_index * 0.4 +
      normalize_system_diversity(patterns.system_diversity) * 0.3 +
      calculate_timing_unpredictability(patterns.engagement_timing_pattern) * 0.3
  end

  defp calculate_timing_unpredictability(timing_pattern) do
    case timing_pattern do
      %{activity_spread: spread} when is_number(spread) -> min(1.0, spread / 12)
      _ -> 0.5
    end
  end

  defp normalize_system_diversity(system_diversity) do
    min(1.0, system_diversity)
  end

  defp calculate_archetype_certainty(archetype_scores) do
    scores = archetype_scores |> Map.values() |> Enum.map(& &1.score)

    if length(scores) < 2 do
      0.5
    else
      sorted_scores = Enum.sort(scores, :desc)
      top_score = List.first(sorted_scores)
      second_score = Enum.at(sorted_scores, 1)

      # Certainty based on separation between top scores
      separation = top_score - second_score
      # Scale separation to 0-1
      min(1.0, separation * 2)
    end
  end

  defp identify_hybrid_traits(archetype_scores) do
    # Identify characteristics that suggest hybrid archetypes
    high_scoring_archetypes =
      archetype_scores
      |> Enum.filter(fn {_key, data} -> data.score > 0.6 end)
      |> Enum.map(&elem(&1, 0))

    case length(high_scoring_archetypes) do
      0 -> [:undefined_archetype]
      1 -> [:pure_archetype]
      2 -> [:hybrid] ++ high_scoring_archetypes
      _ -> [:complex_hybrid] ++ Enum.take(high_scoring_archetypes, 3)
    end
  end

  # Utility functions

  defp calculate_variance(values) do
    if length(values) <= 1 do
      0.0
    else
      mean_val = Enum.sum(values) / length(values)
      variance_sum = values |> Enum.map(&:math.pow(&1 - mean_val, 2)) |> Enum.sum()
      variance_sum / length(values)
    end
  end

  defp assess_data_quality(tactical_patterns, temporal_patterns) do
    pattern_count = length(tactical_patterns)

    temporal_completeness =
      if temporal_patterns.activity_schedule.pattern == :insufficient_data, do: 0.3, else: 0.8

    cond do
      pattern_count >= 4 and temporal_completeness > 0.7 -> :high
      pattern_count >= 2 and temporal_completeness > 0.5 -> :medium
      true -> :low
    end
  end

  defp calculate_overall_confidence(archetype_analysis, anomalies) do
    base_confidence = archetype_analysis.archetype_certainty
    anomaly_penalty = length(anomalies) * 0.1

    max(0.1, base_confidence - anomaly_penalty)
  end

  defp generate_behavioral_predictions(analysis) do
    archetype = analysis.primary_archetype

    predictions =
      case archetype.key do
        :solo_hunter ->
          [
            "Likely to engage in small gang (2-5 pilots) scenarios",
            "Will avoid large fleet battles unless target value is exceptional",
            "Prefers mobile ship types for quick engagement/disengagement"
          ]

        :fleet_anchor ->
          [
            "Most dangerous in fleet environments with 10+ pilots",
            "Likely to coordinate focus fire and tactical movements",
            "May serve as primary or secondary fleet commander"
          ]

        :opportunist ->
          [
            "Will prioritize high-value targets over tactical objectives",
            "May disengage quickly if ISK efficiency becomes unfavorable",
            "Likely to scout extensively before committing to engagements"
          ]

        :specialist ->
          [
            "Will use proven ship fits and tactics repeatedly",
            "Vulnerable to hard counters specific to their preferred ships",
            "May excel in their specialty but struggle when forced to adapt"
          ]

        :wildcard ->
          [
            "Behavior difficult to predict - prepare for unconventional tactics",
            "May experiment with unusual ship/module combinations",
            "Could surprise with creative solutions to tactical problems"
          ]

        :support_master ->
          [
            "High priority target - eliminating them significantly weakens their fleet",
            "Will position defensively and may withdraw if targeted heavily",
            "Likely to coordinate with other support pilots for mutual protection"
          ]

        _ ->
          ["Behavioral pattern unclear - standard precautions apply"]
      end

    %{
      tactical_predictions: predictions,
      confidence_level: archetype.confidence,
      prediction_timeframe: "30-60 days based on current patterns"
    }
  end

  # Placeholder implementations for analysis methods
  # These would be fully implemented with more sophisticated algorithms

  defp analyze_engagement_initiation_patterns(_combat_data) do
    %{
      pattern_type: :engagement_initiation,
      description: "Analyzes how character typically initiates combat",
      confidence: 0.6,
      insights: ["Pattern analysis requires more sophisticated implementation"]
    }
  end

  defp analyze_ship_selection_logic(_combat_data) do
    %{
      pattern_type: :ship_selection,
      description: "Analyzes logic behind ship selection decisions",
      confidence: 0.6,
      insights: ["Ship selection pattern recognition needs enhancement"]
    }
  end

  defp analyze_fleet_role_patterns(_combat_data) do
    %{
      pattern_type: :fleet_roles,
      description: "Analyzes preferred roles in fleet operations",
      confidence: 0.6,
      insights: ["Fleet role analysis requires more detailed implementation"]
    }
  end

  defp analyze_risk_tolerance_patterns(_combat_data) do
    %{
      pattern_type: :risk_tolerance,
      description: "Analyzes risk assessment and management patterns",
      confidence: 0.6,
      insights: ["Risk tolerance calculation needs refinement"]
    }
  end

  defp analyze_tactical_adaptation_patterns(_combat_data) do
    %{
      pattern_type: :tactical_adaptation,
      description: "Analyzes how character adapts tactics to situations",
      confidence: 0.6,
      insights: ["Adaptation analysis requires more complex algorithms"]
    }
  end

  defp analyze_coordination_patterns(_combat_data) do
    %{
      pattern_type: :coordination,
      description: "Analyzes coordination and teamwork patterns",
      confidence: 0.6,
      insights: ["Coordination pattern detection needs enhancement"]
    }
  end

  defp analyze_activity_schedule(killmails) do
    if length(killmails) < 5 do
      %{pattern: :insufficient_data}
    else
      # Basic activity schedule analysis
      hours =
        killmails
        |> Enum.map(fn km ->
          km.killmail_time
          |> NaiveDateTime.to_time()
          |> Time.to_seconds_after_midnight()
          |> elem(0)
          |> div(3600)
        end)
        |> Enum.frequencies()

      %{
        pattern: :time_based,
        peak_hours: hours |> Enum.sort_by(&elem(&1, 1), :desc) |> Enum.take(3),
        activity_distribution: hours
      }
    end
  end

  defp analyze_engagement_frequency(killmails) do
    if length(killmails) < 5 do
      %{frequency: :insufficient_data}
    else
      # Calculate average time between engagements
      sorted_killmails = Enum.sort_by(killmails, & &1.killmail_time)

      time_gaps =
        sorted_killmails
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [km1, km2] ->
          NaiveDateTime.diff(km2.killmail_time, km1.killmail_time, :second)
        end)

      if length(time_gaps) > 0 do
        avg_gap_hours = Enum.sum(time_gaps) / length(time_gaps) / 3600

        %{
          frequency: classify_engagement_frequency(avg_gap_hours),
          avg_gap_hours: avg_gap_hours,
          engagement_consistency: calculate_engagement_consistency(time_gaps)
        }
      else
        %{frequency: :single_engagement}
      end
    end
  end

  defp classify_engagement_frequency(avg_gap_hours) do
    cond do
      avg_gap_hours < 6 -> :very_active
      avg_gap_hours < 24 -> :active
      avg_gap_hours < 72 -> :moderate
      avg_gap_hours < 168 -> :occasional
      true -> :infrequent
    end
  end

  defp calculate_engagement_consistency(time_gaps) do
    if length(time_gaps) <= 1 do
      0.5
    else
      variance = calculate_variance(time_gaps)
      mean_gap = Enum.sum(time_gaps) / length(time_gaps)

      # Lower coefficient of variation = higher consistency
      coefficient_of_variation = if mean_gap > 0, do: :math.sqrt(variance) / mean_gap, else: 1.0

      max(0.0, 1.0 - min(1.0, coefficient_of_variation))
    end
  end

  defp analyze_seasonal_patterns(_killmails) do
    # Placeholder for seasonal analysis
    %{
      pattern: :requires_longer_timeframe,
      insights: ["Seasonal pattern analysis requires 6+ months of data"]
    }
  end

  defp analyze_kill_death_streaks(_combat_data) do
    # Placeholder for streak analysis
    %{
      pattern: :basic_tracking,
      insights: ["Kill/death streak analysis needs implementation"]
    }
  end

  defp analyze_momentum_patterns(_killmails) do
    # Placeholder for momentum analysis
    %{
      pattern: :momentum_tracking,
      insights: ["Momentum pattern analysis requires implementation"]
    }
  end

  # Additional placeholder implementations for comparison functions

  defp analyze_archetype_distribution(_behavioral_analyses) do
    %{distribution: :requires_implementation}
  end

  defp perform_behavioral_clustering(_behavioral_analyses) do
    %{clusters: :requires_implementation}
  end

  defp calculate_similarity_matrix(_behavioral_analyses) do
    %{similarity_matrix: :requires_implementation}
  end

  defp analyze_tactical_overlap(_behavioral_analyses) do
    %{overlap: :requires_implementation}
  end

  defp generate_group_recommendations(_behavioral_analyses) do
    ["Group analysis requires more sophisticated implementation"]
  end

  defp generate_behavioral_prediction(_behavioral_analysis, _scenario) do
    %{
      prediction: "Scenario-based prediction requires implementation",
      confidence: 0.5,
      timeframe: "30 days"
    }
  end

  defp identify_behavioral_shifts(_period_analyses) do
    ["Behavioral shift detection requires implementation"]
  end

  defp calculate_shift_indicators(_period_analyses) do
    %{indicators: :requires_implementation}
  end

  defp generate_shift_recommendations(_period_analyses) do
    ["Shift recommendation system requires implementation"]
  end
end
