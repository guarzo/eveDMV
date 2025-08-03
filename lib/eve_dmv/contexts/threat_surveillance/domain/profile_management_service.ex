defmodule EveDmv.Contexts.ThreatSurveillance.Domain.ProfileManagementService do
  @moduledoc """
  Service for managing surveillance profiles and their criteria.

  Handles:
  - Profile creation and updates
  - Criteria validation and optimization
  - Profile dependencies and threat-based updates
  - Profile activation/deactivation
  - Profile performance tracking

  Works with real surveillance profile data stored in the database.
  """

  alias EveDmv.Api
  alias EveDmv.Contexts.Surveillance.Domain.AdvancedFilterEngine
  alias EveDmv.Shared.Infrastructure.UnifiedCache
  alias EveDmv.Surveillance.Profile

  require Logger
  require Ash.Query

  @max_profiles_per_user 50
  # 10 minutes
  @cache_ttl 600

  @doc """
  Create a new surveillance profile for a user.

  ## Parameters
  - `user_id` - ID of the user creating the profile
  - `profile_data` - Profile configuration including:
    - `:name` - Profile name
    - `:criteria` - Surveillance criteria
    - `:priority` - Alert priority level
    - `:active` - Whether profile is active
    - `:alert_channels` - Where to send alerts

  ## Returns
  - `{:ok, profile}` - Created profile
  - `{:error, reason}` - Error if creation fails
  """
  def create_profile(user_id, profile_data) do
    Logger.info("Creating surveillance profile", user_id: user_id, name: profile_data[:name])

    with :ok <- validate_user_profile_limit(user_id),
         :ok <- validate_profile_data(profile_data),
         {:ok, optimized_criteria} <- optimize_criteria(profile_data[:criteria]),
         profile_attrs <- build_profile_attributes(user_id, profile_data, optimized_criteria),
         {:ok, profile} <- Api.create(Profile, profile_attrs) do
      # Clear user's profile cache
      UnifiedCache.delete(:surveillance, {:user_profiles, user_id})

      # Track profile creation metrics
      track_profile_event(:created, profile)

      {:ok, profile}
    else
      {:error, :profile_limit_exceeded} ->
        {:error, "User has reached maximum profile limit of #{@max_profiles_per_user}"}

      {:error, %Ash.Error.Invalid{} = error} ->
        {:error, format_validation_errors(error)}

      {:error, reason} ->
        Logger.error("Failed to create profile", reason: reason, user_id: user_id)
        {:error, reason}
    end
  end

  @doc """
  Update an existing surveillance profile.

  ## Parameters
  - `profile_id` - ID of the profile to update
  - `updates` - Map of updates to apply

  ## Returns
  - `{:ok, updated_profile}` - Updated profile
  - `{:error, reason}` - Error if update fails
  """
  def update_profile(profile_id, updates) do
    Logger.info("Updating surveillance profile", profile_id: profile_id)

    with {:ok, profile} <- get_profile(profile_id),
         :ok <- validate_profile_ownership(profile, updates[:user_id]),
         :ok <- validate_profile_updates(updates),
         {:ok, processed_updates} <- process_profile_updates(profile, updates),
         {:ok, updated_profile} <- Api.update(profile, processed_updates) do
      # Clear caches
      UnifiedCache.delete(:surveillance, {:profile, profile_id})
      UnifiedCache.delete(:surveillance, {:user_profiles, profile.user_id})

      # Track update metrics
      track_profile_event(:updated, updated_profile)

      {:ok, updated_profile}
    else
      {:error, :not_found} ->
        {:error, "Profile not found"}

      {:error, :unauthorized} ->
        {:error, "Not authorized to update this profile"}

      {:error, reason} ->
        Logger.error("Failed to update profile", reason: reason, profile_id: profile_id)
        {:error, reason}
    end
  end

  @doc """
  Update profiles that depend on threat assessment changes.

  When a character or corporation's threat level changes, this updates
  any profiles that have threat-based criteria.

  ## Parameters
  - `event` - ThreatLevelChanged event containing:
    - `:entity_id` - Character or corporation ID
    - `:entity_type` - :character or :corporation
    - `:old_threat_level` - Previous threat level
    - `:new_threat_level` - New threat level

  ## Returns
  - `:ok` - Updates processed
  """
  def update_threat_dependent_profiles(event) do
    Logger.info("Processing threat level change for profiles",
      entity_id: event.entity_id,
      entity_type: event.entity_type,
      new_level: event.new_threat_level
    )

    # Find profiles with threat-based criteria
    threat_profiles = find_threat_dependent_profiles(event.entity_id, event.entity_type)

    # Update each profile's criteria if needed
    Enum.each(threat_profiles, fn profile ->
      case update_threat_criteria(profile, event) do
        {:ok, updated_profile} ->
          Logger.debug("Updated threat criteria for profile",
            profile_id: updated_profile.id,
            name: updated_profile.name
          )

        {:error, reason} ->
          Logger.warning("Failed to update threat criteria",
            profile_id: profile.id,
            reason: reason
          )
      end
    end)

    :ok
  end

  # Private implementation functions

  defp validate_user_profile_limit(user_id) do
    case count_user_profiles(user_id) do
      {:ok, count} when count < @max_profiles_per_user ->
        :ok

      {:ok, _count} ->
        {:error, :profile_limit_exceeded}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp count_user_profiles(user_id) do
    query =
      Profile
      |> Ash.Query.filter(user_id == ^user_id)
      |> Ash.Query.filter(deleted == false)

    case Api.count(query) do
      {:ok, count} -> {:ok, count}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_profile_data(profile_data) do
    required_fields = [:name, :criteria]

    missing_fields = Enum.filter(required_fields, &(not Map.has_key?(profile_data, &1)))

    if Enum.empty?(missing_fields) do
      validate_criteria_structure(profile_data[:criteria])
    else
      {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
    end
  end

  defp validate_criteria_structure(criteria) do
    case AdvancedFilterEngine.validate_complex_criteria(criteria) do
      {:ok, :valid} -> :ok
      {:error, reason} -> {:error, "Invalid criteria: #{reason}"}
    end
  end

  defp optimize_criteria(criteria) do
    optimized = AdvancedFilterEngine.optimize_criteria(criteria)
    {:ok, optimized}
  end

  defp build_profile_attributes(user_id, profile_data, optimized_criteria) do
    %{
      user_id: user_id,
      name: profile_data[:name],
      description: profile_data[:description],
      criteria: optimized_criteria,
      priority: profile_data[:priority] || :medium,
      active: profile_data[:active] != false,
      alert_channels: profile_data[:alert_channels] || ["web"],
      cooldown_minutes: profile_data[:cooldown_minutes] || 15,
      metadata: %{
        created_via: "profile_management_service",
        version: 1,
        optimized: true
      }
    }
  end

  defp get_profile(profile_id) do
    cache_key = {:profile, profile_id}

    case UnifiedCache.get(:surveillance, cache_key) do
      {:ok, profile} ->
        {:ok, profile}

      :miss ->
        case Api.get(Profile, profile_id) do
          {:ok, profile} ->
            UnifiedCache.put(:surveillance, cache_key, profile, @cache_ttl)
            {:ok, profile}

          {:error, %Ash.Error.Query.NotFound{}} ->
            {:error, :not_found}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp validate_profile_ownership(profile, user_id) do
    if user_id && profile.user_id != user_id do
      {:error, :unauthorized}
    else
      :ok
    end
  end

  defp validate_profile_updates(updates) do
    # Validate specific update fields
    cond do
      Map.has_key?(updates, :criteria) ->
        validate_criteria_structure(updates[:criteria])

      Map.has_key?(updates, :priority) &&
          updates[:priority] not in [:low, :medium, :high, :critical] ->
        {:error, "Invalid priority level"}

      Map.has_key?(updates, :cooldown_minutes) &&
          (updates[:cooldown_minutes] < 1 || updates[:cooldown_minutes] > 1440) ->
        {:error, "Cooldown must be between 1 and 1440 minutes"}

      true ->
        :ok
    end
  end

  defp process_profile_updates(profile, updates) do
    updates
    |> then(fn processed ->
      # Optimize criteria if being updated
      if Map.has_key?(updates, :criteria) do
        case optimize_criteria(updates[:criteria]) do
          {:ok, optimized} -> Map.put(processed, :criteria, optimized)
          _ -> processed
        end
      else
        processed
      end
    end)
    |> then(fn processed ->
      # Add metadata about update
      metadata =
        Map.merge(profile.metadata || %{}, %{
          last_updated: DateTime.utc_now(),
          update_count: (profile.metadata["update_count"] || 0) + 1
        })

      Map.put(processed, :metadata, metadata)
    end)
    |> then(fn processed -> {:ok, processed} end)
  end

  defp find_threat_dependent_profiles(entity_id, entity_type) do
    # Find profiles that have criteria referencing this entity's threat level
    # This is a simplified search - in production would use more sophisticated indexing

    query =
      Profile
      |> Ash.Query.filter(active == true)
      |> Ash.Query.filter(deleted == false)

    case Api.read(query) do
      {:ok, profiles} ->
        # Filter profiles that reference threat levels in criteria
        Enum.filter(profiles, fn profile ->
          has_threat_criteria?(profile.criteria, entity_id, entity_type)
        end)

      {:error, reason} ->
        Logger.error("Failed to find threat dependent profiles", reason: reason)
        []
    end
  end

  defp has_threat_criteria?(criteria, entity_id, entity_type) do
    # Check if criteria references threat levels for this entity
    # This is a simplified check - real implementation would parse criteria tree

    criteria_string = Jason.encode!(criteria)

    entity_reference =
      case entity_type do
        :character -> "character_threat_#{entity_id}"
        :corporation -> "corporation_threat_#{entity_id}"
        _ -> nil
      end

    entity_reference && String.contains?(criteria_string, entity_reference)
  end

  defp update_threat_criteria(profile, event) do
    # Update criteria to reflect new threat level
    # This would involve parsing and modifying the criteria tree
    # For now, we'll add metadata about the threat change

    updated_metadata =
      Map.merge(profile.metadata || %{}, %{
        last_threat_update: DateTime.utc_now(),
        threat_updates: [
          %{
            entity_id: event.entity_id,
            entity_type: event.entity_type,
            old_level: event.old_threat_level,
            new_level: event.new_threat_level,
            timestamp: DateTime.utc_now()
          }
          | (profile.metadata["threat_updates"] || []) |> Enum.take(9)
        ]
      })

    update_profile(profile.id, %{metadata: updated_metadata})
  end

  defp track_profile_event(event_type, profile) do
    # Track metrics about profile operations
    :telemetry.execute(
      [:surveillance, :profile, event_type],
      %{count: 1},
      %{
        profile_id: profile.id,
        user_id: profile.user_id,
        priority: profile.priority,
        active: profile.active
      }
    )
  end

  defp format_validation_errors(%Ash.Error.Invalid{errors: errors}) do
    Enum.map_join(errors, ", ", &format_error/1)
  end

  defp format_error(%{field: field, message: message}) do
    "#{field}: #{message}"
  end

  defp format_error(%{message: message}) do
    message
  end

  defp format_error(error) do
    inspect(error)
  end

  # Additional helper functions for profile management

  @doc """
  Get all profiles for a user.
  """
  def get_user_profiles(user_id) do
    cache_key = {:user_profiles, user_id}

    case UnifiedCache.get(:surveillance, cache_key) do
      {:ok, profiles} ->
        {:ok, profiles}

      :miss ->
        query =
          Profile
          |> Ash.Query.filter(user_id == ^user_id)
          |> Ash.Query.filter(deleted == false)
          |> Ash.Query.sort(created_at: :desc)

        case Api.read(query) do
          {:ok, profiles} ->
            UnifiedCache.put(:surveillance, cache_key, profiles, @cache_ttl)
            {:ok, profiles}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Activate or deactivate a profile.
  """
  def set_profile_active(profile_id, active) do
    update_profile(profile_id, %{active: active})
  end

  @doc """
  Delete a profile (soft delete).
  """
  def delete_profile(profile_id) do
    update_profile(profile_id, %{deleted: true, active: false})
  end

  @doc """
  Get profile performance metrics.
  """
  def get_profile_metrics(profile_id) do
    case get_profile(profile_id) do
      {:ok, profile} ->
        {:ok,
         %{
           match_count: profile.match_count || 0,
           last_match: profile.last_match_at,
           false_positive_rate: calculate_false_positive_rate(profile),
           avg_response_time: profile.metadata["avg_response_time"] || 0,
           created_at: profile.created_at,
           updated_at: profile.updated_at
         }}

      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, :profile_not_found}
    end
  end

  defp calculate_false_positive_rate(profile) do
    total_matches = profile.match_count || 0
    dismissed_matches = profile.metadata["dismissed_matches"] || 0

    if total_matches > 0 do
      Float.round(dismissed_matches / total_matches * 100, 1)
    else
      0.0
    end
  end
end
