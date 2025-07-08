# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
defmodule EveDmvWeb.CorporationLive do
  @moduledoc """
  LiveView for displaying corporation overview and member activity.

  Shows corporation statistics, member list, recent activity, and
  top performing pilots within the corporation.
  """

  use EveDmvWeb, :live_view
  alias EveDmv.Api
  alias EveDmv.Killmails.Participant

  # Import reusable components
  import EveDmvWeb.Components.PageHeaderComponent
  import EveDmvWeb.Components.StatsGridComponent
  import EveDmvWeb.Components.ErrorStateComponent
  import EveDmvWeb.Components.EmptyStateComponent

  # Load current user from session on mount
  on_mount({EveDmvWeb.AuthLive, :load_from_session})

  @impl Phoenix.LiveView
  def mount(%{"corporation_id" => corp_id_str}, _session, socket) do
    case Integer.parse(corp_id_str) do
      {corporation_id, ""} ->
        # Load corporation data
        corp_info = load_corporation_info(corporation_id)
        members = load_corp_members(corporation_id)
        recent_activity = load_recent_activity(corporation_id)
        corp_stats = calculate_corp_stats(members)

        socket =
          socket
          |> assign(:corporation_id, corporation_id)
          |> assign(:corp_info, corp_info)
          |> assign(:members, members)
          |> assign(:recent_activity, recent_activity)
          |> assign(:corp_stats, corp_stats)
          |> assign(:loading, false)
          |> assign(:error, nil)

        {:ok, socket}

      _ ->
        socket =
          socket
          |> assign(:error, "Invalid corporation ID")
          |> assign(:loading, false)

        {:ok, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("refresh", _params, socket) do
    corporation_id = socket.assigns.corporation_id

    # Reload all corporation data
    corp_info = load_corporation_info(corporation_id)
    members = load_corp_members(corporation_id)
    recent_activity = load_recent_activity(corporation_id)
    corp_stats = calculate_corp_stats(members)

    socket =
      socket
      |> assign(:corp_info, corp_info)
      |> assign(:members, members)
      |> assign(:recent_activity, recent_activity)
      |> assign(:corp_stats, corp_stats)
      |> put_flash(:info, "Corporation data refreshed")

    {:noreply, socket}
  end

  # Private helper functions

  defp load_corporation_info(corporation_id) do
    # Get corporation info from recent killmail data using database filtering
    case Ash.read(Participant,
           filter: %{corporation_id: corporation_id},
           limit: 1,
           domain: Api
         ) do
      {:ok, [corp_data | _]} ->
        %{
          corporation_id: corporation_id,
          corporation_name: corp_data.corporation_name || "Unknown Corporation",
          alliance_id: corp_data.alliance_id,
          alliance_name: corp_data.alliance_name
        }

      {:ok, []} ->
        %{
          corporation_id: corporation_id,
          corporation_name: "Unknown Corporation",
          alliance_id: nil,
          alliance_name: nil
        }

      {:error, _} ->
        %{
          corporation_id: corporation_id,
          corporation_name: "Unknown Corporation",
          alliance_id: nil,
          alliance_name: nil
        }
    end
  end

  defp load_corp_members(corporation_id) do
    # Get corporation participants filtered at database level
    case Ash.read(Participant,
           filter: %{corporation_id: corporation_id},
           domain: Api
         ) do
      {:ok, participants} ->
        corp_members =
          participants
          |> Enum.group_by(& &1.character_id)
          |> Enum.map(fn {character_id, participations} ->
            character_name = participations |> List.first() |> Map.get(:character_name, "Unknown")

            # Calculate basic activity stats using is_victim flag instead of damage_dealt
            kills = participations |> Enum.count(&(not &1.is_victim))
            losses = participations |> Enum.count(& &1.is_victim)

            # Get latest activity
            latest_activity =
              Enum.map(participations, & &1.inserted_at)
              |> Enum.max(Date, fn -> nil end)

            %{
              character_id: character_id,
              character_name: character_name,
              total_kills: kills,
              total_losses: losses,
              total_activity: kills + losses,
              latest_activity: latest_activity
            }
          end)
          |> Enum.sort_by(& &1.total_activity, :desc)
          # Limit to top 50 most active members
          |> Enum.take(50)

        corp_members

      {:error, _} ->
        []
    end
  end

  defp load_recent_activity(corporation_id) do
    # Get recent killmail activity filtered and sorted at database level
    case Ash.read(Participant,
           filter: %{corporation_id: corporation_id},
           sort: %{inserted_at: :desc},
           limit: 20,
           domain: Api
         ) do
      {:ok, participants} ->
        Enum.map(participants, fn p ->
          %{
            character_name: p.character_name,
            ship_name: p.ship_name,
            # Use is_victim flag instead of damage_dealt
            is_kill: not p.is_victim,
            timestamp: p.inserted_at,
            solar_system_name: p.solar_system_name
          }
        end)
      {:error, _} ->
        []
    end
  end

  defp calculate_corp_stats(members) do
    total_members = length(members)
    total_kills = members |> Enum.map(& &1.total_kills) |> Enum.sum()
    total_losses = members |> Enum.map(& &1.total_losses) |> Enum.sum()
    total_activity = members |> Enum.map(& &1.total_activity) |> Enum.sum()

    # Calculate averages
    avg_activity = if total_members > 0, do: total_activity / total_members, else: 0
    kd_ratio = if total_losses > 0, do: total_kills / total_losses, else: total_kills

    # Find most active member
    most_active = members |> Enum.max_by(& &1.total_activity, fn -> nil end)

    # Calculate activity distribution
    active_members = members |> Enum.count(&(&1.total_activity > 5))

    %{
      total_members: total_members,
      total_kills: total_kills,
      total_losses: total_losses,
      total_activity: total_activity,
      kill_death_ratio: safe_float_round(kd_ratio, 2),
      avg_activity_per_member: safe_float_round(avg_activity, 1),
      most_active_member: most_active,
      active_members: active_members
    }
  end

  # Helper functions

  defp safe_float_round(value, precision) when is_float(value) do
    Float.round(value, precision)
  end

  defp safe_float_round(value, _precision) when is_integer(value) do
    value * 1.0
  end

  # Template helper functions

  def format_number(nil), do: "0"

  def format_number(number) when is_integer(number) do
    Integer.to_string(number) |> add_commas()
  end

  def format_number(number) when is_float(number) do
    number |> Float.round(1) |> Float.to_string()
  end

  defp add_commas(number_string) do
    String.reverse(number_string)
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  def activity_indicator(activity_count) do
    cond do
      activity_count >= 50 -> {"🔥", "text-red-400"}
      activity_count >= 20 -> {"⚡", "text-yellow-400"}
      activity_count >= 5 -> {"✅", "text-green-400"}
      activity_count > 0 -> {"📍", "text-blue-400"}
      true -> {"💤", "text-gray-500"}
    end
  end

  def activity_level(activity_count) do
    cond do
      activity_count >= 50 -> "Very High"
      activity_count >= 20 -> "High"
      activity_count >= 5 -> "Active"
      activity_count > 0 -> "Low"
      true -> "Inactive"
    end
  end

  def time_ago(nil), do: "Never"

  def time_ago(datetime) do
    case DateTime.diff(DateTime.utc_now(), datetime, :day) do
      0 -> "Today"
      1 -> "Yesterday"
      days when days < 7 -> "#{days} days ago"
      days when days < 30 -> "#{div(days, 7)} weeks ago"
      days -> "#{div(days, 30)} months ago"
    end
  end

  def activity_type_badge(is_kill) do
    if is_kill do
      {"🎯 Kill", "bg-green-600 text-white"}
    else
      {"💀 Loss", "bg-red-600 text-white"}
    end
  end
end
