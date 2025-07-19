# Sprint 18: Foundation Cleanup - Ship Classification & Static Data

**Duration**: 2 weeks  
**Start Date**: TBD  
**End Date**: TBD  
**Sprint Goal**: Replace all modulo-based ship classification with real static data queries  

### 🚨 CLEAN CODEBASE COMMITMENT
**This sprint adheres to the Clean Codebase Vision:**
- ✅ NO placeholder implementations
- ✅ NO functions returning empty data as stubs
- ✅ NO hardcoded "magic" numbers
- ✅ NO random data generation for "analysis"
- ✅ ALL features query real data or don't exist

**Philosophy**: "If it returns mock data, it's not done. If it's not done, delete it."

---

## 🎯 Sprint Objective

### Primary Goal
Transform all ship classification and mass calculations to use the 49,906 loaded static data items instead of modulo math and hardcoded values.

### Success Criteria
- [ ] All ship classification uses static data queries
- [ ] Ship mass calculations query actual mass values
- [ ] Wormhole system classification bug fixed (no more all C6)
- [ ] Ship role detection based on actual ship groups
- [ ] No modulo-based logic remains in codebase
- [ ] All tests updated to use real ship data

### Explicitly Out of Scope
- Advanced fleet analysis algorithms (Sprint 21)
- Wormhole chain tracking (Sprint 22)
- Market pricing integration (deferred)

---

## 📊 Sprint Backlog

| Story ID | Description | Points | Priority | Definition of Done |
|----------|-------------|---------|----------|-------------------|
| CLEANUP-1 | Replace get_ship_class() modulo logic in fleet_analyzer.ex | 5 | CRITICAL | Queries eve_item_types table |
| CLEANUP-2 | Fix ship mass calculations in mass_optimizer.ex | 5 | CRITICAL | Returns actual mass from static data |
| CLEANUP-3 | Fix wormhole C-class detection bug | 3 | CRITICAL | Proper C1-C6 classification |
| CLEANUP-4 | Replace get_participant_role() modulo logic | 5 | HIGH | Uses ship group_id from static data |
| CLEANUP-5 | Update composition_analyzer.ex ship classification | 5 | HIGH | All ship lookups use static data |
| CLEANUP-6 | Remove non-existent ShipDatabase references | 3 | HIGH | Clean removal, no fallbacks |
| CLEANUP-7 | Create StaticData query module | 8 | HIGH | Centralized static data access |
| CLEANUP-8 | Update all tests to use real ship IDs | 5 | HIGH | Tests use actual EVE ship IDs |
| CLEANUP-9 | Performance optimization for static queries | 3 | MEDIUM | Add appropriate indexes |
| STORY-1 | Add ship group constants module | 3 | MEDIUM | Define EVE ship categories |

### 🧹 Placeholder Cleanup Tasks (REQUIRED)
- [x] Identified 6 modules with modulo-based ship classification
- [ ] Replace all `ship_type_id % 10` patterns
- [ ] Remove hardcoded mass value (10,000,000)
- [ ] Delete references to non-existent modules

**Total Points**: 45

---

## 📋 Implementation Details

### 1. Fleet Analyzer Cleanup
**File**: `lib/eve_dmv/contexts/fleet_operations/domain/fleet_analyzer.ex`

**Current (Bad)**:
```elixir
defp get_ship_class(ship_type_id) do
  case rem(ship_type_id, 10) do
    1 -> :frigate
    2 -> :destroyer
    3 -> :cruiser
    # ...
  end
end
```

**Target (Good)**:
```elixir
defp get_ship_class(ship_type_id) do
  case StaticData.get_ship_group(ship_type_id) do
    %{group_id: 25} -> :frigate
    %{group_id: 420} -> :destroyer
    %{group_id: 26} -> :cruiser
    # ... using actual EVE group IDs
  end
end
```

### 2. Mass Optimizer Cleanup
**File**: `lib/eve_dmv/contexts/wormhole_operations/domain/mass_optimizer.ex`

**Current (Bad)**:
```elixir
def get_ship_mass(ship_type_id) do
  # Fallback to 10,000,000
  10_000_000
end
```

**Target (Good)**:
```elixir
def get_ship_mass(ship_type_id) do
  case StaticData.get_type_attributes(ship_type_id) do
    %{mass: mass} when mass > 0 -> mass
    _ -> {:error, :mass_not_found}
  end
end
```

### 3. System Classification Fix
**File**: `lib/eve_dmv/contexts/wormhole_operations/domain/chain_intelligence_service.ex`

**Current (Bad)**:
```elixir
defp classify_system_type(system_id) do
  cond do
    system_id >= 31_000_000 -> :wormhole_c6  # Wrong!
    # All conditions return :wormhole_c6
  end
end
```

**Target (Good)**:
```elixir
defp classify_system_type(system_id) do
  system = StaticData.get_system(system_id)
  
  case system do
    %{security_class: "C1"} -> :wormhole_c1
    %{security_class: "C2"} -> :wormhole_c2
    # ... etc
    %{security_status: sec} when sec >= 0.5 -> :highsec
    %{security_status: sec} when sec > 0.0 -> :lowsec
    _ -> :nullsec
  end
end
```

### 4. Create StaticData Module
**New File**: `lib/eve_dmv/static_data.ex`

```elixir
defmodule EveDmv.StaticData do
  @moduledoc """
  Centralized access to EVE static data with caching.
  """
  
  alias EveDmv.Eve.{ItemType, SolarSystem, ItemGroup}
  
  def get_type(type_id) do
    # Query with caching
  end
  
  def get_ship_group(ship_type_id) do
    # Join with groups table
  end
  
  def get_type_attributes(type_id) do
    # Return mass, volume, etc.
  end
  
  def get_system(system_id) do
    # Return system with security info
  end
end
```

---

## 🔍 Validation Checklist

### Pre-Implementation Checks
- [ ] Run static data verification: `mix eve.verify_static_data`
- [ ] Document current modulo patterns locations
- [ ] Create performance baseline for ship queries

### Post-Implementation Validation
- [ ] Grep for modulo patterns returns 0 results
- [ ] All ship classifications return correct EVE groups
- [ ] Wormhole systems show correct C-class
- [ ] Mass calculations return actual values
- [ ] Performance impact < 10ms per query
- [ ] All tests pass with real data

### Manual Testing Scenarios
1. **Fleet Composition Analysis**
   - Create fleet with mixed ship types
   - Verify correct classification (no more modulo math)
   - Check role assignments match ship bonuses

2. **Wormhole Mass Calculator**
   - Test with common doctrine ships
   - Verify mass values match EVE
   - No hardcoded 10,000,000 fallback

3. **System Classification**
   - Test J-space systems (C1-C6)
   - Test k-space systems (high/low/null)
   - Verify no "all C6" bug

---

## 📊 Sprint Metrics Goals

### Code Quality Metrics
- **Placeholders Removed**: Target 15+ functions
- **Hardcoded Values Eliminated**: All ship-related
- **Static Data Queries Added**: 20+
- **Test Coverage**: Maintain > 80%

### Performance Metrics  
- **Static Query Time**: < 5ms average
- **Cache Hit Rate**: > 90%
- **No Performance Regression**: Page load < 200ms

---

## 🚀 Next Sprint Preview

**Sprint 19: Character Intelligence Cleanup**
- Implement ship preference analysis from killmails
- Calculate weapon usage patterns
- Analyze gang size preferences
- Complete activity statistics

This sprint lays the foundation for all ship-related features to work with real data!