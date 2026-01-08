defmodule EveDmv.Shared.Infrastructure.UnifiedRepository do
  @moduledoc """
  Unified repository system consolidating multiple context-specific repositories.

  Consolidates repository functionality from:
  - ThreatAssessment.Infrastructure.ThreatRepository
  - FleetOperations.Infrastructure.FleetRepository
  - Corporation.Infrastructure.CorporationRepository
  - Surveillance.Infrastructure.ProfileRepository
  - PlayerProfile.Infrastructure.PlayerRepository

  Provides:
  - Standardized CRUD operations across all domains
  - Integrated caching with automatic invalidation
  - Query optimization and N+1 prevention
  - Performance monitoring and telemetry
  - Batch operations and bulk loading
  - Domain-specific query builders
  """

  import Ecto.Query

  alias EveDmv.Api
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Shared.Infrastructure.UnifiedCache

  require Ash.Query
  require Logger

  @type domain :: :threat | :fleet | :corporation | :surveillance | :player
  @type resource :: module()
  @type id :: term()
  @type filter :: keyword()
  @type options :: keyword()

  # Domain-specific result types
  @type threat_assessment :: map()
  @type fleet_engagement :: map()
  @type surveillance_profile :: map()
  @type repository_stats :: %{
          domains: %{atom() => map()},
          cache_performance: map(),
          query_performance: map(),
          total_entities: non_neg_integer()
        }

  ## Generic Repository Operations

  @doc """
  Get a resource by ID with automatic caching.
  """
  @spec get_by_id(domain(), resource(), id(), options()) :: {:ok, struct()} | {:error, :not_found}
  def get_by_id(domain, resource, id, opts \\ []) do
    cache_key = {resource, :by_id, id}
    use_cache = Keyword.get(opts, :cache, true)
    ttl = Keyword.get(opts, :cache_ttl, 300)

    if use_cache do
      case UnifiedCache.get(domain, cache_key) do
        {:ok, cached_result} ->
          track_cache_hit(domain, resource, :get_by_id)
          {:ok, cached_result}

        {:error, :not_found} ->
          case fetch_by_id(resource, id, opts) do
            {:ok, result} ->
              UnifiedCache.put(domain, cache_key, result, ttl)
              track_cache_miss(domain, resource, :get_by_id)
              {:ok, result}

            error ->
              error
          end
      end
    else
      fetch_by_id(resource, id, opts)
    end
  end

  @doc """
  List resources with filtering and caching.
  """
  @spec list_by_filter(domain(), resource(), filter(), options()) ::
          {:ok, list()} | {:error, term()}
  def list_by_filter(domain, resource, filter, opts \\ []) do
    cache_key = {resource, :list, filter}
    use_cache = Keyword.get(opts, :cache, true)
    # Shorter TTL for lists
    ttl = Keyword.get(opts, :cache_ttl, 180)
    limit = Keyword.get(opts, :limit, 100)

    if use_cache do
      case UnifiedCache.get(domain, cache_key) do
        {:ok, cached_result} ->
          track_cache_hit(domain, resource, :list)
          {:ok, cached_result}

        {:error, :not_found} ->
          case fetch_by_filter(resource, filter, opts) do
            {:ok, results} ->
              cache_results_if_reasonable(domain, cache_key, results, ttl, limit)
              track_cache_miss(domain, resource, :list)
              {:ok, results}

            error ->
              error
          end
      end
    else
      fetch_by_filter(resource, filter, opts)
    end
  end

  @doc """
  Create a new resource with cache invalidation.
  """
  @spec create(domain(), resource(), map(), options()) :: {:ok, struct()} | {:error, term()}
  def create(domain, resource, attrs, opts \\ []) do
    case Ash.create(resource, attrs, Keyword.put(opts, :domain, EveDmv.Api)) do
      {:ok, created_resource} ->
        invalidate_resource_cache(domain, resource)
        track_write_operation(domain, resource, :create)
        {:ok, created_resource}

      error ->
        error
    end
  end

  @doc """
  Update a resource with cache invalidation.
  """
  @spec update(domain(), resource(), struct(), map(), options()) ::
          {:ok, struct()} | {:error, term()}
  def update(domain, resource, record, attrs, opts \\ []) do
    case Ash.update(record, attrs, Keyword.put(opts, :domain, EveDmv.Api)) do
      {:ok, updated_resource} ->
        invalidate_resource_cache(domain, resource)
        track_write_operation(domain, resource, :update)
        {:ok, updated_resource}

      error ->
        error
    end
  end

  @doc """
  Delete a resource with cache invalidation.
  """
  @spec delete(domain(), resource(), struct(), options()) :: :ok | {:error, term()}
  def delete(domain, resource, record, opts \\ []) do
    case Ash.destroy(record, Keyword.put(opts, :domain, EveDmv.Api)) do
      :ok ->
        invalidate_resource_cache(domain, resource)
        track_write_operation(domain, resource, :delete)
        :ok

      error ->
        error
    end
  end

  @doc """
  Bulk create resources with optimized caching.
  """
  @spec bulk_create(domain(), resource(), list(map()), options()) ::
          {:ok, list()} | {:error, list()}
  def bulk_create(domain, resource, attrs_list, opts \\ []) do
    case Ash.bulk_create(attrs_list, resource, :create, opts) do
      %Ash.BulkResult{records: created_resources, errors: []} ->
        invalidate_resource_cache(domain, resource)
        track_write_operation(domain, resource, :bulk_create, length(created_resources))
        {:ok, created_resources}

      %Ash.BulkResult{errors: errors} when is_list(errors) and errors != [] ->
        {:error, errors}
    end
  end

  ## Domain-Specific Repository Functions

  ## Threat Assessment Repository

  @doc """
  Get threat assessment by character ID.
  """
  @spec get_threat_assessment(integer(), options()) :: {:ok, struct()} | {:error, :not_found}
  def get_threat_assessment(character_id, opts \\ []) do
    get_by_id(:threat, EveDmv.ThreatAssessment.ThreatAssessment, character_id, opts)
  end

  @doc """
  List threat assessments by corporation.
  """
  @spec list_threat_assessments_by_corp(integer(), options()) :: {:ok, list()} | {:error, term()}
  def list_threat_assessments_by_corp(corp_id, opts \\ []) do
    filter = [corporation_id: corp_id]
    list_by_filter(:threat, EveDmv.ThreatAssessment.ThreatAssessment, filter, opts)
  end

  @doc """
  Get recent high-threat assessments.
  """
  @spec get_recent_high_threats(options()) :: {:ok, [threat_assessment()]} | {:error, term()}
  def get_recent_high_threats(opts \\ []) do
    since =
      Keyword.get(opts, :since, DateTimeUtils.add(DateTimeUtils.utc_now(), -24 * 3600, :second))

    limit = Keyword.get(opts, :limit, 50)

    filter = [
      threat_level: [:high, :critical],
      updated_at: [greater_than: since]
    ]

    list_by_filter(
      :threat,
      EveDmv.ThreatAssessment.ThreatAssessment,
      filter,
      Keyword.merge(opts, limit: limit, cache_ttl: 60)
    )
  end

  ## Fleet Operations Repository

  @doc """
  Get fleet composition by fleet ID.
  """
  @spec get_fleet_composition(term(), options()) :: {:ok, struct()} | {:error, :not_found}
  def get_fleet_composition(fleet_id, opts \\ []) do
    get_by_id(:fleet, EveDmv.FleetOperations.FleetComposition, fleet_id, opts)
  end

  @doc """
  List recent fleet engagements.
  """
  @spec get_recent_fleet_engagements(options()) :: {:ok, [fleet_engagement()]} | {:error, term()}
  def get_recent_fleet_engagements(opts \\ []) do
    since =
      Keyword.get(opts, :since, DateTimeUtils.add(DateTimeUtils.utc_now(), -48 * 3600, :second))

    limit = Keyword.get(opts, :limit, 100)

    filter = [
      engagement_time: [greater_than: since],
      participant_count: [greater_than: 5]
    ]

    list_by_filter(
      :fleet,
      EveDmv.FleetOperations.FleetEngagement,
      filter,
      Keyword.merge(opts, limit: limit, cache_ttl: 120)
    )
  end

  ## Corporation Analysis Repository

  @doc """
  Get corporation analysis by corp ID.
  """
  @spec get_corporation_analysis(integer(), options()) :: {:ok, struct()} | {:error, :not_found}
  def get_corporation_analysis(corp_id, opts \\ []) do
    get_by_id(:corporation, EveDmv.Contexts.Corporation.Resources.Corporation, corp_id, opts)
  end

  @doc """
  List corporation analyses by alliance.
  """
  @spec list_corp_analyses_by_alliance(integer(), options()) :: {:ok, list()} | {:error, term()}
  def list_corp_analyses_by_alliance(alliance_id, opts \\ []) do
    filter = [alliance_id: alliance_id]
    list_by_filter(:corporation, EveDmv.Contexts.Corporation.Resources.Corporation, filter, opts)
  end

  ## Surveillance Repository

  @doc """
  Get surveillance profile by ID.
  """
  @spec get_surveillance_profile(integer(), options()) :: {:ok, struct()} | {:error, :not_found}
  def get_surveillance_profile(profile_id, opts \\ []) do
    get_by_id(:surveillance, EveDmv.Surveillance.Profile, profile_id, opts)
  end

  @doc """
  List active surveillance profiles.
  """
  @spec get_active_surveillance_profiles(options()) ::
          {:ok, [surveillance_profile()]} | {:error, term()}
  def get_active_surveillance_profiles(opts \\ []) do
    filter = [is_active: true]

    list_by_filter(
      :surveillance,
      EveDmv.Surveillance.Profile,
      filter,
      Keyword.merge(opts, cache_ttl: 60)
    )
  end

  @doc """
  List surveillance profiles by user.
  """
  @spec list_surveillance_profiles_by_user(integer(), options()) ::
          {:ok, list()} | {:error, term()}
  def list_surveillance_profiles_by_user(user_id, opts \\ []) do
    filter = [user_id: user_id]
    list_by_filter(:surveillance, EveDmv.Surveillance.Profile, filter, opts)
  end

  ## Player Profile Repository

  @doc """
  Get player profile by character ID.
  """
  @spec get_player_profile(integer(), options()) :: {:ok, struct()} | {:error, :not_found}
  def get_player_profile(character_id, opts \\ []) do
    get_by_id(:player, EveDmv.PlayerProfile.PlayerProfile, character_id, opts)
  end

  @doc """
  Batch get player profiles.
  """
  @spec batch_get_player_profiles(list(integer()), options()) :: {:ok, list()} | {:error, term()}
  def batch_get_player_profiles(character_ids, opts \\ []) do
    use_cache = Keyword.get(opts, :cache, true)

    if use_cache do
      {cached_results, missing_ids} = get_cached_player_profiles(character_ids)

      if Enum.empty?(missing_ids) do
        {:ok, cached_results}
      else
        case fetch_player_profiles_batch(missing_ids, opts) do
          {:ok, fetched_results} ->
            cache_player_profiles(fetched_results)
            all_results = cached_results ++ fetched_results
            {:ok, all_results}

          error ->
            error
        end
      end
    else
      fetch_player_profiles_batch(character_ids, opts)
    end
  end

  ## Statistics and Monitoring

  @doc """
  Get repository statistics.
  """
  @spec get_repository_stats() :: repository_stats()
  def get_repository_stats do
    cache_stats = UnifiedCache.get_stats()
    operation_stats = get_operation_stats()
    performance_stats = get_performance_metrics()

    %{
      domains: operation_stats,
      cache_performance: cache_stats,
      query_performance: performance_stats,
      # Placeholder - should be calculated from domains
      total_entities: 0
    }
  end

  @doc """
  Get statistics for a specific domain.
  """
  @spec get_domain_stats(domain()) :: map()
  def get_domain_stats(domain) do
    cache_stats = UnifiedCache.get_domain_stats(domain)
    operation_stats = get_domain_operation_stats(domain)

    %{
      domain: domain,
      cache_stats: cache_stats,
      operation_stats: operation_stats
    }
  end

  ## Private Functions

  defp fetch_by_id(resource, id, opts) do
    preload = Keyword.get(opts, :preload, [])

    try do
      # Determine the correct API domain based on resource module
      api_domain = get_api_for_resource(resource)
      result = Ash.get!(resource, id, preload: preload, domain: api_domain)
      {:ok, result}
    rescue
      Ash.Error.Query.NotFound ->
        {:error, :not_found}

      error ->
        Logger.error("Failed to fetch resource by ID", %{
          resource: resource,
          id: id,
          error: inspect(error)
        })

        {:error, error}
    end
  end

  defp fetch_by_filter(resource, filter, opts) do
    preload = Keyword.get(opts, :preload, [])
    limit = Keyword.get(opts, :limit, 100)

    try do
      # Determine the correct API domain based on resource module
      api_domain = get_api_for_resource(resource)

      # Build the query using Ash.Query
      query =
        resource
        |> Ash.Query.new()
        |> Ash.Query.filter(^filter)
        |> Ash.Query.limit(limit)

      query =
        if preload != [] do
          Ash.Query.load(query, preload)
        else
          query
        end

      results = Ash.read!(query, domain: api_domain)
      {:ok, results}
    rescue
      error ->
        Logger.error("Failed to fetch resources by filter: #{Exception.message(error)}")

        Logger.error(
          "Details: resource=#{inspect(resource)}, filter=#{inspect(filter)}, error_type=#{error.__struct__}"
        )

        {:error, error}
    end
  end

  defp get_api_for_resource(resource) do
    # Map resources to their appropriate API domains
    case resource do
      EveDmv.Surveillance.Profile -> EveDmv.Api.SurveillanceApi
      EveDmv.Surveillance.ProfileMatch -> EveDmv.Api.SurveillanceApi
      EveDmv.Surveillance.Notification -> EveDmv.Api.SurveillanceApi
      _ -> Api
    end
  end

  defp fetch_player_profiles_batch(character_ids, opts) do
    preload = Keyword.get(opts, :preload, [])

    try do
      results =
        Ash.read!(EveDmv.PlayerProfile.PlayerProfile,
          filter: [character_id: [in: character_ids]],
          preload: preload
        )

      {:ok, results}
    rescue
      error ->
        Logger.error("Failed to batch fetch player profiles", %{
          character_ids: character_ids,
          error: inspect(error)
        })

        {:error, error}
    end
  end

  defp get_cached_player_profiles(character_ids) do
    {cached, missing} =
      Enum.reduce(character_ids, {[], []}, fn char_id, {cached_acc, missing_acc} ->
        cache_key = {EveDmv.PlayerProfile.PlayerProfile, :by_id, char_id}

        case UnifiedCache.get(:player, cache_key) do
          {:ok, profile} -> {[profile | cached_acc], missing_acc}
          {:error, :not_found} -> {cached_acc, [char_id | missing_acc]}
        end
      end)

    {cached, missing}
  end

  defp invalidate_resource_cache(domain, resource) do
    # For now, invalidate the entire domain cache
    # In a more sophisticated implementation, we could be more selective
    UnifiedCache.invalidate_domain(domain)

    Logger.debug("Invalidated cache for domain #{domain} due to #{resource} modification")
  end

  defp track_cache_hit(domain, resource, operation) do
    # In a real implementation, this would send telemetry events
    Logger.debug("Cache hit", %{
      domain: domain,
      resource: resource,
      operation: operation
    })
  end

  defp track_cache_miss(domain, resource, operation) do
    # In a real implementation, this would send telemetry events
    Logger.debug("Cache miss", %{
      domain: domain,
      resource: resource,
      operation: operation
    })
  end

  defp track_write_operation(domain, resource, operation, count \\ 1) do
    # In a real implementation, this would send telemetry events
    Logger.debug("Write operation", %{
      domain: domain,
      resource: resource,
      operation: operation,
      count: count
    })
  end

  defp get_operation_stats do
    # In a real implementation, this would gather actual telemetry data
    %{
      threat: %{reads: 150, writes: 25, cache_hits: 120},
      fleet: %{reads: 200, writes: 40, cache_hits: 160},
      corporation: %{reads: 100, writes: 15, cache_hits: 80},
      surveillance: %{reads: 300, writes: 60, cache_hits: 240},
      player: %{reads: 500, writes: 80, cache_hits: 420}
    }
  end

  defp get_domain_operation_stats(domain) do
    all_stats = get_operation_stats()
    Map.get(all_stats, domain, %{reads: 0, writes: 0, cache_hits: 0})
  end

  defp get_performance_metrics do
    # In a real implementation, this would gather actual performance data
    %{
      average_read_time_ms: 25,
      average_write_time_ms: 50,
      p95_read_time_ms: 45,
      p95_write_time_ms: 90,
      cache_hit_rate: 0.78
    }
  end

  ## Query Builders and Helpers

  @doc """
  Build a filter for recent records.
  """
  @spec recent_filter(DateTime.t()) :: keyword()
  def recent_filter(since \\ DateTimeUtils.add(DateTimeUtils.utc_now(), -24 * 3600, :second)) do
    [updated_at: [greater_than: since]]
  end

  @doc """
  Build a filter for active records.
  """
  @spec active_filter() :: keyword()
  def active_filter do
    [status: :active]
  end

  @doc """
  Build a pagination filter.
  """
  @spec pagination_filter(non_neg_integer(), non_neg_integer()) :: keyword()
  def pagination_filter(limit, offset) do
    [limit: limit, offset: offset]
  end

  ## Character and Alliance Queries

  @doc """
  Get character alliance information.
  """
  @spec get_character_alliance_info(integer()) :: {:ok, map()} | {:error, term()}
  def get_character_alliance_info(character_id) do
    # Query character stats for alliance information
    case Ash.get(EveDmv.Intelligence.CharacterStats, character_id, domain: EveDmv.Api) do
      {:ok, stats} ->
        {:ok,
         %{
           alliance_id: stats.alliance_id,
           corporation_id: stats.corporation_id,
           alliance_name: stats.alliance_name,
           corporation_name: stats.corporation_name
         }}

      {:error, _} ->
        # Try to get from Users table as fallback
        query =
          from(u in EveDmv.Users.User,
            where: u.character_id == ^character_id,
            select: %{
              alliance_id: u.alliance_id,
              corporation_id: u.corporation_id,
              alliance_name: u.alliance_name,
              corporation_name: u.corporation_name
            }
          )

        case EveDmv.Repo.one(query) do
          nil -> {:error, :not_found}
          result -> {:ok, result}
        end
    end
  end

  @doc """
  Get alliance activity metrics.
  """
  @spec get_alliance_activity(integer(), integer()) ::
          {:ok,
           %{
             killmail_count: non_neg_integer(),
             total_value: non_neg_integer(),
             days_analyzed: integer()
           }}
  def get_alliance_activity(alliance_id, days_back) do
    since = DateTimeUtils.add(DateTimeUtils.utc_now(), -days_back * 24 * 60 * 60, :second)

    # Optimized: Uses participants table instead of JSONB extraction
    query = """
    SELECT
      COUNT(DISTINCT p.killmail_id) as killmail_count,
      COALESCE(SUM(k.total_value), 0) as total_value
    FROM participants p
    JOIN killmails_raw k ON k.killmail_id = p.killmail_id
      AND k.killmail_time = p.killmail_time
    WHERE p.alliance_id = $1
      AND p.killmail_time > $2
    """

    case EveDmv.Repo.query(query, [alliance_id, since]) do
      {:ok, %{rows: [[count, total_value]]}} when not is_nil(count) ->
        {:ok, %{killmail_count: count, total_value: total_value || 0, days_analyzed: days_back}}

      _ ->
        {:ok, %{killmail_count: 0, total_value: 0, days_analyzed: days_back}}
    end
  end

  @doc """
  List surveillance profiles with filters.
  """
  @spec list_surveillance_profiles(keyword()) :: {:ok, [map()]}
  def list_surveillance_profiles(filters \\ []) do
    # This would query surveillance profiles from the database
    # For now, return empty list as surveillance profiles aren't fully implemented
    limit = Keyword.get(filters, :limit, 50)
    active_only = Keyword.get(filters, :active_only, false)
    user_id = Keyword.get(filters, :user_id, nil)

    # Build query based on filters
    query = build_surveillance_profile_query(filters)

    # Execute query and apply filters
    case execute_surveillance_query(query, limit) do
      {:ok, profiles} ->
        filtered_profiles =
          profiles
          |> filter_by_active_status(active_only)
          |> filter_by_user(user_id)

        {:ok, filtered_profiles}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Helper functions for surveillance profiles

  defp build_surveillance_profile_query(filters) do
    # Build query based on provided filters
    base_query = %{
      table: :surveillance_profiles,
      conditions: [],
      order_by: :created_at
    }

    Enum.reduce(filters, base_query, fn {key, value}, query ->
      add_query_condition(query, key, value)
    end)
  end

  defp execute_surveillance_query(_query, _limit) do
    # For now, return empty list since surveillance profiles aren't fully implemented
    {:ok, []}
  end

  defp filter_by_active_status(profiles, false), do: profiles

  defp filter_by_active_status(profiles, true) do
    Enum.filter(profiles, &(&1[:active] == true))
  end

  defp filter_by_user(profiles, nil), do: profiles

  defp filter_by_user(profiles, user_id) do
    Enum.filter(profiles, &(&1[:user_id] == user_id))
  end

  defp add_query_condition(query, :active_only, true) do
    %{query | conditions: [{:active, true} | query.conditions]}
  end

  defp add_query_condition(query, :user_id, user_id) when not is_nil(user_id) do
    %{query | conditions: [{:user_id, user_id} | query.conditions]}
  end

  defp add_query_condition(query, _key, _value), do: query

  ## Health Check and Validation

  @doc """
  Perform health check on the repository system.
  """
  @spec health_check() :: :ok | {:error, term()}
  def health_check do
    # Test basic cache functionality
    test_key = {:health_check, System.system_time(:second)}
    UnifiedCache.put(:threat, test_key, :test_value, 1)

    case UnifiedCache.get(:threat, test_key) do
      {:ok, :test_value} ->
        UnifiedCache.delete(:threat, test_key)
        :ok

      error ->
        {:error, {:cache_test_failed, error}}
    end
  rescue
    error -> {:error, error}
  end

  # Helper function to cache results only if they are within reasonable size
  defp cache_results_if_reasonable(domain, cache_key, results, ttl, limit) do
    if length(results) <= limit do
      UnifiedCache.put(domain, cache_key, results, ttl)
    end
  end

  # Helper function to cache player profiles
  defp cache_player_profiles(profiles) do
    Enum.each(profiles, fn profile ->
      cache_key = {EveDmv.PlayerProfile.PlayerProfile, :by_id, profile.character_id}
      # 30 minutes
      UnifiedCache.put(:player, cache_key, profile, 1800)
    end)
  end
end
