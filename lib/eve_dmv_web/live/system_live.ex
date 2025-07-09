defmodule EveDmvWeb.SystemLive do
  @moduledoc """
  LiveView for system intelligence and activity analysis.

  Displays real killmail data, structure kills, danger assessment,
  and corporation/alliance presence for a specific solar system.
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Cache.AnalysisCache
  alias EveDmv.Eve.SolarSystem

  @impl true
  def mount(%{"system_id" => system_id}, _session, socket) do
    system_id = String.to_integer(system_id)

    # Load system info and activity data
    case load_system_data(system_id) do
      {:ok, system_data} ->
        {:ok, assign(socket,
          page_title: "System Intelligence - #{system_data.system_name}",
          system_id: system_id,
          system_data: system_data,
          loading: false
        )}

      {:error, :not_found} ->
        {:ok, assign(socket,
          page_title: "System Not Found",
          system_id: system_id,
          system_data: nil,
          loading: false,
          error: "System not found"
        )}

      {:error, reason} ->
        {:ok, assign(socket,
          page_title: "System Intelligence",
          system_id: system_id,
          system_data: nil,
          loading: false,
          error: "Failed to load system data: #{reason}"
        )}
    end
  end

  @impl true
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

  # Load comprehensive system data with caching
  defp load_system_data(system_id) do
    cache_key = "system_#{system_id}_overview"

    AnalysisCache.get_or_compute(cache_key, fn ->
      with {:ok, system_info} <- get_system_info(system_id),
           {:ok, activity_stats} <- get_activity_statistics(system_id),
           {:ok, structure_kills} <- get_structure_kills(system_id),
           {:ok, corp_presence} <- get_corporation_presence(system_id),
           {:ok, danger_assessment} <- calculate_danger_assessment(system_id),
           {:ok, activity_heatmap} <- get_activity_heatmap(system_id) do

        # Calculate peak activity hour and timezone
        peak_hour = if Enum.any?(activity_heatmap), do: Enum.max_by(activity_heatmap, & &1.count), else: %{hour: 12, count: 0}
        primary_timezone = calculate_primary_timezone(peak_hour.hour)
        
        system_data = %{
          system_name: system_info.system_name,
          region_name: system_info.region_name,
          constellation_name: system_info.constellation_name,
          security_status: system_info.security_status,
          security_class: system_info.security_class,
          activity_stats: activity_stats,
          structure_kills: structure_kills,
          corp_presence: corp_presence,
          danger_assessment: danger_assessment,
          activity_heatmap: activity_heatmap,
          peak_activity_hour: peak_hour.hour,
          primary_timezone: primary_timezone
        }

        {:ok, system_data}
      else
        {:error, reason} -> {:error, reason}
      end
    end, 900_000) # 15 minute cache
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
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

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

    case Ecto.Adapters.SQL.query(EveDmv.Repo, killmail_query, [system_id, thirty_days_ago]) do
      {:ok, %{rows: [[total_kills, active_days, unique_pilots, unique_corps, unique_alliances]]}} ->
        {:ok, %{
          total_kills: total_kills || 0,
          active_days: active_days || 0,
          unique_pilots: unique_pilots || 0,
          unique_corporations: unique_corps || 0,
          unique_alliances: unique_alliances || 0,
          kills_per_day: if(active_days && active_days > 0, do: (total_kills || 0) / active_days, else: 0.0)
        }}

      {:error, reason} -> {:error, reason}
    end
  end

  # Get structure and citadel kills
  defp get_structure_kills(system_id) do
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

    structure_query = """
    SELECT
      t.type_name,
      t.type_id,
      COUNT(*) as kill_count
    FROM killmails_raw k
    JOIN eve_item_types t ON k.victim_ship_type_id = t.type_id
    WHERE k.solar_system_id = $1
      AND k.killmail_time >= $2
      AND (
        t.type_name ILIKE '%citadel%' OR
        t.type_name ILIKE '%complex%' OR
        t.type_name ILIKE '%refinery%' OR
        t.type_name ILIKE '%engineering%' OR
        t.type_name ILIKE '%astrahus%' OR
        t.type_name ILIKE '%fortizar%' OR
        t.type_name ILIKE '%keepstar%' OR
        t.type_name ILIKE '%raitaru%' OR
        t.type_name ILIKE '%azbel%' OR
        t.type_name ILIKE '%sotiyo%' OR
        t.type_name ILIKE '%tatara%' OR
        t.type_name ILIKE '%athanor%'
      )
    GROUP BY t.type_id, t.type_name
    ORDER BY kill_count DESC
    LIMIT 20
    """

    case Ecto.Adapters.SQL.query(EveDmv.Repo, structure_query, [system_id, thirty_days_ago]) do
      {:ok, %{rows: rows}} ->
        structures = Enum.map(rows, fn [type_name, type_id, count] ->
          %{
            type_name: type_name,
            type_id: type_id,
            kill_count: count
          }
        end)

        {:ok, structures}

      {:error, reason} -> {:error, reason}
    end
  end

  # Get corporation and alliance presence
  defp get_corporation_presence(system_id) do
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

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

    case Ecto.Adapters.SQL.query(EveDmv.Repo, presence_query, [system_id, thirty_days_ago]) do
      {:ok, %{rows: rows}} ->
        corporations = Enum.map(rows, fn [corp_id, corp_name, alliance_id, alliance_name, participation, final_blows, unique_kills, unique_pilots] ->
          %{
            corporation_id: corp_id,
            corporation_name: corp_name || "Unknown Corporation",
            alliance_id: alliance_id,
            alliance_name: alliance_name,
            kill_participation: participation,
            final_blows: final_blows,
            unique_kills: unique_kills,
            unique_pilots: unique_pilots,
            activity_score: participation + (final_blows * 2) + unique_pilots
          }
        end)

        {:ok, corporations}

      {:error, reason} -> {:error, reason}
    end
  end

  # Calculate danger assessment score
  defp calculate_danger_assessment(system_id) do
    seven_days_ago = DateTime.utc_now() |> DateTime.add(-7, :day)
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

    danger_query = """
    SELECT
      COUNT(CASE WHEN k.killmail_time >= $2 THEN 1 END) as recent_kills,
      COUNT(CASE WHEN k.killmail_time >= $3 THEN 1 END) as total_kills,
      COUNT(DISTINCT CASE WHEN k.killmail_time >= $2 THEN p.corporation_id END) as recent_hostile_corps,
      COUNT(DISTINCT CASE WHEN k.killmail_time >= $2 THEN DATE(k.killmail_time) END) as recent_active_days
    FROM killmails_raw k
    JOIN participants p ON k.killmail_id = p.killmail_id
    WHERE k.solar_system_id = $1
      AND k.killmail_time >= $3
      AND p.final_blow = true
    """

    case Ecto.Adapters.SQL.query(EveDmv.Repo, danger_query, [system_id, seven_days_ago, thirty_days_ago]) do
      {:ok, %{rows: [[recent_kills, total_kills, hostile_corps, active_days]]}} ->
        # Calculate danger score (0-100) without value component
        recent_activity_score = min(recent_kills * 5, 40)  # Up to 40 points for recent activity
        hostility_score = min(hostile_corps * 3, 30)      # Up to 30 points for multiple hostile corps
        consistency_score = min(active_days * 4, 30)      # Up to 30 points for consistent activity

        danger_score = recent_activity_score + hostility_score + consistency_score

        danger_level = cond do
          danger_score >= 80 -> "Extreme"
          danger_score >= 60 -> "High"
          danger_score >= 40 -> "Moderate"
          danger_score >= 20 -> "Low"
          true -> "Minimal"
        end

        {:ok, %{
          danger_score: danger_score,
          danger_level: danger_level,
          recent_kills: recent_kills || 0,
          total_kills: total_kills || 0,
          hostile_corporations: hostile_corps || 0,
          active_days: active_days || 0,
          recent_avg_value: 0.0  # Not available in current schema
        }}

      {:error, reason} -> {:error, reason}
    end
  end

  # Get 24-hour activity heatmap
  defp get_activity_heatmap(system_id) do
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

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

    case Ecto.Adapters.SQL.query(EveDmv.Repo, heatmap_query, [system_id, thirty_days_ago]) do
      {:ok, %{rows: rows}} ->
        # Create array for all 24 hours
        activity_by_hour = 0..23 |> Enum.map(fn hour ->
          count = Enum.find_value(rows, 0, fn [h, count] -> if h == hour, do: count, else: nil end)
          %{hour: hour, count: count}
        end)

        max_count = Enum.max_by(activity_by_hour, & &1.count) |> Map.get(:count, 1)

        # Calculate percentages for visualization
        heatmap_data = Enum.map(activity_by_hour, fn %{hour: hour, count: count} ->
          %{
            hour: hour,
            count: count,
            percentage: if(max_count > 0, do: round(count / max_count * 100), else: 0)
          }
        end)

        {:ok, heatmap_data}

      {:error, reason} -> {:error, reason}
    end
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
end
