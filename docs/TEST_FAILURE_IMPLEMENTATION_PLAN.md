# Test Failure Implementation Plan

**Date:** 2026-01-05
**Last Updated:** 2026-01-05 16:05 UTC
**Current Status:** 270 failures remaining (down from 757)
**Total Tests:** 1,669 tests (13 excluded)

---

## Executive Summary

After initial fixes, we've reduced failures from 757 to 270. The remaining failures are distributed across multiple test modules with different root causes.

### Failure Distribution by Test File

| Rank | Test File | Failures | Category |
|------|-----------|----------|----------|
| 1 | Corporation.ApiTest | 63 | API function exports |
| 2 | Intelligence.ApiTest | 59 | API function exports |
| 3 | ShipPerformanceAnalyzerTest | 16 | Missing data/mocks |
| 4 | MarketIntelligence.ApiTest | 12 | API function exports |
| 5 | DetectionServiceTest | 12 | Service integration |
| 6 | VulnerabilityScannerTest | 10 | Test data fixtures |
| 7 | ThreatAnalyzerTest | 10 | GenServer lifecycle |
| 8 | SystemAnalysis.ApiTest | 9 | API function exports |
| 9 | FleetOperations.ApiTest | 9 | API function exports |
| 10 | BehavioralPatternAnalyzerTest | 8 | Database queries |
| 11 | KillmailProcessing.ApiTest | 7 | API function exports |
| 12 | CombatIntelligence.ApiTest | 7 | API function exports |
| 13 | IntelligenceScoringTest | 6 | DB connection issues |
| 14 | CharacterMetricsTest | 6 | DB connection issues |
| 15 | Surveillance.ApiTest | 6 | GenServer lifecycle |
| 16 | CorporationIntelligence.ApiTest | 6 | API function exports |
| 17+ | Various others | ~24 | Mixed |

---

## Root Cause Analysis

### Category 1: API Function Export Tests (~150 failures)
**Affected Tests:** Corporation.ApiTest, Intelligence.ApiTest, MarketIntelligence.ApiTest, SystemAnalysis.ApiTest, FleetOperations.ApiTest, KillmailProcessing.ApiTest, CombatIntelligence.ApiTest, CorporationIntelligence.ApiTest

**Root Cause:** Tests check `function_exported?/3` but modules not loaded before check.

**Pattern:**
```elixir
# Failing pattern
test "exports some_function/1" do
  assert function_exported?(Api, :some_function, 1)
end
```

**Fix:** Add `Code.ensure_loaded!/1` in setup block (already fixed for KillmailProcessing.ApiTest):
```elixir
setup do
  Code.ensure_loaded!(Api)
  :ok
end
```

**Estimated Fix Time:** 1 hour (copy pattern to all affected test files)

### Category 2: Test Data Fixtures (~26 failures)
**Affected Tests:** VulnerabilityScannerTest, ThreatAnalyzerTest

**Root Cause:** Tests provide incomplete entity data structures missing required keys.

**Fix:** Create comprehensive test fixture helpers or make production code more defensive.

**Estimated Fix Time:** 2 hours

### Category 3: GenServer Lifecycle (~11 failures)
**Affected Tests:** Surveillance.ApiTest, some ThreatAssessment tests

**Root Cause:** GenServers not properly started/stopped between tests.

**Fix:** Robust setup/teardown with Process.alive? checks.

**Estimated Fix Time:** 1 hour

### Category 4: Database/Service Integration (~28 failures)
**Affected Tests:** ShipPerformanceAnalyzerTest, DetectionServiceTest, BehavioralPatternAnalyzerTest

**Root Cause:**
- SQL queries referencing wrong column names
- Missing mock data
- Service dependencies not available

**Fix:** Update queries, add proper mocks, or skip integration tests.

**Estimated Fix Time:** 2-3 hours

### Category 5: DB Connection Pool Exhaustion (~12 failures)
**Affected Tests:** IntelligenceScoringTest, CharacterMetricsTest

**Root Cause:** Too many concurrent database connections during test runs.

**Fix:**
- Reduce async test parallelism
- Add connection pool configuration for tests
- Use `async: false` for problematic tests

**Estimated Fix Time:** 30 minutes

---

## Implementation Phases

### Phase 1: API Function Export Fixes (HIGHEST IMPACT - ~150 tests)
**Time:** 1 hour

Add `Code.ensure_loaded!/1` to all API test files:

```bash
# Files to modify:
test/eve_dmv/contexts/corporation/api_test.exs
test/eve_dmv/contexts/intelligence/api_test.exs
test/eve_dmv/contexts/market_intelligence/api_test.exs
test/eve_dmv/contexts/system_analysis/api_test.exs
test/eve_dmv/contexts/fleet_operations/api_test.exs
test/eve_dmv/contexts/combat_intelligence/api_test.exs
test/eve_dmv/contexts/corporation_intelligence/api_test.exs
```

**Pattern to apply:**
```elixir
describe "API module exports" do
  setup do
    Code.ensure_loaded!(Api)
    :ok
  end

  # ... existing tests
end
```

### Phase 2: Test Data Fixture Improvements (~26 tests)
**Time:** 2 hours

Create `test/support/threat_assessment_fixtures.ex` with complete entity data builders.

### Phase 3: GenServer Lifecycle Fixes (~11 tests)
**Time:** 1 hour

Update setup blocks to handle GenServer lifecycle properly.

### Phase 4: Database Query Fixes (~28 tests)
**Time:** 2-3 hours

Fix SQL queries and add proper test data/mocks.

### Phase 5: Connection Pool Configuration (~12 tests)
**Time:** 30 minutes

Configure test database pool and reduce concurrency.

---

## Quick Win: Phase 1 Implementation

Since Phase 1 fixes ~150 tests with a simple pattern, here's the exact change needed:

### Step 1: Find all API test files with export tests
```bash
grep -r "function_exported?" test/eve_dmv/contexts/*/api_test.exs
```

### Step 2: Add setup block to each describe
```elixir
describe "API module exports" do
  setup do
    Code.ensure_loaded!(YourApiModule)
    :ok
  end

  # existing tests...
end
```

### Step 3: Verify
```bash
MIX_ENV=test mix test test/eve_dmv/contexts/corporation/api_test.exs
```

---

## Verification Checklist

After implementing all phases:

- [ ] Phase 1: `MIX_ENV=test mix test test/eve_dmv/contexts/*/api_test.exs` - All pass
- [ ] Phase 2: `MIX_ENV=test mix test test/eve_dmv/contexts/threat_assessment/` - All pass
- [ ] Phase 3: `MIX_ENV=test mix test test/eve_dmv/contexts/surveillance/` - All pass
- [ ] Phase 4: `MIX_ENV=test mix test test/eve_dmv/contexts/battle_analysis/` - All pass
- [ ] Phase 5: Full suite passes with `MIX_ENV=test mix test`

---

## Estimated Total Effort

| Phase | Description | Tests Fixed | Time |
|-------|-------------|-------------|------|
| 1 | API function exports | ~150 | 1 hour |
| 2 | Test data fixtures | ~26 | 2 hours |
| 3 | GenServer lifecycle | ~11 | 1 hour |
| 4 | Database/service fixes | ~28 | 2-3 hours |
| 5 | Connection pool config | ~12 | 30 min |
| **Total** | | **~227** | **6.5-7.5 hours** |

Note: Some tests may have overlapping issues, so actual fix count may differ.

---

## Progress Tracking

### Completed Fixes
- [x] BehavioralPatternAnalyzer SQL query fix (victim column)
- [x] ThreatAnalyzerTest match? syntax fix
- [x] ExtendedHistoricalFetcher recursive call fix
- [x] KillmailProcessing.ApiTest Code.ensure_loaded! fix
- [x] ThreatAnalyzerTest GenServer setup improvement
- [x] DomainEvents.KillmailEnriched struct fields
- [x] CharacterStats Ash.Expr import

### Remaining Work
- [ ] Phase 1: Add Code.ensure_loaded! to 7+ API test files
- [ ] Phase 2: Create threat assessment fixtures
- [ ] Phase 3: Fix remaining GenServer lifecycle issues
- [ ] Phase 4: Fix database queries and add mocks
- [ ] Phase 5: Configure test connection pool
