# EVE DMV Revised Requirements

*Updated: 2025-07-18*

This document outlines the revised scope for EVE DMV, focusing on core PvP intelligence features while deferring or dropping non-essential functionality.

## Core Features to Implement

### 1. User Authentication & Access Control
- ✅ **EVE SSO Integration** - Already working
- ✅ **Token Management** - Already working
- ✅ **Session Management** - Already working
- ✅ **Basic Role Support** - Already working
- ❌ ~~Advanced Role Matrix~~ - DROPPED
- ❌ ~~Corporation Officer Detection~~ - DROPPED
- 🔧 **Multi-Character Support** - TO IMPLEMENT

### 2. Live Kill Feed
- ✅ **Real-time Updates** - Already working
- ✅ **Rich Killmail Data** - Already working
- ✅ **Basic Filtering** - Already working
- 🔧 **Advanced Filtering** - TO IMPLEMENT (by alliance, ship type)
- ❌ ~~Mobile Responsive Design~~ - DROPPED
- 🔧 **System Activity Metrics** - TO IMPLEMENT
- 🔧 **Infinite Scroll** - TO IMPLEMENT

### 3. Character Intelligence
- ✅ **Basic Statistics** - Already working
- ✅ **Threat Scoring** - Already working
- ✅ **Ship Preferences** - Already working (lib/eve_dmv_web/live/character_analysis/helpers/character_data_loader.ex:115)
- ✅ **Weapon Preferences** - Already working (lib/eve_dmv_web/live/character_analysis/helpers/character_data_loader.ex:181)
- ✅ **Gang Size Patterns** - Already working (lib/eve_dmv_web/live/character_analysis/helpers/character_data_loader.ex:721)
- ✅ **Activity Patterns** - Already working (lib/eve_dmv_web/live/character_analysis/helpers/character_data_loader.ex:908)
- 🔧 **Comparison Tools** - TO IMPLEMENT
- ❌ ~~Data Export~~ - DROPPED (keep shareable links)

### 4. Battle Analysis
- ✅ **Battle Detection** - Already working
- ✅ **Timeline Reconstruction** - Already working
- 🔧 **Battle Phases** - TO IMPLEMENT
- 🔧 **Participant Analysis** - TO IMPLEMENT
- 🔧 **Doctrine Detection** - TO IMPLEMENT (using static data)
- 🔧 **EWAR Detection** - TO IMPLEMENT
- 🔧 **Outcome Analysis** - TO IMPLEMENT
- 🔧 **Side Determination** - TO IMPLEMENT (proper logic)

### 5. Fleet Operations
- 🔧 **Ship Classification** - TO IMPLEMENT (using static data)
- 🔧 **Real DPS/EHP Calculations** - TO IMPLEMENT
- 🔧 **Role Detection** - TO IMPLEMENT (from ship bonuses)
- 🔧 **Composition Analysis** - TO IMPLEMENT
- 🔧 **Wormhole Mass Calculations** - TO IMPLEMENT (using static data)

### 6. Wormhole Operations
- 🔧 **Chain Mapping** - TO IMPLEMENT (basic)
- 🔧 **System Classification** - TO IMPLEMENT (fix C6 bug)
- 🔧 **Activity Tracking** - TO IMPLEMENT
- 🔧 **Mass Management** - TO IMPLEMENT (using static data)
- 🔧 **Home Defense Analysis** - TO IMPLEMENT (no random data)

### 7. Surveillance Profiles
- ✅ **Basic CRUD** - Already working
- ✅ **Real-time Matching** - Already working
- 🔧 **Complex Filters** - TO IMPLEMENT (AND/OR logic)
- 🔧 **Additional Filter Types** - TO IMPLEMENT
- 📅 ~~Notifications~~ - DEFERRED
- 📅 ~~Profile Sharing~~ - DEFERRED
- 📅 ~~Profile Templates~~ - DEFERRED

### 8. Market Intelligence
- 📅 ~~Price Integration~~ - DEFERRED
- ❌ ~~Mutamarket Support~~ - DROPPED
- Note: Ship values will use static estimates for now

### 9. Data Pipeline & Integrations
- ✅ **wanderer-kills SSE** - Already working
- ✅ **EVE ESI API** - Already working
- ✅ **Broadway Pipeline** - Already working
- ❌ ~~zKillboard Fallback~~ - DROPPED

## Placeholder Cleanup Priority

### Phase 1: Foundation (Static Data Dependent)
1. **Ship Classification** - Replace modulo logic with static data queries
2. **Ship Mass Calculations** - Use actual mass from static data
3. **System Classification** - Fix wormhole C-class detection
4. **Ship Role Detection** - Based on ship bonuses from static data

### Phase 2: Core Analytics
1. ~~**Character Ship/Weapon Preferences**~~ - ✅ ALREADY IMPLEMENTED
2. ~~**Gang Size Patterns**~~ - ✅ ALREADY IMPLEMENTED  
3. ~~**Activity Statistics**~~ - ✅ ALREADY IMPLEMENTED
4. **Battle Phase Detection** - Enhance beyond single-phase implementation
5. **Doctrine Detection** - Pattern matching on ship compositions

### Phase 3: Advanced Features
1. **DPS/EHP Calculations** - Estimates based on ship types
2. **EWAR Detection** - Identify EWAR ships from static data
3. **Fleet Composition Analysis** - Role balance calculations
4. **Wormhole Chain Intelligence** - Basic chain tracking

### Phase 4: Cleanup
1. Remove all `Enum.random` and `:rand.uniform()` calls
2. Remove hardcoded values (DPS, ISK, mass)
3. Remove functions that return empty data
4. Remove references to non-existent modules
5. Update tests to work with real data

## Success Criteria

A feature is complete when:
1. ✅ Queries real data from the database
2. ✅ Uses actual algorithms (no hardcoded values)
3. ✅ No placeholder/mock return values
4. ✅ Tests pass with real data
5. ✅ No random data generation
6. ✅ Leverages static data where applicable

## Out of Scope

The following features are explicitly out of scope:
- Mobile-first design
- Complex permission matrices
- Automatic corporation role detection
- Data export (CSV/JSON)
- External market pricing
- Mutamarket integration
- zKillboard integration
- Push notifications
- Profile sharing system
- Profile template library

## Next Steps

1. **Immediate**: Fix ship classification using static data
2. **Week 1**: Complete Phase 1 (Foundation) items
3. **Week 2**: Complete Phase 2 (Core Analytics)
4. **Week 3**: Complete Phase 3 (Advanced Features)
5. **Week 4**: Complete Phase 4 (Cleanup) and testing