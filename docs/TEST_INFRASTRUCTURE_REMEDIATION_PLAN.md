# Test Infrastructure Remediation Plan

**Created:** 2026-01-05
**Priority:** High
**Scope:** Fix test infrastructure issues causing connection pool exhaustion and SQL Sandbox violations

---

## Executive Summary

During Phase 8 validation, several test infrastructure issues were identified that cause intermittent test failures and resource exhaustion. This plan outlines the steps to diagnose, fix, and prevent these issues.

---

## Identified Issues

### Issue 1: Database Connection Pool Exhaustion

**Symptom:**
```
FATAL 53300 (too_many_connections) sorry, too many clients already
```

**Root Cause:** Tests are spawning processes that open database connections without proper cleanup, exhausting the PostgreSQL connection limit.

**Affected Areas:**
- Integration tests with GenServers
- Tests that spawn background tasks
- Async tests running in parallel

---

### Issue 2: SQL Sandbox Owner Process Exit

**Symptom:**
```
Postgrex.Protocol disconnected: ** (DBConnection.ConnectionError) owner #PID<0.763.0> exited
Client #PID<0.694.0> is still using a connection from owner
```

**Root Cause:** GenServers (like `HistoricalFetchWorker`) spawn background tasks that outlive the test process, attempting to use database connections after the sandbox owner has exited.

**Affected Files:**
- `lib/eve_dmv/contexts/killmail_processing/domain/historical_fetch_worker.ex`
- `test/integration/historical_fetch_flow_test.exs`
- `test/integration/surveillance_flow_test.exs`

---

### Issue 3: Shared GenServer State Between Tests

**Symptom:** Tests that start GenServers can interfere with each other when running in parallel.

**Root Cause:** Named GenServers persist across test boundaries when not properly stopped.

---

## Implementation Plan

### Phase 1: Audit and Diagnosis

#### 1.1 Identify All GenServer Dependencies in Tests

**Files to Review:**
```
test/integration/historical_fetch_flow_test.exs
test/integration/surveillance_flow_test.exs
test/integration/battle_analysis_flow_test.exs
test/integration/character_analysis_flow_test.exs
test/eve_dmv/contexts/killmail_processing/domain/historical_fetch_worker_test.exs
```

**Action:** Create inventory of all GenServers started in tests:
- [ ] HistoricalFetchWorker
- [ ] MatchingEngine
- [ ] NotificationService
- [ ] ProfileRepository
- [ ] BattleDetector

#### 1.2 Identify Background Task Spawning

**Search Pattern:**
```bash
grep -r "Task.async\|Task.start\|spawn\|GenServer.cast" test/
grep -r "Task.async\|Task.start\|spawn" lib/eve_dmv/contexts/killmail_processing/
```

**Action:** Document all locations where background tasks are spawned that may outlive the test.

---

### Phase 2: SQL Sandbox Configuration

#### 2.1 Update DataCase Module

**File:** `test/support/data_case.ex`

**Changes:**
```elixir
defmodule EveDmv.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias EveDmv.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import EveDmv.DataCase
      import EveDmv.Factory

      # Helper for character/corporation ID generation
      def character_id, do: Enum.random(90_000_000..99_999_999)
      def corporation_id, do: Enum.random(98_000_000..98_999_999)
    end
  end

  setup tags do
    EveDmv.DataCase.setup_sandbox(tags)
  end

  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(EveDmv.Repo, shared: not tags[:async])

    on_exit(fn ->
      # Give time for any pending operations to complete
      Process.sleep(50)
      Ecto.Adapters.SQL.Sandbox.stop_owner(pid)
    end)

    :ok
  end
end
```

#### 2.2 Configure Sandbox for Async Tests with GenServers

**Add helper function to DataCase:**
```elixir
@doc """
Allow a process to use the test's database connection.
Call this for any GenServer or spawned process that needs DB access.
"""
def allow_sandbox_access(pid, owner_pid \\ self()) do
  Ecto.Adapters.SQL.Sandbox.allow(EveDmv.Repo, owner_pid, pid)
end

@doc """
Set sandbox to shared mode for tests that spawn processes.
Use sparingly as it disables async test execution.
"""
def set_shared_sandbox_mode do
  Ecto.Adapters.SQL.Sandbox.mode(EveDmv.Repo, {:shared, self()})
end
```

---

### Phase 3: Fix GenServer Test Patterns

#### 3.1 Create GenServer Test Helper Module

**File to Create:** `test/support/genserver_test_helper.ex`

```elixir
defmodule EveDmv.GenServerTestHelper do
  @moduledoc """
  Helpers for testing GenServers with SQL Sandbox.
  """

  @doc """
  Starts a GenServer and ensures it's properly registered with SQL Sandbox.
  Returns {:ok, pid} and automatically stops on test exit.
  """
  def start_genserver_for_test(module, opts \\ []) do
    # Ensure we're using shared sandbox mode
    Ecto.Adapters.SQL.Sandbox.mode(EveDmv.Repo, {:shared, self()})

    # Stop any existing instance
    stop_if_running(module)

    # Start fresh instance
    {:ok, pid} = module.start_link(opts)

    # Allow the GenServer to access the database
    Ecto.Adapters.SQL.Sandbox.allow(EveDmv.Repo, self(), pid)

    # Register cleanup
    ExUnit.Callbacks.on_exit(fn ->
      stop_genserver_gracefully(pid)
    end)

    {:ok, pid}
  end

  @doc """
  Stops a GenServer gracefully, handling already-stopped cases.
  """
  def stop_genserver_gracefully(pid_or_name) do
    pid = resolve_pid(pid_or_name)

    if pid && Process.alive?(pid) do
      try do
        GenServer.stop(pid, :normal, 5_000)
      catch
        :exit, _ -> :ok
      end
    end

    :ok
  end

  @doc """
  Stops a GenServer if it's currently running.
  """
  def stop_if_running(module) when is_atom(module) do
    case GenServer.whereis(module) do
      nil -> :ok
      pid -> stop_genserver_gracefully(pid)
    end
  end

  defp resolve_pid(pid) when is_pid(pid), do: pid
  defp resolve_pid(name) when is_atom(name), do: GenServer.whereis(name)
  defp resolve_pid(_), do: nil
end
```

#### 3.2 Update HistoricalFetchWorker for Testability

**File:** `lib/eve_dmv/contexts/killmail_processing/domain/historical_fetch_worker.ex`

**Changes Required:**

1. Add option to disable background processing in tests:
```elixir
def start_link(opts \\ []) do
  name = Keyword.get(opts, :name, __MODULE__)
  test_mode = Keyword.get(opts, :test_mode, false)
  GenServer.start_link(__MODULE__, %{test_mode: test_mode}, name: name)
end

def init(state) do
  unless state.test_mode do
    schedule_check()
  end
  {:ok, Map.merge(state, %{queue: [], in_progress: nil})}
end
```

2. Make background tasks await-able in tests:
```elixir
defp process_fetch_async(entity_type, entity_id, state) do
  if state.test_mode do
    # Synchronous processing in test mode
    process_fetch(entity_type, entity_id)
  else
    # Async processing in production
    Task.start(fn -> process_fetch(entity_type, entity_id) end)
  end
end
```

#### 3.3 Update Integration Tests to Use Helpers

**Example update for `historical_fetch_flow_test.exs`:**

```elixir
defmodule EveDmv.Integration.HistoricalFetchFlowTest do
  use EveDmv.DataCase, async: false

  import EveDmv.GenServerTestHelper

  setup do
    # Use shared sandbox mode for GenServer tests
    set_shared_sandbox_mode()

    # Start worker in test mode
    {:ok, pid} = start_genserver_for_test(
      EveDmv.Contexts.KillmailProcessing.Domain.HistoricalFetchWorker,
      test_mode: true
    )

    {:ok, worker_pid: pid}
  end

  # ... tests ...
end
```

---

### Phase 4: Connection Pool Configuration

#### 4.1 Increase Test Pool Size

**File:** `config/test.exs`

**Changes:**
```elixir
config :eve_dmv, EveDmv.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "eve_dmv_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 20,  # Increase from default 10
  queue_target: 5000,
  queue_interval: 1000
```

#### 4.2 Add Connection Checkout Timeout

**File:** `config/test.exs`

```elixir
config :eve_dmv, EveDmv.Repo,
  # ... existing config ...
  ownership_timeout: 120_000,  # 2 minutes
  timeout: 30_000  # 30 seconds
```

#### 4.3 PostgreSQL Configuration (if self-hosted)

**Check/Update:** `postgresql.conf` or Docker compose settings

```
max_connections = 200  # Increase from default 100
```

For Docker:
```yaml
# docker-compose.yml
services:
  postgres:
    environment:
      POSTGRES_MAX_CONNECTIONS: 200
```

---

### Phase 5: Test Isolation Improvements

#### 5.1 Add Test Tags for Resource-Intensive Tests

**Update tests to use proper tags:**

```elixir
# For tests that need exclusive database access
@tag :integration
@tag :exclusive_db
test "some resource-intensive test" do
  # ...
end
```

**Update test_helper.exs:**
```elixir
# Exclude exclusive_db tests from parallel runs by default
ExUnit.configure(exclude: [:exclusive_db])
```

#### 5.2 Create Test Cleanup Module

**File to Create:** `test/support/test_cleanup.ex`

```elixir
defmodule EveDmv.TestCleanup do
  @moduledoc """
  Utilities for cleaning up test state between runs.
  """

  @genservers [
    EveDmv.Contexts.KillmailProcessing.Domain.HistoricalFetchWorker,
    EveDmv.Contexts.Surveillance.Domain.MatchingEngine,
    EveDmv.Contexts.Surveillance.Domain.NotificationService,
    EveDmv.Contexts.Surveillance.Infrastructure.ProfileRepository,
    EveDmv.Contexts.BattleAnalysis.Core.BattleDetector
  ]

  def stop_all_genservers do
    Enum.each(@genservers, fn module ->
      case GenServer.whereis(module) do
        nil -> :ok
        pid when is_pid(pid) ->
          if Process.alive?(pid) do
            try do
              GenServer.stop(pid, :normal, 1_000)
            catch
              :exit, _ -> :ok
            end
          end
      end
    end)

    # Give processes time to fully terminate
    Process.sleep(100)
  end

  def reset_test_state do
    stop_all_genservers()
    :ok
  end
end
```

#### 5.3 Add Global Test Setup/Teardown

**File:** `test/test_helper.exs`

```elixir
# Add at the end of test_helper.exs

# Global setup before all tests
ExUnit.after_suite(fn _results ->
  EveDmv.TestCleanup.reset_test_state()
end)
```

---

### Phase 6: Validation and Monitoring

#### 6.1 Create Test Infrastructure Health Check

**File to Create:** `test/support/infrastructure_check.ex`

```elixir
defmodule EveDmv.InfrastructureCheck do
  @moduledoc """
  Validates test infrastructure is properly configured.
  """

  def run_checks do
    checks = [
      {:sandbox_mode, check_sandbox_mode()},
      {:pool_size, check_pool_size()},
      {:connection_available, check_connection_available()}
    ]

    failed = Enum.filter(checks, fn {_, result} -> result != :ok end)

    if Enum.empty?(failed) do
      :ok
    else
      {:error, failed}
    end
  end

  defp check_sandbox_mode do
    case EveDmv.Repo.config()[:pool] do
      Ecto.Adapters.SQL.Sandbox -> :ok
      other -> {:error, "Expected SQL Sandbox, got: #{inspect(other)}"}
    end
  end

  defp check_pool_size do
    pool_size = EveDmv.Repo.config()[:pool_size] || 10
    if pool_size >= 15 do
      :ok
    else
      {:warning, "Pool size #{pool_size} may be too small for integration tests"}
    end
  end

  defp check_connection_available do
    case Ecto.Adapters.SQL.query(EveDmv.Repo, "SELECT 1", []) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
```

#### 6.2 Add CI Monitoring

**Update:** `.github/workflows/ci.yml` (or equivalent)

```yaml
- name: Run tests with connection monitoring
  run: |
    # Monitor PostgreSQL connections during test run
    pg_stat_activity_before=$(psql -c "SELECT count(*) FROM pg_stat_activity" -t)

    MIX_ENV=test mix test --max-failures=10

    pg_stat_activity_after=$(psql -c "SELECT count(*) FROM pg_stat_activity" -t)

    echo "Connections before: $pg_stat_activity_before"
    echo "Connections after: $pg_stat_activity_after"
```

---

## Phase 1 Audit Results (Completed 2026-01-05)

### 1.1 GenServers Started in Tests - Complete Inventory

| GenServer Module | Test File(s) | async: false | Notes |
|------------------|--------------|--------------|-------|
| `HistoricalFetchWorker` | `test/integration/historical_fetch_flow_test.exs`, `test/eve_dmv/contexts/killmail_processing/domain/historical_fetch_worker_test.exs` | ✅ Yes | Properly cleaned up with `on_exit` |
| `ProfileRepository` | `test/integration/surveillance_flow_test.exs` | ✅ Yes | Started first in dependency order |
| `MatchingEngine` | `test/integration/surveillance_flow_test.exs`, `test/eve_dmv/surveillance/matching_engine_test.exs` | ✅ Yes | Depends on ProfileRepository |
| `NotificationService` | `test/integration/surveillance_flow_test.exs` | ✅ Yes | Properly cleaned up |
| `BattleDetector` | `test/integration/battle_analysis_flow_test.exs` | ✅ Yes | Uses helper function to start |
| `CircuitBreaker` | `test/eve_dmv/eve/circuit_breaker_test.exs` | ❌ No | Uses unique names per test - safe |
| `ShipAttributeImporter` | `test/eve_dmv/static_data/ship_attribute_importer_test.exs` | Mixed | Some setup blocks use it |
| `ThreatAnalyzer` | `test/eve_dmv/contexts/threat_assessment/domain/threat_analyzer_test.exs` | ❌ No | Uses ExUnit.Case - no DB access |
| `AlertManagementService` | `test/eve_dmv/contexts/threat_surveillance/alert_management_service_test.exs` | ❌ No | Uses DataCase but has start_link |
| `ThreatAssessmentEngine` | `test/eve_dmv/contexts/threat_surveillance/threat_assessment_engine_test.exs` | ❌ No | Uses DataCase but has start_link |
| `SurveillanceMatchingEngine` | `test/eve_dmv/contexts/threat_surveillance/surveillance_matching_engine_test.exs` | ❌ No | Uses DataCase but has start_link |

### 1.2 Background Task Spawning Locations

**High Risk - `Task.start` (Fire-and-forget, can outlive test):**
| File | Line | Context |
|------|------|---------|
| `lib/eve_dmv/contexts/combat_analysis/domain/battle_analysis_coordinator.ex` | 98 | Background battle analysis |
| `lib/eve_dmv/contexts/combat_analysis/domain/battle_sharing_service.ex` | 98 | Async share creation |
| `lib/eve_dmv/contexts/combat_analysis/domain/fleet_analysis_engine.ex` | 95 | Static data loading |
| `lib/eve_dmv/contexts/market_intelligence/domain/price_service.ex` | 153, 171 | Price updates |

**High Risk - `spawn/spawn_link` (Raw process spawning):**
| File | Line | Context |
|------|------|---------|
| `lib/eve_dmv/contexts/surveillance/domain/alert_system.ex` | 142 | Periodic monitoring |
| `lib/eve_dmv/contexts/surveillance/domain/chain_monitor.ex` | 137, 167, 179, 210 | Chain event processing |

**Medium Risk - `Task.async` (Should be awaited but may not be):**
| File | Lines | Context |
|------|-------|---------|
| `lib/eve_dmv/contexts/character_intelligence/resources/character_stats.ex` | 159-160 | Parallel kill/death counts |
| `lib/eve_dmv/contexts/character_intelligence/domain/data_fetchers/combat_data_fetcher.ex` | 74-75 | Parallel killmail fetching |
| `lib/eve_dmv/contexts/intelligence/core/character_analyzer.ex` | 116, 145, 217-235 | Parallel analysis tasks |
| `lib/eve_dmv/contexts/intelligence/core/threat_assessment_engine.ex` | 96, 170-174 | Threat calculations |
| `lib/eve_dmv/contexts/threat_surveillance/domain/threat_analysis_service.ex` | 74-96 | Threat analysis tasks |
| `lib/eve_dmv/contexts/threat_assessment/analyzers/threat_analyzer.ex` | 119, 128 | Pilot analysis |
| `lib/eve_dmv/contexts/corporation_analysis/domain/corporation_analyzer.ex` | 124 | Corp analysis |
| `lib/eve_dmv/contexts/player_profile/domain/player_analyzer.ex` | 141 | Player analysis |

**Lower Risk - `Task.async_stream` (Bounded, usually awaited):**
- `lib/eve_dmv/contexts/killmail_processing/domain/ingestion_service.ex:119`
- `lib/eve_dmv/contexts/corporation/core/corporation_analyzer.ex:143,231`
- `lib/eve_dmv/contexts/corporation/core/member_activity_analyzer.ex:184`
- `lib/eve_dmv/contexts/corporation/core/member_risk_assessment.ex:76,131`
- `lib/eve_dmv/contexts/surveillance/domain/chain_intelligence_helper.ex:126`
- And 12+ more locations

### 1.3 Tests with `async: true` That Start GenServers

**Finding:** No tests were found that both use `async: true` AND directly call `start_link` on GenServers. This is good - all integration tests that start GenServers properly use `async: false`.

**However**, several tests use `async: true` with `DataCase` and call functions that internally use GenServers or spawn tasks:
- `test/eve_dmv/contexts/threat_surveillance/behavioral_pattern_analyzer_test.exs` - Uses DataCase async
- `test/eve_dmv/contexts/corporation_intelligence/combat_doctrine_analyzer_test.exs` - Uses DataCase async, spawns Task.async in tests
- `test/eve_dmv/contexts/character_intelligence/resources/character_stats_test.exs` - Uses DataCase async, spawns Task.async in tests

### 1.4 Summary of Issues Found

1. **GenServer Tests Using DataCase without async: false:**
   - `AlertManagementService` tests
   - `ThreatAssessmentEngine` tests
   - `SurveillanceMatchingEngine` tests
   - These may cause SQL Sandbox issues if GenServers perform DB operations

2. **Background Tasks That Can Outlive Tests:**
   - `Task.start` in battle analysis coordinator, fleet analysis engine, price service
   - `spawn` in alert_system.ex and chain_monitor.ex
   - These need test mode flags to disable async behavior

3. **Concurrent Tasks in Tests:**
   - Several test files spawn `Task.async` for concurrency testing
   - These must be properly awaited or use shared sandbox mode

---

## Implementation Checklist

### Phase 1: Audit and Diagnosis ✅ COMPLETED
- [x] Inventory all GenServers started in tests
- [x] Document background task spawning locations
- [x] Identify tests with `async: true` that start GenServers

### Phase 2: SQL Sandbox Configuration ✅ COMPLETED
- [x] Update `test/support/data_case.ex` with improved setup
- [x] Add sandbox helper functions
- [x] Test sandbox configuration changes

**Changes Made:**
1. Added 50ms delay in `on_exit` callback before stopping sandbox owner to prevent "owner exited" errors
2. Added `allow_sandbox_access/2` helper for allowing specific processes to share DB connections
3. Added `set_shared_sandbox_mode/0` helper for tests that spawn many processes
4. Added `checkout_sandbox/1` and `checkin_sandbox/0` for explicit sandbox control
5. Updated moduledoc with usage examples for GenServer testing patterns

### Phase 2B: CI Pipeline Updates ✅ COMPLETED

**File:** `.github/workflows/ci.yml`

**Changes Made (2026-01-05):**

1. **Increased PostgreSQL max_connections to 200:**
   ```yaml
   services:
     postgres:
       env:
         POSTGRES_MAX_CONNECTIONS: "200"
   ```
   This prevents "too many clients already" errors during parallel test execution.

2. **Added connection leak monitoring step:**
   - Runs after tests (always, even on failure)
   - Queries `pg_stat_activity` to show active connections by state
   - Warns if more than 50 connections remain active after tests
   - Helps identify connection leaks early in CI

### Phase 3: Fix GenServer Test Patterns
- [ ] Create `test/support/genserver_test_helper.ex`
- [ ] Update `HistoricalFetchWorker` with test mode
- [ ] Update `historical_fetch_flow_test.exs`
- [ ] Update `surveillance_flow_test.exs`
- [ ] Update other affected integration tests

### Phase 4: Connection Pool Configuration
- [ ] Increase test pool size in `config/test.exs`
- [ ] Add ownership and query timeouts
- [x] Update PostgreSQL max_connections in CI (set to 200 in `.github/workflows/ci.yml`)
- [x] Add connection leak monitoring to CI pipeline

### Phase 5: Test Isolation Improvements
- [ ] Add test tags for resource-intensive tests
- [ ] Create `test/support/test_cleanup.ex`
- [ ] Update `test/test_helper.exs` with global cleanup

### Phase 6: Validation and Monitoring
- [ ] Create infrastructure health check
- [ ] Run full test suite and verify no connection errors
- [ ] Update CI pipeline with monitoring

---

## Success Criteria

1. **Zero connection pool exhaustion errors** during test runs
2. **Zero SQL Sandbox owner exit errors**
3. **All integration tests pass consistently** (no flaky tests)
4. **Test suite completes in reasonable time** (< 5 minutes)
5. **Parallel test execution works** for non-integration tests

---

## Estimated Effort

| Phase | Estimated Time |
|-------|---------------|
| Phase 1: Audit | 1-2 hours |
| Phase 2: Sandbox Config | 1 hour |
| Phase 3: GenServer Patterns | 3-4 hours |
| Phase 4: Pool Config | 30 minutes |
| Phase 5: Test Isolation | 2 hours |
| Phase 6: Validation | 1 hour |
| **Total** | **8-10 hours** |

---

## References

- [Ecto SQL Sandbox Documentation](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html)
- [Testing GenServers with Sandbox](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html#module-allowances)
- [Phoenix Testing Best Practices](https://hexdocs.pm/phoenix/testing.html)

---

*Generated: 2026-01-05*
