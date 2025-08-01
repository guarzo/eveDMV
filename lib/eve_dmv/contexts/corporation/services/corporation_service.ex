defmodule EveDmv.Contexts.Corporation.Services.CorporationService do
  @moduledoc """
  Service layer for corporation management operations.

  Handles corporation creation, updates, search, and caching operations.
  """

  alias EveDmv.Platform.Cache.Corporation.CorporationCache
  alias EveDmv.Platform.Database.CorporationRepository
  alias EveDmv.Platform.PubSub.CorporationUpdates

  require Logger

  @doc """
  Create a new corporation profile.
  """
  def create_corporation_profile(corporation_data) do
    Logger.info("Creating corporation profile for #{corporation_data.corporation_id}")

    with {:ok, corporation} <- validate_corporation_data(corporation_data),
         {:ok, created_corp} <- CorporationRepository.create_corporation(corporation),
         :ok <- broadcast_corporation_created(created_corp) do
      {:ok, created_corp}
    else
      {:error, reason} = error ->
        Logger.error("Failed to create corporation profile: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Update corporation data.
  """
  def update_corporation_data(corporation_id, data) do
    Logger.info("Updating corporation data for #{corporation_id}")

    with {:ok, updated_data} <- validate_update_data(data),
         {:ok, updated_corp} <-
           CorporationRepository.update_corporation(corporation_id, updated_data),
         :ok <- invalidate_corporation_cache(corporation_id),
         :ok <- broadcast_corporation_updated(updated_corp) do
      {:ok, updated_corp}
    else
      {:error, reason} = error ->
        Logger.error("Failed to update corporation #{corporation_id}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Get corporation by ID.
  """
  def get_corporation(corporation_id) do
    case CorporationCache.get({:corporation_basic, corporation_id}) do
      nil ->
        case CorporationRepository.get_corporation_info(corporation_id) do
          {:ok, corporation} = result ->
            CorporationCache.put({:corporation_basic, corporation_id}, corporation,
              ttl: :timer.hours(2)
            )

            result

          error ->
            error
        end

      cached_corporation ->
        {:ok, cached_corporation}
    end
  end

  @doc """
  Search corporations by various criteria.
  """
  def search_corporations(search_params) do
    Logger.info("Searching corporations with params: #{inspect(search_params)}")

    with {:ok, validated_params} <- validate_search_params(search_params),
         {:ok, results} <- CorporationRepository.search_corporations(validated_params) do
      {:ok, results}
    else
      {:error, reason} = error ->
        Logger.error("Corporation search failed: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Refresh corporation cache.
  """
  def refresh_corporation_cache(corporation_id) do
    Logger.info("Refreshing cache for corporation #{corporation_id}")

    # Clear all cached data for this corporation
    cache_keys = [
      {:corporation_basic, corporation_id},
      {:corporation_stats, corporation_id},
      {:corporation_analysis, corporation_id},
      {:member_activity, corporation_id},
      {:member_risks, corporation_id},
      {:participation_analysis, corporation_id},
      {:recruitment_pipeline, corporation_id},
      {:combat_doctrine, corporation_id},
      {:organizational_health, corporation_id}
    ]

    Enum.each(cache_keys, &CorporationCache.delete/1)

    # Pre-warm basic corporation data
    case get_corporation(corporation_id) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "Failed to pre-warm cache for corporation #{corporation_id}: #{inspect(reason)}"
        )

        :ok
    end
  end

  @doc """
  Clear corporation cache.
  """
  def clear_corporation_cache(corporation_id) do
    Logger.info("Clearing cache for corporation #{corporation_id}")

    cache_keys = [
      {:corporation_basic, corporation_id},
      {:corporation_stats, corporation_id},
      {:corporation_analysis, corporation_id},
      {:member_activity, corporation_id},
      {:member_risks, corporation_id},
      {:participation_analysis, corporation_id},
      {:recruitment_pipeline, corporation_id},
      {:combat_doctrine, corporation_id},
      {:organizational_health, corporation_id}
    ]

    Enum.each(cache_keys, &CorporationCache.delete/1)
    :ok
  end

  @doc """
  Subscribe to corporation updates.
  """
  def subscribe_to_corporation_updates(corporation_id) do
    CorporationUpdates.subscribe(corporation_id)
  end

  @doc """
  Unsubscribe from corporation updates.
  """
  def unsubscribe_from_corporation_updates(corporation_id) do
    CorporationUpdates.unsubscribe(corporation_id)
  end

  # Private Functions

  defp validate_corporation_data(data) do
    required_fields = [:corporation_id, :corporation_name]

    missing_fields =
      required_fields
      |> Enum.reject(fn field -> Map.has_key?(data, field) end)

    if Enum.empty?(missing_fields) do
      validated_data = %{
        corporation_id: data.corporation_id,
        corporation_name: data.corporation_name,
        ticker: Map.get(data, :ticker),
        alliance_id: Map.get(data, :alliance_id),
        alliance_name: Map.get(data, :alliance_name),
        ceo_id: Map.get(data, :ceo_id),
        founded_date: Map.get(data, :founded_date),
        headquarters: Map.get(data, :headquarters),
        public_info: Map.get(data, :public_info, %{}),
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      {:ok, validated_data}
    else
      {:error, {:missing_required_fields, missing_fields}}
    end
  end

  defp validate_update_data(data) do
    # Filter out nil values and validate allowed fields
    allowed_fields = [
      :corporation_name,
      :ticker,
      :alliance_id,
      :alliance_name,
      :ceo_id,
      :headquarters,
      :public_info
    ]

    validated_data =
      data
      |> Map.take(allowed_fields)
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()
      |> Map.put(:updated_at, DateTime.utc_now())

    {:ok, validated_data}
  end

  defp validate_search_params(params) do
    # Validate and normalize search parameters
    validated_params =
      %{
        name: Map.get(params, :name),
        ticker: Map.get(params, :ticker),
        alliance_id: Map.get(params, :alliance_id),
        min_members: Map.get(params, :min_members),
        max_members: Map.get(params, :max_members),
        activity_level: Map.get(params, :activity_level),
        limit: Map.get(params, :limit, 50),
        offset: Map.get(params, :offset, 0)
      }
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()

    # Validate limits
    validated_params =
      validated_params
      |> Map.update(:limit, 50, fn limit -> min(limit, 100) end)
      |> Map.update(:offset, 0, fn offset -> max(offset, 0) end)

    {:ok, validated_params}
  end

  defp invalidate_corporation_cache(corporation_id) do
    # Invalidate specific caches that might be affected by updates
    cache_keys = [
      {:corporation_basic, corporation_id},
      {:corporation_stats, corporation_id}
    ]

    Enum.each(cache_keys, &CorporationCache.delete/1)
    :ok
  end

  defp broadcast_corporation_created(corporation) do
    CorporationUpdates.broadcast_corporation_created(corporation)
    :ok
  end

  defp broadcast_corporation_updated(corporation) do
    CorporationUpdates.broadcast_corporation_updated(corporation)
    :ok
  end
end
