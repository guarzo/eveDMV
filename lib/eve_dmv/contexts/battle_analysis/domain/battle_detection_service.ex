defmodule EveDmv.Contexts.BattleAnalysis.Domain.BattleDetectionService do
  @moduledoc """
  Service for detecting and clustering killmails into battles.

  Uses time-based clustering with spatial correlation and participant overlap
  to identify discrete battles from killmail data.
  """

  import Ash.Query

  alias EveDmv.Api
  alias EveDmv.Contexts.BattleAnalysis.Domain.ParticipantExtractor
  alias EveDmv.Killmails.KillmailRaw

  require Logger

  # Battle detection parameters
  @max_time_gap_minutes 30
  @max_participant_time_gap_minutes 60
  @min_participants_for_battle 2
  @min_participant_overlap_ratio 0.3

  @doc """
  Detects battles from killmail data within a time range.

  ## Parameters
  - start_time: DateTime or NaiveDateTime for start of search window
  - end_time: DateTime or NaiveDateTime for end of search window
  - options: Keyword list of options
    - :min_participants - minimum participants to consider a battle (default: 2)
    - :max_time_gap - maximum time gap between kills in minutes (default: 10)
    - :same_system_only - only cluster kills in same system (default: true)

  ## Returns
  {:ok, [%{battle_id: String, killmails: [KillmailRaw], metadata: map}]}
  """
  def detect_battles(start_time, end_time, options \\ []) do
    min_participants = Keyword.get(options, :min_participants, @min_participants_for_battle)
    max_time_gap = Keyword.get(options, :max_time_gap, @max_time_gap_minutes)
    same_system_only = Keyword.get(options, :same_system_only, true)

    Logger.info("Detecting battles between #{inspect(start_time)} and #{inspect(end_time)}")

    with {:ok, killmails} <- fetch_killmails_in_range(start_time, end_time) do
      battles =
        killmails
        |> cluster_killmails_by_time_and_space(max_time_gap, same_system_only)
        |> filter_by_participant_count(min_participants)
        |> enrich_battle_metadata()
        |> assign_battle_ids()

      Logger.info("Detected #{length(battles)} battles from #{length(killmails)} killmails")
      {:ok, battles}
    end
  end

  @doc """
  Detects battles in a specific solar system within a time range.
  """
  def detect_battles_in_system(system_id, start_time, end_time, options \\ []) do
    Logger.info("Detecting battles in system #{system_id}")

    with {:ok, killmails} <- fetch_killmails_in_system(system_id, start_time, end_time) do
      battles =
        killmails
        |> cluster_killmails_by_time_and_space(
          Keyword.get(options, :max_time_gap, @max_time_gap_minutes),
          # same_system_only is always true for system-specific search
          true
        )
        |> filter_by_participant_count(
          Keyword.get(options, :min_participants, @min_participants_for_battle)
        )
        |> enrich_battle_metadata()
        |> assign_battle_ids()

      Logger.info("Detected #{length(battles)} battles in system #{system_id}")
      {:ok, battles}
    end
  end

  @doc """
  Analyzes a potential battle from a list of killmail IDs.
  Useful for analyzing battles from external sources like zkillboard.
  """
  def analyze_battle_from_killmail_ids(killmail_ids) when is_list(killmail_ids) do
    Logger.info("Analyzing battle from #{length(killmail_ids)} killmail IDs")

    with {:ok, killmails} <- fetch_killmails_by_ids(killmail_ids) do
      case killmails do
        [] ->
          {:error, :no_killmails_found}

        [single_kill] ->
          # Single killmail - create minimal battle
          battle = %{
            battle_id: generate_battle_id([single_kill]),
            killmails: [single_kill],
            metadata:
              create_battle_metadata([single_kill], %{
                start_time: single_kill.killmail_time,
                end_time: single_kill.killmail_time
              })
          }

          {:ok, battle}

        multiple_kills ->
          # Multiple killmails - analyze as battle
          battles =
            multiple_kills
            |> cluster_killmails_by_time_and_space(@max_time_gap_minutes, false)
            |> enrich_battle_metadata()
            |> assign_battle_ids()

          case battles do
            [single_battle] -> {:ok, single_battle}
            [] -> {:error, :no_valid_battles}
            multiple_battles -> {:ok, %{battles: multiple_battles, type: :multiple_battles}}
          end
      end
    end
  end

  # Private functions

  defp fetch_killmails_in_range(start_time, end_time) do
    try do
      query =
        KillmailRaw
        |> new()
        |> filter(killmail_time: [gte: start_time, lte: end_time])
        |> sort(killmail_time: :asc)
        # Reasonable limit for battle analysis
        |> limit(1000)

      case Ash.read(query, domain: Api) do
        {:ok, filtered_killmails} ->
          {:ok, filtered_killmails}

        {:error, error} ->
          Logger.error("Failed to fetch killmails in range: #{inspect(error)}")
          {:error, :database_error}
      end
    rescue
      error ->
        Logger.error("Failed to fetch killmails in range: #{inspect(error)}")
        {:error, :database_error}
    end
  end

  defp fetch_killmails_in_system(system_id, start_time, end_time) do
    try do
      query =
        KillmailRaw
        |> new()
        |> filter(solar_system_id: system_id)
        |> filter(killmail_time: [gte: start_time, lte: end_time])
        |> sort(killmail_time: :asc)
        # Reasonable limit for single system
        |> limit(500)

      case Ash.read(query, domain: Api) do
        {:ok, filtered_killmails} ->
          {:ok, filtered_killmails}

        {:error, error} ->
          Logger.error("Failed to fetch killmails in system #{system_id}: #{inspect(error)}")
          {:error, :database_error}
      end
    rescue
      error ->
        Logger.error("Failed to fetch killmails in system #{system_id}: #{inspect(error)}")
        {:error, :database_error}
    end
  end

  defp fetch_killmails_by_ids(killmail_ids) do
    try do
      query =
        KillmailRaw
        |> new()
        |> filter(killmail_id: [in: killmail_ids])
        |> sort(killmail_time: :asc)

      case Ash.read(query, domain: Api) do
        {:ok, killmails} ->
          filtered_killmails = killmails

          {:ok, filtered_killmails}

        {:error, error} ->
          Logger.error("Failed to fetch killmails by IDs: #{inspect(error)}")
          {:error, :database_error}
      end
    rescue
      error ->
        Logger.error("Failed to fetch killmails by IDs: #{inspect(error)}")
        {:error, :database_error}
    end
  end

  defp cluster_killmails_by_time_and_space(killmails, max_time_gap_minutes, same_system_only) do
    killmails
    |> Enum.sort_by(& &1.killmail_time)
    |> Enum.reduce([], fn killmail, clusters ->
      add_to_cluster(killmail, clusters, max_time_gap_minutes, same_system_only)
    end)
    |> Enum.map(&Map.put(&1, :killmails, Enum.reverse(&1.killmails)))
  end

  defp add_to_cluster(killmail, [], _max_time_gap, _same_system_only) do
    # First killmail starts first cluster
    [
      %{
        killmails: [killmail],
        start_time: killmail.killmail_time,
        end_time: killmail.killmail_time,
        system_id: killmail.solar_system_id
      }
    ]
  end

  defp add_to_cluster(
         killmail,
         [current_cluster | rest_clusters],
         max_time_gap_minutes,
         same_system_only
       ) do
    time_gap_minutes =
      NaiveDateTime.diff(killmail.killmail_time, current_cluster.end_time, :second) / 60

    # Check for participant overlap for longer time gaps
    participant_overlap_ratio = calculate_participant_overlap(killmail, current_cluster.killmails)

    can_add_to_cluster =
      cond do
        # Close in time and same system (original logic)
        time_gap_minutes <= max_time_gap_minutes and
            (same_system_only == false or killmail.solar_system_id == current_cluster.system_id) ->
          true

        # Longer time gap but significant participant overlap in same system
        time_gap_minutes <= @max_participant_time_gap_minutes and
          participant_overlap_ratio >= @min_participant_overlap_ratio and
            killmail.solar_system_id == current_cluster.system_id ->
          true

        true ->
          false
      end

    if can_add_to_cluster do
      # Add to current cluster
      updated_cluster = %{
        current_cluster
        | killmails: [killmail | current_cluster.killmails],
          end_time: killmail.killmail_time,
          system_id: if(same_system_only, do: current_cluster.system_id, else: nil)
      }

      [updated_cluster | rest_clusters]
    else
      # Try to add to other clusters with participant overlap
      case find_cluster_with_overlap(killmail, rest_clusters) do
        {:found, cluster_index} ->
          # Add to found cluster and move it to front
          {target_cluster, other_clusters} = List.pop_at(rest_clusters, cluster_index)

          updated_cluster = %{
            target_cluster
            | killmails: [killmail | target_cluster.killmails],
              end_time: max(killmail.killmail_time, target_cluster.end_time)
          }

          [current_cluster, updated_cluster | other_clusters]

        :not_found ->
          # Start new cluster
          new_cluster = %{
            killmails: [killmail],
            start_time: killmail.killmail_time,
            end_time: killmail.killmail_time,
            system_id: killmail.solar_system_id
          }

          [new_cluster, current_cluster | rest_clusters]
      end
    end
  end

  defp filter_by_participant_count(clusters, min_participants) do
    Enum.filter(clusters, fn cluster ->
      participant_count = count_unique_participants(cluster.killmails)
      participant_count >= min_participants
    end)
  end

  defp count_unique_participants(killmails) do
    participants =
      killmails
      |> Enum.flat_map(&ParticipantExtractor.extract_participants/1)
      |> Enum.uniq()

    length(participants)
  end

  defp calculate_participant_overlap(killmail, cluster_killmails) do
    killmail_participants = ParticipantExtractor.extract_participants(killmail)

    cluster_participants =
      cluster_killmails
      |> Enum.flat_map(&ParticipantExtractor.extract_participants/1)
      |> Enum.uniq()

    if Enum.empty?(cluster_participants) do
      0.0
    else
      overlap_count =
        killmail_participants
        |> Enum.count(&(&1 in cluster_participants))

      overlap_count / length(cluster_participants)
    end
  end

  defp find_cluster_with_overlap(killmail, clusters) do
    clusters
    |> Enum.with_index()
    |> Enum.find(fn {cluster, _index} ->
      time_gap_minutes =
        NaiveDateTime.diff(killmail.killmail_time, cluster.end_time, :second) / 60

      overlap_ratio = calculate_participant_overlap(killmail, cluster.killmails)

      # Check if killmail can be added to this cluster
      time_gap_minutes <= @max_participant_time_gap_minutes and
        overlap_ratio >= @min_participant_overlap_ratio and
        killmail.solar_system_id == cluster.system_id
    end)
    |> case do
      {_cluster, index} -> {:found, index}
      nil -> :not_found
    end
  end

  defp enrich_battle_metadata(clusters) do
    Enum.map(clusters, fn cluster ->
      metadata = create_battle_metadata(cluster.killmails, cluster)
      Map.put(cluster, :metadata, metadata)
    end)
  end

  defp create_battle_metadata(killmails, cluster) do
    participant_analysis = analyze_participants(killmails)

    base_metadata = %{
      killmail_count: length(killmails),
      duration_minutes: calculate_duration_minutes(killmails),
      unique_participants: participant_analysis.unique_count,
      unique_corporations: participant_analysis.unique_corporations,
      unique_alliances: participant_analysis.unique_alliances,
      primary_system: find_primary_system(killmails),
      isk_destroyed: calculate_total_isk_destroyed(killmails),
      ship_types: analyze_ship_types(killmails),
      battle_type: determine_battle_type(killmails, participant_analysis)
    }

    # Add timing information if cluster is provided
    case cluster do
      nil ->
        base_metadata

      %{start_time: start_time, end_time: end_time} ->
        Map.merge(base_metadata, %{
          start_time: start_time,
          end_time: end_time
        })
    end
  end

  defp analyze_participants(killmails) do
    all_participants = Enum.flat_map(killmails, &ParticipantExtractor.extract_participants/1)

    # Get corporation and alliance data
    corporations =
      killmails
      |> Enum.map(& &1.victim_corporation_id)
      |> Enum.filter(&(&1 != nil))
      |> Enum.uniq()

    alliances =
      killmails
      |> Enum.map(& &1.victim_alliance_id)
      |> Enum.filter(&(&1 != nil))
      |> Enum.uniq()

    %{
      unique_count: length(Enum.uniq(all_participants)),
      unique_corporations: length(corporations),
      unique_alliances: length(alliances)
    }
  end

  defp calculate_duration_minutes(killmails) do
    case killmails do
      [] ->
        0

      # Single kill battles have minimum 1 minute duration
      [_single] ->
        1

      multiple ->
        times = Enum.map(multiple, & &1.killmail_time)
        start_time = Enum.min(times)
        end_time = Enum.max(times)
        duration = NaiveDateTime.diff(end_time, start_time, :second) / 60
        # Only apply minimum if duration is very small (< 0.5 minutes)
        if duration < 0.5, do: 1, else: Float.round(duration, 1)
    end
  end

  defp find_primary_system(killmails) do
    # Find the system with the most killmails
    killmails
    |> Enum.group_by(& &1.solar_system_id)
    |> Enum.max_by(fn {_system_id, kills} -> length(kills) end, fn -> {nil, []} end)
    |> elem(0)
  end

  defp calculate_total_isk_destroyed(killmails) do
    case calculate_killmail_values_batch(killmails) do
      {:ok, values} ->
        values
        |> Enum.sum()
        |> round()

      {:error, _} ->
        # Fallback to individual calculation
        calculate_total_isk_destroyed_fallback(killmails)
    end
  end

  # Optimized batch processing for killmail values
  defp calculate_killmail_values_batch(killmails) do
    alias EveDmv.Market.PriceService

    # First, try to extract zKillboard values (fastest path)
    {zkb_values, needs_calculation} =
      Enum.split_with(killmails, fn killmail ->
        case extract_zkb_value(killmail) do
          {:ok, _value} -> true
          _ -> false
        end
      end)

    zkb_total =
      zkb_values
      |> Enum.map(fn killmail ->
        case extract_zkb_value(killmail) do
          {:ok, value} -> value
          _ -> 0.0
        end
      end)
      |> Enum.sum()

    # For killmails that need calculation, batch the price fetching
    calculation_total =
      case needs_calculation do
        [] ->
          0.0

        killmails_to_calculate ->
          # Extract all unique type IDs from all killmails
          all_type_ids =
            killmails_to_calculate
            |> Enum.flat_map(&extract_type_ids/1)
            |> Enum.uniq()

          # Batch fetch all prices
          case PriceService.get_item_prices(all_type_ids) do
            {:ok, price_map} ->
              killmails_to_calculate
              |> Enum.map(fn killmail ->
                calculate_killmail_value_with_prices(killmail, price_map)
              end)
              |> Enum.sum()

            {:error, _} ->
              0.0
          end
      end

    {:ok, [zkb_total + calculation_total]}
  end

  # Fallback to original individual calculation method  
  defp calculate_total_isk_destroyed_fallback(killmails) do
    alias EveDmv.Market.PriceService

    killmails
    |> Enum.map(fn killmail ->
      case PriceService.calculate_killmail_value(killmail) do
        {:ok, %{total_value: value}} when is_number(value) -> value
        _ -> 0.0
      end
    end)
    |> Enum.sum()
    |> round()
  end

  # Helper to extract zKillboard value
  defp extract_zkb_value(killmail) do
    case killmail.raw_data do
      %{"zkb" => %{"totalValue" => value}} when is_number(value) ->
        {:ok, value}

      _ ->
        {:error, :no_zkb_value}
    end
  end

  # Helper to extract all type IDs from a killmail
  defp extract_type_ids(killmail) do
    type_ids = [killmail.victim_ship_type_id]

    # Extract type IDs from items
    item_type_ids =
      case killmail.raw_data do
        %{"victim" => %{"items" => items}} when is_list(items) ->
          Enum.map(items, fn item -> item["typeID"] end)

        _ ->
          []
      end

    (type_ids ++ item_type_ids)
    |> Enum.filter(&(&1 != nil))
    |> Enum.uniq()
  end

  # Helper to calculate killmail value using pre-fetched prices
  defp calculate_killmail_value_with_prices(killmail, price_map) do
    # Calculate ship value
    ship_value =
      case Map.get(price_map, killmail.victim_ship_type_id) do
        %{buy_price: price} when is_number(price) -> price
        _ -> 0.0
      end

    # Calculate items value
    items_value =
      case killmail.raw_data do
        %{"victim" => %{"items" => items}} when is_list(items) ->
          items
          |> Enum.map(fn item ->
            type_id = item["typeID"]
            quantity = item["quantityDestroyed"] || item["quantityDropped"] || 1

            case Map.get(price_map, type_id) do
              %{buy_price: price} when is_number(price) -> price * quantity
              _ -> 0.0
            end
          end)
          |> Enum.sum()

        _ ->
          0.0
      end

    ship_value + items_value
  end

  defp analyze_ship_types(killmails) do
    killmails
    |> Enum.group_by(& &1.victim_ship_type_id)
    |> Enum.map(fn {type_id, kills} ->
      %{ship_type_id: type_id, count: length(kills)}
    end)
  end

  defp determine_battle_type(killmails, participant_analysis) do
    kill_count = length(killmails)
    participant_count = participant_analysis.unique_count

    cond do
      kill_count == 1 -> :single_kill
      participant_count <= 4 -> :small_gang
      participant_count <= 20 -> :medium_gang
      participant_count <= 100 -> :large_gang
      true -> :fleet_battle
    end
  end

  defp assign_battle_ids(clusters) do
    Enum.map(clusters, fn cluster ->
      battle_id = generate_battle_id(cluster.killmails)
      Map.put(cluster, :battle_id, battle_id)
    end)
  end

  defp generate_battle_id(killmails) do
    # Generate a deterministic battle ID based on the killmails
    case killmails do
      [] ->
        "battle_#{System.unique_integer([:positive])}"

      [first | _] ->
        system_id = first.solar_system_id

        timestamp =
          first.killmail_time |> NaiveDateTime.to_string() |> String.replace([" ", ":", "-"], "")

        "battle_#{system_id}_#{timestamp}"
    end
  end
end
