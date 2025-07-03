# Cleanup Team Beta - Function Refactoring & Over-Engineering Plan

> **AI Assistant Instructions for Cleanup Beta Team**
> 
> You are Cleanup Team Beta, responsible for refactoring oversized functions, extracting repeated patterns, and fixing over-engineering issues. You **depend on Team Alpha** completing dead code removal first.

## 🎯 **Your Mission**

Refactor large functions into smaller, focused functions. Extract repeated patterns into utility modules. Fix over-engineering and simplify complex code structures.

## ⚠️ **Critical Instructions**

### **Quality Requirements**
After **EVERY SINGLE TASK**, you must run:
```bash
mix format
mix credo
git add -A && git commit -m "refactor: descriptive message"
```

**Phase End Requirements**
At the end of each phase, you must run and fix any issues:
```bash
mix dialyzer
mix test
```

### **Dependencies**
- **WAIT** for Team Alpha to complete dead code removal (Week 2)
- **You merge SECOND every Friday** (after Team Alpha)
- **Teams Gamma and Delta depend on your refactoring work**

### **Refactoring Safety**
- **NEVER** change function signatures without checking all callers
- **ALWAYS** extract to private functions first, then consider modules
- **PRESERVE** existing functionality exactly - no behavior changes
- **TEST** thoroughly after each large function split

### **Merge Coordination**
- Wait for Team Alpha's "PHASE 1 COMPLETE" announcement
- Announce major refactorings in team chat before starting
- Your refactoring affects how other teams organize code

## 📋 **Phase 1 Tasks (Weeks 3-4) - LARGE FUNCTION REFACTORING**

### **Week 3: WAIT FOR TEAM ALPHA + Environment Setup** ⏸️
**IMPORTANT**: Do not start until Team Alpha announces "PHASE 1 COMPLETE"

#### Task 0.1: Configure Unique Development Ports
**IMPORTANT**: Configure unique ports for Cleanup Team Beta devcontainer to avoid conflicts with other cleanup teams.

**File**: `.devcontainer/devcontainer.json` (Cleanup Beta worktree)
```json
{
  "name": "EVE DMV Cleanup Beta Team Dev Container",
  "dockerComposeFile": "../docker-compose.yml",
  "service": "app",
  "workspaceFolder": "/workspace",
  "shutdownAction": "stopCompose",
  "forwardPorts": [4021, 5441, 6391],
  "portsAttributes": {
    "4021": {
      "label": "Phoenix Server (Cleanup Beta)",
      "onAutoForward": "notify"
    },
    "5441": {
      "label": "PostgreSQL (Cleanup Beta)"
    },
    "6391": {
      "label": "Redis (Cleanup Beta)"
    }
  }
}
```

**Environment Variables**: Create `.env.cleanup_beta`
```bash
PHOENIX_PORT=4021
DATABASE_URL=postgresql://postgres:postgres@localhost:5441/eve_dmv_dev
REDIS_URL=redis://localhost:6391/0
MIX_ENV=dev
```

#### Task 1.2: Analyze Refactoring Targets
Once Team Alpha is done, review the largest functions:
- `wh_vetting_analyzer.ex` - `analyze_character/2` (79 lines)
- `home_defense_analyzer.ex` - `analyze_corporation/2` (78 lines)
- `member_activity_analyzer.ex` - `calculate_member_engagement/1` (79 lines)
- `member_activity_analyzer.ex` - `analyze_activity_trends/2` (58 lines)
- `wh_fleet_analyzer.ex` - `analyze_fleet_composition/2` (52 lines)

### **Week 4: Split Oversized Functions** ✂️

#### Task 4.1: Refactor WHVetting Analyzer
**File**: `lib/eve_dmv/intelligence/wh_vetting_analyzer.ex`

Split `analyze_character/2` (lines 22-101) into focused functions:
```elixir
def analyze_character(character_id, requested_by_id \\ nil) do
  with {:ok, character_info} <- validate_and_get_character_info(character_id),
       {:ok, analysis_data} <- collect_all_analysis_data(character_id),
       {:ok, scores} <- calculate_all_scores(analysis_data),
       {:ok, recommendation} <- generate_recommendation(scores) do
    create_vetting_record(character_id, character_info, analysis_data, scores, recommendation, requested_by_id)
  end
end

# Extract these private functions:
defp validate_and_get_character_info(character_id) do
  # Lines 28-45 from original function
end

defp collect_all_analysis_data(character_id) do
  # Lines 46-70 from original function
end

defp calculate_all_scores(analysis_data) do
  # Lines 71-85 from original function
end

defp generate_recommendation(scores) do
  # Lines 86-95 from original function
end
```

#### Task 4.2: Refactor Home Defense Analyzer
**File**: `lib/eve_dmv/intelligence/home_defense_analyzer.ex`

Split `analyze_corporation/2` (lines 21-99) into focused functions:
```elixir
def analyze_corporation(corporation_id, options \\ []) do
  with {:ok, corp_data} <- get_corporation_data(corporation_id),
       {:ok, member_data} <- collect_member_data(corporation_id, options),
       {:ok, activity_analysis} <- analyze_activity_patterns(member_data),
       {:ok, defense_metrics} <- calculate_defense_metrics(activity_analysis) do
    generate_corporation_analysis(corp_data, defense_metrics, options)
  end
end

# Extract these private functions with clear responsibilities
```

#### Task 4.3: Refactor Member Activity Analyzer  
**File**: `lib/eve_dmv/intelligence/member_activity_analyzer.ex`

Split `calculate_member_engagement/1` (lines 698-777):
```elixir
def calculate_member_engagement(member_data) do
  %{
    killmail_engagement: calculate_killmail_engagement(member_data),
    fleet_engagement: calculate_fleet_engagement(member_data),
    communication_engagement: calculate_communication_engagement(member_data),
    overall_score: calculate_overall_engagement_score(member_data)
  }
end

# Extract engagement calculation modules
```

Split `analyze_activity_trends/2` (lines 782-840):
```elixir
def analyze_activity_trends(member_id, timeframe) do
  with {:ok, activity_data} <- get_activity_data(member_id, timeframe),
       {:ok, trend_analysis} <- calculate_trend_metrics(activity_data),
       {:ok, patterns} <- identify_activity_patterns(activity_data) do
    generate_trend_summary(trend_analysis, patterns)
  end
end
```

**PHASE 1 END CHECKPOINT**:
```bash
mix dialyzer  # Fix any new warnings from refactoring
mix test      # Ensure all functionality preserved
```

## 📋 **Phase 2 Tasks (Weeks 5-6) - EXTRACT REPEATED PATTERNS**

### **Week 5: Create Utility Modules** 🔧

#### Task 5.1: Extract ESI Error Handling Pattern
Create `lib/eve_dmv/eve/esi_utils.ex`:
```elixir
defmodule EveDmv.Eve.EsiUtils do
  @moduledoc """
  Common utilities for ESI client error handling
  """
  
  require Logger

  def handle_esi_result({:ok, data}, success_fn) when is_function(success_fn, 1) do
    success_fn.(data)
  end

  def handle_esi_result({:error, reason}, fallback_fn) when is_function(fallback_fn, 0) do
    Logger.warning("ESI call failed: #{inspect(reason)}")
    fallback_fn.()
  end

  def safe_esi_call(service_name, call_fn) when is_function(call_fn, 0) do
    try do
      call_fn.()
    rescue
      error ->
        Logger.error("ESI #{service_name} failed: #{inspect(error)}")
        {:error, :service_unavailable}
    end
  end
end
```

Replace ~15 instances of ESI error handling across intelligence modules.

#### Task 5.2: Extract Ash Query Patterns
Create `lib/eve_dmv/database/query_utils.ex`:
```elixir
defmodule EveDmv.Database.QueryUtils do
  @moduledoc """
  Common Ash query patterns and utilities
  """

  def query_killmails_by_corporation(corporation_id, start_date, end_date) do
    KillmailEnriched
    |> Ash.Query.new()
    |> Ash.Query.load(:participants)
    |> Ash.Query.filter(killmail_time >= ^start_date)
    |> Ash.Query.filter(killmail_time <= ^end_date)
    |> Ash.Query.filter(exists(participants, corporation_id == ^corporation_id))
    |> Ash.read(domain: Api)
  end

  def query_killmails_by_character(character_id, start_date, end_date) do
    # Extract similar pattern for character queries
  end

  def safe_percentage(numerator, denominator) do
    if denominator > 0, do: numerator / denominator * 100, else: 0.0
  end
end
```

Replace ~10 instances of repeated Ash queries.

#### Task 5.3: Extract Time Calculation Utilities
Create `lib/eve_dmv/utils/time_utils.ex`:
```elixir
defmodule EveDmv.Utils.TimeUtils do
  @moduledoc """
  Time calculation utilities used across intelligence modules
  """

  def days_between(start_time, end_time) when is_struct(start_time, DateTime) and is_struct(end_time, DateTime) do
    DateTime.diff(end_time, start_time, :day)
  end
  
  def days_since(datetime) when is_struct(datetime, DateTime) do
    days_between(datetime, DateTime.utc_now())
  end

  def hours_between(start_time, end_time) when is_struct(start_time, DateTime) and is_struct(end_time, DateTime) do
    DateTime.diff(end_time, start_time, :hour)
  end

  def truncate_to_hour(datetime) when is_struct(datetime, DateTime) do
    %{datetime | minute: 0, second: 0, microsecond: {0, 6}}
  end
end
```

Replace ~12 instances of DateTime.diff calculations.

### **Week 6: Extract Complex Calculations** 📊

#### Task 6.1: Extract Ship Analysis Module
Create `lib/eve_dmv/intelligence/ship_analyzer.ex`:
```elixir
defmodule EveDmv.Intelligence.ShipAnalyzer do
  @moduledoc """
  Ship categorization and analysis utilities
  """
  
  # Ship type ID ranges based on EVE Online static data
  @frigate_range 25..40
  @destroyer_range 419..420
  @cruiser_range 620..660
  
  def categorize_ship(ship_type_id) when ship_type_id in @frigate_range, do: "Frigate"
  def categorize_ship(ship_type_id) when ship_type_id in @destroyer_range, do: "Destroyer"
  def categorize_ship(ship_type_id) when ship_type_id in @cruiser_range, do: "Cruiser"
  def categorize_ship(_), do: "Other"

  def analyze_ship_usage(killmails) do
    # Extract ship usage analysis patterns
  end

  def calculate_ship_preferences(character_killmails) do
    # Extract ship preference calculations
  end
end
```

#### Task 6.2: Extract Engagement Calculation Module
Create `lib/eve_dmv/intelligence/engagement_calculator.ex`:
```elixir
defmodule EveDmv.Intelligence.EngagementCalculator do
  @moduledoc """
  Member engagement scoring and calculation utilities
  """

  def calculate_overall_score(member_data) do
    killmail_score = calculate_killmail_score(member_data)
    participation_score = calculate_participation_score(member_data)
    communication_score = calculate_communication_score(member_data)
    
    min(100, killmail_score + participation_score + communication_score)
  end
  
  defp calculate_killmail_score(data), do: min(50, Map.get(data, :killmail_count, 0) * 2)
  defp calculate_participation_score(data), do: Map.get(data, :fleet_participation, 0.0) * 30
  defp calculate_communication_score(data), do: min(20, Map.get(data, :communication_activity, 0))
end
```

**PHASE 2 END CHECKPOINT**:
```bash
mix dialyzer  # Fix any new warnings from extractions
mix test      # Ensure all functionality preserved
```

## 📋 **Phase 3 Tasks (Weeks 7-8) - SIMPLIFY OVER-ENGINEERING**

### **Week 7: Simplify Complex Conditionals** 🔀

#### Task 7.1: Simplify Deep Nesting in WHVetting
**File**: `lib/eve_dmv/intelligence/wh_vetting_analyzer.ex`

Replace deep nesting (lines 708-715) with early returns:
```elixir
# BEFORE (deep nesting):
if condition1 do
  if condition2 do
    if condition3 do
      # deep logic
    end
  end
end

# AFTER (early returns):
def some_function(params) do
  unless condition1, do: return_early_result()
  unless condition2, do: return_early_result()
  unless condition3, do: return_early_result()
  
  # main logic at top level
end
```

#### Task 7.2: Simplify Risk Assessment Logic
**File**: `lib/eve_dmv/intelligence/wh_vetting_analyzer.ex`

Replace complex nested conditionals (lines 1499-1523) with pattern matching:
```elixir
defp assess_risk_level(analysis_data) do
  case {analysis_data.threat_score, analysis_data.confidence_score} do
    {threat, confidence} when threat >= 8 and confidence >= 7 -> :high_risk
    {threat, confidence} when threat >= 6 and confidence >= 5 -> :medium_risk
    {threat, confidence} when threat >= 3 and confidence >= 3 -> :low_risk
    _ -> :minimal_risk
  end
end
```

#### Task 7.3: Simplify Fleet Analysis Conditionals
**File**: `lib/eve_dmv/intelligence/wh_fleet_analyzer.ex`

Replace deep nesting (lines 1163-1180) with guard clauses and smaller functions.

### **Week 8: Remove Over-Abstraction** 📐

#### Task 8.1: Review Behavior Implementations
Look for behaviors or protocols that wrap trivial logic and consider removing them if they're not adding value.

#### Task 8.2: Simplify Multi-Arity Functions
Convert excessive multi-arity functions to use default parameters where appropriate:
```elixir
# BEFORE (multiple arities):
def analyze_character(character_id), do: analyze_character(character_id, nil)
def analyze_character(character_id, options), do: analyze_character(character_id, options, nil)
def analyze_character(character_id, options, requested_by)

# AFTER (defaults):
def analyze_character(character_id, options \\ [], requested_by \\ nil)
```

#### Task 8.3: Consolidate Similar Functions
Look for functions that do almost the same thing and consolidate them with parameters.

**PHASE 3 END CHECKPOINT**:
```bash
mix dialyzer  # Should show cleaner, simpler type flows
mix test      # All tests should pass with simpler code
```

## 📋 **Phase 4 Tasks (Weeks 9-10) - FINAL OPTIMIZATION**

### **Week 9: Performance Improvements** ⚡

#### Task 9.1: Replace Enum with Stream for Large Collections
Identify places where large collections are processed multiple times:
```elixir
# BEFORE:
killmails
|> Enum.filter(&filter_fn/1)
|> Enum.map(&transform_fn/1)
|> Enum.reduce(0, &count_fn/2)

# AFTER: 
killmails
|> Stream.filter(&filter_fn/1)
|> Stream.map(&transform_fn/1)
|> Enum.reduce(0, &count_fn/2)
```

#### Task 9.2: Optimize Repeated Calculations
Cache expensive calculations that are repeated within the same function call.

### **Week 10: Code Organization** 📁

#### Task 10.1: Review Module Organization
Ensure extracted utility modules are in the right place and properly namespaced.

#### Task 10.2: Implement TODO Enhancement Features
Add the low-priority enhancement features from TODO.md:

**Corporation Intelligence Analysis** (TODO Item)
**Location**: `lib/eve_dmv/intelligence/correlation_engine.ex:139`  
**Task**: Implement corporation intelligence analysis when data is available  
**Details**: Currently returns placeholder data. Need to implement actual analysis of corporation members and patterns.

**Fleet Analysis Functions** (TODO Item)
**Location**: `lib/eve_dmv/intelligence/correlation_engine.ex:633`  
**Task**: Implement these functions when fleet analysis is ready  
**Details**: Several commented-out functions for ship progression consistency and behavioral analysis are waiting for fleet data integration.

#### Task 10.3: Final Cleanup
Remove any temporary code, ensure consistent naming, and verify all extracted patterns are being used.

**FINAL CHECKPOINT**:
```bash
mix dialyzer  # Clean output with well-structured code
mix test      # All tests passing
mix credo     # Clean code quality metrics
```

## 🚨 **Safety Procedures**

### **Before Refactoring Any Function**
1. **RUN TESTS** to ensure current behavior is captured
2. **EXTRACT GRADUALLY** - one piece at a time
3. **TEST AFTER EACH EXTRACTION** 
4. **PRESERVE EXACT BEHAVIOR** - no functional changes

### **When Extracting Patterns**
1. **FIND ALL INSTANCES** first with grep/ripgrep
2. **CREATE UTILITY MODULE** with comprehensive tests
3. **REPLACE ONE AT A TIME** and test each replacement
4. **VERIFY NO BEHAVIOR CHANGES**

### **If You Break Something**
1. **REVERT IMMEDIATELY** with git
2. **ANALYZE THE FAILURE** carefully
3. **EXTRACT SMALLER PIECES** next time
4. **ASK FOR HELP** if pattern is too complex

## ✅ **Success Criteria**

By the end of 10 weeks, you must achieve:
- [ ] **All functions under 50 lines** (8 functions refactored)
- [ ] **All repeated patterns extracted** (~25 instances)
- [ ] **All deep nesting simplified** (early returns, guard clauses)
- [ ] **All utility modules tested** and documented
- [ ] **Zero functions over 75 lines** anywhere in the codebase
- [ ] **Clean dialyzer output** with simplified type flows
- [ ] **Improved performance** through Stream usage where appropriate
- [ ] **Corporation Intelligence Analysis** implemented (TODO item)
- [ ] **Fleet Analysis Functions** implemented (TODO item)

**Final Deliverable**: A well-organized codebase with focused functions, reusable utilities, and simplified logic flows that's easy to understand and maintain.

Remember: **You are building the structural foundation that makes future development faster and safer. Clean, focused functions make everything else possible.**