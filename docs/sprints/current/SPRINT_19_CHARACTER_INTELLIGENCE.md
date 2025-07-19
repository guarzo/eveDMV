# Sprint 19: Character Intelligence Cleanup

**Duration**: 2 weeks  
**Start Date**: 2025-07-18  
**End Date**: 2025-08-01  
**Sprint Goal**: Transform character intelligence from empty placeholders to real data analysis  

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
Replace all character intelligence placeholders with real queries against killmail data, providing genuine insights into pilot behavior and preferences.

### Success Criteria
- [ ] Ship preferences show actual ships flown with percentages
- [ ] Weapon preferences display real module usage
- [ ] Gang size patterns calculated from killmail participants
- [ ] Activity statistics show real timezone/day patterns
- [ ] External groups identified from killmail data
- [ ] All empty array returns eliminated

### Explicitly Out of Scope
- Advanced behavioral clustering (can be deferred)
- ML-based predictions
- Cross-character comparison UI (separate feature)

---

## 📊 Sprint Backlog

| Story ID | Description | Points | Priority | Definition of Done |
|----------|-------------|---------|----------|-------------------|
| CLEANUP-1 | Implement get_ship_preferences() | 8 | CRITICAL | Returns top ships with counts |
| CLEANUP-2 | Implement get_weapon_preferences() | 8 | CRITICAL | Parses killmail items for weapons |
| CLEANUP-3 | Implement calculate_isk_efficiency() | 5 | CRITICAL | Real ISK calculations |
| CLEANUP-4 | Implement get_gang_size_patterns() | 5 | HIGH | Analyzes participant counts |
| CLEANUP-5 | Implement calculate_activity_stats() | 5 | HIGH | Peak hours from timestamps |
| CLEANUP-6 | Implement get_external_groups() | 8 | HIGH | Non-corp collaborators |
| CLEANUP-7 | Fix character_intelligence_summary() | 3 | HIGH | Aggregate location/timezone |
| CLEANUP-8 | Remove behavioral analyzer stubs | 3 | MEDIUM | Delete or implement |
| STORY-1 | Add character analytics caching | 5 | MEDIUM | Performance optimization |
| STORY-2 | Create preference trend tracking | 5 | LOW | Historical comparisons |

### 🧹 Placeholder Cleanup Tasks (REQUIRED)
- [x] Identified 7 functions returning empty data
- [ ] Replace all `[]` returns with real queries
- [ ] Remove `:requires_implementation` placeholders
- [ ] Update tests to verify real data

**Total Points**: 55

---

## 📋 Implementation Details

### 1. Ship Preferences Implementation
**File**: `lib/eve_dmv_web/live/character_analysis/helpers/character_data_loader.ex`

**Current (Bad)**:
```elixir
def get_ship_preferences(_character_id) do
  []
end
```

**Target (Good)**:
```elixir
def get_ship_preferences(character_id) do
  character_id
  |> KillmailQueries.get_character_ships(limit: 10)
  |> Enum.group_by(& &1.ship_type_id)
  |> Enum.map(fn {ship_type_id, killmails} ->
    ship_type = StaticData.get_type(ship_type_id)
    
    %{
      ship_type_id: ship_type_id,
      ship_name: ship_type.name,
      ship_group: ship_type.group_name,
      count: length(killmails),
      percentage: length(killmails) / total_kills * 100,
      last_used: List.first(killmails).occurred_at,
      avg_fit_value: calculate_avg_fit_value(killmails)
    }
  end)
  |> Enum.sort_by(& &1.count, :desc)
end
```

### 2. Weapon Preferences Implementation

**Target Implementation**:
```elixir
def get_weapon_preferences(character_id) do
  character_id
  |> KillmailQueries.get_character_killmails(role: :attacker)
  |> Enum.flat_map(& &1.attackers)
  |> Enum.filter(&(&1.character_id == character_id))
  |> Enum.flat_map(&parse_weapon_types(&1.items))
  |> Enum.frequencies()
  |> Enum.map(fn {weapon_type_id, count} ->
    weapon = StaticData.get_type(weapon_type_id)
    
    %{
      weapon_type_id: weapon_type_id,
      weapon_name: weapon.name,
      weapon_category: get_weapon_category(weapon),
      usage_count: count,
      percentage: count / total_weapons * 100,
      avg_damage_done: calculate_avg_damage(character_id, weapon_type_id)
    }
  end)
  |> Enum.sort_by(& &1.usage_count, :desc)
  |> Enum.take(10)
end
```

### 3. Gang Size Patterns

**Target Implementation**:
```elixir
def get_gang_size_patterns(character_id) do
  patterns = character_id
  |> KillmailQueries.get_character_kills(days: 90)
  |> Enum.group_by(&classify_gang_size(length(&1.attackers)))
  |> Enum.map(fn {size_category, kills} ->
    {size_category, %{
      count: length(kills),
      percentage: length(kills) / total_kills * 100,
      avg_isk_efficiency: calculate_category_efficiency(kills),
      preferred_ships: get_preferred_ships_for_size(kills)
    }}
  end)
  |> Map.new()
  
  %{
    solo: Map.get(patterns, :solo, default_pattern()),
    small_gang: Map.get(patterns, :small_gang, default_pattern()),
    medium_gang: Map.get(patterns, :medium_gang, default_pattern()),
    fleet: Map.get(patterns, :fleet, default_pattern())
  }
end

defp classify_gang_size(count) when count == 1, do: :solo
defp classify_gang_size(count) when count <= 5, do: :small_gang
defp classify_gang_size(count) when count <= 15, do: :medium_gang
defp classify_gang_size(_count), do: :fleet
```

### 4. Activity Statistics

**Target Implementation**:
```elixir
def calculate_activity_stats(character_id, days \\ 30) do
  killmails = KillmailQueries.get_character_activity(character_id, days: days)
  
  %{
    total_days_active: calculate_active_days(killmails),
    avg_kills_per_day: length(killmails) / days,
    most_active_hour: calculate_peak_hour(killmails),
    most_active_weekday: calculate_peak_weekday(killmails),
    timezone_estimate: estimate_timezone(killmails),
    activity_trend: calculate_trend(killmails),
    longest_streak: calculate_longest_streak(killmails),
    current_streak: calculate_current_streak(killmails)
  }
end

defp calculate_peak_hour(killmails) do
  killmails
  |> Enum.map(&DateTime.to_time(&1.occurred_at).hour)
  |> Enum.frequencies()
  |> Enum.max_by(fn {_hour, count} -> count end)
  |> elem(0)
end
```

### 5. External Groups Analysis

**Target Implementation**:
```elixir
def get_external_groups(character_id) do
  %{corp_id: corp_id, alliance_id: alliance_id} = get_character_affiliation(character_id)
  
  character_id
  |> KillmailQueries.get_character_kills(days: 90)
  |> Enum.flat_map(& &1.attackers)
  |> Enum.reject(&(&1.character_id == character_id))
  |> Enum.reject(&(&1.corporation_id == corp_id))
  |> Enum.reject(&(alliance_id && &1.alliance_id == alliance_id))
  |> Enum.group_by(&{&1.corporation_id, &1.corporation_name})
  |> Enum.map(fn {{corp_id, corp_name}, attackers} ->
    %{
      corporation_id: corp_id,
      corporation_name: corp_name,
      times_flown_with: length(attackers),
      unique_pilots: attackers |> Enum.map(& &1.character_id) |> Enum.uniq() |> length(),
      last_seen: attackers |> Enum.map(& &1.killmail.occurred_at) |> Enum.max(),
      common_targets: analyze_common_targets(character_id, corp_id)
    }
  end)
  |> Enum.sort_by(& &1.times_flown_with, :desc)
  |> Enum.take(10)
end
```

---

## 🔍 Validation Checklist

### Function-by-Function Validation
- [ ] `get_ship_preferences()` returns actual ships with counts
- [ ] `get_weapon_preferences()` shows real weapon usage
- [ ] `calculate_isk_efficiency()` uses killmail values
- [ ] `get_gang_size_patterns()` has percentage breakdowns
- [ ] `calculate_activity_stats()` shows timezone patterns
- [ ] `get_external_groups()` identifies real collaborators
- [ ] No function returns empty arrays as placeholder

### Integration Testing
1. **Character Profile Page**
   - All sections display real data
   - No "No data" messages for active characters
   - Percentages add up correctly
   
2. **Performance Validation**
   - Page load time < 500ms with caching
   - Queries optimized with proper indexes
   
3. **Edge Cases**
   - New character with 0 kills
   - Very active character (1000+ kills)
   - Character with gaps in activity

---

## 📊 Sprint Metrics Goals

### Cleanup Metrics
- **Empty Functions Fixed**: 7/7
- **Placeholder Returns Eliminated**: 100%
- **Real Data Queries Added**: 15+
- **Test Coverage**: > 85%

### Data Quality Metrics
- **Ship Preferences Accuracy**: Matches zkillboard
- **Activity Pattern Detection**: ±1 hour timezone accuracy
- **External Groups**: Validated against killmails

---

## 🚀 Next Sprint Preview

**Sprint 20: Battle Analysis Completion**
- Implement battle phase detection algorithms
- Complete tactical analysis functions
- Add doctrine recognition
- Fix participant flow tracking

Dependencies: Requires static data from Sprint 18