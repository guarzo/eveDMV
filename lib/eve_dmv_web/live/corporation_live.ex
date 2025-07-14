# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
# credo:disable-for-this-file Credo.Check.Readability.StrictModuleLayout
defmodule EveDmvWeb.CorporationLive do
  @moduledoc """
  LiveView for displaying corporation overview and member activity.

  Shows corporation statistics, member list, recent activity, and
  top performing pilots within the corporation.
  """

  use EveDmvWeb, :live_view

  alias Ecto.Adapters.SQL
  alias EveDmv.Api
  alias EveDmv.Analytics.BattleDetector
  alias EveDmv.Cache.AnalysisCache
  alias EveDmv.Contexts.CorporationIntelligence
  alias EveDmv.Eve.EsiCorporationClient
  alias EveDmv.Eve.NameResolver
  alias EveDmv.Killmails.Participant
  alias EveDmv.Performance.BatchNameResolver
  alias EveDmv.Repo

  require Ash.Query
  require Logger

  # Load current user from session on mount
  on_mount({EveDmvWeb.AuthLive, :load_from_session})

  # Import reusable components
  import EveDmvWeb.Components.ErrorStateComponent
  import EveDmvWeb.Components.EmptyStateComponent
  import EveDmvWeb.Components.ThreatLevelComponent
  import EveDmvWeb.Components.ActivityOverviewComponent
  import EveDmvWeb.Components.IskStatsComponent
  import EveDmvWeb.EveImageComponents
  import EveDmvWeb.FormatHelpers

  alias EveDmvWeb.Helpers.TimeFormatter

  # Template helper functions
  def format_relative_time(datetime) do
    TimeFormatter.format_friendly_time(datetime)
  end

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

        # Load members directly for debugging
        members = load_corp_members(corporation_id)
        Logger.info("Loaded #{length(members)} members for corp #{corporation_id}")

        # Load recent activity directly for debugging
        recent_activity = load_recent_activity(corporation_id)

        Logger.info(
          "Loaded #{length(recent_activity)} recent activities for corp #{corporation_id}"
        )

        corp_stats = calculate_corp_stats(members)

        # Get comprehensive corporation statistics (longer time period)
        comprehensive_stats = get_comprehensive_corp_stats(corporation_id)

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

        participation_data = calculate_participation_data(members, corp_info)

        # Load intelligence data directly for debugging
        intelligence_data =
          case CorporationIntelligence.get_corporation_intelligence_report(corporation_id) do
            {:ok, data} ->
              Logger.info("Successfully loaded intelligence data for corp #{corporation_id}")
              data

            {:error, reason} ->
              Logger.error(
                "Failed to load intelligence data for corp #{corporation_id}: #{inspect(reason)}"
              )

              nil
          end

        # Load battle data
        {recent_battles, battle_stats} = {
          BattleDetector.detect_corporation_battles(corporation_id, 10),
          BattleDetector.get_corporation_battle_stats(corporation_id)
        }

        # Load ship intelligence data for corporation
        fleet_doctrines = BattleDetector.get_corporation_fleet_doctrines(corporation_id)

        socket =
          socket
          |> assign(:corporation_id, corporation_id)
          |> assign(:corp_info, corp_info)
          |> assign(:members, members)
          |> assign(:recent_activity, recent_activity)
          |> assign(:corp_stats, corp_stats)
          |> assign(:comprehensive_stats, comprehensive_stats)
          |> assign(:timezone_data, timezone_data)
          |> assign(:participation_data, participation_data)
          |> assign(:location_stats, location_stats)
          |> assign(:victim_stats, victim_stats)
          |> assign(:intelligence_data, intelligence_data)
          |> assign(:recent_battles, recent_battles)
          |> assign(:battle_stats, battle_stats)
          |> assign(:fleet_doctrines, fleet_doctrines)
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

    # Load directly for debugging
    members = load_corp_members(corporation_id)
    Logger.info("Refresh: Loaded #{length(members)} members for corp #{corporation_id}")

    # Get comprehensive stats first
    comprehensive_stats = get_comprehensive_corp_stats(corporation_id)

    recent_activity = load_recent_activity(corporation_id)

    Logger.info(
      "Refresh: Loaded #{length(recent_activity)} recent activities for corp #{corporation_id}"
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

    participation_data = calculate_participation_data(members, corp_info)

    # Reload intelligence data
    intelligence_data =
      case AnalysisCache.get_or_compute(
             AnalysisCache.corp_intelligence_key(corporation_id),
             fn ->
               case CorporationIntelligence.get_corporation_intelligence_report(corporation_id) do
                 {:ok, data} ->
                   data

                 {:error, reason} ->
                   Logger.error(
                     "Failed to load intelligence data for corp #{corporation_id}: #{inspect(reason)}"
                   )

                   nil
               end
             end
           ) do
        {:ok, data} ->
          data

        {:error, reason} ->
          Logger.error("Cache error loading intelligence: #{inspect(reason)}")
          nil
      end

    # Reload battle data
    {recent_battles, battle_stats} = {
      BattleDetector.detect_corporation_battles(corporation_id, 10),
      BattleDetector.get_corporation_battle_stats(corporation_id)
    }

    # Reload ship intelligence data
    fleet_doctrines = BattleDetector.get_corporation_fleet_doctrines(corporation_id)

    socket =
      socket
      |> assign(:corp_info, corp_info)
      |> assign(:members, members)
      |> assign(:recent_activity, recent_activity)
      |> assign(:corp_stats, corp_stats)
      |> assign(:comprehensive_stats, comprehensive_stats)
      |> assign(:timezone_data, timezone_data)
      |> assign(:participation_data, participation_data)
      |> assign(:location_stats, location_stats)
      |> assign(:victim_stats, victim_stats)
      |> assign(:intelligence_data, intelligence_data)
      |> assign(:recent_battles, recent_battles)
      |> assign(:battle_stats, battle_stats)
      |> assign(:fleet_doctrines, fleet_doctrines)
      |> put_flash(:info, "Corporation data refreshed")

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("force_refresh", _params, socket) do
    corporation_id = socket.assigns.corporation_id
    # Clear cache for this corporation
    AnalysisCache.invalidate_corporation(corporation_id)

    # Also clear any corporation intelligence cache
    CorporationIntelligence.clear_corporation_cache(corporation_id)

    # Redirect to reload the page with fresh data
    {:noreply, push_navigate(socket, to: ~p"/corporation/#{corporation_id}")}
  end

  # Private helper functions

  defp load_corporation_info(corporation_id) do
    # First try to get from ESI for accurate member count
    esi_info =
      case EsiCorporationClient.get_corporation(corporation_id) do
        {:ok, corp} -> corp
        _ -> %{}
      end

    # Get additional info from recent killmail data
    case Ash.Query.for_read(Participant, :by_corporation, %{corporation_id: corporation_id})
         |> Ash.Query.limit(1)
         |> Ash.read(domain: Api) do
      {:ok, [participant | _]} ->
        %{
          corporation_id: corporation_id,
          corporation_name:
            Map.get(esi_info, :name) || participant.corporation_name || "Unknown Corporation",
          ticker: Map.get(esi_info, :ticker),
          member_count: Map.get(esi_info, :member_count, 0),
          alliance_id: participant.alliance_id,
          alliance_name: participant.alliance_name
        }

      {:ok, []} ->
        %{
          corporation_id: corporation_id,
          corporation_name: Map.get(esi_info, :name, "Unknown Corporation"),
          ticker: Map.get(esi_info, :ticker),
          member_count: Map.get(esi_info, :member_count, 0),
          alliance_id: Map.get(esi_info, :alliance_id),
          alliance_name: nil
        }

      {:error, _} ->
        %{
          corporation_id: corporation_id,
          corporation_name: Map.get(esi_info, :name, "Unknown Corporation"),
          ticker: Map.get(esi_info, :ticker),
          member_count: Map.get(esi_info, :member_count, 0),
          alliance_id: Map.get(esi_info, :alliance_id),
          alliance_name: nil
        }
    end
  end

  defp load_corp_members(corporation_id) do
    # Get corporation members with activity stats using optimized single query
    # Look back 90 days for comprehensive member data
    ninety_days_ago = DateTime.add(DateTime.utc_now(), -90, :day)

    Logger.info("Loading members for corp #{corporation_id} from #{ninety_days_ago}")

    case Ash.Query.for_read(Participant, :by_corporation, %{corporation_id: corporation_id})
         |> Ash.Query.filter(killmail_time >= ^ninety_days_ago)
         # Don't preload killmail_raw - it might be causing issues
         # |> Ash.Query.load([:killmail_raw])
         # Get more data for better aggregation
         |> Ash.Query.limit(1000)
         |> Ash.read(domain: Api) do
      {:ok, participants} ->
        Logger.debug("Found #{length(participants)} participants for corp #{corporation_id}")

        # Filter out entries without character_id
        valid_participants = Enum.filter(participants, & &1.character_id)
        Logger.debug("#{length(valid_participants)} participants have character_id")

        # Preload all character names to avoid N+1 queries
        character_ids = valid_participants |> Enum.map(& &1.character_id) |> Enum.uniq()
        Logger.debug("Found #{length(character_ids)} unique character IDs")

        BatchNameResolver.preload_participant_names(valid_participants)

        # Group by character and aggregate stats
        members =
          valid_participants
          |> Enum.group_by(& &1.character_id)
          |> Enum.map(fn {character_id, char_participants} ->
            kills = Enum.count(char_participants, &(not &1.is_victim))
            losses = Enum.count(char_participants, & &1.is_victim)

            latest_activity =
              case char_participants |> Enum.map(& &1.killmail_time) |> Enum.filter(& &1) do
                [] -> nil
                times -> Enum.max(times, DateTime)
              end

            # Use cached name resolution
            character_name = NameResolver.character_name(character_id)

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

        Logger.debug("Returning #{length(members)} members")
        members

      {:error, reason} ->
        Logger.error("Failed to load corp members: #{inspect(reason)}")
        []
    end
  end

  defp load_recent_activity(corporation_id) do
    # Get recent killmail activity using optimized query
    Logger.info("Loading recent activity for corp #{corporation_id}")

    case Ash.Query.for_read(Participant, :by_corporation, %{corporation_id: corporation_id})
         # Don't preload killmail_raw - it might be causing issues
         # |> Ash.Query.load([:killmail_raw])
         |> Ash.Query.sort(killmail_time: :desc)
         |> Ash.Query.limit(20)
         |> Ash.read(domain: Api) do
      {:ok, participants} ->
        Logger.debug("Found #{length(participants)} recent activities for corp #{corporation_id}")

        # Filter out entries without character_id
        valid_participants = Enum.filter(participants, & &1.character_id)

        # Preload all names to avoid N+1 queries
        BatchNameResolver.preload_participant_names(valid_participants)

        # Load activities with solar system information
        activities = load_activities_with_system_info(valid_participants)

        Logger.debug("Returning #{length(activities)} recent activities")
        activities

      {:error, reason} ->
        Logger.error("Failed to load corp members: #{inspect(reason)}")
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

  # Get comprehensive corporation statistics over longer time period
  defp get_comprehensive_corp_stats(corporation_id) do
    # Look at 90 days of data for more accurate statistics
    ninety_days_ago = DateTime.add(DateTime.utc_now(), -90, :day)

    # First get participants
    case Ash.Query.for_read(Participant, :by_corporation, %{corporation_id: corporation_id})
         |> Ash.Query.filter(killmail_time >= ^ninety_days_ago)
         # Increased limit for comprehensive stats
         |> Ash.Query.limit(5000)
         |> Ash.read(domain: Api) do
      {:ok, participants} ->
        # Get unique killmail IDs for ISK calculations
        kill_ids =
          participants
          |> Enum.filter(&(not &1.is_victim))
          |> Enum.map(& &1.killmail_id)
          |> Enum.uniq()

        loss_ids =
          participants
          |> Enum.filter(& &1.is_victim)
          |> Enum.map(& &1.killmail_id)
          |> Enum.uniq()

        # Calculate ISK values from killmails
        {isk_destroyed, isk_lost} = calculate_isk_values(kill_ids, loss_ids)

        # Calculate comprehensive statistics
        total_activities = length(participants)
        total_kills = length(kill_ids)
        total_losses = length(loss_ids)

        # Unique members over 90 days
        total_members =
          participants
          |> Enum.map(& &1.character_id)
          |> Enum.filter(& &1)
          |> Enum.uniq()
          |> length()

        # K/D ratio (ensure we get a float)
        kd_ratio = if total_losses > 0, do: total_kills / total_losses, else: total_kills / 1.0

        # Average activity per member (ensure we get a float)
        avg_activity = if total_members > 0, do: total_activities / total_members, else: 0.0

        %{
          total_members: total_members,
          total_kills: total_kills,
          total_losses: total_losses,
          total_activity: total_activities,
          kill_death_ratio: Float.round(kd_ratio, 2),
          avg_activity_per_member: Float.round(avg_activity, 1),
          isk_destroyed: isk_destroyed,
          isk_lost: isk_lost,
          time_period: "90 days"
        }

      {:error, _} ->
        %{
          total_members: 0,
          total_kills: 0,
          total_losses: 0,
          total_activity: 0,
          kill_death_ratio: 0.0,
          avg_activity_per_member: 0.0,
          isk_destroyed: 0,
          isk_lost: 0,
          time_period: "90 days"
        }
    end
  end

  defp calculate_isk_values(kill_ids, loss_ids) do
    # Calculate real ISK values from killmail data
    isk_destroyed = calculate_isk_for_participants(kill_ids, false)
    isk_lost = calculate_isk_for_participants(loss_ids, true)

    {isk_destroyed, isk_lost}
  end

  defp calculate_isk_for_participants(participant_ids, is_victim) when is_list(participant_ids) do
    if Enum.empty?(participant_ids) do
      0
    else
      # Query killmail ISK values for participants
      query = """
      SELECT COALESCE(SUM(k.zkb_total_value), 0) as total_isk
      FROM participants p
      JOIN killmails_raw k ON p.killmail_id = k.killmail_id AND p.killmail_time = k.killmail_time
      WHERE p.id = ANY($1) AND p.is_victim = $2
      """

      case SQL.query(Repo, query, [participant_ids, is_victim]) do
        {:ok, %{rows: [[isk_value]]}} when is_number(isk_value) ->
          round(isk_value)

        {:ok, %{rows: [[nil]]}} ->
          0

        {:error, _reason} ->
          # Fallback to placeholder calculation if query fails
          length(participant_ids) * 50_000_000
      end
    end
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

  # Template helper functions (using FormatHelpers for numbers and ISK)

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

  # Using TimeFormatter.format_friendly_time for time formatting

  def activity_type_badge(is_kill) do
    if is_kill do
      {"🎯 Kill", "bg-green-600 text-white"}
    else
      {"💀 Loss", "bg-red-600 text-white"}
    end
  end

  defp load_location_stats(corporation_id) do
    # Get activity counts by solar system using Ash
    thirty_days_ago = DateTime.add(DateTime.utc_now(), -30, :day)

    case Ash.Query.for_read(Participant, :by_corporation, %{corporation_id: corporation_id})
         |> Ash.Query.filter(killmail_time >= ^thirty_days_ago)
         |> Ash.read(domain: Api) do
      {:ok, participants} ->
        # Group by solar system and aggregate stats
        system_groups = Enum.group_by(participants, & &1.solar_system_id)

        # Batch load all system names to avoid N+1 queries
        system_ids = Enum.filter(Map.keys(system_groups), & &1)
        system_names = get_system_names(system_ids)

        system_groups
        |> Enum.map(fn {system_id, system_participants} ->
          kills = Enum.count(system_participants, &(not &1.is_victim))
          losses = Enum.count(system_participants, & &1.is_victim)

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

      {:error, reason} ->
        Logger.error("Failed to load corp members: #{inspect(reason)}")
        []
    end
  end

  defp load_victim_corporation_stats(corporation_id) do
    # Get top victim corporations using Ash
    thirty_days_ago = DateTime.add(DateTime.utc_now(), -30, :day)

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

      {:error, reason} ->
        Logger.error("Failed to load corp members: #{inspect(reason)}")
        []
    end
  end

  defp get_system_names(system_ids) do
    # Batch load system names to avoid N+1 queries
    NameResolver.system_names(system_ids)
  end

  defp calculate_timezone_data(corporation_id) do
    # Get all corporation activity with timestamps for timezone analysis
    thirty_days_ago = DateTime.add(DateTime.utc_now(), -30, :day)

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

  defp calculate_participation_data(members, corp_info) do
    # Use the actual number of members we have data for
    members_with_data = length(members)

    # Get the actual ESI member count
    total_corp_members = Map.get(corp_info || %{}, :member_count, members_with_data)

    # Use total corp members for participation rates if we have ESI data
    # This gives a more accurate representation of corp activity
    participation_base =
      if total_corp_members > 0 && total_corp_members >= members_with_data do
        total_corp_members
      else
        members_with_data
      end

    # Calculate PvP participation (members with any activity vs total members)
    pvp_participants = Enum.count(members, &(&1.total_activity > 0))

    pvp_rate =
      if participation_base > 0, do: pvp_participants / participation_base * 100, else: 0.0

    # Calculate fleet participation (members with 3+ activities suggesting group play)
    fleet_participants = Enum.count(members, &(&1.total_activity >= 3))

    fleet_rate =
      if participation_base > 0, do: fleet_participants / participation_base * 100, else: 0.0

    # Calculate corporate activity (active members with 5+ activities)
    active_participants = Enum.count(members, &(&1.total_activity >= 5))

    active_rate =
      if participation_base > 0, do: active_participants / participation_base * 100, else: 0.0

    # Overall participation score (weighted average)
    overall_score = pvp_rate * 0.3 + fleet_rate * 0.4 + active_rate * 0.3

    %{
      pvp_participation: %{participants: pvp_participants, rate: Float.round(pvp_rate, 1)},
      fleet_participation: %{participants: fleet_participants, rate: Float.round(fleet_rate, 1)},
      corporate_activity: %{participants: active_participants, rate: Float.round(active_rate, 1)},
      overall_participation_score: Float.round(overall_score, 1),
      members_with_data: members_with_data,
      total_members: total_corp_members
    }
  end

  def format_doctrine_name(doctrine) do
    doctrine
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  def get_doctrine_description(doctrine) do
    case doctrine do
      :shield_kiting ->
        "Long-range shield tanked ships with high mobility and standoff capability"

      :armor_brawling ->
        "Close-range armor tanked ships focused on sustained DPS and tank"

      :ewar_heavy ->
        "Electronic warfare focused doctrine with force multiplication through disruption"

      :capital_escalation ->
        "Doctrine built around capital ship deployment and escalation scenarios"

      :alpha_strike ->
        "High alpha damage doctrine focused on quickly eliminating priority targets"

      :nano_gang ->
        "High speed, high mobility doctrine for hit-and-run tactics"

      :logistics_heavy ->
        "Doctrine emphasizing survivability through extensive logistics support"

      _ ->
        "Unknown doctrine pattern"
    end
  end

  def threat_level_color("Very High"), do: "text-red-500"
  def threat_level_color("High"), do: "text-orange-500"
  def threat_level_color("Moderate"), do: "text-yellow-500"
  def threat_level_color("Low"), do: "text-blue-500"
  def threat_level_color(_), do: "text-green-500"

  defp analyze_timezone_coverage(hourly_distribution) do
    # Use consistent timezone blocks from TimezoneAnalyzer
    # EUTZ: 16:00-20:00
    # USTZ: 21:00-03:00 (wraps around midnight)
    # AUTZ: 08:00-14:00
    timezone_blocks = %{
      "EU Prime (16:00-20:00)" => 16..20,
      "US Prime (21:00-03:00)" => [21, 22, 23, 0, 1, 2, 3],
      "AUTZ Prime (08:00-14:00)" => 8..14
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

  defp load_activities_with_system_info(participants) do
    # Get killmail IDs and times for query
    killmail_data =
      participants
      |> Enum.map(&{&1.killmail_id, &1.killmail_time})
      |> Enum.uniq()

    # Query for solar system IDs
    system_lookup = get_solar_systems_for_killmails(killmail_data)

    # Build activities with system info
    Enum.map(participants, fn p ->
      solar_system_id = Map.get(system_lookup, p.killmail_id)

      %{
        character_id: p.character_id,
        character_name: NameResolver.character_name(p.character_id),
        ship_name: NameResolver.ship_name(p.ship_type_id),
        is_kill: not p.is_victim,
        timestamp: p.killmail_time,
        killmail_id: p.killmail_id,
        solar_system_name:
          if(solar_system_id,
            do: NameResolver.system_name(solar_system_id),
            else: "Unknown"
          )
      }
    end)
  end

  defp get_solar_systems_for_killmails(killmail_data) when is_list(killmail_data) do
    if Enum.empty?(killmail_data) do
      %{}
    else
      # Build query to get solar system IDs for killmails
      killmail_ids = Enum.map(killmail_data, &elem(&1, 0))

      query = """
      SELECT killmail_id, solar_system_id 
      FROM killmails_raw 
      WHERE killmail_id = ANY($1)
      """

      case SQL.query(Repo, query, [killmail_ids]) do
        {:ok, %{rows: rows}} ->
          Enum.into(rows, %{}, fn [killmail_id, system_id] -> {killmail_id, system_id} end)

        {:error, _reason} ->
          %{}
      end
    end
  end
end
