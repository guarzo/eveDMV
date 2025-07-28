defmodule EveDmv.Contexts.ThreatSurveillance do
  @moduledoc """
  Unified Threat Surveillance bounded context.

  Consolidates functionality from Surveillance and ThreatAssessment contexts.

  Responsible for:
  - Real-time surveillance profile matching against killmail data
  - Threat assessment and scoring for characters and corporations
  - Alert generation and notification management
  - Surveillance profile management and criteria definition
  - Behavioral pattern analysis for threat detection
  - Match history and threat analytics

  This unified context provides comprehensive threat detection and surveillance
  capabilities while eliminating overlap between threat assessment and surveillance.
  """

  use EveDmv.Contexts.BoundedContext, name: :threat_surveillance
  use Supervisor

  alias EveDmv.Contexts.ThreatSurveillance.Domain
  alias EveDmv.Shared.Infrastructure.{UnifiedCache, UnifiedRepository}
  alias EveDmv.DomainEvents.KillmailEnriched

  # Supervisor implementation

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Supervisor
  def init(_opts) do
    children = [
      # Domain services (unified threat surveillance)
      Domain.ThreatAssessmentEngine,
      Domain.SurveillanceMatchingEngine,
      Domain.AlertManagementService,
      Domain.NotificationService
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  # Event subscriptions
  @impl EveDmv.Contexts.BoundedContext
  def event_subscriptions do
    [
      {:killmail_enriched, &handle_killmail_enriched/1},
      {:surveillance_match, &handle_surveillance_match/1},
      {:threat_level_changed, &handle_threat_level_changed/1}
    ]
  end

  ## Public API - Threat Assessment

  @doc """
  Assess threat level for a character.
  """
  def assess_character_threat(character_id, options \\ []) do
    Domain.ThreatAssessmentEngine.assess_character_threat(character_id, options)
  end

  @doc """
  Assess threat level for a corporation.
  """
  def assess_corporation_threat(corp_id, options \\ []) do
    Domain.ThreatAssessmentEngine.assess_corporation_threat(corp_id, options)
  end

  @doc """
  Get comprehensive threat analysis.
  """
  def get_threat_analysis(entity_id, entity_type, options \\ []) do
    Domain.ThreatAnalysisService.get_comprehensive_analysis(entity_id, entity_type, options)
  end

  @doc """
  Update threat assessment based on new intelligence.
  """
  def update_threat_assessment(entity_id, entity_type, intelligence_data) do
    Domain.ThreatAssessmentEngine.update_assessment(entity_id, entity_type, intelligence_data)
  end

  ## Public API - Surveillance

  @doc """
  Create a surveillance profile.
  """
  def create_surveillance_profile(user_id, profile_data) do
    Domain.ProfileManagementService.create_profile(user_id, profile_data)
  end

  @doc """
  Update a surveillance profile.
  """
  def update_surveillance_profile(profile_id, updates) do
    Domain.ProfileManagementService.update_profile(profile_id, updates)
  end

  @doc """
  Test surveillance criteria against sample data.
  """
  def test_surveillance_criteria(criteria, sample_data) do
    Domain.SurveillanceMatchingEngine.test_criteria(criteria, sample_data)
  end

  @doc """
  Get recent surveillance matches.
  """
  def get_recent_matches(options \\ []) do
    Domain.SurveillanceMatchingEngine.get_recent_matches(options)
  end

  @doc """
  Get matches for a specific profile.
  """
  def get_profile_matches(profile_id, options \\ []) do
    Domain.SurveillanceMatchingEngine.get_profile_matches(profile_id, options)
  end

  ## Public API - Alerts and Notifications

  @doc """
  Configure alert settings for a user.
  """
  def configure_alerts(user_id, alert_settings) do
    Domain.AlertManagementService.configure_alerts(user_id, alert_settings)
  end

  @doc """
  Send notification for surveillance match.
  """
  def send_match_notification(match_data) do
    Domain.NotificationService.send_match_notification(match_data)
  end

  @doc """
  Send threat level alert.
  """
  def send_threat_alert(threat_data) do
    Domain.NotificationService.send_threat_alert(threat_data)
  end

  ## Public API - Behavioral Analysis

  @doc """
  Analyze behavioral patterns for threat detection.
  """
  def analyze_behavioral_patterns(entity_id, entity_type, options \\ []) do
    Domain.BehavioralPatternAnalyzer.analyze_patterns(entity_id, entity_type, options)
  end

  @doc """
  Detect anomalous behavior.
  """
  def detect_anomalous_behavior(entity_id, recent_activity) do
    Domain.BehavioralPatternAnalyzer.detect_anomalies(entity_id, recent_activity)
  end

  ## Event Handlers

  defp handle_killmail_enriched(%KillmailEnriched{} = event) do
    # Process killmail for surveillance matching
    Domain.SurveillanceMatchingEngine.process_killmail(event)

    # Update threat assessments based on killmail data
    Domain.ThreatAssessmentEngine.process_killmail(event)

    # Analyze behavioral patterns
    Domain.BehavioralPatternAnalyzer.process_killmail(event)
  end

  defp handle_surveillance_match(event) do
    # Generate alerts for surveillance matches
    Domain.AlertManagementService.process_surveillance_match(event)

    # Send notifications if configured
    Domain.NotificationService.process_surveillance_match(event)

    # Update threat assessments based on match
    Domain.ThreatAssessmentEngine.process_surveillance_match(event)
  end

  defp handle_threat_level_changed(event) do
    # Send threat level alerts
    Domain.AlertManagementService.process_threat_level_change(event)

    # Update surveillance profiles that depend on threat levels
    Domain.ProfileManagementService.update_threat_dependent_profiles(event)
  end

  @doc """
  List surveillance profiles with filters.
  """
  def list_profiles(filters \\ []) do
    UnifiedRepository.list_surveillance_profiles(filters)
  end

  @doc """
  Get a surveillance profile by ID.
  """
  def get_profile(profile_id) do
    UnifiedRepository.get_surveillance_profile(profile_id)
  end

  @doc """
  Get alert metrics for the surveillance system.
  """
  def get_alert_metrics(options \\ []) do
    Domain.AlertManagementService.get_metrics(options)
  end

  @doc """
  Get surveillance system metrics.
  """
  def get_surveillance_metrics() do
    %{
      matching_engine: Domain.SurveillanceMatchingEngine.get_metrics(),
      threat_assessment: Domain.ThreatAssessmentEngine.get_metrics(),
      alert_service: Domain.AlertManagementService.get_metrics()
    }
  end

  @doc """
  Get recent alerts.
  """
  def get_recent_alerts(options \\ []) do
    Domain.AlertManagementService.get_recent_alerts(options)
  end

  ## Repository Operations

  @doc """
  Get threat assessment by character ID.
  """
  def get_threat_assessment(character_id, options \\ []) do
    UnifiedRepository.get_threat_assessment(character_id, options)
  end

  @doc """
  Get surveillance profile by ID.
  """
  def get_surveillance_profile(profile_id, options \\ []) do
    UnifiedRepository.get_surveillance_profile(profile_id, options)
  end

  @doc """
  List active surveillance profiles.
  """
  def get_active_surveillance_profiles(options \\ []) do
    UnifiedRepository.get_active_surveillance_profiles(options)
  end

  @doc """
  List surveillance profiles by user.
  """
  def list_user_surveillance_profiles(user_id, options \\ []) do
    UnifiedRepository.list_surveillance_profiles_by_user(user_id, options)
  end

  ## Cache Management

  @doc """
  Get threat surveillance cache statistics.
  """
  def get_cache_stats() do
    %{
      threat_cache: UnifiedCache.get_domain_stats(:threat),
      surveillance_cache: UnifiedCache.get_domain_stats(:surveillance)
    }
  end

  @doc """
  Clear threat surveillance cache.
  """
  def clear_cache() do
    UnifiedCache.invalidate_domain(:threat)
    UnifiedCache.invalidate_domain(:surveillance)
  end

  ## Analytics and Metrics

  @doc """
  Get threat surveillance metrics.
  """
  def get_metrics() do
    %{
      threat_assessments: Domain.ThreatAssessmentEngine.get_metrics(),
      surveillance_matches: Domain.SurveillanceMatchingEngine.get_metrics(),
      alert_statistics: Domain.AlertManagementService.get_metrics(),
      behavioral_analysis: Domain.BehavioralPatternAnalyzer.get_metrics()
    }
  end

  ## Health Check

  @doc """
  Perform health check on threat surveillance services.
  """
  def health_check() do
    services = [
      Domain.ThreatAssessmentEngine,
      Domain.SurveillanceMatchingEngine,
      Domain.AlertManagementService,
      Domain.NotificationService
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
