defmodule EveDmv.Database.SurveillanceRepository do
  @moduledoc """
  Repository for surveillance profile operations.

  Provides optimized database access for surveillance profiles, matches,
  and related data with proper preloading and caching.
  """

  use EveDmv.Database.Repository,
    resource: EveDmv.Surveillance.Profile,
    cache_type: :hot_data

  alias EveDmv.Api
  alias EveDmv.Surveillance.Profile

  @doc """
  Load all surveillance profiles for a user with preloaded matches.
  """
  @spec get_user_profiles(integer(), any()) :: [Profile.t()] | []
  def get_user_profiles(user_id, actor \\ nil) do
    cache_key = {:user_profiles, user_id}

    case Cache.get(@cache_type, cache_key) do
      {:ok, profiles} ->
        profiles

      :miss ->
        query =
          Profile
          |> Ash.Query.new()
          |> Ash.Query.for_read(:user_profiles, %{user_id: user_id})
          |> Ash.Query.load(:matches)

        case Ash.read(query, domain: EveDmv.Api, actor: actor) do
          {:ok, profiles} ->
            Cache.put(@cache_type, cache_key, profiles, ttl: :timer.minutes(5))
            profiles

          {:error, reason} ->
            Logger.warning("Failed to load user profiles: #{inspect(reason)}")
            []
        end
    end
  end

  @doc """
  Create a new surveillance profile.
  """
  @spec create_profile(map(), any()) :: {:ok, Profile.t()} | {:error, any()}
  def create_profile(attrs, actor \\ nil) do
    changeset = Ash.Changeset.for_create(Profile, :create, attrs)
    result = Ash.create(changeset, domain: Api, actor: actor)

    case result do
      {:ok, profile} ->
        # Invalidate user profiles cache
        if user_id = Map.get(attrs, :user_id) do
          Cache.delete(@cache_type, {:user_profiles, user_id})
        end

        {:ok, profile}

      error ->
        error
    end
  end

  @doc """
  Update an existing surveillance profile.
  """
  @spec update_profile(Profile.t(), map(), any()) :: {:ok, Profile.t()} | {:error, any()}
  def update_profile(profile, attrs, actor \\ nil) do
    changeset = Ash.Changeset.for_update(profile, :update, attrs)
    result = Ash.update(changeset, domain: Api, actor: actor)

    case result do
      {:ok, updated_profile} ->
        # Invalidate related caches
        invalidate_profile_caches(updated_profile)
        {:ok, updated_profile}

      error ->
        error
    end
  end

  @doc """
  Delete a surveillance profile.
  """
  @spec delete_profile(Profile.t(), any()) :: :ok | {:error, any()}
  def delete_profile(profile, actor \\ nil) do
    changeset = Ash.Changeset.for_destroy(profile, :destroy)
    result = Ash.destroy(changeset, domain: Api, actor: actor)

    case result do
      :ok ->
        invalidate_profile_caches(profile)
        :ok

      error ->
        error
    end
  end

  @doc """
  Get active profiles for monitoring.
  """
  @spec get_active_profiles() :: [Profile.t()]
  def get_active_profiles do
    cache_key = :active_profiles

    case Cache.get(@cache_type, cache_key) do
      {:ok, profiles} ->
        profiles

      :miss ->
        query =
          Profile
          |> Ash.Query.new()
          |> Ash.Query.for_read(:active)
          |> Ash.Query.load([:matches, :filters])

        case Ash.read(query, domain: EveDmv.Api) do
          {:ok, profiles} ->
            Cache.put(@cache_type, cache_key, profiles, ttl: :timer.minutes(2))
            profiles

          {:error, reason} ->
            Logger.warning("Failed to load active profiles: #{inspect(reason)}")
            []
        end
    end
  end

  @doc """
  Get profiles that match specific criteria for batch processing.
  """
  @spec get_profiles_for_matching([map()]) :: [Profile.t()]
  def get_profiles_for_matching(criteria_list) when is_list(criteria_list) do
    # For now, get all active profiles and filter in memory
    # This could be optimized with more specific queries later
    Enum.filter(get_active_profiles(), fn profile ->
      Enum.any?(criteria_list, &profile_matches_criteria?(profile, &1))
    end)
  end

  @doc """
  Batch update match results for multiple profiles.
  """
  @spec batch_update_matches([{Profile.t(), [map()]}]) :: :ok
  def batch_update_matches(profile_matches) when is_list(profile_matches) do
    # This would ideally use a database transaction
    Enum.each(profile_matches, fn {profile, matches} ->
      # Update matches for each profile
      # Implementation depends on how matches are stored
      Logger.debug("Updating #{length(matches)} matches for profile #{profile.id}")
    end)

    # Invalidate active profiles cache since matches changed
    Cache.delete(@cache_type, :active_profiles)
    :ok
  end

  # Private helper functions

  defp invalidate_profile_caches(profile) do
    # Invalidate user-specific cache
    if profile.user_id do
      Cache.delete(@cache_type, {:user_profiles, profile.user_id})
    end

    # Invalidate active profiles cache
    Cache.delete(@cache_type, :active_profiles)

    :ok
  end

  defp profile_matches_criteria?(_profile, _criteria) do
    # Implement matching logic based on profile configuration
    # This is a placeholder - actual implementation would depend on
    # how profile matching criteria are structured
    true
  end
end
