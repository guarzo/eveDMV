# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
defmodule EveDmv.Surveillance.MatchingEngine do
  use GenServer

    alias EveDmv.Surveillance.Matching.IndexManager
    alias EveDmv.Surveillance.Profile
  alias EveDmv.Api
  alias EveDmv.Surveillance.Matching.MatchEvaluator
  alias EveDmv.Surveillance.Matching.ProfileCompiler

  require Logger
  @moduledoc """
  High-performance killmail matching engine for surveillance profiles.

  This module implements the core matching logic with ETS-based inverted indexes
  for efficient filtering of large numbers of active profiles.

  ## Architecture

  1. **Profile Compilation**: Filter trees are compiled to fast anonymous functions
  2. **Inverted Indexes**: ETS tables map field values to candidate profile IDs
  3. **Candidate Filtering**: Only profiles that could match are evaluated
  4. **Match Recording**: Successful matches are logged and notifications sent

  ## Performance

  - Supports 1000+ active profiles with minimal overhead
  - Sub-millisecond candidate lookup via ETS indexes
  - Parallel evaluation for maximum throughput
  """


  # Performance tuning constants
  @batch_record_interval 5_000
  @match_cache_ttl 60_000

  # Public API

  @doc """
  Start the matching engine GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      # 15 seconds for batch processing
      shutdown: 15_000
    }
  end

  @doc """
  Match a killmail against all active surveillance profiles.

  Returns a list of profile IDs that matched the killmail.
  """
  @spec match_killmail(map()) :: [String.t()]
  def match_killmail(killmail) do
    GenServer.call(__MODULE__, {:match_killmail, killmail}, 10_000)
  end

  @doc """
  Reload all active profiles from the database.
  Called when profiles are created, updated, or deleted.
  """
  @spec reload_profiles() :: :ok
  def reload_profiles do
    GenServer.cast(__MODULE__, :reload_profiles)
  end

  @doc """
  Get statistics about the matching engine.
  """
  @spec get_stats() :: map()
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # GenServer callbacks

  @impl GenServer
  def init(opts) do
    Logger.info("Starting surveillance matching engine")

    # Create ETS tables
    IndexManager.create_ets_tables()

    # Load active profiles
    state = %{
      profiles_loaded: 0,
      matches_processed: 0,
      last_reload: DateTime.utc_now(),
      pending_matches: [],
      last_batch_record: System.monotonic_time(:millisecond)
    }

    # Initial profile load - delay slightly to allow database to be ready
    profiles_count =
      if Mix.env() == :test do
        # In test environment, skip initial load
        0
      else
        # Schedule a delayed load in production/dev
        Process.send_after(self(), :initial_profile_load, 1000)
        0
      end

    # Schedule periodic batch recording
    schedule_batch_recording()

    {:ok, %{state | profiles_loaded: profiles_count}}
  end

  @impl GenServer
  def handle_call({:match_killmail, killmail}, _from, state) do
    start_time = System.monotonic_time(:microsecond)

    try do
      # Validate killmail structure
      case MatchEvaluator.validate_killmail(killmail) do
        {:ok, validated_killmail} ->
          {matches, new_state} = perform_matching(validated_killmail, start_time, state)
          {:reply, matches, new_state}

        {:error, reason} ->
          Logger.warning("Invalid killmail: #{reason}")
          {:reply, [], state}
      end
    rescue
      error ->
        Logger.error("Error matching killmail: #{inspect(error)}")
        {:reply, [], state}
    end
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    table_stats = IndexManager.get_table_stats()

    stats = %{
      profiles_loaded: state.profiles_loaded,
      matches_processed: state.matches_processed,
      last_reload: state.last_reload,
      pending_matches: length(state.pending_matches),
      last_batch_record: state.last_batch_record,
      cache_stats: %{
        size: table_stats.match_cache,
        hit_rate: MatchEvaluator.calculate_cache_hit_rate()
      },
      ets_tables: table_stats
    }

    {:reply, stats, state}
  end

  @impl GenServer
  def handle_cast(:reload_profiles, state) do
    Logger.info("Reloading surveillance profiles")
    profiles_count = load_active_profiles()

    new_state = %{
      state
      | profiles_loaded: profiles_count,
        last_reload: DateTime.utc_now()
    }

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(:batch_record_matches, state) do
    # Process pending matches in batch
    if length(state.pending_matches) > 0 do
      Logger.info("📝 Recording batch of #{length(state.pending_matches)} surveillance matches")

      # Record matches asynchronously to avoid blocking
      Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
        MatchEvaluator.record_matches_batch(state.pending_matches)
      end)

      # Update match frequency metadata
      IndexManager.update_profile_metadata(state.pending_matches)
    end

    # Clean up expired cache entries
    IndexManager.cleanup_expired_cache()

    # Schedule next batch recording
    schedule_batch_recording()

    new_state = %{
      state
      | pending_matches: [],
        last_batch_record: System.monotonic_time(:millisecond)
    }

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(:initial_profile_load, state) do
    Logger.info("Performing initial surveillance profile load")
    profiles_count = load_active_profiles()
    {:noreply, %{state | profiles_loaded: profiles_count}}
  end

  @impl GenServer
  def handle_info(msg, state) do
    Logger.debug("Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private functions

  defp schedule_batch_recording do
    Process.send_after(self(), :batch_record_matches, @batch_record_interval)
  end

  defp perform_matching(killmail, start_time, state) do
    # Check cache first for recent identical killmails
    cache_key = MatchEvaluator.generate_cache_key(killmail)

    case IndexManager.get_cached_match(cache_key) do
      {:ok, cached_matches} ->
        # Cache hit - return cached result
        {cached_matches, %{state | matches_processed: state.matches_processed + 1}}

      {:error, :not_found} ->
        # Cache miss - perform matching
        candidates = IndexManager.find_candidate_profiles_optimized(killmail)
        matches = MatchEvaluator.evaluate_candidates_parallel(candidates, killmail)

        # Cache the result
        IndexManager.cache_match_result(cache_key, matches, @match_cache_ttl * 1000)

        # Add matches to pending batch instead of immediate recording
        new_pending =
          state.pending_matches ++
            Enum.map(matches, &{&1, killmail, DateTime.utc_now()})

        # Emit telemetry
        MatchEvaluator.emit_matching_telemetry(start_time, length(candidates), length(matches))

        new_state = %{
          state
          | matches_processed: state.matches_processed + 1,
            pending_matches: new_pending
        }

        {matches, new_state}
    end
  end

  defp load_active_profiles do
    # Clear existing data
    IndexManager.clear_all_tables()

    # Load active profiles from database
    try do
      case Ash.read(Profile, action: :active_profiles, domain: Api) do
        {:ok, profiles} ->
          Enum.each(profiles, &process_profile/1)
          length(profiles)

        {:error, error} ->
          Logger.error("Failed to load surveillance profiles: #{inspect(error)}")
          0
      end
    rescue
      error ->
        # Handle database not ready errors gracefully during startup
        Logger.warning("Database may not be ready yet, skipping profile load: #{inspect(error)}")
        0
    end
  end

  defp process_profile(profile) do
    # Compile filter tree to anonymous function
    case ProfileCompiler.compile_filter_tree(profile.filter_tree) do
      {:ok, compiled_fn} ->
        # Store compiled function
        IndexManager.store_compiled_profile(profile.id, compiled_fn, profile.name)

        # Build inverted indexes
        IndexManager.build_indexes_for_profile(profile)

        Logger.debug("Compiled profile #{profile.name} (#{profile.id})")

      {:error, reason} ->
        Logger.error("Failed to compile profile #{profile.name}: #{reason}")
    end
  end
end
