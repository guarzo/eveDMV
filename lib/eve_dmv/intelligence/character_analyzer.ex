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
  alias EveDmv.Eve.{ItemType, NameResolver}
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
    # Use a database transaction to ensure consistency
    EveDmv.Repo.transaction(fn ->
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
    end)
    |> case do
      {:ok, result} -> result
      {:error, reason} -> {:error, reason}
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

  # Private functions

  defp get_character_info(character_id) do
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
      
    case Ash.read(query, domain: Api) do
      {:ok, participants} ->
        # Get unique killmail IDs
        killmail_ids = participants 
                      |> Enum.map(& &1.killmail_id) 
                      |> Enum.uniq()
        
        # Get enriched killmails for these IDs
        km_query = 
          KillmailEnriched
          |> Ash.Query.new()
          |> Ash.Query.filter(killmail_id in ^killmail_ids)
          |> Ash.Query.sort(killmail_time: :desc)
          
        case Ash.read(km_query, domain: Api) do
          {:ok, killmails} ->
            if length(killmails) < @min_activity_threshold do
              {:error, :insufficient_activity}
            else
              # Attach participants to killmails manually
              killmails_with_participants = Enum.map(killmails, fn km ->
                km_participants = Enum.filter(participants, & &1.killmail_id == km.killmail_id)
                Map.put(km, :participants, km_participants)
              end)
              {:ok, killmails_with_participants}
            end
            
          {:error, error} ->
            {:error, error}
        end
        
      {:error, error} ->
        {:error, error}
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
        |> Enum.map(fn {_, _, km, _} -> length(km.participants) end)
        |> Enum.filter(&(&1 > 0))

      avg_gang_size =
        if length(gang_sizes) > 0 do
          Enum.sum(gang_sizes) / length(gang_sizes)
        else
          1.0
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
      |> Enum.map(&length(&1.participants))
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
        if item_type.is_ship, do: "small", else: "unknown"
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

  defp calculate_danger_rating(stats) do
    points = []

    # High K/D ratio
    points =
      if stats.basic_stats.kill_death_ratio > 5 do
        [2 | points]
      else
        if stats.basic_stats.kill_death_ratio > 3, do: [1 | points], else: points
      end

    # High ISK efficiency
    points = if stats.basic_stats.isk_efficiency > 80, do: [1 | points], else: points

    # High activity
    points = if stats.basic_stats.total_kills > 100, do: [1 | points], else: points

    # Uses dangerous ships
    dangerous_ships = ["Loki", "Legion", "Proteus", "Tengu"]

    points =
      if Enum.any?(Map.values(stats.ship_usage), fn ship ->
           ship["ship_name"] in dangerous_ships and ship["times_used"] > 10
         end),
         do: [1 | points],
         else: points

    score = Enum.sum(points)
    min(5, max(1, score))
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
end
