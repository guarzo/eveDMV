# Ash Filter Syntax Fix Summary

## Issue
The ChainMonitor tests were failing with "unknown options [:filter]" errors because the code was using the old Ash 2.x query syntax instead of the proper Ash 3.x syntax.

## Root Cause
In Ash 3.x, filters must be applied using `Ash.Query.filter/2` instead of passing `:filter` as an option directly to `Ash.read/2`.

## Files Fixed

### 1. `/workspace/lib/eve_dmv/intelligence/chain_monitor.ex`
- Added `require Ash.Query` 
- Fixed all instances of `Ash.read(Resource, filter: [...], domain: Api)` to use the pipe syntax:
  ```elixir
  Resource
  |> Ash.Query.filter(field == ^value)
  |> Ash.read(domain: Api)
  ```

### 2. `/workspace/test/eve_dmv/intelligence/chain_monitor_test.exs`
- Added `require Ash.Query`
- Fixed filter syntax in test assertions

### 3. `/workspace/lib/eve_dmv_web/live/chain_intelligence_live.ex`
- Added `require Ash.Query`
- Fixed all filter syntax instances

### 4. `/workspace/lib/eve_dmv/intelligence/threat_analyzer.ex`
- Added `require Ash.Query`
- Fixed filter syntax

### 5. `/workspace/lib/eve_dmv/eve/name_resolver.ex`
- Added `require Ash.Query`
- Fixed filter syntax for `in` queries:
  ```elixir
  Resource |> Ash.Query.filter(field in ^list) |> Ash.read(domain: Api)
  ```

### 6. `/workspace/test/manual/manual_testing_data_generator.exs`
- Added `require Ash.Query`
- Fixed filter syntax and converted old query keyword list pattern to pipe syntax

## Key Changes

### Before (Ash 2.x):
```elixir
Ash.read(Resource, filter: [field: value], domain: Api)
Ash.read(Resource, filter: [field: [in: list]], domain: Api)
```

### After (Ash 3.x):
```elixir
Resource |> Ash.Query.filter(field == ^value) |> Ash.read(domain: Api)
Resource |> Ash.Query.filter(field in ^list) |> Ash.read(domain: Api)
```

## Result
The compilation now succeeds without any filter syntax errors. The tests are failing due to a separate database connection ownership issue in the test environment, which is unrelated to the Ash filter syntax problem that has been resolved.