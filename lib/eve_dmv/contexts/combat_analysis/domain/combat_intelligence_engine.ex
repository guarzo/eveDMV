defmodule EveDmv.Contexts.CombatAnalysis.Domain.CombatIntelligenceEngine do
  @moduledoc """
  Core engine for combat intelligence analysis and scoring.

  Provides comprehensive combat intelligence including character analysis,
  threat assessment, fleet effectiveness, and tactical recommendations.
  """
  """

  use GenServer

  alias EveDmv.DomainEvents.KillmailEnriched
  alias EveDmv.Shared.Infrastructure.UnifiedCache

  require Logger

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get comprehensive intelligence summary for an entity.
  """
  def get_intelligence_summary(entity_id, options \\ []) do
    GenServer.call(__MODULE__, {:get_intelligence_summary, entity_id, options})
  end

  @doc """
  Analyze character combat patterns and effectiveness.
  """
  def analyze_character_combat(character_id, options \\ []) do
    GenServer.call(__MODULE__, {:analyze_character_combat, character_id, options})
  end

  @doc """
  Assess threat level for character or corporation.
  """
  def assess_threat(entity_id, entity_type, options \\ []) do
    GenServer.call(__MODULE__, {:assess_threat, entity_id, entity_type, options})
  end

  @doc """
  Process killmail for intelligence updates.
  """
  def process_killmail(%KillmailEnriched{} = killmail) do
    GenServer.cast(__MODULE__, {:process_killmail, killmail})
  end

  @doc """
  Update static data for intelligence calculations.
  """
  def update_static_data(static_data_event) do
    GenServer.cast(__MODULE__, {:update_static_data, static_data_event})
  end

  # GenServer implementation

  @impl GenServer
  def init(_opts) do
    state = %{
      processed_killmails: 0,
      intelligence_cache: %{},
      static_data_version: nil
    }

    Logger.info("CombatIntelligenceEngine started")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:get_intelligence_summary, entity_id, options}, _from, state) do
    entity_type = Keyword.get(options, :entity_type, :character)
    cache_key = {:intelligence_summary, entity_id, entity_type}

    case UnifiedCache.get_combat_analysis(cache_key) do
      {:ok, summary} ->
        {:reply, {:ok, summary}, state}

      {:error, :not_found} ->
        case generate_intelligence_summary(entity_id, entity_type, options) do
          {:ok, summary} ->
            # 15 minutes
            UnifiedCache.cache_combat_analysis(cache_key, summary, 900)
            {:reply, {:ok, summary}, state}

          error ->
            {:reply, error, state}
        end
    end
  end

  @impl GenServer
  def handle_call({:analyze_character_combat, character_id, options}, _from, state) do
    cache_key = {:character_combat_analysis, character_id}

    case UnifiedCache.get_combat_analysis(cache_key) do
      {:ok, analysis} ->
        {:reply, {:ok, analysis}, state}

      {:error, :not_found} ->
        case perform_character_combat_analysis(character_id, options) do
          {:ok, analysis} ->
            # 30 minutes
            UnifiedCache.cache_combat_analysis(cache_key, analysis, 1800)
            {:reply, {:ok, analysis}, state}

          error ->
            {:reply, error, state}
        end
    end
  end

  @impl GenServer
  def handle_call({:assess_threat, entity_id, entity_type, options}, _from, state) do
    cache_key = {:threat_assessment, entity_id, entity_type}

    case UnifiedCache.get_combat_analysis(cache_key) do
      {:ok, assessment} ->
        {:reply, {:ok, assessment}, state}

      {:error, :not_found} ->
        case perform_threat_assessment(entity_id, entity_type, options) do
          {:ok, assessment} ->
            # 10 minutes
            UnifiedCache.cache_combat_analysis(cache_key, assessment, 600)
            {:reply, {:ok, assessment}, state}

          error ->
            {:reply, error, state}
        end
    end
  end

  @impl GenServer
  def handle_call(:health_check, _from, state) do
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_cast({:process_killmail, killmail}, state) do
    # Update intelligence data based on killmail
    update_character_intelligence(killmail)
    update_corporation_intelligence(killmail)
    invalidate_related_cache(killmail)

    {:noreply, %{state | processed_killmails: state.processed_killmails + 1}}
  rescue
    error ->
      Logger.error("Failed to process killmail for intelligence: #{inspect(error)}")
      {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:update_static_data, event}, state) do
    # Update cached static data
    new_version = Map.get(event, :version, DateTime.utc_now())
    Logger.info("Updating static data for combat intelligence: #{new_version}")

    # Invalidate caches that depend on static data
    UnifiedCache.invalidate_domain(:combat)

    {:noreply, %{state | static_data_version: new_version}}
  end

  # Private functions

  defp generate_intelligence_summary(entity_id, entity_type, options) do
    summary = %{
      entity_id: entity_id,
      entity_type: entity_type,
      generated_at: DateTime.utc_now(),
      threat_level: calculate_threat_level(entity_id, entity_type),
      combat_effectiveness: calculate_combat_effectiveness(entity_id, entity_type),
      activity_metrics: get_activity_metrics(entity_id, entity_type, options),
      ship_preferences: get_ship_preferences(entity_id, entity_type),
      tactical_patterns: analyze_tactical_patterns(entity_id, entity_type),
      recommendations: generate_recommendations(entity_id, entity_type)
    }

    {:ok, summary}
  rescue
    error ->
      Logger.error("Failed to generate intelligence summary: #{inspect(error)}")
      {:error, :generation_failed}
  end

  defp perform_character_combat_analysis(character_id, options) do
    time_range = Keyword.get(options, :time_range, :last_30_days)

    try do
      analysis = %{
        character_id: character_id,
        analyzed_at: DateTime.utc_now(),
        time_range: time_range,
        kill_stats: get_character_kill_stats(character_id, time_range),
        ship_usage: get_character_ship_usage(character_id, time_range),
        combat_patterns: get_character_combat_patterns(character_id, time_range),
        effectiveness_metrics: calculate_character_effectiveness(character_id, time_range),
        threat_score: calculate_character_threat_score(character_id, time_range),
        behavioral_analysis: analyze_character_behavior(character_id, time_range)
      }

      {:ok, analysis}
    rescue
      error ->
        Logger.error("Failed to analyze character combat: #{inspect(error)}")
        {:error, :analysis_failed}
    end
  end

  defp perform_threat_assessment(entity_id, entity_type, options) do
    assessment_type = Keyword.get(options, :assessment_type, :comprehensive)

    try do
      assessment = %{
        entity_id: entity_id,
        entity_type: entity_type,
        assessment_type: assessment_type,
        assessed_at: DateTime.utc_now(),
        threat_level: calculate_threat_level(entity_id, entity_type),
        threat_score: calculate_threat_score(entity_id, entity_type),
        risk_factors: identify_risk_factors(entity_id, entity_type),
        behavioral_indicators: get_behavioral_indicators(entity_id, entity_type),
        intelligence_confidence: calculate_confidence_score(entity_id, entity_type),
        recommendations: generate_threat_recommendations(entity_id, entity_type)
      }

      {:ok, assessment}
    rescue
      error ->
        Logger.error("Failed to perform threat assessment: #{inspect(error)}")
        {:error, :assessment_failed}
    end
  end

  # Intelligence calculation functions

  defp calculate_threat_level(entity_id, entity_type) do
    # Simplified threat level calculation
    case entity_type do
      :character ->
        recent_kills = get_character_recent_kills(entity_id)
        gang_activity = get_character_gang_activity(entity_id)

        cond do
          recent_kills > 50 and gang_activity > 0.8 -> :critical
          recent_kills > 20 and gang_activity > 0.6 -> :high
          recent_kills > 5 and gang_activity > 0.4 -> :medium
          recent_kills > 0 -> :low
          true -> :minimal
        end

      :corporation ->
        member_count = get_corporation_member_count(entity_id)
        recent_activity = get_corporation_recent_activity(entity_id)

        cond do
          member_count > 1000 and recent_activity > 0.8 -> :critical
          member_count > 500 and recent_activity > 0.6 -> :high
          member_count > 100 and recent_activity > 0.4 -> :medium
          member_count > 10 -> :low
          true -> :minimal
        end
    end
  end

  defp calculate_combat_effectiveness(entity_id, entity_type) do
    case entity_type do
      :character ->
        %{
          kill_efficiency: calculate_kill_efficiency(entity_id),
          survival_rate: calculate_survival_rate(entity_id),
          isk_efficiency: calculate_isk_efficiency(entity_id),
          fleet_participation: calculate_fleet_participation(entity_id)
        }

      :corporation ->
        %{
          member_effectiveness: calculate_member_effectiveness(entity_id),
          fleet_coordination: calculate_fleet_coordination(entity_id),
          strategic_impact: calculate_strategic_impact(entity_id)
        }
    end
  end

  defp get_activity_metrics(entity_id, entity_type, options) do
    time_range = Keyword.get(options, :time_range, :last_30_days)

    %{
      killmails_involved: count_killmails_involved(entity_id, entity_type, time_range),
      systems_active: count_active_systems(entity_id, entity_type, time_range),
      peak_activity_hours: get_peak_activity_hours(entity_id, entity_type, time_range),
      alliance_interactions: get_alliance_interactions(entity_id, entity_type, time_range)
    }
  end

  defp get_ship_preferences(entity_id, entity_type) do
    case entity_type do
      :character ->
        get_character_ship_preferences(entity_id)

      :corporation ->
        get_corporation_ship_preferences(entity_id)
    end
  end

  defp analyze_tactical_patterns(entity_id, entity_type) do
    %{
      preferred_engagement_types: get_preferred_engagement_types(entity_id, entity_type),
      tactical_roles: identify_tactical_roles(entity_id, entity_type),
      coordination_patterns: analyze_coordination_patterns(entity_id, entity_type)
    }
  end

  defp generate_recommendations(entity_id, entity_type) do
    threat_level = calculate_threat_level(entity_id, entity_type)
    effectiveness = calculate_combat_effectiveness(entity_id, entity_type)

    base_recommendations = []

    recommendations =
      case threat_level do
        :critical ->
          ["Exercise extreme caution", "Consider fleet engagement only" | base_recommendations]

        :high ->
          ["Approach with significant backup", "Monitor closely" | base_recommendations]

        :medium ->
          ["Standard precautions recommended" | base_recommendations]

        :low ->
          ["Low threat, but remain alert" | base_recommendations]

        :minimal ->
          ["Minimal threat detected" | base_recommendations]
      end

    case entity_type do
      :character -> recommendations ++ generate_character_recommendations(effectiveness)
      :corporation -> recommendations ++ generate_corporation_recommendations(effectiveness)
    end
  end

  # Helper functions for intelligence gathering

  defp update_character_intelligence(killmail) do
    # Update character-specific intelligence metrics
    victim_id = get_in(killmail.victim, [:character_id])
    if victim_id, do: invalidate_character_cache(victim_id)

    Enum.each(killmail.attackers, fn attacker ->
      if attacker[:character_id], do: invalidate_character_cache(attacker[:character_id])
    end)
  end

  defp update_corporation_intelligence(killmail) do
    # Update corporation-specific intelligence metrics
    victim_corp = get_in(killmail.victim, [:corporation_id])
    if victim_corp, do: invalidate_corporation_cache(victim_corp)

    Enum.each(killmail.attackers, fn attacker ->
      if attacker[:corporation_id], do: invalidate_corporation_cache(attacker[:corporation_id])
    end)
  end

  defp invalidate_related_cache(killmail) do
    # Invalidate caches that might be affected by this killmail
    victim_ids =
      case get_in(killmail.victim, [:character_id]) do
        nil -> []
        victim_id -> [victim_id]
      end

    attacker_ids = Enum.map(killmail.attackers, & &1[:character_id]) |> Enum.filter(& &1)
    all_affected_entities = victim_ids ++ attacker_ids

    Enum.each(all_affected_entities, fn entity_id ->
      UnifiedCache.delete(:combat, {:intelligence_summary, entity_id, :character})
      UnifiedCache.delete(:combat, {:character_combat_analysis, entity_id})
      UnifiedCache.delete(:combat, {:threat_assessment, entity_id, :character})
    end)
  end

  defp invalidate_character_cache(character_id) do
    UnifiedCache.delete(:combat, {:character_combat_analysis, character_id})
    UnifiedCache.delete(:combat, {:intelligence_summary, character_id, :character})
  end

  defp invalidate_corporation_cache(corp_id) do
    UnifiedCache.delete(:combat, {:intelligence_summary, corp_id, :corporation})
  end

  # Placeholder implementations for complex calculations
  # These would be implemented with real data queries

  defp get_character_recent_kills(_character_id), do: 0
  defp get_character_gang_activity(_character_id), do: 0.0
  defp get_corporation_member_count(_corp_id), do: 0
  defp get_corporation_recent_activity(_corp_id), do: 0.0
  defp calculate_kill_efficiency(_entity_id), do: 0.0
  defp calculate_survival_rate(_entity_id), do: 0.0
  defp calculate_isk_efficiency(_entity_id), do: 0.0
  defp calculate_fleet_participation(_entity_id), do: 0.0
  defp calculate_member_effectiveness(_corp_id), do: 0.0
  defp calculate_fleet_coordination(_corp_id), do: 0.0
  defp calculate_strategic_impact(_corp_id), do: 0.0
  defp count_killmails_involved(_entity_id, _type, _range), do: 0
  defp count_active_systems(_entity_id, _type, _range), do: 0
  defp get_peak_activity_hours(_entity_id, _type, _range), do: []
  defp get_alliance_interactions(_entity_id, _type, _range), do: []
  defp get_character_ship_preferences(_character_id), do: %{}
  defp get_corporation_ship_preferences(_corp_id), do: %{}
  defp get_preferred_engagement_types(_entity_id, _type), do: []
  defp identify_tactical_roles(_entity_id, _type), do: []
  defp analyze_coordination_patterns(_entity_id, _type), do: %{}
  defp generate_character_recommendations(_effectiveness), do: []
  defp generate_corporation_recommendations(_effectiveness), do: []
  defp get_character_kill_stats(_character_id, _range), do: %{}
  defp get_character_ship_usage(_character_id, _range), do: %{}
  defp get_character_combat_patterns(_character_id, _range), do: %{}
  defp calculate_character_effectiveness(_character_id, _range), do: %{}
  defp calculate_character_threat_score(_character_id, _range), do: 0.0
  defp analyze_character_behavior(_character_id, _range), do: %{}
  defp calculate_threat_score(_entity_id, _type), do: 0.0
  defp identify_risk_factors(_entity_id, _type), do: []
  defp get_behavioral_indicators(_entity_id, _type), do: []
  defp calculate_confidence_score(_entity_id, _type), do: 0.0
  defp generate_threat_recommendations(_entity_id, _type), do: []
end
