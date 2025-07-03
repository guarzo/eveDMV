# Cleanup Team Gamma - Test Coverage & Configuration Plan

> **AI Assistant Instructions for Cleanup Gamma Team**
> 
> You are Cleanup Team Gamma, responsible for adding missing test coverage, cleaning up configuration, and fixing security issues. You **depend on Teams Alpha and Beta** completing their foundational work.

## 🎯 **Your Mission**

Add comprehensive test coverage for critical intelligence modules, consolidate duplicate configuration, clean up anti-patterns, and fix unmonitored async tasks.

## ⚠️ **Critical Instructions**

### **Quality Requirements**
After **EVERY SINGLE TASK**, you must run:
```bash
mix format
mix credo
git add -A && git commit -m "test: descriptive message"
```

**Phase End Requirements**
At the end of each phase, you must run and fix any issues:
```bash
mix dialyzer
mix test
```

### **Dependencies**
- **WAIT** for Team Alpha dead code removal (Week 2)
- **WAIT** for Team Beta function refactoring (Week 6)
- **You merge THIRD every Friday** (after Alpha and Beta)
- **Team Delta depends on your test foundation**

### **Test Coverage Safety**
- **NEVER** write tests that depend on external APIs in unit tests
- **ALWAYS** mock external dependencies properly
- **FOCUS** on business logic, not implementation details
- **ENSURE** tests are fast and reliable

### **Merge Coordination**
- Wait for Teams Alpha and Beta completion announcements
- Announce new test files in team chat before creating
- Your test coverage enables safe refactoring for everyone

## 📋 **Phase 1 Tasks (Weeks 3-5) - CRITICAL TEST COVERAGE**

### **Week 3: WAIT FOR TEAM BETA + Environment Setup** ⏸️
**IMPORTANT**: Do not start until Team Beta announces "PHASE 1 COMPLETE"

#### Task 0.1: Configure Unique Development Ports
**IMPORTANT**: Configure unique ports for Cleanup Team Gamma devcontainer to avoid conflicts with other cleanup teams.

**File**: `.devcontainer/devcontainer.json` (Cleanup Gamma worktree)
```json
{
  "name": "EVE DMV Cleanup Gamma Team Dev Container",
  "dockerComposeFile": "../docker-compose.yml",
  "service": "app",
  "workspaceFolder": "/workspace",
  "shutdownAction": "stopCompose",
  "forwardPorts": [4022, 5442, 6392],
  "portsAttributes": {
    "4022": {
      "label": "Phoenix Server (Cleanup Gamma)",
      "onAutoForward": "notify"
    },
    "5442": {
      "label": "PostgreSQL (Cleanup Gamma)"
    },
    "6392": {
      "label": "Redis (Cleanup Gamma)"
    }
  }
}
```

**Environment Variables**: Create `.env.cleanup_gamma`
```bash
PHOENIX_PORT=4022
DATABASE_URL=postgresql://postgres:postgres@localhost:5442/eve_dmv_dev
REDIS_URL=redis://localhost:6392/0
MIX_ENV=dev
```

#### Task 1.2: Assess Test Coverage Gaps
Review the 15+ intelligence modules without tests:
- `advanced_analytics.ex` (775 lines)
- `alert_system.ex`
- `asset_analyzer.ex`
- `chain_connection.ex`
- `chain_monitor.ex` (1103 lines)
- `chain_topology.ex`
- `intelligence_coordinator.ex`
- `intelligence_scoring.ex` (753 lines)
- `performance_optimizer.ex`
- `ship_database.ex`
- `threat_analyzer.ex`
- `wanderer_client.ex`
- `wanderer_sse.ex`

### **Week 4: Core Intelligence Module Tests** 🧪

#### Task 4.1: Create Intelligence Coordinator Tests
**File**: `test/eve_dmv/intelligence/intelligence_coordinator_test.exs`

```elixir
defmodule EveDmv.Intelligence.IntelligenceCoordinatorTest do
  use EveDmv.DataCase, async: true
  use EveDmv.IntelligenceCase

  alias EveDmv.Intelligence.IntelligenceCoordinator

  describe "coordinate_character_analysis/2" do
    test "returns coordinated analysis for valid character" do
      character_id = 123456
      
      # Mock the various analysis modules
      expect_character_analysis_mocks()
      
      assert {:ok, analysis} = IntelligenceCoordinator.coordinate_character_analysis(character_id)
      assert analysis.character_id == character_id
      assert analysis.analysis_timestamp
      assert analysis.comprehensive_analysis
    end

    test "handles missing character gracefully" do
      character_id = 999999
      
      assert {:error, :character_not_found} = 
        IntelligenceCoordinator.coordinate_character_analysis(character_id)
    end
  end

  # Test the core coordination logic without external dependencies
  defp expect_character_analysis_mocks do
    # Mock calls to other intelligence modules
  end
end
```

#### Task 4.2: Create Intelligence Scoring Tests
**File**: `test/eve_dmv/intelligence/intelligence_scoring_test.exs`

Focus on testing the scoring algorithms and business logic:
```elixir
defmodule EveDmv.Intelligence.IntelligenceScoringTest do
  use EveDmv.DataCase, async: true

  alias EveDmv.Intelligence.IntelligenceScoring

  describe "calculate_threat_score/1" do
    test "calculates low threat for new characters" do
      analysis_data = build_analysis_data(
        character_age_days: 30,
        corporation_history_count: 1,
        recent_pvp_activity: :low
      )

      assert IntelligenceScoring.calculate_threat_score(analysis_data) < 3.0
    end

    test "calculates high threat for suspicious patterns" do
      analysis_data = build_analysis_data(
        character_age_days: 10,
        corporation_history_count: 8,
        recent_pvp_activity: :high,
        eviction_participation: true
      )

      assert IntelligenceScoring.calculate_threat_score(analysis_data) > 7.0
    end
  end
end
```

#### Task 4.3: Create Chain Monitor Tests
**File**: `test/eve_dmv/intelligence/chain_monitor_test.exs`

Test the chain monitoring logic:
```elixir
defmodule EveDmv.Intelligence.ChainMonitorTest do
  use EveDmv.DataCase, async: false
  use EveDmv.IntelligenceCase

  alias EveDmv.Intelligence.ChainMonitor

  describe "handle_wanderer_event/3" do
    test "processes system update events correctly" do
      map_id = "test_map_123"
      event_data = %{
        "systems" => [
          %{"id" => 123, "name" => "Test System", "inhabitants" => []}
        ]
      }

      assert :ok = ChainMonitor.handle_wanderer_event(map_id, "system_update", event_data)
    end

    test "processes connection update events correctly" do
      map_id = "test_map_123"
      event_data = %{
        "connections" => [
          %{"from" => 123, "to" => 456, "type" => "wormhole"}
        ]
      }

      assert :ok = ChainMonitor.handle_wanderer_event(map_id, "connection_update", event_data)
    end
  end
end
```

### **Week 5: Utility and Service Tests** 🔧

#### Task 5.1: Create Ship Database Tests
**File**: `test/eve_dmv/intelligence/ship_database_test.exs`

```elixir
defmodule EveDmv.Intelligence.ShipDatabaseTest do
  use ExUnit.Case, async: true

  alias EveDmv.Intelligence.ShipDatabase

  describe "get_ship_category/1" do
    test "returns correct category for known ships" do
      assert ShipDatabase.get_ship_category("Interceptor") == "Frigate"
      assert ShipDatabase.get_ship_category("Heavy Assault Cruiser") == "Cruiser"
    end

    test "returns unknown for unrecognized ships" do
      assert ShipDatabase.get_ship_category("Fake Ship") == "Unknown"
    end
  end

  describe "get_ship_mass/1" do
    test "returns mass for known ships" do
      mass = ShipDatabase.get_ship_mass("Rifter")
      assert is_number(mass)
      assert mass > 0
    end
  end
end
```

#### Task 5.2: Create Alert System Tests
**File**: `test/eve_dmv/intelligence/alert_system_test.exs`

Test alert generation and management:
```elixir
defmodule EveDmv.Intelligence.AlertSystemTest do
  use EveDmv.DataCase, async: false

  alias EveDmv.Intelligence.AlertSystem

  describe "process_character_analysis/1" do
    test "creates high priority alert for high threat characters" do
      analysis = build_analysis(threat_score: 8.5, confidence: 0.9)
      
      assert {:ok, alert} = AlertSystem.process_character_analysis(analysis)
      assert alert.priority == :high
      assert alert.alert_type == :high_threat_character
    end

    test "does not create alert for low threat characters" do
      analysis = build_analysis(threat_score: 2.1, confidence: 0.8)
      
      assert {:ok, nil} = AlertSystem.process_character_analysis(analysis)
    end
  end
end
```

**PHASE 1 END CHECKPOINT**:
```bash
mix dialyzer  # Check for test-related issues
mix test      # All new tests should pass
```

## 📋 **Phase 2 Tasks (Weeks 6-8) - CONFIGURATION CLEANUP**

### **Week 6: Remove Duplicate Configuration** ⚙️

#### Task 6.1: Consolidate Wanderer Configuration
**Files**: `config/dev.exs` and `config/runtime.exs`

Remove duplicate wanderer kills configuration by consolidating to runtime.exs:

```elixir
# In config/runtime.exs - keep this version
config :eve_dmv, :wanderer_kills,
  enabled: System.get_env("WANDERER_KILLS_ENABLED", "true") == "true",
  sse_url: System.get_env("WANDERER_KILLS_SSE_URL", "http://host.docker.internal:4004/api/v1/kills/stream"),
  base_url: System.get_env("WANDERER_KILLS_BASE_URL", "http://host.docker.internal:4004"),
  ws_url: System.get_env("WANDERER_KILLS_WS_URL", "ws://host.docker.internal:4004/socket"),
  wanderer_api_token: System.get_env("WANDERER_API_TOKEN")
```

Remove the duplicate section from `config/dev.exs` (lines 125-131).

#### Task 6.2: Consolidate Database Configuration
**Files**: `config/config.exs` and `config/dev.exs`

Remove duplicate database pool configuration from config.exs since it's overridden in dev.exs anyway.

#### Task 6.3: Remove Unused Configuration Keys
**File**: `config/config.exs`

Remove unused configuration that was identified:
```elixir
# Remove this unused line ~100:
# zkillboard_sse_url: System.get_env("ZKILLBOARD_SSE_URL", "wss://zkillboard.com/websocket/")
```

### **Week 7: Fix Async Task Supervision** ⚡

#### Task 7.1: Fix Cache Warmer Tasks
**File**: `lib/eve_dmv/database/cache_warmer.ex`

Replace unmonitored Task.async calls with supervised tasks:
```elixir
# Add to application.ex supervision tree
{Task.Supervisor, name: EveDmv.TaskSupervisor}

# In cache_warmer.ex, replace lines 116-120:
defp warm_all_caches_supervised do
  tasks = [
    Task.Supervisor.async(EveDmv.TaskSupervisor, fn -> warm_hot_characters() end),
    Task.Supervisor.async(EveDmv.TaskSupervisor, fn -> warm_active_systems() end),
    Task.Supervisor.async(EveDmv.TaskSupervisor, fn -> warm_recent_killmails() end),
    Task.Supervisor.async(EveDmv.TaskSupervisor, fn -> warm_frequent_items() end),
    Task.Supervisor.async(EveDmv.TaskSupervisor, fn -> warm_alliance_stats() end)
  ]
  
  Task.Supervisor.await_many(tasks, 30_000)
end
```

#### Task 7.2: Fix Re-enrichment Worker Tasks
**File**: `lib/eve_dmv/enrichment/re_enrichment_worker.ex`

Replace unmonitored tasks (lines 185-186):
```elixir
# Replace with supervised tasks
defp perform_parallel_updates(config) do
  price_task = Task.Supervisor.async(EveDmv.TaskSupervisor, fn -> 
    perform_price_update(config) 
  end)
  name_task = Task.Supervisor.async(EveDmv.TaskSupervisor, fn -> 
    perform_name_update(config) 
  end)
  
  Task.await(price_task, 30_000)
  Task.await(name_task, 30_000)
end
```

#### Task 7.3: Fix Intelligence Performance Optimizer
**File**: `lib/eve_dmv/intelligence/performance_optimizer.ex`

Replace unmonitored tasks (lines 98-100 and 186-188):
```elixir
defp preload_data_parallel(character_ids) do
  tasks = [
    Task.Supervisor.async(EveDmv.TaskSupervisor, fn -> 
      preload_character_stats(character_ids) 
    end),
    Task.Supervisor.async(EveDmv.TaskSupervisor, fn -> 
      preload_vetting_data(character_ids) 
    end),
    Task.Supervisor.async(EveDmv.TaskSupervisor, fn -> 
      preload_killmail_data(character_ids) 
    end)
  ]
  
  Task.Supervisor.await_many(tasks, 60_000)
end
```

### **Week 8: Fix TypeSpecs and Security** 🔒

#### Task 8.1: Fix Overly Broad TypeSpecs
Replace `any()` typespecs with specific types:

**File**: `lib/eve_dmv/eve/reliability_config.ex`
```elixir
# Line 199 - Replace:
@spec update_config(atom(), any()) :: :ok
# With:
@spec update_config(atom(), keyword() | map()) :: :ok
```

**File**: `lib/eve_dmv/eve/circuit_breaker.ex`
```elixir
# Line 58 - Replace:
@spec call(atom(), function(), keyword()) :: {:ok, any()} | {:error, any()}
# With:
@spec call(atom(), (() -> term()), keyword()) :: {:ok, term()} | {:error, atom() | binary()}
```

Continue for all files with overly broad `any()` types.

#### Task 8.2: Fix Security Issues
Add proper validation and sanitization:

**File**: `lib/eve_dmv/eve/esi_request_client.ex`
```elixir
# Add function to sanitize logs (lines 186-192)
defp log_request_details(method, url, opts) do
  # Remove sensitive data before logging
  safe_opts = 
    opts
    |> Keyword.delete(:auth_token)
    |> Keyword.delete(:api_key)
    
  Logger.debug("ESI Request: #{method} #{url}", safe_opts: safe_opts)
end
```

**PHASE 2 END CHECKPOINT**:
```bash
mix dialyzer  # Should show improved typespecs
mix test      # All tests including new supervision should pass
```

## 📋 **Phase 3 Tasks (Weeks 9-10) - FINAL TESTING & PATTERNS**

### **Week 9: Integration Tests** 🔗

#### Task 9.1: Create Intelligence Integration Tests
**File**: `test/integration/intelligence_workflow_test.exs`

Test end-to-end intelligence workflows:
```elixir
defmodule EveDmv.IntelligenceWorkflowTest do
  use EveDmv.DataCase, async: false
  use EveDmv.IntelligenceCase

  describe "complete character intelligence workflow" do
    test "processes character from analysis to recommendations" do
      character_id = insert_test_character()
      
      # This tests the full workflow
      assert {:ok, result} = EveDmv.Intelligence.process_character_intelligence(character_id)
      
      assert result.character_analysis
      assert result.vetting_analysis
      assert result.correlations
      assert result.recommendations
    end
  end
end
```

#### Task 9.2: Create Performance Tests
**File**: `test/performance/intelligence_performance_test.exs`

Test performance of critical paths:
```elixir
defmodule EveDmv.IntelligencePerformanceTest do
  use ExUnit.Case
  
  @tag :performance
  test "character analysis completes within acceptable time" do
    character_id = 123456
    
    {time_microseconds, _result} = :timer.tc(fn ->
      EveDmv.Intelligence.IntelligenceCoordinator.coordinate_character_analysis(character_id)
    end)
    
    # Should complete within 5 seconds
    assert time_microseconds < 5_000_000
  end
end
```

### **Week 10: Documentation & Final Tests** 📚

#### Task 10.1: Create Test Utilities
**File**: `test/support/intelligence_test_utils.ex`

Create shared test utilities:
```elixir
defmodule EveDmv.IntelligenceTestUtils do
  @moduledoc """
  Shared utilities for intelligence module testing
  """

  def build_analysis_data(opts \\ []) do
    defaults = [
      character_age_days: 365,
      corporation_history_count: 2,
      recent_pvp_activity: :medium,
      eviction_participation: false
    ]
    
    Keyword.merge(defaults, opts) |> Enum.into(%{})
  end

  def expect_character_analysis_mocks do
    # Common mock setup for character analysis
  end
end
```

#### Task 10.2: Add Property-Based Tests
**File**: `test/eve_dmv/intelligence/intelligence_scoring_property_test.exs`

Add property-based tests for scoring logic:
```elixir
defmodule EveDmv.Intelligence.IntelligenceScoringPropertyTest do
  use ExUnit.Case
  use ExUnitProperties

  alias EveDmv.Intelligence.IntelligenceScoring

  property "threat score is always between 0 and 10" do
    check all character_age <- positive_integer(),
              corp_history_count <- non_negative_integer(),
              pvp_activity <- member_of([:low, :medium, :high]) do
      
      analysis_data = %{
        character_age_days: character_age,
        corporation_history_count: corp_history_count,
        recent_pvp_activity: pvp_activity
      }
      
      score = IntelligenceScoring.calculate_threat_score(analysis_data)
      assert score >= 0.0
      assert score <= 10.0
    end
  end
end
```

**PHASE 3 END CHECKPOINT**:
```bash
mix dialyzer  # Clean output with proper types
mix test      # All tests passing including integration tests
mix test --cover # Check coverage improvement
```

## 📋 **Phase 4 Tasks (Weeks 11-12) - VERIFICATION & DOCS**

### **Week 11: Test Coverage Verification** ✅

#### Task 11.1: Measure Coverage Improvement
```bash
mix test --cover
# Target: 70%+ overall coverage
# Critical modules should have 80%+ coverage
```

#### Task 11.2: Add Missing Edge Case Tests
Fill in any remaining gaps in test coverage for critical business logic.

### **Week 12: Documentation & Final Cleanup** 📖

#### Task 12.1: Fix Skipped Tests
**Priority**: Critical for test coverage

Fix all skipped tests to ensure comprehensive test coverage:

**Files with skipped tests**:
- `test/integration/character_analysis_integration_test.exs` - Remove `@moduletag :skip`
- `test/integration/intelligence_integration_test.exs` - Remove `@moduletag :skip` 
- `test/eve_dmv/intelligence/character_analyzer_test.exs` - Remove `@moduletag :skip`
- `test/eve_dmv/intelligence/home_defense_analyzer_test.exs` - Remove `@moduletag :skip`
- `test/eve_dmv_web/live/kill_feed_live_test.exs` - Fix individual `@tag :skip` tests
- `test/eve_dmv/eve/circuit_breaker_test.exs` - Remove `@describetag :skip` from test groups
- `test/eve_dmv_web/live/character_intelligence_live_test.exs` - Fix individual `@tag :skip` tests
- `test/eve_dmv_web/live/wh_vetting_live_test.exs` - Fix individual `@tag :skip` tests

For each skipped test:
1. **IDENTIFY** why it was skipped (missing mocks, external dependencies, etc.)
2. **FIX** underlying issues (add proper mocks, stub external calls)
3. **REMOVE** skip tags
4. **VERIFY** tests pass consistently

#### Task 12.2: Implement Employment Gap Detection (TODO Item)
**Location**: `lib/eve_dmv/intelligence/wh_vetting_analyzer.ex:958`  
**Priority**: Medium Priority (security feature)  
**Task**: Implement employment gap detection when ESI is available  
**Details**: Currently returns empty array for employment gaps. Need ESI integration to fetch employment history and detect suspicious gaps.

```elixir
# Add proper implementation when ESI integration is ready
defp detect_employment_gaps(character_id) do
  case EveDmv.Eve.EsiClient.get_character_employment_history(character_id) do
    {:ok, employment_history} ->
      analyze_employment_gaps(employment_history)
    {:error, :service_unavailable} ->
      # ESI not available yet - return empty for now
      []
    {:error, _reason} ->
      []
  end
end

defp analyze_employment_gaps(employment_history) do
  # Implement gap detection logic
  # Look for suspicious gaps between employment records
  # Flag gaps longer than 30 days as potential red flags
end
```

#### Task 12.3: Document Test Patterns
Create `test/README.md` documenting testing patterns and utilities.

#### Task 12.4: Final Verification
```bash
mix dialyzer  # Zero warnings
mix test      # 100% pass rate with no skipped tests
mix credo     # Clean code metrics
```

**FINAL CHECKPOINT**:
```bash
mix dialyzer  # Perfect type safety
mix test --cover # Strong test coverage
mix credo     # Clean quality metrics
```

## 🚨 **Safety Procedures**

### **When Writing Tests**
1. **MOCK EXTERNAL SERVICES** - never hit real APIs in tests
2. **USE async: true** whenever possible for speed
3. **TEST BEHAVIOR, NOT IMPLEMENTATION** 
4. **KEEP TESTS FAST** - under 100ms each

### **When Fixing Async Tasks**
1. **VERIFY SUPERVISION TREE** changes in application.ex
2. **TEST SUPERVISOR RESTART** scenarios
3. **ENSURE PROPER TIMEOUTS** for all async operations
4. **MONITOR MEMORY USAGE** with supervised tasks

### **When Changing Configuration**
1. **TEST IN ALL ENVIRONMENTS** (dev, test, prod)
2. **VERIFY NO RUNTIME ERRORS** on application start
3. **CHECK BACKWARDS COMPATIBILITY** with existing deployments
4. **DOCUMENT ENVIRONMENT VARIABLE CHANGES**

## ✅ **Success Criteria**

By the end of 12 weeks, you must achieve:
- [ ] **15+ new test files** for intelligence modules
- [ ] **70%+ overall test coverage** 
- [ ] **All async tasks properly supervised**
- [ ] **Zero duplicate configuration**
- [ ] **All any() typespecs replaced** with specific types
- [ ] **All security issues fixed** (no credential logging)
- [ ] **Clean dialyzer output** with proper supervision
- [ ] **Fast, reliable test suite** (all tests under 100ms)
- [ ] **All skipped tests fixed** and passing
- [ ] **Employment Gap Detection** implemented (TODO item)

**Final Deliverable**: A well-tested, properly configured, and securely designed codebase with comprehensive test coverage and proper OTP supervision.

Remember: **You are building the safety net that enables confident development. Good tests and proper supervision make risky changes safe.**