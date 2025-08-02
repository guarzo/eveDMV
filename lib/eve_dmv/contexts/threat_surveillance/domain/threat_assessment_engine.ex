defmodule EveDmv.Contexts.ThreatSurveillance.Domain.ThreatAssessmentEngine do
  @moduledoc """
  Core engine for threat assessment and scoring.

  Provides comprehensive threat analysis for characters and corporations
  including behavioral analysis, risk assessment, and threat scoring.
  """

  use GenServer

  alias EveDmv.DomainEvents.KillmailEnriched
  alias EveDmv.Shared.Infrastructure.UnifiedCache

  require Logger

  # Threat scoring weights
  @threat_weights %{
    recent_kills: 0.25,
    gang_activity: 0.20,
    ship_value: 0.15,
    system_activity: 0.15,
    alliance_affiliation: 0.10,
    behavioral_patterns: 0.15
  }

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Assess threat level for a character.
  """
  def assess_character_threat(character_id, options \\ []) do
    GenServer.call(__MODULE__, {:assess_character_threat, character_id, options})
  end

  @doc """
  Assess threat level for a corporation.
  """
  def assess_corporation_threat(corp_id, options \\ []) do
    GenServer.call(__MODULE__, {:assess_corporation_threat, corp_id, options})
  end

  @doc """
  Update threat assessment based on new intelligence.
  """
  def update_assessment(entity_id, entity_type, intelligence_data) do
    GenServer.call(__MODULE__, {:update_assessment, entity_id, entity_type, intelligence_data})
  end

  @doc """
  Assess threat level for any entity type.
  """
  def assess_threat_level(entity_id, :character) do
    assess_character_threat(entity_id)
  end

  def assess_threat_level(entity_id, :corporation) do
    assess_corporation_threat(entity_id)
  end

  @doc """
  Get threat assessment metrics.
  """
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  @doc """
  Process killmail for threat assessment updates.
  """
  def process_killmail(%KillmailEnriched{} = killmail) do
    GenServer.cast(__MODULE__, {:process_killmail, killmail})
  end

  @doc """
  Process surveillance match for threat updates.
  """
  def process_surveillance_match(match_event) do
    GenServer.cast(__MODULE__, {:process_surveillance_match, match_event})
  end

  # GenServer implementation

  @impl GenServer
  def init(_opts) do
    state = %{
      processed_killmails: 0,
      assessments_generated: 0,
      threat_cache: %{}
    }

    Logger.info("ThreatAssessmentEngine started")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:assess_character_threat, character_id, options}, _from, state) do
    case perform_character_threat_assessment(character_id, options) do
      {:ok, assessment} ->
        # Cache the assessment
        _cache_key = {:character_threat, character_id}
        # 10 minutes
        UnifiedCache.cache_threat_assessment(character_id, assessment, 600)

        {:reply, {:ok, assessment},
         %{state | assessments_generated: state.assessments_generated + 1}}

      error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:assess_corporation_threat, corp_id, options}, _from, state) do
    case perform_corporation_threat_assessment(corp_id, options) do
      {:ok, assessment} ->
        # Cache the assessment
        cache_key = {:corporation_threat, corp_id}
        # 15 minutes
        UnifiedCache.put(:threat, cache_key, assessment, 900)

        {:reply, {:ok, assessment},
         %{state | assessments_generated: state.assessments_generated + 1}}

      error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:update_assessment, entity_id, entity_type, intelligence_data}, _from, state) do
    case update_threat_assessment(entity_id, entity_type, intelligence_data) do
      {:ok, updated_assessment} ->
        # Invalidate cache to force refresh
        cache_key = {safe_entity_type_atom(entity_type), entity_id}
        UnifiedCache.delete(:threat, cache_key)

        {:reply, {:ok, updated_assessment}, state}

      error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call(:get_metrics, _from, state) do
    metrics = %{
      processed_killmails: state.processed_killmails,
      assessments_generated: state.assessments_generated,
      cache_size: map_size(state.threat_cache)
    }

    {:reply, metrics, state}
  end

  @impl GenServer
  def handle_call(:health_check, _from, state) do
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_cast({:process_killmail, killmail}, state) do
    # Update threat assessments for all involved entities
    update_threat_from_killmail(killmail)

    {:noreply, %{state | processed_killmails: state.processed_killmails + 1}}
  rescue
    error ->
      Logger.error("Failed to process killmail for threat assessment: #{inspect(error)}")
      {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:process_surveillance_match, match_event}, state) do
    # Increase threat scores for entities involved in surveillance matches
    update_threat_from_surveillance_match(match_event)

    {:noreply, state}
  rescue
    error ->
      Logger.error(
        "Failed to process surveillance match for threat assessment: #{inspect(error)}"
      )

      {:noreply, state}
  end

  # Private functions

  defp perform_character_threat_assessment(character_id, options) do
    time_range = Keyword.get(options, :time_range, :last_30_days)

    assessment = %{
      character_id: character_id,
      assessed_at: DateTime.utc_now(),
      time_range: time_range,
      threat_score: calculate_character_threat_score(character_id, time_range),
      threat_level: calculate_character_threat_level(character_id, time_range),
      risk_factors: identify_character_risk_factors(character_id, time_range),
      behavioral_analysis: analyze_character_behavior(character_id, time_range),
      activity_patterns: get_character_activity_patterns(character_id, time_range),
      alliance_threat_modifier: get_alliance_threat_modifier(character_id),
      recommendations: generate_character_threat_recommendations(character_id, time_range)
    }

    {:ok, assessment}
  rescue
    error ->
      Logger.error("Failed to assess character threat: #{inspect(error)}")
      {:error, :assessment_failed}
  end

  defp perform_corporation_threat_assessment(corp_id, options) do
    time_range = Keyword.get(options, :time_range, :last_30_days)

    assessment = %{
      corporation_id: corp_id,
      assessed_at: DateTime.utc_now(),
      time_range: time_range,
      threat_score: calculate_corporation_threat_score(corp_id, time_range),
      threat_level: calculate_corporation_threat_level(corp_id, time_range),
      member_threat_distribution: get_member_threat_distribution(corp_id),
      activity_metrics: get_corporation_activity_metrics(corp_id, time_range),
      fleet_capabilities: assess_fleet_capabilities(corp_id),
      territorial_influence: assess_territorial_influence(corp_id),
      alliance_relationships: get_alliance_relationships(corp_id),
      recommendations: generate_corporation_threat_recommendations(corp_id, time_range)
    }

    {:ok, assessment}
  rescue
    error ->
      Logger.error("Failed to assess corporation threat: #{inspect(error)}")
      {:error, :assessment_failed}
  end

  defp update_threat_assessment(entity_id, entity_type, intelligence_data) do
    # Update threat assessment with new intelligence
    current_assessment = get_current_assessment(entity_id, entity_type)

    updated_assessment = %{
      current_assessment
      | last_updated: DateTime.utc_now(),
        intelligence_sources: [intelligence_data | current_assessment.intelligence_sources || []],
        threat_score: recalculate_threat_score(current_assessment, intelligence_data)
    }

    {:ok, updated_assessment}
  end

  defp calculate_character_threat_score(character_id, time_range) do
    # Gather threat indicators
    recent_kills = get_character_recent_kills(character_id, time_range)
    gang_activity = get_character_gang_activity(character_id, time_range)
    ship_value_usage = get_character_ship_value_usage(character_id, time_range)
    system_activity = get_character_system_activity(character_id, time_range)
    alliance_modifier = get_alliance_threat_modifier(character_id)
    behavioral_score = get_character_behavioral_score(character_id, time_range)

    # Calculate weighted threat score
    threat_score =
      recent_kills * @threat_weights.recent_kills +
        gang_activity * @threat_weights.gang_activity +
        ship_value_usage * @threat_weights.ship_value +
        system_activity * @threat_weights.system_activity +
        alliance_modifier * @threat_weights.alliance_affiliation +
        behavioral_score * @threat_weights.behavioral_patterns

    # Normalize to 0-100 scale
    min(100.0, max(0.0, threat_score * 100))
  end

  defp calculate_character_threat_level(character_id, time_range) do
    threat_score = calculate_character_threat_score(character_id, time_range)

    cond do
      threat_score >= 80 -> :critical
      threat_score >= 60 -> :high
      threat_score >= 40 -> :medium
      threat_score >= 20 -> :low
      true -> :minimal
    end
  end

  defp calculate_corporation_threat_score(corp_id, time_range) do
    # Corporation threat is based on member activity and coordination
    member_count = get_corporation_member_count(corp_id)
    active_members = get_active_member_count(corp_id, time_range)
    fleet_activity = get_corporation_fleet_activity(corp_id, time_range)
    territorial_control = get_territorial_control_score(corp_id)
    alliance_strength = get_alliance_strength_modifier(corp_id)

    # Calculate corporation threat score
    base_score =
      active_members / max(1, member_count) * 0.3 +
        fleet_activity * 0.3 +
        territorial_control * 0.2 +
        alliance_strength * 0.2

    # Scale based on corporation size
    size_modifier =
      cond do
        member_count > 1000 -> 1.5
        member_count > 500 -> 1.3
        member_count > 100 -> 1.1
        true -> 1.0
      end

    min(100.0, max(0.0, base_score * size_modifier * 100))
  end

  defp calculate_corporation_threat_level(corp_id, time_range) do
    threat_score = calculate_corporation_threat_score(corp_id, time_range)

    cond do
      threat_score >= 85 -> :critical
      threat_score >= 65 -> :high
      threat_score >= 45 -> :medium
      threat_score >= 25 -> :low
      true -> :minimal
    end
  end

  defp update_threat_from_killmail(killmail) do
    # Update threat assessments for all involved entities
    victim_character_id = get_in(killmail.victim, [:character_id])
    victim_corp_id = get_in(killmail.victim, [:corporation_id])

    if victim_character_id do
      invalidate_character_threat_cache(victim_character_id)
    end

    if victim_corp_id do
      invalidate_corporation_threat_cache(victim_corp_id)
    end

    # Update for attackers
    Enum.each(killmail.attackers, fn attacker ->
      if character_id = attacker[:character_id] do
        invalidate_character_threat_cache(character_id)
      end

      if corp_id = attacker[:corporation_id] do
        invalidate_corporation_threat_cache(corp_id)
      end
    end)
  end

  defp update_threat_from_surveillance_match(match_event) do
    # Increase threat scores for entities involved in surveillance matches
    character_id = match_event[:character_id]
    corp_id = match_event[:corporation_id]

    if character_id do
      invalidate_character_threat_cache(character_id)
    end

    if corp_id do
      invalidate_corporation_threat_cache(corp_id)
    end

    Logger.debug("Updated threat assessment from surveillance match: #{inspect(match_event)}")
  end

  defp invalidate_character_threat_cache(character_id) do
    UnifiedCache.delete(:threat, {:character_threat, character_id})
  end

  defp invalidate_corporation_threat_cache(corp_id) do
    UnifiedCache.delete(:threat, {:corporation_threat, corp_id})
  end

  # Helper functions (simplified implementations for now)

  defp identify_character_risk_factors(_character_id, _time_range) do
    ["High kill activity", "Gang participation", "Expensive ship usage"]
  end

  defp analyze_character_behavior(_character_id, _time_range) do
    %{
      aggression_level: :moderate,
      predictability: :low,
      coordination: :high,
      risk_taking: :moderate
    }
  end

  defp get_character_activity_patterns(_character_id, _time_range) do
    %{
      peak_hours: [18, 19, 20, 21],
      preferred_systems: [],
      engagement_types: ["Fleet", "Gang", "Solo"]
    }
  end

  defp generate_character_threat_recommendations(_character_id, _time_range) do
    [
      "Monitor closely during peak hours",
      "Exercise caution in engagements",
      "Consider alliance intelligence"
    ]
  end

  defp get_member_threat_distribution(_corp_id) do
    %{critical: 5, high: 15, medium: 30, low: 40, minimal: 10}
  end

  defp get_corporation_activity_metrics(_corp_id, _time_range) do
    %{fleet_ops: 25, member_activity: 0.65, systems_active: 12}
  end

  defp assess_fleet_capabilities(_corp_id) do
    %{doctrine_strength: :moderate, coordination: :good, experience: :veteran}
  end

  defp assess_territorial_influence(_corp_id) do
    %{controlled_systems: 5, influence_score: 0.45}
  end

  defp get_alliance_relationships(_corp_id) do
    %{allies: [], neutrals: [], hostiles: []}
  end

  defp generate_corporation_threat_recommendations(_corp_id, _time_range) do
    ["Monitor fleet movements", "Track territorial expansion", "Assess alliance relationships"]
  end

  defp get_current_assessment(entity_id, entity_type) do
    cache_key = {safe_entity_type_atom(entity_type), entity_id}

    case UnifiedCache.get(:threat, cache_key) do
      {:ok, assessment} -> assessment
      {:error, :not_found} -> %{intelligence_sources: []}
    end
  end

  defp recalculate_threat_score(current_assessment, _intelligence_data) do
    # Recalculate threat score with new intelligence
    current_assessment[:threat_score] || 0.0
  end

  # Placeholder implementations for data gathering functions
  defp get_character_recent_kills(_character_id, _time_range), do: 0.0
  defp get_character_gang_activity(_character_id, _time_range), do: 0.0
  defp get_character_ship_value_usage(_character_id, _time_range), do: 0.0
  defp get_character_system_activity(_character_id, _time_range), do: 0.0
  defp get_alliance_threat_modifier(_character_id), do: 0.0
  defp get_character_behavioral_score(_character_id, _time_range), do: 0.0
  defp get_corporation_member_count(_corp_id), do: 0
  defp get_active_member_count(_corp_id, _time_range), do: 0
  defp get_corporation_fleet_activity(_corp_id, _time_range), do: 0.0
  defp get_territorial_control_score(_corp_id), do: 0.0
  defp get_alliance_strength_modifier(_corp_id), do: 0.0

  # Helper function to safely convert entity type to cache key atom
  defp safe_entity_type_atom(:character), do: :character_threat
  defp safe_entity_type_atom(:corporation), do: :corporation_threat
  defp safe_entity_type_atom("character"), do: :character_threat
  defp safe_entity_type_atom("corporation"), do: :corporation_threat
  defp safe_entity_type_atom(_), do: :unknown_threat
end
