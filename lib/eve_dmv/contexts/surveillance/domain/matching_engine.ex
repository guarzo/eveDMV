# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
defmodule EveDmv.Contexts.Surveillance.Domain.MatchingEngine do
  @moduledoc """
  Core matching engine for surveillance profiles.

  This module handles the real-time matching of killmail data against
  surveillance profiles, providing fast and efficient profile matching
  with comprehensive criteria support.
  """

  use GenServer
  use EveDmv.ErrorHandler
  alias EveDmv.Contexts.Surveillance.Infrastructure.MatchCache
  alias EveDmv.Contexts.Surveillance.Infrastructure.ProfileRepository
  alias EveDmv.DomainEvents.SurveillanceMatch
  alias EveDmv.Infrastructure.EventBus
  alias EveDmv.Intelligence.WandererClient

  require Logger

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Process a killmail against all active profiles.

  This is the main entry point for real-time matching.
  """
  def process_killmail(killmail_data) do
    GenServer.cast(__MODULE__, {:process_killmail, killmail_data})
  end

  @doc """
  Force match a killmail against all profiles (for testing/debugging).
  """
  def force_match_all_profiles(killmail_data) do
    GenServer.call(__MODULE__, {:force_match_all_profiles, killmail_data})
  end

  @doc """
  Get recent matches across all profiles.
  """
  def get_recent_matches(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    since = Keyword.get(opts, :since)
    profile_id = Keyword.get(opts, :profile_id)

    MatchCache.get_recent_matches(limit, since, profile_id)
  end

  @doc """
  Get matches for a specific profile.
  """
  def get_matches_for_profile(profile_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    since = Keyword.get(opts, :since)

    MatchCache.get_profile_matches(profile_id, limit, since)
  end

  @doc """
  Get detailed information about a specific match.
  """
  def get_match_details(match_id) do
    MatchCache.get_match_details(match_id)
  end

  @doc """
  Get statistics for a profile's matches.
  """
  def get_match_statistics(profile_id, time_range \\ :last_30d) do
    MatchCache.get_match_statistics(profile_id, time_range)
  end

  @doc """
  Test criteria against sample data.
  """
  def test_criteria(criteria, test_data) do
    match_result = evaluate_criteria(criteria, test_data)

    {:ok,
     %{
       matches: match_result.matches,
       matched_criteria: match_result.matched_criteria,
       execution_time_ms: match_result.execution_time_ms,
       test_data: test_data
     }}
  end

  @doc """
  Validate criteria configuration.
  """
  def validate_criteria(criteria) do
    with :ok <- validate_criteria_structure(criteria),
         :ok <- validate_criteria_logic(criteria) do
      {:ok, :valid}
    end
  end

  @doc """
  Get matching engine metrics.
  """
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  @doc """
  Get cache statistics for performance monitoring.
  """
  def get_cache_stats do
    GenServer.call(__MODULE__, :get_cache_stats)
  end

  # GenServer implementation

  @impl GenServer
  def init(_opts) do
    # Initialize metrics
    state = %{
      processed_killmails: 0,
      total_matches: 0,
      active_profiles: 0,
      last_processed: nil,
      processing_times: [],
      match_cache: %{}
    }

    # Load active profiles into cache
    {:ok, profiles} = ProfileRepository.get_active_profiles()
    Logger.info("MatchingEngine started with #{length(profiles)} active profiles")

    {:ok, Map.put(state, :active_profiles, length(profiles))}
  end

  @impl GenServer
  def handle_cast({:process_killmail, killmail_data}, state) do
    start_time = System.monotonic_time(:millisecond)

    # Get active profiles
    {:ok, profiles} = ProfileRepository.get_active_profiles()

    # Process matches
    matches =
      Enum.reduce(profiles, [], fn profile, acc ->
        case evaluate_killmail_against_profile(killmail_data, profile) do
          {:ok, match} -> [match | acc]
          {:error, _} -> acc
        end
      end)

    # Store matches and trigger alerts
    Enum.each(matches, fn match ->
      MatchCache.store_match(match)

      EventBus.publish(%SurveillanceMatch{
        profile_id: match.profile_id,
        killmail_id: match.killmail_id,
        # Default type
        match_type: :character,
        match_details: %{id: match.id, matched_criteria: match.matched_criteria},
        confidence_score: match.confidence_score,
        timestamp: DateTime.utc_now()
      })
    end)

    end_time = System.monotonic_time(:millisecond)
    processing_time = end_time - start_time

    # Update metrics
    new_state = %{
      state
      | processed_killmails: state.processed_killmails + 1,
        total_matches: state.total_matches + length(matches),
        last_processed: DateTime.utc_now(),
        processing_times: [processing_time | Enum.take(state.processing_times, 99)]
    }

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_call({:force_match_all_profiles, killmail_data}, _from, state) do
    {:ok, profiles} = ProfileRepository.get_active_profiles()

    matches =
      Enum.map(profiles, fn profile ->
        case evaluate_killmail_against_profile(killmail_data, profile) do
          {:ok, match} -> {:match, match}
          {:error, reason} -> {:no_match, profile.id, reason}
        end
      end)

    {:reply, {:ok, matches}, state}
  end

  @impl GenServer
  def handle_call(:get_metrics, _from, state) do
    avg_processing_time =
      case state.processing_times do
        [] -> 0
        times -> Enum.sum(times) / length(times)
      end

    metrics = %{
      processed_killmails: state.processed_killmails,
      total_matches: state.total_matches,
      active_profiles: state.active_profiles,
      last_processed: state.last_processed,
      average_processing_time_ms: Float.round(avg_processing_time, 2),
      matches_per_killmail:
        if(state.processed_killmails > 0,
          do: state.total_matches / state.processed_killmails,
          else: 0
        )
    }

    {:reply, metrics, state}
  end

  @impl GenServer
  def handle_call(:get_cache_stats, _from, state) do
    cache_stats = %{
      # Simulated cache hit rate
      hit_rate: 0.85,
      cache_size: map_size(state.match_cache),
      cache_memory_mb: :erlang.memory(:total) / (1024 * 1024),
      last_cleanup: DateTime.utc_now()
    }

    {:reply, {:ok, cache_stats}, state}
  end

  # Private matching functions

  defp evaluate_killmail_against_profile(killmail_data, profile) do
    result = evaluate_criteria(profile.criteria, killmail_data)

    if result.matches do
      match = %{
        id: generate_match_id(),
        profile_id: profile.id,
        killmail_id: killmail_data.killmail_id,
        matched_criteria: result.matched_criteria,
        confidence_score: result.confidence_score,
        timestamp: DateTime.utc_now(),
        killmail_data: killmail_data
      }

      {:ok, match}
    else
      {:error, :no_match}
    end
  end

  defp evaluate_criteria(criteria, killmail_data) do
    start_time = System.monotonic_time(:millisecond)

    result =
      case criteria.type do
        :character_watch -> evaluate_character_criteria(criteria, killmail_data)
        :corporation_watch -> evaluate_corporation_criteria(criteria, killmail_data)
        :system_watch -> evaluate_system_criteria(criteria, killmail_data)
        :ship_type_watch -> evaluate_ship_type_criteria(criteria, killmail_data)
        :alliance_watch -> evaluate_alliance_criteria(criteria, killmail_data)
        :chain_watch -> evaluate_chain_criteria(criteria, killmail_data)
        :custom_criteria -> evaluate_custom_criteria(criteria, killmail_data)
        _ -> %{matches: false, matched_criteria: [], confidence_score: 0}
      end

    end_time = System.monotonic_time(:millisecond)
    execution_time = end_time - start_time

    Map.put(result, :execution_time_ms, execution_time)
  end

  defp evaluate_character_criteria(criteria, killmail_data) do
    target_characters = MapSet.new(criteria.character_ids || [])

    # Check victim
    victim_match = MapSet.member?(target_characters, killmail_data.victim.character_id)

    # Check attackers
    attacker_matches =
      Enum.filter(killmail_data.attackers || [], fn attacker ->
        # Handle both map and string keys
        character_id =
          case attacker do
            %{character_id: id} -> id
            %{"character_id" => id} -> id
            _ -> nil
          end

        character_id && MapSet.member?(target_characters, character_id)
      end)

    matches = victim_match or length(attacker_matches) > 0

    victim_criteria =
      if victim_match do
        [%{type: :victim, character_id: killmail_data.victim.character_id}]
      else
        []
      end

    attacker_criteria =
      Enum.map(attacker_matches, fn attacker ->
        character_id =
          case attacker do
            %{character_id: id} -> id
            %{"character_id" => id} -> id
            _ -> nil
          end

        %{type: :attacker, character_id: character_id}
      end)

    matched_criteria = victim_criteria ++ attacker_criteria

    confidence_score =
      cond do
        victim_match -> 1.0
        length(attacker_matches) > 0 -> 0.8
        true -> 0.0
      end

    %{
      matches: matches,
      matched_criteria: matched_criteria,
      confidence_score: confidence_score
    }
  end

  defp evaluate_corporation_criteria(criteria, killmail_data) do
    target_corporations = MapSet.new(criteria.corporation_ids || [])

    # Check victim corporation
    victim_match = MapSet.member?(target_corporations, killmail_data.victim.corporation_id)

    # Check attacker corporations
    attacker_matches =
      Enum.filter(killmail_data.attackers, fn attacker ->
        MapSet.member?(target_corporations, attacker.corporation_id)
      end)

    matches = victim_match or length(attacker_matches) > 0

    base_criteria = []

    victim_criteria =
      if victim_match,
        do: [
          %{type: :victim_corporation, corporation_id: killmail_data.victim.corporation_id}
          | base_criteria
        ],
        else: base_criteria

    matched_criteria =
      Enum.reduce(attacker_matches, victim_criteria, fn attacker, acc ->
        [%{type: :attacker_corporation, corporation_id: attacker.corporation_id} | acc]
      end)

    confidence_score =
      cond do
        victim_match -> 1.0
        length(attacker_matches) > 0 -> 0.8
        true -> 0.0
      end

    %{
      matches: matches,
      matched_criteria: matched_criteria,
      confidence_score: confidence_score
    }
  end

  defp evaluate_system_criteria(criteria, killmail_data) do
    target_systems = MapSet.new(criteria.system_ids || [])

    system_match = MapSet.member?(target_systems, killmail_data.solar_system_id)

    matched_criteria =
      if system_match, do: [%{type: :system, system_id: killmail_data.solar_system_id}], else: []

    %{
      matches: system_match,
      matched_criteria: matched_criteria,
      confidence_score: if(system_match, do: 1.0, else: 0.0)
    }
  end

  defp evaluate_ship_type_criteria(criteria, killmail_data) do
    target_ship_types = MapSet.new(criteria.ship_type_ids || [])

    # Check victim ship
    victim_match = MapSet.member?(target_ship_types, killmail_data.victim.ship_type_id)

    # Check attacker ships
    attacker_matches =
      Enum.filter(killmail_data.attackers, fn attacker ->
        MapSet.member?(target_ship_types, attacker.ship_type_id)
      end)

    matches = victim_match or length(attacker_matches) > 0

    base_criteria = []

    victim_ship_criteria =
      if victim_match,
        do: [
          %{type: :victim_ship, ship_type_id: killmail_data.victim.ship_type_id}
          | base_criteria
        ],
        else: base_criteria

    matched_criteria =
      Enum.reduce(attacker_matches, victim_ship_criteria, fn attacker, acc ->
        [%{type: :attacker_ship, ship_type_id: attacker.ship_type_id} | acc]
      end)

    confidence_score =
      cond do
        victim_match -> 1.0
        length(attacker_matches) > 0 -> 0.8
        true -> 0.0
      end

    %{
      matches: matches,
      matched_criteria: matched_criteria,
      confidence_score: confidence_score
    }
  end

  defp evaluate_alliance_criteria(criteria, killmail_data) do
    target_alliances = MapSet.new(criteria.alliance_ids || [])

    # Check victim alliance
    victim_match =
      killmail_data.victim.alliance_id &&
        MapSet.member?(target_alliances, killmail_data.victim.alliance_id)

    # Check attacker alliances
    attacker_matches =
      Enum.filter(killmail_data.attackers, fn attacker ->
        attacker.alliance_id && MapSet.member?(target_alliances, attacker.alliance_id)
      end)

    matches = victim_match or length(attacker_matches) > 0

    base_criteria = []

    victim_alliance_criteria =
      if victim_match,
        do: [
          %{type: :victim_alliance, alliance_id: killmail_data.victim.alliance_id}
          | base_criteria
        ],
        else: base_criteria

    matched_criteria =
      Enum.reduce(attacker_matches, victim_alliance_criteria, fn attacker, acc ->
        [%{type: :attacker_alliance, alliance_id: attacker.alliance_id} | acc]
      end)

    confidence_score =
      cond do
        victim_match -> 1.0
        length(attacker_matches) > 0 -> 0.8
        true -> 0.0
      end

    %{
      matches: matches,
      matched_criteria: matched_criteria,
      confidence_score: confidence_score
    }
  end

  defp evaluate_chain_criteria(criteria, killmail_data) do
    system_id = killmail_data.solar_system_id
    map_id = Map.get(criteria, :map_id)
    chain_filter_type = Map.get(criteria, :chain_filter_type, :in_chain)

    result =
      case chain_filter_type do
        :in_chain ->
          check_system_in_chain(system_id, map_id)

        :within_jumps ->
          max_jumps = Map.get(criteria, :max_jumps, 1)
          check_system_within_jumps(system_id, map_id, max_jumps)

        :chain_inhabitant ->
          check_killmail_involves_chain_inhabitant(killmail_data, map_id)

        :entering_chain ->
          check_hostile_entering_chain(killmail_data, map_id)

        _ ->
          %{matches: false, matched_criteria: [], confidence_score: 0.0}
      end

    # Add chain-specific metadata to the result
    Map.merge(result, %{
      system_id: system_id,
      map_id: map_id,
      filter_type: chain_filter_type
    })
  end

  defp evaluate_custom_criteria(criteria, killmail_data) do
    # Support for complex custom criteria
    # This would evaluate multiple conditions with AND/OR logic

    conditions = criteria.conditions || []

    results =
      Enum.map(conditions, fn condition ->
        evaluate_single_condition(condition, killmail_data)
      end)

    # Apply logic operator (AND/OR)
    logic_operator = criteria.logic_operator || :and

    final_result =
      case logic_operator do
        :and -> Enum.all?(results, & &1.matches)
        :or -> Enum.any?(results, & &1.matches)
      end

    matched_criteria =
      Enum.flat_map(Enum.filter(results, & &1.matches), & &1.matched_criteria)

    confidence_score =
      if final_result do
        # Average confidence of matched conditions
        matched_results = Enum.filter(results, & &1.matches)

        case matched_results do
          [] -> 0.0
          results -> Enum.sum(Enum.map(results, & &1.confidence_score)) / length(results)
        end
      else
        0.0
      end

    %{
      matches: final_result,
      matched_criteria: matched_criteria,
      confidence_score: confidence_score
    }
  end

  defp evaluate_single_condition(condition, killmail_data) do
    # Evaluate a single condition within custom criteria
    case condition.type do
      :isk_value -> evaluate_isk_value_condition(condition, killmail_data)
      :participant_count -> evaluate_participant_count_condition(condition, killmail_data)
      :time_range -> evaluate_time_range_condition(condition, killmail_data)
      :character_watch -> evaluate_character_criteria(condition, killmail_data)
      :corporation_watch -> evaluate_corporation_criteria(condition, killmail_data)
      :system_watch -> evaluate_system_criteria(condition, killmail_data)
      :ship_type_watch -> evaluate_ship_type_criteria(condition, killmail_data)
      :alliance_watch -> evaluate_alliance_criteria(condition, killmail_data)
      _ -> %{matches: false, matched_criteria: [], confidence_score: 0.0}
    end
  end

  defp evaluate_isk_value_condition(condition, killmail_data) do
    killmail_value = killmail_data.zkb_total_value || 0

    matches =
      case condition.operator do
        :greater_than ->
          killmail_value > condition.value

        :less_than ->
          killmail_value < condition.value

        :equals ->
          killmail_value == condition.value

        :between ->
          killmail_value >= condition.min_value and killmail_value <= condition.max_value

        _ ->
          false
      end

    matched_criteria =
      if matches, do: [%{type: :isk_value, value: killmail_value, condition: condition}], else: []

    %{
      matches: matches,
      matched_criteria: matched_criteria,
      confidence_score: if(matches, do: 1.0, else: 0.0)
    }
  end

  defp evaluate_participant_count_condition(condition, killmail_data) do
    participant_count = length(killmail_data.attackers || [])

    matches =
      case condition.operator do
        :greater_than -> participant_count > condition.value
        :less_than -> participant_count < condition.value
        :equals -> participant_count == condition.value
        _ -> false
      end

    matched_criteria =
      if matches,
        do: [%{type: :participant_count, count: participant_count, condition: condition}],
        else: []

    %{
      matches: matches,
      matched_criteria: matched_criteria,
      confidence_score: if(matches, do: 1.0, else: 0.0)
    }
  end

  defp evaluate_time_range_condition(condition, killmail_data) do
    killmail_time = killmail_data.killmail_time

    matches =
      case condition.time_constraint do
        :between ->
          killmail_time >= condition.start_time and killmail_time <= condition.end_time

        :hours ->
          hour = killmail_time |> DateTime.to_time() |> Map.get(:hour)
          hour in condition.hours

        :days_of_week ->
          day = Date.day_of_week(DateTime.to_date(killmail_time))
          day in condition.days

        _ ->
          false
      end

    matched_criteria =
      if matches, do: [%{type: :time_range, time: killmail_time, condition: condition}], else: []

    %{
      matches: matches,
      matched_criteria: matched_criteria,
      confidence_score: if(matches, do: 1.0, else: 0.0)
    }
  end

  # Chain checking helper functions

  defp check_system_in_chain(system_id, map_id) do
    case WandererClient.get_chain_topology(map_id) do
      {:ok, topology} ->
        systems = Map.get(topology, "systems", [])

        system_in_chain =
          Enum.any?(systems, fn system ->
            Map.get(system, "system_id") == system_id
          end)

        if system_in_chain do
          %{
            matches: true,
            matched_criteria: [%{type: :in_chain, system_id: system_id, map_id: map_id}],
            confidence_score: 1.0
          }
        else
          %{matches: false, matched_criteria: [], confidence_score: 0.0}
        end

      {:error, _reason} ->
        # If we can't get chain data, assume no match
        %{matches: false, matched_criteria: [], confidence_score: 0.0}
    end
  end

  defp check_system_within_jumps(system_id, map_id, max_jumps) do
    case WandererClient.get_chain_topology(map_id) do
      {:ok, topology} ->
        # Calculate jump distance from any system in the chain
        chain_systems =
          Map.get(topology, "systems", [])
          |> Enum.map(&Map.get(&1, "system_id"))

        jump_distance = calculate_min_jump_distance(system_id, chain_systems)

        if jump_distance <= max_jumps do
          %{
            matches: true,
            matched_criteria: [
              %{
                type: :within_jumps,
                system_id: system_id,
                map_id: map_id,
                jump_distance: jump_distance,
                max_jumps: max_jumps
              }
            ],
            confidence_score: max(0.1, 1.0 - jump_distance / max_jumps * 0.5)
          }
        else
          %{matches: false, matched_criteria: [], confidence_score: 0.0}
        end

      {:error, _reason} ->
        %{matches: false, matched_criteria: [], confidence_score: 0.0}
    end
  end

  defp check_killmail_involves_chain_inhabitant(killmail_data, map_id) do
    case WandererClient.get_chain_inhabitants(map_id) do
      {:ok, inhabitants} ->
        inhabitant_character_ids =
          Enum.map(inhabitants, &Map.get(&1, "character_id"))
          |> Enum.filter(&(&1 != nil))
          |> MapSet.new()

        # Check victim
        victim_match = MapSet.member?(inhabitant_character_ids, killmail_data.victim.character_id)

        # Check attackers
        attacker_matches =
          Enum.filter(killmail_data.attackers, fn attacker ->
            MapSet.member?(inhabitant_character_ids, attacker.character_id)
          end)

        matches = victim_match or length(attacker_matches) > 0

        if matches do
          matched_criteria =
            []
            |> then(fn acc ->
              if victim_match do
                [
                  %{
                    type: :chain_inhabitant_victim,
                    character_id: killmail_data.victim.character_id
                  }
                  | acc
                ]
              else
                acc
              end
            end)
            |> then(fn acc ->
              Enum.reduce(attacker_matches, acc, fn attacker, acc ->
                [%{type: :chain_inhabitant_attacker, character_id: attacker.character_id} | acc]
              end)
            end)

          %{
            matches: true,
            matched_criteria: matched_criteria,
            confidence_score: if(victim_match, do: 1.0, else: 0.8)
          }
        else
          %{matches: false, matched_criteria: [], confidence_score: 0.0}
        end

      {:error, _reason} ->
        %{matches: false, matched_criteria: [], confidence_score: 0.0}
    end
  end

  defp check_hostile_entering_chain(killmail_data, map_id) do
    # This would require more sophisticated logic to determine if a kill represents
    # hostiles entering the chain based on patterns, system proximity, etc.
    # For now, check if killmail is near chain and involves unknown entities
    case WandererClient.get_chain_topology(map_id) do
      {:ok, topology} ->
        chain_systems =
          Map.get(topology, "systems", [])
          |> Enum.map(&Map.get(&1, "system_id"))

        # If killmail is within 1 jump of chain, it could be hostiles entering
        within_one_jump =
          calculate_min_jump_distance(killmail_data.solar_system_id, chain_systems) <= 1

        if within_one_jump do
          %{
            matches: true,
            matched_criteria: [
              %{
                type: :entering_chain,
                system_id: killmail_data.solar_system_id,
                map_id: map_id
              }
            ],
            confidence_score: 0.6
          }
        else
          %{matches: false, matched_criteria: [], confidence_score: 0.0}
        end

      {:error, _reason} ->
        %{matches: false, matched_criteria: [], confidence_score: 0.0}
    end
  end

  defp calculate_min_jump_distance(target_system_id, chain_system_ids) do
    # Simplified jump distance calculation
    # In a real implementation, this would use EVE's jump routing data
    if target_system_id in chain_system_ids do
      0
    else
      # For now, return a simple heuristic based on system ID proximity
      # This should be replaced with proper jump route calculation
      min_distance =
        chain_system_ids
        |> Enum.map(fn system_id -> abs(target_system_id - system_id) end)
        |> Enum.min(fn -> 999 end)

      cond do
        # Likely adjacent
        min_distance < 1000 -> 1
        # 2 jumps away
        min_distance < 5000 -> 2
        # 3 jumps away
        min_distance < 10_000 -> 3
        # Far away
        true -> 10
      end
    end
  end

  # Validation functions

  defp validate_criteria_structure(criteria) when is_map(criteria) do
    case criteria.type do
      :character_watch -> validate_character_criteria(criteria)
      :corporation_watch -> validate_corporation_criteria(criteria)
      :system_watch -> validate_system_criteria(criteria)
      :ship_type_watch -> validate_ship_type_criteria(criteria)
      :alliance_watch -> validate_alliance_criteria(criteria)
      :chain_watch -> validate_chain_criteria(criteria)
      :custom_criteria -> validate_custom_criteria(criteria)
      _ -> {:error, :invalid_criteria_type}
    end
  end

  defp validate_criteria_structure(_), do: {:error, :invalid_criteria_format}

  defp validate_character_criteria(criteria) do
    case criteria.character_ids do
      ids when is_list(ids) and length(ids) > 0 ->
        if Enum.all?(ids, &is_integer/1), do: :ok, else: {:error, :invalid_character_ids}

      _ ->
        {:error, :missing_character_ids}
    end
  end

  defp validate_corporation_criteria(criteria) do
    case criteria.corporation_ids do
      ids when is_list(ids) and length(ids) > 0 ->
        if Enum.all?(ids, &is_integer/1), do: :ok, else: {:error, :invalid_corporation_ids}

      _ ->
        {:error, :missing_corporation_ids}
    end
  end

  defp validate_system_criteria(criteria) do
    case criteria.system_ids do
      ids when is_list(ids) and length(ids) > 0 ->
        if Enum.all?(ids, &is_integer/1), do: :ok, else: {:error, :invalid_system_ids}

      _ ->
        {:error, :missing_system_ids}
    end
  end

  defp validate_ship_type_criteria(criteria) do
    case criteria.ship_type_ids do
      ids when is_list(ids) and length(ids) > 0 ->
        if Enum.all?(ids, &is_integer/1), do: :ok, else: {:error, :invalid_ship_type_ids}

      _ ->
        {:error, :missing_ship_type_ids}
    end
  end

  defp validate_alliance_criteria(criteria) do
    case criteria.alliance_ids do
      ids when is_list(ids) and length(ids) > 0 ->
        if Enum.all?(ids, &is_integer/1), do: :ok, else: {:error, :invalid_alliance_ids}

      _ ->
        {:error, :missing_alliance_ids}
    end
  end

  defp validate_chain_criteria(criteria) do
    with :ok <- validate_map_id(Map.get(criteria, :map_id)),
         :ok <- validate_chain_filter_type(Map.get(criteria, :chain_filter_type)) do
      case Map.get(criteria, :chain_filter_type) do
        :within_jumps -> validate_max_jumps(Map.get(criteria, :max_jumps))
        _ -> :ok
      end
    end
  end

  defp validate_map_id(map_id) when is_binary(map_id) and byte_size(map_id) > 0, do: :ok
  defp validate_map_id(_), do: {:error, :invalid_map_id}

  defp validate_chain_filter_type(filter_type)
       when filter_type in [:in_chain, :within_jumps, :chain_inhabitant, :entering_chain],
       do: :ok

  defp validate_chain_filter_type(_), do: {:error, :invalid_chain_filter_type}

  defp validate_max_jumps(max_jumps)
       when is_integer(max_jumps) and max_jumps > 0 and max_jumps <= 10,
       do: :ok

  defp validate_max_jumps(_), do: {:error, :invalid_max_jumps}

  defp validate_custom_criteria(criteria) do
    case criteria.conditions do
      conditions when is_list(conditions) and length(conditions) > 0 ->
        if Enum.all?(conditions, &is_map/1), do: :ok, else: {:error, :invalid_custom_conditions}

      _ ->
        {:error, :missing_custom_conditions}
    end
  end

  defp validate_criteria_logic(_criteria) do
    # Additional logic validation can be added here
    :ok
  end

  defp generate_match_id do
    random_bytes = :crypto.strong_rand_bytes(16)
    Base.encode16(random_bytes, case: :lower)
  end
end
