# SDE Data Source Migration Plan

## Overview

Migrate EVE DMV's static data source from **Fuzzwork CSV dumps** to **CCP's official Static Data Export (SDE)**.

### Current State

Downloads CSV files from `https://www.fuzzwork.co.uk/dump/latest/`:
- `invTypes.csv.bz2`, `invGroups.csv.bz2`, `invCategories.csv.bz2`
- `mapSolarSystems.csv.bz2`, `mapRegions.csv.bz2`, `mapConstellations.csv.bz2`

**Problems:**
1. Third-party dependency - Fuzzwork could go offline or lag behind updates
2. No official support or SLA
3. BZ2 compression requires system binaries
4. Imports ALL 49,906 item types when we only need ~5,000

### Target State

Direct consumption of CCP's official SDE:
- **Download URL**: `https://developers.eveonline.com/static-data/eve-online-static-data-latest-jsonl.zip`
- **Version tracking**: `https://developers.eveonline.com/static-data/tranquility/latest.jsonl`
- **Format**: JSON Lines (efficient streaming)

**Benefits:**
1. Official CCP data source with guaranteed availability
2. Build-number based versioning (e.g., `3142455`) for precise tracking
3. Same source used by wanderer-sde and other community tools
4. **Filter to only killmail-relevant items** (~5,000 vs 49,906)

---

## Item Type Filtering Strategy

### What We Need (Killmail-Relevant Items)

Items that appear on killmails and are needed for analysis:

| Category | Category ID | Needed | Reason |
|----------|-------------|--------|--------|
| Ship | 6 | **Yes** | Victim ship, attacker ships |
| Module | 7 | **Yes** | Fitted modules on killmails |
| Charge | 8 | **Yes** | Loaded ammo/scripts |
| Drone | 18 | **Yes** | Drones in bay/space |
| Implant | 20 | **Yes** | Implants on pods |
| Deployable | 22 | **Yes** | Mobile depots, etc. |
| Fighter | 87 | **Yes** | Carrier fighters |
| Structure | 65 | Maybe | Citadels (if tracking structure kills) |

### What We DON'T Need

| Category | Category ID | Reason |
|----------|-------------|--------|
| Blueprint | 9 | Manufacturing only |
| Skill | 16 | Not on killmails |
| Material | 4 | Manufacturing only |
| Commodity | 17 | Trading only |
| Planetary | Various | PI only |
| Apparel | 91 | Cosmetic only |
| SKIN | 91 | Cosmetic only |
| Reaction | 24 | Manufacturing only |

### Estimated Record Counts

| Current | After Filtering |
|---------|-----------------|
| ~49,906 items | ~5,000-8,000 items |
| ~8,436 systems | ~8,436 systems (no change) |

---

## Implementation Plan

### Phase 1: CCP SDE Client

**New File:** `lib/eve_dmv/external/eve/static_data_loader/ccp_sde_client.ex`

```elixir
defmodule EveDmv.Eve.StaticDataLoader.CcpSdeClient do
  @moduledoc """
  Client for downloading EVE SDE directly from CCP.
  """

  @base_url "https://developers.eveonline.com/static-data"
  @version_url "#{@base_url}/tranquility/latest.jsonl"
  @latest_jsonl_url "#{@base_url}/eve-online-static-data-latest-jsonl.zip"

  # Functions:
  # - get_latest_build_number/0 -> {:ok, 3142455}
  # - download_sde_archive/0 -> {:ok, zip_path}
  # - extract_archive/2 -> {:ok, extracted_dir}
end
```

**Key Features:**
- Fetch build number from `latest.jsonl`
- Download ~500MB ZIP with progress reporting
- 30-minute timeout for large downloads
- Retry with exponential backoff

### Phase 2: JSONL Parser

**New File:** `lib/eve_dmv/external/eve/static_data_loader/jsonl_parser.ex`

```elixir
defmodule EveDmv.Eve.StaticDataLoader.JsonlParser do
  @moduledoc """
  Streaming parser for CCP SDE JSON Lines format.

  JSONL format uses _key/_value for integer keys:
  {"_key": 587, "_value": {"name": {"en": "Rifter"}, "groupID": 25, ...}}
  """

  # Stream parse to avoid memory issues
  def stream_types(path, filter_fn) do
    path
    |> File.stream!()
    |> Stream.map(&Jason.decode!/1)
    |> Stream.filter(filter_fn)
  end
end
```

### Phase 3: Update Item Type Processor

**File:** `lib/eve_dmv/external/eve/static_data_loader/item_type_processor.ex`

**Changes:**
1. Add JSONL parsing alongside CSV
2. Add category filtering for killmail-relevant items only
3. Keep existing database fields (no schema changes)

```elixir
# Category IDs for killmail-relevant items
@killmail_category_ids [
  6,   # Ship
  7,   # Module
  8,   # Charge
  18,  # Drone
  20,  # Implant
  22,  # Deployable
  87   # Fighter
]

def should_import?(type, category_id) do
  category_id in @killmail_category_ids and type["published"] == true
end
```

### Phase 4: Update File Manager

**File:** `lib/eve_dmv/external/eve/static_data_loader/file_manager.ex`

**Changes:**
1. Add CCP download option alongside Fuzzwork
2. Handle ZIP extraction (not BZ2)
3. Support both sources via config

```elixir
@ccp_required_files %{
  types: "sde/fsd/types.jsonl",
  groups: "sde/fsd/groups.jsonl",
  categories: "sde/fsd/categories.jsonl",
  solar_systems: "sde/fsd/universe/mapSolarSystems.jsonl",
  regions: "sde/fsd/universe/mapRegions.jsonl",
  constellations: "sde/fsd/universe/mapConstellations.jsonl"
}
```

### Phase 5: Update Version Manager

**File:** `lib/eve_dmv/external/eve/static_data_loader/sde_version_manager.ex`

**Changes:**
1. Use CCP build numbers (integer) instead of date strings
2. Store `sde_build_number` instead of `sde_version` string
3. Simpler version comparison (integer compare)

### Phase 6: Minimal Schema Update

**Only add one field** to track CCP build number:

```elixir
# In item_type.ex and solar_system.ex
attribute :sde_build_number, :integer do
  allow_nil?(true)
  description("CCP SDE build number (e.g., 3142455)")
end
```

**Migration:**
```bash
mix ash_postgres.create
mix ash_postgres.migrate
```

### Phase 7: Testing & Validation

1. Compare record counts between sources
2. Verify all ships/modules from killmails exist
3. Test version update detection
4. Performance test with filtered imports

### Phase 8: Cleanup ✅ COMPLETE

1. ✅ Removed Fuzzwork code from all modules
2. ✅ Removed `sde_importer.ex` (duplicate)
3. ✅ Removed `csv_parser.ex` (Fuzzwork CSV parsing)
4. ✅ Updated CLAUDE.md documentation
5. ✅ Updated tests to remove Fuzzwork test cases

---

## File Changes Summary

### New Files (Phase 1-2) ✅
| File | Purpose |
|------|---------|
| `ccp_sde_client.ex` | CCP download client |
| `jsonl_parser.ex` | JSONL streaming parser |
| `sde_validator.ex` | SDE validation and testing |

### Modified Files (Phase 3-6) ✅
| File | Changes |
|------|---------|
| `file_manager.ex` | CCP-only source, ZIP handling |
| `sde_version_manager.ex` | CCP build number versioning |
| `item_type_processor.ex` | JSONL parsing, category filtering |
| `solar_system_processor.ex` | JSONL parsing |
| `static_data_loader.ex` | CCP-only loading |
| `item_type.ex` | Add `sde_build_number` field |
| `solar_system.ex` | Add `sde_build_number` field |

### Files Removed (Phase 8) ✅
| File | Reason |
|------|--------|
| `sde_importer.ex` | Duplicate Fuzzwork functionality |
| `csv_parser.ex` | Fuzzwork CSV parsing no longer needed |

---

## Environment Variables

```bash
SDE_DOWNLOAD_TIMEOUT=1800   # seconds (30 min default)
```

Note: The `SDE_SOURCE` environment variable has been removed as we now exclusively use CCP's official SDE.

---

## Success Criteria

1. ✅ ~5,000-8,000 filtered items imported (vs 49,906)
2. ✅ All killmail ships/modules resolvable
3. ✅ Build number tracking working
4. ✅ No regression in existing functionality
5. ✅ Fuzzwork code removed
6. ✅ Tests passing

**Migration Status: COMPLETE**

---

## References

- **CCP SDE Docs**: https://developers.eveonline.com/docs/services/static-data/
- **Latest JSONL**: https://developers.eveonline.com/static-data/eve-online-static-data-latest-jsonl.zip
- **Version Info**: https://developers.eveonline.com/static-data/tranquility/latest.jsonl
- **wanderer-sde**: https://github.com/guarzo/wanderer-sde
