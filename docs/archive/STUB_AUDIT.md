# Stub Implementation Audit

**Created**: 2025-01-08  
**Purpose**: Track all placeholder/stub implementations that need to be marked or removed

## 🔴 Critical Stubs to Fix

### 1. Battle Analysis Service ✅
**File**: `lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis_service.ex`
- [x] `fetch_battle_killmails/1` - Now returns {:error, :not_implemented}
- [x] `fetch_recent_system_kills/2` - Now returns {:error, :not_implemented}
- [x] `classify_ship/1` - Now returns :unknown
- [x] `calculate_logistics_ratio/1` - Now returns nil
- [x] `calculate_side_isk_destroyed/2` - Now returns nil
- [x] `calculate_side_isk_lost/2` - Now returns nil
- [x] `calculate_side_efficiency/2` - Now returns nil
- [x] `identify_battle_phases/1` - Marked with TODO
- [x] `identify_tactical_patterns/1` - Marked with TODO
- [x] `identify_key_moments/1` - Marked with TODO
- [x] `identify_turning_points/2` - Marked with TODO
- [x] Main handlers updated to handle {:error, :not_implemented}

### 2. Wormhole Operations ✅
**Chain Intelligence Service** (`lib/eve_dmv/contexts/wormhole_operations/domain/chain_intelligence_service.ex`)
- [x] `calculate_system_strategic_value/1` - Now returns {:error, :not_implemented}
- [x] `analyze_chain_activity/1` - Now returns {:error, :not_implemented}
- [x] `assess_chain_threats/1` - Now returns {:error, :not_implemented}
- [x] `optimize_chain_coverage/2` - Now returns {:error, :not_implemented}
- [x] `get_intelligence_summary/1` - Now returns {:error, :not_implemented}

**Mass Optimizer** (`lib/eve_dmv/contexts/wormhole_operations/domain/mass_optimizer.ex`)
- [x] `optimize_fleet_composition/2` - Now returns {:error, :not_implemented}
- [x] `calculate_mass_efficiency/1` - Now returns {:error, :not_implemented}
- [x] `generate_optimization_suggestions/2` - Now returns {:error, :not_implemented}
- [x] `get_metrics/0` - Marked with TODO comment

**Home Defense Analyzer** (`lib/eve_dmv/contexts/wormhole_operations/domain/home_defense_analyzer.ex`)
- [x] `calculate_defense_readiness_score/1` - Now returns {:error, :not_implemented}
- [x] `generate_defense_recommendations/1` - Now returns {:error, :not_implemented}
- [x] `analyze_defense_capabilities/1` - Now returns {:error, :not_implemented}
- [x] `assess_system_vulnerabilities/1` - Now returns {:error, :not_implemented}

### 3. Market Intelligence ✅
**Valuation Service** (`lib/eve_dmv/contexts/market_intelligence/domain/valuation_service.ex`)
- [x] `calculate_killmail_value/1` - Now returns {:error, :not_implemented}
- [x] `calculate_fleet_value/1` - Now returns {:error, :not_implemented}

### 4. Intelligence Analyzers ✅
**Member Activity Analyzer** (`lib/eve_dmv/intelligence/analyzers/member_activity_analyzer.ex`)
- [x] `fetch_corporation_members/1` - Now returns {:error, :not_implemented}

### 5. Fleet Composition Service
**File**: `lib/eve_dmv/contexts/fleet_operations/domain/fleet_composition_service.ex`
- [ ] Check all calculation functions

### 6. Surveillance Matching Engine
**File**: `lib/eve_dmv/contexts/surveillance/domain/matching_engine.ex`
- [ ] Verify if matching logic is real or stubbed

## 📝 Stub Marking Strategy

### Phase 1: Mark with TODO
```elixir
# Original stub:
def calculate_value(_killmail) do
  {:ok, 0}
end

# Mark as not implemented:
def calculate_value(_killmail) do
  # TODO: Implement real price calculation
  # Requires: Janice API integration
  # Original stub returned: {:ok, 0}
  {:error, :not_implemented}
end
```

### Phase 2: Update Callers
Any code calling these functions must handle `{:error, :not_implemented}`:
```elixir
case calculate_value(killmail) do
  {:ok, value} -> value
  {:error, :not_implemented} -> "Price unavailable"
  {:error, reason} -> "Error: #{reason}"
end
```

### Phase 3: Update UI
LiveViews must gracefully handle missing features:
```heex
<%= if @feature_implemented? do %>
  <div><%= @actual_data %></div>
<% else %>
  <div class="text-gray-500">Coming soon</div>
<% end %>
```

## 🎯 Priority Order

1. **Battle Analysis** - Most visible stub
2. **Fleet Composition** - Complex calculations all stubbed
3. **Market Intelligence** - Critical for value display
4. **Wormhole Features** - Entire section is placeholder
5. **Intelligence Analyzers** - Mix of real and stub

## ✅ Completion Checklist

- [ ] All stubs marked with TODO comments
- [ ] All stubs return {:error, :not_implemented}
- [ ] All callers handle the error gracefully
- [ ] UI shows "Coming soon" for unimplemented features
- [ ] Tests updated to expect :not_implemented
- [ ] No function returns hardcoded mock data