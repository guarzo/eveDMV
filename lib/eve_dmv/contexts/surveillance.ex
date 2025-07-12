defmodule EveDmv.Contexts.Surveillance do
  @moduledoc """
  Surveillance bounded context.

  Responsible for:
  - Real-time surveillance profile matching against killmail data
  - Alert generation and notification management
  - Profile management and criteria definition
  - Match history and analytics

  This context consumes killmail events and produces surveillance
  alerts when matches are found against configured profiles.
  """

  use EveDmv.Contexts.BoundedContext, name: :surveillance
  use Supervisor

  alias EveDmv.Contexts.Surveillance.Api
  alias EveDmv.Contexts.Surveillance.Domain
  alias EveDmv.Contexts.Surveillance.Infrastructure
  alias EveDmv.DomainEvents.KillmailReceived

  # Supervisor implementation

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Supervisor
  def init(_opts) do
    children = [
      # Domain services
      Domain.MatchingEngine,
      Domain.ProfileManager,
      Domain.AlertService,
      Domain.NotificationService,

      # Infrastructure
      Infrastructure.ProfileRepository,
      Infrastructure.MatchCache,
      Infrastructure.NotificationDispatcher,

      # Event processors
      Infrastructure.KillmailEventProcessor
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  # Event subscriptions
  @impl EveDmv.Contexts.BoundedContext
  def event_subscriptions do
    [
      {:killmail_received, &handle_killmail_received/1}
    ]
  end

  # Event handlers
  def handle_killmail_received(%KillmailReceived{} = event) do
    # Process killmail for surveillance matching as soon as it's received
    # This allows for real-time alerting
    Infrastructure.KillmailEventProcessor.process_killmail_for_surveillance(event)
  end

  # Public API delegation
  defdelegate create_profile(profile_data), to: Api
  defdelegate update_profile(profile_id, updates), to: Api
  defdelegate delete_profile(profile_id), to: Api
  defdelegate get_profile(profile_id), to: Api
  defdelegate list_profiles(opts), to: Api
  defdelegate enable_profile(profile_id), to: Api
  defdelegate disable_profile(profile_id), to: Api

  defdelegate get_recent_matches(opts), to: Api
  defdelegate get_matches_for_profile(profile_id, opts), to: Api
  defdelegate get_match_details(match_id), to: Api
  defdelegate get_match_statistics(profile_id, time_range), to: Api

  defdelegate test_profile_criteria(profile_id, test_data), to: Api
  defdelegate validate_profile_criteria(criteria), to: Api

  defdelegate configure_notifications(profile_id, notification_config), to: Api
  defdelegate get_notification_history(profile_id, opts), to: Api
  defdelegate test_notification_delivery(profile_id), to: Api

  # Context-specific utilities
  def force_profile_matching(killmail_data) do
    Domain.MatchingEngine.force_match_all_profiles(killmail_data)
  end

  def get_surveillance_metrics do
    case Domain.MatchingEngine.get_metrics() do
      {:ok, metrics} ->
        # Add system-level metrics
        system_metrics = %{
          avg_response_time_ms: Map.get(metrics, :average_processing_time_ms, 0),
          system_load_percent: get_system_load_percent(),
          cache_hit_rate: get_cache_hit_rate()
        }

        {:ok, Map.merge(metrics, system_metrics)}

      error ->
        error
    end
  end

  defp get_system_load_percent do
    # Simulate system load calculation
    # In production, this would check actual CPU/memory usage
    # 10-30% load
    :rand.uniform(20) + 10
  end

  defp get_cache_hit_rate do
    case Domain.MatchingEngine.get_cache_stats() do
      {:ok, stats} -> Map.get(stats, :hit_rate, 0.0)
      {:error, _} -> 0.0
    end
  end

  def refresh_profile_cache do
    Infrastructure.ProfileRepository.refresh_cache()
  end
end
