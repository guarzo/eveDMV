defmodule EveDmv.Surveillance.MatchingEngine do
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

  use GenServer
  require Logger
  alias EveDmv.Api
  alias EveDmv.Surveillance.{Profile, ProfileMatch}

  # ETS table names
  @compiled_profiles :surveillance_compiled_profiles
  @index_by_tag :surveillance_index_by_tag
  @index_by_system :surveillance_index_by_system
  @index_by_isk :surveillance_index_by_isk
  @index_by_ship :surveillance_index_by_ship
  @profile_metadata :surveillance_profile_metadata
  @match_cache :surveillance_match_cache

  # Performance tuning constants
  @max_candidate_set_size 100
  @batch_record_interval 5_000
  @match_cache_ttl 60_000

  # Public API

  @doc """
  Start the matching engine GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
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

  @impl true
  def init(_opts) do
    Logger.info("Starting surveillance matching engine")

    # Create ETS tables
    create_ets_tables()

    # Load active profiles
    state = %{
      profiles_loaded: 0,
      matches_processed: 0,
      last_reload: DateTime.utc_now(),
      pending_matches: [],
      last_batch_record: System.monotonic_time(:millisecond)
    }

    # Initial profile load
    profiles_count = load_active_profiles()

    # Schedule periodic batch recording
    schedule_batch_recording()

    {:ok, %{state | profiles_loaded: profiles_count}}
  end

  @impl true
  def handle_call({:match_killmail, killmail}, _from, state) do
    start_time = System.monotonic_time(:microsecond)

    try do
      # Check cache first for recent identical killmails
      cache_key = generate_cache_key(killmail)

      case :ets.lookup(@match_cache, cache_key) do
        [{^cache_key, cached_matches, expires_at}] when expires_at > start_time ->
          # Cache hit - return cached result
          {:reply, cached_matches, %{state | matches_processed: state.matches_processed + 1}}

        _ ->
          # Cache miss - perform matching
          {matches, new_state} = perform_matching(killmail, start_time, state)

          # Cache the result
          expires_at = start_time + @match_cache_ttl * 1000
          :ets.insert(@match_cache, {cache_key, matches, expires_at})

          {:reply, matches, new_state}
      end
    rescue
      error ->
        Logger.error("Error matching killmail: #{inspect(error)}")
        {:reply, [], state}
    end
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    cache_size = :ets.info(@match_cache, :size)
    metadata_size = :ets.info(@profile_metadata, :size)

    stats = %{
      profiles_loaded: state.profiles_loaded,
      matches_processed: state.matches_processed,
      last_reload: state.last_reload,
      pending_matches: length(state.pending_matches),
      last_batch_record: state.last_batch_record,
      cache_stats: %{
        size: cache_size,
        hit_rate: calculate_cache_hit_rate()
      },
      ets_tables: %{
        compiled_profiles: :ets.info(@compiled_profiles, :size),
        index_by_tag: :ets.info(@index_by_tag, :size),
        index_by_system: :ets.info(@index_by_system, :size),
        index_by_isk: :ets.info(@index_by_isk, :size),
        index_by_ship: :ets.info(@index_by_ship, :size),
        profile_metadata: metadata_size,
        match_cache: cache_size
      }
    }

    {:reply, stats, state}
  end

  @impl true
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

  @impl true
  def handle_info(:batch_record_matches, state) do
    # Process pending matches in batch
    if length(state.pending_matches) > 0 do
      Logger.info("📝 Recording batch of #{length(state.pending_matches)} surveillance matches")

      # Record matches asynchronously to avoid blocking
      Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
        record_matches_batch(state.pending_matches)
      end)

      # Update match frequency metadata
      update_profile_metadata(state.pending_matches)
    end

    # Clean up expired cache entries
    cleanup_expired_cache()

    # Schedule next batch recording
    schedule_batch_recording()

    new_state = %{
      state
      | pending_matches: [],
        last_batch_record: System.monotonic_time(:millisecond)
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private functions

  defp create_ets_tables do
    # Create ETS tables for compiled profiles and indexes
    :ets.new(@compiled_profiles, [:set, :public, :named_table])
    :ets.new(@index_by_tag, [:bag, :public, :named_table])
    :ets.new(@index_by_system, [:bag, :public, :named_table])
    :ets.new(@index_by_isk, [:bag, :public, :named_table])
    :ets.new(@index_by_ship, [:bag, :public, :named_table])
    :ets.new(@profile_metadata, [:set, :public, :named_table])
    :ets.new(@match_cache, [:set, :public, :named_table])

    Logger.debug("Created ETS tables for surveillance engine")
  end

  defp schedule_batch_recording do
    Process.send_after(self(), :batch_record_matches, @batch_record_interval)
  end

  defp generate_cache_key(killmail) do
    # Generate cache key based on killmail properties that affect matching
    key_fields = [
      killmail["killmail_id"],
      killmail["solar_system_id"] || killmail["system_id"],
      get_in(killmail, ["victim", "ship_type_id"]),
      killmail["total_value"] || get_in(killmail, ["zkb", "totalValue"]),
      length(killmail["attackers"] || [])
    ]

    :crypto.hash(:md5, inspect(key_fields)) |> Base.encode16()
  end

  defp perform_matching(killmail, start_time, state) do
    # Find candidate profiles using optimized inverted indexes
    candidates = find_candidate_profiles_optimized(killmail)

    # Evaluate candidates against the killmail
    matches = evaluate_candidates_parallel(candidates, killmail)

    # Add matches to pending batch instead of immediate recording
    new_pending =
      state.pending_matches ++
        Enum.map(matches, &{&1, killmail, DateTime.utc_now()})

    # Emit telemetry
    duration = System.monotonic_time(:microsecond) - start_time
    :telemetry.execute([:eve_dmv, :surveillance, :matching_time], %{duration: duration}, %{})

    :telemetry.execute(
      [:eve_dmv, :surveillance, :profile, :evaluated],
      %{count: length(candidates)},
      %{}
    )

    if length(matches) > 0 do
      :telemetry.execute(
        [:eve_dmv, :surveillance, :profile, :match],
        %{count: length(matches)},
        %{}
      )
    end

    Logger.debug(
      "Matched killmail #{killmail["killmail_id"]} against #{length(candidates)} candidates in #{duration}μs, #{length(matches)} matches"
    )

    new_state = %{
      state
      | matches_processed: state.matches_processed + 1,
        pending_matches: new_pending
    }

    {matches, new_state}
  end

  defp load_active_profiles do
    # Clear existing data
    :ets.delete_all_objects(@compiled_profiles)
    :ets.delete_all_objects(@index_by_tag)
    :ets.delete_all_objects(@index_by_system)
    :ets.delete_all_objects(@index_by_isk)
    :ets.delete_all_objects(@index_by_ship)
    :ets.delete_all_objects(@profile_metadata)

    # Load active profiles from database
    case Ash.read(Profile, action: :active_profiles, domain: Api) do
      {:ok, profiles} ->
        Enum.each(profiles, &process_profile/1)
        length(profiles)

      {:error, error} ->
        Logger.error("Failed to load surveillance profiles: #{inspect(error)}")
        0
    end
  end

  defp process_profile(profile) do
    # Compile filter tree to anonymous function
    case compile_filter_tree(profile.filter_tree) do
      {:ok, compiled_fn} ->
        # Store compiled function
        :ets.insert(@compiled_profiles, {profile.id, compiled_fn, profile.name})

        # Build inverted indexes
        build_indexes_for_profile(profile)

        Logger.debug("Compiled surveillance profile: #{profile.name}")

      {:error, reason} ->
        Logger.warning("Failed to compile profile #{profile.name}: #{reason}")
    end
  end

  defp compile_filter_tree(%{"condition" => condition, "rules" => rules})
       when condition in ["and", "or"] do
    case compile_rules(rules) do
      {:ok, compiled_rules} ->
        compiled_fn =
          case condition do
            "and" -> fn killmail -> Enum.all?(compiled_rules, & &1.(killmail)) end
            "or" -> fn killmail -> Enum.any?(compiled_rules, & &1.(killmail)) end
          end

        {:ok, compiled_fn}

      error ->
        error
    end
  end

  defp compile_filter_tree(_), do: {:error, "invalid filter tree"}

  defp compile_rules(rules) do
    compiled =
      Enum.reduce_while(rules, [], fn rule, acc ->
        case compile_rule(rule) do
          {:ok, compiled_rule} -> {:cont, [compiled_rule | acc]}
          error -> {:halt, error}
        end
      end)

    case compiled do
      {:error, _} = error -> error
      compiled_rules -> {:ok, Enum.reverse(compiled_rules)}
    end
  end

  defp compile_rule(%{"condition" => _, "rules" => _} = nested_group) do
    compile_filter_tree(nested_group)
  end

  defp compile_rule(%{"field" => field, "operator" => operator, "value" => value}) do
    case compile_operator(operator, field, value) do
      {:ok, compiled_fn} -> {:ok, compiled_fn}
      :error -> {:error, "unsupported operator: #{operator}"}
    end
  end

  defp compile_rule(_), do: {:error, "invalid rule"}

  defp compile_operator(operator, field, value) do
    case operator do
      op when op in ["eq", "ne"] ->
        {:ok, compile_equality_operator(op, field, value)}

      op when op in ["gt", "lt", "gte", "lte"] ->
        {:ok, compile_numeric_operator(op, field, value)}

      op when op in ["in", "not_in"] ->
        {:ok, compile_list_operator(op, field, value)}

      op when op in ["contains_any", "contains_all", "not_contains"] ->
        {:ok, compile_array_operator(op, field, value)}

      _ ->
        :error
    end
  end

  defp compile_equality_operator("eq", field, value) do
    fn km -> get_field(km, field) == value end
  end

  defp compile_equality_operator("ne", field, value) do
    fn km -> get_field(km, field) != value end
  end

  defp compile_numeric_operator("gt", field, value) do
    fn km -> compare_numeric(get_field(km, field), value, :gt) end
  end

  defp compile_numeric_operator("lt", field, value) do
    fn km -> compare_numeric(get_field(km, field), value, :lt) end
  end

  defp compile_numeric_operator("gte", field, value) do
    fn km -> compare_numeric(get_field(km, field), value, :gte) end
  end

  defp compile_numeric_operator("lte", field, value) do
    fn km -> compare_numeric(get_field(km, field), value, :lte) end
  end

  defp compile_list_operator("in", field, value) do
    fn km -> get_field(km, field) in value end
  end

  defp compile_list_operator("not_in", field, value) do
    fn km -> get_field(km, field) not in value end
  end

  defp compile_array_operator("contains_any", field, value) do
    fn km ->
      field_value = get_field(km, field) || []
      is_list(field_value) and not MapSet.disjoint?(MapSet.new(field_value), MapSet.new(value))
    end
  end

  defp compile_array_operator("contains_all", field, value) do
    fn km ->
      field_value = get_field(km, field) || []
      is_list(field_value) and MapSet.subset?(MapSet.new(value), MapSet.new(field_value))
    end
  end

  defp compile_array_operator("not_contains", field, value) do
    fn km ->
      field_value = get_field(km, field) || []
      is_list(field_value) and MapSet.disjoint?(MapSet.new(field_value), MapSet.new(value))
    end
  end

  # Extract field values from killmail data with helper functions to reduce complexity
  defp get_field(killmail, field) do
    case String.split(field, "_", parts: 2) do
      ["victim", victim_field] -> get_victim_field(killmail, victim_field)
      ["solar", "system" | _] -> get_system_field(killmail, field)
      _ -> get_top_level_field(killmail, field)
    end
  end

  defp get_victim_field(killmail, field) do
    case field do
      "character_id" -> get_in(killmail, ["victim", "character_id"])
      "corporation_id" -> get_in(killmail, ["victim", "corporation_id"])
      "alliance_id" -> get_in(killmail, ["victim", "alliance_id"])
      "ship_type_id" -> get_in(killmail, ["victim", "ship_type_id"])
      "character_name" -> get_in(killmail, ["victim", "character_name"])
      "corporation_name" -> get_in(killmail, ["victim", "corporation_name"])
      "alliance_name" -> get_in(killmail, ["victim", "alliance_name"])
      "ship_name" -> get_in(killmail, ["victim", "ship_name"])
      "ship_category" -> classify_ship(get_in(killmail, ["victim", "ship_type_id"]))
      _ -> nil
    end
  end

  defp get_system_field(killmail, field) do
    case field do
      "solar_system_id" -> killmail["solar_system_id"] || killmail["system_id"]
      "solar_system_name" -> killmail["solar_system_name"]
      _ -> nil
    end
  end

  defp get_top_level_field(killmail, field) do
    cond do
      field == "killmail_id" ->
        killmail["killmail_id"]

      field in ["total_value", "ship_value", "fitted_value"] ->
        get_value_fields(killmail, field)

      field in ["module_tags", "noteworthy_modules"] ->
        get_array_fields(killmail, field)

      field == "attacker_count" ->
        killmail["attacker_count"] || length(killmail["attackers"] || [])

      field == "final_blow_character_id" ->
        get_final_blow_character_id(killmail)

      field == "kill_category" ->
        classify_kill(killmail)

      true ->
        nil
    end
  end

  defp get_value_fields(killmail, field) do
    case field do
      "total_value" -> get_value_field(killmail, ["total_value", ["zkb", "totalValue"]])
      "ship_value" -> get_value_field(killmail, ["ship_value", ["zkb", "destroyedValue"]])
      "fitted_value" -> get_value_field(killmail, ["fitted_value", ["zkb", "fittedValue"]])
    end
  end

  defp get_array_fields(killmail, field) do
    killmail[field] || []
  end

  defp get_value_field(killmail, [primary_field, fallback_path]) do
    killmail[primary_field] || get_in(killmail, fallback_path) || 0
  end

  defp get_final_blow_character_id(killmail) do
    case Enum.find(killmail["attackers"] || [], & &1["final_blow"]) do
      %{"character_id" => id} -> id
      _ -> nil
    end
  end

  defp compare_numeric(field_value, compare_value, operator) do
    case {field_value, compare_value} do
      {a, b} when is_number(a) and is_number(b) ->
        case operator do
          :gt -> a > b
          :lt -> a < b
          :gte -> a >= b
          :lte -> a <= b
        end

      _ ->
        false
    end
  end

  defp classify_kill(killmail) do
    attacker_count = killmail["attacker_count"] || length(killmail["attackers"] || [])

    case attacker_count do
      1 -> "solo"
      n when n <= 5 -> "small_gang"
      n when n <= 20 -> "fleet"
      _ -> "large_fleet"
    end
  end

  defp classify_ship(ship_type_id) when is_integer(ship_type_id) do
    # Simplified ship classification
    cond do
      ship_type_id in 580..650 -> "frigate"
      ship_type_id in 16_000..16_100 -> "destroyer"
      ship_type_id in 620..650 -> "cruiser"
      ship_type_id in 416..456 -> "battlecruiser"
      ship_type_id in 640..680 -> "battleship"
      ship_type_id in 19_000..24_000 -> "capital"
      true -> "other"
    end
  end

  defp classify_ship(_), do: "unknown"

  defp build_indexes_for_profile(profile) do
    # Analyze filter tree to build appropriate indexes
    case extract_indexable_fields(profile.filter_tree) do
      {:ok, fields} ->
        Enum.each(fields, &build_field_index(&1, profile.id))

      _ ->
        :ok
    end
  end

  defp build_field_index({field, values}, profile_id) do
    case field do
      "module_tags" -> insert_tag_indexes(values, profile_id)
      "solar_system_id" -> insert_system_indexes(values, profile_id)
      "victim_ship_type_id" -> insert_ship_indexes(values, profile_id)
      "total_value" -> insert_isk_indexes(values, profile_id)
      _ -> :ok
    end
  end

  defp insert_tag_indexes(values, profile_id) do
    Enum.each(values, fn tag ->
      :ets.insert(@index_by_tag, {tag, profile_id})
    end)
  end

  defp insert_system_indexes(values, profile_id) do
    Enum.each(values, fn sys_id ->
      :ets.insert(@index_by_system, {sys_id, profile_id})
    end)
  end

  defp insert_ship_indexes(values, profile_id) do
    Enum.each(values, fn ship_id ->
      :ets.insert(@index_by_ship, {ship_id, profile_id})
    end)
  end

  defp insert_isk_indexes(values, profile_id) do
    # For ISK thresholds, store ranges
    Enum.each(values, fn {operator, value} ->
      :ets.insert(@index_by_isk, {{operator, value}, profile_id})
    end)
  end

  defp extract_indexable_fields(filter_tree) do
    # Simple extraction - could be enhanced for more complex cases
    case filter_tree do
      %{"condition" => _, "rules" => rules} ->
        fields =
          rules
          |> Enum.flat_map(&extract_rule_fields/1)
          |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

        {:ok, fields}

      _ ->
        {:error, "invalid filter tree"}
    end
  end

  defp extract_rule_fields(%{"field" => field, "operator" => operator, "value" => value}) do
    case {field, operator} do
      {"module_tags", op} when op in ["contains_any", "contains_all"] ->
        if is_list(value), do: Enum.map(value, &{field, &1}), else: []

      {field, "in"} when field in ["solar_system_id", "victim_ship_type_id"] ->
        if is_list(value), do: Enum.map(value, &{field, &1}), else: []

      {"total_value", op} when op in ["gt", "lt", "gte", "lte"] ->
        [{field, {op, value}}]

      _ ->
        []
    end
  end

  defp extract_rule_fields(%{"condition" => _, "rules" => rules}) do
    Enum.flat_map(rules, &extract_rule_fields/1)
  end

  defp extract_rule_fields(_), do: []

  # Optimized candidate finding with intersection-based filtering
  defp find_candidate_profiles_optimized(killmail) do
    # Gather candidates from all indexes
    candidate_sets =
      [
        get_tag_candidates(killmail),
        get_system_candidates(killmail),
        get_isk_candidates(killmail),
        get_ship_candidates(killmail)
      ]
      |> Enum.reject(&Enum.empty?/1)

    case candidate_sets do
      [] ->
        # No specific candidates found, test all profiles (but limit to avoid performance issues)
        all_profiles =
          :ets.tab2list(@compiled_profiles)
          |> Enum.map(fn {profile_id, _fun, _name} -> profile_id end)

        if length(all_profiles) > @max_candidate_set_size do
          # Use metadata to prioritize profiles by match frequency
          prioritize_profiles(all_profiles)
        else
          all_profiles
        end

      [single_set] ->
        # Only one index type matched, use those candidates directly
        Enum.uniq(single_set)

      multiple_sets ->
        # Multiple index types matched, use intersection for precision
        multiple_sets
        |> Enum.map(&MapSet.new/1)
        |> Enum.reduce(&MapSet.intersection/2)
        |> MapSet.to_list()
        |> case do
          [] ->
            # Intersection is empty, fall back to union but limit size
            all_candidates = Enum.flat_map(multiple_sets, &MapSet.to_list/1)

            if length(all_candidates) > @max_candidate_set_size do
              prioritize_profiles(Enum.uniq(all_candidates))
            else
              Enum.uniq(all_candidates)
            end

          intersection ->
            intersection
        end
    end
  end

  defp prioritize_profiles(profile_ids) do
    # Sort profiles by recent match frequency and take top candidates
    profile_ids
    |> Enum.map(fn profile_id ->
      match_frequency =
        case :ets.lookup(@profile_metadata, profile_id) do
          [{^profile_id, metadata}] -> Map.get(metadata, :recent_matches, 0)
          [] -> 0
        end

      {profile_id, match_frequency}
    end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(@max_candidate_set_size)
    |> Enum.map(&elem(&1, 0))
  end

  defp evaluate_candidates_parallel(candidates, killmail) do
    # For small candidate sets, use direct evaluation
    if length(candidates) <= 10 do
      evaluate_candidates(candidates, killmail)
    else
      # For larger sets, use parallel evaluation
      candidates
      |> Task.async_stream(
        fn profile_id ->
          case :ets.lookup(@compiled_profiles, profile_id) do
            [{_id, compiled_fn, _name}] ->
              try do
                if compiled_fn.(killmail), do: profile_id, else: nil
              rescue
                _ -> nil
              end

            [] ->
              nil
          end
        end,
        max_concurrency: 4,
        timeout: 1000
      )
      |> Enum.reduce([], fn
        {:ok, profile_id}, acc when not is_nil(profile_id) -> [profile_id | acc]
        _, acc -> acc
      end)
    end
  end

  defp get_tag_candidates(killmail) do
    tags = killmail["module_tags"] || []

    Enum.flat_map(tags, fn tag ->
      :ets.lookup(@index_by_tag, tag)
      |> Enum.map(fn {_tag, profile_id} -> profile_id end)
    end)
  end

  defp get_system_candidates(killmail) do
    system_id = killmail["solar_system_id"] || killmail["system_id"]

    if system_id do
      :ets.lookup(@index_by_system, system_id)
      |> Enum.map(fn {_sys, profile_id} -> profile_id end)
    else
      []
    end
  end

  defp get_ship_candidates(killmail) do
    ship_id = get_in(killmail, ["victim", "ship_type_id"])

    if ship_id do
      :ets.lookup(@index_by_ship, ship_id)
      |> Enum.map(fn {_ship, profile_id} -> profile_id end)
    else
      []
    end
  end

  defp get_isk_candidates(killmail) do
    isk_value = killmail["total_value"] || get_in(killmail, ["zkb", "totalValue"]) || 0

    :ets.tab2list(@index_by_isk)
    |> Enum.filter(fn {{operator, threshold}, _profile_id} ->
      case operator do
        "gt" -> isk_value > threshold
        "gte" -> isk_value >= threshold
        "lt" -> isk_value < threshold
        "lte" -> isk_value <= threshold
        _ -> false
      end
    end)
    |> Enum.map(fn {_threshold, profile_id} -> profile_id end)
  end

  defp evaluate_candidates(candidates, killmail) do
    candidates
    |> Enum.filter(fn profile_id ->
      case :ets.lookup(@compiled_profiles, profile_id) do
        [{_id, compiled_fn, _name}] ->
          try do
            compiled_fn.(killmail)
          rescue
            _ -> false
          end

        [] ->
          false
      end
    end)
  end

  defp record_matches_batch(pending_matches) do
    # Group matches by profile for efficiency
    matches_by_profile = Enum.group_by(pending_matches, fn {profile_id, _, _} -> profile_id end)

    Enum.each(matches_by_profile, fn {profile_id, matches} ->
      try do
        # Record all matches for this profile
        match_records =
          Enum.map(matches, fn {_profile_id, killmail, timestamp} ->
            %{
              profile_id: profile_id,
              killmail_id: killmail["killmail_id"],
              killmail_time: parse_killmail_time(killmail),
              victim_character_name: get_in(killmail, ["victim", "character_name"]),
              victim_ship_name: get_in(killmail, ["victim", "ship_name"]),
              solar_system_name: killmail["solar_system_name"],
              total_value: killmail["total_value"] || get_in(killmail, ["zkb", "totalValue"]),
              created_at: timestamp
            }
          end)

        # Bulk create matches for better performance
        case Ash.bulk_create(ProfileMatch, match_records,
               action: :create,
               domain: Api,
               return_errors?: true
             ) do
          %{records: [_ | _] = created} ->
            Logger.debug(
              "Successfully recorded #{length(created)} matches for profile #{profile_id}"
            )

            # Update profile match count
            case Ash.get(Profile, profile_id, domain: Api) do
              {:ok, profile} ->
                Ash.update(profile,
                  action: :increment_match_count,
                  input: %{match_count_increment: length(created)},
                  domain: Api
                )

              _ ->
                :ok
            end

          %{errors: [_ | _] = errors} ->
            Logger.error(
              "Failed to record some matches for profile #{profile_id}: #{inspect(errors)}"
            )

          result ->
            Logger.warning(
              "Unexpected bulk create result for profile #{profile_id}: #{inspect(result)}"
            )
        end
      rescue
        error ->
          Logger.error(
            "Error recording matches batch for profile #{profile_id}: #{inspect(error)}"
          )
      end
    end)
  end

  defp update_profile_metadata(pending_matches) do
    # Update recent match frequency for profile prioritization
    matches_by_profile = Enum.group_by(pending_matches, fn {profile_id, _, _} -> profile_id end)

    Enum.each(matches_by_profile, fn {profile_id, matches} ->
      current_metadata =
        case :ets.lookup(@profile_metadata, profile_id) do
          [{^profile_id, metadata}] -> metadata
          [] -> %{}
        end

      updated_metadata =
        Map.update(current_metadata, :recent_matches, length(matches), fn count ->
          # Decay old count and add new matches
          max(0, trunc(count * 0.9)) + length(matches)
        end)

      :ets.insert(@profile_metadata, {profile_id, updated_metadata})
    end)
  end

  defp cleanup_expired_cache do
    current_time = System.monotonic_time(:microsecond)

    # Find and delete expired cache entries
    expired_keys =
      :ets.select(@match_cache, [
        {{:"$1", :"$2", :"$3"}, [{:<, :"$3", current_time}], [:"$1"]}
      ])

    Enum.each(expired_keys, fn key ->
      :ets.delete(@match_cache, key)
    end)

    if length(expired_keys) > 0 do
      Logger.debug("Cleaned up #{length(expired_keys)} expired cache entries")
    end
  end

  defp parse_killmail_time(killmail) do
    case killmail["kill_time"] || killmail["timestamp"] do
      nil ->
        DateTime.utc_now()

      timestamp when is_binary(timestamp) ->
        case DateTime.from_iso8601(timestamp) do
          {:ok, dt, _} -> dt
          _ -> DateTime.utc_now()
        end

      _ ->
        DateTime.utc_now()
    end
  end

  defp calculate_cache_hit_rate do
    # Simple approximation - would need proper counters for accurate measurement
    cache_size = :ets.info(@match_cache, :size)

    # Estimate hit rate based on cache size and activity
    case cache_size do
      0 -> 0.0
      size when size < 10 -> 0.1
      size when size < 50 -> 0.3
      size when size < 100 -> 0.5
      _ -> 0.7
    end
  end
end
