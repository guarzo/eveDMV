defmodule EveDmv.Contexts.Surveillance.Infrastructure.MatchCache do
  use EveDmv.ErrorHandler
  use GenServer

  alias EveDmv.Result

  require Logger
  @moduledoc """
  High-performance cache for surveillance matches.

  Provides fast storage and retrieval of surveillance matches with
  automatic expiration and statistical aggregation.
  """



  # Cache configuration
  # 30 days
  @default_ttl_seconds 30 * 24 * 3600
  # 5 minutes
  @cleanup_interval 5 * 60 * 1000
  # Per profile limit
  @max_matches_per_profile 10_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Public API

  @doc """
  Store a surveillance match in the cache.
  """
  def store_match(match) do
    GenServer.cast(__MODULE__, {:store_match, match})
  end

  @doc """
  Get recent matches across all profiles.
  """
  def get_recent_matches(limit \\ 50, since \\ nil, profile_id \\ nil) do
    GenServer.call(__MODULE__, {:get_recent_matches, limit, since, profile_id})
  end

  @doc """
  Get matches for a specific profile.
  """
  def get_profile_matches(profile_id, limit \\ 50, since \\ nil) do
    GenServer.call(__MODULE__, {:get_profile_matches, profile_id, limit, since})
  end

  @doc """
  Get detailed information about a specific match.
  """
  def get_match_details(match_id) do
    GenServer.call(__MODULE__, {:get_match_details, match_id})
  end

  @doc """
  Get match statistics for a profile.
  """
  def get_match_statistics(profile_id, time_range \\ :last_30d) do
    GenServer.call(__MODULE__, {:get_match_statistics, profile_id, time_range})
  end

  @doc """
  Clear all matches for a profile.
  """
  def clear_profile_matches(profile_id) do
    GenServer.call(__MODULE__, {:clear_profile_matches, profile_id})
  end

  @doc """
  Get cache statistics and metrics.
  """
  def get_cache_metrics do
    GenServer.call(__MODULE__, :get_cache_metrics)
  end

  # GenServer implementation

  @impl GenServer
  def init(opts) do
    state = %{
      # match_id -> match_data
      matches: %{},
      # profile_id -> [match_ids] (ordered by timestamp)
      profile_matches: %{},
      # [match_ids] (ordered by timestamp, global)
      recent_matches: [],
      # profile_id -> aggregated_stats
      match_statistics: %{},
      cache_metrics: %{
        total_matches: 0,
        profiles_with_matches: 0,
        memory_usage_bytes: 0,
        last_cleanup: DateTime.utc_now()
      }
    }

    # Schedule periodic cleanup
    schedule_cleanup()

    Logger.info("MatchCache started")
    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:store_match, match}, state) do
    match_id = match.id

    # Store match with expiration timestamp
    enriched_match =
      Map.put(match, :expires_at, DateTime.add(DateTime.utc_now(), @default_ttl_seconds, :second))

    new_matches = Map.put(state.matches, match_id, enriched_match)

    # Add to profile matches (maintain order)
    profile_id = match.profile_id
    current_profile_matches = Map.get(state.profile_matches, profile_id, [])

    # Add new match and limit size
    new_profile_matches =
      Enum.take([match_id | current_profile_matches], @max_matches_per_profile)

    updated_profile_matches = Map.put(state.profile_matches, profile_id, new_profile_matches)

    # Add to recent matches (global)
    new_recent_matches =
      # Keep last 1000 recent matches
      Enum.take([match_id | state.recent_matches], 1000)

    # Update statistics
    new_statistics = update_match_statistics(state.match_statistics, match)

    # Update cache metrics
    new_metrics = %{
      state.cache_metrics
      | total_matches: state.cache_metrics.total_matches + 1,
        profiles_with_matches: map_size(updated_profile_matches)
    }

    new_state = %{
      state
      | matches: new_matches,
        profile_matches: updated_profile_matches,
        recent_matches: new_recent_matches,
        match_statistics: new_statistics,
        cache_metrics: new_metrics
    }

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_call({:get_recent_matches, limit, since, profile_id_filter}, _from, state) do
    # Start with recent matches or profile-specific matches
    candidate_match_ids =
      if profile_id_filter do
        Map.get(state.profile_matches, profile_id_filter, [])
      else
        state.recent_matches
      end

    # Filter and limit matches
    filtered_matches =
      candidate_match_ids
      # Take more to account for filtering
      |> Enum.take(limit * 2)
      |> Enum.map(&Map.get(state.matches, &1))
      |> Enum.filter(&(&1 != nil))
      |> filter_matches_by_time(since)
      |> Enum.take(limit)

    {:reply, {:ok, filtered_matches}, state}
  end

  @impl GenServer
  def handle_call({:get_profile_matches, profile_id, limit, since}, _from, state) do
    profile_match_ids = Map.get(state.profile_matches, profile_id, [])

    profile_matches =
      profile_match_ids
      # Take more to account for filtering
      |> Enum.take(limit * 2)
      |> Enum.map(&Map.get(state.matches, &1))
      |> Enum.filter(&(&1 != nil))
      |> filter_matches_by_time(since)
      |> Enum.take(limit)

    {:reply, {:ok, profile_matches}, state}
  end

  @impl GenServer
  def handle_call({:get_match_details, match_id}, _from, state) do
    case Map.get(state.matches, match_id) do
      nil -> {:reply, {:error, :match_not_found}, state}
      match -> {:reply, {:ok, match}, state}
    end
  end

  @impl GenServer
  def handle_call({:get_match_statistics, profile_id, time_range}, _from, state) do
    profile_stats = Map.get(state.match_statistics, profile_id, %{})

    # Calculate time-range specific statistics
    time_filtered_stats = calculate_time_range_statistics(state, profile_id, time_range)

    combined_stats = Map.merge(profile_stats, time_filtered_stats)

    {:reply, {:ok, combined_stats}, state}
  end

  @impl GenServer
  def handle_call({:clear_profile_matches, profile_id}, _from, state) do
    # Get profile match IDs to remove
    profile_match_ids = Map.get(state.profile_matches, profile_id, [])

    # Remove matches from main storage
    new_matches =
      Enum.reduce(profile_match_ids, state.matches, fn match_id, acc ->
        Map.delete(acc, match_id)
      end)

    # Remove profile from profile matches
    new_profile_matches = Map.delete(state.profile_matches, profile_id)

    # Remove from recent matches
    new_recent_matches =
      Enum.reject(state.recent_matches, fn match_id ->
        match_id in profile_match_ids
      end)

    # Remove from statistics
    new_statistics = Map.delete(state.match_statistics, profile_id)

    # Update metrics
    new_metrics = %{
      state.cache_metrics
      | total_matches: map_size(new_matches),
        profiles_with_matches: map_size(new_profile_matches)
    }

    new_state = %{
      state
      | matches: new_matches,
        profile_matches: new_profile_matches,
        recent_matches: new_recent_matches,
        match_statistics: new_statistics,
        cache_metrics: new_metrics
    }

    Logger.info("Cleared #{length(profile_match_ids)} matches for profile #{profile_id}")

    {:reply, {:ok, length(profile_match_ids)}, new_state}
  end

  @impl GenServer
  def handle_call(:get_cache_metrics, _from, state) do
    # Calculate current memory usage (approximation)
    memory_usage =
      :erlang.external_size(state.matches) +
        :erlang.external_size(state.profile_matches) +
        :erlang.external_size(state.recent_matches)

    metrics = %{
      state.cache_metrics
      | memory_usage_bytes: memory_usage,
        profiles_with_matches: map_size(state.profile_matches),
        total_matches: map_size(state.matches)
    }

    {:reply, {:ok, metrics}, state}
  end

  @impl GenServer
  def handle_info(:cleanup_expired, state) do
    current_time = DateTime.utc_now()

    # Find expired matches
    {expired_matches, active_matches} =
      Enum.split_with(state.matches, fn {_match_id, match} ->
        DateTime.compare(match.expires_at, current_time) == :lt
      end)

    expired_match_ids =
      MapSet.new(Enum.map(expired_matches, fn {match_id, _match} -> match_id end))

    # Clean up expired matches from all structures
    new_matches = Map.new(active_matches)

    new_profile_matches =
      Map.new(state.profile_matches, fn {profile_id, match_ids} ->
        filtered_ids = Enum.reject(match_ids, &MapSet.member?(expired_match_ids, &1))
        {profile_id, filtered_ids}
      end)

    new_recent_matches = Enum.reject(state.recent_matches, &MapSet.member?(expired_match_ids, &1))

    # Update statistics to remove expired data points
    new_statistics = clean_expired_statistics(state.match_statistics, expired_match_ids)

    expired_count = length(expired_matches)

    if expired_count > 0 do
      Logger.info("Cleaned up #{expired_count} expired matches from cache")
    end

    # Update metrics
    new_metrics = %{
      state.cache_metrics
      | total_matches: map_size(new_matches),
        profiles_with_matches: map_size(new_profile_matches),
        last_cleanup: current_time
    }

    # Schedule next cleanup
    schedule_cleanup()

    new_state = %{
      state
      | matches: new_matches,
        profile_matches: new_profile_matches,
        recent_matches: new_recent_matches,
        match_statistics: new_statistics,
        cache_metrics: new_metrics
    }

    {:noreply, new_state}
  end

  # Private helper functions

  defp filter_matches_by_time(matches, nil), do: matches

  defp filter_matches_by_time(matches, since) do
    Enum.filter(matches, fn match ->
      DateTime.compare(match.timestamp, since) == :gt
    end)
  end

  defp update_match_statistics(current_statistics, match) do
    profile_id = match.profile_id
    profile_stats = Map.get(current_statistics, profile_id, initialize_profile_statistics())

    updated_stats = %{
      profile_stats
      | total_matches: profile_stats.total_matches + 1,
        last_match_at: match.timestamp,
        confidence_scores: [
          match.confidence_score | Enum.take(profile_stats.confidence_scores, 99)
        ],
        match_types: update_match_type_counts(profile_stats.match_types, match.matched_criteria),
        hourly_distribution:
          update_hourly_distribution(profile_stats.hourly_distribution, match.timestamp)
    }

    Map.put(current_statistics, profile_id, updated_stats)
  end

  defp initialize_profile_statistics do
    %{
      total_matches: 0,
      last_match_at: nil,
      confidence_scores: [],
      match_types: %{},
      hourly_distribution: %{},
      daily_counts: %{}
    }
  end

  defp update_match_type_counts(current_counts, matched_criteria) do
    Enum.reduce(matched_criteria, current_counts, fn criterion, acc ->
      type = criterion.type
      Map.update(acc, type, 1, &(&1 + 1))
    end)
  end

  defp update_hourly_distribution(current_distribution, timestamp) do
    hour = timestamp |> DateTime.to_time() |> Map.get(:hour)
    Map.update(current_distribution, hour, 1, &(&1 + 1))
  end

  defp calculate_time_range_statistics(state, profile_id, time_range) do
    cutoff_time =
      case time_range do
        :last_hour -> DateTime.add(DateTime.utc_now(), -3600, :second)
        :last_24h -> DateTime.add(DateTime.utc_now(), -24 * 3600, :second)
        :last_7d -> DateTime.add(DateTime.utc_now(), -7 * 24 * 3600, :second)
        :last_30d -> DateTime.add(DateTime.utc_now(), -30 * 24 * 3600, :second)
        {start_time, _end_time} -> start_time
      end

    profile_match_ids = Map.get(state.profile_matches, profile_id, [])

    time_filtered_matches =
      profile_match_ids
      |> Enum.map(&Map.get(state.matches, &1))
      |> Enum.filter(&(&1 != nil))
      |> filter_matches_by_time(cutoff_time)

    %{
      matches_in_range: length(time_filtered_matches),
      time_range: time_range,
      average_confidence: calculate_average_confidence(time_filtered_matches),
      match_rate: calculate_match_rate(time_filtered_matches, time_range)
    }
  end

  defp calculate_average_confidence([]), do: 0.0

  defp calculate_average_confidence(matches) do
    confidence_sum = Enum.sum(Enum.map(matches, & &1.confidence_score))
    confidence_sum / length(matches)
  end

  defp calculate_match_rate(matches, time_range) do
    match_count = length(matches)

    hours_in_range =
      case time_range do
        :last_hour -> 1
        :last_24h -> 24
        :last_7d -> 7 * 24
        :last_30d -> 30 * 24
        # Default
        _ -> 24
      end

    match_count / hours_in_range
  end

  defp clean_expired_statistics(statistics, _expired_match_ids) do
    # In a more complete implementation, this would remove specific
    # data points from statistics. For now, we'll keep statistics as-is
    # since they're aggregated
    statistics
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_expired, @cleanup_interval)
  end
end
