# TODO Items Replaced During Dialyzer Fix

This document tracks all TODO comments that were replaced or modified during the systematic Dialyzer error resolution process.

## Phase 1: Foundation Issues - Pattern Matching Failures

### Overview
During Phase 1 of the Dialyzer fix implementation, we're replacing stub functions that return `{:error, :not_implemented}` or always return empty results with minimal viable implementations that satisfy type contracts.

### Replaced TODO Items

## Phase 3: Guards & Contracts

### /workspace/lib/eve_dmv/contexts/market_intelligence/infrastructure/price_cache.ex - stats/0
- **Original TODO**: None (was a type spec mismatch)
- **Replacement**: Updated @spec to include all fields returned by the function (hits, misses, puts, hit_rate)
- **Rationale**: The @spec only listed size and memory_bytes but the function returns 6 fields
- **Future Work**: None - this is the correct spec

### /workspace/lib/eve_dmv/intelligence_engine/plugins/character/combat_stats.ex - plugin_info/0 and cache_strategy/0
- **Original TODO**: None (was callback type mismatches)
- **Replacement**: Removed extra fields (author, tags from plugin_info and strategy from cache_strategy)
- **Rationale**: The Plugin behaviour callbacks only expect specific fields
- **Future Work**: Consider extending the behaviour if these fields are needed

### /workspace/lib/eve_dmv_web/live/system_live.ex - Guard failures lines 320-323
- **Original TODO**: None (was redundant guard clauses)
- **Replacement**: Removed `|| 0` fallback patterns since variables already have numeric values
- **Rationale**: Variables were already guaranteed to be numbers from calculations above
- **Future Work**: None - cleanup only

### /workspace/lib/eve_dmv_web/live/corporation_live.ex - Guard failures lines 91-93
- **Original TODO**: None (was redundant guard clauses)
- **Replacement**: Removed `|| []` and `|| %{}` fallback patterns for battles, battle_stats, fleet_doctrines
- **Rationale**: These fields are always populated by function calls in load_all_corporation_data
- **Future Work**: None - cleanup only

---

## Documentation Notes

- **Purpose**: Track removed TODO items to maintain visibility into what was temporarily implemented
- **Format**: Each entry includes file path, function name, original TODO text, and replacement rationale
- **Review**: These items should be revisited for full implementation in future sprints

## Template for New Entries

```markdown
### [File Path] - [Function Name]
- **Original TODO**: [Original TODO comment text]
- **Replacement**: [Brief description of what was implemented instead]
- **Rationale**: [Why this replacement was chosen for Dialyzer compliance]
- **Future Work**: [Notes on what a full implementation would require]
```