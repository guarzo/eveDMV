# Cleanup Team Delta - Remaining Work Plan

> **Status**: Team Delta completed ~75% of planned work. This document outlines the remaining tasks needed to achieve the original goals.

## 🚨 **Critical Remaining Issues**

Based on verification of Team Delta's work, the following critical issues remain unresolved:

### **Dialyzer Warnings (5 errors remain)**
1. **asset_analyzer.ex:38** - Incomplete pattern match (missing error clause)
2. **home_defense_analyzer.ex:175** - Pattern can never match
3. **asset_analyzer.ex:144** - EsiCache.get_type/1 undefined function
4. **correlation_engine.ex:134** - Missing error clause in case statement
5. **wh_vetting_analyzer.ex:215** - New pattern match issue (introduced after Delta's work)

### **Documentation Gaps**
1. **docs/configuration.md** - Not created as specified in plan
2. Some modules still lack comprehensive @spec annotations

## 📋 **Priority 1: Fix Remaining Dialyzer Warnings**

### Task 1.1: Fix Asset Analyzer Pattern Matching
**File**: `lib/eve_dmv/intelligence/asset_analyzer.ex`

```elixir
# Line 38 - Add missing error clause:
member_assets =
  case fetch_member_assets(composition.corporation_id, auth_token) do
    {:ok, assets} -> assets
    {:error, reason} -> 
      Logger.warning("Failed to fetch member assets: #{inspect(reason)}")
      []
  end
```

### Task 1.2: Fix Correlation Engine Pattern Match
**File**: `lib/eve_dmv/intelligence/correlation_engine.ex`

```elixir
# Line 134 - Add missing error clause:
case get_corporation_members_from_activity(corporation_id) do
  {:ok, members} when members == [] ->
    {:error, "No recent activity found for corporation"}
  {:ok, members} ->
    {:ok, %{corporation_id: corporation_id, members: members, analysis: "not_implemented"}}
  {:error, reason} -> 
    {:error, reason}
end
```

### Task 1.3: Fix Home Defense Analyzer Pattern
**File**: `lib/eve_dmv/intelligence/home_defense_analyzer.ex:175`

Investigate and fix the pattern that can never match. This requires understanding the function's logic and fixing the impossible condition.

### Task 1.4: Fix Undefined Function Call
**File**: `lib/eve_dmv/intelligence/asset_analyzer.ex:144`

```elixir
# Change from:
EsiClient.get_type(type_id)

# To:
EsiCache.get_type(type_id)
```

### Task 1.5: Fix WHVetting Analyzer New Issue
**File**: `lib/eve_dmv/intelligence/wh_vetting_analyzer.ex:215`

This is a new issue introduced after Team Delta's work. Investigate the refactoring at line 215 and fix the pattern match issue.

## 📋 **Priority 2: Complete Documentation**

### Task 2.1: Create Configuration Documentation
**File**: `docs/configuration.md`

Create comprehensive configuration guide as specified in original plan:

```markdown
# Configuration Guide

## Environment Variables

### Required Variables
- `EVE_SSO_CLIENT_ID` - EVE SSO application client ID
- `EVE_SSO_CLIENT_SECRET` - EVE SSO application secret
- `SECRET_KEY_BASE` - Phoenix secret key base
- `DATABASE_URL` - PostgreSQL connection string

### Optional Variables
- `WANDERER_KILLS_ENABLED` - Enable wanderer kills integration (default: true)
- `WANDERER_KILLS_SSE_URL` - SSE endpoint URL
- `PIPELINE_ENABLED` - Enable killmail pipeline (default: true)
- `MOCK_SSE_SERVER_ENABLED` - Use mock server for development (default: false)

## Intelligence Configuration

Configure intelligence analysis behavior in `config/config.exs`:

\```elixir
config :eve_dmv, :intelligence,
  analysis_timeout: 30_000,
  correlation_enabled: true,
  threat_scoring: [
    character_age_weight: 0.3,
    corporation_history_weight: 0.4,
    activity_weight: 0.3
  ]
\```

## Cache Configuration

Configure caching behavior:

\```elixir
config :eve_dmv, :cache,
  ttl: 3600,  # 1 hour default TTL
  max_stale_age: 86400,  # 24 hours max stale age
  cleanup_interval: 300_000  # 5 minutes cleanup
\```
```

### Task 2.2: Add Missing Type Specifications
Review and add @spec annotations to any remaining public functions without them, particularly in:
- Security modules
- Database modules
- Any newly refactored modules

## 📋 **Priority 3: Quality Verification**

### Task 3.1: Run Full Quality Suite
After fixing all issues, run complete quality verification:

```bash
# Fix all code formatting
mix format

# Run static analysis
mix credo --strict

# Run Dialyzer - MUST show 0 errors
mix dialyzer

# Run all tests
mix test

# Generate documentation
mix docs
```

### Task 3.2: Update Final Report
Update the TEAM_DELTA_FINAL_REPORT.md with accurate metrics after completing all fixes.

## 🎯 **Success Criteria**

The work is complete when:
- [ ] **0 Dialyzer warnings** (currently 5)
- [ ] **Configuration documentation created**
- [ ] **All pattern match issues resolved**
- [ ] **All undefined function calls fixed**
- [ ] **Quality suite passes cleanly**

## ⏱️ **Estimated Time**

- Priority 1 (Dialyzer fixes): 2-3 hours
- Priority 2 (Documentation): 1 hour
- Priority 3 (Verification): 30 minutes

**Total: 3-4 hours of focused work**

## 🚨 **Important Notes**

1. **Test After Each Fix**: Run `mix test` after each Dialyzer fix to ensure no regressions
2. **Understand Before Fixing**: Don't just silence warnings - understand and fix the root cause
3. **Coordinate with Team**: If fixes require changes to shared modules, coordinate with other teams
4. **Document Complex Fixes**: If a fix requires non-obvious logic, add comments explaining why

Remember: The goal is not just to silence warnings but to create a robust, maintainable codebase that serves as a model for future development.