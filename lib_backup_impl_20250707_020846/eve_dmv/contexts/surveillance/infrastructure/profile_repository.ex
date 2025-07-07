defmodule EveDmv.Contexts.Surveillance.Infrastructure.ProfileRepository do
  @moduledoc """
  Data access layer for surveillance profiles.

  Provides persistence and retrieval operations for surveillance profiles
  using Ash framework resources.
  """

  alias EveDmv.Result
  use EveDmv.ErrorHandler
  require Logger

  # This would typically use an Ash resource, but for this implementation
  # we'll use a simplified in-memory store with GenServer
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Public API

  @doc """
  Create a new surveillance profile.
  """
  def create_profile(profile_data) do
    GenServer.call(__MODULE__, {:create_profile, profile_data})
  end

  @doc """
  Update an existing surveillance profile.
  """
  def update_profile(profile_id, updates) do
    GenServer.call(__MODULE__, {:update_profile, profile_id, updates})
  end

  @doc """
  Delete a surveillance profile.
  """
  def delete_profile(profile_id) do
    GenServer.call(__MODULE__, {:delete_profile, profile_id})
  end

  @doc """
  Get a surveillance profile by ID.
  """
  def get_profile(profile_id) do
    GenServer.call(__MODULE__, {:get_profile, profile_id})
  end

  @doc """
  Get a profile by name and user ID.
  """
  def get_profile_by_name_and_user(name, user_id) do
    GenServer.call(__MODULE__, {:get_profile_by_name_and_user, name, user_id})
  end

  @doc """
  List surveillance profiles with filtering options.
  """
  def list_profiles(opts \\ []) do
    GenServer.call(__MODULE__, {:list_profiles, opts})
  end

  @doc """
  Get all active profiles for matching.
  """
  def get_active_profiles do
    GenServer.call(__MODULE__, :get_active_profiles)
  end

  @doc """
  Count profiles for a user.
  """
  def count_user_profiles(user_id) do
    GenServer.call(__MODULE__, {:count_user_profiles, user_id})
  end

  @doc """
  Get profile statistics.
  """
  def get_profile_statistics(profile_id) do
    GenServer.call(__MODULE__, {:get_profile_statistics, profile_id})
  end

  @doc """
  Get inactive profiles before a certain date.
  """
  def get_inactive_profiles_before(cutoff_date) do
    GenServer.call(__MODULE__, {:get_inactive_profiles_before, cutoff_date})
  end

  @doc """
  Archive multiple profiles.
  """
  def archive_profiles(profile_ids) do
    GenServer.call(__MODULE__, {:archive_profiles, profile_ids})
  end

  # GenServer implementation

  @impl GenServer
  def init(opts) do
    state = %{
      # profile_id -> profile_data
      profiles: %{},
      next_id: 1,
      # profile_id -> stats
      statistics: %{}
    }

    Logger.info("ProfileRepository started")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:create_profile, profile_data}, _from, state) do
    profile_id = generate_profile_id(state.next_id)

    profile = %{
      id: profile_id,
      name: profile_data.name,
      criteria: profile_data.criteria,
      user_id: profile_data.user_id,
      notification_config: profile_data[:notification_config] || %{},
      description: profile_data[:description],
      is_active: profile_data[:is_active] || false,
      is_archived: false,
      match_count: 0,
      created_at: profile_data[:created_at] || DateTime.utc_now(),
      updated_at: DateTime.utc_now(),
      activated_at: profile_data[:activated_at],
      deactivated_at: profile_data[:deactivated_at],
      last_match_at: nil
    }

    new_profiles = Map.put(state.profiles, profile_id, profile)

    # Initialize statistics
    new_statistics =
      Map.put(state.statistics, profile_id, %{
        total_matches: 0,
        matches_last_24h: 0,
        matches_last_7d: 0,
        matches_last_30d: 0,
        average_matches_per_day: 0.0,
        last_match_at: nil
      })

    new_state = %{
      state
      | profiles: new_profiles,
        statistics: new_statistics,
        next_id: state.next_id + 1
    }

    {:reply, {:ok, profile}, new_state}
  end

  @impl GenServer
  def handle_call({:update_profile, profile_id, updates}, _from, state) do
    case Map.get(state.profiles, profile_id) do
      nil ->
        {:reply, {:error, :profile_not_found}, state}

      existing_profile ->
        updated_profile =
          Map.merge(existing_profile, Map.put(updates, :updated_at, DateTime.utc_now()))

        new_profiles = Map.put(state.profiles, profile_id, updated_profile)

        new_state = %{state | profiles: new_profiles}

        {:reply, {:ok, updated_profile}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:delete_profile, profile_id}, _from, state) do
    case Map.get(state.profiles, profile_id) do
      nil ->
        {:reply, {:error, :profile_not_found}, state}

      _profile ->
        new_profiles = Map.delete(state.profiles, profile_id)
        new_statistics = Map.delete(state.statistics, profile_id)

        new_state = %{
          state
          | profiles: new_profiles,
            statistics: new_statistics
        }

        {:reply, {:ok, :deleted}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:get_profile, profile_id}, _from, state) do
    case Map.get(state.profiles, profile_id) do
      nil -> {:reply, {:error, :profile_not_found}, state}
      profile -> {:reply, {:ok, profile}, state}
    end
  end

  @impl GenServer
  def handle_call({:get_profile_by_name_and_user, name, user_id}, _from, state) do
    matching_profile =
      state.profiles
      |> Map.values()
      |> Enum.find(fn profile ->
        profile.name == name and profile.user_id == user_id and not profile.is_archived
      end)

    result =
      case matching_profile do
        nil -> {:ok, nil}
        profile -> {:ok, profile}
      end

    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:list_profiles, opts}, _from, state) do
    user_id = Keyword.get(opts, :user_id)
    active_only = Keyword.get(opts, :active_only, true)
    limit = Keyword.get(opts, :limit)
    offset = Keyword.get(opts, :offset, 0)

    filtered_profiles =
      state.profiles
      |> Map.values()
      |> Enum.filter(fn profile ->
        user_match = is_nil(user_id) or profile.user_id == user_id
        active_match = not active_only or profile.is_active
        archived_match = not profile.is_archived

        user_match and active_match and archived_match
      end)
      |> Enum.sort_by(& &1.updated_at, {:desc, DateTime})
      |> Enum.drop(offset)

    limited_profiles =
      if limit do
        Enum.take(filtered_profiles, limit)
      else
        filtered_profiles
      end

    {:reply, {:ok, limited_profiles}, state}
  end

  @impl GenServer
  def handle_call(:get_active_profiles, _from, state) do
    active_profiles =
      state.profiles
      |> Map.values()
      |> Enum.filter(fn profile ->
        profile.is_active and not profile.is_archived
      end)

    {:reply, {:ok, active_profiles}, state}
  end

  @impl GenServer
  def handle_call({:count_user_profiles, user_id}, _from, state) do
    count =
      state.profiles
      |> Map.values()
      |> Enum.count(fn profile ->
        profile.user_id == user_id and not profile.is_archived
      end)

    {:reply, {:ok, count}, state}
  end

  @impl GenServer
  def handle_call({:get_profile_statistics, profile_id}, _from, state) do
    case Map.get(state.statistics, profile_id) do
      nil -> {:reply, {:error, :profile_not_found}, state}
      stats -> {:reply, {:ok, stats}, state}
    end
  end

  @impl GenServer
  def handle_call({:get_inactive_profiles_before, cutoff_date}, _from, state) do
    inactive_profiles =
      state.profiles
      |> Map.values()
      |> Enum.filter(fn profile ->
        # Profile is inactive and last updated before cutoff
        not profile.is_active and
          not profile.is_archived and
          DateTime.compare(profile.updated_at, cutoff_date) == :lt
      end)

    {:reply, {:ok, inactive_profiles}, state}
  end

  @impl GenServer
  def handle_call({:archive_profiles, profile_ids}, _from, state) do
    {new_profiles, archived_count} =
      Enum.reduce(profile_ids, {state.profiles, 0}, fn profile_id, {profiles_acc, count_acc} ->
        case Map.get(profiles_acc, profile_id) do
          nil ->
            {profiles_acc, count_acc}

          profile ->
            archived_profile = %{profile | is_archived: true, updated_at: DateTime.utc_now()}
            {Map.put(profiles_acc, profile_id, archived_profile), count_acc + 1}
        end
      end)

    new_state = %{state | profiles: new_profiles}

    {:reply, {:ok, archived_count}, new_state}
  end

  # Match statistics update (called from MatchingEngine)
  def update_match_statistics(profile_id, match_data) do
    GenServer.cast(__MODULE__, {:update_match_statistics, profile_id, match_data})
  end

  @impl GenServer
  def handle_cast({:update_match_statistics, profile_id, match_data}, state) do
    # Update profile match count and last match time
    new_profiles =
      case Map.get(state.profiles, profile_id) do
        nil ->
          state.profiles

        profile ->
          updated_profile = %{
            profile
            | match_count: profile.match_count + 1,
              last_match_at: match_data.timestamp,
              updated_at: DateTime.utc_now()
          }

          Map.put(state.profiles, profile_id, updated_profile)
      end

    # Update statistics
    new_statistics =
      case Map.get(state.statistics, profile_id) do
        nil ->
          state.statistics

        stats ->
          current_time = DateTime.utc_now()

          updated_stats = %{
            stats
            | total_matches: stats.total_matches + 1,
              matches_last_24h:
                calculate_matches_in_period(profile_id, state, current_time, 24 * 3600),
              matches_last_7d:
                calculate_matches_in_period(profile_id, state, current_time, 7 * 24 * 3600),
              matches_last_30d:
                calculate_matches_in_period(profile_id, state, current_time, 30 * 24 * 3600),
              last_match_at: match_data.timestamp
          }

          # Calculate average matches per day
          profile = Map.get(new_profiles, profile_id)
          days_since_creation = DateTime.diff(current_time, profile.created_at, :day)

          average_matches_per_day =
            if days_since_creation > 0 do
              updated_stats.total_matches / days_since_creation
            else
              0.0
            end

          %{updated_stats | average_matches_per_day: average_matches_per_day}

          Map.put(state.statistics, profile_id, updated_stats)
      end

    new_state = %{
      state
      | profiles: new_profiles,
        statistics: new_statistics
    }

    {:noreply, new_state}
  end

  # Private helper functions

  defp generate_profile_id(next_id) do
    "profile_#{next_id}_#{System.unique_integer()}"
  end

  defp calculate_matches_in_period(_profile_id, _state, _current_time, _period_seconds) do
    # In a real implementation, this would query actual match records
    # For this simplified implementation, we'll return a placeholder
    0
  end
end
