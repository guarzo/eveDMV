defmodule EveDmv.Contexts.Corporation.Services.StatsLoader do
  @moduledoc """
  Loads corporation statistics using a hybrid approach.

  This module replaces `CorporationQueries.get_corporation_stats/2` with a
  more maintainable implementation that uses Ash queries where possible
  and falls back to optimized SQL for complex aggregations.

  ## Usage

      {:ok, stats} = StatsLoader.load_stats(corporation_id, days: 90)
  """

  alias EveDmv.Platform.Cache.QueryCache
  alias EveDmv.Repo
  require Logger

  @default_days 90
  @cache_ttl :timer.hours(1)

  @doc """
  Load corporation statistics for the given time period.

  ## Options

    * `:days` - Number of days to look back (default: 90)
    * `:skip_cache` - Skip the cache and compute fresh (default: false)

  ## Returns

      {:ok, %{
        kills: 150,
        losses: 50,
        isk_destroyed: 1_000_000_000.0,
        isk_lost: 250_000_000.0,
        efficiency: 75.0,
        isk_efficiency: 80.0,
        active_members: 25
      }}
  """
  @spec load_stats(integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def load_stats(corporation_id, opts \\ []) do
    days = Keyword.get(opts, :days, @default_days)
    skip_cache = Keyword.get(opts, :skip_cache, false)

    since_date = DateTime.add(DateTime.utc_now(), -days, :day)
    cache_key = "corp_stats_v2:#{corporation_id}:#{Date.to_iso8601(DateTime.to_date(since_date))}"

    if skip_cache do
      compute_stats(corporation_id, since_date)
    else
      QueryCache.get_or_compute(
        cache_key,
        fn -> compute_stats(corporation_id, since_date) end,
        ttl: @cache_ttl
      )
    end
  end

  defp compute_stats(corporation_id, since_date) do
    # Use the materialized view for fast lookups
    # Falls back to direct query if view isn't available
    stats_query = """
    SELECT
      SUM(kills) as kill_count,
      SUM(losses) as loss_count,
      SUM(isk_destroyed) as isk_destroyed,
      SUM(isk_lost) as isk_lost,
      COUNT(DISTINCT character_id) as active_members
    FROM corporation_member_summary
    WHERE corporation_id = $1
      AND last_seen >= $2
    """

    case Repo.query(stats_query, [corporation_id, since_date]) do
      {:ok, %{rows: [[kills, losses, isk_destroyed, isk_lost, active_members]]}} ->
        format_stats(kills, losses, isk_destroyed, isk_lost, active_members)

      {:ok, %{rows: []}} ->
        # No data found, return zero stats
        format_stats(0, 0, nil, nil, 0)

      {:error, %Postgrex.Error{postgres: %{code: :undefined_table}}} ->
        # Materialized view doesn't exist, fall back to direct query
        Logger.warning("corporation_member_summary view not available, using fallback")
        compute_stats_direct(corporation_id, since_date)

      {:error, error} ->
        Logger.error("Failed to load corporation stats: #{inspect(error)}")
        {:error, :query_failed}
    end
  end

  defp compute_stats_direct(corporation_id, since_date) do
    # Direct query against participants table
    query = """
    SELECT
      COUNT(CASE WHEN p.is_victim = false THEN 1 END) as kills,
      COUNT(CASE WHEN p.is_victim = true THEN 1 END) as losses,
      COALESCE(SUM(CASE WHEN p.is_victim = false THEN k.total_value ELSE 0 END), 0) as isk_destroyed,
      COALESCE(SUM(CASE WHEN p.is_victim = true THEN k.total_value ELSE 0 END), 0) as isk_lost,
      COUNT(DISTINCT p.character_id) as active_members
    FROM participants p
    LEFT JOIN killmails_raw k ON p.killmail_id = k.killmail_id
    WHERE p.corporation_id = $1
      AND p.killmail_time >= $2
    """

    case Repo.query(query, [corporation_id, since_date]) do
      {:ok, %{rows: [[kills, losses, isk_destroyed, isk_lost, active_members]]}} ->
        format_stats(kills, losses, isk_destroyed, isk_lost, active_members)

      {:ok, %{rows: []}} ->
        # No data found, return zero stats
        format_stats(0, 0, nil, nil, 0)

      {:error, error} ->
        Logger.error("Fallback query failed: #{inspect(error)}")
        {:error, :query_failed}
    end
  end

  defp format_stats(kills, losses, isk_destroyed, isk_lost, active_members) do
    k = kills || 0
    l = losses || 0
    isk_d = safe_to_float(isk_destroyed)
    isk_l = safe_to_float(isk_lost)

    efficiency = if k + l > 0, do: Float.round(k / (k + l) * 100, 2), else: 100.0

    isk_efficiency =
      if isk_d + isk_l > 0, do: Float.round(isk_d / (isk_d + isk_l) * 100, 2), else: 50.0

    {:ok,
     %{
       kills: k,
       losses: l,
       isk_destroyed: isk_d,
       isk_lost: isk_l,
       efficiency: efficiency,
       isk_efficiency: isk_efficiency,
       active_members: active_members || 0
     }}
  end

  defp safe_to_float(nil), do: 0.0
  defp safe_to_float(%Decimal{} = d), do: Decimal.to_float(d)
  defp safe_to_float(n) when is_number(n), do: n * 1.0
  defp safe_to_float(_), do: 0.0
end
