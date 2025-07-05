defmodule EveDmv.Database.Repository do
  @moduledoc """
  Base repository pattern for consistent database access across EVE DMV.

  Provides standardized query patterns, caching integration, performance monitoring,
  and N+1 query prevention for all domain resources.

  ## Usage

      defmodule EveDmv.Database.KillmailRepository do
        use EveDmv.Database.Repository, 
          resource: EveDmv.Killmails.KillmailEnriched,
          cache_type: :hot_data
      end
      
      # Query with automatic caching and monitoring
      KillmailRepository.get_by_id(123456)
      KillmailRepository.list_by_corporation(corp_id, preload: [:participants])
      KillmailRepository.get_recent_killmails(limit: 100)

  ## Features

  - **Standardized interfaces**: Consistent query methods across all repositories
  - **Automatic caching**: Configurable cache integration with TTL management  
  - **Performance monitoring**: Built-in telemetry for query tracking
  - **N+1 prevention**: Optimized preloading and batch operations
  - **Query composition**: Composable filters and query building
  """

  defmacro __using__(opts) do
    resource = Keyword.fetch!(opts, :resource)
    cache_type = Keyword.get(opts, :cache_type, :api_responses)

    quote bind_quoted: [resource: resource, cache_type: cache_type] do
      require Logger
      require Ash.Query

      alias EveDmv.Api
      alias EveDmv.Cache
      alias EveDmv.Database.Repository.{QueryBuilder, CacheHelper, TelemetryHelper}

      @resource resource
      @cache_type cache_type
      @resource_name resource |> Module.split() |> List.last() |> Macro.underscore()

      # Standard CRUD operations

      @doc """
      Get a single record by ID with optional preloading and caching.

      ## Options

      - `:preload` - List of associations to preload
      - `:cache_ttl` - Override default cache TTL (in milliseconds)
      - `:bypass_cache` - Skip cache lookup and force database query

      ## Examples

          get_by_id(123)
          get_by_id(123, preload: [:association])
          get_by_id(123, cache_ttl: 60_000, bypass_cache: true)
      """
      @spec get_by_id(integer(), keyword()) :: {:ok, struct()} | {:error, term()}
      def get_by_id(id, opts \\ []) do
        cache_key = CacheHelper.build_key(@resource_name, "id", id, opts)

        case should_use_cache?(opts) do
          true ->
            Cache.get_or_compute(
              @cache_type,
              cache_key,
              fn ->
                execute_get_by_id(id, opts)
              end,
              opts
            )

          false ->
            execute_get_by_id(id, opts)
        end
      end

      @doc """
      List records with filtering, pagination, and preloading.

      ## Options

      - `:filters` - Map of field filters to apply
      - `:preload` - List of associations to preload  
      - `:limit` - Maximum number of records to return
      - `:offset` - Number of records to skip
      - `:order_by` - Field or list of fields to order by
      - `:cache_ttl` - Cache TTL for results

      ## Examples

          list()
          list(limit: 50, order_by: [:inserted_at])
          list(filters: %{status: "active"}, preload: [:user])
      """
      @spec list(keyword()) :: {:ok, [struct()]} | {:error, term()}
      def list(opts \\ []) do
        TelemetryHelper.measure_query(@resource_name, :list, fn ->
          query = build_list_query(opts)
          Ash.read(query, domain: Api)
        end)
      end

      @doc """
      Count records matching the given filters.

      ## Options

      - `:filters` - Map of field filters to apply
      - `:cache_ttl` - Cache TTL for count result

      ## Examples

          count()
          count(filters: %{status: "active"})
      """
      @spec count(keyword()) :: {:ok, integer()} | {:error, term()}
      def count(opts \\ []) do
        cache_key = CacheHelper.build_key(@resource_name, "count", opts)

        Cache.get_or_compute(
          @cache_type,
          cache_key,
          fn ->
            TelemetryHelper.measure_query(@resource_name, :count, fn ->
              query = build_count_query(opts)

              case Ash.count(query, domain: Api) do
                {:ok, count} -> {:ok, count}
                {:error, reason} -> {:error, reason}
              end
            end)
          end,
          opts
        )
      end

      @doc """
      Create a new record with the given attributes.

      ## Examples

          create(%{name: "Test", status: "active"})
      """
      @spec create(map()) :: {:ok, struct()} | {:error, term()}
      def create(attrs) do
        TelemetryHelper.measure_query(@resource_name, :create, fn ->
          case Ash.create(@resource, attrs, domain: Api) do
            {:ok, record} ->
              # Invalidate relevant caches
              CacheHelper.invalidate_for_resource(@cache_type, @resource_name)
              {:ok, record}

            {:error, reason} ->
              {:error, reason}
          end
        end)
      end

      @doc """
      Update an existing record with the given attributes.

      ## Examples

          update(record, %{status: "inactive"})
      """
      @spec update(struct(), map()) :: {:ok, struct()} | {:error, term()}
      def update(record, attrs) do
        TelemetryHelper.measure_query(@resource_name, :update, fn ->
          case Ash.update(record, attrs, domain: Api) do
            {:ok, updated_record} ->
              # Invalidate relevant caches
              CacheHelper.invalidate_for_record(@cache_type, @resource_name, record)
              {:ok, updated_record}

            {:error, reason} ->
              {:error, reason}
          end
        end)
      end

      @doc """
      Delete a record.

      ## Examples

          delete(record)
      """
      @spec delete(struct()) :: {:ok, struct()} | {:error, term()}
      def delete(record) do
        TelemetryHelper.measure_query(@resource_name, :delete, fn ->
          case Ash.destroy(record, domain: Api) do
            :ok ->
              # Invalidate relevant caches
              CacheHelper.invalidate_for_record(@cache_type, @resource_name, record)
              {:ok, record}

            {:error, reason} ->
              {:error, reason}
          end
        end)
      end

      # Batch operations for performance

      @doc """
      Batch load multiple records by IDs with optimized preloading.

      Prevents N+1 queries by loading all records and associations in minimal queries.

      ## Examples

          batch_get_by_ids([1, 2, 3])
          batch_get_by_ids([1, 2, 3], preload: [:association])
      """
      @spec batch_get_by_ids([integer()], keyword()) :: {:ok, [struct()]} | {:error, term()}
      def batch_get_by_ids(ids, opts \\ []) when is_list(ids) do
        TelemetryHelper.measure_query(@resource_name, :batch_get, fn ->
          query = build_batch_query(ids, opts)
          Ash.read(query, domain: Api)
        end)
      end

      @doc """
      Bulk create multiple records in a single operation.

      ## Examples

          bulk_create([%{name: "A"}, %{name: "B"}])
      """
      @spec bulk_create([map()]) :: {:ok, [struct()]} | {:error, term()}
      def bulk_create(records_attrs) when is_list(records_attrs) do
        TelemetryHelper.measure_query(@resource_name, :bulk_create, fn ->
          case Ash.bulk_create(@resource, records_attrs, domain: Api) do
            %{records: records} ->
              # Invalidate relevant caches
              CacheHelper.invalidate_for_resource(@cache_type, @resource_name)
              {:ok, records}

            %{errors: errors} ->
              {:error, errors}
          end
        end)
      end

      # Query building helpers

      defp execute_get_by_id(id, opts) do
        TelemetryHelper.measure_query(@resource_name, :get, fn ->
          query = QueryBuilder.build_get_query(@resource, id, opts)

          case Ash.read_one(query, domain: Api) do
            {:ok, nil} -> {:error, :not_found}
            {:ok, record} -> {:ok, record}
            {:error, reason} -> {:error, reason}
          end
        end)
      end

      defp build_list_query(opts) do
        QueryBuilder.build_list_query(@resource, opts)
      end

      defp build_count_query(opts) do
        QueryBuilder.build_count_query(@resource, opts)
      end

      defp build_batch_query(ids, opts) do
        QueryBuilder.build_batch_query(@resource, ids, opts)
      end

      defp should_use_cache?(opts) do
        not Keyword.get(opts, :bypass_cache, false)
      end

      # Allow repositories to define custom methods
      defoverridable get_by_id: 2,
                     list: 1,
                     count: 1,
                     create: 1,
                     update: 2,
                     delete: 1,
                     batch_get_by_ids: 2,
                     bulk_create: 1
    end
  end
end
