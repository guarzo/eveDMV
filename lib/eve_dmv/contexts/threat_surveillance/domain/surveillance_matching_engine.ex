defmodule EveDmv.Contexts.ThreatSurveillance.Domain.SurveillanceMatchingEngine do
  @moduledoc """
  Core engine for surveillance profile matching against killmail data.

  Provides real-time matching of killmails against surveillance profiles
  with comprehensive criteria support and alert generation.
  """

  use GenServer

  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.DomainEvents.KillmailEnriched
  alias EveDmv.DomainEvents.SurveillanceMatch
  alias EveDmv.Infrastructure.EventBus
  alias EveDmv.Shared.Infrastructure.UnifiedCache
  alias EveDmv.Shared.Infrastructure.UnifiedRepository

  require Logger

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Process a killmail against all active surveillance profiles.
  """
  def process_killmail(%KillmailEnriched{} = killmail) do
    GenServer.cast(__MODULE__, {:process_killmail, killmail})
  end

  @doc """
  Test surveillance criteria against sample data.
  """
  def test_criteria(criteria, sample_data) do
    GenServer.call(__MODULE__, {:test_criteria, criteria, sample_data})
  end

  @doc """
  Get recent surveillance matches.
  """
  def get_recent_matches(options \\ []) do
    GenServer.call(__MODULE__, {:get_recent_matches, options})
  end

  @doc """
  Get matches for a specific profile.
  """
  def get_profile_matches(profile_id, options \\ []) do
    GenServer.call(__MODULE__, {:get_profile_matches, profile_id, options})
  end

  @doc """
  Get surveillance matching metrics.
  """
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  # GenServer implementation

  @impl GenServer
  def init(_opts) do
    state = %{
      processed_killmails: 0,
      total_matches: 0,
      active_profiles: [],
      match_cache: %{},
      performance_metrics: %{
        average_processing_time: 0,
        recent_processing_times: []
      }
    }

    # Load active profiles
    {:ok, profiles} = load_active_profiles()

    Logger.info("SurveillanceMatchingEngine started with #{length(profiles)} active profiles")
    {:ok, %{state | active_profiles: profiles}}
  end

  @impl GenServer
  def handle_cast({:process_killmail, killmail}, state) do
    start_time = System.monotonic_time(:millisecond)

    try do
      matches = process_killmail_against_profiles(killmail, state.active_profiles)

      # Store matches in cache
      if not Enum.empty?(matches) do
        UnifiedCache.cache_surveillance_match(killmail.killmail_id, matches)

        # Publish surveillance match events
        Enum.each(matches, fn match ->
          EventBus.publish(%SurveillanceMatch{
            profile_id: match.profile_id,
            killmail_id: match.killmail_id,
            match_type: match.match_type || :character,
            character_id: match.character_id,
            character_name: match.character_name,
            match_details: match.matched_criteria,
            confidence_score: match.confidence_score,
            timestamp: DateTime.utc_now()
          })
        end)
      end

      # Update performance metrics
      end_time = System.monotonic_time(:millisecond)
      processing_time = end_time - start_time
      updated_metrics = update_performance_metrics(state.performance_metrics, processing_time)

      new_state = %{
        state
        | processed_killmails: state.processed_killmails + 1,
          total_matches: state.total_matches + length(matches),
          performance_metrics: updated_metrics
      }

      {:noreply, new_state}
    rescue
      error ->
        Logger.error("Failed to process killmail for surveillance matching: #{inspect(error)}")
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_call({:test_criteria, criteria, sample_data}, _from, state) do
    result = evaluate_criteria_against_data(criteria, sample_data)
    {:reply, {:ok, result}, state}
  rescue
    error ->
      Logger.error("Failed to test surveillance criteria: #{inspect(error)}")
      {:reply, {:error, :test_failed}, state}
  end

  @impl GenServer
  def handle_call({:get_recent_matches, options}, _from, state) do
    limit = Keyword.get(options, :limit, 50)
    since = Keyword.get(options, :since, DateTimeUtils.add(DateTime.utc_now(), -24 * 3600, :second))

    case get_recent_matches_from_cache_or_db(since, limit) do
      {:ok, matches} -> {:reply, {:ok, matches}, state}
      error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:get_profile_matches, profile_id, options}, _from, state) do
    limit = Keyword.get(options, :limit, 50)

    since =
      Keyword.get(options, :since, DateTimeUtils.add(DateTime.utc_now(), -7 * 24 * 3600, :second))

    case get_profile_matches_from_cache_or_db(profile_id, since, limit) do
      {:ok, matches} -> {:reply, {:ok, matches}, state}
      error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call(:get_metrics, _from, state) do
    metrics = %{
      processed_killmails: state.processed_killmails,
      total_matches: state.total_matches,
      active_profiles: length(state.active_profiles),
      match_rate: calculate_match_rate(state),
      average_processing_time: state.performance_metrics.average_processing_time,
      cache_size: map_size(state.match_cache)
    }

    {:reply, metrics, state}
  end

  @impl GenServer
  def handle_call(:health_check, _from, state) do
    {:reply, :ok, state}
  end

  # Private functions

  defp process_killmail_against_profiles(killmail, profiles) do
    Enum.reduce(profiles, [], fn profile, matches ->
      case evaluate_profile_against_killmail(profile, killmail) do
        {:match, match_data} -> [match_data | matches]
        :no_match -> matches
      end
    end)
  end

  defp evaluate_profile_against_killmail(profile, killmail) do
    criteria = profile[:criteria] || profile.criteria

    # Check if killmail matches all criteria
    match_results =
      Enum.map(criteria, fn criterion ->
        evaluate_single_criterion(criterion, killmail)
      end)

    # Calculate overall match
    if Enum.all?(match_results, & &1.matches) do
      confidence_score = calculate_confidence_score(match_results)
      matched_criteria = Enum.filter(match_results, & &1.matches)

      match_data = %{
        profile_id: profile[:id] || profile.id,
        killmail_id: killmail.killmail_id,
        matched_criteria: matched_criteria,
        confidence_score: confidence_score,
        matched_at: DateTime.utc_now(),
        match_details: %{
          victim: extract_match_details(killmail.victim),
          attackers: Enum.map(killmail.attackers, &extract_match_details/1),
          system_id: killmail.solar_system_id,
          total_value: killmail.zkb_total_value
        }
      }

      {:match, match_data}
    else
      :no_match
    end
  rescue
    error ->
      Logger.error("Failed to evaluate profile against killmail: #{inspect(error)}")
      :no_match
  end

  defp evaluate_single_criterion(criterion, killmail) do
    case criterion.type do
      "character_id" ->
        character_ids = get_all_character_ids_from_killmail(killmail)
        matches = criterion.value in character_ids
        %{criterion: criterion, matches: matches, match_type: :character_id}

      "corporation_id" ->
        corp_ids = get_all_corporation_ids_from_killmail(killmail)
        matches = criterion.value in corp_ids
        %{criterion: criterion, matches: matches, match_type: :corporation_id}

      "alliance_id" ->
        alliance_ids = get_all_alliance_ids_from_killmail(killmail)
        matches = criterion.value in alliance_ids
        %{criterion: criterion, matches: matches, match_type: :alliance_id}

      "ship_type_id" ->
        ship_type_ids = get_all_ship_type_ids_from_killmail(killmail)
        matches = criterion.value in ship_type_ids
        %{criterion: criterion, matches: matches, match_type: :ship_type_id}

      "system_id" ->
        matches = killmail.solar_system_id == criterion.value
        %{criterion: criterion, matches: matches, match_type: :system_id}

      "min_value" ->
        matches = (killmail.zkb_total_value || 0) >= criterion.value
        %{criterion: criterion, matches: matches, match_type: :min_value}

      "max_value" ->
        matches = (killmail.zkb_total_value || 0) <= criterion.value
        %{criterion: criterion, matches: matches, match_type: :max_value}

      "security_status" ->
        security_status = get_system_security_status(killmail.solar_system_id)
        matches = evaluate_security_criterion(criterion, security_status)
        %{criterion: criterion, matches: matches, match_type: :security_status}

      "time_range" ->
        matches = evaluate_time_criterion(criterion, killmail.killmail_time)
        %{criterion: criterion, matches: matches, match_type: :time_range}

      _ ->
        Logger.warning("Unknown criterion type: #{criterion.type}")
        %{criterion: criterion, matches: false, match_type: :unknown}
    end
  end

  defp evaluate_criteria_against_data(criteria, sample_data) do
    # Test criteria against sample killmail data
    results =
      Enum.map(criteria, fn criterion ->
        evaluate_single_criterion(criterion, sample_data)
      end)

    %{
      overall_match: Enum.all?(results, & &1.matches),
      criterion_results: results,
      confidence_score: calculate_confidence_score(results)
    }
  end

  defp get_all_character_ids_from_killmail(killmail) do
    victim_id = get_in(killmail.victim, [:character_id])
    attacker_ids = Enum.map(killmail.attackers, & &1[:character_id]) |> Enum.filter(& &1)

    [victim_id | attacker_ids] |> Enum.filter(& &1) |> Enum.uniq()
  end

  defp get_all_corporation_ids_from_killmail(killmail) do
    victim_corp = get_in(killmail.victim, [:corporation_id])
    attacker_corps = Enum.map(killmail.attackers, & &1[:corporation_id]) |> Enum.filter(& &1)

    [victim_corp | attacker_corps] |> Enum.filter(& &1) |> Enum.uniq()
  end

  defp get_all_alliance_ids_from_killmail(killmail) do
    victim_alliance = get_in(killmail.victim, [:alliance_id])
    attacker_alliances = Enum.map(killmail.attackers, & &1[:alliance_id]) |> Enum.filter(& &1)

    [victim_alliance | attacker_alliances] |> Enum.filter(& &1) |> Enum.uniq()
  end

  defp get_all_ship_type_ids_from_killmail(killmail) do
    victim_ship = get_in(killmail.victim, [:ship_type_id])
    attacker_ships = Enum.map(killmail.attackers, & &1[:ship_type_id]) |> Enum.filter(& &1)

    [victim_ship | attacker_ships] |> Enum.filter(& &1) |> Enum.uniq()
  end

  defp get_system_security_status(_system_id) do
    # Would query static data for system security
    # Placeholder
    0.5
  end

  defp evaluate_security_criterion(criterion, security_status) do
    case criterion.operator do
      ">" -> security_status > criterion.value
      ">=" -> security_status >= criterion.value
      "<" -> security_status < criterion.value
      "<=" -> security_status <= criterion.value
      "=" -> security_status == criterion.value
      _ -> false
    end
  end

  defp evaluate_time_criterion(criterion, killmail_time) do
    case criterion.type do
      "hour_range" ->
        hour = killmail_time.hour
        hour >= criterion.start_hour and hour <= criterion.end_hour

      "day_of_week" ->
        day = Date.day_of_week(killmail_time)
        day in criterion.days

      _ ->
        true
    end
  end

  defp calculate_confidence_score(match_results) do
    if Enum.empty?(match_results) do
      0.0
    else
      matching_count = Enum.count(match_results, & &1.matches)
      matching_count / length(match_results)
    end
  end

  defp extract_match_details(participant) when is_map(participant) do
    %{
      character_id: participant[:character_id],
      corporation_id: participant[:corporation_id],
      alliance_id: participant[:alliance_id],
      ship_type_id: participant[:ship_type_id]
    }
  end

  defp extract_match_details(_), do: %{}

  defp load_active_profiles do
    # Load active surveillance profiles from repository
    case UnifiedRepository.get_active_surveillance_profiles() do
      {:ok, profiles} -> {:ok, profiles}
      # Return empty list if unable to load
      {:error, _reason} -> {:ok, []}
    end
  end

  defp get_recent_matches_from_cache_or_db(since, limit) do
    cache_key = {:recent_matches, since}

    case UnifiedCache.get(:surveillance, cache_key) do
      {:ok, matches} ->
        {:ok, Enum.take(matches, limit)}

      {:error, :not_found} ->
        # Would query database for recent matches
        # Placeholder
        matches = []
        # 3 minutes
        UnifiedCache.put(:surveillance, cache_key, matches, 180)
        {:ok, Enum.take(matches, limit)}
    end
  end

  defp get_profile_matches_from_cache_or_db(profile_id, since, limit) do
    cache_key = {:profile_matches, profile_id, since}

    case UnifiedCache.get(:surveillance, cache_key) do
      {:ok, matches} ->
        {:ok, Enum.take(matches, limit)}

      {:error, :not_found} ->
        # Would query database for profile matches
        # Placeholder
        matches = []
        # 5 minutes
        UnifiedCache.put(:surveillance, cache_key, matches, 300)
        {:ok, Enum.take(matches, limit)}
    end
  end

  defp update_performance_metrics(metrics, processing_time) do
    recent_times = [processing_time | metrics.recent_processing_times] |> Enum.take(100)

    average_time =
      if Enum.empty?(recent_times), do: 0, else: Enum.sum(recent_times) / length(recent_times)

    %{
      average_processing_time: Float.round(average_time, 2),
      recent_processing_times: recent_times
    }
  end

  defp calculate_match_rate(state) do
    if state.processed_killmails > 0 do
      Float.round(state.total_matches / state.processed_killmails, 3)
    else
      0.0
    end
  end
end
