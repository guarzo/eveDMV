defmodule EveDmv.Contexts.WormholeOperations do
  @moduledoc """
  Wormhole Operations bounded context.

  Responsible for:
  - Wormhole recruitment and vetting analysis
  - Home defense assessment and monitoring
  - Wormhole mass optimization and fleet planning
  - J-space activity tracking and threat analysis
  - Operational security (OpSec) compliance monitoring
  - Chain mapping and intelligence coordination

  This context provides specialized intelligence for wormhole corporations,
  focusing on recruitment safety, home defense capabilities, and
  operational effectiveness in J-space environments.
  """

  use EveDmv.Contexts.BoundedContext, name: :wormhole_operations
  use Supervisor

    alias EveDmv.Contexts.WormholeOperations.Api
    alias EveDmv.DomainEvents.CharacterAnalyzed
  alias EveDmv.Contexts.WormholeOperations.Domain
  alias EveDmv.Contexts.WormholeOperations.Infrastructure
  alias EveDmv.DomainEvents.FleetAnalysisComplete
  alias EveDmv.DomainEvents.ThreatDetected

  # Supervisor implementation

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Supervisor
  def init(_opts) do
    children = [
      # Domain services
      Domain.RecruitmentVetter,
      Domain.HomeDefenseAnalyzer,
      Domain.MassOptimizer,
      Domain.OperationalSecurityMonitor,
      Domain.ChainIntelligenceService,

      # Infrastructure
      Infrastructure.VettingRepository,
      Infrastructure.DefenseMetricsCache,
      Infrastructure.WormholeDataProvider,

      # Event processors
      Infrastructure.WormholeEventProcessor
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  # Event subscriptions
  @impl EveDmv.Contexts.BoundedContext
  def event_subscriptions do
    [
      {:character_analyzed, &handle_character_analyzed/1},
      {:threat_detected, &handle_threat_detected/1},
      {:fleet_analysis_complete, &handle_fleet_analysis_complete/1}
    ]
  end

  # Event handlers
  def handle_character_analyzed(%CharacterAnalyzed{} = event) do
    # Process character for wormhole recruitment suitability
    Infrastructure.WormholeEventProcessor.process_character_for_wormhole_vetting(event)
  end

  def handle_threat_detected(%ThreatDetected{} = event) do
    # Analyze threat for home defense implications
    Infrastructure.WormholeEventProcessor.process_threat_for_home_defense(event)
  end

  def handle_fleet_analysis_complete(%FleetAnalysisComplete{} = event) do
    # Analyze fleet for wormhole mass and operational suitability
    Infrastructure.WormholeEventProcessor.process_fleet_for_wormhole_ops(event)
  end

  # Public API delegation

  # Recruitment and Vetting
  defdelegate vet_recruitment_candidate(character_id, vetting_criteria), to: Api
  defdelegate get_vetting_report(vetting_id), to: Api
  defdelegate get_recruitment_recommendations(character_id), to: Api
  defdelegate update_vetting_criteria(corporation_id, criteria), to: Api
  defdelegate get_vetting_statistics(corporation_id, time_range), to: Api

  # Home Defense Analysis
  defdelegate analyze_home_defense_capabilities(corporation_id), to: Api
  defdelegate get_defense_vulnerability_assessment(system_id), to: Api
  defdelegate calculate_defense_readiness_score(corporation_id), to: Api
  defdelegate get_defense_recommendations(corporation_id), to: Api
  defdelegate track_defense_metrics(corporation_id, time_range), to: Api

  # Mass Optimization
  defdelegate optimize_fleet_for_wormhole(fleet_data, wormhole_class), to: Api
  defdelegate calculate_mass_efficiency(fleet_data), to: Api
  defdelegate get_mass_optimization_suggestions(fleet_data, target_class), to: Api
  defdelegate validate_fleet_mass_limits(fleet_data, wormhole_constraints), to: Api

  # Operational Security
  defdelegate assess_opsec_compliance(corporation_id), to: Api
  defdelegate get_opsec_violations(corporation_id, time_range), to: Api
  defdelegate generate_opsec_recommendations(corporation_id), to: Api
  defdelegate monitor_opsec_metrics(corporation_id), to: Api

  # Chain Intelligence
  defdelegate analyze_chain_activity(chain_data), to: Api
  defdelegate get_chain_threat_assessment(chain_data), to: Api
  defdelegate optimize_chain_coverage(corporation_id, chain_data), to: Api
  defdelegate get_chain_intelligence_summary(corporation_id), to: Api

  # Context-specific utilities
  def force_revett_candidate(character_id) do
    Domain.RecruitmentVetter.force_revett_candidate(character_id)
  end

  def get_wormhole_operations_metrics do
    %{
      recruitment_vetter: Domain.RecruitmentVetter.get_metrics(),
      home_defense: Domain.HomeDefenseAnalyzer.get_metrics(),
      mass_optimizer: Domain.MassOptimizer.get_metrics(),
      opsec_monitor: Domain.OperationalSecurityMonitor.get_metrics()
    }
  end

  def refresh_wormhole_data_cache do
    Infrastructure.WormholeDataProvider.refresh_cache()
  end

  def calculate_system_strategic_value(system_id) do
    Domain.ChainIntelligenceService.calculate_system_strategic_value(system_id)
  end
end
