# Sprint 18: Initial Placeholder Audit Results

**Date**: 2025-07-18  
**Sprint**: 18 - Foundation Cleanup

## Summary of Findings

### Modulo-Based Ship Classification
Found several instances of using `rem(ship_type_id, 10)` for ship classification:

1. **fleet_operations/domain/effectiveness_calculator.ex**
   - Line contains: `case rem(ship_type_id, 10) do`
   - Used for role determination

2. **fleet_operations/domain/doctrine_manager.ex**
   - Line contains: `case rem(ship_type_id, 10) do`
   - Used for ship classification

3. **wormhole_operations/domain/recruitment_vetter.ex**
   - Contains modulo logic for ship analysis

### Hardcoded Mass Values
Major issue found:

1. **shared/ship_database_service.ex**
   - Contains hardcoded ship database with static mass values
   - Fallback function: `def get_ship_mass(_), do: 10_000_000`
   - This appears to be a temporary static data solution

2. **contexts/wormhole_operations/domain/mass_optimizer.ex**
   - Direct use of `10_000_000` as fallback
   - Random mass calculations: `rand.uniform(50_000_000_000)`

3. **contexts/fleet_operations/domain/fleet_analyzer.ex**
   - Uses `@ship_masses` map with fallback to `10_000_000`

### Non-Existent Module References
Need to investigate:
- References to ShipDatabase modules mentioned in cleanup plan
- The `ship_database_service.ex` appears to be the temporary implementation

## Priority Actions for Sprint 18

1. **Create StaticData Module** (CLEANUP-7)
   - Central module for all static data queries
   - Replace ship_database_service.ex

2. **Fix Ship Classification** (CLEANUP-1, CLEANUP-5)
   - effectiveness_calculator.ex
   - doctrine_manager.ex
   - Use real ship group IDs from static data

3. **Fix Mass Calculations** (CLEANUP-2)
   - mass_optimizer.ex
   - Remove all hardcoded mass values
   - Query from eve_item_types table

4. **Fix Wormhole Classification** (CLEANUP-3)
   - Need to find the actual wormhole classification code
   - Mentioned in plan but not found in initial scan

## Static Data Verification

Before starting, we should verify:
1. Ship type data is accessible
2. Ship groups are properly loaded
3. Mass attributes are available in the static data

## Notes

- The `ship_database_service.ex` appears to be an interim solution that should be completely replaced
- Some modulo usage is for non-ship purposes (batch processing) - these are OK
- Random data generation found in mass calculations needs removal