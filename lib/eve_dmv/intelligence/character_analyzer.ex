defmodule EveDmv.Intelligence.CharacterAnalyzer do
  @moduledoc """
  Core character analysis coordination
  """

  require Logger
  alias EveDmv.Api
  alias EveDmv.Eve.{EsiClient, ItemType, NameResolver}
  alias EveDmv.Intelligence.{CharacterFormatters, CharacterMetrics, CharacterStats}
  alias EveDmv.Killmails.{KillmailEnriched, Participant}
  require Ash.Query

  @analysis_period_days 90
  @min_activity_threshold 10

  @doc """
  Analyze a character and create/update their intelligence profile.
  """
  @spec analyze_character(integer()) :: {:ok, CharacterStats.t()} | {:error, term()}
  def analyze_character(character_id) do
    Logger.info("Analyzing character #{character_id}")

    with {:ok, basic_info} <- get_character_info(character_id),
         {:ok, killmail_data} <- get_recent_killmails(character_id),
         {:ok, metrics} <- calculate_all_metrics(character_id, killmail_data),
         {:ok, character_stats} <- save_character_stats(basic_info, metrics) do
      {:ok, character_stats}
    else
      {:error, reason} = error ->
        Logger.error("Failed to analyze character #{character_id}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Analyze multiple characters in batch.
  """
  def analyze_characters(character_ids) when is_list(character_ids) do
    Logger.info("Batch analyzing #{length(character_ids)} characters")

    results =
      character_ids
      |> Task.async_stream(&analyze_character_with_timeout/1,
        max_concurrency: 5,
        timeout: 30_000,
        on_timeout: :kill_task
      )
      |> Enum.map(fn
        {:ok, result} -> result
        {:exit, :timeout} -> {:error, :timeout}
      end)

    successful = Enum.count(results, &match?({:ok, _}, &1))
    failed = length(results) - successful

    Logger.info("Batch analysis complete: #{successful} successful, #{failed} failed")
    {:ok, results}
  end

  @doc """
  Process killmail data to extract character analysis information.
  """
  def process_killmail_data(raw_killmail_data) do
    # Convert raw killmail data into structured format for analysis
    participants = raw_killmail_data["participants"] || []

    processed = %{
      killmail_id: raw_killmail_data["killmail_id"],
      killmail_time: raw_killmail_data["killmail_time"],
      solar_system_id: raw_killmail_data["solar_system_id"],
      participants: participants,
      victim: find_victim_participant(participants),
      attackers: Enum.reject(participants, &(&1["is_victim"] == true)),
      zkb: raw_killmail_data["zkb"] || %{}
    }

    {:ok, processed}
  end

  # Private implementation functions

  defp analyze_character_with_timeout(character_id) do
    Task.async(fn -> analyze_character(character_id) end)
    |> Task.await(25_000)
  rescue
    error ->
      Logger.error("Error analyzing character #{character_id}: #{inspect(error)}")
      {:error, error}
  end

  defp get_character_info(character_id) do
    case EsiClient.get_character_info(character_id) do
      {:ok, character_data} ->
        # Get corporation and alliance info
        corp_info =
          case EsiClient.get_corporation_info(character_data["corporation_id"]) do
            {:ok, corp} -> corp
            {:error, _} -> %{"name" => "Unknown Corporation"}
          end

        alliance_info =
          case character_data["alliance_id"] do
            nil ->
              nil

            alliance_id ->
              case EsiClient.get_alliance_info(alliance_id) do
                {:ok, alliance} -> alliance
                {:error, _} -> %{"name" => "Unknown Alliance"}
              end
          end

        basic_info = %{
          character_id: character_id,
          character_name: character_data["name"],
          corporation_id: character_data["corporation_id"],
          corporation_name: corp_info["name"],
          alliance_id: character_data["alliance_id"],
          alliance_name: alliance_info && alliance_info["name"],
          security_status: character_data["security_status"],
          birthday: character_data["birthday"]
        }

        {:ok, basic_info}

      {:error, :not_found} ->
        # Try to get character info from killmail data as fallback
        get_character_info_from_killmails(character_id)

      {:error, reason} ->
        Logger.warning("Failed to get character info from ESI: #{inspect(reason)}")
        get_character_info_from_killmails(character_id)
    end
  end

  defp get_character_info_from_killmails(character_id) do
    # Get basic info from recent killmails as fallback
    participants_query =
      Participant
      |> Ash.Query.new()
      |> Ash.Query.filter(character_id == ^character_id)
      |> Ash.Query.limit(1)
      |> Ash.Query.sort(updated_at: :desc)

    case Ash.read(participants_query, domain: Api) do
      {:ok, [participant | _]} ->
        basic_info = extract_basic_info(participant, character_id)
        {:ok, basic_info}

      {:ok, []} ->
        Logger.warning("No participant data found for character #{character_id}")
        {:error, :no_data}

      {:error, reason} ->
        Logger.error("Failed to query participant data: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp extract_basic_info(participant, character_id) do
    %{
      character_id: character_id,
      character_name: participant.character_name || "Unknown Character",
      corporation_id: participant.corporation_id,
      corporation_name: participant.corporation_name || "Unknown Corporation",
      alliance_id: participant.alliance_id,
      alliance_name: participant.alliance_name,
      security_status: nil,
      birthday: nil
    }
  end

  defp get_recent_killmails(character_id) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -@analysis_period_days, :day)

    # Get killmails where character was involved
    participants_query =
      Participant
      |> Ash.Query.new()
      |> Ash.Query.filter(character_id == ^character_id)
      |> Ash.Query.filter(updated_at >= ^cutoff_date)
      |> Ash.Query.load([:ship_type, :weapon_type])

    case Ash.read(participants_query, domain: Api) do
      {:ok, participants} ->
        killmails = fetch_killmails_for_participants(participants)
        {:ok, build_killmails_with_participants(killmails, participants)}

      {:error, reason} ->
        Logger.error(
          "Failed to fetch killmails for character #{character_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp fetch_killmails_for_participants(participants) do
    killmail_ids = Enum.map(participants, & &1.killmail_id)

    KillmailEnriched
    |> Ash.Query.new()
    |> Ash.Query.filter(killmail_id in ^killmail_ids)
    |> Ash.Query.load([:victim_ship_type, :solar_system])
    |> Ash.read!(domain: Api)
  end

  defp build_killmails_with_participants(killmails, participants) do
    # Convert to format expected by metrics calculations
    Enum.map(killmails, fn killmail ->
      km_participants = Enum.filter(participants, &(&1.killmail_id == killmail.killmail_id))

      %{
        "killmail_id" => killmail.killmail_id,
        "killmail_time" => DateTime.to_iso8601(killmail.killmail_time),
        "solar_system_id" => killmail.solar_system_id,
        "participants" => Enum.map(km_participants, &participant_to_map/1),
        "victim" => find_victim_in_participants(km_participants),
        "attackers" => find_attackers_in_participants(km_participants),
        "zkb" => %{
          "totalValue" => Decimal.to_integer(killmail.total_value || Decimal.new(0))
        }
      }
    end)
  end

  defp calculate_all_metrics(character_id, killmail_data) do
    if length(killmail_data) < @min_activity_threshold do
      Logger.info(
        "Character #{character_id} has insufficient activity for analysis (#{length(killmail_data)} killmails)"
      )

      {:error, :insufficient_data}
    else
      metrics = CharacterMetrics.calculate_all_metrics(character_id, killmail_data)
      {:ok, metrics}
    end
  end

  defp save_character_stats(basic_info, metrics) do
    # Calculate completeness score based on available data
    completeness = calculate_completeness(metrics)

    # Build character stats resource
    stats_params = %{
      character_id: basic_info.character_id,
      character_name: basic_info.character_name,
      corporation_id: basic_info.corporation_id,
      corporation_name: basic_info.corporation_name,
      alliance_id: basic_info.alliance_id,
      alliance_name: basic_info.alliance_name,

      # Basic combat statistics
      kill_count: metrics.basic_stats.kills.count,
      loss_count: metrics.basic_stats.losses.count,
      solo_kill_count: metrics.basic_stats.kills.solo,
      total_kill_value: Decimal.new(metrics.basic_stats.kills.total_value),
      total_loss_value: Decimal.new(metrics.basic_stats.losses.total_value),
      dangerous_rating: round(metrics.danger_rating.score),

      # Derived metrics
      kd_ratio: metrics.basic_stats.kd_ratio,
      solo_ratio: metrics.basic_stats.solo_ratio,
      efficiency: metrics.basic_stats.efficiency,

      # Analysis metadata
      last_analyzed_at: DateTime.utc_now(),
      completeness_score: completeness,
      data_quality: assess_data_quality(metrics),

      # Store structured analysis data
      analysis_data: Jason.encode!(metrics)
    }

    case CharacterStats.create(stats_params, domain: Api) do
      {:ok, character_stats} ->
        Logger.info("Successfully saved character stats for #{basic_info.character_id}")
        {:ok, character_stats}

      {:error, reason} ->
        Logger.error("Failed to save character stats: #{inspect(reason)}")

        # Try to update existing record instead
        case CharacterStats.update_by_character_id(basic_info.character_id, stats_params,
               domain: Api
             ) do
          {:ok, character_stats} ->
            Logger.info("Successfully updated character stats for #{basic_info.character_id}")
            {:ok, character_stats}

          {:error, update_reason} ->
            Logger.error("Failed to update character stats: #{inspect(update_reason)}")
            {:error, update_reason}
        end
    end
  end

  # Helper functions

  defp find_victim_participant(participants) do
    Enum.find(participants, &(&1["is_victim"] == true))
  end

  defp participant_to_map(participant) do
    %{
      "character_id" => participant.character_id,
      "character_name" => participant.character_name,
      "corporation_id" => participant.corporation_id,
      "corporation_name" => participant.corporation_name,
      "alliance_id" => participant.alliance_id,
      "alliance_name" => participant.alliance_name,
      "ship_type_id" => participant.ship_type_id,
      "ship_name" => participant.ship_name,
      "damage_done" => participant.damage_done,
      "final_blow" => participant.final_blow,
      "is_victim" => participant.is_victim
    }
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

    # Pre-load ship types to avoid N+1 queries
    ship_type_ids = victims |> Enum.map(fn {victim, _} -> victim.ship_type_id end) |> Enum.uniq()
    ship_categories_map = batch_categorize_ships(ship_type_ids)

    ship_categories =
      victims
      |> Enum.group_by(fn {victim, _} ->
        Map.get(ship_categories_map, victim.ship_type_id, "unknown")
      end)
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

  defp find_victim_participant(participants) do
    Enum.find(participants, &(&1["is_victim"] == true))
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

  # Batch version to avoid N+1 queries
  defp batch_categorize_ships(type_ids) when is_list(type_ids) do
    case Ash.read(ItemType,
           filter: [type_id: [in: type_ids]],
           domain: Api
         ) do
      {:ok, item_types} ->
        item_types
        |> Enum.map(fn item_type ->
          {item_type.type_id, determine_ship_category(item_type)}
        end)
        |> Map.new()

      {:error, _} ->
        # Fallback to individual queries if batch fails
        type_ids
        |> Enum.map(fn type_id -> {type_id, categorize_ship(type_id)} end)
        |> Map.new()
    end
  rescue
    _ ->
      # Return unknown for all if something goes wrong
      type_ids |> Enum.map(fn type_id -> {type_id, "unknown"} end) |> Map.new()
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

  @doc """
  Calculate danger rating on a scale of 1-5 based on combat statistics.
  """
  def calculate_danger_rating(stats) when is_map(stats) do
    combat_metrics = extract_combat_metrics(stats)
    score = calculate_danger_score(combat_metrics)
    convert_score_to_rating(score)
  end

  defp find_victim_in_participants(participants) do
    participant = Enum.find(participants, &(&1.is_victim == true))
    if participant, do: participant_to_map(participant), else: nil
  end

  defp find_attackers_in_participants(participants) do
    participants
    |> Enum.reject(&(&1.is_victim == true))
    |> Enum.map(&participant_to_map/1)
  end

  defp calculate_completeness(metrics) do
    # Calculate a completeness score based on available metrics
    total_possible = 10
    available = 0

    available = if metrics.basic_stats.kills.count > 0, do: available + 1, else: available
    available = if metrics.ship_usage.favorite_ships != [], do: available + 1, else: available

    available =
      if metrics.geographic_patterns.most_active_systems != [], do: available + 1, else: available

    available = if metrics.temporal_patterns.peak_hours != [], do: available + 1, else: available

    available =
      if metrics.frequent_associates.top_associates != [], do: available + 1, else: available

    available =
      if metrics.target_preferences.preferred_target_ships != [],
        do: available + 1,
        else: available

    available =
      if metrics.behavioral_patterns.risk_aversion != "Unknown",
        do: available + 1,
        else: available

    available =
      if metrics.weaknesses.vulnerable_to_ship_types != [], do: available + 1, else: available

    available = if metrics.danger_rating.score > 0, do: available + 1, else: available
    available = if metrics.success_rate > 0, do: available + 1, else: available

    (available / total_possible * 100) |> round()
  end

  defp assess_data_quality(metrics) do
    # Assess overall data quality
    total_activity = metrics.basic_stats.kills.count + metrics.basic_stats.losses.count

    cond do
      total_activity >= 100 -> "Excellent"
      total_activity >= 50 -> "Good"
      total_activity >= 25 -> "Fair"
      total_activity >= 10 -> "Limited"
      true -> "Poor"
    end
  end

  # Missing helper functions

  defp victim_is_character?(killmail, character_id) do
    victim = Enum.find(killmail.participants || killmail["participants"] || [], & &1.is_victim)
    victim && (victim.character_id == character_id || victim["character_id"] == character_id)
  end

  defp extract_combat_metrics(stats) do
    %{
      kills:
        Map.get(stats, :basic_stats, %{}) |> Map.get(:kills, %{count: 0}) |> Map.get(:count, 0),
      losses:
        Map.get(stats, :basic_stats, %{}) |> Map.get(:losses, %{count: 0}) |> Map.get(:count, 0),
      solo_kills: Map.get(stats, :basic_stats, %{}) |> Map.get(:kills, %{}) |> Map.get(:solo, 0),
      efficiency: Map.get(stats, :basic_stats, %{}) |> Map.get(:efficiency, 50.0),
      kd_ratio: Map.get(stats, :basic_stats, %{}) |> Map.get(:kd_ratio, 1.0)
    }
  end

  defp calculate_danger_score(combat_metrics) do
    # Calculate a danger score from 0-100 based on combat metrics
    # Max 40 points for K/D
    kd_weight = min(combat_metrics.kd_ratio * 20, 40)
    # Max 30 points for solo kills
    solo_weight = min(combat_metrics.solo_kills * 2, 30)
    # Max 20 points for activity
    activity_weight = min(combat_metrics.kills / 10, 20)
    # Max 10 points for efficiency
    efficiency_weight = combat_metrics.efficiency / 10

    kd_weight + solo_weight + activity_weight + efficiency_weight
  end

  defp convert_score_to_rating(score) do
    cond do
      score >= 80 -> 5
      score >= 60 -> 4
      score >= 40 -> 3
      score >= 20 -> 2
      true -> 1
    end
  end

  # Delegation to formatters
  defdelegate format_character_summary(analysis_results), to: CharacterFormatters
  defdelegate format_analysis_summary(character_stats), to: CharacterFormatters
end
