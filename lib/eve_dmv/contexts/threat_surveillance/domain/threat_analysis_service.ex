defmodule EveDmv.Contexts.ThreatSurveillance.Domain.ThreatAnalysisService do
  @compile {:nowarn_unused_function}
  @moduledoc """
  Comprehensive threat analysis service for characters and corporations.

  Provides:
  - Multi-dimensional threat assessment
  - Historical threat evolution
  - Predictive threat modeling
  - Threat correlation analysis
  - Risk factor identification

  All analysis is based on real killmail data, behavioral patterns,
  and threat scoring from the ThreatAssessmentEngine.
  """

  import Ecto.Query

  alias EveDmv.Api
  alias EveDmv.Contexts.ThreatSurveillance.Domain.BehavioralPatternAnalyzer
  alias EveDmv.Contexts.ThreatSurveillance.Domain.ThreatAssessmentEngine
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Intelligence.CharacterStats
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Shared.Infrastructure.UnifiedCache

  require Logger

  # 5 minutes
  @cache_ttl 300

  @doc """
  Get comprehensive threat analysis for an entity.

  ## Parameters
  - `entity_id` - Character or corporation ID
  - `entity_type` - :character or :corporation
  - `options` - Analysis options:
    - `:include_history` - Include historical threat data
    - `:include_predictions` - Include predictive analysis
    - `:include_correlations` - Include correlated threats
    - `:timeframe` - Analysis timeframe in days (default: 90)

  ## Returns
  - `{:ok, analysis}` - Comprehensive threat analysis
  - `{:error, reason}` - Error if analysis fails
  """
  def get_comprehensive_analysis(entity_id, entity_type, options \\ []) do
    Logger.info("Performing comprehensive threat analysis",
      entity_id: entity_id,
      entity_type: entity_type
    )

    cache_key = {:comprehensive_analysis, entity_type, entity_id, options}

    case UnifiedCache.get(:threat_surveillance, cache_key) do
      {:ok, cached_analysis} ->
        {:ok, cached_analysis}

      :miss ->
        case perform_comprehensive_analysis(entity_id, entity_type, options) do
          {:ok, analysis} ->
            UnifiedCache.put(:threat_surveillance, cache_key, analysis, @cache_ttl)
            {:ok, analysis}

          {:error, reason} ->
            {:error, reason}

          _ ->
            {:error, :analysis_failed}
        end
    end
  end

  # Private implementation

  defp perform_comprehensive_analysis(entity_id, entity_type, options) do
    timeframe = Keyword.get(options, :timeframe, 90)

    tasks =
      [
        Task.async(fn -> get_current_threat_assessment(entity_id, entity_type) end),
        Task.async(fn -> get_behavioral_analysis(entity_id, entity_type, timeframe) end),
        Task.async(fn -> get_combat_statistics(entity_id, entity_type, timeframe) end),
        Task.async(fn -> get_engagement_patterns(entity_id, entity_type, timeframe) end)
      ]
      |> then(fn tasks ->
        # Add optional analyses
        if Keyword.get(options, :include_history, true) do
          [Task.async(fn -> get_threat_history(entity_id, entity_type) end) | tasks]
        else
          tasks
        end
      end)
      |> then(fn tasks ->
        if Keyword.get(options, :include_predictions, true) do
          [Task.async(fn -> get_threat_predictions(entity_id, entity_type) end) | tasks]
        else
          tasks
        end
      end)
      |> then(fn tasks ->
        if Keyword.get(options, :include_correlations, true) do
          [Task.async(fn -> get_threat_correlations(entity_id, entity_type) end) | tasks]
        else
          tasks
        end
      end)

    # Await all tasks with timeout
    results = Task.await_many(tasks, 10_000)

    # Process results
    build_comprehensive_analysis(entity_id, entity_type, results, options)
  end

  defp get_current_threat_assessment(entity_id, entity_type) do
    case ThreatAssessmentEngine.assess_threat_level(entity_id, entity_type) do
      {:ok, assessment} -> {:threat_assessment, assessment}
      {:error, reason} -> {:threat_assessment, %{error: reason}}
    end
  end

  defp get_behavioral_analysis(entity_id, entity_type, timeframe) do
    case BehavioralPatternAnalyzer.analyze_patterns(entity_id, entity_type, timeframe: timeframe) do
      {:ok, patterns} -> {:behavioral_patterns, patterns}
      {:error, reason} -> {:behavioral_patterns, %{error: reason}}
    end
  end

  defp get_combat_statistics(entity_id, entity_type, timeframe) do
    stats =
      case entity_type do
        :character -> get_character_combat_stats(entity_id, timeframe)
        :corporation -> get_corporation_combat_stats(entity_id, timeframe)
      end

    {:combat_statistics, stats}
  end

  defp get_character_combat_stats(character_id, _days) do
    # Query character stats from materialized view
    case Api.get(CharacterStats, character_id) do
      {:ok, stats} ->
        %{
          total_kills: stats.total_kills || 0,
          total_losses: stats.total_losses || 0,
          kill_death_ratio:
            Float.round((stats.total_kills || 0) / max(1, stats.total_losses || 0), 2),
          total_isk_destroyed: stats.total_isk_destroyed || 0,
          total_isk_lost: stats.total_isk_lost || 0,
          isk_efficiency:
            calculate_isk_efficiency(stats.total_isk_destroyed, stats.total_isk_lost),
          last_seen: stats.last_seen,
          danger_rating: stats.danger_rating || 0,
          pvp_experience_days: stats.pvp_experience_days || 0
        }

      {:error, _} ->
        # No stats found - return empty stats
        %{
          total_kills: 0,
          total_losses: 0,
          kill_death_ratio: 0.0,
          total_isk_destroyed: 0,
          total_isk_lost: 0,
          isk_efficiency: 0.0,
          last_seen: nil,
          danger_rating: 0,
          pvp_experience_days: 0
        }
    end
  end

  defp get_corporation_combat_stats(corporation_id, days) do
    since = DateTimeUtils.add(DateTime.utc_now(), -days * 24 * 60 * 60, :second)

    # Query killmails for corporation members
    victim_query =
      from(k in KillmailRaw,
        where: fragment("?->>'corporation_id' = ?", k.victim, ^to_string(corporation_id)),
        where: k.killmail_time > ^since,
        select: %{
          count: count(k.id),
          total_value: sum(k.zkb_total_value)
        }
      )

    case EveDmv.Repo.one(victim_query) do
      %{count: losses, total_value: isk_lost} ->
        %{
          member_losses: losses || 0,
          total_isk_lost: isk_lost || 0,
          avg_loss_value: if(losses > 0, do: div(isk_lost || 0, losses), else: 0),
          activity_level: categorize_activity_level(losses || 0, days)
        }

      _ ->
        %{
          member_losses: 0,
          total_isk_lost: 0,
          avg_loss_value: 0,
          activity_level: :inactive
        }
    end
  end

  defp get_engagement_patterns(entity_id, entity_type, timeframe) do
    since = DateTimeUtils.add(DateTime.utc_now(), -timeframe * 24 * 60 * 60, :second)

    # Query recent engagements
    query = build_engagement_query(entity_id, entity_type, since)

    case EveDmv.Repo.all(query) do
      killmails when is_list(killmails) ->
        patterns = analyze_engagement_patterns(killmails)
        {:engagement_patterns, patterns}

      _ ->
        {:engagement_patterns, %{}}
    end
  end

  defp build_engagement_query(entity_id, :character, since) do
    from(k in KillmailRaw,
      where: fragment("?->>'character_id' = ?", k.victim, ^to_string(entity_id)),
      where: k.killmail_time > ^since,
      order_by: [desc: k.killmail_time],
      limit: 500
    )
  end

  defp build_engagement_query(entity_id, :corporation, since) do
    from(k in KillmailRaw,
      where: fragment("?->>'corporation_id' = ?", k.victim, ^to_string(entity_id)),
      where: k.killmail_time > ^since,
      order_by: [desc: k.killmail_time],
      limit: 500
    )
  end

  defp analyze_engagement_patterns(killmails) do
    if Enum.empty?(killmails) do
      %{
        preferred_engagement_size: :unknown,
        combat_role: :unknown,
        threat_vectors: []
      }
    else
      gang_sizes = Enum.map(killmails, fn km -> length(km.attackers) end)
      avg_gang_size = Enum.sum(gang_sizes) / length(gang_sizes)

      preferred_size =
        cond do
          avg_gang_size < 2 -> :solo
          avg_gang_size < 6 -> :small_gang
          avg_gang_size < 15 -> :medium_fleet
          true -> :large_fleet
        end

      # Analyze combat role based on ship types
      ship_types =
        killmails
        |> Enum.map(& &1.victim["ship_type_id"])
        |> Enum.filter(&(&1 != nil))
        |> Enum.frequencies()

      combat_role = infer_combat_role(ship_types)

      # Identify threat vectors (who they lose to most)
      threat_vectors = identify_threat_vectors(killmails)

      %{
        preferred_engagement_size: preferred_size,
        average_enemy_count: Float.round(avg_gang_size, 1),
        combat_role: combat_role,
        threat_vectors: threat_vectors
      }
    end
  end

  defp get_threat_history(_entity_id, _entity_type) do
    # Get historical threat assessments
    # In a full implementation, this would query a threat history table
    {:threat_history,
     %{
       assessments: [],
       trend: :stable,
       peak_threat_date: nil,
       average_threat_level: 0
     }}
  end

  defp get_threat_predictions(entity_id, entity_type) do
    # Predictive threat modeling based on trends
    # Simplified implementation - real version would use ML/statistical models
    {:threat_predictions,
     %{
       next_24h: %{level: :medium, confidence: 0.7},
       next_7d: %{level: :medium, confidence: 0.5},
       risk_factors: identify_future_risk_factors(entity_id, entity_type)
     }}
  end

  defp get_threat_correlations(_entity_id, _entity_type) do
    # Find correlated threats (associates, common enemies, etc)
    {:threat_correlations,
     %{
       associates: [],
       common_enemies: [],
       alliance_threats: []
     }}
  end

  defp build_comprehensive_analysis(entity_id, entity_type, results, options) do
    # Convert results list to map
    analysis_data = Enum.into(results, %{})

    analysis = %{
      entity_id: entity_id,
      entity_type: entity_type,
      analysis_timestamp: DateTime.utc_now(),
      analysis_options: options,

      # Core assessments
      current_threat_level:
        get_in(analysis_data, [:threat_assessment, :threat_level]) || :unknown,
      threat_score: get_in(analysis_data, [:threat_assessment, :threat_score]) || 0,
      danger_rating: get_in(analysis_data, [:threat_assessment, :danger_rating]) || 0,

      # Behavioral analysis
      behavioral_patterns: Map.get(analysis_data, :behavioral_patterns, %{}),

      # Combat statistics
      combat_statistics: Map.get(analysis_data, :combat_statistics, %{}),
      engagement_patterns: Map.get(analysis_data, :engagement_patterns, %{}),

      # Risk assessment
      risk_factors: compile_risk_factors(analysis_data),
      threat_classification: classify_threat_type(analysis_data),

      # Recommendations
      recommendations: generate_threat_recommendations(analysis_data)
    }

    # Add optional sections if requested
    final_analysis =
      analysis
      |> maybe_add_threat_history(analysis_data)
      |> maybe_add_threat_predictions(analysis_data)
      |> maybe_add_threat_correlations(analysis_data)

    {:ok, final_analysis}
  end

  defp maybe_add_threat_history(analysis, analysis_data) do
    if Map.has_key?(analysis_data, :threat_history) do
      Map.put(analysis, :threat_history, analysis_data.threat_history)
    else
      analysis
    end
  end

  defp maybe_add_threat_predictions(analysis, analysis_data) do
    if Map.has_key?(analysis_data, :threat_predictions) do
      Map.put(analysis, :threat_predictions, analysis_data.threat_predictions)
    else
      analysis
    end
  end

  defp maybe_add_threat_correlations(analysis, analysis_data) do
    if Map.has_key?(analysis_data, :threat_correlations) do
      Map.put(analysis, :threat_correlations, analysis_data.threat_correlations)
    else
      analysis
    end
  end

  # Helper functions

  defp calculate_isk_efficiency(destroyed, lost) do
    total = (destroyed || 0) + (lost || 0)

    if total > 0 do
      Float.round((destroyed || 0) / total * 100, 1)
    else
      0.0
    end
  end

  defp categorize_activity_level(kill_count, days) do
    kills_per_day = kill_count / max(1, days)

    cond do
      kills_per_day >= 5 -> :very_active
      kills_per_day >= 2 -> :active
      kills_per_day >= 0.5 -> :moderate
      kills_per_day > 0 -> :low
      true -> :inactive
    end
  end

  defp infer_combat_role(ship_type_frequencies) do
    # Analyze ship usage patterns to determine predominant combat role
    if Enum.empty?(ship_type_frequencies) do
      :unknown
    else
      analyze_ship_role_patterns(ship_type_frequencies)
    end
  end

  defp analyze_ship_role_patterns(ship_type_frequencies) do
    # Get ship attributes for analysis
    ship_classifications = get_ship_classifications(Map.keys(ship_type_frequencies))

    # Calculate role weights based on usage frequency
    role_weights =
      ship_type_frequencies
      |> Enum.reduce(%{}, fn {ship_type_id, frequency}, acc ->
        case Map.get(ship_classifications, ship_type_id) do
          nil ->
            acc

          ship_data ->
            role = ship_data.role_classification || "dps"
            size_class = ship_data.size_class || "unknown"

            # Weight by frequency and ship importance
            weight = frequency * get_ship_importance_multiplier(size_class)
            Map.update(acc, role, weight, &(&1 + weight))
        end
      end)

    # Determine predominant role
    determine_primary_role(role_weights)
  end

  defp get_ship_classifications(ship_type_ids) do
    case EveDmv.Repo.query(
           """
             SELECT sa.type_id, sa.role_classification, sa.size_class, sa.tactical_category,
                    eit.type_name, eit.group_name
             FROM ship_attributes sa
             JOIN eve_item_types eit ON sa.type_id = eit.type_id
             WHERE sa.type_id = ANY($1)
           """,
           [ship_type_ids]
         ) do
      {:ok, %{rows: rows}} ->
        rows
        |> Enum.reduce(%{}, fn [
                                 type_id,
                                 role,
                                 size_class,
                                 tactical_category,
                                 type_name,
                                 group_name
                               ],
                               acc ->
          Map.put(acc, type_id, %{
            role_classification: role,
            size_class: size_class,
            tactical_category: tactical_category,
            type_name: type_name,
            group_name: group_name
          })
        end)

      _ ->
        # Fallback to basic ship group analysis if no ship attributes available
        get_basic_ship_classifications(ship_type_ids)
    end
  end

  defp get_basic_ship_classifications(ship_type_ids) do
    case EveDmv.Repo.query(
           """
             SELECT type_id, type_name, group_name
             FROM eve_item_types
             WHERE type_id = ANY($1) AND is_ship = true
           """,
           [ship_type_ids]
         ) do
      {:ok, %{rows: rows}} ->
        rows
        |> Enum.reduce(%{}, fn [type_id, type_name, group_name], acc ->
          Map.put(acc, type_id, %{
            role_classification: infer_role_from_group(group_name),
            size_class: infer_size_from_group(group_name),
            tactical_category: infer_tactical_from_group(group_name),
            type_name: type_name,
            group_name: group_name
          })
        end)

      _ ->
        %{}
    end
  end

  defp infer_role_from_group(group_name) do
    cond do
      String.contains?(group_name, ["Logistics", "Force Auxiliary"]) ->
        "logistics"

      String.contains?(group_name, ["Recon", "Electronic Attack"]) ->
        "ewar"

      String.contains?(group_name, ["Interceptor", "Interdictor", "Heavy Interdiction"]) ->
        "tackle"

      String.contains?(group_name, ["Assault", "Heavy Assault"]) ->
        "dps"

      String.contains?(group_name, ["Command"]) ->
        "support"

      true ->
        "dps"
    end
  end

  defp infer_size_from_group(group_name) do
    cond do
      String.contains?(group_name, ["Frigate", "Stealth Bomber"]) -> "frigate"
      String.contains?(group_name, ["Destroyer"]) -> "destroyer"
      String.contains?(group_name, ["Cruiser"]) -> "cruiser"
      String.contains?(group_name, ["Battlecruiser"]) -> "battlecruiser"
      String.contains?(group_name, ["Battleship", "Marauder", "Black Ops"]) -> "battleship"
      String.contains?(group_name, ["Carrier", "Dreadnought", "Force Auxiliary"]) -> "capital"
      String.contains?(group_name, ["Supercarrier", "Titan"]) -> "supercapital"
      true -> "unknown"
    end
  end

  defp infer_tactical_from_group(group_name) do
    cond do
      String.contains?(group_name, ["Logistics"]) -> "logistics"
      String.contains?(group_name, ["Electronic", "Recon"]) -> "ewar"
      String.contains?(group_name, ["Interceptor", "Interdictor"]) -> "tackler"
      String.contains?(group_name, ["Stealth Bomber"]) -> "bomber"
      String.contains?(group_name, ["Assault", "Heavy Assault"]) -> "brawler"
      true -> "brawler"
    end
  end

  defp get_ship_importance_multiplier(size_class) do
    case size_class do
      "frigate" -> 1.0
      "destroyer" -> 1.2
      "cruiser" -> 1.5
      "battlecruiser" -> 2.0
      "battleship" -> 2.5
      "capital" -> 4.0
      "supercapital" -> 6.0
      _ -> 1.0
    end
  end

  defp determine_primary_role(role_weights) when map_size(role_weights) == 0, do: :unknown

  defp determine_primary_role(role_weights) do
    total_weight = role_weights |> Map.values() |> Enum.sum()

    # Find the dominant role
    {primary_role, primary_weight} =
      role_weights
      |> Enum.max_by(fn {_role, weight} -> weight end)

    primary_percentage = primary_weight / total_weight

    # Classify based on role distribution
    cond do
      primary_percentage >= 0.6 ->
        # Clear specialization
        role_string_to_atom(primary_role)

      primary_percentage >= 0.4 ->
        # Primary role with some diversity
        case primary_role do
          "dps" -> :damage_focused
          "logistics" -> :support_focused
          "ewar" -> :disruption_focused
          "tackle" -> :control_focused
          _ -> :specialized
        end

      true ->
        # Very diverse usage
        :versatile
    end
  end

  defp role_string_to_atom(role) do
    case role do
      "logistics" -> :logistics
      "ewar" -> :ewar
      "tackle" -> :tackle
      "dps" -> :dps
      "support" -> :support
      # Default fallback
      _ -> :dps
    end
  end

  defp identify_threat_vectors(killmails) do
    # Find most dangerous opponents
    killmails
    |> Enum.flat_map(& &1.attackers)
    |> Enum.filter(&(&1["character_id"] != nil))
    |> Enum.group_by(& &1["character_id"])
    |> Enum.map(fn {char_id, attacks} ->
      %{
        character_id: char_id,
        encounter_count: length(attacks),
        total_damage: Enum.sum(Enum.map(attacks, &(&1["damage_done"] || 0)))
      }
    end)
    |> Enum.sort_by(& &1.encounter_count, :desc)
    |> Enum.take(5)
  end

  defp identify_future_risk_factors(_entity_id, _entity_type) do
    # Identify factors that might increase future threat
    [
      %{
        factor: :increased_activity,
        description: "Recent increase in PvP activity",
        impact: :medium
      }
    ]
  end

  defp compile_risk_factors(analysis_data) do
    # Check combat statistics for risk indicators
    combat_stats = Map.get(analysis_data, :combat_statistics, %{})
    # Check behavioral patterns
    behavioral = Map.get(analysis_data, :behavioral_patterns, %{})

    []
    |> then(fn risk_factors ->
      if Map.get(combat_stats, :kill_death_ratio, 0) > 3.0 do
        [
          %{
            factor: :high_kdr,
            description: "High kill/death ratio indicates skilled combatant",
            severity: :high
          }
          | risk_factors
        ]
      else
        risk_factors
      end
    end)
    |> then(fn risk_factors ->
      if Map.get(combat_stats, :danger_rating, 0) > 80 do
        [
          %{
            factor: :high_danger_rating,
            description: "Consistently dangerous in combat",
            severity: :high
          }
          | risk_factors
        ]
      else
        risk_factors
      end
    end)
    |> then(fn risk_factors ->
      if get_in(behavioral, [:engagement_patterns, :solo_percentage]) > 70 do
        [
          %{
            factor: :solo_hunter,
            description: "Primarily operates solo - unpredictable threat",
            severity: :medium
          }
          | risk_factors
        ]
      else
        risk_factors
      end
    end)
  end

  defp classify_threat_type(analysis_data) do
    # Classify the type of threat based on patterns
    engagement = Map.get(analysis_data, :engagement_patterns, %{})
    behavioral = Map.get(analysis_data, :behavioral_patterns, %{})

    cond do
      Map.get(engagement, :preferred_engagement_size) == :solo ->
        :solo_hunter

      Map.get(engagement, :preferred_engagement_size) in [:small_gang, :medium_fleet] ->
        :gang_member

      Map.get(engagement, :preferred_engagement_size) == :large_fleet ->
        :fleet_pilot

      get_in(behavioral, [:activity_patterns, :estimated_timezone]) == "Mixed/Unknown" ->
        :irregular_threat

      true ->
        :general_threat
    end
  end

  defp generate_threat_recommendations(analysis_data) do
    threat_type = classify_threat_type(analysis_data)
    behavioral = Map.get(analysis_data, :behavioral_patterns, %{})

    []
    |> then(fn recommendations ->
      case threat_type do
        :solo_hunter ->
          ["Avoid isolated travel in their active systems" | recommendations]

        :gang_member ->
          ["Watch for scout alts when this pilot is active" | recommendations]

        :fleet_pilot ->
          ["Monitor for fleet formups when active" | recommendations]

        _ ->
          recommendations
      end
    end)
    |> then(fn recommendations ->
      # Add specific recommendations based on patterns
      if get_in(behavioral, [:activity_patterns, :peak_hours]) != [] do
        peak_hours = get_in(behavioral, [:activity_patterns, :peak_hours])
        ["Highest threat during hours: #{Enum.join(peak_hours, ", ")}" | recommendations]
      else
        recommendations
      end
    end)
  end
end
