# EVE DMV Clean Codebase Vision

*Target State After Cleanup*

## Overview

After implementing the cleanup plan, EVE DMV will be a focused PvP intelligence platform with a clean, maintainable codebase that queries real data and provides genuine analytical value.

## What EVE DMV Will Be

### A Focused PvP Intelligence Tool
- **Real-time kill tracking** with rich filtering capabilities
- **Character threat assessment** based on actual combat performance
- **Battle reconstruction** with timeline and participant analysis
- **Fleet composition analysis** using real ship data
- **Wormhole activity tracking** for chain awareness
- **Surveillance profiles** for custom intelligence gathering

### Clean Architecture Principles
1. **No Placeholder Data**: Every function returns real calculations or queries
2. **Static Data Integration**: All ship/system lookups use the loaded EVE data
3. **Honest Implementations**: If a feature isn't ready, it's removed rather than stubbed
4. **Testable Code**: All features work with real data in tests
5. **Clear Boundaries**: Deferred features are cleanly separated

## Core User Journeys

### 1. PvP Intelligence Analyst
```
Login → View Live Feed → Filter by Region/Alliance
→ Click Character → View Threat Score & Combat History
→ Analyze Ship Preferences → Compare with Corpmates
→ Share Intelligence Link
```

### 2. Fleet Commander
```
Login → Fleet Optimizer → Input Pilot List
→ View Composition Analysis → See Role Balance
→ Get DPS/Tank Estimates → Check Wormhole Mass
→ Share Fleet Composition
```

### 3. Wormhole Corporation Member
```
Login → View Chain Activity → See Recent Kills
→ Track Home Defense Metrics → Monitor Entry Points
→ Check Mass Calculations → Plan Fleet Movements
```

### 4. Intelligence Officer
```
Login → Create Surveillance Profile → Set Complex Filters
→ Monitor Real-time Matches → View Historical Patterns
→ Analyze Battle Outcomes → Track Enemy Doctrines
```

## Technical Implementation

### Data Flow
```
wanderer-kills SSE → Broadway Pipeline → PostgreSQL
                                      ↓
                          Static Data Tables ← EVE SDE
                                      ↓
                              Domain Services
                                      ↓
                              Phoenix LiveView → User
```

### Key Improvements

#### Before (Placeholder)
```elixir
def get_ship_preferences(_character_id) do
  []  # Returns nothing
end

def estimate_fleet_dps(_ships) do
  600  # Hardcoded value
end
```

#### After (Clean)
```elixir
def get_ship_preferences(character_id) do
  character_id
  |> KillmailQueries.get_character_ships()
  |> Enum.group_by(& &1.ship_type_id)
  |> Enum.map(fn {type_id, kills} -> 
    %{
      ship_type_id: type_id,
      ship_name: StaticData.get_type_name(type_id),
      count: length(kills),
      percentage: length(kills) / total_kills * 100
    }
  end)
  |> Enum.sort_by(& &1.count, :desc)
end

def estimate_fleet_dps(ships) do
  ships
  |> Enum.map(fn ship ->
    base_dps = StaticData.get_ship_attribute(ship.type_id, :base_dps)
    role_modifier = get_role_modifier(ship.type_id)
    base_dps * role_modifier
  end)
  |> Enum.sum()
end
```

## What's NOT in Scope

The clean codebase will NOT include:
- ❌ Stub functions that return fake data
- ❌ References to features we're not building
- ❌ Complex UI for mobile devices
- ❌ Half-implemented market pricing
- ❌ Notification systems that don't notify
- ❌ Random data generators masquerading as analytics

## Quality Indicators

### Code Smells Eliminated
- No more `TODO` comments
- No more `:requires_implementation`
- No more `Enum.random` in production code
- No more hardcoded "magic" numbers
- No more empty catch-all functions

### Positive Patterns Established
- Clear service boundaries
- Consistent error handling
- Comprehensive test coverage
- Documented API contracts
- Performance monitoring

## User Experience

### Current State Issues
- "Why does every wormhole show as C6?"
- "Why are all ship values exactly 400k ISK?"
- "Why does fleet DPS always show 600?"

### Target State Benefits
- Accurate ship classifications from static data
- Real fleet composition analysis
- Meaningful threat assessments
- Trustworthy intelligence data

## Maintenance Benefits

### Developer Experience
- New developers can understand the codebase
- Features either work completely or don't exist
- Clear separation between implemented and deferred
- No confusion about what's real vs placeholder

### Future Development
- Clean foundation for adding deferred features
- Clear patterns for implementing new analytics
- No technical debt from placeholder code
- Easy to add market pricing when ready

## Success Metrics

1. **Zero Placeholder Functions**: Grep for common patterns shows 0 results
2. **100% Static Data Usage**: All ship/system lookups use real data
3. **Real User Value**: Every feature provides actionable intelligence
4. **Clean Test Suite**: All tests pass with real data
5. **No Confusion**: Code does what it says, nothing more, nothing less

## Timeline to Clean State

- **Week 1**: Foundation established (static data fully integrated)
- **Week 2**: Core analytics working (character, battle analysis)
- **Week 3**: Advanced features complete (fleet, wormhole ops)
- **Week 4**: Final cleanup and validation

## Conclusion

The clean EVE DMV will be a focused, honest implementation that provides real value to EVE Online PvP pilots. By removing placeholders and focusing on core features that work with real data, we create a maintainable platform that can grow organically as new requirements emerge.

**The goal**: When a user clicks on any feature, it works with real data or it doesn't exist.