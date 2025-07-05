defmodule EveDmv.IntelligenceEngine.Pipeline do
  @moduledoc """
  Core execution pipeline for Intelligence Engine analysis.

  Orchestrates the analysis workflow through stages:
  1. **Input Validation** - Validate entity ID and options
  2. **Cache Lookup** - Check for cached results
  3. **Data Gathering** - Collect base data for analysis
  4. **Plugin Execution** - Run selected plugins in optimal order
  5. **Result Aggregation** - Combine plugin results
  6. **Cache Storage** - Store results for future use
  7. **Telemetry** - Record performance metrics

  ## Pipeline Stages

  Each stage can be customized through configuration and options.
  The pipeline supports both serial and parallel execution modes
  depending on plugin dependencies and performance requirements.
  """

  require Logger
  alias EveDmv.IntelligenceEngine.{PluginRegistry, CacheManager, MetricsCollector, Config}
  alias EveDmv.Database.{KillmailRepository, CharacterRepository}

  @type pipeline_context :: %{
          domain: atom(),
          entity_id: integer(),
          entity_ids: [integer()],
          opts: keyword(),
          plugins: [atom()],
          scope: atom(),
          cache_manager: term(),
          metrics_collector: term(),
          started_at: integer()
        }

  @type pipeline_result :: {:ok, map()} | {:error, term()}

  @doc """
  Execute analysis pipeline for a single entity.
  """
  @spec execute(atom(), integer(), keyword(), map()) :: pipeline_result()
  def execute(domain, entity_id, opts, state) do
    context = %{
      domain: domain,
      entity_id: entity_id,
      entity_ids: [entity_id],
      opts: opts,
      plugins: get_plugins_for_scope(domain, opts),
      scope: Keyword.get(opts, :scope, :standard),
      cache_manager: state.cache_manager,
      metrics_collector: state.metrics_collector,
      plugin_registry: state.plugin_registry,
      started_at: System.monotonic_time()
    }

    Logger.debug("Starting intelligence analysis",
      domain: domain,
      entity_id: entity_id,
      plugins: context.plugins
    )

    with {:ok, context} <- validate_input(context),
         {:ok, context, cached_result} <- check_cache(context),
         {:ok, context} <- gather_base_data(context),
         {:ok, context} <- execute_plugins(context),
         {:ok, result} <- aggregate_results(context),
         :ok <- store_cache(context, result, cached_result) do
      record_success_metrics(context, result)
      {:ok, result}
    else
      {:error, reason} = error ->
        record_error_metrics(context, reason)

        Logger.warning("Intelligence analysis failed",
          domain: domain,
          entity_id: entity_id,
          reason: inspect(reason)
        )

        error
    end
  end

  @doc """
  Execute batch analysis pipeline for multiple entities.
  """
  @spec execute_batch(atom(), [integer()], keyword(), map()) :: {:ok, map()} | {:error, term()}
  def execute_batch(domain, entity_ids, opts, state) do
    context = %{
      domain: domain,
      entity_id: nil,
      entity_ids: entity_ids,
      opts: opts,
      plugins: get_plugins_for_scope(domain, opts),
      scope: Keyword.get(opts, :scope, :standard),
      cache_manager: state.cache_manager,
      metrics_collector: state.metrics_collector,
      plugin_registry: state.plugin_registry,
      started_at: System.monotonic_time()
    }

    Logger.debug("Starting batch intelligence analysis",
      domain: domain,
      entity_count: length(entity_ids),
      plugins: context.plugins
    )

    # For batch operations, we can optimize by running analyses in parallel
    parallel_enabled = Keyword.get(opts, :parallel, true)

    if parallel_enabled and length(entity_ids) > 1 do
      execute_batch_parallel(context)
    else
      execute_batch_serial(context)
    end
  end

  # Pipeline Stages

  defp validate_input(context) do
    cond do
      context.entity_id && not is_integer(context.entity_id) ->
        {:error, :invalid_entity_id}

      context.entity_ids && not is_list(context.entity_ids) ->
        {:error, :invalid_entity_ids}

      context.domain not in [:character, :corporation, :fleet, :threat] ->
        {:error, :invalid_domain}

      length(context.plugins) == 0 ->
        {:error, :no_plugins_available}

      true ->
        {:ok, context}
    end
  end

  defp check_cache(context) do
    if Keyword.get(context.opts, :bypass_cache, false) do
      {:ok, context, nil}
    else
      cache_key = build_cache_key(context)

      case CacheManager.get(context.cache_manager, cache_key) do
        {:ok, cached_result} ->
          Logger.debug("Cache hit for intelligence analysis",
            domain: context.domain,
            entity_id: context.entity_id
          )

          # Return cached result immediately
          {:ok, context, cached_result}

        :miss ->
          {:ok, context, nil}
      end
    end
  end

  defp gather_base_data(context) do
    case context.domain do
      :character ->
        gather_character_data(context)

      :corporation ->
        gather_corporation_data(context)

      :fleet ->
        gather_fleet_data(context)

      :threat ->
        gather_threat_data(context)
    end
  end

  defp gather_character_data(context) do
    entity_ids = if context.entity_id, do: [context.entity_id], else: context.entity_ids

    with {:ok, character_stats} <- CharacterRepository.batch_get_character_stats(entity_ids),
         {:ok, killmail_stats} <- get_character_killmail_stats(entity_ids, context.scope) do
      base_data = %{
        character_stats: index_by_character_id(character_stats),
        killmail_stats: killmail_stats,
        scope: context.scope
      }

      {:ok, Map.put(context, :base_data, base_data)}
    else
      {:error, reason} -> {:error, {:data_gathering_failed, reason}}
    end
  end

  defp gather_corporation_data(context) do
    entity_ids = if context.entity_id, do: [context.entity_id], else: context.entity_ids

    # For corporation analysis, we need member data and corporation stats
    base_data = %{
      corporation_ids: entity_ids,
      scope: context.scope
    }

    {:ok, Map.put(context, :base_data, base_data)}
  end

  defp gather_fleet_data(context) do
    # Fleet analysis base data gathering
    base_data = %{
      fleet_ids: context.entity_ids,
      scope: context.scope
    }

    {:ok, Map.put(context, :base_data, base_data)}
  end

  defp gather_threat_data(context) do
    # Threat analysis base data gathering
    base_data = %{
      threat_ids: context.entity_ids,
      scope: context.scope
    }

    {:ok, Map.put(context, :base_data, base_data)}
  end

  defp execute_plugins(context) do
    parallel_enabled = Keyword.get(context.opts, :parallel, true)

    if parallel_enabled and length(context.plugins) > 1 do
      execute_plugins_parallel(context)
    else
      execute_plugins_serial(context)
    end
  end

  defp execute_plugins_serial(context) do
    results =
      Enum.reduce_while(context.plugins, %{}, fn plugin_name, acc ->
        case execute_single_plugin(context, plugin_name) do
          {:ok, plugin_result} ->
            {:cont, Map.put(acc, plugin_name, plugin_result)}

          {:error, reason} ->
            Logger.warning("Plugin execution failed",
              plugin: plugin_name,
              reason: inspect(reason)
            )

            # Continue with other plugins, but mark this one as failed
            {:cont, Map.put(acc, plugin_name, {:error, reason})}
        end
      end)

    {:ok, Map.put(context, :plugin_results, results)}
  end

  defp execute_plugins_parallel(context) do
    tasks =
      Enum.map(context.plugins, fn plugin_name ->
        Task.async(fn ->
          {plugin_name, execute_single_plugin(context, plugin_name)}
        end)
      end)

    results =
      tasks
      |> Enum.map(&Task.await(&1, 30_000))
      |> Enum.into(%{}, fn {plugin_name, result} -> {plugin_name, result} end)

    {:ok, Map.put(context, :plugin_results, results)}
  end

  defp execute_single_plugin(context, plugin_name) do
    case PluginRegistry.get_plugin(context.plugin_registry, context.domain, plugin_name) do
      {:ok, plugin_module} ->
        plugin_start = System.monotonic_time()

        try do
          result =
            plugin_module.analyze(
              context.entity_id || context.entity_ids,
              context.base_data,
              context.opts
            )

          plugin_duration = System.monotonic_time() - plugin_start
          record_plugin_metrics(context, plugin_name, plugin_duration, result)

          result
        rescue
          exception ->
            plugin_duration = System.monotonic_time() - plugin_start
            record_plugin_metrics(context, plugin_name, plugin_duration, {:error, exception})
            {:error, {:plugin_exception, exception}}
        end

      {:error, :not_found} ->
        {:error, {:plugin_not_found, plugin_name}}
    end
  end

  defp aggregate_results(context) do
    # Combine plugin results into a unified intelligence report
    successful_results =
      context.plugin_results
      |> Enum.filter(fn {_plugin, result} ->
        match?({:ok, _}, result)
      end)
      |> Enum.into(%{}, fn {plugin, {:ok, result}} ->
        {plugin, result}
      end)

    failed_plugins =
      context.plugin_results
      |> Enum.filter(fn {_plugin, result} ->
        match?({:error, _}, result)
      end)
      |> Enum.map(fn {plugin, _} -> plugin end)

    aggregated_result = %{
      domain: context.domain,
      entity_id: context.entity_id,
      entity_ids: context.entity_ids,
      scope: context.scope,
      analysis: successful_results,
      metadata: %{
        plugins_executed: Map.keys(context.plugin_results),
        plugins_successful: Map.keys(successful_results),
        plugins_failed: failed_plugins,
        analysis_duration_ms: System.monotonic_time() - context.started_at,
        generated_at: DateTime.utc_now()
      }
    }

    {:ok, aggregated_result}
  end

  defp store_cache(context, result, cached_result) do
    # Only store if we didn't get a cached result
    if cached_result do
      :ok
    else
      cache_key = build_cache_key(context)
      cache_ttl = get_cache_ttl(context)

      CacheManager.put(context.cache_manager, cache_key, result, cache_ttl)
    end
  end

  # Batch execution helpers

  defp execute_batch_parallel(context) do
    tasks =
      Enum.map(context.entity_ids, fn entity_id ->
        Task.async(fn ->
          single_context = %{context | entity_id: entity_id, entity_ids: [entity_id]}
          {entity_id, execute_single_entity(single_context)}
        end)
      end)

    results =
      tasks
      |> Enum.map(&Task.await(&1, 60_000))
      |> Enum.into(%{}, fn {entity_id, result} -> {entity_id, result} end)

    {:ok, results}
  end

  defp execute_batch_serial(context) do
    results =
      Enum.reduce(context.entity_ids, %{}, fn entity_id, acc ->
        single_context = %{context | entity_id: entity_id, entity_ids: [entity_id]}

        case execute_single_entity(single_context) do
          {:ok, result} -> Map.put(acc, entity_id, result)
          {:error, reason} -> Map.put(acc, entity_id, {:error, reason})
        end
      end)

    {:ok, results}
  end

  defp execute_single_entity(context) do
    with {:ok, context} <- gather_base_data(context),
         {:ok, context} <- execute_plugins(context),
         {:ok, result} <- aggregate_results(context) do
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Helper functions

  defp get_plugins_for_scope(domain, opts) do
    case Keyword.get(opts, :plugins) do
      nil -> Config.get_default_plugins(domain, Keyword.get(opts, :scope, :standard))
      plugins when is_list(plugins) -> plugins
    end
  end

  defp get_character_killmail_stats(character_ids, scope) do
    days_back =
      case scope do
        :basic -> 30
        :standard -> 90
        :full -> 365
      end

    # Get basic killmail statistics for each character
    stats =
      Enum.map(character_ids, fn character_id ->
        case KillmailRepository.get_kill_stats(character_id: character_id, days_back: days_back) do
          {:ok, stats} -> {character_id, stats}
          {:error, _} -> {character_id, %{}}
        end
      end)
      |> Enum.into(%{})

    {:ok, stats}
  end

  defp index_by_character_id(character_stats) do
    Enum.into(character_stats, %{}, fn stats ->
      {stats.character_id, stats}
    end)
  end

  defp build_cache_key(context) do
    entity_key =
      if context.entity_id do
        "#{context.entity_id}"
      else
        context.entity_ids |> Enum.sort() |> Enum.join(",")
      end

    plugins_key = context.plugins |> Enum.sort() |> Enum.join(",")

    "intelligence:#{context.domain}:#{entity_key}:#{context.scope}:#{plugins_key}"
  end

  defp get_cache_ttl(context) do
    case context.scope do
      # 5 minutes
      :basic -> 300_000
      # 10 minutes  
      :standard -> 600_000
      # 30 minutes
      :full -> 1_800_000
    end
  end

  # Metrics recording

  defp record_success_metrics(context, result) do
    duration_ms = System.monotonic_time() - context.started_at

    MetricsCollector.record_analysis(
      context.metrics_collector,
      context.domain,
      duration_ms,
      {:ok, result}
    )
  end

  defp record_error_metrics(context, reason) do
    duration_ms = System.monotonic_time() - context.started_at

    MetricsCollector.record_analysis(
      context.metrics_collector,
      context.domain,
      duration_ms,
      {:error, reason}
    )
  end

  defp record_plugin_metrics(context, plugin_name, duration_ms, result) do
    MetricsCollector.record_plugin_execution(
      context.metrics_collector,
      context.domain,
      plugin_name,
      duration_ms,
      result
    )
  end
end
