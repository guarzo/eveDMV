defmodule EveDmv.IntelligenceEngineTest do
  @moduledoc """
  Test suite for the Intelligence Engine and plugin system.
  """

  use ExUnit.Case, async: true

  alias EveDmv.IntelligenceEngine
  alias EveDmv.IntelligenceEngine.{Config, Pipeline, PluginRegistry}
  alias EveDmv.IntelligenceEngine.Plugins.Character.CombatStats

  describe "Intelligence Engine basic functionality" do
    test "config loads successfully" do
      config = Config.load()

      assert is_map(config)
      assert Map.has_key?(config, :analysis)
      assert Map.has_key?(config, :cache)
      assert Map.has_key?(config, :plugins)
      assert Map.has_key?(config, :performance)
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
    end

    test "plugin info is correctly structured" do
      plugin_info = CombatStats.plugin_info()

      assert is_map(plugin_info)
      assert is_binary(plugin_info.name)
      assert is_binary(plugin_info.description)
      assert is_binary(plugin_info.version)
      assert is_list(plugin_info.dependencies)
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
  end

  describe "Plugin Registry" do
    setup do
      # Start a test registry
      {:ok, registry} = PluginRegistry.start_link([])
      %{registry: registry}
    end

    test "can register and list plugins", %{registry: registry} do
      # Register a test plugin
      :ok = PluginRegistry.register(registry, :character, :test_plugin, CombatStats)

      # List plugins
      plugins = PluginRegistry.list_plugins(registry, :character)
      assert is_list(plugins)
      assert {:test_plugin, CombatStats} in plugins
    end

    test "can get specific plugin", %{registry: registry} do
      # Register a test plugin
      :ok = PluginRegistry.register(registry, :character, :test_plugin, CombatStats)

      # Get the plugin
      {:ok, module} = PluginRegistry.get_plugin(registry, :character, :test_plugin)
      assert module == CombatStats
    end

    test "returns error for non-existent plugin", %{registry: registry} do
      result = PluginRegistry.get_plugin(registry, :character, :non_existent)
      assert {:error, :plugin_not_found} = result
    end
  end

  describe "Data preparation and validation" do
    test "validates entity IDs correctly" do
      # Valid entity IDs
      assert Pipeline.validate_entity_id(12345) == :ok
      assert Pipeline.validate_entity_id([12345, 67890]) == :ok

      # Invalid entity IDs
      assert {:error, _} = Pipeline.validate_entity_id(0)
      assert {:error, _} = Pipeline.validate_entity_id(-1)
      assert {:error, _} = Pipeline.validate_entity_id("invalid")
      assert {:error, _} = Pipeline.validate_entity_id([])
      assert {:error, _} = Pipeline.validate_entity_id([0, 12345])
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
      entity_id = 12345
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

  describe "Error handling" do
    test "handles invalid plugin gracefully" do
      # This should fail gracefully if the Intelligence Engine isn't fully running
      result = IntelligenceEngine.analyze(:invalid_domain, 12345, [])

      # Should return an error, not crash
      assert {:error, _reason} = result
    end

    test "handles invalid entity ID gracefully" do
      result = IntelligenceEngine.analyze(:character, -1, [])

      # Should return an error for invalid entity ID
      assert {:error, _reason} = result
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
  end

  describe "Performance and configuration" do
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
end
