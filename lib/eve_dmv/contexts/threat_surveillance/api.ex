defmodule EveDmv.Contexts.ThreatSurveillance.Api do
  @moduledoc """
  API module for the unified Threat Surveillance context.

  Provides a clean interface for all threat surveillance functionality
  including threat assessment, surveillance matching, and alert management.
  """
  """

  alias EveDmv.Contexts.ThreatSurveillance

  ## Threat Assessment API

  @doc """
  Assess threat level for a character.
  """
  defdelegate assess_character_threat(character_id, options \\ []), to: ThreatSurveillance

  @doc """
  Assess threat level for a corporation.
  """
  defdelegate assess_corporation_threat(corp_id, options \\ []), to: ThreatSurveillance

  @doc """
  Get comprehensive threat analysis.
  """
  defdelegate get_threat_analysis(entity_id, entity_type, options \\ []), to: ThreatSurveillance

  @doc """
  Update threat assessment based on new intelligence.
  """
  defdelegate update_threat_assessment(entity_id, entity_type, intelligence_data),
    to: ThreatSurveillance

  ## Surveillance API

  @doc """
  Create a surveillance profile with matching criteria.
  """
  defdelegate create_surveillance_profile(user_id, profile_data), to: ThreatSurveillance

  @doc """
  Update a surveillance profile.
  """
  defdelegate update_surveillance_profile(profile_id, updates), to: ThreatSurveillance

  @doc """
  Test surveillance criteria against sample data.
  """
  defdelegate test_surveillance_criteria(criteria, sample_data), to: ThreatSurveillance

  @doc """
  Get recent surveillance matches across all profiles.
  """
  defdelegate get_recent_matches(options \\ []), to: ThreatSurveillance

  @doc """
  Get matches for a specific surveillance profile.
  """
  defdelegate get_profile_matches(profile_id, options \\ []), to: ThreatSurveillance

  ## Alerts and Notifications API

  @doc """
  Configure alert settings for a user.
  """
  defdelegate configure_alerts(user_id, alert_settings), to: ThreatSurveillance

  @doc """
  Send notification for surveillance match.
  """
  defdelegate send_match_notification(match_data), to: ThreatSurveillance

  @doc """
  Send threat level alert.
  """
  defdelegate send_threat_alert(threat_data), to: ThreatSurveillance

  ## Behavioral Analysis API

  @doc """
  Analyze behavioral patterns for threat detection.
  """
  defdelegate analyze_behavioral_patterns(entity_id, entity_type, options \\ []),
    to: ThreatSurveillance

  @doc """
  Detect anomalous behavior patterns.
  """
  defdelegate detect_anomalous_behavior(entity_id, recent_activity), to: ThreatSurveillance

  ## Repository Operations API

  @doc """
  Get threat assessment by character ID.
  """
  defdelegate get_threat_assessment(character_id, options \\ []), to: ThreatSurveillance

  @doc """
  Get surveillance profile by ID.
  """
  defdelegate get_surveillance_profile(profile_id, options \\ []), to: ThreatSurveillance

  @doc """
  List active surveillance profiles.
  """
  defdelegate get_active_surveillance_profiles(options \\ []), to: ThreatSurveillance

  @doc """
  List surveillance profiles by user.
  """
  defdelegate list_user_surveillance_profiles(user_id, options \\ []), to: ThreatSurveillance

  ## Cache and Monitoring API

  @doc """
  Get threat surveillance cache statistics.
  """
  defdelegate get_cache_stats(), to: ThreatSurveillance

  @doc """
  Clear threat surveillance cache.
  """
  defdelegate clear_cache(), to: ThreatSurveillance

  @doc """
  Get threat surveillance metrics and analytics.
  """
  defdelegate get_metrics(), to: ThreatSurveillance

  @doc """
  Perform health check on threat surveillance services.
  """
  defdelegate health_check(), to: ThreatSurveillance
end
