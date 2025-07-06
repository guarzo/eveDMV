defmodule EveDmv.IntelligenceEngineBasicTest do
  @moduledoc """
  Basic test suite for Intelligence Engine components that don't require database.
  """

  use ExUnit.Case, async: true

  alias EveDmv.IntelligenceEngine.{Config, Pipeline}
  alias EveDmv.IntelligenceEngine.Plugins.Character.CombatStats

  describe "Intelligence Engine Configuration" do
    test "config loads successfully" do
      config = Config.load()

      assert is_map(config)
      assert Map.has_key?(config, :analysis)
      assert Map.has_key?(config, :cache)
      assert Map.has_key?(config, :plugins)
      assert Map.has_key?(config, :performance)

      # Check analysis configuration
      assert is_map(config.analysis)
      assert config.analysis.default_scope in [:basic, :standard, :full]
      assert is_integer(config.analysis.default_timeout_ms)
      assert config.analysis.default_timeout_ms > 0

      # Check cache configuration
      assert is_map(config.cache)
      assert is_integer(config.cache.default_ttl_ms)
      assert config.cache.default_ttl_ms > 0
    end

    test "gets default plugins for character domain" do
      basic_plugins = Config.get_default_plugins(:character, :basic)
      standard_plugins = Config.get_default_plugins(:character, :standard)
      full_plugins = Config.get_default_plugins(:character, :full)

      assert is_list(basic_plugins)
      assert is_list(standard_plugins)
      assert is_list(full_plugins)

      # Basic should be a subset of standard, which should be a subset of full
      assert length(basic_plugins) <= length(standard_plugins)
      assert length(standard_plugins) <= length(full_plugins)

      # Basic should include combat_stats
      assert :combat_stats in basic_plugins

      # Standard should include behavioral_patterns and ship_preferences
      assert :combat_stats in standard_plugins
      assert :behavioral_patterns in standard_plugins
      assert :ship_preferences in standard_plugins
    end

    test "gets default plugins for corporation domain" do
      basic_plugins = Config.get_default_plugins(:corporation, :basic)
      standard_plugins = Config.get_default_plugins(:corporation, :standard)
      full_plugins = Config.get_default_plugins(:corporation, :full)

      assert is_list(basic_plugins)
      assert is_list(standard_plugins)
      assert is_list(full_plugins)

      # Basic should include member_activity
      assert :member_activity in basic_plugins
    end

    test "gets appropriate timeout for different scopes" do
      basic_timeout = Config.get_analysis_timeout(:basic, 1)
      standard_timeout = Config.get_analysis_timeout(:standard, 1)
      full_timeout = Config.get_analysis_timeout(:full, 1)

      assert is_integer(basic_timeout)
      assert is_integer(standard_timeout)
      assert is_integer(full_timeout)

      # Full analysis should have longer timeout
      assert basic_timeout <= standard_timeout
      assert standard_timeout <= full_timeout
    end

    test "scales timeout with entity count" do
      single_timeout = Config.get_analysis_timeout(:standard, 1)
      batch_timeout = Config.get_analysis_timeout(:standard, 50)

      assert batch_timeout > single_timeout
    end

    test "gets cache TTL for different scopes" do
      basic_ttl = Config.get_cache_ttl(:basic)
      standard_ttl = Config.get_cache_ttl(:standard)
      full_ttl = Config.get_cache_ttl(:full)

      assert is_integer(basic_ttl)
      assert is_integer(standard_ttl)
      assert is_integer(full_ttl)

      # Full analysis should have longer cache TTL
      assert basic_ttl <= standard_ttl
      assert standard_ttl <= full_ttl
    end
  end

  describe "Plugin System" do
    test "plugin info is correctly structured" do
      plugin_info = CombatStats.plugin_info()

      assert is_map(plugin_info)
      assert is_binary(plugin_info.name)
      assert is_binary(plugin_info.description)
      assert is_binary(plugin_info.version)
      assert is_list(plugin_info.dependencies)

      # Check optional fields
      assert Map.has_key?(plugin_info, :author)
      assert Map.has_key?(plugin_info, :tags)
      assert is_list(plugin_info.tags)
    end

    test "plugin supports required callbacks" do
      # Verify the plugin implements required functions
      assert function_exported?(CombatStats, :analyze, 3)
      assert function_exported?(CombatStats, :plugin_info, 0)

      # Verify optional callbacks
      assert function_exported?(CombatStats, :supports_batch?, 0)
      assert function_exported?(CombatStats, :dependencies, 0)
      assert function_exported?(CombatStats, :cache_strategy, 0)
    end

    test "plugin cache strategy is properly configured" do
      cache_strategy = CombatStats.cache_strategy()

      assert is_map(cache_strategy)
      assert Map.has_key?(cache_strategy, :strategy)
      assert Map.has_key?(cache_strategy, :ttl_seconds)
      assert is_integer(cache_strategy.ttl_seconds)
      assert cache_strategy.ttl_seconds > 0
    end

    test "plugin supports batch analysis" do
      supports_batch = CombatStats.supports_batch?()
      assert is_boolean(supports_batch)
      assert supports_batch == true
    end

    test "plugin has valid dependencies" do
      dependencies = CombatStats.dependencies()
      assert is_list(dependencies)

      # Should have database dependencies
      assert Enum.any?(dependencies, fn dep ->
               dep == EveDmv.Database.CharacterRepository or
                 dep == EveDmv.Database.KillmailRepository
             end)
    end
  end

  describe "Data validation and preparation" do
    test "validates entity IDs correctly" do
      # Valid entity IDs
      assert Pipeline.validate_entity_id(12_345) == :ok
      assert Pipeline.validate_entity_id([12_345, 67_890]) == :ok

      # Invalid entity IDs
      assert {:error, _} = Pipeline.validate_entity_id(0)
      assert {:error, _} = Pipeline.validate_entity_id(-1)
      assert {:error, _} = Pipeline.validate_entity_id("invalid")
      assert {:error, _} = Pipeline.validate_entity_id([])
      assert {:error, _} = Pipeline.validate_entity_id([0, 12_345])
    end

    test "validates analysis domains correctly" do
      # Valid domains
      assert Pipeline.validate_domain(:character) == :ok
      assert Pipeline.validate_domain(:corporation) == :ok
      assert Pipeline.validate_domain(:fleet) == :ok
      assert Pipeline.validate_domain(:threat) == :ok

      # Invalid domains
      assert {:error, _} = Pipeline.validate_domain(:invalid)
      assert {:error, _} = Pipeline.validate_domain("character")
      assert {:error, _} = Pipeline.validate_domain(nil)
    end

    test "prepares base data structure correctly" do
      entity_id = 12_345
      domain = :character
      opts = [scope: :basic]

      base_data = Pipeline.prepare_base_data(entity_id, domain, opts)

      assert is_map(base_data)
      assert Map.has_key?(base_data, :entity_id)
      assert Map.has_key?(base_data, :domain)
      assert Map.has_key?(base_data, :scope)
      assert Map.has_key?(base_data, :analysis_timestamp)

      assert base_data.entity_id == entity_id
      assert base_data.domain == domain
      assert base_data.scope == :basic
    end
  end

  describe "Cache key generation" do
    test "generates consistent cache keys" do
      key1 = Pipeline.generate_cache_key(:character, 12345, :basic, [])
      key2 = Pipeline.generate_cache_key(:character, 12345, :basic, [])

      assert key1 == key2
      assert is_binary(key1)
      assert String.contains?(key1, "character")
      assert String.contains?(key1, "12345")
      assert String.contains?(key1, "basic")
    end

    test "generates different keys for different parameters" do
      key1 = Pipeline.generate_cache_key(:character, 12345, :basic, [])
      key2 = Pipeline.generate_cache_key(:character, 12345, :standard, [])
      key3 = Pipeline.generate_cache_key(:character, 67890, :basic, [])
      key4 = Pipeline.generate_cache_key(:corporation, 12345, :basic, [])

      # All keys should be different
      keys = [key1, key2, key3, key4]
      assert length(Enum.uniq(keys)) == 4
    end

    test "handles options in cache key generation" do
      key1 = Pipeline.generate_cache_key(:character, 12345, :basic, [])
      key2 = Pipeline.generate_cache_key(:character, 12345, :basic, parallel: true)
      key3 = Pipeline.generate_cache_key(:character, 12345, :basic, entity_type: :pilot)

      # Keys with different options should be different
      assert key1 != key2
      assert key1 != key3
      assert key2 != key3
    end
  end

  describe "Configuration validation" do
    test "validates complete configuration" do
      config = Config.load()
      result = Config.validate_config(config)

      assert {:ok, ^config} = result
    end

    test "detects invalid configuration" do
      invalid_config = %{
        # Invalid negative timeout
        analysis: %{default_timeout_ms: -1},
        # Invalid zero TTL
        cache: %{scope_ttl: %{basic: 0}},
        plugins: %{}
      }

      result = Config.validate_config(invalid_config)
      assert {:error, errors} = result
      assert is_list(errors)
      assert length(errors) > 0
    end
  end

  describe "Plugin configuration" do
    test "checks if plugins are enabled" do
      # Should be enabled by default
      assert Config.plugin_enabled?(:character, :combat_stats) == true
      assert Config.plugin_enabled?(:corporation, :member_activity) == true
    end

    test "gets performance limits" do
      limits = Config.get_performance_limits()

      assert is_map(limits)
      assert Map.has_key?(limits, :max_concurrent_analyses)
      assert Map.has_key?(limits, :max_batch_size)
      assert Map.has_key?(limits, :slow_analysis_threshold_ms)
      assert Map.has_key?(limits, :memory_limit_mb)

      # All values should be positive integers
      assert is_integer(limits.max_concurrent_analyses)
      assert limits.max_concurrent_analyses > 0
      assert is_integer(limits.max_batch_size)
      assert limits.max_batch_size > 0
    end
  end

  describe "Helper function extraction" do
    test "extracts character data from base_data" do
      # Test the helper functions that plugins use
      base_data = %{
        character_stats: %{
          12345 => %{
            character_id: 12345,
            character_name: "Test Character",
            total_kills: 50,
            total_losses: 10
          }
        }
      }

      # This simulates what plugins do internally
      result = get_in(base_data, [:character_stats, 12345])
      assert is_map(result)
      assert result.character_id == 12345
      assert result.character_name == "Test Character"
    end

    test "handles missing character data gracefully" do
      base_data = %{character_stats: %{}}

      result = get_in(base_data, [:character_stats, 99999])
      assert result == nil
    end
  end
end
