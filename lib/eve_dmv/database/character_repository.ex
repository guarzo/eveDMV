defmodule EveDmv.Database.CharacterRepository do
  @moduledoc """
  Repository for character statistics and intelligence data.

  Provides optimized access to character intelligence data with caching
  and performance monitoring specifically designed for hunter analysis.
  """

  use EveDmv.Database.Repository,
    resource: EveDmv.Intelligence.CharacterStats,
    cache_type: :analysis

  alias EveDmv.Api
  alias EveDmv.Cache
  alias EveDmv.Database.Repository.CacheHelper
  alias EveDmv.Database.Repository.QueryBuilder
  alias EveDmv.Database.Repository.TelemetryHelper
  alias EveDmv.Intelligence.CharacterStats
  require Ash.Query

  @doc """
  Get character statistics by character ID with caching.

  Optimized for frequent lookups during intelligence analysis.

  ## Examples

      get_character_stats(98765)
      get_character_stats(98765, bypass_cache: true)
  """
  @spec get_character_stats(integer(), keyword()) :: {:ok, struct() | nil} | {:error, term()}
  def get_character_stats(character_id, opts \\ []) do
    cache_key = CacheHelper.build_key("character_stats", "character", character_id, opts)

    Cache.get_or_compute(
      :analysis,
      cache_key,
      fn ->
        TelemetryHelper.measure_query("character_stats", :get_by_character, fn ->
          query =
            CharacterStats
            |> Ash.Query.new()
            |> Ash.Query.filter(character_id == ^character_id)

          case Ash.read_one(query, domain: Api) do
            {:ok, stats} -> {:ok, stats}
            {:error, reason} -> {:error, reason}
          end
        end)
      end,
      opts
    )
  end

  @doc """
  Get dangerous characters with high threat ratings.

  Cached query for quickly identifying high-priority targets.

  ## Options

  - `:min_rating` - Minimum dangerous rating (default: 4)
  - `:limit` - Maximum results (default: 100)
  - `:corporation_id` - Filter to specific corporation

  ## Examples

      get_dangerous_characters()
      get_dangerous_characters(min_rating: 5, limit: 50)
  """
  @spec get_dangerous_characters(keyword()) :: {:ok, [struct()]} | {:error, term()}
  def get_dangerous_characters(opts \\ []) do
    cache_key = CacheHelper.build_key("character_stats", "dangerous", opts, [])

    Cache.get_or_compute(
      :analysis,
      cache_key,
      fn ->
        TelemetryHelper.measure_query("character_stats", :get_dangerous, fn ->
          min_rating = Keyword.get(opts, :min_rating, 4)
          limit = Keyword.get(opts, :limit, 100)
          corporation_id = Keyword.get(opts, :corporation_id)

          query =
            CharacterStats
            |> Ash.Query.new()
            |> Ash.Query.filter(dangerous_rating >= ^min_rating)
            |> Ash.Query.sort(desc: :dangerous_rating)
            |> Ash.Query.limit(limit)

          query =
            if corporation_id do
              Ash.Query.filter(query, corporation_id == ^corporation_id)
            else
              query
            end

          Ash.read(query, domain: Api)
        end)
      end,
      opts
    )
  end

  @doc """
  Batch get character statistics for multiple characters.

  Prevents N+1 queries when loading stats for multiple characters
  during corporation or fleet analysis.

  ## Examples

      batch_get_character_stats([98765, 98766, 98767])
  """
  @spec batch_get_character_stats([integer()]) :: {:ok, [struct()]} | {:error, term()}
  def batch_get_character_stats(character_ids) when is_list(character_ids) do
    TelemetryHelper.measure_query("character_stats", :batch_get, fn ->
      query =
        CharacterStats
        |> Ash.Query.new()
        |> Ash.Query.filter(character_id in ^character_ids)
        |> Ash.Query.sort(:character_name)

      Ash.read(query, domain: Api)
    end)
  end

  @doc """
  Get corporation members with their character statistics.

  Optimized for corporation intelligence analysis.

  ## Options

  - `:active_only` - Only include recently active members
  - `:min_activity_days` - Minimum days since last activity (default: 30)

  ## Examples

      get_corporation_members(12345)
      get_corporation_members(12345, active_only: true)
  """
  @spec get_corporation_members(integer(), keyword()) :: {:ok, [struct()]} | {:error, term()}
  def get_corporation_members(corporation_id, opts \\ []) do
    cache_key = CacheHelper.build_key("character_stats", "corp_members", corporation_id, opts)

    Cache.get_or_compute(
      :analysis,
      cache_key,
      fn ->
        TelemetryHelper.measure_query("character_stats", :get_corp_members, fn ->
          active_only = Keyword.get(opts, :active_only, false)
          min_activity_days = Keyword.get(opts, :min_activity_days, 30)

          query =
            CharacterStats
            |> Ash.Query.new()
            |> Ash.Query.filter(corporation_id == ^corporation_id)
            |> Ash.Query.sort(:character_name)

          query =
            if active_only do
              cutoff_date = DateTime.add(DateTime.utc_now(), -min_activity_days, :day)
              Ash.Query.filter(query, last_calculated_at >= ^cutoff_date)
            else
              query
            end

          Ash.read(query, domain: Api)
        end)
      end,
      opts
    )
  end

  @doc """
  Update character statistics and invalidate related caches.

  Ensures cache consistency when character data is refreshed.
  """
  @spec update_character_stats(struct(), map()) :: {:ok, struct()} | {:error, term()}
  def update_character_stats(character_stats, attrs) do
    case update(character_stats, attrs) do
      {:ok, updated_stats} ->
        # Invalidate specific caches related to this character
        invalidate_character_caches(updated_stats.character_id)
        {:ok, updated_stats}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Refresh statistics for a character by triggering recalculation.
  """
  @spec refresh_character_stats(integer()) :: {:ok, struct()} | {:error, term()}
  def refresh_character_stats(character_id) do
    case get_character_stats(character_id, bypass_cache: true) do
      {:ok, nil} ->
        {:error, :not_found}

      {:ok, stats} ->
        TelemetryHelper.measure_query("character_stats", :refresh, fn ->
          case Ash.update(stats, %{last_calculated_at: DateTime.utc_now()},
                 action: :refresh_stats,
                 domain: Api
               ) do
            {:ok, updated_stats} ->
              invalidate_character_caches(character_id)
              {:ok, updated_stats}

            {:error, reason} ->
              {:error, reason}
          end
        end)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private helper functions

  defp invalidate_character_caches(character_id) do
    # Invalidate specific character caches
    Cache.delete(
      :analysis,
      CacheHelper.build_key("character_stats", "character", character_id, [])
    )

    # Invalidate dangerous characters cache (might include this character)
    Cache.invalidate_pattern(:analysis, "repo:character_stats:dangerous:*")

    # Invalidate corporation member caches (if this character belongs to a corp)
    Cache.invalidate_pattern(:analysis, "repo:character_stats:corp_members:*")

    :ok
  end
end
