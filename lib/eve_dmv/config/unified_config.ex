defmodule EveDmv.Config.UnifiedConfig do
  @moduledoc """
  Unified configuration management for EVE DMV.

  This module provides a single, consistent interface for accessing all application
  configuration, with proper defaults, validation, and environment handling.

  ## Usage

      # Get configuration with default
      UnifiedConfig.get(:database, :pool_size, 10)

      # Get nested configuration
      UnifiedConfig.get([:intelligence, :analysis, :timeout_ms], 30_000)

      # Get environment variable with fallback to application config
      UnifiedConfig.env("EVE_SSO_CLIENT_ID", [:eve_sso, :client_id])

      # Check if feature is enabled
      UnifiedConfig.feature_enabled?(:pipeline_enabled)

  ## Configuration Categories

  - `:database` - Database and repository settings
  - `:cache` - Caching configuration and TTL values
  - `:api` - External API configurations (ESI, Janice, etc.)
  - `:intelligence` - Intelligence engine settings
  - `:pipeline` - Broadway pipeline configuration
  - `:security` - Authentication and authorization settings
  - `:web` - Phoenix and LiveView settings
  - `:features` - Feature flags and toggles

  ## Environment Variables

  Environment variables take precedence over application config when present.
  Naming convention: `EVE_DMV_<CATEGORY>_<SETTING>` or service-specific prefixes.
  """

  require Logger

  # Configuration schema with defaults and validation
  @config_schema %{
    database: %{
      pool_size: {10, :integer},
      timeout_ms: {15_000, :integer},
      log_level: {:info, :atom}
    },
    cache: %{
      default_ttl_ms: {600_000, :integer},
      cleanup_interval_ms: {300_000, :integer},
      max_memory_mb: {512, :integer},
      character_analysis_ttl_ms: {1_800_000, :integer},
      api_response_ttl_ms: {300_000, :integer}
    },
    api: %{
      esi: %{
        base_url: {"https://esi.evetech.net", :string},
        datasource: {"tranquility", :string},
        timeout_ms: {30_000, :integer},
        user_agent: {"EVE-DMV/1.0", :string}
      },
      janice: %{
        base_url: {"https://janice.e-351.com", :string},
        timeout_ms: {15_000, :integer}
      },
      mutamarket: %{
        base_url: {"https://mutamarket.com", :string},
        timeout_ms: {10_000, :integer}
      },
      wanderer: %{
        base_url: {"http://host.docker.internal:4004", :string},
        sse_url: {"http://host.docker.internal:4004/api/v1/kills/stream", :string},
        ws_url: {"ws://host.docker.internal:4004/socket", :string},
        timeout_ms: {30_000, :integer}
      }
    },
    intelligence: %{
      analysis: %{
        timeout_ms: {30_000, :integer},
        max_batch_size: {50, :integer},
        enable_parallel: {true, :boolean}
      },
      cache: %{
        default_ttl_ms: {600_000, :integer},
        character_analysis_ttl_ms: {1_800_000, :integer},
        correlation_analysis_ttl_ms: {3_600_000, :integer}
      },
      performance: %{
        slow_analysis_threshold_ms: {5_000, :integer},
        max_concurrent_analyses: {10, :integer}
      }
    },
    pipeline: %{
      enabled: {true, :boolean},
      concurrency: {4, :integer},
      batch_size: {10, :integer},
      batch_timeout_ms: {5_000, :integer},
      surveillance_batch_size: {5, :integer}
    },
    security: %{
      secret_key_base: {nil, :string},
      rate_limit: %{
        max_requests: {100, :integer},
        window_ms: {60_000, :integer}
      }
    },
    web: %{
      port: {4010, :integer},
      url: %{
        host: {"localhost", :string},
        port: {4010, :integer}
      },
      endpoint: %{
        secret_key_base: {nil, :string}
      }
    },
    features: %{
      pipeline_enabled: {true, :boolean},
      mock_sse_server_enabled: {false, :boolean},
      advanced_threat_analysis: {false, :boolean},
      experimental_features: {false, :boolean}
    }
  }

  # Environment variable mappings
  @env_mappings %{
    # Database
    "DATABASE_URL" => [:database, :url],
    "DATABASE_POOL_SIZE" => [:database, :pool_size],

    # Security & Authentication
    "SECRET_KEY_BASE" => [:security, :secret_key_base],
    "EVE_SSO_CLIENT_ID" => [:security, :eve_sso, :client_id],
    "EVE_SSO_CLIENT_SECRET" => [:security, :eve_sso, :client_secret],

    # External APIs
    "JANICE_API_KEY" => [:api, :janice, :api_key],
    "WANDERER_AUTH_TOKEN" => [:api, :wanderer, :auth_token],
    "WANDERER_KILLS_SSE_URL" => [:api, :wanderer, :sse_url],
    "WANDERER_KILLS_BASE_URL" => [:api, :wanderer, :base_url],

    # Pipeline
    "PIPELINE_ENABLED" => [:features, :pipeline_enabled],
    "MOCK_SSE_SERVER_ENABLED" => [:features, :mock_sse_server_enabled],

    # Intelligence
    "INTELLIGENCE_ANALYSIS_QUALITY" => [:intelligence, :analysis, :quality],
    "INTELLIGENCE_DISABLED_PLUGINS" => [:intelligence, :disabled_plugins],

    # Performance
    "EVE_DMV_CACHE_TTL_MS" => [:cache, :default_ttl_ms],
    "EVE_DMV_HTTP_TIMEOUT_MS" => [:api, :default_timeout_ms]
  }

  @type config_key :: atom() | [atom()]
  @type config_value :: term()

  @doc """
  Get configuration value with optional default.

  Supports both simple keys and nested key paths.
  Environment variables take precedence over application config.
  """
  @spec get(config_key(), config_value()) :: config_value()
  def get(key, default \\ nil)

  def get(key, default) when is_atom(key) do
    get([key], default)
  end

  def get(key_path, default) when is_list(key_path) do
    # Try to get from application config first
    app_value = get_from_app_config(key_path)

    # Check for environment variable override
    env_value = get_from_env(key_path)

    # Use precedence: env_value > app_value > schema_default > provided_default
    env_value || app_value || get_schema_default(key_path) || default
  end

  @doc """
  Get configuration from environment variable with fallback to application config.

  Useful for sensitive data that should come from environment variables.
  """
  @spec env(String.t(), config_key(), config_value()) :: config_value()
  def env(env_var, fallback_key, default \\ nil) do
    case System.get_env(env_var) do
      nil -> get(fallback_key, default)
      value -> cast_env_value(value, get_schema_type(fallback_key))
    end
  end

  @doc """
  Check if a feature is enabled.

  Features can be controlled by environment variables or application config.
  """
  @spec feature_enabled?(atom()) :: boolean()
  def feature_enabled?(feature_name) do
    get([:features, feature_name], false)
  end

  @doc """
  Get all configuration for a category.
  """
  @spec get_category(atom()) :: map()
  def get_category(category) do
    case Map.get(@config_schema, category) do
      nil ->
        Logger.warning("Unknown configuration category: #{category}")
        %{}

      schema ->
        build_category_config(category, schema)
    end
  end

  @doc """
  Validate current configuration and return any issues.
  """
  @spec validate_config() :: {:ok, :valid} | {:error, [String.t()]}
  def validate_config do
    errors =
      Enum.flat_map(@config_schema, fn {category, schema} ->
        validate_category(category, schema)
      end)

    case errors do
      [] -> {:ok, :valid}
      errors -> {:error, errors}
    end
  end

  @doc """
  Get configuration summary for debugging.
  """
  @spec config_summary() :: map()
  def config_summary do
    %{
      categories: Map.keys(@config_schema),
      env_variables_set: count_env_variables_set(),
      validation_status: validate_config(),
      runtime_environment: Mix.env()
    }
  end

  # Private functions

  defp get_from_app_config(key_path) do
    case key_path do
      [category | rest] ->
        base_config = Application.get_env(:eve_dmv, category, %{})
        get_nested_value(base_config, rest)

      [] ->
        nil
    end
  rescue
    _ -> nil
  end

  defp get_from_env(key_path) do
    # Find matching environment variable
    env_var =
      @env_mappings
      |> Enum.find(fn {_env, path} -> path == key_path end)
      |> case do
        {env_var, _} -> env_var
        nil -> generate_env_var_name(key_path)
      end

    case System.get_env(env_var) do
      nil -> nil
      value -> cast_env_value(value, get_schema_type(key_path))
    end
  end

  defp get_schema_default(key_path) do
    case get_nested_value(@config_schema, key_path) do
      {default, _type} -> default
      _ -> nil
    end
  end

  defp get_schema_type(key_path) do
    case get_nested_value(@config_schema, key_path) do
      {_default, type} -> type
      _ -> :string
    end
  end

  defp get_nested_value(map, []) when is_map(map), do: map

  defp get_nested_value(map, [key | rest]) when is_map(map) do
    case Map.get(map, key) do
      nil -> nil
      value -> get_nested_value(value, rest)
    end
  end

  defp get_nested_value(value, []), do: value
  defp get_nested_value(_, _), do: nil

  defp cast_env_value(value, type) do
    case type do
      :string -> value
      :integer -> String.to_integer(value)
      :boolean -> value in ["true", "1", "yes", "on"]
      :atom -> String.to_existing_atom(value)
      _ -> value
    end
  rescue
    _ ->
      Logger.warning("Failed to cast environment variable value '#{value}' to type #{type}")
      value
  end

  defp generate_env_var_name(key_path) do
    key_path
    |> Enum.map_join("_", &(&1 |> to_string() |> String.upcase()))
    |> then(&("EVE_DMV_" <> &1))
  end

  defp build_category_config(category, schema) do
    Enum.into(schema, %{}, fn {key, _spec} ->
      value = get([category, key])
      {key, value}
    end)
  end

  defp validate_category(category, schema) do
    Enum.flat_map(schema, fn {key, {_default, type}} ->
      value = get([category, key])
      validate_value([category, key], value, type)
    end)
  end

  defp validate_value(key_path, value, expected_type) do
    case {value, expected_type} do
      {nil, _} ->
        []

      {v, :string} when is_binary(v) ->
        []

      {v, :integer} when is_integer(v) ->
        []

      {v, :boolean} when is_boolean(v) ->
        []

      {v, :atom} when is_atom(v) ->
        []

      _ ->
        [
          "Invalid type for #{inspect(key_path)}: expected #{expected_type}, got #{inspect(value)}"
        ]
    end
  end

  defp count_env_variables_set do
    @env_mappings
    |> Map.keys()
    |> Enum.count(&System.get_env/1)
  end
end
