defmodule EveDmv.IntelligenceEngine.Config do
  @moduledoc """
  Configuration management for the Intelligence Engine legacy compatibility layer.

  Provides configuration for the bounded context system while maintaining
  the old IntelligenceEngine.Config API.
  """

  @default_config %{
    analysis: %{
      timeout_base_ms: 5_000,
      timeout_per_entity_ms: 100,
      max_concurrent_analyses: 10,
      default_scope: :standard,
      default_timeout_ms: 5_000
    },
    cache: %{
      basic_ttl_seconds: 300,
      standard_ttl_seconds: 600,
      full_ttl_seconds: 1800,
      default_ttl_ms: 300_000
    },
    plugins: %{
      character: %{
        basic: [:combat_stats, :activity_summary],
        standard: [:combat_stats, :activity_summary, :ship_preferences, :behavioral_patterns],
        full: [
          :combat_stats,
          :activity_summary,
          :ship_preferences,
          :behavioral_patterns,
          :threat_assessment,
          :wormhole_vetting
        ]
      },
      corporation: %{
        basic: [:member_activity, :fleet_composition],
        standard: [:member_activity, :fleet_composition, :recruitment_analysis],
        full: [:member_activity, :fleet_composition, :recruitment_analysis, :security_assessment]
      }
    },
    performance: %{
      enable_metrics: true,
      metrics_interval_ms: 30_000,
      max_concurrent_analyses: 50,
      timeout_multiplier: 1.5,
      max_batch_size: 100,
      slow_analysis_threshold_ms: 5_000,
      memory_limit_mb: 512
    }
  }

  def load do
    @default_config
  end

  def get_default_plugins(domain, scope)
      when domain in [:character, :corporation] and scope in [:basic, :standard, :full] do
    get_in(@default_config, [:plugins, domain, scope]) || []
  end

  def get_analysis_timeout(_scope, entity_count \\ 1) do
    base_timeout = @default_config.analysis.timeout_base_ms
    per_entity_timeout = @default_config.analysis.timeout_per_entity_ms
    base_timeout + per_entity_timeout * entity_count
  end

  def get_cache_ttl(scope) when scope in [:basic, :standard, :full] do
    case scope do
      :basic -> @default_config.cache.basic_ttl_seconds
      :standard -> @default_config.cache.standard_ttl_seconds
      :full -> @default_config.cache.full_ttl_seconds
    end
  end

  def get_max_concurrent_analyses do
    @default_config.analysis.max_concurrent_analyses
  end

  def get_performance_limits do
    @default_config.performance
  end

  def metrics_enabled? do
    @default_config.performance.enable_metrics
  end

  def get_metrics_interval do
    @default_config.performance.metrics_interval_ms
  end

  def plugin_enabled?(domain, plugin_name) when domain in [:character, :corporation] do
    case domain do
      :character ->
        all_character_plugins = get_all_plugins_for_domain(:character)
        plugin_name in all_character_plugins

      :corporation ->
        all_corporation_plugins = get_all_plugins_for_domain(:corporation)
        plugin_name in all_corporation_plugins
    end
  end

  def plugin_enabled?(_, _), do: false

  defp get_all_plugins_for_domain(domain) do
    basic_plugins = get_in(@default_config, [:plugins, domain, :basic]) || []
    standard_plugins = get_in(@default_config, [:plugins, domain, :standard]) || []
    full_plugins = get_in(@default_config, [:plugins, domain, :full]) || []

    Enum.uniq(basic_plugins ++ standard_plugins ++ full_plugins)
  end

  def validate_config(config) when is_map(config) do
    validations = [
      {:analysis, &validate_analysis_config/1},
      {:cache, &validate_cache_config/1},
      {:plugins, &validate_plugins_config/1},
      {:performance, &validate_performance_config/1}
    ]

    validation_errors =
      Enum.reduce(validations, [], fn {key, validator}, acc ->
        config_section = Map.get(config, key, %{})

        case validator.(config_section) do
          :ok -> acc
          {:error, reason} -> [reason | acc]
        end
      end)

    case validation_errors do
      [] -> {:ok, config}
      errors -> {:error, Enum.reverse(errors)}
    end
  end

  def validate_config(_invalid_config) do
    {:error, [:invalid_config_format]}
  end

  defp validate_analysis_config(analysis) do
    cond do
      Map.get(analysis, :default_timeout_ms, 1) < 0 -> {:error, :negative_timeout}
      Map.get(analysis, :timeout_base_ms, 1) < 0 -> {:error, :negative_base_timeout}
      Map.get(analysis, :max_concurrent_analyses, 1) < 1 -> {:error, :invalid_concurrent_limit}
      true -> :ok
    end
  end

  defp validate_cache_config(cache) do
    case Map.get(cache, :scope_ttl) do
      %{basic: ttl} when ttl <= 0 -> {:error, :invalid_cache_ttl}
      _ -> :ok
    end
  end

  defp validate_plugins_config(plugins) when is_map(plugins), do: :ok
  defp validate_plugins_config(_), do: {:error, :invalid_plugins_config}

  defp validate_performance_config(performance) when is_map(performance), do: :ok
  defp validate_performance_config(_), do: {:error, :invalid_performance_config}
end
