defmodule EveDmv.Contexts.Surveillance.Api do
  @moduledoc """
  Public API for the Surveillance bounded context.

  This module provides the external interface for surveillance profile management,
  matching operations, and alert notifications. All public operations are validated
  and logged through this interface.
  """

  use EveDmv.Core.Errors.ErrorHandler

  import EveDmv.Core.Validation.Validators

  alias EveDmv.Contexts.Surveillance.Domain.MatchingEngine
  alias EveDmv.Contexts.Surveillance.Domain.NotificationService
  alias EveDmv.Contexts.Surveillance.Domain.ProfileManager

  require Logger

  # Type definitions
  @type profile_id :: String.t()
  @type match_id :: String.t()
  @type user_id :: pos_integer()
  @type profile_data :: map()
  @type profile :: map()
  @type match :: map()
  @type notification_config :: map()
  @type time_range :: :last_24h | :last_7d | :last_30d | {DateTime.t(), DateTime.t()}
  @type opts :: keyword()
  @type result(t) :: {:ok, t} | {:error, term()}

  # Profile Management API

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
  def create_profile(profile_data) do
    with {:ok, validated_data} <- validate_profile_data(profile_data),
         {:ok, profile} <- ProfileManager.create_profile(validated_data) do
      Logger.info("Created surveillance profile: #{profile.name}")
      {:ok, profile}
    else
      {:error, reason} ->
        Logger.warning("Failed to create surveillance profile: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Update an existing surveillance profile.
  """
  @spec update_profile(profile_id(), map()) :: result(profile())
  def update_profile(profile_id, updates) do
    with {:ok, validated_updates} <- validate_profile_updates(updates),
         {:ok, profile} <- ProfileManager.update_profile(profile_id, validated_updates) do
      Logger.info("Updated surveillance profile: #{profile_id}")
      {:ok, profile}
    else
      {:error, reason} ->
        Logger.warning("Failed to update surveillance profile #{profile_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Delete a surveillance profile.
  """
  @spec delete_profile(profile_id()) :: :ok | {:error, term()}
  def delete_profile(profile_id) do
    case ProfileManager.delete_profile(profile_id) do
      :ok ->
        Logger.info("Deleted surveillance profile: #{profile_id}")
        :ok

      {:ok, _} ->
        Logger.info("Deleted surveillance profile: #{profile_id}")
        :ok

      {:error, reason} ->
        Logger.warning("Failed to delete surveillance profile #{profile_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get a surveillance profile by ID.
  """
  @spec get_profile(profile_id()) :: result(profile())
  def get_profile(profile_id) do
    ProfileManager.get_profile(profile_id)
  end

  @doc """
  List surveillance profiles with optional filtering.

  ## Options
  - user_id: Filter by profile owner
  - active_only: Only return active profiles (default: true)
  - limit: Maximum number of profiles to return
  - offset: Pagination offset
  """
  @spec list_profiles(opts()) :: result([profile()])
  def list_profiles(opts \\ []) do
    ProfileManager.list_profiles(opts)
  end

  @doc """
  Enable a surveillance profile.
  """
  @spec enable_profile(profile_id()) :: result(profile())
  def enable_profile(profile_id) do
    case ProfileManager.enable_profile(profile_id) do
      {:ok, profile} ->
        Logger.info("Enabled surveillance profile: #{profile_id}")
        {:ok, profile}

      {:error, reason} ->
        Logger.warning("Failed to enable surveillance profile #{profile_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Disable a surveillance profile.
  """
  @spec disable_profile(profile_id()) :: result(profile())
  def disable_profile(profile_id) do
    case ProfileManager.disable_profile(profile_id) do
      {:ok, profile} ->
        Logger.info("Disabled surveillance profile: #{profile_id}")
        {:ok, profile}

      {:error, reason} ->
        Logger.warning("Failed to disable surveillance profile #{profile_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Matching and Query API

  @doc """
  Get recent matches across all profiles.

  ## Options
  - limit: Maximum number of matches to return (default: 50)
  - since: Return matches since this timestamp
  - profile_id: Filter by specific profile
  """
  @spec get_recent_matches(opts()) :: result([match()])
  def get_recent_matches(opts \\ []) do
    MatchingEngine.get_recent_matches(opts)
  end

  @doc """
  Get matches for a specific profile.
  """
  @spec get_matches_for_profile(profile_id(), opts()) :: result([match()])
  def get_matches_for_profile(profile_id, opts \\ []) do
    MatchingEngine.get_matches_for_profile(profile_id, opts)
  end

  @doc """
  Get detailed information about a specific match.
  """
  @spec get_match_details(match_id()) :: result(match())
  def get_match_details(match_id) do
    MatchingEngine.get_match_details(match_id)
  end

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
  def get_match_statistics(profile_id, time_range \\ :last_30d) do
    MatchingEngine.get_match_statistics(profile_id, time_range)
  end

  # Profile Testing and Validation

  @doc """
  Test profile criteria against sample data.

  This allows users to validate their profile criteria before activation.
  """
  @spec test_profile_criteria(profile_id(), map()) :: result(map())
  def test_profile_criteria(profile_id, test_data) do
    with {:ok, profile} <- ProfileManager.get_profile(profile_id),
         {:ok, validated_test_data} <- validate_test_data(test_data) do
      MatchingEngine.test_criteria(profile.criteria, validated_test_data)
    end
  end

  @doc """
  Validate profile criteria configuration.

  Checks that criteria are properly formatted and logically consistent.
  """
  @spec validate_profile_criteria(map()) :: :ok | {:error, term()}
  def validate_profile_criteria(criteria) do
    MatchingEngine.validate_criteria(criteria)
  end

  # Notification Management

  @doc """
  Configure notifications for a profile.

  ## Configuration options
  - email: Email notification settings
  - webhook: Webhook URL for notifications
  - in_app: In-app notification preferences
  - frequency: Notification frequency limits
  """
  @spec configure_notifications(profile_id(), notification_config()) :: result(map())
  def configure_notifications(profile_id, notification_config) do
    with {:ok, validated_config} <- validate_notification_config(notification_config),
         {:ok, config} <-
           NotificationService.configure_notifications(profile_id, validated_config) do
      Logger.info("Updated notification config for profile: #{profile_id}")
      {:ok, config}
    else
      {:error, reason} ->
        Logger.warning(
          "Failed to configure notifications for profile #{profile_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Get notification history for a profile.
  """
  @spec get_notification_history(profile_id(), opts()) :: result([map()])
  def get_notification_history(profile_id, opts \\ []) do
    NotificationService.get_notification_history(profile_id, opts)
  end

  @doc """
  Test notification delivery for a profile.

  Sends a test notification to verify delivery configuration.
  """
  @spec test_notification_delivery(profile_id()) :: result(map())
  def test_notification_delivery(profile_id) do
    case NotificationService.test_notification_delivery(profile_id) do
      {:ok, result} ->
        Logger.info("Test notification sent for profile: #{profile_id}")
        {:ok, result}

      {:error, reason} ->
        Logger.warning(
          "Failed to send test notification for profile #{profile_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  # Private validation functions
  #
  # Uses centralized validators from EveDmv.Core.Validation.Validators

  defp validate_profile_data(profile_data) do
    with :ok <- validate_required_keys(:profile_data, profile_data, [:name, :criteria, :user_id]),
         :ok <- validate_profile_name(profile_data[:name]),
         :ok <- validate_criteria_structure(profile_data[:criteria]),
         :ok <- validate_positive_integer(:user_id, profile_data[:user_id]) do
      {:ok, profile_data}
    else
      {:error, {:user_id, _}} -> {:error, :invalid_user_id}
      {:error, other} -> {:error, other}
    end
  end

  defp validate_profile_updates(updates) do
    # Only allow updating certain fields
    allowed_fields = [:name, :criteria, :notification_config, :is_active]

    filtered_updates = Map.take(updates, allowed_fields)

    with :ok <- validate_update_fields(filtered_updates) do
      {:ok, filtered_updates}
    end
  end

  defp validate_profile_name(name) do
    case validate_string(:name, name, min: 3, max: 100) do
      :ok -> :ok
      {:error, {:name, :required}} -> {:error, :invalid_name_type}
      {:error, {:name, :invalid_type}} -> {:error, :invalid_name_type}
      {:error, {:name, :too_short}} -> {:error, :name_too_short}
      {:error, {:name, :too_long}} -> {:error, :name_too_long}
      {:error, {:name, :empty}} -> {:error, :name_empty}
    end
  end

  defp validate_criteria_structure(criteria) do
    # Basic structure validation - more detailed validation in MatchingEngine
    case validate_map(:criteria, criteria, allow_empty: false) do
      :ok ->
        case validate_required_keys(:criteria, criteria, [:type]) do
          :ok -> :ok
          {:error, {:criteria, {:missing_keys, _}}} -> {:error, {:missing_fields, [:type]}}
        end

      {:error, {:criteria, :invalid_type}} ->
        {:error, :invalid_criteria_type}

      {:error, {:criteria, :required}} ->
        {:error, :invalid_criteria_type}

      {:error, {:criteria, :empty}} ->
        {:error, {:missing_fields, [:type]}}
    end
  end

  defp validate_update_fields(updates) do
    # Validate each field that's being updated
    Enum.reduce_while(updates, :ok, fn {field, value}, :ok ->
      case validate_update_field(field, value) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, {field, reason}}}
      end
    end)
  end

  defp validate_update_field(:name, name), do: validate_profile_name(name)
  defp validate_update_field(:criteria, criteria), do: validate_criteria_structure(criteria)

  defp validate_update_field(:is_active, active) do
    case validate_boolean(:is_active, active) do
      :ok -> :ok
      {:error, _} -> {:error, :invalid_type}
    end
  end

  defp validate_update_field(:notification_config, config) do
    case validate_map(:notification_config, config) do
      :ok -> :ok
      {:error, _} -> {:error, :invalid_type}
    end
  end

  defp validate_update_field(field, _value), do: {:error, {:invalid_field, field}}

  defp validate_test_data(test_data) do
    # Test data should contain killmail-like structure
    with :ok <- validate_map(:test_data, test_data),
         :ok <-
           validate_required_keys(:test_data, test_data, [
             :character_id,
             :corporation_id,
             :ship_type_id
           ]) do
      {:ok, test_data}
    else
      {:error, {:test_data, :invalid_type}} -> {:error, :invalid_test_data_type}
      {:error, {:test_data, :required}} -> {:error, :invalid_test_data_type}
      {:error, {:test_data, {:missing_keys, keys}}} -> {:error, {:missing_fields, keys}}
    end
  end

  defp validate_notification_config(config) do
    # Validate notification configuration structure
    allowed_types = [:email, :webhook, :in_app]

    case validate_map(:notification_config, config) do
      :ok ->
        config_keys = Map.keys(config)
        invalid_keys = Enum.reject(config_keys, fn key -> key in allowed_types end)

        case invalid_keys do
          [] -> {:ok, config}
          keys -> {:error, {:invalid_notification_types, keys}}
        end

      {:error, _} ->
        {:error, :invalid_notification_config_type}
    end
  end
end
