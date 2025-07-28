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

  alias EveDmv.Contexts.CombatAnalysis.Api
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
end
