defmodule EveDmv.Contexts.CombatAnalysis do
  @moduledoc """
  Unified Combat Analysis bounded context.

  Consolidates functionality from CombatIntelligence, BattleSharing, and BattleAnalysis.

  Responsible for:
  - Real-time combat intelligence and threat assessment
  - Battle detection, analysis, and reconstruction
  - Combat effectiveness metrics and analytics
  - Battle sharing and community curation
  - Fleet composition and tactical analysis
  - Character and corporation combat analysis

  This unified context provides comprehensive combat analysis capabilities
  while maintaining clean boundaries and avoiding duplication.
  """

  use EveDmv.Contexts.BoundedContext, name: :combat_analysis
  use Supervisor

  alias EveDmv.Contexts.CombatAnalysis.Domain
  alias EveDmv.Shared.Infrastructure.{UnifiedCache, UnifiedEventProcessor}
  alias EveDmv.DomainEvents.KillmailEnriched

  # Supervisor implementation

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Supervisor
  def init(_opts) do
    children = [
      # Domain services (unified combat analysis)
      Domain.BattleDetectionService,
      Domain.CombatIntelligenceEngine,
      Domain.BattleAnalysisCoordinator,
      Domain.BattleSharingService,
      Domain.FleetAnalysisEngine,
      Domain.CharacterAnalysisEngine
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  # Event subscriptions
  @impl EveDmv.Contexts.BoundedContext
  def event_subscriptions do
    [
      {:killmail_enriched, &handle_killmail_enriched/1},
      {:battle_detected, &handle_battle_detected/1},
      {:static_data_updated, &handle_static_data_updated/1}
    ]
  end

  ## Public API - Battle Analysis

  @doc """
  Analyze a battle from killmail data.
  """
  def analyze_battle(battle_data, options \\ []) do
    Domain.BattleAnalysisCoordinator.analyze_battle(battle_data, options)
  end

  @doc """
  Get battle timeline and phases.
  """
  def get_battle_timeline(battle_id) do
    Domain.BattleAnalysisCoordinator.get_battle_timeline(battle_id)
  end

  @doc """
  Get fleet composition analysis.
  """
  def analyze_fleet_composition(participants) do
    Domain.FleetAnalysisEngine.analyze_composition(participants)
  end

  ## Public API - Combat Intelligence

  @doc """
  Analyze character combat patterns.
  """
  def analyze_character_combat(character_id, options \\ []) do
    Domain.CharacterAnalysisEngine.analyze_combat_patterns(character_id, options)
  end

  @doc """
  Assess threat level for character or corporation.
  """
  def assess_threat(entity_id, entity_type, options \\ []) do
    Domain.ThreatAssessmentEngine.assess_threat(entity_id, entity_type, options)
  end

  @doc """
  Get combat intelligence summary.
  """
  def get_combat_intelligence(entity_id, options \\ []) do
    Domain.CombatIntelligenceEngine.get_intelligence_summary(entity_id, options)
  end

  ## Public API - Battle Sharing

  @doc """
  Create a shareable battle report.
  """
  def create_battle_report(battle_id, creator_id, options \\ []) do
    Domain.BattleSharingService.create_battle_report(battle_id, creator_id, options)
  end

  @doc """
  Rate a battle report.
  """
  def rate_battle_report(report_id, user_id, rating) do
    Domain.BattleSharingService.rate_battle_report(report_id, user_id, rating)
  end

  @doc """
  Import battle data from zKillboard URL.
  """
  def import_from_zkillboard(url) do
    # Parse the URL to extract relevant IDs
    case parse_zkillboard_url(url) do
      {:ok, params} ->
        fetch_zkillboard_data(params)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Create battle report from raw data.
  """
  def create_battle_report_from_data(battle_data, creator_id, options \\ []) do
    # Validate and create battle report
    with {:ok, validated_data} <- validate_battle_data(battle_data),
         {:ok, battle} <- Domain.BattleDetectionService.create_battle_from_data(validated_data) do
      create_battle_report(battle.id, creator_id, options)
    end
  end

  @doc """
  Detect recent battles based on criteria.
  """
  def detect_recent_battles(hours_back, options \\ []) do
    Domain.BattleDetectionService.detect_recent_battles(hours_back, options)
  end

  @doc """
  Reconstruct battle timeline from battle data.
  """
  def reconstruct_battle_timeline(battle) do
    Domain.BattleAnalysisCoordinator.reconstruct_timeline(battle)
  end

  @doc """
  Analyze battle with full intelligence integration.
  """
  def analyze_battle_with_intelligence(battle) do
    # Comprehensive analysis with all intelligence sources
    with {:ok, timeline} <- get_battle_timeline(battle.id),
         {:ok, analysis} <- analyze_battle(battle),
         {:ok, intelligence} <- gather_battle_intelligence(battle) do
      {:ok,
       %{
         battle: battle,
         timeline: timeline,
         analysis: analysis,
         intelligence: intelligence
       }}
    end
  end

  @doc """
  Get battle with timeline data.
  """
  def get_battle_with_timeline(battle_id) do
    with {:ok, battle} <- Domain.BattleDetectionService.get_battle(battle_id),
         {:ok, timeline} <- get_battle_timeline(battle_id) do
      {:ok, Map.put(battle, :timeline, timeline)}
    end
  end

  @doc """
  Get all reports for a specific battle.
  """
  def get_reports_for_battle(battle_id) do
    Domain.BattleSharingService.get_battle_reports(battle_id)
  end

  ## Event Handlers

  defp handle_killmail_enriched(%KillmailEnriched{} = event) do
    # Process killmail for all analysis types
    UnifiedEventProcessor.process_killmail_for_combat_intelligence(event)

    # Trigger battle detection
    Domain.BattleDetectionService.process_killmail(event)

    # Update character combat patterns
    Domain.CharacterAnalysisEngine.process_killmail(event)

    # Update threat assessments
    Domain.ThreatAssessmentEngine.process_killmail(event)
  end

  defp handle_battle_detected(event) do
    # Analyze the detected battle
    Domain.BattleAnalysisCoordinator.analyze_detected_battle(event.battle_id)

    # Check if battle is worth sharing
    Domain.BattleSharingService.evaluate_battle_for_sharing(event.battle_id)
  end

  defp handle_static_data_updated(event) do
    # Update cached ship and system data used in analysis
    Domain.CombatIntelligenceEngine.update_static_data(event)
  end

  ## Cache Management

  @doc """
  Get combat analysis cache statistics.
  """
  def get_cache_stats() do
    UnifiedCache.get_domain_stats(:combat)
  end

  @doc """
  Clear combat analysis cache.
  """
  def clear_cache() do
    UnifiedCache.invalidate_domain(:combat)
  end

  ## Health Check

  @doc """
  Perform health check on combat analysis services.
  """
  def health_check() do
    services = [
      Domain.BattleDetectionService,
      Domain.CombatIntelligenceEngine,
      Domain.BattleAnalysisCoordinator,
      Domain.ThreatAssessmentEngine
    ]

    results =
      Enum.map(services, fn service ->
        try do
          case GenServer.call(service, :health_check, 5_000) do
            :ok -> {service, :healthy}
            error -> {service, {:unhealthy, error}}
          end
        rescue
          _ -> {service, {:unhealthy, :timeout}}
        end
      end)

    unhealthy =
      Enum.filter(results, fn {_service, status} ->
        status != :healthy
      end)

    if Enum.empty?(unhealthy) do
      :ok
    else
      {:error, {:unhealthy_services, unhealthy}}
    end
  end

  # Private helper functions

  defp parse_zkillboard_url(url) do
    # Parse zKillboard URL format
    # Examples: 
    # https://zkillboard.com/kill/123456/
    # https://zkillboard.com/related/30002537/202301011200/

    cond do
      String.contains?(url, "/kill/") ->
        case Regex.run(~r/\/kill\/(\d+)/, url) do
          [_, kill_id] -> {:ok, %{type: :single_kill, kill_id: String.to_integer(kill_id)}}
          _ -> {:error, "Invalid kill URL format"}
        end

      String.contains?(url, "/related/") ->
        case Regex.run(~r/\/related\/(\d+)\/(\d+)/, url) do
          [_, system_id, timestamp] ->
            {:ok,
             %{type: :related, system_id: String.to_integer(system_id), timestamp: timestamp}}

          _ ->
            {:error, "Invalid related kills URL format"}
        end

      true ->
        {:error, "Unsupported zKillboard URL format"}
    end
  end

  defp fetch_zkillboard_data(%{type: :single_kill, kill_id: _kill_id}) do
    # Would fetch data from zKillboard API
    # For now, return error as we shouldn't make external API calls
    {:error, "zKillboard API integration not implemented"}
  end

  defp fetch_zkillboard_data(%{type: :related, system_id: _system_id, timestamp: _timestamp}) do
    # Would fetch related kills from zKillboard API
    {:error, "zKillboard API integration not implemented"}
  end

  defp validate_battle_data(battle_data) do
    required_fields = [:killmail_ids, :start_time, :end_time]

    missing_fields = Enum.filter(required_fields, &(not Map.has_key?(battle_data, &1)))

    if Enum.empty?(missing_fields) do
      {:ok, battle_data}
    else
      {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
    end
  end

  defp gather_battle_intelligence(battle) do
    # Gather intelligence about battle participants
    participants = extract_participants(battle)

    intelligence = %{
      participant_count: length(participants),
      corporations_involved: count_unique_corporations(participants),
      alliances_involved: count_unique_alliances(participants),
      threat_levels: assess_participant_threats(participants),
      known_fcs: identify_known_fcs(participants)
    }

    {:ok, intelligence}
  end

  defp extract_participants(_battle) do
    # Extract unique participants from battle
    # This would query actual killmail data
    []
  end

  defp count_unique_corporations(participants) do
    participants
    |> Enum.map(& &1[:corporation_id])
    |> Enum.uniq()
    |> length()
  end

  defp count_unique_alliances(participants) do
    participants
    |> Enum.map(& &1[:alliance_id])
    |> Enum.filter(&(&1 != nil))
    |> Enum.uniq()
    |> length()
  end

  defp assess_participant_threats(_participants) do
    # Would assess threat levels of key participants
    %{
      high_threat_count: 0,
      average_threat_score: 0
    }
  end

  defp identify_known_fcs(_participants) do
    # Would identify known fleet commanders
    []
  end
end
