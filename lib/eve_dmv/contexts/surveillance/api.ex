defmodule EveDmv.Contexts.Surveillance.Api do
  @moduledoc """
  Public API for the Surveillance bounded context.

  This module provides the external interface for surveillance profile management,
  matching operations, and alert notifications. All public operations are validated
  and logged through this interface.
  """

  use EveDmv.ErrorHandler
  alias EveDmv.Result
  alias EveDmv.Utils.ValidationUtils

  alias EveDmv.Contexts.Surveillance.Domain.{
    ProfileManager,
    MatchingEngine,
    AlertService,
    NotificationService
  }

  alias EveDmv.Shared.ValueObjects.{CharacterId, CorporationId}

  require Logger

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
  def delete_profile(profile_id) do
    with {:ok, _} <- ProfileManager.delete_profile(profile_id) do
      Logger.info("Deleted surveillance profile: #{profile_id}")
      :ok
    else
      {:error, reason} ->
        Logger.warning("Failed to delete surveillance profile #{profile_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get a surveillance profile by ID.
  """
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
  def list_profiles(opts \\ []) do
    ProfileManager.list_profiles(opts)
  end

  @doc """
  Enable a surveillance profile.
  """
  def enable_profile(profile_id) do
    with {:ok, profile} <- ProfileManager.enable_profile(profile_id) do
      Logger.info("Enabled surveillance profile: #{profile_id}")
      {:ok, profile}
    else
      {:error, reason} ->
        Logger.warning("Failed to enable surveillance profile #{profile_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Disable a surveillance profile.
  """
  def disable_profile(profile_id) do
    with {:ok, profile} <- ProfileManager.disable_profile(profile_id) do
      Logger.info("Disabled surveillance profile: #{profile_id}")
      {:ok, profile}
    else
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
  def get_recent_matches(opts \\ []) do
    MatchingEngine.get_recent_matches(opts)
  end

  @doc """
  Get matches for a specific profile.
  """
  def get_matches_for_profile(profile_id, opts \\ []) do
    MatchingEngine.get_matches_for_profile(profile_id, opts)
  end

  @doc """
  Get detailed information about a specific match.
  """
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
  def get_match_statistics(profile_id, time_range \\ :last_30d) do
    MatchingEngine.get_match_statistics(profile_id, time_range)
  end

  # Profile Testing and Validation

  @doc """
  Test profile criteria against sample data.

  This allows users to validate their profile criteria before activation.
  """
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
  def get_notification_history(profile_id, opts \\ []) do
    NotificationService.get_notification_history(profile_id, opts)
  end

  @doc """
  Test notification delivery for a profile.

  Sends a test notification to verify delivery configuration.
  """
  def test_notification_delivery(profile_id) do
    with {:ok, result} <- NotificationService.test_notification_delivery(profile_id) do
      Logger.info("Test notification sent for profile: #{profile_id}")
      {:ok, result}
    else
      {:error, reason} ->
        Logger.warning(
          "Failed to send test notification for profile #{profile_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  # Private validation functions

  defp validate_profile_data(profile_data) do
    required_fields = [:name, :criteria, :user_id]

    with :ok <- ValidationUtils.validate_required_fields(profile_data, required_fields),
         :ok <- validate_profile_name(profile_data[:name]),
         :ok <- validate_criteria_structure(profile_data[:criteria]),
         :ok <- validate_user_id(profile_data[:user_id]) do
      {:ok, profile_data}
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

  defp validate_profile_name(name) when is_binary(name) do
    cond do
      String.length(name) < 3 -> {:error, :name_too_short}
      String.length(name) > 100 -> {:error, :name_too_long}
      String.trim(name) == "" -> {:error, :name_empty}
      true -> :ok
    end
  end

  defp validate_profile_name(_), do: {:error, :invalid_name_type}

  defp validate_criteria_structure(criteria) when is_map(criteria) do
    # Basic structure validation - more detailed validation in MatchingEngine
    required_criteria_fields = [:type]

    with :ok <- ValidationUtils.validate_required_fields(criteria, required_criteria_fields) do
      :ok
    end
  end

  defp validate_criteria_structure(_), do: {:error, :invalid_criteria_type}

  defp validate_user_id(user_id) when is_integer(user_id) and user_id > 0, do: :ok
  defp validate_user_id(_), do: {:error, :invalid_user_id}

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
  defp validate_update_field(:is_active, active) when is_boolean(active), do: :ok
  defp validate_update_field(:notification_config, config) when is_map(config), do: :ok
  defp validate_update_field(field, _value), do: {:error, {:invalid_field, field}}

  defp validate_test_data(test_data) when is_map(test_data) do
    # Test data should contain killmail-like structure
    required_fields = [:character_id, :corporation_id, :ship_type_id]

    with :ok <- ValidationUtils.validate_required_fields(test_data, required_fields) do
      {:ok, test_data}
    end
  end

  defp validate_test_data(_), do: {:error, :invalid_test_data_type}

  defp validate_notification_config(config) when is_map(config) do
    # Validate notification configuration structure
    allowed_types = [:email, :webhook, :in_app]

    config_keys = Map.keys(config)
    invalid_keys = Enum.reject(config_keys, fn key -> key in allowed_types end)

    case invalid_keys do
      [] -> {:ok, config}
      keys -> {:error, {:invalid_notification_types, keys}}
    end
  end

  defp validate_notification_config(_), do: {:error, :invalid_notification_config_type}
end
