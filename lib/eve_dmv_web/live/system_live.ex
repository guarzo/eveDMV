defmodule EveDmvWeb.SystemLive do
  @moduledoc """
  LiveView for system intelligence and activity analysis.

  Displays real killmail data, structure kills, danger assessment,
  and corporation/alliance presence for a specific solar system.
  """

  use EveDmvWeb, :live_view

  on_mount({EveDmvWeb.AuthLive, :load_from_session_optional})

  import EveDmvWeb.Components.HistoricalFetchIndicator
  import EveDmvWeb.FormatHelpers

  alias Ecto.Adapters.SQL
  alias EveDmv.Contexts.BattleAnalysis.Domain.Services.DetectionService, as: BattleDetector
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Core.Utils.NumericUtils
  alias EveDmv.Eve.NameResolver
  alias EveDmv.Eve.SolarSystem
  alias EveDmv.Platform.Cache.AnalysisCache
  alias EveDmv.Repo

  # Structure group names from EVE SDE for identifying citadels and upwell structures.
  # These are authoritative group_name values from the eve_item_types table.
  # Used in parameterized SQL queries (passed as query parameters, not interpolated).
  @structure_group_names [
    # Upwell structures (modern citadels)
    "Citadel",
    "Engineering Complex",
    "Refinery",
    # Legacy POS structures
    "Control Tower",
    "POS Module",
    "Starbase",
    # Sovereignty structures
    "Territorial Claim Unit",
    "Infrastructure Hub",
    "Sovereignty Blockade Unit"
  ]

  @impl Phoenix.LiveView
  def mount(%{"system_id" => system_id}, _session, socket) do
    system_id = String.to_integer(system_id)

    # Subscribe to historical fetch updates when connected
    if connected?(socket) do
      subscribe_to_historical_fetch(:system, system_id)
    end

    # Get current historical fetch status
    historical_status = get_historical_fetch_status(:system, system_id)

    # Load system info and activity data
    case load_system_data(system_id) do
      {:ok, system_data} ->
        {:ok,
         assign(socket,
           page_title: "System Intelligence - #{system_data.system_name}",
           system_id: system_id,
           system_data: system_data,
           loading: false,
           detail_panel: nil,
           detail_type: nil,
           historical_fetch_status: historical_status
         )}

      {:error, :not_found} ->
        {:ok,
         assign(socket,
           page_title: "System Not Found",
           system_id: system_id,
           system_data: nil,
           loading: false,
           error: "System not found",
           historical_fetch_status: nil
         )}

      {:error, reason} ->
        {:ok,
         assign(socket,
           page_title: "System Intelligence",
           system_id: system_id,
           system_data: nil,
           loading: false,
           error: "Failed to load system data: #{reason}",
           historical_fetch_status: nil
         )}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:cache_updated, cache_key}, socket) do
    if String.contains?(cache_key, "system_#{socket.assigns.system_id}") do
      # Refresh system data when cache is updated
      case load_system_data(socket.assigns.system_id) do
        {:ok, system_data} ->
          {:noreply, assign(socket, system_data: system_data)}

        {:error, _reason} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  # Handle historical fetch status updates via PubSub
  def handle_info({:historical_fetch_update, :system, _entity_id, update}, socket) do
    system_id = socket.assigns.system_id

    case update do
      {:progress, _progress} ->
        status = get_historical_fetch_status(:system, system_id)
        {:noreply, assign(socket, :historical_fetch_status, status)}

      {:completed, _result} ->
        status = get_historical_fetch_status(:system, system_id)
        # Reload data to include new historical killmails
        case load_system_data(system_id) do
          {:ok, system_data} ->
            {:noreply,
             socket
             |> assign(:historical_fetch_status, status)
             |> assign(:system_data, system_data)}

          {:error, _} ->
            {:noreply, assign(socket, :historical_fetch_status, status)}
        end

      {:failed, _reason} ->
        status = get_historical_fetch_status(:system, system_id)
        {:noreply, assign(socket, :historical_fetch_status, status)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("show_kills", _params, socket) do
    {:noreply, assign(socket, detail_panel: :kills, detail_type: :kills)}
  end

  def handle_event("show_pilots", _params, socket) do
    {:noreply, assign(socket, detail_panel: :pilots, detail_type: :pilots)}
  end

  def handle_event("show_corporations", _params, socket) do
    {:noreply, assign(socket, detail_panel: :corporations, detail_type: :corporations)}
  end

  def handle_event("close_detail_panel", _params, socket) do
    {:noreply, assign(socket, detail_panel: nil, detail_type: nil)}
  end

  def handle_event(
        "retry_historical_fetch",
        %{"entity_type" => "system", "entity_id" => id},
        socket
      ) do
    entity_id = String.to_integer(id)
    queue_historical_fetch(:system, entity_id)
    status = get_historical_fetch_status(:system, entity_id)
    {:noreply, assign(socket, :historical_fetch_status, status)}
  end

  # Load comprehensive system data with caching
  defp load_system_data(system_id) do
    cache_key = "system_#{system_id}_overview"

    AnalysisCache.get_or_compute(
      cache_key,
      fn ->
        with {:ok, system_info} <- get_system_info(system_id),
             {:ok, activity_stats} <- get_activity_statistics(system_id),
             {:ok, structure_kills} <- get_structure_kills(system_id),
             {:ok, corp_presence} <- get_corporation_presence(system_id),
             {:ok, danger_assessment} <- calculate_danger_assessment(system_id),
             {:ok, activity_heatmap} <- get_activity_heatmap(system_id),
             {:ok, recent_kills} <- get_recent_kills(system_id),
             {:ok, recent_pilots} <- get_recent_pilots(system_id) do
          # Calculate peak activity hour and timezone
          peak_hour =
            if Enum.any?(activity_heatmap),
              do: Enum.max_by(activity_heatmap, & &1.count),
              else: %{hour: 12, count: 0}

          primary_timezone = calculate_primary_timezone(peak_hour.hour)

          # Load battle data
          recent_battles = BattleDetector.detect_system_battles(system_id, 10)
          battle_stats = BattleDetector.get_system_battle_stats(system_id)

          # Get corrected security class (handles wormhole detection properly)
          security_info = NameResolver.system_security(system_id)

          # Separate regular kills from structure kills
          {ship_kills, structure_kill_list} =
            Enum.split_with(recent_kills, fn kill -> not kill.is_structure end)

          system_data = %{
            system_name: system_info.system_name,
            region_name: system_info.region_name,
            constellation_name: system_info.constellation_name,
            security_status: system_info.security_status,
            security_class: security_info.class,
            activity_stats: activity_stats,
            structure_kills: structure_kills,
            corp_presence: corp_presence,
            recent_pilots: recent_pilots,
            danger_assessment: danger_assessment,
            activity_heatmap: activity_heatmap,
            peak_activity_hour: peak_hour.hour,
            primary_timezone: primary_timezone,
            recent_battles: recent_battles,
            battle_stats: battle_stats,
            recent_kills: ship_kills,
            recent_structure_kills: structure_kill_list
          }

          {:ok, system_data}
        else
          {:error, reason} -> {:error, reason}
        end
      end,
      # 15 minute cache
      900_000
    )
  end

  # Get basic system information
  defp get_system_info(system_id) do
    case SolarSystem.get_by_id(system_id) do
      {:ok, system} -> {:ok, system}
      {:error, %Ash.Error.Query.NotFound{}} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  # Get activity statistics for the last 30 days
  defp get_activity_statistics(system_id) do
    thirty_days_ago = DateTimeUtils.add(DateTime.utc_now(), -30 * 24 * 60 * 60, :second)

    # Query killmail activity in this system
    killmail_query = """
    SELECT
      COUNT(*) as total_kills,
      COUNT(DISTINCT DATE(k.killmail_time)) as active_days,
      COUNT(DISTINCT p.character_id) as unique_pilots,
      COUNT(DISTINCT p.corporation_id) as unique_corporations,
      COUNT(DISTINCT p.alliance_id) as unique_alliances
    FROM killmails_raw k
    JOIN participants p ON k.killmail_id = p.killmail_id
    WHERE k.solar_system_id = $1
      AND k.killmail_time >= $2
      AND p.final_blow = true
    """

    case SQL.query(Repo, killmail_query, [system_id, thirty_days_ago]) do
      {:ok, %{rows: [[total_kills, active_days, unique_pilots, unique_corps, unique_alliances]]}} ->
        {:ok,
         %{
           total_kills: total_kills || 0,
           active_days: active_days || 0,
           unique_pilots: unique_pilots || 0,
           unique_corporations: unique_corps || 0,
           unique_alliances: unique_alliances || 0,
           kills_per_day:
             if(active_days && active_days > 0, do: (total_kills || 0) / active_days, else: 0.0)
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Get structure and citadel kills
  # Uses EVE SDE group_name for authoritative structure classification
  defp get_structure_kills(system_id) do
    thirty_days_ago = DateTimeUtils.add(DateTime.utc_now(), -30 * 24 * 60 * 60, :second)

    # Query uses parameterized group_name matching via PostgreSQL ANY() operator
    structure_query = """
    SELECT
      t.type_name,
      t.type_id,
      COUNT(*) as kill_count
    FROM killmails_raw k
    JOIN eve_item_types t ON k.victim_ship_type_id = t.type_id
    WHERE k.solar_system_id = $1
      AND k.killmail_time >= $2
      AND t.group_name = ANY($3)
    GROUP BY t.type_id, t.type_name
    ORDER BY kill_count DESC
    LIMIT 20
    """

    case SQL.query(Repo, structure_query, [system_id, thirty_days_ago, @structure_group_names]) do
      {:ok, %{rows: rows}} ->
        structures =
          Enum.map(rows, fn [type_name, type_id, count] ->
            %{
              type_name: type_name,
              type_id: type_id,
              kill_count: count
            }
          end)

        {:ok, structures}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Get corporation and alliance presence
  defp get_corporation_presence(system_id) do
    thirty_days_ago = DateTimeUtils.add(DateTime.utc_now(), -30 * 24 * 60 * 60, :second)

    presence_query = """
    SELECT
      p.corporation_id,
      p.corporation_name,
      p.alliance_id,
      p.alliance_name,
      COUNT(*) as kill_participation,
      COUNT(CASE WHEN p.final_blow = true THEN 1 END) as final_blows,
      COUNT(DISTINCT k.killmail_id) as unique_kills,
      COUNT(DISTINCT p.character_id) as unique_pilots
    FROM participants p
    JOIN killmails_raw k ON p.killmail_id = k.killmail_id
    WHERE k.solar_system_id = $1
      AND k.killmail_time >= $2
    GROUP BY p.corporation_id, p.corporation_name, p.alliance_id, p.alliance_name
    HAVING COUNT(*) >= 3
    ORDER BY kill_participation DESC
    LIMIT 20
    """

    case SQL.query(Repo, presence_query, [system_id, thirty_days_ago]) do
      {:ok, %{rows: rows}} ->
        # Corporation names are resolved at ingestion time in DataProcessor.enrich_entity_names/1
        # If names are missing, run: mix run priv/repo/scripts/backfill_corporation_names.exs
        corporations =
          Enum.map(rows, fn [
                              corp_id,
                              corp_name,
                              alliance_id,
                              alliance_name,
                              participation,
                              final_blows,
                              unique_kills,
                              unique_pilots
                            ] ->
            %{
              corporation_id: corp_id,
              corporation_name: corp_name || "Unknown Corporation",
              alliance_id: alliance_id,
              alliance_name: alliance_name,
              kill_participation: participation,
              final_blows: final_blows,
              unique_kills: unique_kills,
              unique_pilots: unique_pilots,
              activity_score: participation + final_blows * 2 + unique_pilots
            }
          end)

        {:ok, corporations}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Calculate danger assessment score
  defp calculate_danger_assessment(system_id) do
    seven_days_ago = DateTimeUtils.add(DateTime.utc_now(), -7 * 24 * 60 * 60, :second)
    thirty_days_ago = DateTimeUtils.add(DateTime.utc_now(), -30 * 24 * 60 * 60, :second)

    danger_query = """
    SELECT
      COUNT(CASE WHEN k.killmail_time >= $2 THEN 1 END) as recent_kills,
      COUNT(CASE WHEN k.killmail_time >= $3 THEN 1 END) as total_kills,
      COUNT(DISTINCT CASE WHEN k.killmail_time >= $2 THEN p.corporation_id END) as recent_hostile_corps,
      COUNT(DISTINCT CASE WHEN k.killmail_time >= $2 THEN DATE(k.killmail_time) END) as recent_active_days,
      COALESCE(AVG(CASE WHEN k.killmail_time >= $2 THEN
        COALESCE(k.total_value, (k.raw_data->'zkb'->>'totalValue')::numeric)
      END), 0) as recent_avg_value
    FROM killmails_raw k
    JOIN participants p ON k.killmail_id = p.killmail_id
    WHERE k.solar_system_id = $1
      AND k.killmail_time >= $3
      AND p.final_blow = true
    """

    case SQL.query(Repo, danger_query, [
           system_id,
           seven_days_ago,
           thirty_days_ago
         ]) do
      {:ok, %{rows: [[recent_kills, total_kills, hostile_corps, active_days, avg_value]]}} ->
        # Calculate danger score (0-100) without value component
        # Up to 40 points for recent activity
        recent_activity_score = min((recent_kills || 0) * 5, 40)
        # Up to 30 points for multiple hostile corps
        hostility_score = min((hostile_corps || 0) * 3, 30)
        # Up to 30 points for consistent activity
        consistency_score = min((active_days || 0) * 4, 30)

        danger_score = recent_activity_score + hostility_score + consistency_score

        danger_level =
          cond do
            danger_score >= 80 -> "Extreme"
            danger_score >= 60 -> "High"
            danger_score >= 40 -> "Moderate"
            danger_score >= 20 -> "Low"
            true -> "Minimal"
          end

        {:ok,
         %{
           danger_score: danger_score,
           danger_level: danger_level,
           recent_kills: recent_kills || 0,
           total_kills: total_kills || 0,
           hostile_corporations: hostile_corps || 0,
           active_days: active_days || 0,
           recent_avg_value: NumericUtils.to_float(avg_value) || 0.0
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Get 24-hour activity heatmap
  defp get_activity_heatmap(system_id) do
    thirty_days_ago = DateTimeUtils.add(DateTime.utc_now(), -30 * 24 * 60 * 60, :second)

    heatmap_query = """
    SELECT
      CAST(EXTRACT(HOUR FROM k.killmail_time AT TIME ZONE 'UTC') AS INTEGER) as hour,
      COUNT(*) as kill_count
    FROM killmails_raw k
    WHERE k.solar_system_id = $1
      AND k.killmail_time >= $2
    GROUP BY hour
    ORDER BY hour
    """

    case SQL.query(Repo, heatmap_query, [system_id, thirty_days_ago]) do
      {:ok, %{rows: rows}} ->
        heatmap_data = process_activity_heatmap_data(rows)
        {:ok, heatmap_data}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_activity_heatmap_data(rows) do
    # Create array for all 24 hours
    activity_by_hour =
      Enum.map(0..23, fn hour ->
        count = find_hour_count(rows, hour)
        %{hour: hour, count: count}
      end)

    max_count = activity_by_hour |> Enum.max_by(& &1.count) |> Map.get(:count, 1)

    # Calculate percentages for visualization
    Enum.map(activity_by_hour, fn %{hour: hour, count: count} ->
      %{
        hour: hour,
        count: count,
        percentage: if(max_count > 0, do: round(count / max_count * 100), else: 0)
      }
    end)
  end

  defp find_hour_count(rows, hour) do
    Enum.find_value(rows, 0, fn [hour_value, count] ->
      if hour_value == hour, do: count, else: nil
    end)
  end

  # Calculate primary timezone based on peak activity hour
  defp calculate_primary_timezone(peak_hour) do
    cond do
      peak_hour >= 0 && peak_hour < 6 -> "AUTZ (Oceania)"
      peak_hour >= 6 && peak_hour < 14 -> "EUTZ (Europe)"
      peak_hour >= 14 && peak_hour < 22 -> "USTZ (Americas)"
      true -> "AUTZ (Oceania)"
    end
  end

  # Get recent kills in this system (last 7 days, max 20)
  defp get_recent_kills(system_id) do
    seven_days_ago = DateTimeUtils.add(DateTime.utc_now(), -7 * 24 * 60 * 60, :second)

    kills_query = """
    SELECT
      k.killmail_id,
      k.killmail_time,
      k.victim_character_id,
      k.victim_ship_type_id,
      COALESCE(k.total_value, (k.raw_data->'zkb'->>'totalValue')::numeric, 0) as total_value,
      k.attacker_count,
      t.type_name as ship_name,
      t.group_name as ship_group,
      COALESCE(k.raw_data->'victim'->>'character_name', 'Unknown Pilot') as victim_name,
      COALESCE(k.raw_data->'victim'->>'corporation_name', 'Unknown Corp') as corporation_name
    FROM killmails_raw k
    LEFT JOIN eve_item_types t ON k.victim_ship_type_id = t.type_id
    WHERE k.solar_system_id = $1
      AND k.killmail_time >= $2
    ORDER BY k.killmail_time DESC
    LIMIT 20
    """

    case SQL.query(Repo, kills_query, [system_id, seven_days_ago]) do
      {:ok, %{rows: rows}} ->
        kills =
          Enum.map(rows, fn [
                              killmail_id,
                              killmail_time,
                              victim_character_id,
                              victim_ship_type_id,
                              total_value,
                              attacker_count,
                              ship_name,
                              ship_group,
                              victim_name,
                              corporation_name
                            ] ->
            # Determine if this is a structure kill
            is_structure = structure_kill?(ship_group, ship_name)

            %{
              killmail_id: killmail_id,
              killmail_time: killmail_time,
              victim_character_id: victim_character_id,
              victim_ship_type_id: victim_ship_type_id,
              total_value: total_value || Decimal.new(0),
              attacker_count: attacker_count || 0,
              ship_name: ship_name || "Unknown Ship",
              ship_group: ship_group,
              victim_name: victim_name,
              corporation_name: corporation_name,
              is_structure: is_structure
            }
          end)

        {:ok, kills}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Get recent pilots active in this system (attackers on kills)
  defp get_recent_pilots(system_id) do
    thirty_days_ago = DateTimeUtils.add(DateTime.utc_now(), -30 * 24 * 60 * 60, :second)

    pilots_query = """
    SELECT
      p.character_id,
      p.character_name,
      p.corporation_id,
      p.corporation_name,
      p.ship_type_id,
      t.type_name as ship_name,
      COUNT(*) as kill_count,
      MAX(k.killmail_time) as last_seen,
      SUM(CASE WHEN p.final_blow = true THEN 1 ELSE 0 END) as final_blows
    FROM participants p
    JOIN killmails_raw k ON p.killmail_id = k.killmail_id
    LEFT JOIN eve_item_types t ON p.ship_type_id = t.type_id
    WHERE k.solar_system_id = $1
      AND k.killmail_time >= $2
      AND p.character_id IS NOT NULL
    GROUP BY p.character_id, p.character_name, p.corporation_id, p.corporation_name,
             p.ship_type_id, t.type_name
    ORDER BY kill_count DESC, last_seen DESC
    LIMIT 30
    """

    case SQL.query(Repo, pilots_query, [system_id, thirty_days_ago]) do
      {:ok, %{rows: rows}} ->
        # Group by character to combine ship usage
        pilots_by_id =
          Enum.reduce(rows, %{}, fn [
                                      character_id,
                                      character_name,
                                      corporation_id,
                                      corporation_name,
                                      _ship_type_id,
                                      ship_name,
                                      kill_count,
                                      last_seen,
                                      final_blows
                                    ],
                                    acc ->
            Map.update(
              acc,
              character_id,
              %{
                character_id: character_id,
                character_name: character_name || "Unknown Pilot",
                corporation_id: corporation_id,
                corporation_name: corporation_name || "Unknown Corp",
                last_ship: ship_name || "Unknown Ship",
                kill_count: kill_count,
                final_blows: final_blows,
                last_seen: last_seen
              },
              fn existing ->
                %{
                  existing
                  | kill_count: existing.kill_count + kill_count,
                    final_blows: existing.final_blows + final_blows,
                    last_seen: max_datetime(existing.last_seen, last_seen),
                    last_ship: select_most_recent_ship(existing, ship_name, last_seen)
                }
              end
            )
          end)

        pilots =
          pilots_by_id
          |> Map.values()
          |> Enum.sort_by(& &1.kill_count, :desc)
          |> Enum.take(20)

        {:ok, pilots}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp max_datetime(nil, dt), do: dt
  defp max_datetime(dt, nil), do: dt

  defp max_datetime(dt1, dt2) do
    if DateTime.compare(dt1, dt2) == :gt, do: dt1, else: dt2
  end

  # Select the most recent ship based on last_seen timestamps
  defp select_most_recent_ship(existing, ship_name, last_seen) do
    cond do
      is_nil(last_seen) ->
        existing.last_ship

      is_nil(existing.last_seen) ->
        ship_name || existing.last_ship

      DateTime.compare(last_seen, existing.last_seen) == :gt ->
        ship_name || existing.last_ship

      true ->
        existing.last_ship
    end
  end

  # Check if a kill is a structure/citadel using EVE SDE group_name
  # Uses @structure_group_names module attribute for consistency with SQL query
  defp structure_kill?(ship_group, _ship_name) do
    ship_group && ship_group in @structure_group_names
  end

  # Historical fetch helpers
  # These functions integrate with the KillmailProcessing context for 2-year historical data.
  # The backend API (Phase 4) provides the actual implementation; these are the LiveView wrappers.

  defp get_historical_fetch_status(entity_type, entity_id) do
    # Try to get status from KillmailProcessing API if available
    # Returns nil if not found (component handles nil gracefully)
    require Ash.Query
    import Ash.Expr

    entity_type_str = to_string(entity_type)

    case EveDmv.Contexts.KillmailProcessing.Resources.HistoricalFetchStatus
         |> Ash.Query.filter(expr(entity_type == ^entity_type_str and entity_id == ^entity_id))
         |> Ash.read_one(domain: EveDmv.Api) do
      {:ok, status} when not is_nil(status) ->
        %{
          status: String.to_existing_atom(status.status),
          killmails_fetched: status.killmails_fetched,
          oldest_killmail_date: status.oldest_killmail_date,
          target_date: status.target_date
        }

      _ ->
        nil
    end
  rescue
    # Handle case where resource doesn't exist yet (Phase 1B not complete)
    _ -> nil
  end

  defp subscribe_to_historical_fetch(entity_type, entity_id) do
    # Subscribe to PubSub topic for historical fetch updates
    topic = "historical_fetch:#{entity_type}:#{entity_id}"
    Phoenix.PubSub.subscribe(EveDmv.PubSub, topic)
  rescue
    # Gracefully handle if PubSub not configured
    _ -> :ok
  end

  defp queue_historical_fetch(entity_type, entity_id) do
    # Queue a historical fetch via the worker (Phase 4B)
    # This is a no-op if the worker isn't running yet
    case Code.ensure_loaded(EveDmv.Contexts.KillmailProcessing.Domain.HistoricalFetchWorker) do
      {:module, worker} ->
        worker.queue_fetch(entity_type, entity_id)

      _ ->
        {:error, :worker_not_available}
    end
  rescue
    _ -> {:error, :worker_not_available}
  end
end
