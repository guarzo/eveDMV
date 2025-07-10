# Systematic Combat Log & Fitting Persistence Fix Plan

## Current State Analysis

### 🔍 Root Cause Investigation

**Problem 1: Combat Log Parser Not Working**
- Enhanced parser works in isolation (tested in IEx)
- Database shows old format: `type: :combat` instead of `type: :damage_dealt`
- 106 events parsed but all generic `:combat` type
- Issue: Combat log resource may not be using enhanced parser despite code changes

**Problem 2: Fitting Persistence Failing**
- Fittings disappear when clicking between ships
- LiveView state management issue
- Fixed code but problem persists

### 🎯 Systematic Debugging Approach

## Phase 1: Diagnostic Testing (30 minutes)

### Step 1.1: Verify Parser Integration
**Goal**: Confirm which parser is actually being called

**Tests to run:**
```bash
# Test 1: Check if enhanced parser module is loaded
iex -S mix
> EveDmv.Contexts.BattleAnalysis.Domain.EnhancedCombatLogParser.__info__(:functions)

# Test 2: Check if combat log resource imports are correct
> EveDmv.Contexts.BattleAnalysis.Resources.CombatLog.__info__(:compile)

# Test 3: Direct parser test with real log content
> {:ok, content} = File.read("/workspace/tmp/message2.txt")
> EveDmv.Contexts.BattleAnalysis.Domain.EnhancedCombatLogParser.parse_combat_log(content)
```

### Step 1.2: Database State Verification
**Goal**: Check if old logs are cached/interfering

**Actions:**
1. Delete all existing combat logs from database
2. Upload fresh log and trace execution
3. Check if parse action is actually called

### Step 1.3: LiveView State Debugging
**Goal**: Identify exact fitting persistence failure point

**Tests:**
1. Add debug logging to `analyze_ship_performance`
2. Trace fitting data through each step
3. Verify socket assignment state

## Phase 2: Root Cause Fixes (60 minutes)

### Step 2.1: Combat Log Parser Fix

**Hypothesis 1: Module Not Reloaded**
```bash
# Solution: Force module reload
mix compile --force
# Restart any running processes
```

**Hypothesis 2: Import Issue**
```elixir
# Check: Does combat_log.ex actually import enhanced parser?
# File: lib/eve_dmv/contexts/battle_analysis/resources/combat_log.ex:92
# Expected: EveDmv.Contexts.BattleAnalysis.Domain.EnhancedCombatLogParser.parse_combat_log
```

**Hypothesis 3: Parse Action Not Triggered**
```elixir
# Check: Is :parse action called after upload?
# Add logging to combat_log.ex parse action
```

### Step 2.2: Create Comprehensive Tests

**Test File**: `test/eve_dmv/contexts/battle_analysis/enhanced_combat_log_parser_test.exs`

```elixir
defmodule EveDmv.Contexts.BattleAnalysis.Domain.EnhancedCombatLogParserTest do
  use ExUnit.Case
  alias EveDmv.Contexts.BattleAnalysis.Domain.EnhancedCombatLogParser
  
  describe "parse_combat_log/2" do
    test "parses outgoing damage correctly" do
      content = "04:28:01\tCombat\t84 to Hornet II[GI.N](Hornet II) - Scourge Rage Rocket - Hits"
      
      {:ok, result} = EnhancedCombatLogParser.parse_combat_log(content)
      
      assert length(result.events) == 1
      event = List.first(result.events)
      assert event.type == :damage_dealt
      assert event.damage == 84
      assert event.target == "Hornet II"
      assert event.weapon == "Scourge Rage Rocket"
      assert event.hit_quality == :normal
    end
    
    test "parses tackle attempts correctly" do
      content = "04:27:24\tCombat\tWarp scramble attempt from you to"
      
      {:ok, result} = EnhancedCombatLogParser.parse_combat_log(content)
      
      assert length(result.events) == 1
      event = List.first(result.events)
      assert event.type == :tackle_attempt
      assert event.module == "Warp Scrambler"
    end
    
    test "generates tactical analysis" do
      content = """
      04:28:01\tCombat\t84 to Hornet II[GI.N](Hornet II) - Scourge Rage Rocket - Hits
      04:28:04\tCombat\t278 to Darin Raltin[GI.N](Porpoise) - Scourge Rage Rocket - Smashes
      """
      
      {:ok, result} = EnhancedCombatLogParser.parse_combat_log(content)
      
      assert result.tactical_analysis.damage_application.total_shots == 2
      assert result.tactical_analysis.damage_application.average_application > 0
      assert length(result.recommendations) > 0
    end
  end
end
```

**Test File**: `test/eve_dmv_web/live/battle_analysis_live_test.exs`

```elixir
defmodule EveDmvWeb.BattleAnalysisLiveTest do
  use EveDmvWeb.ConnCase
  import Phoenix.LiveViewTest
  
  describe "fitting persistence" do
    test "fitting data persists when switching between ships" do
      # Setup battle with multiple ships
      # Import fitting for ship A
      # Click on ship B
      # Click back on ship A
      # Assert fitting is still there
    end
  end
  
  describe "combat log upload" do
    test "uses enhanced parser for new uploads" do
      # Upload real combat log
      # Assert events have correct types (:damage_dealt, :tackle_attempt)
      # Assert tactical analysis is present
    end
  end
end
```

### Step 2.3: Systematic Issue Resolution

**Issue 1: Parser Integration**
```elixir
# File: lib/eve_dmv/contexts/battle_analysis/resources/combat_log.ex
# Line 92: Verify this line exists and is correct:
case EveDmv.Contexts.BattleAnalysis.Domain.EnhancedCombatLogParser.parse_combat_log(content, pilot_name: log.pilot_name) do

# Add debug logging:
Logger.info("Using enhanced parser for combat log #{log.id}")
```

**Issue 2: Parse Action Triggering**
```elixir
# File: lib/eve_dmv_web/live/battle_analysis_live.ex
# In upload_log event handler, add:
send(self(), {:parse_log, combat_log.id})

# Add handle_info:
def handle_info({:parse_log, log_id}, socket) do
  case Ash.update(log, :parse) do
    {:ok, updated_log} -> 
      Logger.info("Successfully parsed log #{log_id}")
    {:error, error} -> 
      Logger.error("Failed to parse log #{log_id}: #{inspect(error)}")
  end
  {:noreply, socket}
end
```

**Issue 3: Fitting Persistence**
```elixir
# File: lib/eve_dmv_web/live/battle_analysis_live.ex
# Add debug logging to analyze_ship_performance:

def handle_event("analyze_ship_performance", params, socket) do
  Logger.info("Analyzing ship performance: #{inspect(params)}")
  Logger.info("Current selected ship: #{inspect(socket.assigns.selected_ship)}")
  
  # ... existing code ...
  
  Logger.info("Fitting data found: #{inspect(existing_fitting)}")
  Logger.info("Final ship data: #{inspect(ship_data)}")
  
  # ... rest of function
end
```

## Phase 3: Integration Testing (30 minutes)

### Step 3.1: End-to-End Test
1. Delete all combat logs from database
2. Upload fresh combat log
3. Verify enhanced parser output in database
4. Test fitting persistence through UI

### Step 3.2: Regression Testing
1. Test old functionality still works
2. Verify no breaking changes to existing features
3. Check performance impact

## Phase 4: Validation & Documentation (15 minutes)

### Step 4.1: Success Criteria
- [ ] Combat logs parse with correct event types (`:damage_dealt`, etc.)
- [ ] Tactical analysis data appears in database
- [ ] Fittings persist when switching ships
- [ ] All tests pass
- [ ] No performance regression

### Step 4.2: Documentation Update
- Update combat log parser documentation
- Add tactical analysis examples
- Document fitting persistence behavior

## Execution Order

### Immediate Actions (Next 15 minutes)
1. **Run diagnostic tests** to confirm which parser is actually being used
2. **Check import statements** in combat_log.ex 
3. **Add debug logging** to trace execution flow
4. **Test in IEx** with actual log file content

### Priority Fixes (Next 45 minutes)
1. **Fix parser integration** - ensure enhanced parser is actually called
2. **Fix parse action triggering** - ensure logs are re-parsed after upload
3. **Fix fitting persistence** - add proper state management

### Validation (Final 15 minutes)
1. **Upload test log** and verify correct parsing
2. **Test fitting persistence** through UI
3. **Run test suite** to ensure no regressions

## Risk Mitigation

**Risk 1: Parser integration requires deeper changes**
- Mitigation: Fall back to fixing old parser with enhanced patterns

**Risk 2: State management issues are complex**
- Mitigation: Implement simpler persistence mechanism using ETS or GenServer

**Risk 3: Database schema incompatibility**
- Mitigation: Add migration to update existing logs

## Success Metrics

1. **Parser Success**: `type: :damage_dealt` appears in database logs
2. **Tactical Analysis**: `tactical_analysis` field populated with real data
3. **Fitting Persistence**: Fitting data survives ship switching 100% of time
4. **Performance**: No degradation in upload/parsing speed

This systematic approach will identify the exact failure points and fix them methodically rather than guessing at solutions.