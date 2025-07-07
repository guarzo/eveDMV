defmodule EveDmv.Contexts.FleetOperations do
  @moduledoc """
  Fleet Operations bounded context.

  Responsible for:
  - Fleet composition analysis and optimization
  - Fleet effectiveness tracking and metrics
  - Doctrine compliance monitoring
  - Fleet event processing and historical analysis
  - Mass analysis for wormhole operations
  - Fleet performance insights and recommendations

  This context consumes killmail events to analyze fleet engagements
  and provides insights for fleet commanders and doctrine planners.
  """

  use EveDmv.Contexts.BoundedContext, name: :fleet_operations
  use Supervisor

    alias EveDmv.Contexts.FleetOperations.Api
  alias EveDmv.Contexts.FleetOperations.Domain
  alias EveDmv.Contexts.FleetOperations.Infrastructure
  alias EveDmv.DomainEvents.KillmailEnriched

  # Supervisor implementation

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Domain services
      Domain.FleetAnalyzer,
      Domain.DoctrineManager,
      Domain.EffectivenessCalculator,
      Domain.FleetEventProcessor,

      # Infrastructure
      Infrastructure.FleetRepository,
      Infrastructure.EngagementCache,
      Infrastructure.MetricsAggregator,

      # Event processors
      Infrastructure.KillmailFleetProcessor
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  # Event subscriptions
  @impl true
  def event_subscriptions do
    [
      {:killmail_enriched, &handle_killmail_enriched/1}
    ]
  end

  # Event handlers
  def handle_killmail_enriched(%KillmailEnriched{} = event) do
    # Analyze killmail for fleet engagement patterns
    Infrastructure.KillmailFleetProcessor.process_for_fleet_analysis(event)
  end

  # Public API delegation
  defdelegate analyze_fleet_composition(fleet_data), to: Api
  defdelegate analyze_fleet_engagement(engagement_data), to: Api
  defdelegate get_fleet_statistics(fleet_id, time_range), to: Api
  defdelegate get_doctrine_compliance(fleet_data, doctrine_name), to: Api
  defdelegate get_fleet_effectiveness_metrics(fleet_id), to: Api

  defdelegate create_doctrine(doctrine_data), to: Api
  defdelegate update_doctrine(doctrine_id, updates), to: Api
  defdelegate get_doctrine(doctrine_id), to: Api
  defdelegate list_doctrines(opts), to: Api
  defdelegate validate_fleet_against_doctrine(fleet_data, doctrine_id), to: Api

  defdelegate get_fleet_engagements(opts), to: Api
  defdelegate get_engagement_details(engagement_id), to: Api
  defdelegate get_fleet_performance_trends(corporation_id, time_range), to: Api
  defdelegate get_mass_analysis(fleet_data), to: Api

  defdelegate recommend_fleet_improvements(fleet_data), to: Api
  defdelegate get_optimal_fleet_composition(doctrine_id, pilot_count), to: Api
  defdelegate analyze_fleet_losses(fleet_data), to: Api

  # Context-specific utilities
  def force_reanalyze_engagement(engagement_id) do
    Domain.FleetAnalyzer.force_reanalyze_engagement(engagement_id)
  end

  def get_fleet_operations_metrics do
    Domain.FleetAnalyzer.get_metrics()
  end

  def refresh_doctrine_cache do
    Infrastructure.FleetRepository.refresh_doctrine_cache()
  end

  def calculate_wormhole_mass_limits(fleet_data) do
    Domain.FleetAnalyzer.calculate_wormhole_mass_limits(fleet_data)
  end
end
