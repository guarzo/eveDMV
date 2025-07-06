defmodule EveDmv.Contexts.KillmailProcessing do
  @moduledoc """
  Killmail Processing bounded context.

  Responsible for:
  - Real-time ingestion of killmail data from external feeds
  - Data validation and enrichment with ISK values and metadata
  - Storage of raw and enriched killmail data
  - Publishing domain events for other contexts

  This context is the foundation of the EVE DMV system, providing the
  core data that all other contexts depend on for analysis.
  """

  use EveDmv.Contexts.BoundedContext, name: :killmail_processing
  use Supervisor

  alias EveDmv.Contexts.KillmailProcessing.{Api, Domain, Infrastructure}
  # alias EveDmv.DomainEvents

  # Supervisor implementation

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Supervisor
  def init(_opts) do
    children =
      [
        # Domain services
        Domain.KillmailOrchestrator,
        Domain.EnrichmentService,
        Domain.ValidationService,

        # Infrastructure - only start if pipeline is enabled
        maybe_start_pipeline_infrastructure()
      ]
      |> List.flatten()
      |> Enum.reject(&is_nil/1)

    Supervisor.init(children, strategy: :one_for_one)
  end

  # Event subscriptions - this context doesn't subscribe to external events
  @impl EveDmv.Contexts.BoundedContext
  def event_subscriptions, do: []

  # Public API delegation
  defdelegate ingest_killmail(raw_killmail), to: Api
  defdelegate get_recent_killmails(opts), to: Api
  defdelegate get_killmail_by_id(killmail_id), to: Api
  defdelegate get_killmails_by_system(system_id, opts), to: Api
  defdelegate get_killmails_by_character(character_id, opts), to: Api
  defdelegate get_high_value_killmails(opts), to: Api
  defdelegate fetch_historical_killmails(character_ids, opts), to: Api
  defdelegate get_system_statistics(system_id, time_range), to: Api

  # Internal pipeline management
  def start_pipeline do
    Domain.KillmailOrchestrator.start_pipeline()
  end

  def stop_pipeline do
    Domain.KillmailOrchestrator.stop_pipeline()
  end

  def pipeline_status do
    Domain.KillmailOrchestrator.pipeline_status()
  end

  def get_pipeline_metrics do
    Domain.KillmailOrchestrator.get_metrics()
  end

  # Private helpers

  defp maybe_start_pipeline_infrastructure do
    if Application.get_env(:eve_dmv, :pipeline_enabled, false) do
      [
        # Broadway pipeline
        Infrastructure.KillmailPipeline,

        # Historical fetcher
        Infrastructure.HistoricalFetcher,

        # Display service for UI integration
        Infrastructure.DisplayService
      ]
    else
      []
    end
  end
end
