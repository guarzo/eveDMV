# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
# credo:disable-for-this-file Credo.Check.Readability.StrictModuleLayout
defmodule EveDmvWeb.CorporationLive do
  @moduledoc """
  LiveView for displaying corporation overview and member activity.

  Shows corporation statistics, member list, recent activity, and
  top performing pilots within the corporation.
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Api
  alias EveDmv.Killmails.Participant
  alias EveDmv.Cache.AnalysisCache

  require Ash.Query
  require Logger

  # Load current user from session on mount
  on_mount({EveDmvWeb.AuthLive, :load_from_session})

  # Import reusable components
  import EveDmvWeb.Components.PageHeaderComponent
  import EveDmvWeb.Components.StatsGridComponent
  import EveDmvWeb.Components.ErrorStateComponent
  import EveDmvWeb.Components.EmptyStateComponent
  import EveDmvWeb.EveImageComponents

  @impl Phoenix.LiveView
  def mount(%{"corporation_id" => corp_id_str}, _session, socket) do
    case Integer.parse(corp_id_str) do
      {corporation_id, ""} ->
        # Load corporation data with caching
        {:ok, corp_info} =
          AnalysisCache.get_or_compute(
            AnalysisCache.corp_info_key(corporation_id),
            fn -> load_corporation_info(corporation_id) end
          )

        {:ok, members} =
          AnalysisCache.get_or_compute(
            AnalysisCache.corp_members_key(corporation_id),
            fn -> load_corp_members(corporation_id) end
          )

        {:ok, recent_activity} =
          AnalysisCache.get_or_compute(
            AnalysisCache.corp_activity_key(corporation_id),
            fn -> load_recent_activity(corporation_id) end
          )

        corp_stats = calculate_corp_stats(members)

        {:ok, location_stats} =
          AnalysisCache.get_or_compute(
            AnalysisCache.corp_location_key(corporation_id),
            fn -> load_location_stats(corporation_id) end
          )

        {:ok, victim_stats} =
          AnalysisCache.get_or_compute(
            AnalysisCache.corp_victims_key(corporation_id),
            fn -> load_victim_corporation_stats(corporation_id) end
          )

        # Get timezone and activity analysis with caching
        {:ok, timezone_data} =
          AnalysisCache.get_or_compute(
            AnalysisCache.corp_timezone_key(corporation_id),
            fn -> calculate_timezone_data(corporation_id) end
          )

        participation_data = calculate_participation_data(members, corp_stats)

        socket =
          socket
          |> assign(:corporation_id, corporation_id)
          |> assign(:corp_info, corp_info)
          |> assign(:members, members)
          |> assign(:recent_activity, recent_activity)
          |> assign(:corp_stats, corp_stats)
          |> assign(:timezone_data, timezone_data)
          |> assign(:participation_data, participation_data)
          |> assign(:location_stats, location_stats)
          |> assign(:victim_stats, victim_stats)
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

    # Invalidate cache for this corporation
    AnalysisCache.invalidate_corporation(corporation_id)

    # Reload all corporation data (will cache fresh data)
    {:ok, corp_info} =
      AnalysisCache.get_or_compute(
        AnalysisCache.corp_info_key(corporation_id),
        fn -> load_corporation_info(corporation_id) end
      )

    {:ok, members} =
      AnalysisCache.get_or_compute(
        AnalysisCache.corp_members_key(corporation_id),
        fn -> load_corp_members(corporation_id) end
      )

    {:ok, recent_activity} =
      AnalysisCache.get_or_compute(
        AnalysisCache.corp_activity_key(corporation_id),
        fn -> load_recent_activity(corporation_id) end
      )

    corp_stats = calculate_corp_stats(members)

    {:ok, location_stats} =
      AnalysisCache.get_or_compute(
        AnalysisCache.corp_location_key(corporation_id),
        fn -> load_location_stats(corporation_id) end
      )

    {:ok, victim_stats} =
      AnalysisCache.get_or_compute(
        AnalysisCache.corp_victims_key(corporation_id),
        fn -> load_victim_corporation_stats(corporation_id) end
      )

    # Get timezone and activity analysis
    {:ok, timezone_data} =
      AnalysisCache.get_or_compute(
        AnalysisCache.corp_timezone_key(corporation_id),
        fn -> calculate_timezone_data(corporation_id) end
      )

    participation_data = calculate_participation_data(members, corp_stats)

    socket =
      socket
      |> assign(:corp_info, corp_info)
      |> assign(:members, members)
      |> assign(:recent_activity, recent_activity)
      |> assign(:corp_stats, corp_stats)
      |> assign(:timezone_data, timezone_data)
      |> assign(:participation_data, participation_data)
      |> assign(:location_stats, location_stats)
      |> assign(:victim_stats, victim_stats)
      |> put_flash(:info, "Corporation data refreshed")

    {:noreply, socket}
  end

  # Private helper functions

  defp load_corporation_info(corporation_id) do
    # Get corporation info from recent killmail data using Ash
    case Ash.Query.for_read(Participant, :by_corporation, %{corporation_id: corporation_id})
         |> Ash.Query.limit(1)
         |> Ash.read(domain: Api) do
      {:ok, [participant | _]} ->
        %{
          corporation_id: corporation_id,
          corporation_name: participant.corporation_name || "Unknown Corporation",
          alliance_id: participant.alliance_id,
          alliance_name: participant.alliance_name
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
    # Get corporation members with activity stats using optimized single query
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

    case Ash.Query.for_read(Participant, :by_corporation, %{corporation_id: corporation_id})
         |> Ash.Query.filter(killmail_time >= ^thirty_days_ago)
         # Preload killmail data
         |> Ash.Query.load([:killmail_raw])
         # Get more data for better aggregation
         |> Ash.Query.limit(1000)
         |> Ash.read(domain: Api) do
      {:ok, participants} ->
        # Preload all character names to avoid N+1 queries
        _character_ids =
          participants |> Enum.map(& &1.character_id) |> Enum.filter(& &1) |> Enum.uniq()

        EveDmv.Performance.BatchNameResolver.preload_participant_names(participants)

        # Group by character and aggregate stats
        participants
        |> Enum.group_by(& &1.character_id)
        |> Enum.map(fn {character_id, char_participants} ->
          kills = char_participants |> Enum.count(&(not &1.is_victim))
          losses = char_participants |> Enum.count(& &1.is_victim)

          latest_activity =
            char_participants |> Enum.map(& &1.killmail_time) |> Enum.max(DateTime, fn -> nil end)

          # Use cached name resolution
          character_name = EveDmv.Eve.NameResolver.character_name(character_id)

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
        |> Enum.take(50)

      {:error, _} ->
        []
    end
  end

  defp load_recent_activity(corporation_id) do
    # Get recent killmail activity using optimized query
    case Ash.Query.for_read(Participant, :by_corporation, %{corporation_id: corporation_id})
         # Preload killmail data
         |> Ash.Query.load([:killmail_raw])
         |> Ash.Query.limit(20)
         |> Ash.read(domain: Api) do
      {:ok, participants} ->
        # Preload all names to avoid N+1 queries
        EveDmv.Performance.BatchNameResolver.preload_participant_names(participants)

        # We need to load the killmail data for timestamps
        # For now, let's use the participant data we have
        Enum.map(participants, fn p ->
          %{
            character_id: p.character_id,
            character_name: EveDmv.Eve.NameResolver.character_name(p.character_id),
            ship_name: EveDmv.Eve.NameResolver.ship_name(p.ship_type_id),
            is_kill: not p.is_victim,
            timestamp: p.killmail_time,
            # TODO: Add solar system name lookup
            solar_system_name: nil
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
    most_active = Enum.max_by(members, & &1.total_activity, fn -> nil end)

    # Calculate activity distribution
    active_members = Enum.count(members, &(&1.total_activity > 5))

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

  defp round_value(value, precision) when is_number(value) do
    if is_float(value) do
      Float.round(value, precision)
    else
      # Convert integer to float for rounding
      Float.round(value * 1.0, precision)
    end
  end

  defp round_value(_value, _precision), do: 0.0

  defp safe_float_round(value, precision) when is_float(value) do
    Float.round(value, precision)
  end

  defp safe_float_round(value, _precision) when is_integer(value) do
    value * 1.0
  end

  # Template helper functions

  def format_number(nil), do: "0"

  def format_number(number) when is_integer(number) do
    add_commas(Integer.to_string(number))
  end

  def format_number(number) when is_float(number) do
    number |> Float.round(1) |> Float.to_string()
  end

  defp add_commas(number_string) do
    number_string
    |> String.reverse()
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

  def time_ago(%DateTime{} = datetime) do
    case DateTime.diff(DateTime.utc_now(), datetime, :day) do
      0 -> "Today"
      1 -> "Yesterday"
      days when days < 7 -> "#{days} days ago"
      days when days < 30 -> "#{div(days, 7)} weeks ago"
      days -> "#{div(days, 30)} months ago"
    end
  end

  def time_ago(%NaiveDateTime{} = datetime) do
    # Convert NaiveDateTime to DateTime (assuming UTC)
    datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> time_ago()
  end

  def time_ago(_), do: "Unknown"

  def activity_type_badge(is_kill) do
    if is_kill do
      {"🎯 Kill", "bg-green-600 text-white"}
    else
      {"💀 Loss", "bg-red-600 text-white"}
    end
  end

  defp load_location_stats(corporation_id) do
    # Get activity counts by solar system using Ash
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

    case Ash.Query.for_read(Participant, :by_corporation, %{corporation_id: corporation_id})
         |> Ash.Query.filter(killmail_time >= ^thirty_days_ago)
         |> Ash.read(domain: Api) do
      {:ok, participants} ->
        # Group by solar system and aggregate stats
        system_groups = participants |> Enum.group_by(& &1.solar_system_id)

        # Batch load all system names to avoid N+1 queries
        system_ids = Map.keys(system_groups) |> Enum.filter(& &1)
        system_names = get_system_names(system_ids)

        system_groups
        |> Enum.map(fn {system_id, system_participants} ->
          kills = system_participants |> Enum.count(&(not &1.is_victim))
          losses = system_participants |> Enum.count(& &1.is_victim)

          %{
            solar_system_id: system_id,
            solar_system_name: Map.get(system_names, system_id, "Unknown System #{system_id}"),
            activity_count: length(system_participants),
            kills: kills,
            losses: losses
          }
        end)
        |> Enum.sort_by(& &1.activity_count, :desc)
        |> Enum.take(20)

      {:error, _} ->
        []
    end
  end

  defp load_victim_corporation_stats(corporation_id) do
    # Get top victim corporations using Ash
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

    # First get all our corporation's attackers (is_victim = false)
    case Ash.Query.for_read(Participant, :by_corporation, %{corporation_id: corporation_id})
         |> Ash.Query.filter(killmail_time >= ^thirty_days_ago and is_victim == false)
         |> Ash.read(domain: Api) do
      {:ok, our_attackers} ->
        # Get unique killmail IDs where our corp attacked
        our_killmail_ids = our_attackers |> Enum.map(& &1.killmail_id) |> Enum.uniq()

        # Now get all victims from those killmails
        case Ash.Query.for_read(Participant, :read)
             |> Ash.Query.filter(killmail_id in ^our_killmail_ids and is_victim == true)
             |> Ash.read(domain: Api) do
          {:ok, victims} ->
            # Group by victim corporation and count kills
            victims
            |> Enum.group_by(&{&1.corporation_id, &1.corporation_name})
            |> Enum.map(fn {{corp_id, corp_name}, victim_participants} ->
              kill_count =
                victim_participants |> Enum.map(& &1.killmail_id) |> Enum.uniq() |> length()

              %{
                corporation_id: corp_id,
                corporation_name: corp_name || "Unknown Corporation",
                kill_count: kill_count
              }
            end)
            |> Enum.sort_by(& &1.kill_count, :desc)
            |> Enum.take(10)

          {:error, _} ->
            []
        end

      {:error, _} ->
        []
    end
  end

  defp get_system_names(system_ids) do
    # Batch load system names to avoid N+1 queries
    EveDmv.Eve.NameResolver.system_names(system_ids)
  end

  defp calculate_timezone_data(corporation_id) do
    # Get all corporation activity with timestamps for timezone analysis
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

    case Ash.Query.for_read(Participant, :by_corporation, %{corporation_id: corporation_id})
         |> Ash.Query.filter(killmail_time >= ^thirty_days_ago)
         |> Ash.read(domain: Api) do
      {:ok, participants} ->
        # Group by hour of the day (EVE time is UTC)
        hourly_distribution =
          participants
          |> Enum.map(fn participant ->
            case participant.killmail_time do
              %DateTime{} = dt -> DateTime.to_time(dt).hour
              %NaiveDateTime{} = ndt -> NaiveDateTime.to_time(ndt).hour
              _ -> 0
            end
          end)
          |> Enum.frequencies()
          |> Map.new(fn {hour, count} -> {hour, count} end)

        # Find peak hours (top 3 hours with most activity)
        peak_hours =
          hourly_distribution
          |> Enum.sort_by(&elem(&1, 1), :desc)
          |> Enum.take(3)
          |> Enum.map(fn {hour, activity} -> %{hour: hour, activity: activity} end)

        # Calculate overall coverage score (how many hours have activity)
        active_hours = hourly_distribution |> Map.keys() |> length()
        overall_coverage_score = active_hours / 24 * 100

        # Analyze timezone coverage strengths and gaps
        timezone_coverage = analyze_timezone_coverage(hourly_distribution)

        %{
          hourly_distribution: hourly_distribution,
          peak_hours: peak_hours,
          timezone_coverage: timezone_coverage,
          overall_coverage_score: overall_coverage_score
        }

      {:error, reason} ->
        Logger.error("Failed to calculate timezone data: #{inspect(reason)}")

        %{
          hourly_distribution: %{},
          peak_hours: [],
          timezone_coverage: %{coverage_strengths: [], coverage_gaps: []},
          overall_coverage_score: 0
        }
    end
  end

  defp calculate_participation_data(members, corp_stats) do
    total_members = corp_stats.total_members

    # Calculate PvP participation (members with any activity)
    pvp_participants = Enum.count(members, &(&1.total_activity > 0))
    pvp_rate = if total_members > 0, do: pvp_participants / total_members * 100, else: 0.0

    # Calculate fleet participation (members with 3+ activities suggesting group play)
    fleet_participants = Enum.count(members, &(&1.total_activity >= 3))
    fleet_rate = if total_members > 0, do: fleet_participants / total_members * 100, else: 0.0

    # Calculate corporate activity (highly active members with 10+ activities)
    active_participants = Enum.count(members, &(&1.total_activity >= 10))
    active_rate = if total_members > 0, do: active_participants / total_members * 100, else: 0.0

    # Overall participation score (weighted average)
    overall_score = pvp_rate * 0.3 + fleet_rate * 0.4 + active_rate * 0.3

    %{
      pvp_participation: %{participants: pvp_participants, rate: Float.round(pvp_rate, 1)},
      fleet_participation: %{participants: fleet_participants, rate: Float.round(fleet_rate, 1)},
      corporate_activity: %{participants: active_participants, rate: Float.round(active_rate, 1)},
      overall_participation_score: Float.round(overall_score, 1)
    }
  end

  defp analyze_timezone_coverage(hourly_distribution) do
    # Define timezone blocks (approximate)
    timezone_blocks = %{
      "EU Prime (18:00-22:00)" => 18..22,
      "US Prime (00:00-04:00)" => 0..4,
      "AUTZ Prime (10:00-14:00)" => 10..14,
      "Late Night (22:00-02:00)" => [22, 23, 0, 1, 2]
    }

    # Check each timezone block for activity
    {coverage_strengths, coverage_gaps} =
      Enum.reduce(timezone_blocks, {[], []}, fn {tz_name, hours}, {strengths, gaps} ->
        hours_list = if is_list(hours), do: hours, else: Enum.to_list(hours)

        total_activity =
          hours_list |> Enum.map(&Map.get(hourly_distribution, &1, 0)) |> Enum.sum()

        if total_activity >= 5 do
          {[tz_name | strengths], gaps}
        else
          {strengths, [tz_name | gaps]}
        end
      end)

    %{
      coverage_strengths: Enum.reverse(coverage_strengths),
      coverage_gaps: Enum.reverse(coverage_gaps)
    }
  end
end
