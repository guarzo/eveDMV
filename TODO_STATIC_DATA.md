# TODO: EVE Static Data Integration

## Current Status
The killmail processing pipeline is working but we have temporarily disabled foreign key relationships to EVE static data.

## Changes Made
**Date**: 2025-06-29  
**File**: `lib/eve_dmv/killmails/participant.ex`

Temporarily commented out the following relationships in the `Participant` resource:

```elixir
# belongs_to :ship_type, EveDmv.Eve.ItemType do
#   source_attribute(:ship_type_id)
#   destination_attribute(:type_id)
#   description("Ship type information")
# end

# belongs_to :weapon_type, EveDmv.Eve.ItemType do
#   source_attribute(:weapon_type_id)
#   destination_attribute(:type_id)
#   description("Weapon type information")
# end
```

## Why This Was Done
- Participants were failing to insert due to foreign key constraint violations
- The `eve_item_types` table is currently empty (no EVE static data loaded)
- Ship type IDs from killmails (e.g., 73789, 20125, 32968, 670, etc.) don't exist in the static data table

## What Needs To Be Done Later

1. **Load EVE Static Data**
   - Populate the `eve_item_types` table with ship types, weapon types, and other item data
   - This could be done via EVE's Static Data Export (SDE) or EVE Swagger API

2. **Re-enable Foreign Key Relationships**
   - Uncomment the `belongs_to` relationships in `participant.ex`
   - Generate and run a new migration to add the foreign key constraints back

3. **Test Data Integrity**
   - Ensure all existing participants can be linked to valid item types
   - Handle any orphaned records that reference non-existent item types

## Impact
- ✅ Killmail pipeline now works end-to-end without foreign key errors
- ✅ Raw killmails, enriched killmails, and participants are all being inserted
- ⚠️ Ship and weapon type information is stored as IDs only (no name resolution)
- ⚠️ No referential integrity for item type IDs until foreign keys are restored

## Priority
**Medium** - The pipeline works without this, but having proper static data relationships will improve data quality and enable better querying capabilities.