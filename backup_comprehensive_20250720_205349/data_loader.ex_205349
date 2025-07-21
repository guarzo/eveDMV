defmodule EveDmvWeb.CorporationLive.DataLoader do
  @moduledoc """
  Optimized data loading for corporation analysis using new query modules.
  """

  alias EveDmv.Database.{CorporationQueries, QueryPerformance}
  alias EveDmv.Cache.AnalysisCache
  alias EveDmv.Eve.EsiCorporationClient
  require Logger

  @doc """
  Load all corporation data with optimized queries.
  """
  def load_corporation_data(corporation_id) do
    # Load data in parallel
    tasks = [
      Task.async(fn ->
        {"info", load_corporation_info(corporation_id)}
      end),
      Task.async(fn ->
        {"stats", load_corporation_stats(corporation_id)}
      end),
      Task.async(fn ->
        {"members", load_top_members(corporation_id)}
      end),
      Task.async(fn ->
        {"activity", load_recent_activity(corporation_id)}
      end),
      Task.async(fn ->
        {"timezone", load_timezone_activity(corporation_id)}
      end),
      Task.async(fn ->
        {"ships", load_ship_usage(corporation_id)}
      end)
    ]

    # Await all tasks and collect results
    results =
      tasks
      |> Enum.map(&Task.await(&1, 30_000))
      |> Map.new()

    # Combine all data
    %{
      corporation_id: corporation_id,
      info: results["info"],
      stats: results["stats"],
      members: results["members"],
      activity: results["activity"],
      timezone: results["timezone"],
      ships: results["ships"]
    }
  end

  @doc """
  Load corporation basic info (name, alliance, etc).
  """
  def load_corporation_info(corporation_id) do
    AnalysisCache.get_or_compute(
      AnalysisCache.corp_info_key(corporation_id),
      fn ->
        # First try to get from killmail data
        killmail_info =
          QueryPerformance.tracked_query(
            "corp_info_killmails",
            fn -> CorporationQueries.get_corporation_info_from_killmails(corporation_id) end,
            metadata: %{corporation_id: corporation_id}
          )

        # If we have a name from killmails, use it
        if killmail_info.corporation_name do
          {:ok, killmail_info}
        else
          # Fall back to ESI
          case EsiCorporationClient.get_corporation(corporation_id) do
            {:ok, esi_info} ->
              {:ok, Map.merge(killmail_info, esi_info)}

            {:error, _} ->
              # Return what we have from killmails
              {:ok, killmail_info}
          end
        end
      end,
      :timer.hours(24)
    )
  end

  @doc """
  Load corporation statistics (kills, losses, efficiency).
  """
  def load_corporation_stats(corporation_id) do
    ninety_days_ago = DateTime.utc_now() |> DateTime.add(-90, :day)
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)
    seven_days_ago = DateTime.utc_now() |> DateTime.add(-7, :day)

    AnalysisCache.get_or_compute(
      "corp_stats:#{corporation_id}",
      fn ->
        # Get stats for different time periods
        stats_90d =
          QueryPerformance.tracked_query(
            "corp_stats_90d",
            fn -> CorporationQueries.get_corporation_stats(corporation_id, ninety_days_ago) end
          )

        stats_30d =
          QueryPerformance.tracked_query(
            "corp_stats_30d",
            fn -> CorporationQueries.get_corporation_stats(corporation_id, thirty_days_ago) end
          )

        stats_7d =
          QueryPerformance.tracked_query(
            "corp_stats_7d",
            fn -> CorporationQueries.get_corporation_stats(corporation_id, seven_days_ago) end
          )

        {:ok,
         %{
           all_time: stats_90d,
           last_30_days: stats_30d,
           last_7_days: stats_7d
         }}
      end,
      :timer.hours(1)
    )
  end

  @doc """
  Load top active members.
  """
  def load_top_members(corporation_id, limit \\ 20) do
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

    QueryPerformance.tracked_query(
      "corp_top_members",
      fn ->
        CorporationQueries.get_top_active_members(corporation_id, limit, thirty_days_ago)
      end,
      metadata: %{corporation_id: corporation_id}
    )
  end

  @doc """
  Load recent corporation activity.
  """
  def load_recent_activity(corporation_id, limit \\ 50) do
    QueryPerformance.tracked_query(
      "corp_recent_activity",
      fn ->
        CorporationQueries.get_recent_activity(corporation_id, limit)
      end,
      metadata: %{corporation_id: corporation_id}
    )
  end

  @doc """
  Load timezone activity pattern.
  """
  def load_timezone_activity(corporation_id) do
    seven_days_ago = DateTime.utc_now() |> DateTime.add(-7, :day)

    AnalysisCache.get_or_compute(
      AnalysisCache.corp_timezone_key(corporation_id),
      fn ->
        activity =
          QueryPerformance.tracked_query(
            "corp_timezone",
            fn ->
              CorporationQueries.get_timezone_activity(corporation_id, seven_days_ago)
            end
          )

        # Calculate peak hours
        peak_hours =
          activity
          |> Enum.sort_by(& &1.activity, :desc)
          |> Enum.take(3)
          |> Enum.map(& &1.hour)

        # Determine primary timezone based on peak activity
        primary_tz = determine_timezone(peak_hours)

        {:ok,
         %{
           hourly_activity: activity,
           peak_hours: peak_hours,
           primary_timezone: primary_tz
         }}
      end,
      :timer.hours(6)
    )
  end

  @doc """
  Load ship usage statistics.
  """
  def load_ship_usage(corporation_id, limit \\ 25) do
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

    AnalysisCache.get_or_compute(
      "corp_ships:#{corporation_id}",
      fn ->
        ships =
          QueryPerformance.tracked_query(
            "corp_ship_usage",
            fn ->
              CorporationQueries.get_ship_usage_stats(corporation_id, thirty_days_ago, limit)
            end
          )

        # Resolve ship names if needed
        # This would integrate with your ship type resolver

        {:ok, ships}
      end,
      :timer.hours(2)
    )
  end

  # Helper functions

  defp determine_timezone(peak_hours) when is_list(peak_hours) do
    avg_hour = Enum.sum(peak_hours) / length(peak_hours)

    cond do
      avg_hour >= 0 and avg_hour < 8 -> "AU TZ"
      avg_hour >= 8 and avg_hour < 16 -> "EU TZ"
      avg_hour >= 16 and avg_hour < 24 -> "US TZ"
      true -> "Mixed TZ"
    end
  end
end
