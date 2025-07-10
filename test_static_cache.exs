# Test script for StaticDataCache performance
Mix.install([])

# Start required apps
{:ok, _} = Application.ensure_all_started(:postgrex)
{:ok, _} = Application.ensure_all_started(:ecto)
{:ok, _} = EveDmv.Repo.start_link([])

# Test batch resolution
IO.puts("\n=== Testing StaticDataCache Performance ===\n")

# Test system names
system_ids = [30000142, 30002187, 30002659, 30002053, 30002510]
IO.puts("Testing system name resolution...")

start_time = System.monotonic_time(:microsecond)
system_names = EveDmv.Cache.StaticDataCache.resolve_system_names(system_ids)
end_time = System.monotonic_time(:microsecond)
duration_us = end_time - start_time

IO.puts("First call (cold cache): #{duration_us} μs")
IO.inspect(system_names, label: "System Names")

# Second call should be from cache
start_time = System.monotonic_time(:microsecond)
system_names_cached = EveDmv.Cache.StaticDataCache.resolve_system_names(system_ids)
end_time = System.monotonic_time(:microsecond)
duration_cached_us = end_time - start_time

IO.puts("\nSecond call (warm cache): #{duration_cached_us} μs")
IO.puts("Speedup: #{Float.round(duration_us / duration_cached_us, 2)}x")

# Test ship names
ship_ids = [587, 588, 620, 621, 638, 639]
IO.puts("\n\nTesting ship name resolution...")

start_time = System.monotonic_time(:microsecond)
ship_names = EveDmv.Cache.StaticDataCache.resolve_ship_names(ship_ids)
end_time = System.monotonic_time(:microsecond)
duration_us = end_time - start_time

IO.puts("First call (cold cache): #{duration_us} μs")
IO.inspect(ship_names, label: "Ship Names")

# Get cache statistics
stats = EveDmv.Cache.StaticDataCache.get_stats()
IO.puts("\n\nCache Statistics:")
IO.inspect(stats)

# Test with NameResolver integration
IO.puts("\n\nTesting NameResolver integration...")

start_time = System.monotonic_time(:microsecond)
jita_name = EveDmv.Eve.NameResolver.system_name(30000142)
end_time = System.monotonic_time(:microsecond)
resolver_duration = end_time - start_time

IO.puts("NameResolver.system_name(30000142): #{jita_name} (#{resolver_duration} μs)")

# Test batch resolution through NameResolver
start_time = System.monotonic_time(:microsecond)
batch_names = EveDmv.Eve.NameResolver.system_names(system_ids)
end_time = System.monotonic_time(:microsecond)
batch_duration = end_time - start_time

IO.puts("NameResolver.system_names batch: #{batch_duration} μs")
IO.inspect(batch_names, label: "Batch Names")