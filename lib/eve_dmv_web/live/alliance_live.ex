# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
# credo:disable-for-this-file Credo.Check.Readability.StrictModuleLayout
defmodule EveDmvWeb.AllianceLive do
  @moduledoc """
  LiveView for displaying alliance analytics dashboard.

  Shows alliance statistics, member corporations, activity trends,
  and performance metrics across the entire alliance.
  """

  use EveDmvWeb, :live_view

  import EveDmvWeb.Components.PageHeaderComponent
  import EveDmvWeb.Components.StatsGridComponent
  import EveDmvWeb.Components.ErrorStateComponent
  import EveDmvWeb.Components.EmptyStateComponent
  import EveDmvWeb.Components.HistoricalFetchIndicator
  import EveDmvWeb.FormatHelpers

  alias EveDmv.Api
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Killmails.Participant
  alias EveDmvWeb.Helpers.TimeFormatter

  # Load current user from session on mount
  on_mount({EveDmvWeb.AuthLive, :load_from_session})

  # Helper function for template
  defp time_ago(datetime), do: TimeFormatter.format_relative_time(datetime)
  @impl Phoenix.LiveView
  def mount(%{"alliance_id" => alliance_id_str}, _session, socket) do
    case Integer.parse(alliance_id_str) do
      {alliance_id, ""} ->
        # Subscribe to historical fetch updates when connected
        if connected?(socket) do
          subscribe_to_historical_fetch(:alliance, alliance_id)
        end

        # Get current historical fetch status
        historical_status = get_historical_fetch_status(:alliance, alliance_id)

        # Load alliance data
        alliance_info = load_alliance_info(alliance_id)
        corporations = load_alliance_corporations(alliance_id)
        recent_activity = load_recent_activity(alliance_id)
        alliance_stats = calculate_alliance_stats(corporations, alliance_id)
        top_pilots = load_top_pilots(alliance_id, 10)
        activity_trends = calculate_activity_trends(alliance_id)

        socket =
          socket
          |> assign(:alliance_id, alliance_id)
          |> assign(:alliance_info, alliance_info)
          |> assign(:corporations, corporations)
          |> assign(:recent_activity, recent_activity)
          |> assign(:alliance_stats, alliance_stats)
          |> assign(:top_pilots, top_pilots)
          |> assign(:activity_trends, activity_trends)
          |> assign(:loading, false)
          |> assign(:error, nil)
          |> assign(:historical_fetch_status, historical_status)

        {:ok, socket}

      _ ->
        socket =
          socket
          |> assign(:error, "Invalid alliance ID")
          |> assign(:loading, false)
          |> assign(:historical_fetch_status, nil)

        {:ok, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("refresh", _params, socket) do
    alliance_id = socket.assigns.alliance_id
    # Reload all alliance data
    alliance_info = load_alliance_info(alliance_id)
    corporations = load_alliance_corporations(alliance_id)
    recent_activity = load_recent_activity(alliance_id)
    alliance_stats = calculate_alliance_stats(corporations, alliance_id)
    top_pilots = load_top_pilots(alliance_id, 10)
    activity_trends = calculate_activity_trends(alliance_id)

    socket =
      socket
      |> assign(:alliance_info, alliance_info)
      |> assign(:corporations, corporations)
      |> assign(:recent_activity, recent_activity)
      |> assign(:alliance_stats, alliance_stats)
      |> assign(:top_pilots, top_pilots)
      |> assign(:activity_trends, activity_trends)
      |> put_flash(:info, "Alliance data refreshed")

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event(
        "retry_historical_fetch",
        %{"entity_type" => "alliance", "entity_id" => id},
        socket
      ) do
    entity_id = String.to_integer(id)
    queue_historical_fetch(:alliance, entity_id)
    status = get_historical_fetch_status(:alliance, entity_id)
    {:noreply, assign(socket, :historical_fetch_status, status)}
  end

  # Handle historical fetch status updates via PubSub
  @impl Phoenix.LiveView
  def handle_info({:historical_fetch_update, :alliance, _entity_id, update}, socket) do
    alliance_id = socket.assigns.alliance_id

    case update do
      {:progress, _progress} ->
        status = get_historical_fetch_status(:alliance, alliance_id)
        {:noreply, assign(socket, :historical_fetch_status, status)}

      {:completed, _result} ->
        status = get_historical_fetch_status(:alliance, alliance_id)
        # Reload data to include new historical killmails
        corporations = load_alliance_corporations(alliance_id)
        recent_activity = load_recent_activity(alliance_id)
        alliance_stats = calculate_alliance_stats(corporations, alliance_id)

        {:noreply,
         socket
         |> assign(:historical_fetch_status, status)
         |> assign(:corporations, corporations)
         |> assign(:recent_activity, recent_activity)
         |> assign(:alliance_stats, alliance_stats)}

      {:failed, _reason} ->
        status = get_historical_fetch_status(:alliance, alliance_id)
        {:noreply, assign(socket, :historical_fetch_status, status)}

      _ ->
        {:noreply, socket}
    end
  end

  # Private helper functions
  defp load_alliance_info(alliance_id) do
    # Get alliance info from recent killmail data
    case Ash.read(Participant,
           filter: %{alliance_id: alliance_id},
           limit: 1,
           domain: Api
         ) do
      {:ok, [alliance_data | _]} ->
        %{
          alliance_id: alliance_id,
          alliance_name: alliance_data.alliance_name || "Unknown Alliance"
        }

      {:ok, []} ->
        %{
          alliance_id: alliance_id,
          alliance_name: "Unknown Alliance"
        }

      {:error, _} ->
        %{
          alliance_id: alliance_id,
          alliance_name: "Unknown Alliance"
        }
    end
  end

  defp load_alliance_corporations(alliance_id) do
    # Get all participants from this alliance and group by corporation
    case Ash.read(Participant,
           filter: %{alliance_id: alliance_id},
           domain: Api
         ) do
      {:ok, participants} ->
        corporations =
          participants
          |> Enum.group_by(& &1.corporation_id)
          |> Enum.map(fn {corp_id, corp_participants} ->
            corp_name = Map.get(List.first(corp_participants), :corporation_name, "Unknown")
            # Calculate corporation stats
            members =
              corp_participants
              |> Enum.map(& &1.character_id)
              |> Enum.uniq()
              |> length()

            kills = Enum.count(corp_participants, &(not &1.is_victim))
            losses = Enum.count(corp_participants, & &1.is_victim)
            # Get latest activity
            latest_activity =
              corp_participants
              |> Enum.map(& &1.inserted_at)
              |> Enum.max(Date, fn -> nil end)

            %{
              corporation_id: corp_id,
              corporation_name: corp_name,
              member_count: members,
              total_kills: kills,
              total_losses: losses,
              total_activity: kills + losses,
              kill_death_ratio: if(losses > 0, do: kills / losses, else: kills),
              latest_activity: latest_activity
            }
          end)
          |> Enum.sort_by(& &1.total_activity, :desc)
          # Limit to top 50 most active corporations
          |> Enum.take(50)

        corporations

      {:error, _} ->
        []
    end
  end

  defp load_recent_activity(alliance_id) do
    # Get recent killmail activity for the alliance
    case Ash.read(Participant,
           filter: %{alliance_id: alliance_id},
           sort: %{inserted_at: :desc},
           limit: 30,
           domain: Api
         ) do
      {:ok, participants} ->
        Enum.map(participants, fn p ->
          %{
            character_name: p.character_name,
            corporation_name: p.corporation_name,
            ship_name: p.ship_name,
            is_kill: not p.is_victim,
            timestamp: p.inserted_at,
            solar_system_name: p.solar_system_name
          }
        end)

      {:error, _} ->
        []
    end
  end

  defp load_top_pilots(alliance_id, limit) do
    # Get top performing pilots in the alliance
    case Ash.read(Participant,
           filter: %{alliance_id: alliance_id},
           domain: Api
         ) do
      {:ok, participants} ->
        participants
        |> Enum.group_by(& &1.character_id)
        |> Enum.map(fn {character_id, participations} ->
          character_name = Map.get(List.first(participations), :character_name, "Unknown")
          corp_name = Map.get(List.first(participations), :corporation_name, "Unknown")
          kills = Enum.count(participations, &(not &1.is_victim))
          losses = Enum.count(participations, & &1.is_victim)

          %{
            character_id: character_id,
            character_name: character_name,
            corporation_name: corp_name,
            total_kills: kills,
            total_losses: losses,
            kill_death_ratio: if(losses > 0, do: kills / losses, else: kills),
            efficiency_score: calculate_efficiency_score(kills, losses)
          }
        end)
        |> Enum.sort_by(& &1.efficiency_score, :desc)
        |> Enum.take(limit)

      {:error, _} ->
        []
    end
  end

  defp calculate_alliance_stats(corporations, _alliance_id) do
    total_corporations = length(corporations)

    total_members =
      corporations
      |> Enum.map(& &1.member_count)
      |> Enum.sum()

    total_kills =
      corporations
      |> Enum.map(& &1.total_kills)
      |> Enum.sum()

    total_losses =
      corporations
      |> Enum.map(& &1.total_losses)
      |> Enum.sum()

    total_activity =
      corporations
      |> Enum.map(& &1.total_activity)
      |> Enum.sum()

    # Calculate averages
    avg_activity_per_corp =
      if total_corporations > 0, do: total_activity / total_corporations, else: 0

    avg_activity_per_member = if total_members > 0, do: total_activity / total_members, else: 0
    kd_ratio = if total_losses > 0, do: total_kills / total_losses, else: total_kills
    # Find most active corporation
    most_active_corp = Enum.max_by(corporations, & &1.total_activity, fn -> nil end)
    # Calculate activity distribution
    active_corporations = Enum.count(corporations, &(&1.total_activity > 10))

    %{
      total_corporations: total_corporations,
      total_members: total_members,
      total_kills: total_kills,
      total_losses: total_losses,
      total_activity: total_activity,
      kill_death_ratio: safe_float_round(kd_ratio, 2),
      avg_activity_per_corp: safe_float_round(avg_activity_per_corp, 1),
      avg_activity_per_member: safe_float_round(avg_activity_per_member, 1),
      most_active_corp: most_active_corp,
      active_corporations: active_corporations,
      efficiency_rating: calculate_alliance_efficiency(total_kills, total_losses, total_members)
    }
  end

  defp calculate_activity_trends(alliance_id) do
    # Calculate weekly activity trends for the past 4 weeks using a single query
    end_date = DateTime.utc_now()
    start_date = DateTimeUtils.add(end_date, -28 * 24 * 60 * 60, :second)

    query = """
    SELECT
      DATE_TRUNC('week', killmail_time) as week_start,
      COUNT(*) as activity_count,
      COUNT(DISTINCT character_id) as unique_pilots,
      SUM(CASE WHEN is_victim THEN 0 ELSE 1 END) as kills,
      SUM(CASE WHEN is_victim THEN 1 ELSE 0 END) as losses
    FROM participants
    WHERE alliance_id = $1
      AND killmail_time >= $2
      AND killmail_time <= $3
    GROUP BY DATE_TRUNC('week', killmail_time)
    ORDER BY week_start DESC
    LIMIT 4
    """

    weeks =
      case EveDmv.Repo.query(query, [alliance_id, start_date, end_date]) do
        {:ok, %{rows: rows}} ->
          # Convert rows and calculate week labels
          rows
          |> Enum.with_index()
          |> Enum.map(fn {[_week_start, _count, _pilots, kills, losses], idx} ->
            %{
              week_label: "Week -#{idx}",
              kills: kills || 0,
              losses: losses || 0,
              total: (kills || 0) + (losses || 0)
            }
          end)

        {:error, _} ->
          # Fallback to empty weeks
          for week <- 0..3, do: %{week_label: "Week -#{week}", kills: 0, losses: 0, total: 0}
      end

    # Ensure we always have 4 weeks of data (pad with zeros if needed)
    weeks = pad_weeks_data(weeks)

    %{
      weekly_data: weeks,
      trend_direction: calculate_trend_direction(weeks)
    }
  end

  # Pad weeks data to ensure we always have 4 weeks
  defp pad_weeks_data(weeks) when length(weeks) >= 4, do: Enum.take(weeks, 4)

  defp pad_weeks_data(weeks) do
    existing_count = length(weeks)

    padding =
      for week <- existing_count..3 do
        %{week_label: "Week -#{week}", kills: 0, losses: 0, total: 0}
      end

    weeks ++ padding
  end

  defp calculate_trend_direction(weeks) do
    recent =
      weeks
      |> Enum.take(2)
      |> Enum.map(& &1.total)
      |> Enum.sum()

    older =
      weeks
      |> Enum.drop(2)
      |> Enum.map(& &1.total)
      |> Enum.sum()

    cond do
      recent > older * 1.2 -> :increasing
      recent < older * 0.8 -> :decreasing
      true -> :stable
    end
  end

  defp calculate_efficiency_score(kills, losses) do
    # Weighted efficiency score that considers both K/D and total activity
    kd_ratio = if losses > 0, do: kills / losses, else: kills
    activity_weight = :math.log(kills + losses + 1)
    kd_ratio * activity_weight
  end

  defp calculate_alliance_efficiency(kills, losses, _members) do
    return_ratio = if losses > 0, do: kills / losses, else: kills

    cond do
      return_ratio >= 2.0 -> "Elite"
      return_ratio >= 1.5 -> "Excellent"
      return_ratio >= 1.0 -> "Good"
      return_ratio >= 0.5 -> "Average"
      true -> "Poor"
    end
  end

  # Helper functions
  defp safe_float_round(value, precision) when is_float(value) do
    Float.round(value, precision)
  end

  defp safe_float_round(value, _precision) when is_integer(value) do
    value * 1.0
  end

  # Template helper functions (using FormatHelpers for numbers)
  def corporation_activity_indicator(activity_count) do
    cond do
      activity_count >= 500 -> {"🔥", "text-red-400"}
      activity_count >= 200 -> {"⚡", "text-yellow-400"}
      activity_count >= 50 -> {"✅", "text-green-400"}
      activity_count > 0 -> {"📍", "text-blue-400"}
      true -> {"💤", "text-gray-500"}
    end
  end

  def efficiency_badge(ratio) when is_float(ratio) or is_integer(ratio) do
    cond do
      ratio >= 2.0 -> {"Elite", "bg-purple-600 text-white"}
      ratio >= 1.5 -> {"Excellent", "bg-green-600 text-white"}
      ratio >= 1.0 -> {"Good", "bg-blue-600 text-white"}
      ratio >= 0.5 -> {"Average", "bg-yellow-600 text-white"}
      true -> {"Poor", "bg-red-600 text-white"}
    end
  end

  def trend_indicator(trend_direction) do
    case trend_direction do
      :increasing -> {"📈 Increasing", "text-green-400"}
      :decreasing -> {"📉 Decreasing", "text-red-400"}
      :stable -> {"➡️ Stable", "text-yellow-400"}
    end
  end

  # Using TimeFormatter.format_friendly_time for time formatting
  def activity_type_badge(is_kill) do
    if is_kill do
      {"🎯 Kill", "bg-green-600 text-white"}
    else
      {"💀 Loss", "bg-red-600 text-white"}
    end
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
