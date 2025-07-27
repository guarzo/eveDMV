defmodule EveDmv.Analytics.CharacterComparisonService do
  @moduledoc """
  Service for comparing characters across multiple dimensions including combat effectiveness,
  activity patterns, ship preferences, and threat assessment.

  Provides comprehensive comparison analytics for:
  - Combat statistics and efficiency
  - Activity patterns and engagement types
  - Ship and fitting preferences
  - Threat levels and danger assessment
  - Alliance/corporation relationships
  - Geographic activity patterns
  """

  alias EveDmv.Api
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Eve.NameResolver

  require Ash.Query

  @doc """
  Compare multiple characters with comprehensive analysis.
  """
  def compare_characters(character_ids, timeframe \\ :last_30_days) when is_list(character_ids) do
    if length(character_ids) < 2 or length(character_ids) > 10 do
      {:error, "Can compare between 2 and 10 characters"}
    else
      {start_time, end_time} = get_timeframe_bounds(timeframe)

      # Get comprehensive data for each character
      character_analyses =
        character_ids
        |> Enum.map(fn char_id ->
          analyze_character_comprehensive(char_id, start_time, end_time)
        end)
        |> Enum.reject(&is_nil/1)

      if length(character_analyses) < 2 do
        {:error, "Need at least 2 valid characters with data"}
      else
        comparison_result = %{
          timeframe: timeframe,
          period_start: start_time,
          period_end: end_time,
          characters_analyzed: length(character_analyses),
          character_data: character_analyses,

          # Comparative analysis
          combat_comparison: compare_combat_effectiveness(character_analyses),
          activity_comparison: compare_activity_patterns(character_analyses),
          ship_comparison: compare_ship_preferences(character_analyses),
          threat_comparison: compare_threat_levels(character_analyses),
          geographic_comparison: compare_geographic_patterns(character_analyses),
          relationship_analysis: analyze_character_relationships(character_analyses),

          # Rankings and insights
          rankings: generate_character_rankings(character_analyses),
          insights: generate_comparison_insights(character_analyses),
          recommendations: generate_tactical_recommendations(character_analyses)
        }

        {:ok, comparison_result}
      end
    end
  end

  @doc """
  Compare two characters head-to-head with detailed breakdown.
  """
  def head_to_head_comparison(char_id_1, char_id_2, timeframe \\ :last_30_days) do
    case compare_characters([char_id_1, char_id_2], timeframe) do
      {:ok, comparison} ->
        [char1_data, char2_data] = comparison.character_data

        head_to_head = %{
          character_1: char1_data,
          character_2: char2_data,
          timeframe: timeframe,

          # Direct comparisons
          combat_advantage: determine_combat_advantage(char1_data, char2_data),
          activity_comparison: compare_activity_head_to_head(char1_data, char2_data),
          ship_matchup: analyze_ship_matchup(char1_data, char2_data),
          experience_comparison: compare_experience_levels(char1_data, char2_data),
          threat_assessment: assess_mutual_threat(char1_data, char2_data),

          # Encounter prediction
          likely_outcome: predict_encounter_outcome(char1_data, char2_data),
          tactical_advice: generate_tactical_advice(char1_data, char2_data),

          # Historical data
          previous_encounters: find_previous_encounters(char_id_1, char_id_2),
          common_systems: find_common_activity_systems(char1_data, char2_data)
        }

        {:ok, head_to_head}

      error ->
        error
    end
  end

  @doc """
  Generate character similarity analysis to find similar pilots.
  """
  def find_similar_characters(character_id, timeframe \\ :last_30_days, limit \\ 10) do
    {start_time, end_time} = get_timeframe_bounds(timeframe)

    # Get base character analysis
    base_analysis = analyze_character_comprehensive(character_id, start_time, end_time)

    if is_nil(base_analysis) do
      {:error, "Character not found or no data available"}
    else
      # Get candidates from recent activity
      candidate_chars =
        get_candidate_characters_for_similarity(base_analysis, start_time, limit * 3)

      # Analyze each candidate
      candidate_analyses =
        candidate_chars
        |> Enum.map(fn char_id ->
          analyze_character_comprehensive(char_id, start_time, end_time)
        end)
        |> Enum.reject(&is_nil/1)

      # Calculate similarity scores
      similarities =
        candidate_analyses
        |> Enum.map(fn candidate ->
          similarity_score = calculate_character_similarity(base_analysis, candidate)

          %{
            character: candidate,
            similarity_score: similarity_score,
            similarity_factors: identify_similarity_factors(base_analysis, candidate)
          }
        end)
        |> Enum.sort_by(& &1.similarity_score, :desc)
        |> Enum.take(limit)

      {:ok,
       %{
         base_character: base_analysis,
         similar_characters: similarities,
         timeframe: timeframe
       }}
    end
  end

  # Private analysis functions

  defp analyze_character_comprehensive(character_id, start_time, end_time) do
    # Get killmails as victim and attacker
    victim_killmails = get_character_victim_killmails(character_id, start_time, end_time)
    attacker_killmails = get_character_attacker_killmails(character_id, start_time, end_time)

    if Enum.empty?(victim_killmails) and Enum.empty?(attacker_killmails) do
      nil
    else
      character_name = get_character_name(character_id)

      %{
        character_id: character_id,
        character_name: character_name,

        # Basic stats
        total_kills: length(attacker_killmails),
        total_deaths: length(victim_killmails),
        kill_death_ratio:
          calculate_kd_ratio(length(attacker_killmails), length(victim_killmails)),

        # ISK efficiency
        isk_destroyed: calculate_total_isk_from_killmails(attacker_killmails),
        isk_lost: calculate_total_isk_from_killmails(victim_killmails),
        isk_efficiency: calculate_isk_efficiency(attacker_killmails, victim_killmails),

        # Activity patterns
        activity_pattern: analyze_activity_pattern(victim_killmails ++ attacker_killmails),
        most_active_hours: calculate_most_active_hours(victim_killmails ++ attacker_killmails),
        activity_systems: analyze_activity_systems(victim_killmails ++ attacker_killmails),

        # Combat analysis
        combat_style: analyze_combat_style(attacker_killmails, victim_killmails),
        preferred_ships: analyze_preferred_ships(victim_killmails),
        ship_versatility: calculate_ship_versatility(victim_killmails),
        engagement_preference: analyze_engagement_preference(attacker_killmails),

        # Threat assessment
        danger_rating: calculate_character_danger_rating(attacker_killmails),
        target_preference: analyze_target_preference(attacker_killmails),
        survival_rating: calculate_survival_rating(victim_killmails),

        # Alliance/Corp info
        corporation_info: get_character_corporation_info(victim_killmails ++ attacker_killmails),
        alliance_info: get_character_alliance_info(victim_killmails ++ attacker_killmails),

        # Advanced metrics
        solo_kill_percentage: calculate_solo_kill_percentage(attacker_killmails),
        avg_gang_size: calculate_average_gang_size(attacker_killmails),
        expensive_kill_ratio: calculate_expensive_kill_ratio(attacker_killmails),
        capital_experience: analyze_capital_experience(victim_killmails ++ attacker_killmails),

        # Raw data for further analysis
        victim_killmails: victim_killmails,
        attacker_killmails: attacker_killmails
      }
    end
  end

  defp compare_combat_effectiveness(character_analyses) do
    combat_metrics =
      character_analyses
      |> Enum.map(fn char ->
        %{
          character_id: char.character_id,
          character_name: char.character_name,
          kill_death_ratio: char.kill_death_ratio,
          isk_efficiency: char.isk_efficiency,
          danger_rating: char.danger_rating,
          solo_kill_percentage: char.solo_kill_percentage,
          combat_effectiveness_score: calculate_combat_effectiveness_score(char)
        }
      end)
      |> Enum.sort_by(& &1.combat_effectiveness_score, :desc)

    %{
      rankings: combat_metrics,
      top_performer: List.first(combat_metrics),
      metrics_comparison: %{
        highest_kd_ratio: Enum.max_by(combat_metrics, & &1.kill_death_ratio),
        highest_isk_efficiency: Enum.max_by(combat_metrics, & &1.isk_efficiency),
        most_dangerous: Enum.max_by(combat_metrics, & &1.danger_rating),
        best_solo_pilot: Enum.max_by(combat_metrics, & &1.solo_kill_percentage)
      }
    }
  end

  defp compare_activity_patterns(character_analyses) do
    activity_comparison =
      character_analyses
      |> Enum.map(fn char ->
        %{
          character_id: char.character_id,
          character_name: char.character_name,
          total_activity: char.total_kills + char.total_deaths,
          activity_score: calculate_activity_score(char),
          most_active_hours: char.most_active_hours,
          primary_systems: Enum.take(char.activity_systems, 3),
          activity_spread: calculate_activity_spread(char.activity_systems)
        }
      end)

    %{
      activity_rankings: Enum.sort_by(activity_comparison, & &1.activity_score, :desc),
      common_hours: find_common_active_hours(character_analyses),
      geographic_overlap: calculate_geographic_overlap(character_analyses),
      activity_diversity: analyze_activity_diversity(activity_comparison)
    }
  end

  defp compare_ship_preferences(character_analyses) do
    ship_analysis =
      character_analyses
      |> Enum.map(fn char ->
        %{
          character_id: char.character_id,
          character_name: char.character_name,
          preferred_ships: char.preferred_ships,
          ship_versatility: char.ship_versatility,
          combat_style: char.combat_style,
          capital_experience: char.capital_experience
        }
      end)

    %{
      ship_preferences: ship_analysis,
      common_ships: find_common_ship_preferences(ship_analysis),
      ship_class_distribution: analyze_ship_class_distribution(ship_analysis),
      specialization_levels: analyze_specialization_levels(ship_analysis)
    }
  end

  defp compare_threat_levels(character_analyses) do
    threat_analysis =
      character_analyses
      |> Enum.map(fn char ->
        %{
          character_id: char.character_id,
          character_name: char.character_name,
          danger_rating: char.danger_rating,
          survival_rating: char.survival_rating,
          target_preference: char.target_preference,
          threat_level: calculate_overall_threat_level(char)
        }
      end)
      |> Enum.sort_by(& &1.threat_level, :desc)

    %{
      threat_rankings: threat_analysis,
      highest_threat: List.first(threat_analysis),
      threat_categories: categorize_threats(threat_analysis),
      mutual_threat_matrix: calculate_mutual_threat_matrix(character_analyses)
    }
  end

  defp compare_geographic_patterns(character_analyses) do
    geographic_data =
      character_analyses
      |> Enum.map(fn char ->
        systems = char.activity_systems

        %{
          character_id: char.character_id,
          character_name: char.character_name,
          active_systems: systems,
          primary_region: determine_primary_region(systems),
          security_preference: analyze_security_preference(systems),
          roaming_tendency: calculate_roaming_tendency(systems)
        }
      end)

    %{
      geographic_profiles: geographic_data,
      system_overlaps: find_system_overlaps(geographic_data),
      regional_distribution: analyze_regional_distribution(geographic_data),
      encounter_probability: calculate_encounter_probabilities(geographic_data)
    }
  end

  defp analyze_character_relationships(character_analyses) do
    # Analyze potential relationships between characters
    _relationships = []

    # Check for same corporation/alliance
    corp_groups = Enum.group_by(character_analyses, & &1.corporation_info.corporation_id)
    alliance_groups = Enum.group_by(character_analyses, & &1.alliance_info.alliance_id)

    corp_relationships = identify_corporate_relationships(corp_groups)
    alliance_relationships = identify_alliance_relationships(alliance_groups)

    # Check for combat interactions
    combat_history = analyze_combat_history_between_characters(character_analyses)

    %{
      corporate_relationships: corp_relationships,
      alliance_relationships: alliance_relationships,
      combat_history: combat_history,
      relationship_summary:
        summarize_relationships(corp_relationships, alliance_relationships, combat_history)
    }
  end

  # Helper functions for calculations

  defp get_timeframe_bounds(timeframe) do
    now = DateTime.utc_now()

    case timeframe do
      :last_7_days -> {DateTime.add(now, -7, :day), now}
      :last_30_days -> {DateTime.add(now, -30, :day), now}
      :last_90_days -> {DateTime.add(now, -90, :day), now}
      :last_180_days -> {DateTime.add(now, -180, :day), now}
      {:custom, days} -> {DateTime.add(now, -days, :day), now}
    end
  end

  defp get_character_victim_killmails(character_id, start_time, end_time) do
    KillmailRaw
    |> Ash.Query.new()
    |> Ash.Query.filter(victim_character_id == ^character_id)
    |> Ash.Query.filter(killmail_time >= ^start_time and killmail_time <= ^end_time)
    |> Ash.Query.sort(killmail_time: :desc)
    |> Ash.Query.limit(500)
    |> Ash.read!(domain: Api)
  end

  defp get_character_attacker_killmails(_character_id, _start_time, _end_time) do
    # This would require a more complex query to find killmails where character was an attacker
    # For now, we'll return empty list - this would need to be implemented with proper attacker indexing
    []
  end

  defp get_character_name(character_id) do
    # Use NameResolver or fallback
    "Character #{character_id}"
  end

  defp calculate_kd_ratio(kills, deaths) do
    if deaths > 0 do
      Float.round(kills / deaths, 2)
    else
      if kills > 0, do: kills * 1.0, else: 0.0
    end
  end

  defp calculate_total_isk_from_killmails(killmails) do
    killmails
    |> Enum.map(&(&1.total_value || 0))
    |> Enum.sum()
    |> Decimal.new()
  end

  defp calculate_isk_efficiency(attacker_killmails, victim_killmails) do
    isk_destroyed = Decimal.to_float(calculate_total_isk_from_killmails(attacker_killmails))
    isk_lost = Decimal.to_float(calculate_total_isk_from_killmails(victim_killmails))

    if isk_lost > 0 do
      Float.round(isk_destroyed / isk_lost, 2)
    else
      if isk_destroyed > 0, do: 10.0, else: 1.0
    end
  end

  defp analyze_activity_pattern(killmails) do
    if Enum.empty?(killmails) do
      %{pattern: :inactive, intensity: 0}
    else
      # Analyze time distribution
      hourly_distribution =
        killmails
        |> Enum.map(fn km ->
          km.killmail_time
          |> DateTime.to_time()
          |> Time.to_iso8601()
          |> String.slice(0, 2)
          |> String.to_integer()
        end)
        |> Enum.frequencies()

      # Determine pattern
      pattern = if map_size(hourly_distribution) >= 12, do: :consistent, else: :sporadic
      # kills per day
      intensity = length(killmails) / 30.0

      %{
        pattern: pattern,
        intensity: Float.round(intensity, 2),
        hourly_distribution: hourly_distribution,
        peak_hours: get_peak_hours(hourly_distribution)
      }
    end
  end

  defp calculate_most_active_hours(killmails) do
    killmails
    |> Enum.map(fn km ->
      km.killmail_time
      |> DateTime.to_time()
      |> Time.to_iso8601()
      |> String.slice(0, 2)
      |> String.to_integer()
    end)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_hour, count} -> count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {hour, count} -> %{hour: hour, activity_count: count} end)
  end

  defp analyze_activity_systems(killmails) do
    killmails
    |> Enum.map(& &1.solar_system_id)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_system, count} -> count end, :desc)
    |> Enum.take(10)
    |> Enum.map(fn {system_id, count} ->
      %{
        system_id: system_id,
        system_name: NameResolver.system_name(system_id),
        activity_count: count
      }
    end)
  end

  defp analyze_combat_style(attacker_killmails, victim_killmails) do
    total_kills = length(attacker_killmails)
    total_deaths = length(victim_killmails)

    cond do
      total_kills > total_deaths * 2 -> :aggressive
      total_deaths > total_kills * 2 -> :cautious
      total_kills > 0 and total_deaths > 0 -> :balanced
      total_kills > 0 -> :hunter
      total_deaths > 0 -> :target
      true -> :inactive
    end
  end

  defp analyze_preferred_ships(victim_killmails) do
    victim_killmails
    |> Enum.map(& &1.victim_ship_type_id)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_ship, count} -> count end, :desc)
    |> Enum.take(5)
    |> Enum.map(fn {ship_type_id, count} ->
      %{
        ship_type_id: ship_type_id,
        ship_name: NameResolver.ship_name(ship_type_id),
        usage_count: count
      }
    end)
  end

  defp calculate_ship_versatility(victim_killmails) do
    unique_ships =
      victim_killmails |> Enum.map(& &1.victim_ship_type_id) |> Enum.uniq() |> length()

    total_losses = length(victim_killmails)

    if total_losses > 0 do
      Float.round(unique_ships / total_losses, 2)
    else
      0.0
    end
  end

  defp analyze_engagement_preference(_attacker_killmails) do
    # This would analyze the attackers list to determine gang size preferences
    # For now, return placeholder
    %{preference: :unknown, avg_gang_size: 0}
  end

  defp calculate_character_danger_rating(attacker_killmails) do
    kill_count = length(attacker_killmails)

    # Simple danger calculation
    cond do
      kill_count >= 50 -> :very_high
      kill_count >= 20 -> :high
      kill_count >= 10 -> :moderate
      kill_count >= 5 -> :low
      true -> :minimal
    end
  end

  defp analyze_target_preference(_attacker_killmails) do
    # Analyze what types of targets this character prefers
    # This would analyze victim ship types, values, etc.
    %{preference: :mixed}
  end

  defp calculate_survival_rating(victim_killmails) do
    death_count = length(victim_killmails)

    # Simple survival rating (inverse of deaths)
    cond do
      death_count <= 5 -> :excellent
      death_count <= 15 -> :good
      death_count <= 30 -> :average
      death_count <= 50 -> :poor
      true -> :very_poor
    end
  end

  defp get_character_corporation_info(killmails) do
    corp_info =
      killmails
      |> Enum.map(fn km ->
        case km.raw_data["victim"] do
          %{"corporation_id" => corp_id, "corporation_name" => corp_name} ->
            {corp_id, corp_name}

          _ ->
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> List.first()

    case corp_info do
      {corp_id, corp_name} -> %{corporation_id: corp_id, corporation_name: corp_name}
      nil -> %{corporation_id: nil, corporation_name: "Unknown"}
    end
  end

  defp get_character_alliance_info(killmails) do
    alliance_info =
      killmails
      |> Enum.map(fn km ->
        case km.raw_data["victim"] do
          %{"alliance_id" => alliance_id, "alliance_name" => alliance_name} ->
            {alliance_id, alliance_name}

          _ ->
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> List.first()

    case alliance_info do
      {alliance_id, alliance_name} -> %{alliance_id: alliance_id, alliance_name: alliance_name}
      nil -> %{alliance_id: nil, alliance_name: "No Alliance"}
    end
  end

  # Stub implementations for complex analysis functions
  defp calculate_solo_kill_percentage(_attacker_killmails), do: 0.0
  defp calculate_average_gang_size(_attacker_killmails), do: 1.0
  defp calculate_expensive_kill_ratio(_attacker_killmails), do: 0.0
  defp analyze_capital_experience(_killmails), do: %{has_experience: false, capital_kills: 0}
  defp calculate_combat_effectiveness_score(_char), do: 50.0
  defp calculate_activity_score(_char), do: 50.0
  defp calculate_activity_spread(_systems), do: 0.5
  defp find_common_active_hours(_characters), do: []
  defp calculate_geographic_overlap(_characters), do: 0.0
  defp analyze_activity_diversity(_activity_comparison), do: %{diversity_score: 0.5}
  defp find_common_ship_preferences(_ship_analysis), do: []
  defp analyze_ship_class_distribution(_ship_analysis), do: %{}
  defp analyze_specialization_levels(_ship_analysis), do: []
  defp calculate_overall_threat_level(_char), do: 50.0
  defp categorize_threats(_threat_analysis), do: %{}
  defp calculate_mutual_threat_matrix(_characters), do: %{}
  defp determine_primary_region(_systems), do: "Unknown"
  defp analyze_security_preference(_systems), do: :mixed
  defp calculate_roaming_tendency(_systems), do: 0.5
  defp find_system_overlaps(_geographic_data), do: []
  defp analyze_regional_distribution(_geographic_data), do: %{}
  defp calculate_encounter_probabilities(_geographic_data), do: %{}
  defp identify_corporate_relationships(_corp_groups), do: []
  defp identify_alliance_relationships(_alliance_groups), do: []
  defp analyze_combat_history_between_characters(_characters), do: []
  defp summarize_relationships(_corp, _alliance, _combat), do: %{}
  defp generate_character_rankings(_characters), do: []
  defp generate_comparison_insights(_characters), do: []
  defp generate_tactical_recommendations(_characters), do: []
  defp determine_combat_advantage(_char1, _char2), do: :balanced
  defp compare_activity_head_to_head(_char1, _char2), do: %{}
  defp analyze_ship_matchup(_char1, _char2), do: %{}
  defp compare_experience_levels(_char1, _char2), do: %{}
  defp assess_mutual_threat(_char1, _char2), do: %{}
  defp predict_encounter_outcome(_char1, _char2), do: %{prediction: :balanced, confidence: 0.5}
  defp generate_tactical_advice(_char1, _char2), do: []
  defp find_previous_encounters(_char1_id, _char2_id), do: []
  defp find_common_activity_systems(_char1, _char2), do: []
  defp get_candidate_characters_for_similarity(_base, _start_time, _limit), do: []
  defp calculate_character_similarity(_base, _candidate), do: 0.5
  defp identify_similarity_factors(_base, _candidate), do: []

  defp get_peak_hours(hourly_dist) do
    hourly_dist
    |> Enum.sort_by(fn {_hour, count} -> count end, :desc)
    |> Enum.take(3)
    |> Enum.map(&elem(&1, 0))
  end
end
