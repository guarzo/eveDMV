defmodule EveDmv.Contexts.BattleAnalysis.Core.OptimizedBattleAnalyzer do
  @moduledoc """
  Optimized battle analysis module with efficient queries and preloading.
  Fixes N+1 query problems and improves performance.
  """

  import Ecto.Query
  alias EveDmv.Contexts.BattleAnalysis.Resources.Battle
  alias EveDmv.Contexts.Combat.Core.FleetCompositionAnalyzer
  alias EveDmv.Contexts.Combat.Core.ParticipantAnalyzer
  alias EveDmv.Contexts.Combat.Core.PerformanceCalculator
  alias EveDmv.Contexts.Combat.Core.TacticalPatternDetector
  alias EveDmv.Contexts.Combat.Core.TimelineBuilder
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Repo

  @doc """
  Perform comprehensive analysis of a battle with optimized queries.
  Uses preloading and batch fetching to avoid N+1 problems.
  """
  def analyze_battle(battle_id) do
    with {:ok, battle_with_killmails} <- get_battle_with_killmails_optimized(battle_id),
         {:ok, timeline} <- TimelineBuilder.build_timeline(battle_with_killmails.killmails),
         {:ok, participants} <-
           ParticipantAnalyzer.analyze_participants(battle_with_killmails.killmails),
         {:ok, fleet_comp} <-
           FleetCompositionAnalyzer.analyze_composition(battle_with_killmails.killmails),
         {:ok, tactics} <-
           TacticalPatternDetector.detect_patterns(battle_with_killmails.killmails, timeline),
         {:ok, performance} <-
           PerformanceCalculator.calculate_metrics(battle_with_killmails.killmails, participants) do
      {:ok,
       %{
         battle_id: battle_id,
         summary: build_battle_summary(battle_with_killmails, battle_with_killmails.killmails),
         metrics: calculate_battle_metrics(battle_with_killmails.killmails, participants),
         timeline: timeline,
         participants: participants,
         fleet_composition: fleet_comp,
         tactical_patterns: tactics,
         performance_metrics: performance,
         recommendations: []
       }}
    else
      {:error, _} = error -> error
    end
  end

  @doc """
  Get battle metrics for a specific battle.

  Returns metrics including:
  - Duration in minutes
  - Total kills
  - Total ISK destroyed
  - Unique participants
  - Unique corporations and alliances
  - Kill rate and average kill value
  """
  def get_battle_metrics(battle_id) do
    with {:ok, battle} <- get_battle_with_killmails_optimized(battle_id) do
      killmails = battle.killmails

      metrics = %{
        duration_minutes: calculate_duration(killmails),
        total_kills: length(killmails),
        total_isk_destroyed: calculate_total_isk(killmails),
        unique_participants: count_unique_participants(killmails),
        unique_corporations: count_unique_corporations(killmails),
        unique_alliances: count_unique_alliances(killmails),
        kills_per_minute: calculate_kill_rate(killmails),
        average_kill_value: calculate_average_kill_value(killmails),
        ship_classes_involved: get_ship_classes(killmails),
        system_security: get_system_security(battle),
        peak_activity_time: find_peak_activity(killmails)
      }

      {:ok, metrics}
    end
  end

  @doc """
  Generate a battle summary suitable for display.

  Returns summary including:
  - Headline
  - Key stats
  - Winning side
  - MVP pilot
  - Turning point
  - Notable kills
  """
  def get_battle_summary(battle_id) do
    case analyze_battle(battle_id) do
      {:ok, analysis} ->
        summary = %{
          headline: generate_summary_headline(analysis),
          key_stats: extract_summary_key_stats(analysis),
          winning_side: determine_battle_winner(analysis),
          mvp_pilot: find_battle_mvp(analysis),
          turning_point: identify_battle_turning_point(analysis),
          notable_kills: find_battle_notable_kills(analysis)
        }

        {:ok, summary}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get battle details with all related data in a single query.
  Optimized version that preloads all necessary associations.
  """
  def get_battle_details(battle_id) do
    # Single optimized query with all necessary data
    query = """
    WITH battle_data AS (
      SELECT 
        b.id,
        b.start_time,
        b.end_time,
        b.system_id,
        b.region_id,
        b.constellation_id,
        b.killmail_ids,
        b.participant_count,
        b.kill_count,
        b.total_value
      FROM battles b
      WHERE b.id = $1
    ),
    killmail_data AS (
      SELECT 
        k.killmail_id,
        k.killmail_time,
        k.solar_system_id,
        k.victim_character_id,
        k.victim_corporation_id,
        k.victim_alliance_id,
        k.victim_ship_type_id,
        k.total_value,
        k.data,
        s.system_name,
        s.security_status,
        ch.character_name as victim_name,
        co.corporation_name as victim_corp,
        al.alliance_name as victim_alliance
      FROM killmails_raw k
      LEFT JOIN eve_solar_systems s ON k.solar_system_id = s.system_id
      LEFT JOIN characters ch ON k.victim_character_id = ch.character_id
      LEFT JOIN corporations co ON k.victim_corporation_id = co.corporation_id
      LEFT JOIN alliances al ON k.victim_alliance_id = al.alliance_id
      WHERE k.killmail_id = ANY((SELECT killmail_ids FROM battle_data)::bigint[])
      ORDER BY k.killmail_time ASC
    )
    SELECT 
      json_build_object(
        'battle', row_to_json(bd),
        'killmails', json_agg(kd ORDER BY kd.killmail_time)
      ) as result
    FROM battle_data bd, killmail_data kd
    GROUP BY bd.id, bd.start_time, bd.end_time, bd.system_id, 
             bd.region_id, bd.constellation_id, bd.killmail_ids,
             bd.participant_count, bd.kill_count, bd.total_value
    """

    case Ecto.Adapters.SQL.query(Repo, query, [battle_id]) do
      {:ok, %{rows: [[result]]}} ->
        {:ok, parse_battle_result(result)}

      {:ok, %{rows: []}} ->
        {:error, :battle_not_found}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Batch load multiple battles efficiently.
  Fetches all battles and their killmails in 2 queries instead of N+1.
  """
  def get_battles_batch(battle_ids) when is_list(battle_ids) do
    # Query 1: Get all battles
    battles_query =
      from(b in Battle,
        where: b.id in ^battle_ids,
        select: b
      )

    battles = Repo.all(battles_query)

    # Extract all killmail IDs
    all_killmail_ids =
      battles
      |> Enum.flat_map(& &1.killmail_ids)
      |> Enum.uniq()

    # Query 2: Get all killmails in one query
    killmails_query =
      from(k in KillmailRaw,
        where: k.killmail_id in ^all_killmail_ids,
        left_join: s in assoc(k, :solar_system),
        left_join: vc in assoc(k, :victim_character),
        left_join: vco in assoc(k, :victim_corporation),
        preload: [solar_system: s, victim_character: vc, victim_corporation: vco],
        order_by: [asc: k.killmail_time]
      )

    killmails = Repo.all(killmails_query)

    # Create killmail lookup map for O(1) access
    killmail_map = Map.new(killmails, &{&1.killmail_id, &1})

    # Attach killmails to battles
    battles_with_killmails =
      Enum.map(battles, fn battle ->
        battle_killmails =
          battle.killmail_ids
          |> Enum.map(&Map.get(killmail_map, &1))
          |> Enum.filter(& &1)

        Map.put(battle, :killmails, battle_killmails)
      end)

    {:ok, battles_with_killmails}
  end

  @doc """
  Stream large battle analysis to avoid memory issues.
  Processes battles in chunks for better memory management.
  """
  def analyze_battles_in_range(start_time, end_time, options \\ []) do
    chunk_size = Keyword.get(options, :chunk_size, 10)

    query =
      from(b in Battle,
        where: b.start_time >= ^start_time and b.end_time <= ^end_time,
        order_by: [asc: b.start_time]
      )

    query
    |> Repo.stream(max_rows: chunk_size)
    |> Stream.chunk_every(chunk_size)
    |> Stream.map(&process_battle_chunk/1)
    |> Enum.to_list()
  end

  # Private functions

  defp get_battle_with_killmails_optimized(battle_id) do
    # Use a single query with JOIN to get battle and killmails
    query = """
    SELECT 
      b.id as battle_id,
      b.start_time,
      b.end_time,
      b.system_id,
      b.region_id,
      b.constellation_id,
      b.participant_count,
      b.kill_count,
      b.total_value,
      array_agg(
        json_build_object(
          'killmail_id', k.killmail_id,
          'killmail_time', k.killmail_time,
          'solar_system_id', k.solar_system_id,
          'victim_character_id', k.victim_character_id,
          'victim_corporation_id', k.victim_corporation_id,
          'victim_alliance_id', k.victim_alliance_id,
          'victim_ship_type_id', k.victim_ship_type_id,
          'total_value', k.total_value,
          'data', k.data
        ) ORDER BY k.killmail_time
      ) as killmails
    FROM battles b
    INNER JOIN LATERAL unnest(b.killmail_ids) AS kid ON true
    INNER JOIN killmails_raw k ON k.killmail_id = kid
    WHERE b.id = $1
    GROUP BY b.id, b.start_time, b.end_time, b.system_id, 
             b.region_id, b.constellation_id, b.participant_count,
             b.kill_count, b.total_value
    """

    case Ecto.Adapters.SQL.query(Repo, query, [battle_id]) do
      {:ok, %{rows: [row]}} ->
        battle = parse_battle_row(row)
        {:ok, battle}

      {:ok, %{rows: []}} ->
        {:error, :battle_not_found}

      {:error, error} ->
        {:error, error}
    end
  end

  defp parse_battle_row([
         battle_id,
         start_time,
         end_time,
         system_id,
         region_id,
         constellation_id,
         participant_count,
         kill_count,
         total_value,
         killmails_json
       ]) do
    killmails = Enum.map(killmails_json, &parse_killmail_json/1)

    %{
      id: battle_id,
      start_time: start_time,
      end_time: end_time,
      system_id: system_id,
      region_id: region_id,
      constellation_id: constellation_id,
      participant_count: participant_count,
      kill_count: kill_count,
      total_value: total_value,
      killmails: killmails
    }
  end

  defp parse_killmail_json(json) do
    %{
      killmail_id: json["killmail_id"],
      killmail_time: json["killmail_time"],
      solar_system_id: json["solar_system_id"],
      victim_character_id: json["victim_character_id"],
      victim_corporation_id: json["victim_corporation_id"],
      victim_alliance_id: json["victim_alliance_id"],
      victim_ship_type_id: json["victim_ship_type_id"],
      total_value: json["total_value"],
      raw_data: json["data"]
    }
  end

  defp process_battle_chunk(battles) do
    # Get all killmail IDs for this chunk
    all_killmail_ids =
      battles
      |> Enum.flat_map(& &1.killmail_ids)
      |> Enum.uniq()

    # Batch fetch all killmails
    killmails =
      from(k in KillmailRaw,
        where: k.killmail_id in ^all_killmail_ids,
        order_by: [asc: k.killmail_time]
      )
      |> Repo.all()

    # Create lookup map
    killmail_map = Map.new(killmails, &{&1.killmail_id, &1})

    # Process each battle
    Enum.map(battles, fn battle ->
      battle_killmails =
        battle.killmail_ids
        |> Enum.map(&Map.get(killmail_map, &1))
        |> Enum.filter(& &1)

      analyze_single_battle(battle, battle_killmails)
    end)
  end

  defp analyze_single_battle(battle, killmails) do
    %{
      battle_id: battle.id,
      start_time: battle.start_time,
      end_time: battle.end_time,
      metrics: calculate_battle_metrics(killmails, nil),
      participant_count: battle.participant_count,
      total_value: battle.total_value
    }
  end

  defp build_battle_summary(battle, killmails) do
    %{
      battle_id: battle.id,
      location: %{
        system_id: battle.system_id,
        region_id: battle.region_id,
        constellation_id: battle.constellation_id
      },
      time_span: %{
        start: battle.start_time,
        end: battle.end_time,
        duration_minutes: calculate_duration(killmails)
      },
      scale: categorize_battle_scale(killmails),
      intensity: calculate_battle_intensity(killmails),
      total_isk_destroyed: battle.total_value
    }
  end

  defp calculate_battle_metrics(killmails, _participants) do
    %{
      total_kills: length(killmails),
      duration_minutes: calculate_duration(killmails),
      kills_per_minute: calculate_kill_rate(killmails),
      average_kill_value: calculate_average_kill_value(killmails),
      unique_systems: count_unique_systems(killmails)
    }
  end

  defp calculate_duration(killmails) when length(killmails) <= 1, do: 1

  defp calculate_duration(killmails) do
    first = List.first(killmails)
    last = List.last(killmails)

    seconds = DateTimeUtils.diff(last.killmail_time, first.killmail_time, :second)
    max(Float.round(seconds / 60, 1), 1)
  end

  defp calculate_kill_rate([]), do: 0

  defp calculate_kill_rate(killmails) do
    duration = calculate_duration(killmails)
    if duration > 0, do: Float.round(length(killmails) / duration, 2), else: 0
  end

  defp calculate_average_kill_value([]), do: 0

  defp calculate_average_kill_value(killmails) do
    total = Enum.reduce(killmails, 0, fn km, acc -> acc + (km.total_value || 0) end)
    Float.round(total / length(killmails), 2)
  end

  defp count_unique_systems(killmails) do
    killmails
    |> Enum.map(& &1.solar_system_id)
    |> Enum.uniq()
    |> length()
  end

  defp categorize_battle_scale(killmails) do
    participant_count = count_unique_participants(killmails)

    cond do
      participant_count <= 5 -> :small_gang
      participant_count <= 25 -> :medium_gang
      participant_count <= 100 -> :large_gang
      true -> :fleet_battle
    end
  end

  defp calculate_battle_intensity(killmails) do
    kill_rate = calculate_kill_rate(killmails)

    cond do
      kill_rate >= 5 -> :extreme
      kill_rate >= 3 -> :high
      kill_rate >= 1 -> :moderate
      true -> :low
    end
  end

  defp count_unique_participants(killmails) do
    killmails
    |> Enum.flat_map(fn km ->
      victim = [Map.get(km, :victim_character_id)]

      raw_data = Map.get(km, :raw_data) || Map.get(km, :data) || %{}

      attackers =
        case raw_data do
          %{"attackers" => attackers} when is_list(attackers) ->
            Enum.map(attackers, & &1["character_id"])

          _ ->
            []
        end

      victim ++ attackers
    end)
    |> Enum.filter(& &1)
    |> Enum.uniq()
    |> length()
  end

  defp parse_battle_result(%{"battle" => battle_data, "killmails" => killmails_data}) do
    %{
      battle: parse_battle_data(battle_data),
      killmails: Enum.map(killmails_data || [], &parse_killmail_data/1)
    }
  end

  defp parse_battle_data(data) do
    %{
      id: data["id"],
      start_time: data["start_time"],
      end_time: data["end_time"],
      system_id: data["system_id"],
      region_id: data["region_id"],
      constellation_id: data["constellation_id"],
      participant_count: data["participant_count"],
      kill_count: data["kill_count"],
      total_value: data["total_value"]
    }
  end

  defp parse_killmail_data(data) do
    %{
      killmail_id: data["killmail_id"],
      killmail_time: data["killmail_time"],
      solar_system_id: data["solar_system_id"],
      victim_character_id: data["victim_character_id"],
      victim_corporation_id: data["victim_corporation_id"],
      victim_alliance_id: data["victim_alliance_id"],
      victim_ship_type_id: data["victim_ship_type_id"],
      total_value: data["total_value"],
      victim_name: data["victim_name"],
      victim_corp: data["victim_corp"],
      victim_alliance: data["victim_alliance"],
      system_name: data["system_name"],
      security_status: data["security_status"]
    }
  end

  # Helper functions for get_battle_metrics

  defp calculate_total_isk(killmails) do
    Enum.reduce(killmails, 0.0, fn km, acc ->
      acc + (km.total_value || 0.0)
    end)
  end

  defp count_unique_corporations(killmails) do
    killmails
    |> Enum.flat_map(fn km ->
      victim_corp = km.victim_corporation_id
      raw_data = Map.get(km, :raw_data) || Map.get(km, :data) || %{}

      attacker_corps =
        case raw_data do
          %{"attackers" => attackers} when is_list(attackers) ->
            Enum.map(attackers, & &1["corporation_id"])

          _ ->
            []
        end

      [victim_corp | attacker_corps] |> Enum.reject(&is_nil/1)
    end)
    |> Enum.uniq()
    |> length()
  end

  defp count_unique_alliances(killmails) do
    killmails
    |> Enum.flat_map(fn km ->
      victim_alliance = km.victim_alliance_id
      raw_data = Map.get(km, :raw_data) || Map.get(km, :data) || %{}

      attacker_alliances =
        case raw_data do
          %{"attackers" => attackers} when is_list(attackers) ->
            Enum.map(attackers, & &1["alliance_id"])

          _ ->
            []
        end

      [victim_alliance | attacker_alliances] |> Enum.reject(&is_nil/1)
    end)
    |> Enum.uniq()
    |> length()
  end

  defp get_ship_classes(killmails) do
    killmails
    |> Enum.map(& &1.victim_ship_type_id)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&{&1, EveDmv.StaticData.ShipTypes.classify_ship_type(&1)})
    |> Enum.group_by(fn {_type_id, class} -> class end)
    |> Enum.map(fn {class, ships} -> {class, length(ships)} end)
    |> Map.new()
  end

  defp get_system_security(battle) do
    EveDmv.StaticData.SystemData.get_security_status(battle.system_id)
  end

  defp find_peak_activity(killmails) do
    killmails
    |> Enum.group_by(fn km ->
      km.killmail_time
      |> DateTimeUtils.truncate_to_minute()
    end)
    |> Enum.max_by(fn {_time, kms} -> length(kms) end, fn -> {nil, []} end)
    |> elem(0)
  end

  # Helper functions for get_battle_summary

  defp generate_summary_headline(analysis) do
    scale = get_in(analysis, [:summary, :scale]) || :unknown
    total_kills = get_in(analysis, [:metrics, :total_kills]) || 0
    duration = get_in(analysis, [:metrics, :duration_minutes]) || 0

    scale_text =
      case scale do
        :fleet_battle -> "Fleet Battle"
        :large_gang -> "Large Gang Fight"
        :medium_gang -> "Medium Gang Fight"
        :small_gang -> "Small Gang Skirmish"
        _ -> "Engagement"
      end

    "#{scale_text}: #{total_kills} kills over #{duration} minutes"
  end

  defp extract_summary_key_stats(analysis) do
    [
      %{label: "Total Kills", value: get_in(analysis, [:metrics, :total_kills]) || 0},
      %{label: "Duration", value: "#{get_in(analysis, [:metrics, :duration_minutes]) || 0} min"},
      %{label: "ISK Destroyed", value: get_in(analysis, [:summary, :total_isk_destroyed]) || 0},
      %{label: "Kills/Min", value: get_in(analysis, [:metrics, :kills_per_minute]) || 0}
    ]
  end

  defp determine_battle_winner(analysis) do
    case get_in(analysis, [:performance_metrics, :side_comparison]) do
      %{winner: winner} when not is_nil(winner) -> winner
      _ -> :unknown
    end
  end

  defp find_battle_mvp(analysis) do
    case get_in(analysis, [:performance_metrics, :top_performers]) do
      [top | _] -> top
      _ -> nil
    end
  end

  defp identify_battle_turning_point(analysis) do
    case get_in(analysis, [:tactical_patterns, :momentum_shifts]) do
      [shift | _] -> shift
      _ -> nil
    end
  end

  defp find_battle_notable_kills(analysis) do
    case get_in(analysis, [:performance_metrics, :notable_kills]) do
      kills when is_list(kills) -> Enum.take(kills, 5)
      _ -> []
    end
  end
end
