# EVE DMV Placeholder Implementation Audit

*Updated: 2025-07-25*

This document catalogs all placeholder implementations that violate the "clean codebase" principle by using hardcoded values, random data generation, or stub logic instead of real data analysis.

## 🚨 Critical Placeholders (Immediate Removal Required)

### 1. Hardcoded DPS Values

#### Fleet DPS Calculations
**File**: `lib/eve_dmv/intelligence/analyzers/wh_fleet_analyzer/fleet_analyzer.ex:500-503`  
**Problem**: Static DPS values per ship class
```elixir
battleship_dps = safe_get_count(ship_categories, "battleship") * 800
battlecruiser_dps = safe_get_count(ship_categories, "battlecruiser") * 600  
cruiser_dps = safe_get_count(ship_categories, "cruiser") * 400
destroyer_dps = safe_get_count(ship_categories, "destroyer") * 300
frigate_dps = safe_get_count(ship_categories, "frigate") * 200
```
**Solution**: Query ship attributes from EVE static data tables

#### Ship Stats Calculator
**File**: `lib/eve_dmv/contexts/combat_intelligence/domain/ship_stats_calculator.ex:38`  
**Problem**: `base_dps: 200` for frigate stats  
**Solution**: Calculate from ship bonuses and base attributes

#### Ship Performance Analyzer
**File**: `lib/eve_dmv/contexts/battle_analysis/domain/ship_performance_analyzer.ex:473`  
**Problem**: `base_dps: 200` hardcoded value  
**Solution**: Use ship-specific base damage values

### 2. Hardcoded EHP Values

#### Fleet EHP Calculations
**File**: `lib/eve_dmv/intelligence/analyzers/wh_fleet_analyzer/fleet_analyzer.ex:511-514`  
**Problem**: Static EHP values per ship class
```elixir
base_ehp =
  safe_get_count(ship_categories, "battleship") * 100_000 +
  safe_get_count(ship_categories, "battlecruiser") * 80_000 +
  safe_get_count(ship_categories, "cruiser") * 50_000 +
  safe_get_count(ship_categories, "destroyer") * 15_000
```
**Solution**: Calculate from ship hull/shield/armor values and resistances

### 3. Hardcoded Mass Values

#### Ship Mass Detection
**File**: `lib/eve_dmv/eve/item_type.ex:403`  
**Problem**: Arbitrary 10M mass threshold
```elixir
record.mass && record.mass > 10_000_000 -> "cruiser"
```
**Solution**: Use proper ship classification from static data

#### Ship Stats Mass Fallback
**File**: `lib/eve_dmv/contexts/combat_intelligence/domain/ship_stats_calculator.ex:723`  
**Problem**: `_mass = ship_info.mass || 10_000_000`  
**Solution**: Always require valid mass from static data

## 🎲 Random Data Generation (Remove All)

### 1. Surveillance Dashboard
**File**: `lib/eve_dmv_web/live/surveillance_dashboard_live.ex`  
**Problems**:
- Line 448: `alert_count = :rand.uniform(10)`
- Line 602: `%{hour: hour, alerts: :rand.uniform(5)}`
- Line 621: `confidence: 0.7 + :rand.uniform() * 0.3`
**Solution**: Calculate real alert counts and confidence scores from data

### 2. Wormhole Operations (Extensive Random Data)
**File**: `lib/eve_dmv/contexts/wormhole_operations/domain/home_defense_analyzer.ex:740-742`  
**Problem**: Complete fabrication of connection data
```elixir
connection_type: Enum.random([:c1, :c2, :c3, :null, :low]),
threat_level: Enum.random([:low, :medium, :high]),
monitoring_status: Enum.random([:monitored, :unmonitored, :partially_monitored])
```
**Solution**: Analyze actual wormhole data or remove feature entirely

### 3. Battle Sharing System
**File**: `lib/eve_dmv/contexts/battle_sharing.ex:275-283`  
**Problem**: Multiple `Enum.random()` and `:rand.uniform()` calls  
**Solution**: Use real battle statistics

### 4. Community Manager
**File**: `lib/eve_dmv/contexts/battle_sharing/domain/community_manager.ex:195-207`  
**Problem**: Extensive random data generation for battle statistics  
**Solution**: Query actual community engagement metrics

### 5. Intelligence Analyzers
**File**: `lib/eve_dmv/intelligence/analyzers/corporation_analyzer.ex:262`  
**Problem**: `Enum.random(1..100)` for threat scores  
**Solution**: Calculate threat scores from actual activity data

### 6. Cache Cleanup Worker
**File**: `lib/eve_dmv/intelligence/cache_cleanup_worker.ex:164`  
**Problem**: `cleanup_count = Enum.random(0..10)`  
**Solution**: Report actual cleanup statistics

## 🔢 Modulo-Based Classifications (Replace All)

### 1. Battle Phase Side Assignment
**File**: `lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/analyzers/battle_phase_analyzer.ex:184`  
**Problem**: Arbitrary side assignment
```elixir
case rem(alliance_id, 2) do
  0 -> :side_a
  1 -> :side_b
end
```
**Solution**: Analyze alliance relationships and conflict history

### 2. Wormhole Recruitment Vetter (Extensive Modulo Usage)
**File**: `lib/eve_dmv/contexts/wormhole_operations/domain/recruitment_vetter.ex:234-241`  
**Problem**: Multiple `rem(character_id, n)` operations for fake character data  
**Solution**: Query real character statistics or remove feature

**Additional modulo issues in same file**:
- Lines 475-521: Extensive modulo-based logic for fake corporation history
- Should be completely rewritten with real ESI data queries

### 3. Intelligence Infrastructure
**File**: `lib/eve_dmv/contexts/intelligence_infrastructure/domain/cross_system/analyzers/single_system_analyzer.ex:226`  
**Problem**: `rem(p.character_id, 10) == rem(system_id, 10)` for participant correlation  
**Solution**: Use real spatial/temporal correlation analysis

### 4. Combat Intelligence Service
**File**: `lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis_service.ex:1970`  
**Problem**: `case rem(hash, 4)` for outcome determination  
**Solution**: Analyze actual battle outcomes from killmail data

**Additional issue in same file**:
- Line 1982: `case rem(hash, 3)` for battle type classification
- Should use real engagement pattern analysis

## 📊 Stub Functions (Empty Returns)

### 1. Battle Phase Analysis
**File**: `lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/analyzers/battle_phase_analyzer.ex:19`  
**Problem**: Returns `[]` for battles with <3 events  
**Solution**: Implement single-phase analysis for short battles

### 2. Ship Intelligence Bridge
**File**: `lib/eve_dmv/integrations/ship_intelligence_bridge.ex:185`  
**Problem**: Returns empty arrays when analysis fails
```elixir
primary_ship_classes: []
preferred_roles: []
```
**Solution**: Proper error handling and fallback analysis

## 🧹 Cleanup Action Plan

### Phase 1: Critical Fixes (Week 1)
1. **Replace all hardcoded DPS/EHP values** with static data queries
2. **Remove all random data generation** from surveillance dashboard
3. **Fix ship mass calculations** using proper static data
4. **Replace modulo-based side assignments** with alliance analysis

### Phase 2: Algorithm Improvements (Week 2)
1. **Implement proper battle phase detection** algorithms
2. **Replace wormhole random data** with real analysis or feature removal
3. **Fix corporation analyzer** threat scoring
4. **Improve intelligence correlation** analysis

### Phase 3: Feature Completion (Week 3)
1. **Complete battle sharing system** with real statistics
2. **Enhance recruitment vetting** with ESI data
3. **Implement cache cleanup** reporting
4. **Add proper error handling** for all stub functions

### Phase 4: Testing & Validation (Week 4)
1. **Update all tests** to work with real data
2. **Remove test mocks** that enabled placeholder behavior
3. **Add integration tests** for static data usage
4. **Performance testing** for new implementations

## 🎯 Acceptance Criteria

A placeholder is considered resolved when:

1. ✅ **No Hardcoded Values**: All calculations use real data sources
2. ✅ **No Random Generation**: All data comes from actual system state
3. ✅ **No Modulo Logic**: Classifications use proper algorithms
4. ✅ **No Empty Returns**: Functions provide real analysis or proper errors
5. ✅ **Static Data Integration**: Ship/system data comes from EVE SDE
6. ✅ **Test Coverage**: New implementations have comprehensive tests

## 📈 Impact Assessment

### High Impact (User-Facing)
- **Fleet DPS/EHP calculations** - Affects battle analysis accuracy
- **Surveillance dashboard** - Users see fake alert data
- **Battle phase analysis** - Provides no useful intelligence

### Medium Impact (Backend Analysis)
- **Corporation threat scoring** - Affects intelligence quality
- **Wormhole operations** - Misleads operational planning
- **Cache cleanup reporting** - Affects system monitoring

### Low Impact (Development/Testing)
- **Battle sharing statistics** - Internal feature quality
- **Recruitment vetting** - Specialized use case
- **Intelligence correlation** - Background processing quality

## 📋 Tracking Progress

**Total Placeholders Identified**: 25+  
**Critical Placeholders**: 12  
**Random Data Generators**: 8  
**Modulo-Based Logic**: 5  
**Stub Functions**: 2  

*This document should be updated as placeholders are removed and replaced with real implementations.*