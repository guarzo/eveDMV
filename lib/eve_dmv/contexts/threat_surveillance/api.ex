defmodule EveDmv.Contexts.ThreatSurveillance.Api do
  @moduledoc """
  API module for the unified Threat Surveillance context.

  Provides a clean interface for all threat surveillance functionality
  including threat assessment, surveillance matching, and alert management.
  """

  alias EveDmv.Contexts.ThreatSurveillance
  alias EveDmv.Types

  ## Threat Assessment API

  @doc """
  Assess threat level for a character.
  """
  @spec assess_character_threat(Types.character_id(), Types.opts()) :: Types.analysis_result()
  defdelegate assess_character_threat(character_id, options \\ []), to: ThreatSurveillance

  @doc """
  Assess threat level for a corporation.
  """
  @spec assess_corporation_threat(Types.corporation_id(), Types.opts()) :: Types.analysis_result()
  defdelegate assess_corporation_threat(corp_id, options \\ []), to: ThreatSurveillance

  @doc """
  Get comprehensive threat analysis.
  """
  @spec get_threat_analysis(pos_integer(), Types.entity_type(), Types.opts()) ::
          Types.analysis_result()
  defdelegate get_threat_analysis(entity_id, entity_type, options \\ []), to: ThreatSurveillance

  @doc """
  Update threat assessment based on new intelligence.
  """
  @spec update_threat_assessment(pos_integer(), Types.entity_type(), map()) ::
          Types.analysis_result()
  defdelegate update_threat_assessment(entity_id, entity_type, intelligence_data),
    to: ThreatSurveillance

  ## Surveillance API

  @doc """
  Create a surveillance profile with matching criteria.
  """
  @spec create_surveillance_profile(Types.user_id(), map()) :: Types.result(map())
  defdelegate create_surveillance_profile(user_id, profile_data), to: ThreatSurveillance

  @doc """
  Update a surveillance profile.
  """
  @spec update_surveillance_profile(Types.profile_id(), map()) :: Types.result(map())
  defdelegate update_surveillance_profile(profile_id, updates), to: ThreatSurveillance

  @doc """
  Test surveillance criteria against sample data.
  """
  @spec test_surveillance_criteria(map(), map()) :: Types.analysis_result()
  defdelegate test_surveillance_criteria(criteria, sample_data), to: ThreatSurveillance

  @doc """
  Get recent surveillance matches across all profiles.
  """
  @spec get_recent_matches(Types.opts()) :: Types.result([map()])
  defdelegate get_recent_matches(options \\ []), to: ThreatSurveillance

  @doc """
  Get matches for a specific surveillance profile.
  """
  @spec get_profile_matches(Types.profile_id(), Types.opts()) :: Types.result([map()])
  defdelegate get_profile_matches(profile_id, options \\ []), to: ThreatSurveillance

  ## Alerts and Notifications API

  @doc """
  Configure alert settings for a user.
  """
  @spec configure_alerts(Types.user_id(), map()) :: Types.result(map())
  defdelegate configure_alerts(user_id, alert_settings), to: ThreatSurveillance

  @doc """
  Send notification for surveillance match.
  """
  @spec send_match_notification(map()) :: Types.void_result()
  defdelegate send_match_notification(match_data), to: ThreatSurveillance

  @doc """
  Send threat level alert.
  """
  @spec send_threat_alert(map()) :: Types.void_result()
  defdelegate send_threat_alert(threat_data), to: ThreatSurveillance

  ## Behavioral Analysis API

  @doc """
  Analyze behavioral patterns for threat detection.
  """
  @spec analyze_behavioral_patterns(pos_integer(), Types.entity_type(), Types.opts()) ::
          Types.analysis_result()
  defdelegate analyze_behavioral_patterns(entity_id, entity_type, options \\ []),
    to: ThreatSurveillance

  @doc """
  Detect anomalous behavior patterns.
  """
  @spec detect_anomalous_behavior(pos_integer(), [map()]) :: Types.analysis_result()
  defdelegate detect_anomalous_behavior(entity_id, recent_activity), to: ThreatSurveillance

  ## Repository Operations API

  @doc """
  Get threat assessment by character ID.
  """
  @spec get_threat_assessment(Types.character_id(), Types.opts()) :: Types.result(map())
  defdelegate get_threat_assessment(character_id, options \\ []), to: ThreatSurveillance

  @doc """
  Get surveillance profile by ID.
  """
  @spec get_surveillance_profile(Types.profile_id(), Types.opts()) :: Types.result(map())
  defdelegate get_surveillance_profile(profile_id, options \\ []), to: ThreatSurveillance

  @doc """
  List active surveillance profiles.
  """
  @spec get_active_surveillance_profiles(Types.opts()) :: Types.result([map()])
  defdelegate get_active_surveillance_profiles(options \\ []), to: ThreatSurveillance

  @doc """
  List surveillance profiles by user.
  """
  @spec list_user_surveillance_profiles(Types.user_id(), Types.opts()) :: Types.result([map()])
  defdelegate list_user_surveillance_profiles(user_id, options \\ []), to: ThreatSurveillance

  ## Cache and Monitoring API

  @doc """
  Get threat surveillance cache statistics.
  """
  @spec get_cache_stats() :: map()
  defdelegate get_cache_stats(), to: ThreatSurveillance

  @doc """
  Clear threat surveillance cache.
  """
  @spec clear_cache() :: :ok
  defdelegate clear_cache(), to: ThreatSurveillance

  @doc """
  Get threat surveillance metrics and analytics.
  """
  @spec get_metrics() :: map()
  defdelegate get_metrics(), to: ThreatSurveillance

  @doc """
  Perform health check on threat surveillance services.
  """
  @spec health_check() :: Types.health_check_result()
  defdelegate health_check(), to: ThreatSurveillance
end
