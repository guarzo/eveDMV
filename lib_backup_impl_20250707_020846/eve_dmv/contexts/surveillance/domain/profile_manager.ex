defmodule EveDmv.Contexts.Surveillance.Domain.ProfileManager do
  @moduledoc """
  Domain service for managing surveillance profiles.

  Handles CRUD operations for surveillance profiles, including
  validation, activation/deactivation, and profile lifecycle management.
  """

  alias EveDmv.Contexts.Surveillance.Domain.MatchingEngine
  alias EveDmv.Contexts.Surveillance.Infrastructure.ProfileRepository
  use EveDmv.ErrorHandler

  require Logger

  # Profile CRUD operations

  @doc """
  Create a new surveillance profile.
  """
  def create_profile(profile_data) do
    with {:ok, validated_data} <- validate_create_data(profile_data),
         {:ok, profile} <- ProfileRepository.create_profile(validated_data) do
      Logger.info("Created surveillance profile: #{profile.name} (#{profile.id})")
      {:ok, profile}
    end
  end

  @doc """
  Update an existing surveillance profile.
  """
  def update_profile(profile_id, updates) do
    with {:ok, existing_profile} <- ProfileRepository.get_profile(profile_id),
         {:ok, validated_updates} <- validate_update_data(updates, existing_profile),
         {:ok, updated_profile} <- ProfileRepository.update_profile(profile_id, validated_updates) do
      Logger.info("Updated surveillance profile: #{profile_id}")
      {:ok, updated_profile}
    end
  end

  @doc """
  Delete a surveillance profile.
  """
  def delete_profile(profile_id) do
    with {:ok, profile} <- ProfileRepository.get_profile(profile_id),
         :ok <- validate_profile_deletion(profile),
         {:ok, _} <- ProfileRepository.delete_profile(profile_id) do
      Logger.info("Deleted surveillance profile: #{profile_id}")
      :ok
    end
  end

  @doc """
  Get a surveillance profile by ID.
  """
  def get_profile(profile_id) do
    ProfileRepository.get_profile(profile_id)
  end

  @doc """
  List surveillance profiles with filtering options.
  """
  def list_profiles(opts \\ []) do
    ProfileRepository.list_profiles(opts)
  end

  @doc """
  Enable a surveillance profile.
  """
  def enable_profile(profile_id) do
    with {:ok, profile} <- ProfileRepository.get_profile(profile_id),
         :ok <- validate_profile_activation(profile),
         {:ok, updated_profile} <-
           ProfileRepository.update_profile(profile_id, %{
             is_active: true,
             activated_at: DateTime.utc_now()
           }) do
      Logger.info("Enabled surveillance profile: #{profile_id}")
      {:ok, updated_profile}
    end
  end

  @doc """
  Disable a surveillance profile.
  """
  def disable_profile(profile_id) do
    with {:ok, _profile} <- ProfileRepository.get_profile(profile_id),
         {:ok, updated_profile} <-
           ProfileRepository.update_profile(profile_id, %{
             is_active: false,
             deactivated_at: DateTime.utc_now()
           }) do
      Logger.info("Disabled surveillance profile: #{profile_id}")
      {:ok, updated_profile}
    end
  end

  @doc """
  Get profile statistics and usage metrics.
  """
  def get_profile_statistics(profile_id) do
    with {:ok, profile} <- ProfileRepository.get_profile(profile_id),
         {:ok, stats} <- ProfileRepository.get_profile_statistics(profile_id) do
      enhanced_stats = %{
        profile_id: profile_id,
        profile_name: profile.name,
        is_active: profile.is_active,
        created_at: profile.created_at,
        activated_at: profile.activated_at,
        total_matches: stats.total_matches,
        matches_last_24h: stats.matches_last_24h,
        matches_last_7d: stats.matches_last_7d,
        matches_last_30d: stats.matches_last_30d,
        average_matches_per_day: stats.average_matches_per_day,
        last_match_at: stats.last_match_at,
        criteria_effectiveness: calculate_criteria_effectiveness(stats)
      }

      {:ok, enhanced_stats}
    end
  end

  @doc """
  Clone an existing profile with modifications.
  """
  def clone_profile(source_profile_id, clone_data) do
    with {:ok, source_profile} <- ProfileRepository.get_profile(source_profile_id),
         {:ok, clone_config} <- prepare_clone_config(source_profile, clone_data),
         {:ok, cloned_profile} <- create_profile(clone_config) do
      Logger.info("Cloned surveillance profile #{source_profile_id} to #{cloned_profile.id}")
      {:ok, cloned_profile}
    end
  end

  @doc """
  Archive old inactive profiles.
  """
  def archive_inactive_profiles(inactive_days \\ 90) do
    current_time = DateTime.utc_now()
    cutoff_date = DateTime.add(current_time, -inactive_days * 24 * 3600, :second)

    with {:ok, inactive_profiles} <- ProfileRepository.get_inactive_profiles_before(cutoff_date),
         {:ok, archived_count} <-
           ProfileRepository.archive_profiles(Enum.map(inactive_profiles, & &1.id)) do
      Logger.info("Archived #{archived_count} inactive surveillance profiles")
      {:ok, archived_count}
    end
  end

  # Private validation functions

  defp validate_create_data(profile_data) do
    with :ok <- validate_required_create_fields(profile_data),
         :ok <- validate_profile_name_uniqueness(profile_data.name, profile_data.user_id),
         :ok <- validate_criteria_complexity(profile_data.criteria),
         :ok <- validate_user_profile_limits(profile_data.user_id) do
      # Set default values
      default_data = %{
        is_active: false,
        created_at: DateTime.utc_now(),
        match_count: 0,
        last_match_at: nil
      }

      {:ok, Map.merge(default_data, profile_data)}
    end
  end

  defp validate_update_data(updates, existing_profile) do
    with :ok <- validate_allowed_update_fields(updates),
         :ok <- validate_name_change(updates, existing_profile),
         :ok <- validate_criteria_change(updates, existing_profile) do
      # Add update timestamp
      {:ok, Map.put(updates, :updated_at, DateTime.utc_now())}
    end
  end

  defp validate_required_create_fields(profile_data) do
    required_fields = [:name, :criteria, :user_id]

    missing_fields =
      Enum.filter(required_fields, fn field ->
        not Map.has_key?(profile_data, field) or is_nil(profile_data[field])
      end)

    case missing_fields do
      [] -> :ok
      fields -> {:error, {:missing_required_fields, fields}}
    end
  end

  defp validate_profile_name_uniqueness(name, user_id) do
    case ProfileRepository.get_profile_by_name_and_user(name, user_id) do
      {:ok, nil} -> :ok
      {:ok, _existing_profile} -> {:error, :profile_name_exists}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_criteria_complexity(criteria) do
    # Validate that criteria are not too complex (performance consideration)
    complexity_score = calculate_criteria_complexity(criteria)

    cond do
      complexity_score > 100 -> {:error, :criteria_too_complex}
      complexity_score == 0 -> {:error, :criteria_too_simple}
      true -> :ok
    end
  end

  defp validate_user_profile_limits(user_id) do
    {:ok, user_profile_count} = ProfileRepository.count_user_profiles(user_id)
    # Configurable limit
    max_profiles_per_user = 50

    if user_profile_count >= max_profiles_per_user do
      {:error, {:profile_limit_exceeded, max_profiles_per_user}}
    else
      :ok
    end
  end

  defp validate_profile_deletion(profile) do
    # Check if profile has recent matches that would be lost
    if profile.match_count > 0 do
      Logger.warning("Deleting profile #{profile.id} with #{profile.match_count} matches")
    end

    :ok
  end

  defp validate_profile_activation(profile) do
    # Validate that criteria are still valid before activation
    case MatchingEngine.validate_criteria(profile.criteria) do
      {:ok, :valid} -> :ok
      {:error, reason} -> {:error, {:invalid_criteria_for_activation, reason}}
    end
  end

  defp validate_allowed_update_fields(updates) do
    allowed_fields = [:name, :criteria, :notification_config, :is_active, :description]
    provided_fields = Map.keys(updates)

    invalid_fields = Enum.reject(provided_fields, fn field -> field in allowed_fields end)

    case invalid_fields do
      [] -> :ok
      fields -> {:error, {:invalid_update_fields, fields}}
    end
  end

  defp validate_name_change(updates, existing_profile) do
    case Map.get(updates, :name) do
      # No name change
      nil -> :ok
      # Same name
      new_name when new_name == existing_profile.name -> :ok
      new_name -> validate_profile_name_uniqueness(new_name, existing_profile.user_id)
    end
  end

  defp validate_criteria_change(updates, existing_profile) do
    case Map.get(updates, :criteria) do
      # No criteria change
      nil ->
        :ok

      new_criteria ->
        with :ok <- validate_criteria_complexity(new_criteria) do
          # Log criteria change for audit
          Logger.info("Criteria changed for profile #{existing_profile.id}")
          :ok
        end
    end
  end

  # Helper functions

  defp calculate_criteria_complexity(criteria) do
    base_complexity = 1

    # Add complexity based on criteria type and configuration
    type_complexity =
      case criteria.type do
        :character_watch -> length(criteria.character_ids || [])
        :corporation_watch -> length(criteria.corporation_ids || [])
        :system_watch -> length(criteria.system_ids || [])
        :ship_type_watch -> length(criteria.ship_type_ids || [])
        :alliance_watch -> length(criteria.alliance_ids || [])
        # Custom criteria are more complex
        :custom_criteria -> length(criteria.conditions || []) * 2
        _ -> 1
      end

    # Add complexity for additional filters
    base_filter_complexity = 0

    isk_filter_complexity =
      if Map.get(criteria, :isk_value_filter),
        do: base_filter_complexity + 2,
        else: base_filter_complexity

    time_filter_complexity =
      if Map.get(criteria, :time_filter),
        do: isk_filter_complexity + 1,
        else: isk_filter_complexity

    filter_complexity =
      if Map.get(criteria, :location_filter),
        do: time_filter_complexity + 3,
        else: time_filter_complexity

    base_complexity + type_complexity + filter_complexity
  end

  defp calculate_criteria_effectiveness(stats) do
    # Calculate how effective the criteria are at generating useful matches
    total_matches = stats.total_matches

    cond do
      total_matches == 0 -> 0.0
      # Low effectiveness - too restrictive
      total_matches < 10 -> 0.3
      # Low effectiveness - too broad
      total_matches > 1000 -> 0.2
      # Optimal around 100 matches
      true -> 1.0 - abs(total_matches - 100) / 100
    end
  end

  defp prepare_clone_config(source_profile, clone_data) do
    base_config = %{
      name: clone_data[:name] || "#{source_profile.name} (Copy)",
      criteria: source_profile.criteria,
      user_id: clone_data[:user_id] || source_profile.user_id,
      notification_config: source_profile.notification_config,
      description: clone_data[:description] || source_profile.description
    }

    # Apply any modifications from clone_data
    modified_config =
      Map.merge(
        base_config,
        Map.take(clone_data, [:criteria, :notification_config, :description])
      )

    {:ok, modified_config}
  end
end
