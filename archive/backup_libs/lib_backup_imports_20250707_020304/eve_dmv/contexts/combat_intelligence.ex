defmodule EveDmv.Contexts.CombatIntelligence do
  use EveDmv.Contexts.BoundedContext, name: :combat_intelligence
  use Supervisor

    alias EveDmv.Contexts.CombatIntelligence.Api
    alias EveDmv.DomainEvents.KillmailEnriched
  alias EveDmv.Contexts.CombatIntelligence.Domain
  alias EveDmv.Contexts.CombatIntelligence.Infrastructure
  alias EveDmv.DomainEvents.StaticDataUpdated
  @moduledoc """
  Combat Intelligence bounded context.

  Responsible for:
  - Character tactical analysis and threat assessment
  - Corporation activity patterns and metrics
  - Intelligence scoring and recommendation generation
  - Combat effectiveness analysis
  - Pilot behavioral pattern recognition

  This context consumes killmail events and produces intelligence
  analysis for tactical decision-making in EVE Online.
  """



  # Supervisor implementation

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Domain services
      Domain.CharacterAnalyzer,
      Domain.CorporationAnalyzer,
      Domain.ThreatAssessor,
      Domain.IntelligenceScoring,

      # Infrastructure
      Infrastructure.AnalysisCache,
      Infrastructure.IntelligenceRepository,

      # Event processors
      Infrastructure.KillmailEventProcessor,
      Infrastructure.StaticDataEventProcessor
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  # Event subscriptions
  @impl true
  def event_subscriptions do
    [
      {:killmail_enriched, &handle_killmail_enriched/1},
      {:static_data_updated, &handle_static_data_updated/1}
    ]
  end

  # Event handlers
  def handle_killmail_enriched(%KillmailEnriched{} = event) do
    Infrastructure.KillmailEventProcessor.process_killmail_event(event)
  end

  def handle_static_data_updated(%StaticDataUpdated{categories_updated: categories}) do
    if :item_types in categories or :ship_types in categories do
      Infrastructure.StaticDataEventProcessor.refresh_ship_data()
    end
  end

  # Public API delegation
  defdelegate analyze_character(character_id, opts), to: Api
  defdelegate get_character_intelligence(character_id), to: Api
  defdelegate analyze_corporation(corporation_id, opts), to: Api
  defdelegate get_corporation_intelligence(corporation_id), to: Api
  defdelegate assess_threat(character_id, context), to: Api
  defdelegate get_threat_assessment(character_id), to: Api
  defdelegate calculate_intelligence_score(character_id, scoring_type), to: Api
  defdelegate get_character_recommendations(character_id), to: Api
  defdelegate search_characters_by_criteria(criteria), to: Api
  defdelegate get_activity_patterns(character_id, time_range), to: Api
  defdelegate compare_characters(character_ids), to: Api
  defdelegate get_intelligence_cache_stats(), to: Api

  # Context-specific utilities
  def refresh_character_analysis(character_id) do
    Domain.CharacterAnalyzer.refresh_analysis(character_id)
  end

  def bulk_analyze_characters(character_ids, opts \\ []) do
    Domain.CharacterAnalyzer.bulk_analyze(character_ids, opts)
  end

  def invalidate_intelligence_cache(character_id) do
    Infrastructure.AnalysisCache.invalidate_character(character_id)
  end
end
