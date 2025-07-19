# EVE DMV Placeholder Cleanup Plan

*Created: 2025-07-18*

This document provides a detailed, file-by-file plan for removing all placeholder implementations and creating a clean codebase that meets the revised requirements.

## Phase 1: Foundation Fixes (Static Data Dependent)

### 1.1 Ship Classification
**File**: `lib/eve_dmv/contexts/fleet_operations/domain/fleet_analyzer.ex`
- **Line 298-319**: Replace `get_ship_class()` modulo logic with static data query
- **Action**: Query `eve_item_types` table using ship_type_id

**File**: `lib/eve_dmv/contexts/fleet_operations/analyzers/composition_analyzer.ex`
- **Lines 314-331**: Update ship classification to use static data
- **Action**: Join with static data tables for proper ship groups

### 1.2 Ship Mass Calculations
**File**: `lib/eve_dmv/contexts/wormhole_operations/domain/mass_optimizer.ex`
- **Lines 314-331**: Remove hardcoded 10,000,000 fallback
- **Lines 321-323**: Remove references to non-existent ShipDatabase modules
- **Action**: Query mass from `eve_item_types` table

### 1.3 System Classification
**File**: `lib/eve_dmv/contexts/wormhole_operations/domain/chain_intelligence_service.ex`
- **Lines 396-410**: Fix `classify_system_type()` C6 bug
- **Action**: Use proper system_id ranges or query static data

**File**: `lib/eve_dmv/contexts/wormhole_operations/domain/home_defense_analyzer.ex`
- **Lines 678-716**: Fix wormhole classification logic
- **Action**: Use static data for proper C-class detection

### 1.4 Ship Role Detection
**File**: `lib/eve_dmv/contexts/fleet_operations/domain/fleet_analyzer.ex`
- **Lines 456-463**: Replace `get_participant_role()` modulo logic
- **Action**: Determine roles based on ship group_id from static data

## Phase 2: Core Analytics Implementation

### 2.1 Character Preferences
**File**: `lib/eve_dmv_web/live/character_analysis/helpers/character_data_loader.ex`
- **Line 103**: Implement `get_ship_preferences()`
  - Query killmails for ship_type_id frequency
  - Group by ship type and count
- **Line 105**: Implement `get_weapon_preferences()`
  - Parse killmail items for weapon types
  - Aggregate by weapon type
- **Line 111**: Implement `get_gang_size_patterns()`
  - Analyze killmail participant counts
  - Create distribution buckets (solo, small gang, fleet)

### 2.2 Activity Statistics
**File**: `lib/eve_dmv_web/live/character_analysis/helpers/character_data_loader.ex`
- **Line 113**: Implement `calculate_activity_stats()`
  - Query killmail timestamps
  - Calculate active days, peak hours
- **Line 115**: Implement `calculate_character_intelligence_summary()`
  - Aggregate location data from killmails
  - Determine timezone from activity patterns

### 2.3 Battle Analysis
**File**: `lib/eve_dmv/contexts/battle_analysis/domain/battle_analysis_service.ex`
- **Line 1004**: Implement `identify_battle_phases()`
  - Analyze kill timing for intensity changes
  - Identify escalation/de-escalation periods
- **Line 1831**: Implement `calculate_intensity_curve()`
  - Calculate kills per minute over battle duration
- **Line 1836**: Implement `track_participant_flow()`
  - Track when pilots enter/leave battle
- **Line 1083**: Implement `detect_doctrine_usage()`
  - Pattern match ship compositions
- **Line 1118**: Implement `detect_ewar_presence()`
  - Check for EWAR ship types from static data

### 2.4 Battle Outcomes
**File**: `lib/eve_dmv/contexts/battle_analysis/domain/battle_analysis_service.ex`
- **Line 1925**: Implement `determine_battle_winner()`
  - Compare ISK destroyed by each side
  - Consider strategic objectives
- **Line 1009**: Fix `determine_side()` 
  - Use corporation/alliance standings or relationships

## Phase 3: Advanced Features

### 3.1 Fleet Analysis
**File**: `lib/eve_dmv/contexts/fleet_operations/domain/fleet_analyzer.ex`
- **Lines 582-591**: Replace `estimate_fleet_dps()` hardcoded values
  - Use ship base stats from static data
  - Apply reasonable multipliers

**File**: `lib/eve_dmv/contexts/fleet_operations/analyzers/composition_analyzer.ex`
- **Lines 866-887**: Implement `analyze_damage_capabilities()`
  - Use ship bonuses from static data
- **Line 889**: Implement `analyze_ewar_capabilities()`
  - Detect EWAR ships and estimate strength
- **Lines 982-992**: Replace hardcoded analysis values
  - Calculate based on actual fleet composition

### 3.2 Wormhole Intelligence
**File**: `lib/eve_dmv/contexts/wormhole_operations/domain/chain_intelligence_service.ex`
- **Lines 432-445**: Replace hardcoded strategic values
  - Calculate based on actual system activity
- **Lines 448-475**: Implement pattern analysis
  - Query killmail data for temporal patterns
- **Line 580-582**: Implement `get_corporation_active_chains()`
  - Track systems with corp activity

**File**: `lib/eve_dmv/contexts/wormhole_operations/domain/home_defense_analyzer.ex`
- **Lines 759-777**: Remove `Enum.random` from `analyze_entry_points()`
  - Analyze actual connection data
- **Lines 860-906**: Remove random data generation
  - Calculate from actual system topology

## Phase 4: Final Cleanup

### 4.1 Remove Random Data Generation
**Files to clean**:
- `home_defense_analyzer.ex` - All `:rand.uniform()` calls
- `mass_optimizer.ex` - Lines 796-850 (metrics functions)
- Any remaining `Enum.random` usage

### 4.2 Remove Stub Price Client
**File**: `lib/eve_dmv/contexts/market_intelligence/infrastructure/external_price_client.ex`
- **Action**: Since pricing is deferred, remove the stub client entirely
- Update dependent code to use static ship value estimates

### 4.3 Remove Empty Functions
**File**: `lib/eve_dmv/contexts/battle_analysis/domain/battle_analysis_service.ex`
- **Lines 1844-1856**: Remove functions that only return empty data
- Either implement or remove based on revised requirements

### 4.4 Update LiveViews
**File**: `lib/eve_dmv_web/live/battle_analysis_live.ex`
- **Lines 479, 538**: Replace mock character IDs with actual user IDs

**File**: `lib/eve_dmv_web/live/fleet_operations_live.ex`
- **Lines 1122-1136**: Use static data for ship values instead of hardcoded

### 4.5 Fix Behavioral Pattern Analyzer
**File**: `lib/eve_dmv/contexts/character_intelligence/domain/behavioral_pattern_analyzer.ex`
- Replace all `:requires_implementation` returns with either:
  - Actual implementations if needed
  - Remove functions if not in revised scope

## Testing Strategy

1. **Unit Tests**: Update all tests to use real static data
2. **Integration Tests**: Ensure queries return actual data
3. **Remove Mock Data**: Delete any test fixtures with fake data
4. **Validation**: Ensure no functions return hardcoded values

## Success Metrics

After cleanup:
- 0 instances of `Enum.random` or `:rand.uniform()`
- 0 functions returning hardcoded analytical values
- 0 references to non-existent modules
- All ship/system classification using static data
- All empty array/map returns replaced with real queries

## Estimated Timeline

- **Week 1**: Complete Phase 1 (Foundation)
- **Week 2**: Complete Phase 2 (Core Analytics)
- **Week 3**: Complete Phase 3 (Advanced Features)
- **Week 4**: Complete Phase 4 (Cleanup) and comprehensive testing

This plan ensures a systematic approach to removing all placeholders while maintaining a working application throughout the process.