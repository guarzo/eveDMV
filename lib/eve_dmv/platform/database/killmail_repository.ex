defmodule EveDmv.Database.KillmailRepository do
  @moduledoc """
  Repository for killmail data access with optimized queries and caching.

  Provides high-performance access to killmail data with specialized methods
  for common EVE DMV use cases like character/corporation analysis and
  intelligence gathering.
  """

  use EveDmv.Database.Repository,
    resource: EveDmv.Killmails.KillmailEnriched,
    cache_type: :hot_data

  alias EveDmv.Api
  alias EveDmv.Cache
  alias EveDmv.Database.Repository.CacheHelper
  alias EveDmv.Database.Repository.QueryBuilder
  alias EveDmv.Database.Repository.TelemetryHelper
  alias EveDmv.Killmails.KillmailEnriched

  require Ash.Query

  # Specialized query methods for killmail intelligence

  # Helper functions to safely create field atoms
  defp entity_field(:character), do: :character_id
  defp entity_field(:corporation), do: :corporation_id

  defp victim_entity_field(:character), do: :victim_character_id
  defp victim_entity_field(:corporation), do: :victim_corporation_id

  @doc """
  Get killmails by character within a date range with efficient preloading.

  Optimized for character intelligence analysis with proper participant preloading
  to avoid N+1 queries.

  ## Options

  - `:start_date` - Start of date range (DateTime or Date)
  - `:end_date` - End of date range (DateTime or Date)
  - `:limit` - Maximum number of killmails (default: 1000)
  - `:preload_participants` - Whether to preload participants (default: true)
  - `:include_losses` - Include killmails where character was victim (default: true)

  ## Examples

      get_by_character(98_765, start_date: ~D[2024-01-01], end_date: ~D[2024-01-31])
      get_by_character(98_765, limit: 500, include_losses: false)
  """
  @spec get_by_character(integer(), keyword()) :: {:ok, [struct()]} | {:error, term()}
  def get_by_character(character_id, opts \\ []) do
    cache_key = CacheHelper.build_key("killmail", "character", character_id, opts)

    Cache.get_or_compute(
      :hot_data,
      cache_key,
      fn ->
        TelemetryHelper.measure_query("killmail", :get_by_character, fn ->
          query = build_character_killmails_query(character_id, opts)
          Ash.read(query, domain: Api)
        end)
      end,
      opts
    )
  end

  @doc """
  Get killmails by corporation within a date range.

  Optimized for corporation analysis with efficient participant filtering.

  ## Options

  - `:start_date` - Start of date range
  - `:end_date` - End of date range
  - `:limit` - Maximum number of killmails (default: 1000)
  - `:include_losses` - Include corporation losses (default: true)
  - `:wormhole_only` - Filter to wormhole systems only (default: false)

  ## Examples

      get_by_corporation(12_345, start_date: ~D[2024-01-01], end_date: ~D[2024-01-31])
      get_by_corporation(12_345, wormhole_only: true, limit: 200)
  """
  @spec get_by_corporation(integer(), keyword()) :: {:ok, [struct()]} | {:error, term()}
  def get_by_corporation(corporation_id, opts \\ []) do
    cache_key = CacheHelper.build_key("killmail", "corporation", corporation_id, opts)

    Cache.get_or_compute(
      :hot_data,
      cache_key,
      fn ->
        TelemetryHelper.measure_query("killmail", :get_by_corporation, fn ->
          query = build_corporation_killmails_query(corporation_id, opts)
          Ash.read(query, domain: Api)
        end)
      end,
      opts
    )
  end

  @doc """
  Get recent high-value killmails for the kill feed.

  Optimized query for the real-time kill feed with appropriate caching.

  ## Options

  - `:limit` - Number of killmails to return (default: 100)
  - `:min_value` - Minimum ISK value threshold (default: 10M ISK)
  - `:hours_back` - How many hours back to search (default: 24)
  - `:wormhole_only` - Only wormhole killmails (default: false)

  ## Examples

      get_recent_high_value(limit: 50, min_value: 50_000_000)
      get_recent_high_value(wormhole_only: true, hours_back: 6)
  """
  @spec get_recent_high_value(keyword()) :: {:ok, [struct()]} | {:error, term()}
  def get_recent_high_value(opts \\ []) do
    cache_key = CacheHelper.build_key("killmail", "recent_high_value", opts, [])

    # Use shorter cache TTL for real-time data
    # 30 seconds
    cache_opts = Keyword.put(opts, :cache_ttl, 30_000)

    Cache.get_or_compute(
      :hot_data,
      cache_key,
      fn ->
        TelemetryHelper.measure_query("killmail", :get_recent_high_value, fn ->
          query = build_recent_high_value_query(opts)
          Ash.read(query, domain: Api)
        end)
      end,
      cache_opts
    )
  end

  @doc """
  Get killmail statistics for a character or corporation.

  Returns aggregated statistics with efficient calculation using database functions.

  ## Examples

      get_kill_stats(character_id: 98_765)
      get_kill_stats(corporation_id: 12_345, days_back: 30)
  """
  @spec get_kill_stats(keyword()) :: {:ok, map()} | {:error, term()}
  def get_kill_stats(opts) do
    entity_type =
      cond do
        opts[:character_id] -> :character
        opts[:corporation_id] -> :corporation
        true -> :invalid
      end

    case entity_type do
      :invalid ->
        {:error, "Must specify either character_id or corporation_id"}

      entity_type ->
        entity_id = opts[entity_field(entity_type)]
        cache_key = CacheHelper.build_key("killmail", "stats_#{entity_type}", entity_id, opts)

        Cache.get_or_compute(
          :api_responses,
          cache_key,
          fn ->
            TelemetryHelper.measure_query("killmail", :get_kill_stats, fn ->
              calculate_kill_stats(entity_type, entity_id, opts)
            end)
          end,
          opts
        )
    end
  end

  @doc """
  Batch load killmails by IDs with optimized participant preloading.

  Prevents N+1 queries when loading multiple killmails with their participants.
  """
  @spec batch_get_with_participants([integer()]) :: {:ok, [struct()]} | {:error, term()}
  def batch_get_with_participants(killmail_ids) when is_list(killmail_ids) do
    TelemetryHelper.measure_query("killmail", :batch_get_with_participants, fn ->
      query =
        Ash.Query.new(KillmailEnriched)
        |> Ash.Query.filter(killmail_id in ^killmail_ids)
        |> Ash.Query.load([:participants])
        |> Ash.Query.sort(desc: :killmail_time)

      Ash.read(query, domain: Api)
    end)
  end

  @doc """
  Get battles since a specific date.
  """
  @spec get_battles_since(DateTime.t()) :: {:ok, [struct()]} | {:error, term()}
  def get_battles_since(since_date) do
    cache_key = CacheHelper.build_key("killmail", "battles_since", since_date, [])

    Cache.get_or_compute(
      :hot_data,
      cache_key,
      fn ->
        TelemetryHelper.measure_query("killmail", :get_battles_since, fn ->
          # For now, return battles based on high-value killmail grouping
          # This is a simplified implementation - in reality would need battle detection logic
          query =
            Ash.Query.new(KillmailEnriched)
            |> Ash.Query.filter(killmail_time >= ^since_date)
            # 50M+ ISK battles
            |> Ash.Query.filter(total_value >= 50_000_000)
            |> Ash.Query.sort(desc: :killmail_time)
            |> Ash.Query.limit(100)
            |> Ash.Query.load([:participants])

          Ash.read(query, domain: Api)
        end)
      end,
      # 5 minutes cache
      cache_ttl: 300
    )
  end

  @doc """
  Get popular fleet compositions with minimum engagement count.
  """
  @spec get_popular_fleet_compositions(integer(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def get_popular_fleet_compositions(min_engagements, opts \\ []) do
    cache_key = CacheHelper.build_key("killmail", "popular_compositions", min_engagements, opts)

    Cache.get_or_compute(
      :analysis,
      cache_key,
      fn ->
        TelemetryHelper.measure_query("killmail", :get_popular_compositions, fn ->
          # Simplified implementation - analyze ship types from recent killmails
          days_back = Keyword.get(opts, :days_back, 30)
          since_date = DateTime.add(DateTime.utc_now(), -days_back, :day)

          query =
            Ash.Query.new(KillmailEnriched)
            |> Ash.Query.filter(killmail_time >= ^since_date)
            # High value engagements
            |> Ash.Query.filter(total_value >= 100_000_000)
            |> Ash.Query.sort(desc: :killmail_time)
            |> Ash.Query.limit(500)
            |> Ash.Query.load([:participants])

          case Ash.read(query, domain: Api) do
            {:ok, killmails} ->
              compositions = analyze_fleet_compositions(killmails, min_engagements)
              {:ok, compositions}

            error ->
              error
          end
        end)
      end,
      # 1 hour cache
      Keyword.merge(opts, cache_ttl: 3600)
    )
  end

  # Private query building methods

  defp build_character_killmails_query(character_id, opts) do
    start_date = get_date_option(opts, :start_date, days_ago: 90)
    end_date = get_date_option(opts, :end_date, DateTime.utc_now())
    limit = Keyword.get(opts, :limit, 1000)
    include_losses = Keyword.get(opts, :include_losses, true)
    preload_participants = Keyword.get(opts, :preload_participants, true)

    query =
      Ash.Query.new(KillmailEnriched)
      |> Ash.Query.filter(killmail_time >= ^start_date)
      |> Ash.Query.filter(killmail_time <= ^end_date)
      |> Ash.Query.sort(desc: :killmail_time)
      |> Ash.Query.limit(limit)

    # Add character involvement filter
    filtered_query =
      if include_losses do
        Ash.Query.filter(
          query,
          victim_character_id == ^character_id or
            exists(participants, character_id == ^character_id)
        )
      else
        Ash.Query.filter(
          query,
          exists(participants, character_id == ^character_id and not is_victim)
        )
      end

    # Add preloads if requested
    if preload_participants do
      Ash.Query.load(filtered_query, [:participants])
    else
      filtered_query
    end
  end

  defp build_corporation_killmails_query(corporation_id, opts) do
    start_date = get_date_option(opts, :start_date, days_ago: 30)
    end_date = get_date_option(opts, :end_date, DateTime.utc_now())
    limit = Keyword.get(opts, :limit, 1000)
    include_losses = Keyword.get(opts, :include_losses, true)
    wormhole_only = Keyword.get(opts, :wormhole_only, false)

    query =
      Ash.Query.new(KillmailEnriched)
      |> Ash.Query.filter(killmail_time >= ^start_date)
      |> Ash.Query.filter(killmail_time <= ^end_date)
      |> Ash.Query.sort(desc: :killmail_time)
      |> Ash.Query.limit(limit)
      |> Ash.Query.load([:participants])

    # Add corporation involvement filter
    corp_filtered_query =
      if include_losses do
        Ash.Query.filter(
          query,
          victim_corporation_id == ^corporation_id or
            exists(participants, corporation_id == ^corporation_id)
        )
      else
        Ash.Query.filter(
          query,
          exists(participants, corporation_id == ^corporation_id and not is_victim)
        )
      end

    # Add wormhole filter if requested
    if wormhole_only do
      Ash.Query.filter(corp_filtered_query, solar_system_id >= 31_000_000)
    else
      corp_filtered_query
    end
  end

  defp build_recent_high_value_query(opts) do
    limit = Keyword.get(opts, :limit, 100)
    # 10M ISK
    min_value = Keyword.get(opts, :min_value, 10_000_000)
    hours_back = Keyword.get(opts, :hours_back, 24)
    wormhole_only = Keyword.get(opts, :wormhole_only, false)

    cutoff_time = DateTime.add(DateTime.utc_now(), -hours_back, :hour)

    query =
      Ash.Query.new(KillmailEnriched)
      |> Ash.Query.filter(killmail_time >= ^cutoff_time)
      |> Ash.Query.filter(total_value >= ^min_value)
      |> Ash.Query.sort(desc: :killmail_time)
      |> Ash.Query.limit(limit)
      |> Ash.Query.load([:participants])

    if wormhole_only do
      Ash.Query.filter(query, solar_system_id >= 31_000_000)
    else
      query
    end
  end

  defp calculate_kill_stats(entity_type, entity_id, opts) do
    days_back = Keyword.get(opts, :days_back, 90)
    start_date = DateTime.add(DateTime.utc_now(), -days_back, :day)

    # This would use more sophisticated database aggregation in practice
    # For now, provide a basic implementation structure
    case get_killmails_for_stats(entity_type, entity_id, start_date) do
      {:ok, killmails} ->
        stats = %{
          total_killmails: length(killmails),
          total_kills: count_kills(killmails, entity_type, entity_id),
          total_losses: count_losses(killmails, entity_type, entity_id),
          total_isk_destroyed: sum_isk_destroyed(killmails, entity_type, entity_id),
          total_isk_lost: sum_isk_lost(killmails, entity_type, entity_id),
          period_start: start_date,
          period_end: DateTime.utc_now()
        }

        {:ok, stats}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_killmails_for_stats(entity_type, entity_id, start_date) do
    field = entity_field(entity_type)
    victim_field = victim_entity_field(entity_type)

    query =
      Ash.Query.new(KillmailEnriched)
      |> Ash.Query.filter(killmail_time >= ^start_date)
      |> Ash.Query.filter(
        field(^victim_field) == ^entity_id or
          exists(participants, field(^field) == ^entity_id)
      )
      |> Ash.Query.load([:participants])

    Ash.read(query, domain: Api)
  end

  defp count_kills(killmails, entity_type, entity_id) do
    field = entity_field(entity_type)
    victim_field = victim_entity_field(entity_type)

    Enum.count(killmails, fn km ->
      Map.get(km, victim_field) != entity_id and
        Enum.any?(km.participants || [], fn p -> Map.get(p, field) == entity_id end)
    end)
  end

  defp count_losses(killmails, entity_type, entity_id) do
    victim_field = victim_entity_field(entity_type)

    Enum.count(killmails, fn km ->
      Map.get(km, victim_field) == entity_id
    end)
  end

  defp sum_isk_destroyed(killmails, entity_type, entity_id) do
    field = entity_field(entity_type)
    victim_field = victim_entity_field(entity_type)

    killmails
    |> Enum.filter(fn km ->
      Map.get(km, victim_field) != entity_id and
        Enum.any?(km.participants || [], fn p -> Map.get(p, field) == entity_id end)
    end)
    |> Enum.map(fn km -> km.total_value || 0 end)
    |> Enum.sum()
  end

  defp sum_isk_lost(killmails, entity_type, entity_id) do
    victim_field = victim_entity_field(entity_type)

    killmails
    |> Enum.filter(fn km -> Map.get(km, victim_field) == entity_id end)
    |> Enum.map(fn km -> km.total_value || 0 end)
    |> Enum.sum()
  end

  defp get_date_option(opts, key, default_opts) do
    case Keyword.get(opts, key) do
      nil ->
        case default_opts do
          [days_ago: days] -> DateTime.add(DateTime.utc_now(), -days, :day)
          datetime -> datetime
        end

      date_or_datetime ->
        date_or_datetime
    end
  end

  @doc """
  Get killmails involving multiple characters with a date filter.

  Fetches all killmails where any of the specified characters appear
  either as victims or attackers.

  ## Examples

      get_killmails_by_characters([12345, 67890], ~U[2024-01-01 00:00:00Z])
  """
  @spec get_killmails_by_characters([integer()], DateTime.t()) ::
          {:ok, [struct()]} | {:error, term()}
  def get_killmails_by_characters(character_ids, start_time) when is_list(character_ids) do
    TelemetryHelper.measure_query("killmail", :get_by_characters, fn ->
      query =
        KillmailEnriched
        |> Ash.Query.new()
        |> Ash.Query.filter(killmail_time >= ^start_time)
        |> Ash.Query.filter(
          victim_character_id in ^character_ids or
            exists(participants, character_id in ^character_ids)
        )
        |> Ash.Query.sort(desc: :killmail_time)
        |> Ash.Query.limit(1000)
        |> Ash.Query.load([:participants])

      Ash.read(query, domain: Api)
    end)
  end

  defp analyze_fleet_compositions(killmails, min_engagements) do
    # Group killmails by similar engagement patterns and analyze ship compositions
    killmails
    |> Enum.group_by(fn km ->
      # Group by system and rough time window (1 hour)
      hour = DateTime.truncate(km.killmail_time, :hour)
      {km.solar_system_id, hour}
    end)
    |> Enum.filter(fn {_key, kms} -> length(kms) >= min_engagements end)
    |> Enum.map(fn {{system_id, hour}, kms} ->
      ship_types =
        kms
        |> Enum.flat_map(fn km -> km.participants || [] end)
        |> Enum.map(fn p -> p.ship_type_id end)
        |> Enum.frequencies()
        |> Enum.sort_by(fn {_ship, count} -> count end, :desc)
        |> Enum.take(10)

      %{
        system_id: system_id,
        engagement_time: hour,
        killmail_count: length(kms),
        total_value: kms |> Enum.map(&(&1.total_value || 0)) |> Enum.sum(),
        ship_composition: ship_types,
        participant_count: kms |> Enum.flat_map(fn km -> km.participants || [] end) |> length()
      }
    end)
    |> Enum.sort_by(& &1.total_value, :desc)
    |> Enum.take(20)
  end
end
