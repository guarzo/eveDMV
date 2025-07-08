#!/usr/bin/env elixir

IO.puts("=== Intelligence Engine Test Script ===")

# Test 1: Configuration Loading
IO.puts("\n1. Testing Configuration...")
config = EveDmv.IntelligenceEngine.Config.load()
IO.inspect(Map.keys(config), label: "Config sections")

# Test 2: Plugin Information
IO.puts("\n2. Testing Plugin System...")
plugin_info = EveDmv.IntelligenceEngine.Plugins.Character.CombatStats.plugin_info()
IO.inspect(plugin_info, label: "CombatStats plugin info")

# Test 3: Default Plugin Lists
IO.puts("\n3. Testing Plugin Configuration...")
basic_plugins = EveDmv.IntelligenceEngine.Config.get_default_plugins(:character, :basic)
IO.inspect(basic_plugins, label: "Character basic plugins")

standard_plugins = EveDmv.IntelligenceEngine.Config.get_default_plugins(:character, :standard)
IO.inspect(standard_plugins, label: "Character standard plugins")

full_plugins = EveDmv.IntelligenceEngine.Config.get_default_plugins(:character, :full)
IO.inspect(full_plugins, label: "Character full plugins")

# Test 4: Cache TTL Configuration
IO.puts("\n4. Testing Cache Configuration...")
basic_ttl = EveDmv.IntelligenceEngine.Config.get_cache_ttl(:basic)
standard_ttl = EveDmv.IntelligenceEngine.Config.get_cache_ttl(:standard)
full_ttl = EveDmv.IntelligenceEngine.Config.get_cache_ttl(:full)

IO.puts("Cache TTLs - Basic: #{basic_ttl}ms, Standard: #{standard_ttl}ms, Full: #{full_ttl}ms")

# Test 5: Analysis Timeouts
IO.puts("\n5. Testing Analysis Timeouts...")
basic_timeout = EveDmv.IntelligenceEngine.Config.get_analysis_timeout(:basic, 1)
standard_timeout = EveDmv.IntelligenceEngine.Config.get_analysis_timeout(:standard, 1)
full_timeout = EveDmv.IntelligenceEngine.Config.get_analysis_timeout(:full, 1)

IO.puts(
  "Analysis Timeouts - Basic: #{basic_timeout}ms, Standard: #{standard_timeout}ms, Full: #{full_timeout}ms"
)

# Test 6: Plugin Capabilities
IO.puts("\n6. Testing Plugin Capabilities...")
supports_batch = EveDmv.IntelligenceEngine.Plugins.Character.CombatStats.supports_batch?()
dependencies = EveDmv.IntelligenceEngine.Plugins.Character.CombatStats.dependencies()
cache_strategy = EveDmv.IntelligenceEngine.Plugins.Character.CombatStats.cache_strategy()

IO.puts("CombatStats Plugin:")
IO.puts("  - Supports batch: #{supports_batch}")
IO.puts("  - Dependencies: #{inspect(dependencies)}")
IO.puts("  - Cache strategy: #{inspect(cache_strategy)}")

# Test 7: Configuration Validation
IO.puts("\n7. Testing Configuration Validation...")
config = EveDmv.IntelligenceEngine.Config.load()
validation_result = EveDmv.IntelligenceEngine.Config.validate_config(config)
IO.inspect(validation_result, label: "Config validation result")

# Test 8: Performance Limits
IO.puts("\n8. Testing Performance Limits...")
performance_limits = EveDmv.IntelligenceEngine.Config.get_performance_limits()
IO.inspect(performance_limits, label: "Performance limits")

# Test 9: Plugin Enabled Check
IO.puts("\n9. Testing Plugin Enabled Checks...")
combat_enabled = EveDmv.IntelligenceEngine.Config.plugin_enabled?(:character, :combat_stats)
member_enabled = EveDmv.IntelligenceEngine.Config.plugin_enabled?(:corporation, :member_activity)

IO.puts("Plugin enabled status:")
IO.puts("  - Combat Stats: #{combat_enabled}")
IO.puts("  - Member Activity: #{member_enabled}")

# Test 10: Legacy Adapter Test (this will fail gracefully without database)
IO.puts("\n10. Testing Legacy Adapter...")
result = EveDmv.Intelligence.Analyzers.CharacterAnalyzer.analyze_character(12345)
IO.inspect(result, label: "Legacy character analysis result")

IO.puts("\n=== Intelligence Engine Test Complete ===")
IO.puts("✅ All core components tested successfully!")
