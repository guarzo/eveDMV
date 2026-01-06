defmodule EveDmv.Contexts.Surveillance.Api do
  @moduledoc """
  Public API for the Surveillance bounded context.

  This module provides the external interface for surveillance profile management,
  matching operations, and alert notifications. All operations are validated
  through the ProfileValidationService before processing.
  """

  alias EveDmv.Contexts.Surveillance.Domain.MatchingEngine
  alias EveDmv.Contexts.Surveillance.Domain.NotificationService
  alias EveDmv.Contexts.Surveillance.Domain.ProfileManager

  require Logger

  # Type definitions
  @type profile_id :: String.t()
  @type match_id :: String.t()
  @type profile_data :: map()
  @type profile :: map()
  @type match :: map()
  @type notification_config :: map()
  @type time_range :: :last_24h | :last_7d | :last_30d | {DateTime.t(), DateTime.t()}
  @type opts :: keyword()
  @type result(t) :: {:ok, t} | {:error, term()}

  # ============================================================================
  # Profile Management API
  # ============================================================================

  @doc """
  Create a new surveillance profile.

  ## Parameters
  - profile_data: Map containing profile configuration
    - name: Profile name
    - criteria: Matching criteria configuration
    - user_id: Owner of the profile
    - notification_config: How to deliver alerts

  ## Returns
  - {:ok, profile} on success
  - {:error, reason} on failure
  """
  @spec create_profile(profile_data()) :: result(profile())
  defdelegate create_profile(profile_data),
    to: ProfileManager,
    as: :create_profile_validated

  @doc """
  Update an existing surveillance profile.
  """
  @spec update_profile(profile_id(), map()) :: result(profile())
  defdelegate update_profile(profile_id, updates),
    to: ProfileManager,
    as: :update_profile_validated

  @doc """
  Delete a surveillance profile.
  """
  @spec delete_profile(profile_id()) :: :ok | {:error, term()}
  defdelegate delete_profile(profile_id), to: ProfileManager

  @doc """
  Get a surveillance profile by ID.
  """
  @spec get_profile(profile_id()) :: result(profile())
  defdelegate get_profile(profile_id), to: ProfileManager

  @doc """
  List surveillance profiles with optional filtering.

  ## Options
  - user_id: Filter by profile owner
  - active_only: Only return active profiles (default: true)
  - limit: Maximum number of profiles to return
  - offset: Pagination offset
  """
  @spec list_profiles(opts()) :: result([profile()])
  defdelegate list_profiles(opts \\ []), to: ProfileManager

  @doc """
  Enable a surveillance profile.
  """
  @spec enable_profile(profile_id()) :: result(profile())
  defdelegate enable_profile(profile_id),
    to: ProfileManager,
    as: :enable_profile_logged

  @doc """
  Disable a surveillance profile.
  """
  @spec disable_profile(profile_id()) :: result(profile())
  defdelegate disable_profile(profile_id),
    to: ProfileManager,
    as: :disable_profile_logged

  # ============================================================================
  # Matching and Query API
  # ============================================================================

  @doc """
  Get recent matches across all profiles.

  ## Options
  - limit: Maximum number of matches to return (default: 50)
  - since: Return matches since this timestamp
  - profile_id: Filter by specific profile
  """
  @spec get_recent_matches(opts()) :: result([match()])
  defdelegate get_recent_matches(opts \\ []), to: MatchingEngine

  @doc """
  Get matches for a specific profile.
  """
  @spec get_matches_for_profile(profile_id(), opts()) :: result([match()])
  defdelegate get_matches_for_profile(profile_id, opts \\ []), to: MatchingEngine

  @doc """
  Get detailed information about a specific match.
  """
  @spec get_match_details(match_id()) :: result(match())
  defdelegate get_match_details(match_id), to: MatchingEngine

  @doc """
  Get statistics for a profile's matches over a time range.

  ## Parameters
  - profile_id: The profile to analyze
  - time_range: Time range for analysis (:last_24h, :last_7d, :last_30d, or {start_date, end_date})

  ## Returns
  Statistics including:
  - Total matches
  - Match rate trend
  - Top matching criteria
  - Geographic distribution
  """
  @spec get_match_statistics(profile_id(), time_range()) :: result(map())
  defdelegate get_match_statistics(profile_id, time_range \\ :last_30d), to: MatchingEngine

  # ============================================================================
  # Profile Testing and Validation
  # ============================================================================

  @doc """
  Test profile criteria against sample data.

  This allows users to validate their profile criteria before activation.
  """
  @spec test_profile_criteria(profile_id(), map()) :: result(map())
  defdelegate test_profile_criteria(profile_id, test_data),
    to: MatchingEngine,
    as: :test_profile_criteria_validated

  @doc """
  Validate profile criteria configuration.

  Checks that criteria are properly formatted and logically consistent.
  """
  @spec validate_profile_criteria(map()) :: :ok | {:error, term()}
  defdelegate validate_profile_criteria(criteria), to: MatchingEngine, as: :validate_criteria

  # ============================================================================
  # Notification Management
  # ============================================================================

  @doc """
  Configure notifications for a profile.

  ## Configuration options
  - email: Email notification settings
  - webhook: Webhook URL for notifications
  - in_app: In-app notification preferences
  - frequency: Notification frequency limits
  """
  @spec configure_notifications(profile_id(), notification_config()) :: result(map())
  defdelegate configure_notifications(profile_id, notification_config),
    to: NotificationService,
    as: :configure_notifications_validated

  @doc """
  Get notification history for a profile.
  """
  @spec get_notification_history(profile_id(), opts()) :: result([map()])
  defdelegate get_notification_history(profile_id, opts \\ []), to: NotificationService

  @doc """
  Test notification delivery for a profile.

  Sends a test notification to verify delivery configuration.
  """
  @spec test_notification_delivery(profile_id()) :: result(map())
  defdelegate test_notification_delivery(profile_id),
    to: NotificationService,
    as: :test_notification_delivery_logged
end
