# Placeholder and TODO Audit Report

Generated: 2025-07-28

## Summary

This audit identified placeholder implementations, TODO comments, and functions returning empty data throughout the EVE DMV codebase. The findings align with the issues documented in CLAUDE.md.

## 1. TODO Comments (9 locations)

### Ship Attribute Calculations
- **File**: `lib/eve_dmv/static_data/ship_attribute_importer.ex`
  - Line 225: `# TODO: Replace with full dogma calculation when SDE import is complete`
  - Line 377: `# TODO: Replace with real dogma calculations`
  - Line 473: `# TODO: Replace with real dogma resistances`

### Threat Analysis
- **File**: `lib/eve_dmv/contexts/threat_surveillance/domain/threat_analysis_service.ex`
  - Line 375: `# TODO: Implement actual ship class analysis`

### Combat Intelligence (Backup Files)
- **File**: `lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/extractors/participant_extractor.ex.backup`
  - Multiple TODOs in backup file (not active code)

## 2. Functions Returning Empty Data (50+ instances)

### Common Patterns
- Error handling fallbacks
- Configuration defaults
- Base case returns in recursive functions
- Empty recommendations/suggestions lists

### Most Affected Files
- Query analyzers (`query_plan_analyzer/`)
- Configuration files (`config/`)
- Database utilities (`database/`)

### Examples
```elixir
# lib/eve_dmv/error_codes.ex:342
def codes_in_category(_), do: []

# lib/eve_dmv/database/surveillance_repository.ex:41
[] # Fallback when query fails
```

## 3. Hardcoded Values

### Ship Attributes
**File**: `lib/eve_dmv/static_data/ship_attribute_importer.ex`
- Line 432-433: Hardcoded HP and DPS values for capital/supercapital ships
  ```elixir
  "capital" -> %{shield_hp: 50000, armor_hp: 45000, structure_hp: 40000, dps: 2000}
  "supercapital" -> %{shield_hp: 150_000, armor_hp: 120_000, structure_hp: 100_000, dps: 5000}
  ```

### Market Pricing
**File**: `lib/eve_dmv/contexts/market_intelligence/infrastructure/external_price_client.ex`
- Line 144: Returns `{price: 0.0}` as fallback
- Lines 166-172: Hardcoded price ranges based on type_id

### Valuation Service
**File**: `lib/eve_dmv/contexts/market_intelligence/domain/valuation_service.ex`
- Line 278: Default item value of 100,000
- Lines 285-297: Hardcoded values based on item type ranges

## 4. Random Data Generation (20+ instances)

### Wormhole Operations
**File**: `lib/eve_dmv/contexts/intelligence_infrastructure/domain/cross_system_analyzer/wormhole_chain_analyzer.ex`
- Lines 72, 135, 200-203, 218-226: Random traffic, connections, and wormhole classes
- Line 239: Random ID generation

**File**: `lib/eve_dmv/contexts/wormhole_operations/domain/home_defense_analyzer.ex`
- Lines 739, 879, 887: Modulo-based connection type assignment

**File**: `lib/eve_dmv/contexts/wormhole_operations/domain/recruitment_vetter.ex`
- Lines 234-241: Completely fake character data using modulo operations

### Threat Repository (Archived)
**File**: `lib/eve_dmv/contexts/_archived_infrastructure/threat_repository_archived.ex`
- Lines 98-100: Random threat levels and confidence scores

## 5. Modulo-Based Logic

### Examples
```elixir
# recruitment_vetter.ex:234
corporation_id: 1_000_000 + rem(character_id, 1000)

# home_defense_analyzer.ex:739
connection_type = case rem(i, 5) do

# home_defense_analyzer.ex:879
connection_type = case rem(i, 4) do
```

## 6. Critical Areas Requiring Immediate Attention

### High Priority
1. **Ship Attribute Calculations** - Replace hardcoded HP/DPS values with real SDE data
2. **Wormhole Operations** - Remove all random data generation
3. **Market Pricing** - Implement proper price lookups instead of returning 0.0

### Medium Priority
1. **Threat Analysis** - Implement actual ship class analysis
2. **Modulo-Based Classifications** - Replace with proper logic
3. **Empty Return Values** - Review and implement proper error handling

### Low Priority
1. **Backup Files** - Remove or archive old backup files
2. **Configuration Defaults** - Review if empty defaults are appropriate

## Implementation Plan

1. Start with ship attribute calculations using real SDE data
2. Replace random data generation in wormhole operations
3. Implement proper market price fallbacks
4. Add real threat analysis logic
5. Clean up modulo-based classifications