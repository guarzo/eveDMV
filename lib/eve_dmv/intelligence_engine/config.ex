defmodule EveDmv.IntelligenceEngine.Config do
  @moduledoc """
  Configuration management for the Intelligence Engine.

  Centralizes configuration for plugins, analysis scopes, caching behavior,
  and performance tuning. Supports environment-specific configuration
  and runtime configuration updates.
  """

  @type domain :: :character | :corporation | :fleet | :threat
  @type scope :: :basic | :standard | :full
  @type plugin_name :: atom()

  @doc """
  Load Intelligence Engine configuration.
  """
  @spec load() :: map()
  def load do
    %{
      # Analysis configuration
      analysis: %{
        default_scope: :standard,
        default_timeout_ms: 30_000,
        max_batch_size: 50,
        enable_parallel: true
      },

      # Caching configuration
      cache: %{
        # 10 minutes
        default_ttl_ms: 600_000,
        scope_ttl: %{
          # 5 minutes
          basic: 300_000,
          # 10 minutes
          standard: 600_000,
          # 30 minutes
          full: 1_800_000
        },
        enable_cache_warming: false
      },

      # Plugin configuration
      plugins: load_plugin_config(),

      # Performance configuration
      performance: %{
        slow_analysis_threshold_ms: 5_000,
        slow_plugin_threshold_ms: 1_000,
        max_concurrent_analyses: 10,
        enable_metrics: true
      },

      # Environment-specific overrides
      environment: load_environment_config()
    }
  end

  @doc """
  Get default plugins for a domain and scope.
  """
  @spec get_default_plugins(domain(), scope()) :: [plugin_name()]
  def get_default_plugins(domain, scope) do
    case {domain, scope} do
      # Character analysis plugins
      {:character, :basic} ->
        [:combat_stats]

      {:character, :standard} ->
        [:combat_stats, :behavioral_patterns, :ship_preferences]

      {:character, :full} ->
        [
          :combat_stats,
          :behavioral_patterns,
          :ship_preferences,
          :threat_assessment,
          :alliance_activity
        ]

      # Corporation analysis plugins
      {:corporation, :basic} ->
        [:member_activity]

      {:corporation, :standard} ->
        [:member_activity, :fleet_readiness]

      {:corporation, :full} ->
        [
          :member_activity,
          :fleet_readiness,
          :doctrine_compliance,
          :security_assessment,
          :timezone_coverage
        ]

      # Fleet analysis plugins
      {:fleet, :basic} ->
        [:composition_analysis]

      {:fleet, :standard} ->
        [:composition_analysis, :effectiveness_rating]

      {:fleet, :full} ->
        [
          :composition_analysis,
          :effectiveness_rating,
          :tactical_assessment,
          :doctrine_optimization
        ]

      # Threat analysis plugins
      {:threat, :basic} ->
        [:vulnerability_scan]

      {:threat, :standard} ->
        [:vulnerability_scan, :risk_assessment]

      {:threat, :full} ->
        [:vulnerability_scan, :risk_assessment, :attack_vector_analysis, :threat_correlation]

      # Default fallback
      _ ->
        []
    end
  end

  @doc """
  Get configuration value by path.
  """
  @spec get(map(), [atom()], term()) :: term()
  def get(config, path, default \\ nil) do
    get_in(config, path) || default
  end

  @doc """
  Update configuration value by path.
  """
  @spec update(map(), [atom()], term()) :: map()
  def update(config, path, value) do
    put_in(config, path, value)
  end

  @doc """
  Get cache TTL for a specific scope.
  """
  @spec get_cache_ttl(scope()) :: integer()
  def get_cache_ttl(scope) do
    ttl_config = %{
      # 5 minutes
      basic: 300_000,
      # 10 minutes
      standard: 600_000,
      # 30 minutes
      full: 1_800_000
    }

    Map.get(ttl_config, scope, 600_000)
  end

  @doc """
  Get timeout for analysis operations.
  """
  @spec get_analysis_timeout(scope(), integer()) :: integer()
  def get_analysis_timeout(scope, entity_count \\ 1) do
    base_timeout =
      case scope do
        # 10 seconds
        :basic -> 10_000
        # 30 seconds
        :standard -> 30_000
        # 60 seconds
        :full -> 60_000
      end

    # Scale timeout based on entity count for batch operations
    base_timeout * max(1, div(entity_count, 10) + 1)
  end

  @doc """
  Check if a plugin is enabled for a domain.
  """
  @spec plugin_enabled?(domain(), plugin_name()) :: boolean()
  def plugin_enabled?(domain, plugin_name) do
    # Check environment configuration for plugin overrides
    case System.get_env("INTELLIGENCE_DISABLED_PLUGINS") do
      nil ->
        true

      disabled_list ->
        disabled_plugins =
          disabled_list
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.map(&String.to_atom/1)

        plugin_name not in disabled_plugins
    end
  end

  @doc """
  Get performance limits configuration.
  """
  @spec get_performance_limits() :: map()
  def get_performance_limits do
    %{
      max_concurrent_analyses: get_env_int("INTELLIGENCE_MAX_CONCURRENT", 10),
      max_batch_size: get_env_int("INTELLIGENCE_MAX_BATCH_SIZE", 50),
      slow_analysis_threshold_ms: get_env_int("INTELLIGENCE_SLOW_THRESHOLD_MS", 5_000),
      memory_limit_mb: get_env_int("INTELLIGENCE_MEMORY_LIMIT_MB", 1_000)
    }
  end

  @doc """
  Validate configuration structure.
  """
  @spec validate_config(map()) :: {:ok, map()} | {:error, [String.t()]}
  def validate_config(config) do
    errors = []

    # Validate required sections
    errors =
      if not Map.has_key?(config, :analysis),
        do: ["Missing :analysis section" | errors],
        else: errors

    errors =
      if not Map.has_key?(config, :cache), do: ["Missing :cache section" | errors], else: errors

    errors =
      if not Map.has_key?(config, :plugins),
        do: ["Missing :plugins section" | errors],
        else: errors

    # Validate timeout values
    errors =
      if config[:analysis][:default_timeout_ms] <= 0,
        do: ["Invalid default_timeout_ms" | errors],
        else: errors

    # Validate cache TTL values
    if Map.has_key?(config, :cache) and Map.has_key?(config[:cache], :scope_ttl) do
      scope_ttl = config[:cache][:scope_ttl]
      errors = if scope_ttl[:basic] <= 0, do: ["Invalid basic scope TTL" | errors], else: errors

      errors =
        if scope_ttl[:standard] <= 0, do: ["Invalid standard scope TTL" | errors], else: errors

      errors = if scope_ttl[:full] <= 0, do: ["Invalid full scope TTL" | errors], else: errors
    end

    case errors do
      [] -> {:ok, config}
      errors -> {:error, Enum.reverse(errors)}
    end
  end

  # Private helper functions

  defp load_plugin_config do
    %{
      # Character plugins configuration
      character: %{
        combat_stats: %{
          enabled: true,
          cache_ttl_ms: 300_000,
          analysis_depth: :standard
        },
        behavioral_patterns: %{
          enabled: true,
          cache_ttl_ms: 600_000,
          pattern_window_days: 90
        },
        ship_preferences: %{
          enabled: true,
          cache_ttl_ms: 600_000,
          min_usage_threshold: 5
        },
        threat_assessment: %{
          enabled: true,
          cache_ttl_ms: 300_000,
          risk_factors: [:aggression, :capability, :opportunity]
        }
      },

      # Corporation plugins configuration
      corporation: %{
        member_activity: %{
          enabled: true,
          cache_ttl_ms: 600_000,
          activity_window_days: 30
        },
        fleet_readiness: %{
          enabled: true,
          cache_ttl_ms: 1_800_000,
          readiness_threshold: 0.7
        },
        doctrine_compliance: %{
          enabled: true,
          cache_ttl_ms: 3_600_000,
          compliance_threshold: 0.8
        }
      },

      # Fleet plugins configuration
      fleet: %{
        composition_analysis: %{
          enabled: true,
          cache_ttl_ms: 600_000,
          role_analysis: true
        },
        effectiveness_rating: %{
          enabled: true,
          cache_ttl_ms: 1_800_000,
          rating_algorithm: :weighted_average
        }
      },

      # Threat plugins configuration
      threat: %{
        vulnerability_scan: %{
          enabled: true,
          cache_ttl_ms: 300_000,
          scan_depth: :standard
        },
        risk_assessment: %{
          enabled: true,
          cache_ttl_ms: 600_000,
          risk_model: :composite
        }
      }
    }
  end

  defp load_environment_config do
    %{
      # Environment-specific plugin overrides
      disabled_plugins: parse_disabled_plugins(),

      # Performance overrides
      max_concurrent: get_env_int("INTELLIGENCE_MAX_CONCURRENT", nil),
      cache_ttl_override: get_env_int("INTELLIGENCE_CACHE_TTL_MS", nil),

      # Debug configuration
      debug_mode: get_env_bool("INTELLIGENCE_DEBUG", false),
      log_plugin_execution: get_env_bool("INTELLIGENCE_LOG_PLUGINS", false),

      # Feature flags
      enable_experimental: get_env_bool("INTELLIGENCE_EXPERIMENTAL", false),
      enable_cache_warming: get_env_bool("INTELLIGENCE_CACHE_WARMING", false)
    }
  end

  defp parse_disabled_plugins do
    case System.get_env("INTELLIGENCE_DISABLED_PLUGINS") do
      nil ->
        []

      value ->
        value
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.filter(&(&1 != ""))
        |> Enum.map(&String.to_atom/1)
    end
  end

  defp get_env_int(key, default) do
    case System.get_env(key) do
      nil ->
        default

      value ->
        case Integer.parse(value) do
          {int_value, ""} -> int_value
          _ -> default
        end
    end
  end

  defp get_env_bool(key, default) do
    case System.get_env(key) do
      nil -> default
      value -> value in ["true", "1", "yes", "on"]
    end
  end
end
