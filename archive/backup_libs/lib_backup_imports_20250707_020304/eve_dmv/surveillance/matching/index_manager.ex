defmodule EveDmv.Surveillance.Matching.IndexManager do
  alias EveDmv.Surveillance.Matching.KillmailFieldExtractor

  require Logger
  @moduledoc """
  ETS index management for surveillance profile matching.

  This module manages the creation, population, and querying of inverted indexes
  that enable efficient candidate profile lookup during killmail matching.
  """



  # ETS table names
  @compiled_profiles :surveillance_compiled_profiles
  @index_by_tag :surveillance_index_by_tag
  @index_by_system :surveillance_index_by_system
  @index_by_isk :surveillance_index_by_isk
  @index_by_ship :surveillance_index_by_ship
  @profile_metadata :surveillance_profile_metadata
  @match_cache :surveillance_match_cache

  @doc """
  Create all ETS tables needed for surveillance matching.
  """
  def create_ets_tables do
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

  @doc """
  Clear all ETS table data.
  """
  def clear_all_tables do
    :ets.delete_all_objects(@compiled_profiles)
    :ets.delete_all_objects(@index_by_tag)
    :ets.delete_all_objects(@index_by_system)
    :ets.delete_all_objects(@index_by_isk)
    :ets.delete_all_objects(@index_by_ship)
    :ets.delete_all_objects(@profile_metadata)
  end

  @doc """
  Store a compiled profile in the main profiles table.
  """
  def store_compiled_profile(profile_id, compiled_fn, profile_name) do
    :ets.insert(@compiled_profiles, {profile_id, compiled_fn, profile_name})
  end

  @doc """
  Build inverted indexes for a profile based on its filter tree.
  """
  def build_indexes_for_profile(profile) do
    # Extract indexable criteria from filter tree
    indexable_criteria = extract_indexable_criteria(profile.filter_tree)

    # Build indexes for each criterion
    Enum.each(indexable_criteria, fn {field, values} ->
      build_field_index(profile.id, field, values)
    end)

    # Store profile metadata
    :ets.insert(@profile_metadata, {
      profile.id,
      %{
        profile_id: profile.id,
        name: profile.name,
        created_by: profile.created_by,
        last_matched: nil,
        match_count: 0
      }
    })
  end

  @doc """
  Find candidate profiles using optimized inverted indexes.

  Returns a list of profile IDs that could potentially match the killmail.
  """
  def find_candidate_profiles_optimized(killmail) do
    # Extract values from killmail for index lookup
    indexable_values =
      KillmailFieldExtractor.extract_indexable_values(killmail)

    # Find candidates from each index
    candidates_by_system = find_candidates_by_system(indexable_values.systems)
    candidates_by_ship = find_candidates_by_ship(indexable_values.ships)
    candidates_by_isk = find_candidates_by_isk(indexable_values.isk_values)
    candidates_by_tag = find_candidates_by_tag(indexable_values.tags)

    # Combine and deduplicate candidates
    all_candidates =
      [
        candidates_by_system,
        candidates_by_ship,
        candidates_by_isk,
        candidates_by_tag
      ]
      |> List.flatten()
      |> Enum.uniq()

    # If no index-based candidates found, return all profiles
    # This ensures new or complex filters aren't missed
    case all_candidates do
      [] -> get_all_profile_ids()
      candidates -> candidates
    end
  end

  @doc """
  Get all available profile IDs from the compiled profiles table.
  """
  def get_all_profile_ids do
    :ets.tab2list(@compiled_profiles)
    |> Enum.map(fn {profile_id, _fn, _name} -> profile_id end)
  end

  @doc """
  Get a compiled profile function by ID.
  """
  def get_compiled_profile(profile_id) do
    case :ets.lookup(@compiled_profiles, profile_id) do
      [{^profile_id, compiled_fn, _name}] -> {:ok, compiled_fn}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Update profile metadata after a successful match.
  """
  def update_profile_metadata(profile_matches) do
    Enum.each(profile_matches, fn {profile_id, _killmail, _timestamp} ->
      case :ets.lookup(@profile_metadata, profile_id) do
        [{profile_id, metadata}] ->
          updated_metadata = %{
            metadata
            | last_matched: DateTime.utc_now(),
              match_count: metadata.match_count + 1
          }

          :ets.insert(@profile_metadata, {profile_id, updated_metadata})

        [] ->
          # Profile metadata doesn't exist, create it
          :ets.insert(@profile_metadata, {
            profile_id,
            %{
              last_matched: DateTime.utc_now(),
              match_count: 1
            }
          })
      end
    end)
  end

  @doc """
  Get ETS table statistics for monitoring.
  """
  def get_table_stats do
    %{
      compiled_profiles: :ets.info(@compiled_profiles, :size),
      index_by_tag: :ets.info(@index_by_tag, :size),
      index_by_system: :ets.info(@index_by_system, :size),
      index_by_isk: :ets.info(@index_by_isk, :size),
      index_by_ship: :ets.info(@index_by_ship, :size),
      profile_metadata: :ets.info(@profile_metadata, :size),
      match_cache: :ets.info(@match_cache, :size)
    }
  end

  # Cache management

  @doc """
  Store a match result in the cache.
  """
  def cache_match_result(cache_key, matches, ttl_microseconds) do
    expires_at = System.monotonic_time(:microsecond) + ttl_microseconds
    :ets.insert(@match_cache, {cache_key, matches, expires_at})
  end

  @doc """
  Get a cached match result if still valid.
  """
  def get_cached_match(cache_key) do
    current_time = System.monotonic_time(:microsecond)

    case :ets.lookup(@match_cache, cache_key) do
      [{^cache_key, cached_matches, expires_at}] when expires_at > current_time ->
        {:ok, cached_matches}

      _ ->
        {:error, :not_found}
    end
  end

  @doc """
  Clean up expired cache entries.
  """
  def cleanup_expired_cache do
    current_time = System.monotonic_time(:microsecond)

    expired_keys =
      :ets.tab2list(@match_cache)
      |> Enum.filter(fn {_key, _matches, expires_at} -> expires_at <= current_time end)
      |> Enum.map(fn {key, _matches, _expires_at} -> key end)

    Enum.each(expired_keys, fn key ->
      :ets.delete(@match_cache, key)
    end)

    length(expired_keys)
  end

  # Private helper functions

  defp extract_indexable_criteria(filter_tree) do
    # Recursively walk the filter tree to find indexable criteria
    criteria = extract_criteria_from_node(filter_tree)

    criteria
    |> List.flatten()
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  defp extract_criteria_from_node(%{
         "type" => "rule",
         "field" => field,
         "operator" => "eq",
         "value" => value
       }) do
    if KillmailFieldExtractor.indexable_field?(field) do
      [{field, value}]
    else
      []
    end
  end

  defp extract_criteria_from_node(%{
         "type" => "rule",
         "field" => field,
         "operator" => "in",
         "value" => values
       })
       when is_list(values) do
    if KillmailFieldExtractor.indexable_field?(field) do
      Enum.map(values, fn value -> {field, value} end)
    else
      []
    end
  end

  defp extract_criteria_from_node(%{"type" => type, "children" => children})
       when type in ["and", "or"] and is_list(children) do
    Enum.flat_map(children, &extract_criteria_from_node/1)
  end

  defp extract_criteria_from_node(_), do: []

  defp build_field_index(profile_id, field, values) when is_list(values) do
    Enum.each(values, fn value ->
      build_field_index(profile_id, field, value)
    end)
  end

  defp build_field_index(profile_id, field, value) do
    index_table = KillmailFieldExtractor.get_index_type(field)

    if index_table do
      :ets.insert(index_table, {value, profile_id})
    end
  end

  defp find_candidates_by_system(systems) do
    Enum.flat_map(systems, fn system_id ->
      system_lookup = :ets.lookup(@index_by_system, system_id)
      Enum.map(system_lookup, fn {_system, profile_id} -> profile_id end)
    end)
  end

  defp find_candidates_by_ship(ships) do
    Enum.flat_map(ships, fn ship_id ->
      ship_lookup = :ets.lookup(@index_by_ship, ship_id)
      Enum.map(ship_lookup, fn {_ship, profile_id} -> profile_id end)
    end)
  end

  defp find_candidates_by_isk(isk_values) do
    # For ISK values, we need range-based lookup
    # This is simplified - production would use more sophisticated range indexing
    Enum.flat_map(isk_values, fn isk_value ->
      isk_list = :ets.tab2list(@index_by_isk)

      isk_list
      |> Enum.filter(fn {indexed_value, _profile_id} ->
        # 10% tolerance
        abs(indexed_value - isk_value) < isk_value * 0.1
      end)
      |> Enum.map(fn {_isk, profile_id} -> profile_id end)
    end)
  end

  defp find_candidates_by_tag(tags) do
    Enum.flat_map(tags, fn tag ->
      lookup_results = :ets.lookup(@index_by_tag, tag)
      Enum.map(lookup_results, fn {_tag, profile_id} -> profile_id end)
    end)
  end
end
