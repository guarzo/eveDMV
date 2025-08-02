defmodule EveDmv.Contexts.Corporation.Services.MemberService do
  @moduledoc """
  Service layer for corporation member management operations.

  Handles member addition, updates, removal, and querying operations.
  """

  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Database.CharacterRepository
  alias EveDmv.Platform.Cache.Corporation.CorporationCache
  alias EveDmv.Platform.Database.CorporationRepository
  alias EveDmv.Platform.PubSub.CorporationUpdates

  require Logger

  @doc """
  Add a new member to the corporation.
  """
  def add_member(corporation_id, member_data) do
    Logger.info("Adding member #{member_data.character_id} to corporation #{corporation_id}")

    with {:ok, validated_data} <- validate_member_data(member_data),
         {:ok, member} <-
           CorporationRepository.add_corporation_member(corporation_id, validated_data),
         :ok <- invalidate_member_caches(corporation_id),
         :ok <- broadcast_member_added(corporation_id, member) do
      {:ok, member}
    else
      {:error, reason} = error ->
        Logger.error("Failed to add member to corporation #{corporation_id}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Update member information.
  """
  def update_member(member_id, data) do
    Logger.info("Updating member #{member_id}")

    with {:ok, validated_data} <- validate_member_update_data(data),
         {:ok, updated_member} <-
           CorporationRepository.update_corporation_member(member_id, validated_data),
         :ok <- invalidate_member_caches(updated_member.corporation_id),
         :ok <- broadcast_member_updated(updated_member) do
      {:ok, updated_member}
    else
      {:error, reason} = error ->
        Logger.error("Failed to update member #{member_id}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Remove a member from the corporation.
  """
  def remove_member(member_id) do
    Logger.info("Removing member #{member_id}")

    with {:ok, member} <- CorporationRepository.get_corporation_member(member_id),
         {:ok, removed_member} <- CorporationRepository.remove_corporation_member(member_id),
         :ok <- invalidate_member_caches(member.corporation_id),
         :ok <- broadcast_member_removed(member.corporation_id, removed_member) do
      {:ok, removed_member}
    else
      {:error, reason} = error ->
        Logger.error("Failed to remove member #{member_id}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Get member list for a corporation.

  Options:
    - include_inactive: Include inactive members (default: true)
    - sort_by: Sort field (:activity, :join_date, :name) (default: :activity)
    - order: Sort order (:asc, :desc) (default: :desc)
    - limit: Maximum results (default: 100)
    - offset: Result offset (default: 0)
  """
  def get_member_list(corporation_id, opts \\ []) do
    cache_key = {:member_list, corporation_id, opts}

    case CorporationCache.get(cache_key) do
      nil ->
        case fetch_member_list(corporation_id, opts) do
          {:ok, members} = result ->
            CorporationCache.put(cache_key, members, ttl: :timer.minutes(30))
            result

          error ->
            error
        end

      cached_members ->
        {:ok, cached_members}
    end
  end

  @doc """
  Get detailed information for a specific member.
  """
  def get_member_details(member_id) do
    cache_key = {:member_details, member_id}

    case CorporationCache.get(cache_key) do
      nil ->
        case build_member_details(member_id) do
          {:ok, details} = result ->
            CorporationCache.put(cache_key, details, ttl: :timer.hours(1))
            result

          error ->
            error
        end

      cached_details ->
        {:ok, cached_details}
    end
  end

  @doc """
  Bulk update member roles.
  """
  def bulk_update_member_roles(role_updates) do
    Logger.info("Performing bulk member role updates for #{length(role_updates)} members")

    results =
      role_updates
      |> Task.async_stream(
        fn {member_id, new_roles} ->
          {member_id, update_member_roles(member_id, new_roles)}
        end,
        max_concurrency: 10,
        timeout: 15_000
      )
      |> Enum.reduce({[], []}, fn
        {:ok, {member_id, {:ok, member}}}, {successes, failures} ->
          {[{member_id, member} | successes], failures}

        {:ok, {member_id, {:error, reason}}}, {successes, failures} ->
          {successes, [{member_id, reason} | failures]}

        {:exit, reason}, {successes, failures} ->
          Logger.error("Bulk role update task failed: #{inspect(reason)}")
          {successes, failures}
      end)
      |> then(fn {successes, failures} ->
        {:ok,
         %{
           updated: Enum.reverse(successes),
           failed: Enum.reverse(failures)
         }}
      end)

    # Invalidate caches for affected corporations
    affected_corporations =
      role_updates
      |> Enum.map(fn {member_id, _roles} ->
        case CorporationRepository.get_corporation_member(member_id) do
          {:ok, member} -> member.corporation_id
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    Enum.each(affected_corporations, &invalidate_member_caches/1)

    results
  end

  @doc """
  Get member statistics for a corporation.
  """
  def get_member_statistics(corporation_id) do
    cache_key = {:member_statistics, corporation_id}

    case CorporationCache.get(cache_key) do
      nil ->
        case calculate_member_statistics(corporation_id) do
          {:ok, stats} = result ->
            CorporationCache.put(cache_key, stats, ttl: :timer.hours(2))
            result

          error ->
            error
        end

      cached_stats ->
        {:ok, cached_stats}
    end
  end

  # Private Functions

  defp validate_member_data(data) do
    required_fields = [:character_id, :character_name]

    missing_fields =
      required_fields
      |> Enum.reject(fn field -> Map.has_key?(data, field) end)

    if Enum.empty?(missing_fields) do
      validated_data = %{
        character_id: data.character_id,
        character_name: data.character_name,
        join_date: Map.get(data, :join_date, DateTime.utc_now()),
        last_seen: Map.get(data, :last_seen),
        roles: Map.get(data, :roles, []),
        title: Map.get(data, :title),
        notes: Map.get(data, :notes),
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      {:ok, validated_data}
    else
      {:error, {:missing_required_fields, missing_fields}}
    end
  end

  defp validate_member_update_data(data) do
    allowed_fields = [
      :character_name,
      :last_seen,
      :roles,
      :title,
      :notes
    ]

    validated_data =
      data
      |> Map.take(allowed_fields)
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()
      |> Map.put(:updated_at, DateTime.utc_now())

    {:ok, validated_data}
  end

  defp fetch_member_list(corporation_id, opts) do
    with {:ok, members} <- CorporationRepository.get_corporation_members(corporation_id) do
      processed_members =
        members
        |> maybe_filter_inactive(opts)
        |> sort_members(opts)
        |> paginate_members(opts)
        |> enrich_member_data()

      {:ok, processed_members}
    end
  end

  defp maybe_filter_inactive(members, opts) do
    if Keyword.get(opts, :include_inactive, true) do
      members
    else
      cutoff = DateTime.utc_now() |> DateTimeUtils.add(-30 * 24 * 60 * 60, :second)

      Enum.filter(members, fn member ->
        member.last_seen && DateTimeUtils.compare(member.last_seen, cutoff) == :gt
      end)
    end
  end

  defp sort_members(members, opts) do
    sort_by = Keyword.get(opts, :sort_by, :activity)
    order = Keyword.get(opts, :order, :desc)

    sort_fun =
      case sort_by do
        :activity -> &(&1.recent_activity_score || 0)
        :join_date -> &(&1.join_date || DateTime.utc_now())
        :name -> & &1.character_name
        _ -> &(&1.recent_activity_score || 0)
      end

    Enum.sort_by(members, sort_fun, order)
  end

  defp paginate_members(members, opts) do
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)

    members
    |> Enum.drop(offset)
    |> Enum.take(limit)
  end

  defp enrich_member_data(members) do
    # Add computed fields and recent activity data
    members
    |> Enum.map(fn member ->
      Map.merge(member, %{
        tenure_days: calculate_tenure_days(member.join_date),
        activity_status: determine_activity_status(member),
        role_summary: summarize_roles(member.roles || [])
      })
    end)
  end

  defp calculate_tenure_days(nil), do: 0

  defp calculate_tenure_days(join_date) do
    DateTimeUtils.diff(DateTime.utc_now(), join_date, :day)
  end

  defp determine_activity_status(member) do
    if member.last_seen do
      days_since = DateTimeUtils.diff(DateTime.utc_now(), member.last_seen, :day)

      cond do
        days_since <= 7 -> :very_active
        days_since <= 14 -> :active
        days_since <= 30 -> :moderately_active
        days_since <= 60 -> :low_activity
        true -> :inactive
      end
    else
      :unknown
    end
  end

  defp summarize_roles(roles) do
    role_priorities = %{
      "CEO" => 1,
      "Director" => 2,
      "Personnel Manager" => 3,
      "Fleet Commander" => 4,
      "Diplomat" => 5
    }

    highest_role =
      roles
      |> Enum.min_by(fn role -> Map.get(role_priorities, role, 999) end, fn -> nil end)

    %{
      primary_role: highest_role,
      role_count: length(roles),
      has_leadership: Enum.any?(roles, fn role -> Map.has_key?(role_priorities, role) end)
    }
  end

  defp build_member_details(member_id) do
    with {:ok, member} <- CorporationRepository.get_corporation_member(member_id),
         {:ok, character_stats} <- get_character_stats(member.character_id),
         {:ok, recent_activity} <- get_recent_activity(member.character_id) do
      details = %{
        member_info: member,
        character_stats: character_stats,
        recent_activity: recent_activity,
        tenure_analysis: analyze_member_tenure(member),
        role_history: get_role_history(member_id),
        performance_metrics: calculate_performance_metrics(member, character_stats)
      }

      {:ok, details}
    end
  end

  defp get_character_stats(character_id) do
    case CharacterRepository.get_character_stats(character_id) do
      {:ok, stats} -> {:ok, stats}
      {:error, :not_found} -> {:ok, %{}}
      error -> error
    end
  end

  defp get_recent_activity(character_id) do
    # Get recent activity data (last 30 days)
    start_date = DateTime.utc_now() |> DateTimeUtils.add(-30 * 24 * 60 * 60, :second)

    case CharacterRepository.get_character_killmails_since(character_id, start_date) do
      {:ok, killmails} ->
        activity = %{
          recent_kills: length(Enum.filter(killmails, &(&1.victim.character_id != character_id))),
          recent_losses:
            length(Enum.filter(killmails, &(&1.victim.character_id == character_id))),
          total_recent_activity: length(killmails),
          activity_days: calculate_activity_days(killmails),
          most_used_ships: extract_most_used_ships(killmails, character_id)
        }

        {:ok, activity}

      error ->
        error
    end
  end

  defp calculate_activity_days(killmails) do
    killmails
    |> Enum.map(fn km -> DateTime.to_date(km.killmail_time) end)
    |> Enum.uniq()
    |> length()
  end

  defp extract_most_used_ships(killmails, character_id) do
    killmails
    |> Enum.flat_map(&extract_ship_type_for_character(&1, character_id))
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_ship, count} -> count end, :desc)
    |> Enum.take(5)
  end

  defp extract_ship_type_for_character(km, character_id) do
    if km.victim.character_id == character_id do
      [km.victim.ship_type_id]
    else
      case Enum.find(km.attackers, fn att -> att.character_id == character_id end) do
        nil -> []
        attacker -> [attacker.ship_type_id]
      end
    end
  end

  defp analyze_member_tenure(member) do
    tenure_days = calculate_tenure_days(member.join_date)

    %{
      tenure_days: tenure_days,
      tenure_category: categorize_tenure(tenure_days),
      join_date: member.join_date,
      is_veteran: tenure_days > 365,
      is_new_member: tenure_days < 90
    }
  end

  defp categorize_tenure(days) do
    cond do
      days < 30 -> :new_recruit
      days < 90 -> :junior_member
      days < 365 -> :regular_member
      days < 730 -> :veteran_member
      true -> :senior_veteran
    end
  end

  defp get_role_history(_member_id) do
    # Would get actual role history from database
    # Simplified implementation
    [
      %{
        role: "Member",
        assigned_date: DateTime.utc_now() |> DateTimeUtils.add(-100 * 24 * 60 * 60, :second),
        assigned_by: "CEO"
      }
    ]
  end

  defp calculate_performance_metrics(member, character_stats) do
    base_metrics = %{
      kill_death_ratio:
        if character_stats[:kill_death_ratio] do
          Decimal.to_float(character_stats.kill_death_ratio)
        else
          0.0
        end,
      isk_efficiency: character_stats[:isk_efficiency] || 0.0,
      total_kills: character_stats[:total_kills] || 0,
      total_losses: character_stats[:total_losses] || 0
    }

    # Add tenure-adjusted metrics
    tenure_days = calculate_tenure_days(member.join_date)

    Map.merge(base_metrics, %{
      kills_per_day:
        if tenure_days > 0 do
          base_metrics.total_kills / tenure_days
        else
          0.0
        end,
      # Would calculate from historical data
      performance_trend: :stable,
      # Would compare to corp average
      relative_performance: :average
    })
  end

  defp update_member_roles(member_id, new_roles) do
    update_data = %{
      roles: new_roles,
      updated_at: DateTime.utc_now()
    }

    CorporationRepository.update_corporation_member(member_id, update_data)
  end

  defp calculate_member_statistics(corporation_id) do
    with {:ok, members} <- CorporationRepository.get_corporation_members(corporation_id) do
      stats = %{
        total_members: length(members),
        active_members: count_active_members(members),
        inactive_members: count_inactive_members(members),
        new_recruits: count_new_recruits(members),
        veteran_members: count_veteran_members(members),
        leadership_count: count_leadership_members(members),
        average_tenure: calculate_average_tenure(members),
        activity_distribution: analyze_activity_distribution(members),
        role_distribution: analyze_role_distribution(members)
      }

      {:ok, stats}
    end
  end

  defp count_active_members(members) do
    cutoff = DateTime.utc_now() |> DateTimeUtils.add(-30 * 24 * 60 * 60, :second)

    Enum.count(members, fn member ->
      member.last_seen && DateTimeUtils.compare(member.last_seen, cutoff) == :gt
    end)
  end

  defp count_inactive_members(members) do
    length(members) - count_active_members(members)
  end

  defp count_new_recruits(members) do
    cutoff = DateTime.utc_now() |> DateTimeUtils.add(-90 * 24 * 60 * 60, :second)

    Enum.count(members, fn member ->
      member.join_date && DateTimeUtils.compare(member.join_date, cutoff) == :gt
    end)
  end

  defp count_veteran_members(members) do
    cutoff = DateTime.utc_now() |> DateTimeUtils.add(-365 * 24 * 60 * 60, :second)

    Enum.count(members, fn member ->
      member.join_date && DateTimeUtils.compare(member.join_date, cutoff) == :lt
    end)
  end

  defp count_leadership_members(members) do
    leadership_roles = ["CEO", "Director", "Personnel Manager", "Fleet Commander"]

    Enum.count(members, fn member ->
      member.roles && Enum.any?(member.roles, fn role -> role in leadership_roles end)
    end)
  end

  defp calculate_average_tenure(members) do
    if Enum.empty?(members) do
      0
    else
      total_tenure =
        members
        |> Enum.map(&calculate_tenure_days(&1.join_date))
        |> Enum.sum()

      Float.round(total_tenure / length(members), 1)
    end
  end

  defp analyze_activity_distribution(members) do
    activity_levels =
      members
      |> Enum.map(&determine_activity_status/1)
      |> Enum.frequencies()

    activity_levels
  end

  defp analyze_role_distribution(members) do
    all_roles =
      members
      |> Enum.flat_map(fn member -> member.roles || [] end)
      |> Enum.frequencies()

    all_roles
  end

  defp invalidate_member_caches(corporation_id) do
    # Invalidate all member-related caches for the corporation
    cache_patterns = [
      {:member_list, corporation_id, :_},
      {:member_statistics, corporation_id},
      {:member_activity, corporation_id},
      {:participation_analysis, corporation_id}
    ]

    # Clear cache entries (simplified - would use pattern matching)
    Enum.each(cache_patterns, fn pattern ->
      case pattern do
        {:member_list, corp_id, :_} ->
          # Would clear all member_list entries for this corporation
          CorporationCache.delete({:member_list, corp_id, []})

        other ->
          CorporationCache.delete(other)
      end
    end)

    :ok
  end

  defp broadcast_member_added(corporation_id, member) do
    CorporationUpdates.broadcast_member_added(corporation_id, member)
    :ok
  end

  defp broadcast_member_updated(member) do
    CorporationUpdates.broadcast_member_updated(member)
    :ok
  end

  defp broadcast_member_removed(corporation_id, member) do
    CorporationUpdates.broadcast_member_removed(corporation_id, member)
    :ok
  end
end
