defmodule EveDmv.Intelligence.CharacterAnalyzer do
  @moduledoc """
  Analyzes killmail data to generate hunter-focused character intelligence.

  This module aggregates killmail data to identify patterns useful for hunters:
  - Ship preferences and common fits
  - Gang composition and frequent associates
  - Geographic activity patterns
  - Target selection preferences
  - Behavioral weaknesses
  """

  require Logger
  alias EveDmv.Api
  alias EveDmv.Eve.{EsiClient, ItemType, NameResolver}
  alias EveDmv.Intelligence.CharacterStats
  alias EveDmv.Killmails.{KillmailEnriched, Participant}
  require Ash.Query

  @analysis_period_days 90
  # Minimum kills+losses for meaningful analysis
  @min_activity_threshold 10

  @doc """
  Analyze a character and create/update their intelligence profile.

  ## Examples

      iex> CharacterAnalyzer.analyze_character(95465499)
      {:ok, %CharacterStats{
        character_id: 95465499,
        character_name: "CCP Falcon",
        dangerous_rating: 4,
        ...
      }}
  """
  @spec analyze_character(integer()) :: {:ok, CharacterStats.t()} | {:error, term()}
  def analyze_character(character_id) do
    Logger.info("Analyzing character #{character_id}")

    with {:ok, basic_info} <- get_character_info(character_id),
         {:ok, killmail_data} <- get_recent_killmails(character_id),
         {:ok, stats} <- calculate_statistics(character_id, killmail_data),
         {:ok, character_stats} <- save_character_stats(basic_info, stats) do
      {:ok, character_stats}
    else
      {:error, reason} = error ->
        Logger.error("Failed to analyze character #{character_id}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Analyze multiple characters in parallel.
  """
  @spec analyze_characters([integer()]) :: {:ok, [CharacterStats.t()]}
  def analyze_characters(character_ids) do
    # Remove unnecessary transaction wrapper - analyze_character_with_timeout handles its own DB operations
    character_ids
    |> Task.async_stream(&analyze_character_with_timeout/1,
      max_concurrency: 5,
      timeout: 30_000,
      on_timeout: :exit
    )
    |> Enum.reduce({[], []}, fn
      {:ok, {:ok, stats}}, {successful, failed} ->
        {[stats | successful], failed}

      {:ok, {:error, reason}}, {successful, failed} ->
        {successful, [{:error, reason} | failed]}

      {:exit, :timeout}, {successful, failed} ->
        {successful, [{:timeout, "Character analysis timed out"} | failed]}

      {:exit, reason}, {successful, failed} ->
        {successful, [{:exit, reason} | failed]}
    end)
    |> case do
      {successful, []} ->
        {:ok, successful}

      {successful, failed} ->
        Logger.warning("Partial analysis failure: #{length(failed)} characters failed")
        {:ok, successful}
    end
  end

  # Wrapper that handles timeout gracefully
  defp analyze_character_with_timeout(character_id) do
    analyze_character(character_id)
  catch
    :exit, {:timeout, _} ->
      {:error, :timeout}

    :exit, reason ->
      {:error, {:exit, reason}}
  end

  @doc """
  Process killmail data and return statistics.

  This function is primarily used for testing and analysis purposes.
  """
  @spec process_killmail_data(map()) :: {:ok, map()} | {:error, term()}
  def process_killmail_data(killmail_data) when is_map(killmail_data) do
    # Extract character_id and killmails from the data structure
    character_id = Map.get(killmail_data, :character_id)
    killmails = Map.get(killmail_data, :killmails, [])

    if character_id && is_list(killmails) && length(killmails) > 0 do
      # Convert test data to the format expected by calculate_statistics
      formatted_killmails = format_test_killmails(killmails, character_id)
      calculate_statistics(character_id, formatted_killmails)
    else
      {:error, :invalid_killmail_data}
    end
  rescue
    error ->
      {:error, {:processing_error, error}}
  end

  def process_killmail_data(_), do: {:error, :invalid_input}

  # Private functions

  defp get_character_info(character_id) do
    # First try to get current info from ESI
    case EsiClient.get_character(character_id) do
      {:ok, char_data} ->
        # Get corporation and alliance info
        corp_info =
          case EsiClient.get_corporation(char_data.corporation_id) do
            {:ok, corp} ->
              %{
                corporation_name: corp.name,
                alliance_id: corp.alliance_id
              }

            _ ->
              %{
                corporation_name: "Unknown Corporation",
                alliance_id: nil
              }
          end

        alliance_name =
          if corp_info.alliance_id do
            case EsiClient.get_alliance(corp_info.alliance_id) do
              {:ok, alliance} -> alliance.name
              _ -> nil
            end
          else
            nil
          end

        {:ok,
         %{
           character_id: character_id,
           character_name: char_data.name,
           corporation_id: char_data.corporation_id,
           corporation_name: corp_info.corporation_name,
           alliance_id: corp_info.alliance_id,
           alliance_name: alliance_name,
           security_status: char_data.security_status
         }}

      {:error, _reason} ->
        # Fallback to killmail participant data
        get_character_info_from_killmails(character_id)
    end
  end

  defp get_character_info_from_killmails(character_id) do
    # Return error immediately if character_id is invalid
    if not is_integer(character_id) or character_id <= 0 do
      {:error, "Invalid character ID"}
    else
      # Try to get the most recent victim record for basic info using Ash
      query =
        Participant
        |> Ash.Query.new()
        |> Ash.Query.filter(character_id == ^character_id and is_victim == true)
        |> Ash.Query.sort(killmail_time: :desc)
        |> Ash.Query.limit(1)

      case Ash.read(query, domain: Api) do
        {:ok, [participant | _]} ->
          extract_basic_info(participant, character_id)

        {:ok, []} ->
          # Try non-victim records
          query =
            Participant
            |> Ash.Query.new()
            |> Ash.Query.filter(character_id == ^character_id)
            |> Ash.Query.sort(killmail_time: :desc)
            |> Ash.Query.limit(1)

          case Ash.read(query, domain: Api) do
            {:ok, [participant | _]} ->
              extract_basic_info(participant, character_id)

            {:ok, []} ->
              {:error, :character_not_found}

            {:error, error} ->
              {:error, error}
          end

        {:error, error} ->
          {:error, error}
      end
    end
  end

  defp extract_basic_info(participant, character_id) do
    {:ok,
     %{
       character_id: character_id,
       character_name: participant.character_name || NameResolver.character_name(character_id),
       corporation_id: participant.corporation_id,
       corporation_name:
         participant.corporation_name ||
           (participant.corporation_id &&
              NameResolver.corporation_name(participant.corporation_id)),
       alliance_id: participant.alliance_id,
       alliance_name:
         participant.alliance_name ||
           (participant.alliance_id && NameResolver.alliance_name(participant.alliance_id))
     }}
  end

  defp get_recent_killmails(character_id) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -@analysis_period_days, :day)

    # Use Ash to get participants for this character
    query =
      Participant
      |> Ash.Query.new()
      |> Ash.Query.filter(character_id == ^character_id and killmail_time >= ^cutoff_date)
      |> Ash.Query.sort(killmail_time: :desc)

    with {:ok, participants} <- Ash.read(query, domain: Api),
         {:ok, killmails} <- fetch_killmails_for_participants(participants) do
      build_killmails_with_participants(killmails, participants)
    end
  end

  defp fetch_killmails_for_participants(participants) do
    killmail_ids = participants |> Enum.map(& &1.killmail_id) |> Enum.uniq()

    km_query =
      KillmailEnriched
      |> Ash.Query.new()
      |> Ash.Query.filter(killmail_id in ^killmail_ids)
      |> Ash.Query.sort(killmail_time: :desc)

    Ash.read(km_query, domain: Api)
  end

  defp build_killmails_with_participants(killmails, participants) do
    if length(killmails) < @min_activity_threshold do
      {:error, :insufficient_activity}
    else
      killmails_with_participants =
        Enum.map(killmails, fn km ->
          km_participants = Enum.filter(participants, &(&1.killmail_id == km.killmail_id))
          Map.put(km, :participants, km_participants)
        end)

      {:ok, killmails_with_participants}
    end
  end

  defp calculate_statistics(character_id, killmails) do
    stats = %{
      basic_stats: calculate_basic_stats(character_id, killmails),
      ship_usage: analyze_ship_usage(character_id, killmails),
      gang_composition: analyze_gang_composition(character_id, killmails),
      geographic_patterns: analyze_geographic_patterns(character_id, killmails),
      target_profile: analyze_target_preferences(character_id, killmails),
      behavioral_patterns: analyze_behavioral_patterns(character_id, killmails),
      weaknesses: identify_weaknesses(character_id, killmails)
    }

    {:ok, stats}
  end

  defp calculate_basic_stats(character_id, killmails) do
    {kills, losses} =
      Enum.reduce(killmails, {[], []}, fn km, {kills, losses} ->
        if victim_is_character?(km, character_id) do
          {kills, [km | losses]}
        else
          {[km | kills], losses}
        end
      end)

    solo_kills = Enum.count(kills, &solo_kill?/1)
    solo_losses = Enum.count(losses, &solo_loss?/1)

    total_destroyed = kills |> Enum.map(&Decimal.to_float(&1.total_value)) |> Enum.sum()
    total_lost = losses |> Enum.map(&Decimal.to_float(&1.total_value)) |> Enum.sum()

    isk_efficiency =
      if total_destroyed + total_lost > 0 do
        total_destroyed / (total_destroyed + total_lost) * 100
      else
        50.0
      end

    %{
      total_kills: length(kills),
      total_losses: length(losses),
      solo_kills: solo_kills,
      solo_losses: solo_losses,
      isk_destroyed: total_destroyed,
      isk_lost: total_lost,
      isk_efficiency: Float.round(isk_efficiency, 2),
      kill_death_ratio: calculate_kd_ratio(length(kills), length(losses))
    }
  end

  defp analyze_ship_usage(character_id, killmails) do
    killmails
    |> Enum.flat_map(fn km ->
      # Get ships used by character in this killmail
      km.participants
      |> Enum.filter(&(&1.character_id == character_id))
      |> Enum.map(
        &{&1.ship_type_id, &1.ship_name || NameResolver.ship_name(&1.ship_type_id), km,
         &1.is_victim}
      )
    end)
    |> Enum.group_by(fn {type_id, name, _km, _is_victim} -> {type_id, name} end)
    |> Enum.map(fn {{type_id, name}, uses} ->
      kills = Enum.count(uses, fn {_, _, _, is_victim} -> not is_victim end)
      losses = Enum.count(uses, fn {_, _, _, is_victim} -> is_victim end)

      gang_sizes =
        uses
        # Subtract 1 to exclude victim
        |> Enum.map(fn {_, _, km, _} -> max(0, length(km.participants) - 1) end)
        |> Enum.filter(&(&1 >= 0))

      avg_gang_size =
        if length(gang_sizes) > 0 do
          Enum.sum(gang_sizes) / length(gang_sizes)
        else
          # No gang if excluding victim results in 0
          0.0
        end

      {Integer.to_string(type_id),
       %{
         "ship_name" => name,
         "times_used" => length(uses),
         "kills" => kills,
         "losses" => losses,
         "success_rate" => Float.round(kills / max(1, kills + losses), 2),
         "avg_gang_size" => Float.round(avg_gang_size, 1)
       }}
    end)
    |> Map.new()
    |> then(fn map ->
      map
      |> Map.to_list()
      |> Enum.sort_by(fn {_, data} -> -data["times_used"] end)
      |> Enum.take(10)
      |> Map.new()
    end)
  end

  defp analyze_gang_composition(character_id, killmails) do
    killmails
    # Only kills
    |> Enum.filter(fn km -> not victim_is_character?(km, character_id) end)
    |> Enum.flat_map(fn km ->
      # Find all non-victim participants except our character
      km.participants
      |> Enum.filter(&(&1.character_id != character_id and not &1.is_victim))
      |> Enum.map(&{&1.character_id, &1.character_name, &1.corporation_id, &1.ship_name})
    end)
    |> Enum.group_by(fn {char_id, name, corp_id, _ship} -> {char_id, name, corp_id} end)
    |> Enum.map(fn {{char_id, name, corp_id}, appearances} ->
      ships =
        appearances
        |> Enum.map(fn {_, _, _, ship} -> ship end)
        |> Enum.reject(&is_nil/1)
        |> Enum.frequencies()
        |> Map.keys()

      {Integer.to_string(char_id),
       %{
         "name" => name || NameResolver.character_name(char_id),
         "corp_id" => corp_id,
         "times_together" => length(appearances),
         # Top 3 ships
         "ships_flown" => Enum.take(ships, 3)
       }}
    end)
    |> Enum.sort_by(fn {_, data} -> -data["times_together"] end)
    # Top 20 associates
    |> Enum.take(20)
    |> Map.new()
  end

  defp analyze_geographic_patterns(character_id, killmails) do
    killmails
    |> Enum.group_by(&{&1.solar_system_id, &1.solar_system_name})
    |> Enum.map(fn {{system_id, system_name}, kms} ->
      kills = Enum.count(kms, fn km -> not victim_is_character?(km, character_id) end)
      losses = Enum.count(kms, fn km -> victim_is_character?(km, character_id) end)
      last_seen = kms |> Enum.map(& &1.killmail_time) |> Enum.max()

      system_info = NameResolver.system_security(system_id)

      {Integer.to_string(system_id),
       %{
         "system_name" => system_name || NameResolver.system_name(system_id),
         "security" => system_info.status,
         "security_class" => system_info.class,
         "kills" => kills,
         "losses" => losses,
         "total_activity" => kills + losses,
         "last_seen" => last_seen
       }}
    end)
    |> Enum.sort_by(fn {_, data} -> -data["total_activity"] end)
    # Top 20 systems
    |> Enum.take(20)
    |> Map.new()
  end

  defp analyze_target_preferences(character_id, killmails) do
    victims =
      killmails
      |> Enum.filter(fn km -> not victim_is_character?(km, character_id) end)
      |> Enum.map(fn km ->
        victim = Enum.find(km.participants, & &1.is_victim)
        {victim, km}
      end)
      |> Enum.reject(fn {victim, _} -> is_nil(victim) end)

    ship_categories =
      victims
      |> Enum.group_by(fn {victim, _} -> categorize_ship(victim.ship_type_id) end)
      |> Enum.map(fn {category, victim_list} ->
        {category,
         %{
           "killed" => length(victim_list),
           "avg_value" => average_kill_value(victim_list)
         }}
      end)
      |> Map.new()

    avg_victim_gang_size =
      killmails
      |> Enum.filter(fn km -> not victim_is_character?(km, character_id) end)
      # Subtract 1 to exclude victim
      |> Enum.map(&max(0, length(&1.participants) - 1))
      |> average()

    %{
      "ship_categories" => ship_categories,
      "avg_victim_gang_size" => Float.round(avg_victim_gang_size, 1),
      "total_unique_victims" =>
        victims |> Enum.map(fn {v, _} -> v.character_id end) |> Enum.uniq() |> length()
    }
  end

  defp analyze_behavioral_patterns(character_id, killmails) do
    # Time zone analysis
    hours =
      killmails
      |> Enum.map(fn km -> km.killmail_time.hour end)
      |> Enum.frequencies()

    {prime_start, prime_end} = find_prime_timezone(hours)

    # Home system (most kills, not losses)
    home_system =
      killmails
      |> Enum.filter(fn km -> not victim_is_character?(km, character_id) end)
      |> Enum.group_by(&{&1.solar_system_id, &1.solar_system_name})
      |> Enum.max_by(fn {_, kms} -> length(kms) end, fn -> {nil, []} end)
      |> elem(0)

    # Gang size preference
    gang_sizes =
      killmails
      |> Enum.filter(fn km -> not victim_is_character?(km, character_id) end)
      |> Enum.map(&length(&1.participants))

    # Aggression calculation
    total_engagements = length(killmails)

    aggressive_engagements =
      killmails
      |> Enum.count(fn km ->
        # Engaged when outnumbered
        not victim_is_character?(km, character_id) and
          length(km.participants) > 2
      end)

    aggression = aggressive_engagements / max(1, total_engagements) * 10

    %{
      prime_timezone: "#{prime_start}:00-#{prime_end}:00 EVE",
      home_system_id: elem(home_system || {nil, nil}, 0),
      home_system_name: elem(home_system || {nil, nil}, 1),
      avg_gang_size: Float.round(average(gang_sizes), 1),
      aggression_index: Float.round(aggression, 1)
    }
  end

  defp identify_weaknesses(character_id, killmails) do
    losses = Enum.filter(killmails, &victim_is_character?(&1, character_id))

    behavioral = []
    technical = []

    # Check for predictable timing
    behavioral =
      if concentrated_activity?(killmails) do
        ["predictable_schedule" | behavioral]
      else
        behavioral
      end

    # Check for overconfidence
    behavioral =
      if takes_bad_fights?(character_id, losses) do
        ["overconfident" | behavioral]
      else
        behavioral
      end

    # Check technical weaknesses from losses
    technical = technical ++ analyze_loss_patterns(losses)

    %{
      "behavioral" => behavioral,
      "technical" => technical,
      "loss_patterns" => summarize_losses(losses)
    }
  end

  # Helper functions

  defp victim_is_character?(killmail, character_id) do
    Enum.any?(killmail.participants, fn p ->
      p.character_id == character_id and p.is_victim
    end)
  end

  defp solo_kill?(killmail) do
    non_victim_count = Enum.count(killmail.participants, &(not &1.is_victim))
    non_victim_count == 1
  end

  defp solo_loss?(killmail) do
    # Character died to a single attacker
    non_victim_count = Enum.count(killmail.participants, &(not &1.is_victim))
    non_victim_count == 1
  end

  defp calculate_kd_ratio(kills, losses) do
    Float.round(kills / max(1, losses), 2)
  end

  defp categorize_ship(type_id) do
    case Ash.get(ItemType, type_id, domain: Api) do
      {:ok, item_type} ->
        determine_ship_category(item_type)

      {:error, _} ->
        "unknown"
    end
  rescue
    _ -> "unknown"
  end

  # Determine ship category based on group name and other attributes
  defp determine_ship_category(item_type) do
    case item_type.group_name do
      name
      when name in [
             "Frigate",
             "Assault Frigate",
             "Covert Ops",
             "Electronic Attack Ship",
             "Interceptor",
             "Stealth Bomber"
           ] ->
        "frigate"

      name
      when name in [
             "Cruiser",
             "Heavy Assault Cruiser",
             "Logistics",
             "Recon Ship",
             "Strategic Cruiser"
           ] ->
        "cruiser"

      name when name in ["Battleship", "Black Ops", "Marauder"] ->
        "battleship"

      name when name in ["Destroyer", "Interdictor", "Command Destroyer", "Tactical Destroyer"] ->
        "destroyer"

      name
      when name in [
             "Battlecruiser",
             "Combat Battlecruiser",
             "Attack Battlecruiser",
             "Command Ship"
           ] ->
        "battlecruiser"

      name
      when name in [
             "Carrier",
             "Dreadnought",
             "Supercarrier",
             "Titan",
             "Capital Industrial Ship",
             "Jump Freighter",
             "Force Auxiliary"
           ] ->
        "capital"

      name
      when name in ["Industrial", "Mining Barge", "Exhumer", "Freighter", "Transport Ship"] ->
        "industrial"

      _ ->
        if item_type.is_ship, do: "unknown", else: "unknown"
    end
  end

  defp average_kill_value(victim_list) do
    values =
      victim_list
      |> Enum.map(fn {_, km} -> Decimal.to_float(km.total_value) end)

    if length(values) > 0 do
      Enum.sum(values) / length(values)
    else
      0.0
    end
  end

  defp average(list) when length(list) > 0 do
    Enum.sum(list) / length(list)
  end

  defp average(_), do: 0.0

  defp find_prime_timezone(hour_frequencies) do
    # Find the 4-hour window with most activity
    max_window =
      0..23
      |> Enum.map(fn start_hour ->
        total =
          0..3
          |> Enum.map(fn offset ->
            Map.get(hour_frequencies, rem(start_hour + offset, 24), 0)
          end)
          |> Enum.sum()

        {start_hour, total}
      end)
      |> Enum.max_by(&elem(&1, 1))

    start = elem(max_window, 0)
    {start, rem(start + 4, 24)}
  end

  defp concentrated_activity?(killmails) do
    # Check if >70% of activity is in a 6-hour window
    hours = Enum.map(killmails, fn km -> km.killmail_time.hour end)
    hour_counts = Enum.frequencies(hours)

    max_6h_window =
      0..23
      |> Enum.map(fn start ->
        0..5
        |> Enum.map(fn offset -> Map.get(hour_counts, rem(start + offset, 24), 0) end)
        |> Enum.sum()
      end)
      |> Enum.max()

    max_6h_window / length(killmails) > 0.7
  end

  defp takes_bad_fights?(_character_id, losses) do
    # Check if they often die when outnumbered
    bad_losses =
      Enum.count(losses, fn km ->
        attackers = Enum.count(km.participants, &(not &1.is_victim))
        # Died to 3+ attackers
        attackers > 3
      end)

    bad_losses / max(1, length(losses)) > 0.4
  end

  defp analyze_loss_patterns(losses) do
    patterns = []

    # Check for neut vulnerability
    neut_deaths =
      Enum.count(losses, fn km ->
        Enum.any?(km.participants, fn p ->
          not p.is_victim and
            p.weapon_name && String.contains?(String.downcase(p.weapon_name), "neutralizer")
        end)
      end)

    patterns =
      if neut_deaths / max(1, length(losses)) > 0.2 do
        ["weak_to_neuts" | patterns]
      else
        patterns
      end

    patterns
  end

  defp summarize_losses(losses) do
    losses
    # Last 5 losses
    |> Enum.take(5)
    |> Enum.map(fn km ->
      victim = Enum.find(km.participants, & &1.is_victim)

      %{
        "ship" => victim.ship_name,
        "value" => Decimal.to_float(km.total_value),
        "date" => km.killmail_time,
        "system" => km.solar_system_name
      }
    end)
  end

  defp save_character_stats(basic_info, stats) do
    # Calculate derived fields
    dangerous_rating = calculate_danger_rating(stats)

    # Build the complete stats record
    attrs =
      basic_info
      |> Map.merge(stats.basic_stats)
      |> Map.merge(stats.behavioral_patterns)
      |> Map.put(:ship_usage, stats.ship_usage)
      |> Map.put(:frequent_associates, stats.gang_composition)
      |> Map.put(:active_systems, stats.geographic_patterns)
      |> Map.put(:target_profile, stats.target_profile)
      |> Map.put(:identified_weaknesses, stats.weaknesses)
      |> Map.put(:dangerous_rating, dangerous_rating)
      |> Map.put(:last_calculated_at, DateTime.utc_now())
      |> Map.put(:data_completeness, calculate_completeness(stats))

    # Upsert the stats
    query =
      CharacterStats
      |> Ash.Query.new()
      |> Ash.Query.filter(character_id == ^attrs.character_id)

    case Ash.read_one(query, domain: Api) do
      {:ok, existing} ->
        Ash.update(existing, attrs, domain: Api)

      {:error, _} ->
        Ash.create(CharacterStats, attrs, domain: Api)
    end
  end

  @doc """
  Calculate danger rating on a scale of 1-5 based on combat statistics.
  """
  def calculate_danger_rating(stats) when is_map(stats) do
    combat_metrics = extract_combat_metrics(stats)
    score = calculate_danger_score(combat_metrics)
    convert_score_to_rating(score)
  end

  defp extract_combat_metrics(stats) do
    %{
      total_kills: stats[:total_kills] || stats.total_kills || 0,
      total_losses: stats[:total_losses] || stats.total_losses || 0,
      solo_kills: stats[:solo_kills] || stats.solo_kills || 0,
      isk_destroyed: stats[:isk_destroyed] || stats.isk_destroyed || 0,
      avg_gang_size: stats[:avg_gang_size] || stats.avg_gang_size || 1.0
    }
  end

  defp calculate_danger_score(%{
         total_kills: total_kills,
         total_losses: total_losses,
         solo_kills: solo_kills,
         isk_destroyed: isk_destroyed,
         avg_gang_size: avg_gang_size
       }) do
    kd_score = calculate_kd_score(total_kills, total_losses)
    solo_score = calculate_solo_score(solo_kills, total_kills)
    isk_score = calculate_isk_score(isk_destroyed)
    gang_score = calculate_gang_score(avg_gang_size)
    activity_score = calculate_activity_score(total_kills)

    kd_score + solo_score + isk_score + gang_score + activity_score
  end

  defp calculate_kd_score(total_kills, total_losses) do
    kd_ratio = if total_losses > 0, do: total_kills / total_losses, else: total_kills
    min(kd_ratio * 2, 20)
  end

  defp calculate_solo_score(solo_kills, total_kills) do
    solo_percentage = if total_kills > 0, do: solo_kills / total_kills, else: 0
    solo_percentage * 15
  end

  defp calculate_isk_score(isk_destroyed) do
    isk_billions = isk_destroyed / 1_000_000_000
    min(isk_billions / 10, 15)
  end

  defp calculate_gang_score(avg_gang_size) do
    max(0, 10 - avg_gang_size)
  end

  defp calculate_activity_score(total_kills) do
    min(total_kills / 100, 10)
  end

  defp convert_score_to_rating(score) do
    cond do
      # Extremely dangerous
      score >= 45 -> 5
      # Very dangerous
      score >= 35 -> 4
      # Moderately dangerous
      score >= 25 -> 3
      # Slightly dangerous
      score >= 15 -> 2
      # Low threat
      true -> 1
    end
  end

  defp calculate_completeness(stats) do
    checks = [
      stats.basic_stats.total_kills > 0,
      map_size(stats.ship_usage) > 0,
      map_size(stats.gang_composition) > 0,
      map_size(stats.geographic_patterns) > 0,
      stats.behavioral_patterns.home_system_id != nil
    ]

    passed = Enum.count(checks, & &1)
    round(passed / length(checks) * 100)
  end

  defp format_test_killmails(killmails, character_id) do
    Enum.map(killmails, fn km ->
      # Convert test killmail format to the format expected by analyze functions
      participants = create_test_participants(km, character_id)

      %{
        killmail_id: Map.get(km, :killmail_id, :rand.uniform(999_999_999)),
        killmail_time: Map.get(km, :killmail_time, DateTime.utc_now()),
        solar_system_id: Map.get(km, :solar_system_id, 30_002_187),
        solar_system_name: Map.get(km, :solar_system_name, "Rens"),
        total_value: Decimal.new(Map.get(km, :total_value, 0.0)),
        participants: participants
      }
    end)
  end

  defp create_test_participants(km, character_id) do
    # Create victim participant for the character
    victim = %{
      character_id: character_id,
      character_name: "Test Character",
      corporation_id: 98_000_001,
      corporation_name: "Test Corp",
      alliance_id: 99_000_001,
      alliance_name: "Test Alliance",
      ship_type_id: Map.get(km, :ship_type_id, 11_999),
      ship_name: Map.get(km, :ship_name, "Rifter"),
      is_victim: Map.get(km, :is_victim, true),
      killmail_id: Map.get(km, :killmail_id, :rand.uniform(999_999_999)),
      killmail_time: Map.get(km, :killmail_time, DateTime.utc_now()),
      weapon_type_id: nil,
      weapon_name: nil
    }

    # Create attackers based on attacker_count
    attacker_count = Map.get(km, :attacker_count, 1)

    attackers =
      Enum.map(1..attacker_count, fn i ->
        %{
          character_id: character_id + i,
          character_name: "Attacker #{i}",
          corporation_id: 98_000_002,
          corporation_name: "Enemy Corp",
          alliance_id: 99_000_002,
          alliance_name: "Enemy Alliance",
          ship_type_id: 11_999,
          ship_name: "Rifter",
          is_victim: false,
          killmail_id: Map.get(km, :killmail_id, :rand.uniform(999_999_999)),
          killmail_time: Map.get(km, :killmail_time, DateTime.utc_now()),
          weapon_type_id: 12_345,
          weapon_name: "Light Missile Launcher"
        }
      end)

    [victim | attackers]
  end

  # Additional public API functions expected by tests

  @doc """
  Analyze geographic patterns from killmail data.
  """
  def analyze_geographic_patterns(killmails) when is_list(killmails) do
    if Enum.empty?(killmails) do
      %{
        active_systems: %{},
        security_preferences: %{},
        home_system_id: nil,
        regional_activity: %{}
      }
    else
      # Group by solar system
      system_activity =
        killmails
        |> Enum.group_by(fn km ->
          {Map.get(km, :solar_system_id), Map.get(km, :solar_system_name)}
        end)
        |> Enum.map(fn {{system_id, system_name}, kms} ->
          {system_id,
           %{
             "system_name" => system_name || "Unknown",
             "activity_count" => length(kms),
             "security_status" => Map.get(List.first(kms), :security_status, 0.0),
             "last_seen" =>
               kms
               |> Enum.map(&Map.get(&1, :killmail_time, DateTime.utc_now()))
               |> Enum.max(DateTime, fn -> DateTime.utc_now() end)
           }}
        end)
        |> Enum.into(%{})

      # Find home system (most active)
      home_system_id =
        system_activity
        |> Enum.max_by(fn {_id, data} -> data["activity_count"] end, fn -> {nil, nil} end)
        |> elem(0)

      # Calculate security preferences
      security_prefs =
        killmails
        |> Enum.group_by(fn km ->
          sec_status = Map.get(km, :security_status, 0.0)

          cond do
            sec_status >= 0.5 -> "highsec"
            sec_status > 0.0 -> "lowsec"
            sec_status == 0.0 -> "nullsec"
            sec_status < 0.0 -> "wormhole"
            true -> "unknown"
          end
        end)
        |> Enum.map(fn {sec_type, kms} -> {sec_type, length(kms)} end)
        |> Enum.into(%{})
        |> normalize_percentages()

      # Regional activity (simplified)
      regional_activity = %{
        "domain" => Map.get(security_prefs, "highsec", 0),
        "providence" => Map.get(security_prefs, "nullsec", 0),
        "j_space" => Map.get(security_prefs, "wormhole", 0)
      }

      %{
        active_systems: system_activity,
        security_preferences: security_prefs,
        home_system_id: home_system_id,
        regional_activity: regional_activity
      }
    end
  end

  @doc """
  Determine timezone from activity hours.
  """
  def determine_timezone_from_activity(active_hours) when is_list(active_hours) do
    cond do
      # Peak activity around 18-22 UTC suggests EUTZ
      Enum.any?(active_hours, fn h -> h in 18..22 end) -> "EUTZ"
      # Peak activity around 1-5 UTC suggests USTZ
      Enum.any?(active_hours, fn h -> h in 1..5 end) -> "USTZ"
      # Peak activity around 10-14 UTC suggests AUTZ
      Enum.any?(active_hours, fn h -> h in 10..14 end) -> "AUTZ"
      true -> "Unknown"
    end
  end

  @doc """
  Calculate ship preferences from killmail data.
  """
  def calculate_ship_preferences(killmails) when is_list(killmails) do
    if Enum.empty?(killmails) do
      %{
        most_used_ships: [],
        ship_success_rates: %{},
        preferred_ship_categories: %{},
        total_unique_ships: 0
      }
    else
      # Group by ship name and calculate usage stats
      ship_usage =
        killmails
        |> Enum.group_by(fn km -> Map.get(km, :ship_name, "Unknown") end)
        |> Enum.map(fn {ship_name, uses} ->
          kills = Enum.count(uses, fn use -> not Map.get(use, :is_victim, false) end)
          losses = Enum.count(uses, fn use -> Map.get(use, :is_victim, false) end)
          total_uses = kills + losses
          success_rate = if total_uses > 0, do: Float.round(kills / total_uses, 2), else: 0.0

          %{
            ship_name: ship_name,
            usage_count: total_uses,
            kills: kills,
            losses: losses,
            success_rate: success_rate
          }
        end)
        |> Enum.sort_by(& &1.usage_count, :desc)

      # Calculate success rates map
      success_rates =
        ship_usage
        |> Enum.map(fn ship -> {ship.ship_name, ship.success_rate} end)
        |> Enum.into(%{})

      # Categorize ships and calculate category preferences
      preferred_categories =
        ship_usage
        |> Enum.group_by(fn ship -> categorize_ship_by_name(ship.ship_name) end)
        |> Enum.map(fn {category, ships} ->
          total_usage = Enum.sum(Enum.map(ships, & &1.usage_count))
          {category, total_usage}
        end)
        |> Enum.into(%{})
        |> normalize_percentages()

      %{
        most_used_ships: Enum.take(ship_usage, 10),
        ship_success_rates: success_rates,
        preferred_ship_categories: preferred_categories,
        total_unique_ships: length(ship_usage)
      }
    end
  end

  @doc """
  Identify frequent associates from killmail data.
  """
  def identify_frequent_associates(killmails, character_id) when is_list(killmails) do
    if Enum.empty?(killmails) do
      %{}
    else
      killmails
      |> Enum.flat_map(fn km ->
        participants = Map.get(km, :participants, [])
        # Get all non-victim participants except the character themselves
        participants
        |> Enum.filter(fn p ->
          p.character_id != character_id and not Map.get(p, :is_victim, false)
        end)
        |> Enum.map(fn p ->
          {p.character_id, p.character_name, Map.get(p, :corporation_name, "Unknown")}
        end)
      end)
      |> Enum.frequencies()
      |> Enum.map(fn {{char_id, char_name, corp_name}, count} ->
        {Integer.to_string(char_id),
         %{
           "name" => char_name,
           "shared_kills" => count,
           "corp_name" => corp_name,
           # Would need more analysis to determine
           "is_logistics" => false
         }}
      end)
      |> Enum.sort_by(fn {_id, data} -> -data["shared_kills"] end)
      # Top 20 associates
      |> Enum.take(20)
      |> Enum.into(%{})
    end
  end

  @doc """
  Analyze temporal patterns in killmail data.
  """
  def analyze_temporal_patterns(killmails) when is_list(killmails) do
    if Enum.empty?(killmails) do
      %{
        active_hours: [],
        prime_timezone: "Unknown",
        activity_consistency: 0.0,
        weekend_vs_weekday: 0.0,
        hourly_distribution: %{},
        daily_distribution: %{},
        peak_activity_hours: [],
        timezone_estimate: "Unknown"
      }
    else
      # Extract hours and days from killmail times
      times =
        Enum.map(killmails, fn km ->
          killmail_time = Map.get(km, :killmail_time, DateTime.utc_now())
          {killmail_time.hour, Date.day_of_week(DateTime.to_date(killmail_time))}
        end)

      # Calculate hourly distribution
      hourly_dist =
        times
        |> Enum.map(&elem(&1, 0))
        |> Enum.frequencies()
        |> normalize_percentages()

      # Calculate daily distribution
      daily_dist =
        times
        |> Enum.map(&elem(&1, 1))
        |> Enum.frequencies()
        |> Enum.map(fn {day_num, count} ->
          day_name =
            case day_num do
              1 -> "Monday"
              2 -> "Tuesday"
              3 -> "Wednesday"
              4 -> "Thursday"
              5 -> "Friday"
              6 -> "Saturday"
              7 -> "Sunday"
            end

          {day_name, count}
        end)
        |> Enum.into(%{})

      # Find peak activity hours (top 3 hours with most activity)
      peak_hours =
        hourly_dist
        |> Enum.sort_by(&elem(&1, 1), :desc)
        |> Enum.take(3)
        |> Enum.map(&elem(&1, 0))

      # Get active hours (all hours with activity)
      active_hours = hourly_dist |> Map.keys() |> Enum.sort()

      # Estimate timezone based on peak activity
      timezone_estimate = estimate_timezone_from_peaks(peak_hours)

      # Calculate activity consistency (how spread out activity is)
      hour_variance =
        if length(active_hours) > 1 do
          mean_hour = Enum.sum(active_hours) / length(active_hours)

          variance =
            Enum.sum(Enum.map(active_hours, &:math.pow(&1 - mean_hour, 2))) / length(active_hours)

          # 144 = 12^2 (max spread)
          max(0.0, 1.0 - variance / 144.0)
        else
          1.0
        end

      # Calculate weekend vs weekday ratio
      weekend_activity = Enum.count(times, fn {_hour, day} -> day >= 6 end)
      weekday_activity = length(times) - weekend_activity

      weekend_ratio =
        if weekday_activity > 0 do
          weekend_activity / weekday_activity
        else
          if weekend_activity > 0, do: 2.0, else: 0.0
        end

      %{
        active_hours: active_hours,
        prime_timezone: timezone_estimate,
        activity_consistency: Float.round(hour_variance, 2),
        weekend_vs_weekday: Float.round(weekend_ratio, 2),
        hourly_distribution: hourly_dist,
        daily_distribution: daily_dist,
        peak_activity_hours: peak_hours,
        timezone_estimate: timezone_estimate
      }
    end
  end

  @doc """
  Format character analysis into a summary.
  """
  def format_character_summary(analysis) do
    character_name = Map.get(analysis, :character_name, "Unknown")
    character_id = Map.get(analysis, :character_id, 0)
    total_kills = Map.get(analysis, :total_kills, 0)
    total_losses = Map.get(analysis, :total_losses, 0)
    dangerous_rating = Map.get(analysis, :dangerous_rating, 1)

    # Extract key information
    associates = Map.get(analysis, :frequent_associates, %{})
    weaknesses = Map.get(analysis, :identified_weaknesses, %{})
    ship_usage = Map.get(analysis, :ship_usage, %{})

    # Generate summary text
    summary_text = """
    Character Analysis: #{character_name} (#{character_id})

    Combat Record: #{total_kills} kills, #{total_losses} losses
    Threat Level: #{dangerous_rating}/5

    #{format_associates_summary(associates)}
    #{format_weaknesses_summary(weaknesses)}
    #{format_ship_usage_summary(ship_usage)}
    """

    # Create structured summary with expected test format
    %{
      pilot_profile: String.trim(summary_text),
      threat_assessment: %{
        level: dangerous_rating,
        description: assess_threat_level(dangerous_rating, total_kills),
        metrics: %{
          kills: total_kills,
          losses: total_losses,
          associate_count: map_size(associates)
        }
      },
      tactical_notes: generate_counter_recommendations(analysis)
    }
  end

  @doc """
  Categorize ship type by name.
  """
  def categorize_ship_type(ship_name) do
    case ship_name do
      name when name in ["Rifter", "Punisher", "Merlin", "Tristan"] -> "frigate"
      name when name in ["Crucifier", "Griffin", "Maulus", "Vigil"] -> "ewar_frigate"
      name when name in ["Ares", "Malediction", "Stiletto", "Crow"] -> "interceptor"
      name when name in ["Maller", "Vexor", "Caracal", "Thorax"] -> "cruiser"
      name when name in ["Legion", "Proteus", "Tengu", "Loki"] -> "strategic_cruiser"
      name when name in ["Damnation", "Nighthawk", "Claymore", "Sleipnir"] -> "command_ship"
      name when name in ["Guardian", "Scimitar", "Basilisk", "Oneiros"] -> "logistics"
      name when name in ["Devoter", "Phobos", "Onyx", "Broadsword"] -> "heavy_interdictor"
      _ -> "unknown"
    end
  end

  @doc """
  Check if a date is a weekend.
  """
  def weekend?(date) do
    day_of_week = Date.day_of_week(date)
    # Saturday or Sunday
    day_of_week == 6 or day_of_week == 7
  end

  @doc """
  Check if a date is a weekend (alias for weekend?/1).
  """
  def weekend_day?(date), do: weekend?(date)

  @doc """
  Extract hour from datetime.
  """
  def extract_hour_from_datetime(%DateTime{} = datetime), do: datetime.hour

  @doc """
  Calculate success rate from kills and losses.
  """
  def calculate_success_rate(0, 0), do: 0.0
  def calculate_success_rate(_kills, 0), do: 1.0

  def calculate_success_rate(kills, losses) when kills >= 0 and losses >= 0 do
    kills / (kills + losses)
  end

  @doc """
  Identify weaknesses from character data.
  """
  def identify_weaknesses(character_data) when is_map(character_data) do
    behavioral_weaknesses = []
    technical_weaknesses = []

    # Check ship usage patterns for poor success rates
    ship_usage = Map.get(character_data, :ship_usage, %{})
    most_used_ships = Map.get(ship_usage, :most_used_ships, [])

    behavioral_weaknesses =
      if Enum.any?(most_used_ships, fn ship ->
           Map.get(ship, :success_rate, 1.0) < 0.3
         end) do
        ["overconfident_ship_choices" | behavioral_weaknesses]
      else
        behavioral_weaknesses
      end

    # Check target preferences for high-risk behavior
    target_prefs = Map.get(character_data, :target_preferences, %{})
    hunting_patterns = Map.get(target_prefs, :hunting_patterns, %{})
    solo_hunting = Map.get(hunting_patterns, :solo_hunting, 0.0)

    behavioral_weaknesses =
      if solo_hunting > 0.8 do
        ["excessive_solo_hunting" | behavioral_weaknesses]
      else
        behavioral_weaknesses
      end

    %{
      behavioral_weaknesses: behavioral_weaknesses,
      technical_weaknesses: technical_weaknesses,
      summary:
        "#{length(behavioral_weaknesses)} behavioral, #{length(technical_weaknesses)} technical weaknesses identified"
    }
  end

  # Helper functions for the new API functions

  defp categorize_ship_by_name(ship_name) do
    case ship_name do
      name when name in ["Rifter", "Punisher", "Merlin", "Tristan", "Crucifier", "Griffin"] ->
        "frigate"

      name when name in ["Ares", "Malediction", "Stiletto", "Crow"] ->
        "interceptor"

      name when name in ["Maller", "Vexor", "Caracal", "Thorax"] ->
        "cruiser"

      name when name in ["Legion", "Proteus", "Tengu", "Loki"] ->
        "strategic_cruiser"

      name when name in ["Damnation", "Nighthawk"] ->
        "command_ship"

      name when name in ["Guardian", "Scimitar"] ->
        "logistics"

      _ ->
        "other"
    end
  end

  defp normalize_percentages(frequency_map) do
    total = frequency_map |> Map.values() |> Enum.sum()

    if total > 0 do
      frequency_map
      |> Enum.map(fn {key, count} ->
        {key, Float.round(count / total * 100, 1)}
      end)
      |> Enum.into(%{})
    else
      frequency_map
    end
  end

  defp estimate_timezone_from_peaks(peak_hours) do
    cond do
      # Peak activity around 18-22 UTC suggests EUTZ
      Enum.any?(peak_hours, fn h -> h in 18..22 end) -> "EUTZ"
      # Peak activity around 1-5 UTC suggests USTZ
      Enum.any?(peak_hours, fn h -> h in 1..5 end) -> "USTZ"
      # Peak activity around 10-14 UTC suggests AUTZ
      Enum.any?(peak_hours, fn h -> h in 10..14 end) -> "AUTZ"
      true -> "Unknown"
    end
  end

  defp format_associates_summary(associates) do
    if map_size(associates) > 0 do
      top_associate =
        associates
        |> Enum.max_by(fn {_id, data} -> data["shared_kills"] end)
        |> elem(1)

      "Primary Associate: #{top_associate["name"]} (#{top_associate["shared_kills"]} shared kills)"
    else
      "No significant associates identified"
    end
  end

  defp format_weaknesses_summary(weaknesses) do
    behavioral = Map.get(weaknesses, :behavioral_weaknesses, [])
    technical = Map.get(weaknesses, :technical_weaknesses, [])

    weakness_count = length(behavioral) + length(technical)

    if weakness_count > 0 do
      "Identified Weaknesses: #{weakness_count} behavioral/technical patterns"
    else
      "No significant weaknesses identified"
    end
  end

  defp format_ship_usage_summary(ship_usage) do
    most_used = Map.get(ship_usage, :most_used_ships, [])

    if length(most_used) > 0 do
      primary_ship = hd(most_used)
      "Primary Ship: #{primary_ship["ship_name"]} (#{primary_ship["times_used"]} uses)"
    else
      "Ship usage data unavailable"
    end
  end

  defp assess_threat_level(dangerous_rating, total_kills) do
    cond do
      dangerous_rating >= 4 and total_kills > 100 -> "High Threat"
      dangerous_rating >= 3 or total_kills > 50 -> "Moderate Threat"
      dangerous_rating >= 2 or total_kills > 10 -> "Low Threat"
      true -> "Minimal Threat"
    end
  end

  defp generate_counter_recommendations(analysis) do
    dangerous_rating = Map.get(analysis, :dangerous_rating, 1)
    weaknesses = Map.get(analysis, :identified_weaknesses, %{})

    recommendations = []

    recommendations =
      if dangerous_rating >= 4 do
        ["Avoid solo engagement", "Bring overwhelming force" | recommendations]
      else
        recommendations
      end

    recommendations =
      if Map.get(weaknesses, :behavioral_weaknesses, []) != [] do
        ["Exploit predictable patterns" | recommendations]
      else
        recommendations
      end

    if Enum.empty?(recommendations) do
      ["Standard engagement protocols apply"]
    else
      recommendations
    end
  end

  @doc """
  Calculate target preferences based on killmail data.
  """
  def calculate_target_preferences(killmails) when is_list(killmails) do
    # Filter only kills (not losses)
    kills = Enum.filter(killmails, &(!&1.is_victim))

    if Enum.empty?(kills) do
      %{
        preferred_target_types: %{},
        avg_target_value: 0,
        target_size_preference: "unknown",
        hunting_patterns: %{
          solo_hunting: 0.0,
          small_gang: 0.0,
          fleet_hunting: 0.0
        }
      }
    else
      # Use victim_ship_name instead of ship_name
      target_types =
        kills
        |> Enum.group_by(
          &(Map.get(&1, :victim_ship_name) || Map.get(&1, :ship_name) || "Unknown")
        )
        |> Enum.map(fn {ship, occurrences} -> {ship, length(occurrences)} end)
        |> Enum.into(%{})

      avg_value =
        kills
        |> Enum.map(&Map.get(&1, :total_value, 0))
        |> Enum.sum()
        |> Kernel./(length(kills))
        |> Float.round(0)

      # Analyze gang sizes for hunting patterns
      gang_sizes = Enum.map(kills, &Map.get(&1, :attacker_count, 1))
      solo_count = Enum.count(gang_sizes, &(&1 == 1))
      small_gang_count = Enum.count(gang_sizes, &(&1 in 2..5))
      fleet_count = Enum.count(gang_sizes, &(&1 > 5))
      total = length(gang_sizes)

      hunting_patterns = %{
        solo_hunting: if(total > 0, do: solo_count / total, else: 0.0),
        small_gang: if(total > 0, do: small_gang_count / total, else: 0.0),
        fleet_hunting: if(total > 0, do: fleet_count / total, else: 0.0)
      }

      # Determine target size preference
      target_size_preference =
        cond do
          solo_count / total > 0.6 -> "solo_targets"
          small_gang_count / total > 0.4 -> "small_groups"
          fleet_count / total > 0.3 -> "large_groups"
          true -> "mixed"
        end

      %{
        preferred_target_types: target_types,
        avg_target_value: avg_value,
        target_size_preference: target_size_preference,
        hunting_patterns: hunting_patterns
      }
    end
  end
end
