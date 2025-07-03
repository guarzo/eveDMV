# Cleanup Team Alpha - Dead Code & File Removal Plan

> **AI Assistant Instructions for Cleanup Alpha Team**
> 
> You are Cleanup Team Alpha, responsible for removing dead code, backup files, and unused artifacts. Your work has **highest merge priority** as it creates the cleanest foundation for other cleanup teams.

## 🎯 **Your Mission**

Remove dead files, backup artifacts, unused functions, and obsolete code to establish a clean codebase foundation for the entire cleanup effort.

## ⚠️ **Critical Instructions**

### **Quality Requirements**
After **EVERY SINGLE TASK**, you must run:
```bash
mix format
mix credo
git add -A && git commit -m "cleanup: descriptive message"
```

**Phase End Requirements**
At the end of each phase, you must run and fix any issues:
```bash
mix dialyzer
mix test
```

### **Safety First**
- **NEVER** remove files unless you've verified they're truly unused
- **ALWAYS** search the entire codebase before removing functions
- **BACKUP** any questionable removals in commit messages
- **TEST** the application after each removal batch

### **Dependencies**
- **NO DEPENDENCIES** - You start immediately
- **You merge FIRST every Friday**
- **All other cleanup teams depend on your work**

### **Merge Coordination**
- Announce file deletions in team chat immediately
- Other teams depend on your cleanup being complete
- Your changes affect the entire codebase

## 📋 **Phase 1 Tasks (Weeks 1-2) - CRITICAL FILE CLEANUP**

### **Week 1: Environment Setup & Dead File Removal** 🗑️

#### Task 0.1: Configure Unique Development Ports
**IMPORTANT**: Configure unique ports for Cleanup Team Alpha devcontainer to avoid conflicts with other cleanup teams.

**File**: `.devcontainer/devcontainer.json` (Cleanup Alpha worktree)
```json
{
  "name": "EVE DMV Cleanup Alpha Team Dev Container",
  "dockerComposeFile": "../docker-compose.yml",
  "service": "app",
  "workspaceFolder": "/workspace",
  "shutdownAction": "stopCompose",
  "forwardPorts": [4020, 5440, 6390],
  "portsAttributes": {
    "4020": {
      "label": "Phoenix Server (Cleanup Alpha)",
      "onAutoForward": "notify"
    },
    "5440": {
      "label": "PostgreSQL (Cleanup Alpha)"
    },
    "6390": {
      "label": "Redis (Cleanup Alpha)"
    }
  }
}
```

**Environment Variables**: Create `.env.cleanup_alpha`
```bash
PHOENIX_PORT=4020
DATABASE_URL=postgresql://postgres:postgres@localhost:5440/eve_dmv_dev
REDIS_URL=redis://localhost:6390/0
MIX_ENV=dev
```

### **Week 1: Remove Dead Files & Directories** 🗑️

#### Task 1.1: Remove Backup Files (IMMEDIATE)
```bash
# These files are definitely safe to remove
rm lib/eve_dmv_web/components/intelligence_components.ex.backup
rm -rf priv/repo/migrations_backup/
rm dialyzer.txt
rm erl_crash.dump
rm testing_helpers.exs
rmdir test/eve_dmv/users/

git add -A
git commit -m "cleanup: remove backup files and empty directories"
```

#### Task 1.2: Clean Asset Duplicates
```bash
cd priv/static/assets/
# Remove non-hashed versions (hashed versions are the canonical ones)
rm app.css app.js
# Only keep the hashed versions: app-*.css and app-*.js

git add -A
git commit -m "cleanup: remove duplicate non-hashed assets"
```

#### Task 1.3: Search for Remaining Artifacts
```bash
# Search for other potential cleanup targets
find . -name "*.backup" -o -name "*.bak" -o -name "*~"
find . -name "*.orig" -o -name "*.swp" -o -name ".DS_Store"

# Remove any found artifacts
# Document findings in commit message
```

**MERGE CHECKPOINT**: Commit and push. Other teams need clean file structure.

**PHASE 1 END CHECKPOINT**:
```bash
mix dialyzer  # Fix any new warnings
mix test      # Ensure no tests broken by removals
```

### **Week 2: Remove Unused Functions** ✂️

#### Task 2.1: Remove Hardcoded Stub Functions
**File**: `lib/eve_dmv/intelligence/character_metrics.ex`

Remove these unused functions that return hardcoded values:
```elixir
# Lines 496, 635, 640 - Remove these functions:
# - get_region_from_system/1 (returns "Unknown Region")
# - estimate_preferred_range/1 (returns "Unknown")  
# - calculate_bait_susceptibility/1 (returns "Unknown")
```

Search entire codebase first to ensure they're unused:
```bash
rg "get_region_from_system|estimate_preferred_range|calculate_bait_susceptibility" lib/ test/
```

#### Task 2.2: Remove Unused Trend Functions  
**File**: `lib/eve_dmv/intelligence/member_activity_analyzer.ex`

Remove these functions that return hardcoded `:stable` (lines 642-644):
```elixir
# Remove these after verifying they're unused:
# - determine_overall_trend_direction/1
# - calculate_member_count_trend/1  
# - calculate_engagement_trend/1
```

#### Task 2.3: Remove Unused Correlation Engine Functions
**File**: `lib/eve_dmv/intelligence/correlation_engine.ex`

Based on Dialyzer warnings, remove these unused functions:
```elixir
# Lines 522-544 - Remove these functions:
# - get_bulk_character_analyses/1
# - analyze_recruitment_patterns/1
# - analyze_activity_coordination/1
# - analyze_corp_skill_distribution/1
# - analyze_corp_risk_distribution/1
# - analyze_doctrine_adherence/1
```

#### Task 2.4: Remove Unused Intelligence Coordinator Functions
**File**: `lib/eve_dmv/intelligence/intelligence_coordinator.ex`

Remove unused functions (lines 480-494):
```elixir
# Remove these functions:
# - generate_corp_summary/1
# - assess_corp_security/1  
# - generate_corp_recommendations/1
```

#### Task 2.5: Remove Unused WHVetting Functions
**File**: `lib/eve_dmv/intelligence/wh_vetting_analyzer.ex`

Remove unused date analysis functions (lines 1018-1040):
```elixir
# Remove these functions:
# - detect_employment_gaps/1
# - calculate_date_gap/2
```

## 📋 **Phase 2 Tasks (Weeks 3-4) - LIVEW VIEW CLEANUP**

### **Week 3: Remove Unused LiveView Functions** 🖥️

#### Task 3.1: Intelligence Dashboard LiveView Cleanup
**File**: `lib/eve_dmv_web/live/intelligence_dashboard_live.ex`

Remove these unused private functions (lines 268-357):
```elixir
# Remove these unused formatter functions:
# - format_threat_level/1
# - format_timeframe/1  
# - format_cache_health/1
# - format_system_status/1
# - format_relative_time/1
# - get_confidence_color/1
# - get_analysis_type_badge/1
# - format_number/1
# - get_timeframe_options/0
```

Search to confirm they're truly unused:
```bash
rg "format_threat_level|format_timeframe|format_cache_health" lib/eve_dmv_web/
```

#### Task 3.2: Character Intelligence LiveView Cleanup  
**File**: `lib/eve_dmv_web/live/character_intelligence_live.ex`

Remove unused functions (lines 371-448):
```elixir
# Remove these unused functions:
# - format_threat_level/1
# - format_confidence/1
# - format_vetting_status/1  
# - format_relative_time/1
# - get_correlation_strength_color/1
# - get_analysis_completeness/1
```

Remove unused alias:
```elixir
# Remove this unused alias on line 13:
# alias EveDmv.Intelligence.IntelligenceCache
```

**PHASE 2 END CHECKPOINT**:
```bash
mix dialyzer  # Fix any new warnings  
mix test      # Ensure no tests broken by removals
```

#### Task 3.3: WHVetting LiveView Cleanup
**File**: `lib/eve_dmv_web/live/wh_vetting_live.ex`

Remove unused function (line 200):
```elixir
# Remove this function:
# - create_basic_character_results/1
```

### **Week 4: Configuration & Module Cleanup** ⚙️

#### Task 4.1: Remove Unused Configuration
**File**: `config/config.exs`

Remove unused zkillboard configuration (line 100):
```elixir
# Remove this unused config:
# zkillboard_sse_url: System.get_env("ZKILLBOARD_SSE_URL", "wss://zkillboard.com/websocket/")
```

#### Task 4.2: Remove Unused Module Attributes
**File**: `lib/eve_dmv/intelligence/intelligence_cache.ex`

Remove unused module attribute (line 14):
```elixir
# Remove this unused attribute:
# @default_ttl :timer.hours(6)
```

#### Task 4.3: Fix Unused Variables (Dialyzer Issues)
**File**: `lib/eve_dmv/intelligence/intelligence_coordinator.ex`

Fix unused variables throughout the file by prefixing with underscore:
```elixir
# Lines 309, 321, 332, 349, 366, 371, 387, 394, 397, 400, 412, 461, 468, 498, 499, 504
# Change: summary_points = [...]
# To: _summary_points = [...]

# Line 529: Fix unused parameter
# Change: defp get_recent_intelligence_activity(timeframe) do
# To: defp get_recent_intelligence_activity(_timeframe) do
```

**File**: `lib/eve_dmv/database/health_check.ex`

Fix unused variable (line 196):
```elixir
# Change: total_queue_length = 
# To: _total_queue_length =
```

**File**: `lib/eve_dmv_web/live/character_intelligence_live.ex`

Fix unused variable (line 306):
```elixir
# Change: def handle_info({:vetting_complete, vetting_record}, socket) do
# To: def handle_info({:vetting_complete, _vetting_record}, socket) do
```

**PHASE 3 END CHECKPOINT**:
```bash
mix dialyzer  # Should show significant reduction in warnings
mix test      # All tests should pass
```

## 📋 **Phase 3 Tasks (Weeks 5-6) - FINAL CLEANUP**

### **Week 5: Remove Obsolete Code Patterns** 🔧

#### Task 5.1: Clean up Pattern Matches
Fix impossible pattern matches identified by Dialyzer in:
- `lib/eve_dmv/intelligence/character_formatters.ex:590`
- `lib/eve_dmv/intelligence/correlation_engine.ex` (multiple locations)
- `lib/eve_dmv/intelligence/member_activity_analyzer.ex` (multiple locations)

#### Task 5.2: Clean up Ship Database Duplicates
**File**: `lib/eve_dmv/intelligence/ship_database.ex`

Fix duplicate key warning (line 119):
```elixir
# Fix the duplicate key 23913 in the ship database map
# Investigate which value is correct and remove the duplicate
```

### **Week 6: Documentation & Final Verification** 📚

#### Task 6.1: Update Documentation
Remove references to deleted functions from any documentation.

#### Task 6.2: Final Verification
```bash
# Run comprehensive checks
mix format
mix credo --strict  
mix dialyzer
mix test
mix deps.audit

# Verify no broken references remain
rg "TODO|FIXME|XXX|HACK" lib/ || echo "No technical debt markers found"
```

#### Task 6.3: Create API Fallback Controller (TODO Item)
**Location**: `lib/eve_dmv_web/controllers/api/api_keys_controller.ex:14`  
**Priority**: High Priority (affects API reliability)

Create the missing fallback controller for consistent API error responses:

**File**: `lib/eve_dmv_web/controllers/fallback_controller.ex`
```elixir
defmodule EveDmvWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid HTTP responses.
  
  See https://hexdocs.pm/phoenix/controllers.html#action-fallback-controllers
  for more details.
  """
  use EveDmvWeb, :controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(EveDmvWeb.ErrorView)
    |> render(:"404")
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(EveDmvWeb.ErrorView)
    |> render(:"401")
  end

  def call(conn, {:error, changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(EveDmvWeb.ChangesetView)
    |> render("error.json", changeset: changeset)
  end
end
```

#### Task 6.4: Generate Cleanup Report
Create a summary of all removed code:
- Lines of code removed: ~500+
- Functions removed: ~25+  
- Files removed: ~15+
- Directories removed: ~2+

## 🚨 **Safety Procedures**

### **Before Removing Any Function**
1. **SEARCH** the entire codebase: `rg "function_name" lib/ test/`
2. **CHECK** test files: `rg "function_name" test/`
3. **VERIFY** no dynamic calls: `rg "apply|send|:erlang.apply" lib/`
4. **DOCUMENT** removal reason in commit message

### **Before Removing Any File**
1. **CHECK** imports: `rg "YourModule" lib/`
2. **VERIFY** no dynamic references: `rg "String.to_atom|Module.concat" lib/`
3. **TEST** application startup after removal
4. **BACKUP** content in commit message if uncertain

### **If You're Unsure**
1. **ASK** in team chat before removing
2. **COMMENT OUT** instead of deleting initially
3. **TEST** with comments before final removal
4. **DOCUMENT** uncertainty in commit message

## ✅ **Success Criteria**

By the end of 6 weeks, you must achieve:
- [ ] **All backup files** removed from repository
- [ ] **All unused functions** removed (verified by search)
- [ ] **All empty directories** removed
- [ ] **All unused imports/aliases** removed
- [ ] **All impossible pattern matches** fixed
- [ ] **All unused variables** fixed (prefixed with _)
- [ ] **Zero Dialyzer warnings** for unused code
- [ ] **Zero TODO/FIXME** comments in lib/
- [ ] **Clean credo output** with no dead code warnings
- [ ] **API Fallback Controller** implemented (TODO item)

**Final Deliverable**: A pristine codebase with ~500+ lines of dead code removed, ready for other cleanup teams to focus on refactoring and optimization.

Remember: **You are creating the foundation for all other cleanup work. A clean, dead-code-free codebase makes everything else possible.**