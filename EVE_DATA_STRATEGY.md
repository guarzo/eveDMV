# EVE Data Strategy Plan

## Overview

This document outlines the strategy for handling EVE Online static data and API integration to resolve issues with missing system names, ship types, and other entity information in the killmail pipeline.

## Current Issues

- System names showing as "Unknown System" because wanderer-kills only provides `system_id`
- Foreign key relationships disabled due to missing static data in `eve_item_types` table
- No real-time lookup capability for dynamic data (character/corp/alliance names)

## Strategy

### 1. **Static Data Loading** (Priority: High)
- Load EVE SDE (Static Data Export) for:
  - Solar system names (`solar_systems` table)
  - Ship type information (`item_types` table) 
  - Corporation/alliance names that don't change often
- Store in our existing `eve_item_types` table and create new tables as needed
- This solves the immediate "Unknown System" issue

### 2. **EVE ESI API Integration** (Priority: High)  
- Create EVE ESI client for real-time lookups
- Handle dynamic data that changes frequently:
  - Character names
  - Corporation names (can change)
  - Alliance names (can change)
- Implement rate limiting and error handling

### 3. **Data Strategy**
- **Static data first**: Always try local static data lookup
- **ESI fallback**: Call ESI API for missing/dynamic data
- **Cache ESI responses**: Store frequently accessed API results
- **Graceful degradation**: Show IDs when both static and API fail

### 4. **Implementation Steps**
1. Create EVE SDE data loader (mix task)
2. Build ESI API client module  
3. Create lookup service that tries static → ESI → fallback
4. Re-enable foreign key relationships
5. Update pipeline to use lookup service

## Implementation Details

### Phase 1: Static Data Foundation
- Download and parse EVE SDE data
- Create database tables for:
  - `eve_solar_systems` (system_id, system_name, constellation, region)
  - Expand `eve_item_types` with complete ship/module data
  - `eve_corporations` and `eve_alliances` for major entities
- Create mix tasks for data loading and updates

### Phase 2: ESI API Client
- HTTP client with proper rate limiting (ESI has strict limits)
- Caching layer for API responses
- Error handling and retry logic
- Endpoints needed:
  - `/universe/systems/{system_id}/`
  - `/characters/{character_id}/`
  - `/corporations/{corporation_id}/`
  - `/alliances/{alliance_id}/`

### Phase 3: Lookup Service
- Unified service that abstracts data source (static vs API)
- Intelligent caching strategy
- Fallback mechanisms

### Phase 4: Pipeline Integration
- Update killmail pipeline to use lookup service
- Re-enable foreign key relationships
- Update LiveView to display proper names

## Benefits

- **Performance**: Static data lookups are instant
- **Reliability**: Local data doesn't depend on EVE API availability
- **Completeness**: ESI fills gaps for dynamic/missing data
- **User Experience**: Proper names instead of IDs
- **Data Integrity**: Foreign key relationships ensure data consistency

## Files to Create/Modify

- `lib/eve_dmv/eve/sde_loader.ex` - Static data loader
- `lib/eve_dmv/eve/esi_client.ex` - ESI API client
- `lib/eve_dmv/eve/lookup_service.ex` - Unified lookup service
- `lib/mix/tasks/eve.load_sde.ex` - Mix task for SDE loading
- Update pipeline and LiveView to use lookup service
- Re-enable foreign keys in participant resource

## Next Steps

1. **Immediate**: Create SDE loader for solar systems to fix "Unknown System" issue
2. **Short-term**: Build ESI client for character/corp/alliance lookups
3. **Long-term**: Complete static data loading and re-enable all foreign keys